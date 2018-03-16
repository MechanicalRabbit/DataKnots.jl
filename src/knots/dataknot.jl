#
# Type definition.
#

struct DataKnot
    shp::OutputShape
    elts::AbstractVector
end

DataKnot(elts) = convert(DataKnot, elts)

convert(::Type{DataKnot}, knot::DataKnot) = knot

convert(::Type{DataKnot}, elts::AbstractVector) =
    DataKnot(
        OutputShape(guessshape(elts),
                    (length(elts) < 1 ? OPT : REG) | (length(elts) > 1 ? PLU : REG)),
        elts)

convert(::Type{DataKnot}, elt::T) where {T} =
    DataKnot(OutputShape(NativeShape(T)), T[elt])

convert(::Type{DataKnot}, ::Missing) =
    DataKnot(OutputShape(NoneShape(), OPT), Union{}[])

elements(knot::DataKnot) = knot.elts

syntax(knot::DataKnot) =
    Symbol("DataKnot( … )")

get(knot::DataKnot) =
    let card = cardinality(knot.shp)
        card == REG || card == OPT && !isempty(knot.elts) ? knot.elts[1] :
        card == OPT ? missing : knot.elts
    end

shape(knot::DataKnot) = knot.shp

signature(knot::DataKnot) = Signature(knot.shp)

domain(knot::DataKnot) = domain(knot.shp)

mode(knot::DataKnot) = mode(knot.shp)

cardinality(knot::DataKnot) = cardinality(knot.shp)

