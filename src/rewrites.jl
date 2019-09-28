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
    if p.op == pass()
        return Pipeline[]
    elseif p.op == chain_of
        return collect(Pipeline, p.args[1])
    else
        return Pipeline[p]
    end
end

function rewrite_all(p::Pipeline; memo=RewriteMemo())::Pipeline
    rewrite_simplify(p, memo=memo)
end


#
# Local simplification.
#

function rewrite_simplify(p::Pipeline; memo=RewriteMemo())::Pipeline
    rewrite_simplify(memo, p) |> designate(p.sig)
end

function rewrite_simplify(memo::RewriteMemo, p::Pipeline)
    if p.op == chain_of
        chain = Pipeline[]
        simplify_and_push!(memo, chain, p)
        return memo(chain)
    end
    args = collect(Any, rewrite_simplify.(Ref(memo), p.args))
    # with_column(N, pass()) => pass()
    if p.op == with_column && args[2].op == pass
        return memo(pass())
    end
    # with_elements(pass()) => pass()
    if p.op == with_elements && args[1].op == pass
        return memo(pass())
    end
    memo(Pipeline(p.op, args=args))
end

rewrite_simplify(memo::RewriteMemo, p::Vector{Pipeline}) =
    rewrite_simplify.(Ref(memo), p)

rewrite_simplify(memo::RewriteMemo, other) = other

function simplify_and_push!(memo::RewriteMemo, chain::Vector{Pipeline}, p::Pipeline)
    if p.op == pass
    elseif p.op == chain_of
        for q in p.args[1]
            if q.op == chain_of
                simplify_and_push!(memo, chain, q)
            else
                simplify_and_push!(memo, chain, rewrite_simplify(memo, q))
            end
        end
    # chain_of(wrap(), with_elements(p)) => chain_of(p, wrap())
    elseif p.op == with_elements && length(chain) >= 1 && chain[end].op == wrap
        pop!(chain)
        simplify_and_push!(memo, chain, p.args[1])
        simplify_and_push!(memo, chain, memo(wrap()))
    # chain_of(with_elements(p), with_elements(q)) => with_elements(chain_of(p, q))
    elseif p.op == with_elements && length(chain) >= 1 && chain[end].op == with_elements
        qs = unchain(chain[end].args[1])
        pop!(chain)
        for q in unchain(p.args[1])
            simplify_and_push!(memo, qs, q)
        end
        push!(chain, memo(with_elements(memo(qs))))
    # chain_of(wrap(), flatten()) => pass()
    elseif p.op == flatten && length(chain) >= 1 && chain[end].op == wrap
        pop!(chain)
    # chain_of(with_elements(chain_of(p, wrap())), flatten()) => with_elements(p)
    elseif p.op == flatten && length(chain) >= 1 && chain[end].op == with_elements
        qs = unchain(chain[end].args[1])
        if length(qs) >= 1 && qs[end].op == wrap
            pop!(chain)
            pop!(qs)
            if !isempty(qs)
                push!(chain, memo(with_elements(memo(qs))))
            end
        else
            push!(chain, p)
        end
    # chain_of(wrap(), lift(f)) => lift(f)
    elseif p.op == lift
        while length(chain) >= 1 && chain[end].op == wrap
            pop!(chain)
        end
        push!(chain, p)
    # chain_of(tuple_of(chain_of(p, wrap()), ...), tuple_lift(f)) => chain_of(tuple_of(p, ...), tuple_lift(f))
    elseif p.op == tuple_lift && length(chain) >= 1 && chain[end].op == tuple_of
        lbls, cols = chain[end].args
        cols′ = Pipeline[]
        for col in cols
            qs = unchain(col)
            while length(qs) >= 1 && qs[end].op == wrap
                pop!(qs)
            end
            push!(cols′, memo(qs))
        end
        pop!(chain)
        push!(chain, memo(tuple_of(lbls, cols′)))
        push!(chain, p)
    # chain_of(with_column(k, chain_of(p, wrap())), distribute(k)) => chain_of(with_column(k, p), wrap())
    elseif p.op == distribute && length(chain) >= 1 && chain[end].op == with_column && p.args[1] == chain[end].args[1]
        k = p.args[1]
        qs = unchain(chain[end].args[2])
        if length(qs) >= 1 && qs[end].op == wrap
            pop!(chain)
            pop!(qs)
            if !isempty(qs)
                push!(chain, memo(with_column(k, memo(qs))))
            end
            push!(chain, memo(wrap()))
        else
            push!(chain, p)
        end
    # chain_of(tuple_of(p1, ..., pn), column(k)) => pk
    elseif p.op == column && p.args[1] isa Number && length(chain) >= 1 && chain[end].op == tuple_of
        k = p.args[1]
        qs = unchain(chain[end].args[2][k])
        pop!(chain)
        for q in qs
            simplify_and_push!(memo, chain, q)
        end
    else
        push!(chain, p)
    end
    nothing
end

