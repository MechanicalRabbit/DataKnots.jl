function rewrite_all(p::Pipeline)::Pipeline
    #return delinearize!(simplify(linearize(p))) |> designate(signature(p))
    return chain_of(linearize(p)...) |> designate(signature(p))
end

function simplify(vp::Vector{Pipeline})::Vector{Pipeline}
    return vp
end

function linearize(p::Pipeline, path::Vector{Int}=Int[])::Vector{Pipeline}
    retval = Pipeline[]
    @match_pipeline if (p ~ pass())
        nothing
    elseif (p ~ chain_of(qs))
        for q in qs
            append!(retval, linearize(q, path))
        end
    elseif (p ~ with_elements(q))
        for r in linearize(q, push!(copy(path), 0) )
            push!(retval, r)
        end
    elseif (p ~ with_column(lbl::Int, q))
        for r in linearize(q, push!(copy(path), lbl))
            push!(retval, r)
        end
    elseif (p ~ tuple_of(lbls, cols::Vector{Pipeline}))
        push!(retval, with_nested(path, tuple_of(lbls, length(cols))))
        for (idx, q) in enumerate(cols)
            for r in linearize(q, push!(copy(path), idx))
                push!(retval, r)
            end
        end
    else
        push!(retval, with_nested(path, p))
    end
    return retval
end

function delinearize!(vp::Vector{Pipeline})::Pipeline
    chain = Pipeline[]
    while length(vp) > 0
        @match_pipeline if (vp[1] ~ with_elements(arg))
            push!(chain, delinearize_block!(vp))
        elseif (vp[1] ~ with_nested(path, p))
           #for idx in reverse(path)
           #    if idx == 0
           #        p = with_elements(p)
           #    else
           #        p = with_column(idx, p)
           #    end
           #end
            push!(chain, popfirst!(vp))
        elseif (vp[1] ~ tuple_of(lbls, width::Int))
            push!(chain, delinearize_tuple!(vp, lbls, width))
        else
            push!(chain, popfirst!(vp))
        end
    end
    return chain_of(chain...)
end

function delinearize_block!(vp::Vector{Pipeline})::Pipeline
    chain = Vector{Pipeline}()
    @match_pipeline while (vp ~ [with_elements(p), _...])
        popfirst!(vp)
        push!(chain, p)
    end
    return with_elements(delinearize!(chain))
end

function delinearize_tuple!(vp::Vector{Pipeline}, lbls, width)::Pipeline
    popfirst!(vp) # drop the `tuple_of`
    slots = [Pipeline[] for x in 1:width]
    @match_pipeline while (vp ~ [with_column(idx, p), _...])
        popfirst!(vp)
        if !isa(idx, Int)
            idx = findfirst(==(idx), lbls)
            @assert !isnothing(idx)
        end
        push!(slots[idx], p)
    end
    return tuple_of(lbls, [delinearize!(cv) for cv in slots])
end
