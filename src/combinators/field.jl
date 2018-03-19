#
# Attribute access.
#

field(name) =
    Combinator(field, name)

translate(::Type{Val{name}}) where {name} =
    field(name)

function field(env::Environment, q::Query, name)
    r = lookup(domain(q), name)
    r !== missing || error("unknown attribute $name at\n$(domain(q))")
    compose(q, r)
end

lookup(::AbstractShape, ::Any) = missing

lookup(shp::DecoratedShape, name) =
    lookup(undecorate(shp), name)

function lookup(shp::RecordShape, name::Symbol)
    for fld in shp.flds
        lbl = decoration(fld, :tag, Symbol)
        if lbl == name
            return column(lbl) |> designate(InputShape(shp), fld)
        end
    end
    return missing
end

