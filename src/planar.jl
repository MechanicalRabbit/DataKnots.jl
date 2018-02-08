#
# Vector types for planar (aka column-oriented or SoA) storage.
#

module Planar

export
    BlockVector,
    IndexVector,
    TupleVector,
    column,
    columns,
    dereference,
    elements,
    identifier,
    indexes,
    isclosed,
    labels,
    offsets,
    partition,
    width

import Base:
    IndexStyle,
    OneTo,
    getindex,
    size,
    show,
    summary

include("planar/tuple.jl")
include("planar/block.jl")
include("planar/index.jl")
include("planar/chunk.jl")
include("planar/show.jl")
include("planar/build.jl")

end
