#
# Extracting parameters.
#

Recall(name::Symbol) =
    Combinator(Recall, name)

function Recall(env::Environment, q::Query, name)
    for slot in env.slots
        if slot.first == name
            shp = slot.second
            ishp = InputShape(domain(q), [slot])
            r = chain_of(
                    column(2),
                    column(1)
            ) |> designate(ishp, shp)
            return compose(q, r)
        end
    end
    error("undefined parameter: $name")
end

