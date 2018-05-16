#
# Vector types for columnar/SoA storage.
#

module Vectors

export
    @VectorTree,
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
    ordering,
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

using Base.Cartesian

include("wrapper.jl")
include("ordering.jl")
include("tuple.jl")
include("block.jl")
include("index.jl")
include("capsule.jl")
include("chunk.jl")
include("show.jl")
include("vectortree.jl")

end
