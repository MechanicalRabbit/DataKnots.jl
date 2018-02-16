#
# Encapsulation of self-referential data.
#

module Knots

export
    OPT,
    PLU,
    REG,
    AbstractShape,
    AnyShape,
    BlockShape,
    CapsuleShape,
    Cardinality,
    DecoratedShape,
    IndexShape,
    InputShape,
    NativeShape,
    NoneShape,
    OutputShape,
    TupleShape,
    bound,
    cardinality,
    class,
    decorate,
    decoration,
    denominalize,
    fits,
    ibound,
    isclosed,
    isoptional,
    isplural,
    isregular,
    syntax,
    undecorate

import Base:
    IndexStyle,
    OneTo,
    convert,
    getindex,
    eltype,
    size,
    show,
    summary,
    &, |, ~

using ..Layouts

include("knots/sorteddict.jl")
include("knots/bound.jl")
include("knots/cardinality.jl")
include("knots/shape.jl")

end
