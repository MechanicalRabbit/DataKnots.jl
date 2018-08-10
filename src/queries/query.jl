#
# Query interface.
#


"""
    Runtime(refs)

Runtime state for query evaluation.
"""
mutable struct Runtime
    refs::Vector{Pair{Symbol,AbstractVector}}
end


"""
    Query(op, args...)

A query represents a vectorized data transformation.

Parameter `op` is a function that performs the transformation.
It is invoked with the following arguments:

    op(rt::Runtime, input::AbstractVector, args...)

It must return the output vector of the same length as the input vector.
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

"""
    designate(::Query, ::Signature) -> Query
    designate(::Query, ::InputShape, ::OutputShape) -> Query
    q::Query |> designate(::Signature) -> Query
    q::Query |> designate(::InputShape, ::OutputShape) -> Query

Sets the query signature.
"""
designate(q::Query, sig::Signature) =
    Query(q.op, q.args, sig, q.src)

designate(q::Query, ishp::InputShape, shp::OutputShape) =
    Query(q.op, q.args, Signature(ishp, shp), q.src)

designate(sig::Signature) =
    q::Query -> designate(q, sig)

designate(ishp::InputShape, shp::OutputShape) =
    q::Query -> designate(q, Signature(ishp, shp))

"""
    signature(::Query) -> Signature

Returns the query signature.
"""
signature(q::Query) = q.sig

shape(q::Query) = shape(q.sig)

ishape(q::Query) = ishape(q.sig)

domain(q::Query) = domain(q.sig)

idomain(q::Query) = idomain(q.sig)

mode(q::Query) = mode(q.sig)

imode(q::Query) = imode(q.sig)

cardinality(q::Query) = cardinality(q.sig)

isregular(q::Query) = isregular(q.sig)

isoptional(q::Query) = isoptional(q.sig)

isplural(q::Query) = isplural(q.sig)

isfree(q::Query) = isfree(q.sig)

isframed(q::Query) = isframed(q.sig)

slots(q::Query) = slots(q.sig)

function (q::Query)(input::AbstractVector)
    input, refs = decapsulate(input)
    rt = Runtime(copy(refs))
    output = q(rt, input)
    encapsulate(output, rt.refs)
end

function (q::Query)(rt::Runtime, input::AbstractVector)
    try
        q.op(rt, input, q.args...)
    catch err
        if err isa QueryError && err.q === nothing && err.input === nothing
            err = err |> setquery(q) |> setinput(encapsulate(input, rt.refs))
        end
        rethrow(err)
    end
end

syntax(q::Query) =
    syntax(q.op, q.args)

show(io::IO, q::Query) =
    print_code(io, syntax(q))

"""
    optimize(::Query)::Query

Rewrites the query to make it more effective.
"""
optimize(q::Query) =
    simplify(q) |> designate(q.sig)


"""
    QueryError(msg, ::Query, ::AbstractVector)

Exception thrown when a query gets unexpected input.
"""
struct QueryError <: Exception
    msg::String
    q::Union{Nothing,Query}
    input::Union{Nothing,AbstractVector}
end

QueryError(msg) = QueryError(msg, nothing, nothing)

setquery(q::Query) =
    err::QueryError -> QueryError(err.msg, q, err.input)

setinput(input::AbstractVector) =
    err::QueryError -> QueryError(err.msg, err.q, input)

function showerror(io::IO, err::QueryError)
    print(io, "$(nameof(QueryError)): $(err.msg)")
    if err.q !== nothing && err.input !== nothing
        println(io, " at:")
        println(io, err.q)
        println(io, "with input:")
        print(IOContext(io, :limit => true), err.input)
    end
end

macro ensure_fits(input, shp)
    return quote
        let (input, shp) = ($(esc(input)), $(esc(shp)))
            fits(input, shp) || throw(QueryError("expected input of shape $(sigsyntax(shp)); got $(sigsyntax(shapeof(input)))"))
        end
    end
end

