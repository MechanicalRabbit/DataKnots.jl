#
# Optimizing pipelines.
#

struct RewriteMemo
    op_map::Dict{Any,Dict{Vector{Any},Pipeline}}

    RewriteMemo() = new(Dict{Any,Dict{Vector{Any},Pipeline}}())
end

function (memo::RewriteMemo)(p::Pipeline)
    args_map = get!(memo.op_map, p.op) do
        Dict{Any,Dict{Vector{Any},Pipeline}}()
    end
    get!(args_map, p.args) do
        p
    end
end

function (memo::RewriteMemo)(ps::Vector{Pipeline})
    if isempty(ps)
        memo(pass())
    elseif length(ps) == 1
        memo(ps[1])
    else
        memo(chain_of(ps))
    end
end

function unchain(p)
    if p.op == pass
        return Pipeline[]
    elseif p.op == chain_of
        return collect(Pipeline, p.args[1])
    else
        return Pipeline[p]
    end
end

function rewrite_all(p::Pipeline; memo=RewriteMemo())::Pipeline
    rewrite_common(rewrite_simplify(p, memo=memo), memo=memo)
end

@inline function rewrite_with(f, memo, p)
    args = collect(Any, f.(Ref(memo), p.args))
    memo(Pipeline(p.op, args=args))
end


#
# Local simplification.
#

function rewrite_simplify(p::Pipeline; memo=RewriteMemo())::Pipeline
    rewrite_simplify(memo, p) |> designate(p.sig)
end

function rewrite_simplify(memo::RewriteMemo, p::Pipeline)
    @match_pipeline if (p ~ chain_of(_))
        chain = Pipeline[]
        simplify_and_push!(memo, chain, p)
        return memo(chain)
    end
    p′ = rewrite_with(rewrite_simplify, memo, p)
    # with_column(N, pass()) => pass()
    @match_pipeline if (p′ ~ with_column(_, pass()))
        p′ =  memo(pass())
    # with_elements(pass()) => pass()
    elseif (p′ ~ with_elements(pass()))
        p′ = memo(pass())
    end
    p′
end

rewrite_simplify(memo::RewriteMemo, ps::Vector{Pipeline}) =
    rewrite_simplify.(Ref(memo), ps)

rewrite_simplify(memo::RewriteMemo, other) = other

