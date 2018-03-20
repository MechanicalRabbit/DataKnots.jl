#
# Simplify composition.
#

function simplify(q::Query)
    qs = simplify_chain(q)
    if isempty(qs)
        return pass()
    elseif length(qs) == 1
        return qs[1]
    else
        return chain_of(qs)
    end
end

simplify(qs::Vector{Query}) =
    simplify.(qs)

simplify(other) = other

function simplify_chain(q::Query)
    if q.op == pass
        return Query[]
    elseif q.op == chain_of
        return simplify_block(vcat(simplify_chain.(q.args[1])...))
    else
        return [Query(q.op, simplify.(q.args)...)]
    end
end

function simplify_block(qs)
    while true
        if !any(qs[k].op == as_block && qs[k+1].op == in_block && qs[k+2].op == flat_block
                for k = 1:length(qs)-2)
            return qs
        end
        qs′ = Query[]
        k = 1
        while k <= length(qs)
            if k <= length(qs)-2 && qs[k].op == as_block && qs[k+1].op == in_block && qs[k+2].op == flat_block
                push!(qs′, qs[k+1].args[1])
                k += 3
            else
                push!(qs′, qs[k])
                k += 1
            end
        end
        qs = qs′
    end
end

