#
# The Data combinator.
#

struct DataPrim <: AbstractPrimitive
    knot::DataKnot
end

Data(val) =
    Combinator(DataPrim(convert(DataKnot, val)))

Layouts.layout(op::DataPrim) =
    Layouts.literal("Data($(op.knot))")

function combine(env::Environment, q::Query, op::DataPrim)
    @assert shape(op.knot) isa OutputShape
    q >> Query(op, InputDomain(Any), domain(op.knot))
end

function execute(op::DataPrim, input::KnotVector)
    output = KnotVector(op.knot.vals[fill(op.knot.idx, length(input))], op.knot.dom, op.knot.refs)
    output
end