function simplify_and_push!(memo::RewriteMemo, chain::Vector{Pipeline}, p::Pipeline)
    top = !isempty(chain) ? chain[end] : memo(pass())
    @match_pipeline if (p ~ pass())
    elseif (p ~ chain_of(qs))
        for q in qs
            if (q ~ chain_of(_))
                simplify_and_push!(memo, chain, q)
            else
                simplify_and_push!(memo, chain, rewrite_simplify(memo, q))
            end
        end
    elseif (p ~ tuple_of(lbls, cols))
        head = nothing
        for col in cols
            if (col ~ chain_of([q, _...]))
                col = q
            end
            if (col ~ filler(_)) || (col ~ block_filler(_, _)) || (col ~ null_filler())
            elseif (col ~ column(k)) && (head === nothing || head === col)
                head = col
            else
                head = missing
                break
            end
        end
        if head === missing
            push!(chain, p)
        elseif head === nothing
            empty!(chain)
            push!(chain, p)
        else
            cols′ = Pipeline[]
            for col in cols
                if col === head
                    col = memo(pass())
                elseif (col ~ chain_of([q, qs...]))
                    if q === head
                        col = memo(qs)
                    end
                end
                push!(cols′, col)
            end
            simplify_and_push!(memo, chain, head)
            simplify_and_push!(memo, chain, memo(tuple_of(lbls, cols′)))
        end
    # chain_of(p, filler(val)) => filler(val)
    elseif (p ~ filler(_)) || (p ~ block_filler(_, _)) || (p ~ null_filler())
        empty!(chain)
        push!(chain, p)
    # chain_of(tuple_of(p1, ..., pn), column(k)) => pk
    elseif (top ~ tuple_of(lbls, cols)) && (p ~ column(lbl))
        k = lbl isa Symbol ? findfirst(isequal(lbl), lbls) : lbl
        qs = unchain(cols[k])
        pop!(chain)
        for q in qs
            simplify_and_push!(memo, chain, q)
        end
    # chain_of(tuple_of(..., pk, ...), with_column(k, q)) => tuple_of(..., chain_of(pk, q), ...)
    elseif (top ~ tuple_of(lbls, cols)) && (p ~ with_column(lbl, q))
        k = lbl isa Symbol ? findfirst(isequal(lbl), lbls) : lbl
        pop!(chain)
        qs = unchain(cols[k])
        simplify_and_push!(memo, qs, q)
        cols′ = copy(cols)
        cols′[k] = memo(qs)
        simplify_and_push!(memo, chain, memo(tuple_of(lbls, cols′)))
    # chain_of(tuple_of(chain_of(p, wrap()), ...), tuple_lift(f)) => chain_of(tuple_of(p, ...), tuple_lift(f))
    elseif (top ~ tuple_of(lbls, cols)) && (p ~ tuple_lift(_))
        cols′ = Pipeline[]
        for col in cols
            qs = unchain(col)
            while (qs ~ [_..., wrap()])
                pop!(qs)
            end
            push!(cols′, memo(qs))
        end
        pop!(chain)
        push!(chain, memo(tuple_of(lbls, cols′)))
        push!(chain, p)
    # chain_of(with_column(k, wrap()), distribute(k)) => wrap()
    elseif (top ~ with_column(j, wrap())) && (p ~ distribute(k)) && j == k
        pop!(chain)
        simplify_and_push!(memo, chain, memo(wrap()))
    # chain_of(with_column(k, chain_of(p, wrap())), distribute(k)) => chain_of(with_column(k, p), wrap())
    elseif (top ~ with_column(j, chain_of([qs..., wrap()]))) && (p ~ distribute(k)) && j == k
        pop!(chain)
        push!(chain, memo(with_column(k, memo(qs))))
        push!(chain, memo(wrap()))
    # chain_of(wrap(), flatten()) => pass()
    elseif (top ~ wrap()) && (p ~ flatten())
        pop!(chain)
    # chain_of(wrap(), with_elements(p)) => chain_of(p, wrap())
    elseif (top ~ wrap()) && (p ~ with_elements(q))
        pop!(chain)
        qs = unchain(q)
        for q in qs
            simplify_and_push!(memo, chain, q)
        end
        simplify_and_push!(memo, chain, top)
    # chain_of(wrap(), lift(f)) => lift(f)
    elseif (top ~ wrap()) && (p ~ lift(_))
        pop!(chain)
        simplify_and_push!(memo, chain, p)
    # chain_of(with_elements(p), with_elements(q)) => with_elements(chain_of(p, q))
    elseif (top ~ with_elements(q1)) && (p ~ with_elements(q2))
        pop!(chain)
        qs = unchain(q1)
        for q in unchain(q2)
            simplify_and_push!(memo, qs, q)
        end
        simplify_and_push!(memo, chain, memo(with_elements(memo(qs))))
    # chain_of(with_elements(wrap()), flatten()) => pass()
    elseif (top ~ with_elements(wrap())) && (p ~ flatten())
        pop!(chain)
    # chain_of(with_elements(chain_of(p, wrap())), flatten()) => with_elements(p)
    elseif (top ~ with_elements(chain_of([qs..., wrap()]))) && (p ~ flatten())
        pop!(chain)
        simplify_and_push!(memo, chain, memo(with_elements(memo(qs))))
    # chain_of(flatten(), with_elements(column(k))) => chain_of(with_elements(with_elements(column(k))), flatten())
    elseif (top ~ flatten()) && (p ~ with_elements(column(k)))
        pop!(chain)
        simplify_and_push!(memo, chain, memo(with_elements(p)))
        simplify_and_push!(memo, chain, top)
   # chain_of(flatten(), with_elements(chain_of(column(k), p))) => chain_of(with_elements(with_elements(column(k))), flatten(), with_elements(p))
    elseif (top ~ flatten()) && (p ~ with_elements(chain_of([column(k), qs...])))
        pop!(chain)
        simplify_and_push!(memo, chain, memo(with_elements(memo(with_elements(memo(column(k)))))))
        simplify_and_push!(memo, chain, top)
        simplify_and_push!(memo, chain, memo(with_elements(memo(qs))))
    # chain_of(distribute(k), with_elements(column(k))) => column(k)
    elseif (top ~ distribute(j)) && (p ~ with_elements(column(k))) && j == k
        pop!(chain)
        simplify_and_push!(memo, chain, memo(column(k)))
    # chain_of(distribute(k), with_elements(chain_of(column(k), p))) => chain_of(column(k), with_elements(p))
    elseif (top ~ distribute(j)) && (p ~ with_elements(chain_of([column(k), qs...]))) && j == k
        pop!(chain)
        simplify_and_push!(memo, chain, memo(column(k)))
        simplify_and_push!(memo, chain, memo(with_elements(memo(qs))))
    # chain_of(sieve_by(), with_elements(column(k))) => chain_of(with_column(1, column(k)), sieve_by())
    elseif (top ~ sieve_by()) && (p ~ with_elements(column(k)))
        pop!(chain)
        simplify_and_push!(memo, chain, memo(with_column(1, memo(column(k)))))
        simplify_and_push!(memo, chain, top)
    else
        push!(chain, p)
    end
    nothing
