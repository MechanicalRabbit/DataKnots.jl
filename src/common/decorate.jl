#
# Setting domain decorations.
#


struct DecoratePrim <: AbstractPrimitive
    decors::Vector{Pair{Symbol,Any}}
end

ThenDecorate(decors::Vector{Pair{Symbol,Any}}) =
    Combinator(DecoratePrim(decors))

ThenDecorate(decors::Pair{Symbol}...) =
    ThenDecorate(sort(collect(Pair{Symbol,Any}, decors), by=(pair -> pair.first)))

Layouts.layout(op::DecoratePrim) =
    Layouts.layout(map(Layouts.layout, op.decors), brk=("ThenDecorate(",")"))

function Query(op::DecoratePrim, dom::Domain)
    isig = InputDomain(dom)
    osig = OutputDomain(decorate(dom, op.decors))
    Query(op, isig, osig)
end

function execute(op::DecoratePrim, input::KnotVector)
    KnotVector(SliceVector(input.vals), OutputDomain(decorate(input.dom[], op.decors)), input.refs)
end

convert(::Type{Combinator}, pair::Pair{Symbol,Combinator}) =
    pair.second >> ThenDecorate(:tag => pair.first)

