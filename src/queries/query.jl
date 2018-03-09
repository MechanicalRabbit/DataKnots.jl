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
    sig::Signature
    src::Any

end

let NO_SIG = Signature()

    global Query

    Query(op, args...) =
        Query(op, collect(Any, args), NO_SIG, nothing)
end

sign(q::Query, sig::Signature) =
    Query(q.op, q.args, sig, q.src)

sign(q::Query, ishp::InputShape, shp::OutputShape) =
    Query(q.op, q.args, Signature(ishp, shp), q.src)

sign(sig::Signature) =
    q::Query -> sign(q, sig)

sign(ishp::InputShape, shp::OutputShape) =
    q::Query -> sign(q, Signature(ishp, shp))

signature(q::Query) = q.sig

shape(q::Query) = shape(q.sig)

ishape(q::Query) = ishape(q.sig)

domain(q::Query) = domain(q.sig)

idomain(q::Query) = idomain(q.sig)

mode(q::Query) = mode(q.sig)

imode(q::Query) = imode(q.sig)

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

