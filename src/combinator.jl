#
# Combinator type.
#


struct Combinator
    op::AbstractOperation
    args::Vector{Combinator}
end

let NO_ARGS = Combinator[]

    Combinator(op::AbstractPrimitive) =
        Combinator(op, NO_ARGS)
end

show(io::IO, F::Combinator) =
    Layouts.render_single_layout(io, F)

show(io::IO, ::MIME"text/plain", F::Combinator) =
    Layouts.render_best_layout(io, F)

Layouts.layout(F::Combinator) =
    Layouts.layout(F.op, F.args)

Layouts.layout(op::AbstractOperation, args::Vector{Combinator}) =
    Layouts.layout(op, Layouts.Layout[Layouts.layout(arg) for arg in args])

Layouts.layout(op::AbstractPrimitive, ::Vector{Combinator}) =
    Layouts.layout(op)

Layouts.layout(op::AbstractOperation, args::Vector{Layouts.Layout}) =
    Layouts.layout(Layouts.Layout[Layouts.literal(repr(op)), args...], brk=("Combinator(",")"))

type Environment
    slots::Vector{Pair{Symbol,Domain}}
end

Environment() = Environment([])

combine(F::Combinator; slots...) =
    combine(F, Domain(Void), sort(collect(Pair{Symbol,Domain}, slots), by=(slot -> slot.first)))

combine(F::Combinator, idom; slots...) =
    combine(F, convert(Domain, idom), sort(collect(Pair{Symbol,Domain}, slots), by=(slot -> slot.first)))

combine(F::Combinator, idom::Domain, slots::Vector{Pair{Symbol,Domain}}) =
    combine(Environment(slots), stub(idom), F)

combine(env::Environment, q::Query, F::Combinator) =
    combine(env, q, F.op, F.args)

combine(env::Environment, q::Query, op::AbstractPrimitive, ::Vector{Combinator}) =
    combine(env, q, op)

@inline combine(env::Environment, q::Query, op::AbstractPrimitive) =
    q >> Query(op, domain(q)[])

execute(F::Combinator; params...) =
    execute(F, sort(collect(Pair{Symbol,DataKnot}, params), by=(param -> param.first)))

execute(F::Combinator, data; params...) =
    execute(F, convert(DataKnot, data), sort(collect(Pair{Symbol,DataKnot}, params), by=(param -> param.first)))

execute(F::Combinator, data::DataKnot, params::Vector{Pair{Symbol,DataKnot}}) =
    execute(Data(data) >> F, params)

function execute(F::Combinator, params::Vector{Pair{Symbol,DataKnot}})
    slots = Pair{Symbol,Domain}[param.first => domain(param.second) for param in params]
    q = combine(F, Domain(Void), slots)
    input = pack(ishape(q), params)
    output = execute(q, input)
    return unpack(output)
end

function pack(shp::InputShape, params::Vector{Pair{Symbol,DataKnot}})
    KnotVector([nothing], InputDomain(Void))
end

function unpack(output::KnotVector)
    @assert length(output) == 1
    output[1]
end

