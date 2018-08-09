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
    ordering_pair,
    partition,
    recapsulate,
    width

import Base:
    IndexStyle,
    OneTo,
    getindex,
    setindex!,
    show,
    size,
    summary

if VERSION < v"1.0-"
    import Base: done
else
    export done
end

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
