#
# Identity and composition combinators.
#

struct ItOp <: AbstractPrimitive
end

const It = Combinator(ItOp(), [])

Layouts.layout(::ItOp) = Layouts.literal("It")

combine(env::Environment, q::Query, op::ItOp) =
    q

execute(::ItOp, input::KnotVector) =
    box(input)

struct ComposeOp <: AbstractOperation
end

function >>(q::Query, r::Query)
    @assert fits(q, r) "fits($q : $(domain(q)), $r : $(idomain(r)))"
    return Query(
            ComposeOp(),
            [q, r],
            InputDomain(ibound(ishape(q), ishape(r)), idomain(q)[]),
            OutputDomain(bound(shape(q), shape(r)), domain(r)[]))
end

>>(X::Combinator, Y::Combinator) =
    Combinator(ComposeOp(), [X, Y])

>>(X, Y::Combinator) =
    convert(Combinator, X) >> Y

Layouts.layout(::ComposeOp, args::Vector{Layouts.Layout}) =
    Layouts.layout(args, sep=(" >> ",">> ",""))

function combine(env::Environment, q::Query, op::ComposeOp, args::Vector{Combinator})
    for arg in args
        q = combine(env, q, arg)
    end
    q
end

function execute(::ComposeOp, args::Vector{Query}, input::KnotVector)
    output = box(input)
    first = true
    for arg in args
        idom = idomain(arg)
        input′ =
            if first
                narrow(idom, input)
            else
                distribute(idom, narrow(idom, input), output)
            end
        output′ = execute(arg, input′)
        output =
            if first
                output′
            else
                compact(output, output′)
            end
        first = false
    end
    return output
end

function narrow(::Domain, input::KnotVector)
    input
end

function distribute(::Domain, input::KnotVector, output::KnotVector)
    KnotVector(items(output.vals), InputDomain(output.dom[]), output.refs)
end

function box(input::KnotVector)
    KnotVector(SliceVector(input.vals), OutputDomain(input.dom[]), input.refs)
end

function compact(output1::KnotVector, output2::KnotVector)
    KnotVector(
        SliceVector(
            compose_map(offsets(output1.vals), offsets(output2.vals)),
            items(output2.vals)),
        OutputDomain(cardinality(output1.dom) | cardinality(output2.dom), argument(output2.dom)),
        output2.refs)
end

compose_map(offs1::AbstractVector{Int}, offs2::AbstractVector{Int}) =
    Int[offs2[off] for off in offs1]

compose_map(offs1::OneTo, offs2::OneTo) = offs1

compose_map(offs1::OneTo, offs2::AbstractVector{Int}) = offs2

compose_map(offs1::AbstractVector{Int}, offs2::OneTo) = offs1

