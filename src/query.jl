#
# Query definition.
#

struct Query
    op::AbstractOperation
    args::Vector{Query}
    isig::InputSignature
    osig::OutputSignature
end

operation(q::Query) = q.op

arguments(q::Query) = q.args

isignature(q::Query) = q.isig

idomain(q::Query) = domain(q.isig)

imode(q::Query) = mode(q.isig)

signature(q::Query) = q.osig

domain(q::Query) = domain(q.osig)

mode(q::Query) = mode(q.osig)

execute(q::Query) =
    let input = [Void],
        output = apply(q, input)
        output[1]
    end

apply(q::Query, input::AbstractVector) =
    apply(q.op, q.args, q.isig, q.osig, input)

apply(op::AbstractPrimitive, args::Vector{Query}, isig::InputSignature, osig::OutputSignature, input::AbstractVector) =
    apply(op, isig, osig, input)

