#
# Applying a combinator to a query.
#

const SomeCombinator = Union{DataKnot, Combinator, Navigation}

mutable struct Environment
    slots::Vector{Pair{Symbol,OutputShape}}
end

combine(knot::DataKnot, env::Environment, q::Query) =
    compose(
        q,
        lift_block(elements(knot)) |> designate(InputShape(AnyShape()), shape(knot)))


combine(F::Combinator, env::Environment, q::Query) =
    F.op(env, q, F.args...)

function combine(nav::Navigation, env::Environment, q::Query)
    for fld in getfield(nav, :_path)
        q = combine(field(fld), env, q)
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

