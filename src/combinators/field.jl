#
# Attribute access.
#

field(name) =
    Combinator(field, name)

translate(::Type{Val{name}}) where {name} =
    field(name)

function field(env::Environment, q::Query, name)
    if any(slot.first == name for slot in env.slots)
        return recall(env, q, name)
    end
    r = lookup(domain(q), name)
    r !== missing || error("unknown attribute $name at\n$(domain(q))")
    compose(q, r)
end

function lookup(env::Environment, name)
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
end

lookup(::AbstractShape, ::Any) = missing

lookup(shp::DecoratedShape, name) =
    lookup(shp[], name)

function lookup(shp::RecordShape, name::Symbol)
    for fld in shp.flds
        lbl = decoration(fld, :tag, Symbol)
        if lbl == name
            return column(lbl) |> designate(InputShape(shp), fld)
        end
    end
    return missing
end