end


#
# Common subexpression elimination.
#

function rewrite_common(p::Pipeline; memo=RewriteMemo())::Pipeline
    rewrite_common(memo, p) |> designate(p.sig)
end

function rewrite_common(memo::RewriteMemo, p::Pipeline)
    @match_pipeline if (p ~ tuple_of(_, _))
        chain = Pipeline[]
        l, r = pull_common(memo, p)
        append!(chain, unchain(rewrite_common(memo, l)))
        push!(chain, rewrite_with(rewrite_common, memo, r))
        memo(chain)
    else
        rewrite_with(rewrite_common, memo, p)
    end
end

rewrite_common(memo::RewriteMemo, ps::Vector{Pipeline}) =
    rewrite_common.(Ref(memo), ps)

rewrite_common(memo::RewriteMemo, other) = other

function pull_common(memo::RewriteMemo, p::Pipeline)
    @match_pipeline if (p ~ tuple_of(lbls, cols)) && length(cols) > 1
        i = memo(pass())
        deps = Dict{Pipeline,Vector{Pipeline}}(i => Pipeline[], p => cols)
        seen = Set{Pipeline}()
        dups = Set{Pipeline}()
        for col in cols
            parts = Pipeline[i]
            collect_parts!(memo, parts, deps, i, col)
            for q in parts
                if q in seen
                    push!(dups, q)
                end
            end
            for q in parts
                push!(seen, q)
            end
        end
        if length(dups) > 1
            seen = Set{Pipeline}()
            basis = Pipeline[]
            stack = Pipeline[p]
            while !isempty(stack)
                q = pop!(stack)
                for dep in deps[q]
                    if !(dep in seen)
                        if dep in dups
                            push!(basis, dep)
                        else
                            push!(stack, dep)
                        end
                        push!(seen, dep)
                    end
                end
            end
            #=
            println("!"^50)
            println(p)
            println("-"^50)
            for q in basis
                println(q)
            end
            println("!"^50)
            =#
        end
        return (memo(pass()), p)
    else
        return (memo(pass()), p)
    end
end

function collect_parts!(memo, parts, deps, i, p)
    @match_pipeline if (p ~ pass())
        o = i
    elseif (p ~ chain_of(qs))
        o = i
        for q in qs
            o = collect_parts!(memo, parts, deps, o, q)
        end
    elseif (p ~ tuple_of(lbls, cols))
        os = Pipeline[]
        for col in cols
            push!(os, collect_parts!(memo, parts, deps, i, col))
        end
        chain = unchain(i)
        push!(chain, p)
        o = memo(chain)
        push!(parts, o)
        get!(deps, o, os)
    elseif (p ~ with_elements(q))
        q_i = memo(pass())
        q_parts = Pipeline[]
        collect_parts!(memo, q_parts, deps, q_i, q)
        o = i
        for r in q_parts
            chain = unchain(i)
            push!(chain, memo(with_elements(r)))
            o = memo(chain)
            push!(parts, o)
            get!(deps, o) do
                o_deps = Pipeline[]
                for dep in deps[r]
                    if dep != q_i
                        chain = unchain(i)
                        push!(chain, memo(with_elements(dep)))
                        push!(o_deps, memo(chain))
                    end
                end
                if isempty(o_deps)
                    push!(o_deps, i)
                end
                o_deps
            end
        end
    elseif (p ~ with_column(lbl, q))
        q_i = memo(pass())
        q_parts = Pipeline[]
        collect_parts!(memo, q_parts, deps, q_i, q)
        o = i
        for r in q_parts
            chain = unchain(i)
            push!(chain, memo(with_column(lbl, r)))
            o = memo(chain)
            push!(parts, o)
            get!(deps, o) do
                o_deps = Pipeline[]
                for dep in deps[r]
                    if dep != q_i
                        chain = unchain(i)
                        push!(chain, memo(with_column(lbl, dep)))
                        push!(o_deps, memo(chain))
                    end
                end
                if isempty(o_deps)
                    push!(o_deps, i)
                end
                o_deps
            end
        end
    else
        chain = unchain(i)
        push!(chain, p)
        o = memo(chain)
        push!(parts, o)
        if (p ~ filler(_)) || (p ~ block_filler(_, _)) || (p ~ null_filler())
            get!(deps, o, Pipeline[])
        else
            get!(deps, o, Pipeline[i])
        end
    end
    o
end

