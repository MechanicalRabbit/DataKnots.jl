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

include("vectors/wrapper.jl")
include("vectors/tuple.jl")
include("vectors/block.jl")
include("vectors/index.jl")
include("vectors/capsule.jl")
include("vectors/chunk.jl")
include("vectors/show.jl")
include("vectors/parallel.jl")

end
