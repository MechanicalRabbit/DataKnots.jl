#
# Optimizing pipelines.
#

function unchain(p)
    if p.op == pass()
        return Pipeline[]
    elseif p.op == chain_of
        return collect(Pipeline, p.args[1])
    else
        return Pipeline[p]
    end
end

function rechain(ps)
    if isempty(ps)
        return pass()
    elseif length(ps) == 1
        return ps[1]
    else
        return chain_of(ps)
    end
end

rewrite_all(p::Pipeline)::Pipeline =
    p |> rewrite_simplify


#
# Local simplification.
#

function rewrite_simplify(p::Pipeline)::Pipeline
    simplify(p) |> designate(p.sig)
end

function simplify(p::Pipeline)
    if p.op == chain_of
        chain = Pipeline[]
        simplify_and_push!(chain, p)
        return rechain(chain)
    end
    args = collect(Any, simplify.(p.args))
    # with_column(N, pass()) => pass()
    if p.op == with_column && args[2].op == pass
        return pass()
    end
    # with_elements(pass()) => pass()
    if p.op == with_elements && args[1].op == pass
        return pass()
    end
    Pipeline(p.op, args=args)
end

simplify(p::Vector{Pipeline}) =
    simplify.(p)

simplify(other) = other

function simplify_and_push!(chain::Vector{Pipeline}, p::Pipeline)
    if p.op == pass
    elseif p.op == chain_of
        for q in p.args[1]
            if q.op == chain_of
                simplify_and_push!(chain, q)
            else
                simplify_and_push!(chain, simplify(q))
            end
        end
    # chain_of(wrap(), with_elements(p)) => chain_of(p, wrap())
    elseif p.op == with_elements && length(chain) >= 1 && chain[end].op == wrap
        pop!(chain)
        simplify_and_push!(chain, p.args[1])
        simplify_and_push!(chain, wrap())
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
                push!(chain, with_elements(rechain(qs)))
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
            push!(cols′, rechain(qs))
        end
        pop!(chain)
        push!(chain, tuple_of(lbls, cols′))
        push!(chain, p)
    # chain_of(with_column(k, chain_of(p, wrap())), distribute(k)) => chain_of(with_column(k, p), wrap())
    elseif p.op == distribute && length(chain) >= 1 && chain[end].op == with_column && p.args[1] == chain[end].args[1]
        k = p.args[1]
        qs = unchain(chain[end].args[2])
        if length(qs) >= 1 && qs[end].op == wrap
            pop!(chain)
            pop!(qs)
            if !isempty(qs)
                push!(chain, with_column(k, rechain(qs)))
            end
            push!(chain, wrap())
        else
            push!(chain, p)
        end
    # chain_of(tuple_of(p1, ..., pn), column(k)) => pk
    elseif p.op == column && p.args[1] isa Number && length(chain) >= 1 && chain[end].op == tuple_of
        k = p.args[1]
        qs = unchain(chain[end].args[2][k])
        pop!(chain)
        for q in qs
            simplify_and_push!(chain, q)
        end
    else
        push!(chain, p)
    end
    nothing
end

