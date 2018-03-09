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
    IndexShape,
    InputMode,
    InputShape,
    NativeShape,
    NoneShape,
    OutputMode,
    OutputShape,
    RecordShape,
    Signature,
    TupleShape,
    bound,
    cardinality,
    class,
    decorate,
    decoration,
    denominalize,
    domain,
    fits,
    ibound,
    idomain,
    imode,
    isclosed,
    ishape,
    isoptional,
    isplural,
    isregular,
    mode,
    shape,
    signature,
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
include("signature.jl")

end
