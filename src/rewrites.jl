function rewrite_all(p::Pipeline)::Pipeline
    return delinearize!(linearize(p)) |> designate(signature(p))
end

function simplify(vp::Vector{Pipeline})::Vector{Pipeline}
    return vp
end

function linearize(p::Pipeline, path::NestedPath=tuple())::Vector{Pipeline}
    retval = Pipeline[]
    @match_pipeline if (p ~ pass())
        nothing
    elseif (p ~ chain_of(qs))
        for q in qs
            append!(retval, linearize(q, path))
        end
    elseif (p ~ with_elements(q))
        append!(retval, linearize(q, (path..., 0)))
    elseif (p ~ with_column(lbl::Int, q))
        append!(retval, linearize(q, (path..., lbl)))
    elseif (p ~ tuple_of(lbls, cols::Vector{Pipeline}))
        push!(retval, with_nested(path, tuple_of(lbls, length(cols))))
        for (idx, q) in enumerate(cols)
            append!(retval, linearize(q, (path..., idx)))
        end
    else
        push!(retval, with_nested(path, p))
    end
    return retval
end

function delinearize!(vp::Vector{Pipeline}, base::NestedPath=tuple())::Pipeline
    depth = length(base)
    chain = Pipeline[]
    while length(vp) > 0
        @match_pipeline if (vp ~ [with_nested(path, p), _...])
            if path == base
                @match_pipeline if (p ~ tuple_of(lbls, width::Int))
                    push!(chain, delinearize_tuple!(vp, base, lbls, width))
                    continue
                end
                popfirst!(vp)
                push!(chain, p)
                continue
            end
            if base == path[1:length(base)]
                idx = path[depth+1]
                push!(chain, delinearize!(vp, base, idx))
                continue
            end
            break
        end
        push!(chain, popfirst!(vp))
    end
    return chain_of(chain...)
end

function delinearize!(vp::Vector{Pipeline}, base::NestedPath, idx::Int)::Pipeline
    base = (base..., idx)
    depth = length(base)
    chain = Pipeline[]
    @match_pipeline while (vp ~ [with_nested(path, p), _...])
        if length(path) >= depth && base == path[1:depth]
            push!(chain, popfirst!(vp))
            continue
        end
        break
    end
    if 0 == idx
        return with_elements(delinearize!(chain, base))
    end
    return with_column(idx, delinearize!(chain, base))
end

function delinearize_tuple!(vp::Vector{Pipeline}, base, lbls, width)::Pipeline
    popfirst!(vp) # drop the `tuple_of`
    depth = length(base)
    slots = [Pipeline[] for x in 1:width]
    @match_pipeline while (vp ~ [with_nested(path, p), _...])
        if base == path[1:depth]
            if length(path) > depth
                idx = path[depth+1]
                if idx > 0
                    push!(slots[idx], popfirst!(vp))
                    continue
                end
            elseif length(path) == depth
                if (p ~ with_column(idx, q))
                    popfirst!(vp)
                    if !isa(idx, Int)
                         idx = findfirst(==(idx), lbls)
                         @assert !isnothing(idx)
                    end
                    push!(slots[idx], q)
                    continue
                end
            end
        end
        break
    end
    return tuple_of(lbls, [delinearize!(cv, (base..., idx))
                              for (cv, idx) in zip(slots, 1:width)])
end
