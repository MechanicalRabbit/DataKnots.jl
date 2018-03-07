#
# Vector types for parallel (aka column-oriented or SoA) storage.
#

module Vectors

export
    @Parallel,
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

include("wrapper.jl")
include("tuple.jl")
include("block.jl")
include("index.jl")
include("capsule.jl")
include("chunk.jl")
include("show.jl")
include("parallel.jl")

end
