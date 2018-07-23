#
# Applying a combinator to a query.
#

struct DataValue{T}
    val::T
end

show(io::IO, data::DataValue) = show(io, data.val)

const SomeCombinator = Union{DataKnot, DataValue, Combinator, Navigation}

convert(::Type{SomeCombinator}, val::Union{Integer,String}) =
    DataValue(val)

convert(::Type{SomeCombinator}, val::Base.RefValue) =
    DataValue(val.x)

mutable struct Environment
    slots::Vector{Pair{Symbol,OutputShape}}
end

combine(knot::DataKnot, env::Environment, q::Query) =
    compose(
        q,
        lift_block(elements(knot)) |> designate(InputShape(AnyShape()), shape(knot)))

combine(data::DataValue, env::Environment, q::Query) =
    combine(convert(DataKnot, data.val), env, q)

combine(F::Combinator, env::Environment, q::Query) =
    F.op(env, q, F.args...)

function combine(nav::Navigation, env::Environment, q::Query)
    for fld in getfield(nav, :_path)
        q = combine(Field(fld), env, q)
    end
    q
end

stub(shp::AbstractShape) =
    as_block() |> designate(InputShape(shp), OutputShape(shp))

stub() = stub(NativeShape(Nothing))

stub(q::Query) =
    stub(shape(q)[])

istub(q::Query) =
    stub(ishape(q)[])

