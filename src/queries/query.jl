#
# Query interface.
#


"""
    Runtime

Runtime state for query evaluation.
"""
mutable struct Runtime
    refs::Vector{Pair{Symbol,AbstractVector}}
end


"""
    Query

A query represents a vector function that, given the runtime environment and
the input vector, produces an output vector of the same length.
"""
struct Query
    op
    args::Vector{Any}
    sig::Tuple{AbstractShape,AbstractShape}
    src::Any

end

Query(op, args...) =
    Query(op, collect(Any, args), (NoneShape(), AnyShape()), nothing)

sign(q::Query, sig::Tuple{AbstractShape,AbstractShape}) =
    Query(q.op, q.args, sig, q.src)

sign(ishp::AbstractShape, shp::AbstractShape) =
    q::Query -> designate(q, (ishp, shp))

shape(q::Query) = q.sig[2]

ishape(q::Query) = q.sig[1]

function (q::Query)(input::AbstractVector)
    input, refs = decapsulate(input)
    rt = Runtime(copy(refs))
    output = q(rt, input)
    encapsulate(output, rt.refs)
end

(q::Query)(rt::Runtime, input::AbstractVector) =
    q.op(rt, input, q.args...)

syntax(q::Query) =
    syntax(q.op, q.args)

show(io::IO, q::Query) =
    print_code(io, syntax(q))

