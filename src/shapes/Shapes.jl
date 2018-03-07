#
# Type system.
#

module Shapes

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
    FieldShape,
    IndexShape,
    InputShape,
    NativeShape,
    NoneShape,
    OutputShape,
    RecordShape,
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
import ..Layouts: syntax

include("sorteddict.jl")
include("bound.jl")
include("cardinality.jl")
include("shape.jl")

end
