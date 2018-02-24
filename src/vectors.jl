#
# Vector types for planar (aka column-oriented or SoA) storage.
#

module Planar

export
    @Planar,
    BlockCursor,
    BlockVector,
    CapsuleVector,
    IndexVector,
    SomeBlockVector,
    SomeIndexVector,
    SomeTupleVector,
    TupleVector,
    column,
    columns,
    cursor,
    decapsulate,
    dereference,
    elements,
    encapsulate,
    identifier,
    indexes,
    isclosed,
    labels,
    locate,
    move!,
    next!,
    offsets,
    partition,
    recapsulate,
    width

import Base:
    IndexStyle,
    OneTo,
    done,
    getindex,
    next,
    setindex!,
    show,
    size,
    start,
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
