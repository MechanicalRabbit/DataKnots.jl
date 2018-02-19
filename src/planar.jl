#
# Vector types for planar (aka column-oriented or SoA) storage.
#

module Planar

export
    @Planar,
    BlockVector,
    CapsuleVector,
    IndexVector,
    SomeBlockVector,
    SomeIndexVector,
    SomeTupleVector,
    TupleVector,
    column,
    columns,
    decapsulate,
    dereference,
    elements,
    encapsulate,
    identifier,
    indexes,
    isclosed,
    labels,
    offsets,
    partition,
    recapsulate,
    width

import Base:
    IndexStyle,
    OneTo,
    getindex,
    size,
    show,
    summary

include("planar/wrapper.jl")
include("planar/tuple.jl")
include("planar/block.jl")
include("planar/index.jl")
include("planar/capsule.jl")
include("planar/chunk.jl")
include("planar/show.jl")
include("planar/construct.jl")

end
