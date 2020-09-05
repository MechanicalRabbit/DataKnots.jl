function rewrite_all(p::Pipeline)::Pipeline
    return delinearize!(simplify(linearize(p))) |> designate(signature(p))
end

function simplify(vp::Vector{Pipeline})::Vector{Pipeline}
    return vp
end

function linearize(p::Pipeline)::Vector{Pipeline}
    retval = Pipeline[]
    @match_pipeline if (p ~ pass())
        nothing
    elseif (p ~ chain_of(qs))
        for q in qs
            append!(retval, linearize(q))
        end
    elseif (p ~ with_elements(q))
        for r in linearize(q)
            push!(retval, with_elements(r))
        end
    elseif (p ~ with_column(lbl, q))
        for r in linearize(q)
            push!(retval, with_column(lbl, r))
        end
    elseif (p ~ tuple_of(lbls, cols::Vector{Pipeline}))
        push!(retval, tuple_of(lbls, length(cols)))
        for (idx, q) in enumerate(cols)
            for r in linearize(q)
                push!(retval, with_column(idx, r))
            end
        end
    else
        push!(retval, p)
    end
    return retval
end

function delinearize!(vp::Vector{Pipeline})::Pipeline
    chain = Vector{Pipeline}()
    while length(vp) > 0
        @match_pipeline if (vp[1] ~ with_elements(arg))
            push!(chain, delinearize_elements!(vp))
        elseif (vp[1] ~ tuple_of(lbls, width::Int))
            popfirst!(vp)
            push!(chain, delinearize_columns!(vp, lbls, width))
        else
            push!(chain, popfirst!(vp))
        end
    end
    return chain_of(chain...)
end

function delinearize_elements!(vp::Vector{Pipeline})::Pipeline
    chain = Vector{Pipeline}()
    while length(vp) > 0 && vp[1].op == with_elements
        push!(chain, popfirst!(vp).args[1])
    end
    return with_elements(delinearize!(chain))
end

function delinearize_columns!(vp::Vector{Pipeline}, lbls, width)::Pipeline
    slots = [Pipeline[] for x in 1:width]
    while length(vp) > 0 && vp[1].op == with_column
        idx = vp[1].args[1]
        if !isa(idx, Int)
            idx = findfirst(==(idx), lbls)
            if isnothing(idx)
                # found a column that depends upon the shape of the
                # input; stop delinearizing
                break
            end
        end
        push!(slots[idx], popfirst!(vp).args[2])
    end
    return tuple_of(lbls, [delinearize!(cv) for cv in slots])
end
