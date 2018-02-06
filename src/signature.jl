#
# Structure of query input and query output.
#

# Output structure.

struct OutputShape <: DataKnots.AbstractShape
    card::Cardinality
end

OutputShape() = OutputShape(REG)

cardinality(shp::OutputShape) = shp.card

OutputDomain(dom) =
    Domain(OutputShape(), Domain[convert(Domain, dom)])

OutputDomain(card::Cardinality, dom) =
    Domain(OutputShape(card), Domain[convert(Domain, dom)])

OutputDomain(shp::OutputShape, dom) =
    Domain(shp, Domain[convert(Domain, dom)])

Layouts.layout(shp::OutputShape, args::Vector{Domain}) =
    if shp.card == REG
        Layouts.layout([Layouts.layout(args[1])], brk=("OutputDomain(",")"))
    else
        Layouts.layout([Layouts.literal(repr(shp.card)), Layouts.layout(args[1])], brk=("OutputDomain(",")"))
    end

# Input structure.

struct InputShape <: DataKnots.AbstractShape
    slots::Vector{Pair{Symbol,Domain}}
    rel::Bool
end

let NO_SLOTS = Pair{Symbol,Domain}[]
    InputShape() = InputShape(NO_SLOTS, false)
end

InputDomain(dom) =
    Domain(InputShape(), Domain[convert(Domain, dom)])

InputDomain(shp::InputShape, dom) =
    Domain(shp, Domain[convert(Domain, dom)])

Layouts.layout(shp::InputShape, args::Vector{Domain}) =
    Layouts.layout([Layouts.layout(args[1])], brk=("InputDomain(",")"))

# Subdomain relation.

fits(shp1::OutputShape, shp2::OutputShape) =
    fits(shp1.card, shp2.card)

fits(shp1::InputShape, shp2::InputShape) =
    fits(shp1.slots, shp2.slots) && shp1.rel >= shp2.rel

# Upper bound.

bound(shp1::OutputShape, shp2::OutputShape) =
    OutputShape(shp1.card | shp2.card)

function bound(shp1::InputShape, shp2::InputShape)
    if shp1 == shp2
        return shp1
    end
    slots = Pair{Symbol,Domain}[]
    i = 1
    j = 1
    while i <= length(shp1.slots) && j <= length(shp2.slots)
        if shp1.slots[i].first < shp2.slots[j].first
            i += 1
        elseif shp1.slots[i].first > shp2.slots[j].first
            j += 1
        else
            push!(refs, Pair{Symbol,Domain}(shp1.slots[i].first,
                                            bound(shp1.slots[i].second, shp2.slots[j].second)))
        end
    end
    OutputShape(slots, shp1.rel && shp2.rel)
end

# Lower bound.

ibound(shp1::OutputShape, shp2::OutputShape) =
    OutputShape(shp1.card & shp2.card)

function ibound(shp1::InputShape, shp2::InputShape)
    if shp1 == shp2
        return shp1
    end
    OutputShape(merge(ibound, shp1.slots, shp2.slots), shp1.rel || shp2.rel)
end

# Data conversion.

let NO_REFS = Pair{Symbol,AbstractVector}[]

    global convert

    convert(::Type{DataKnot}, knot::DataKnot) =
        knot

    convert(::Type{DataKnot}, vals::Vector{T}) where {T} =
        DataKnot(1, SliceVector([1, length(vals)+1], vals), OutputDomain(OPT|PLU, Domain(T)), NO_REFS)

    convert(::Type{DataKnot}, data::T) where {T} =
        DataKnot(1, SliceVector(T[data]), OutputDomain(REG, Domain(T)), NO_REFS)
end

