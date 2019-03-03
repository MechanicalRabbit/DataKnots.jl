#
# Combinator-based embedded query language.
#

module DataKnots

export
    Cardinality,
    Count,
    DataKnot,
    Drop,
    Each,
    Filter,
    Get,
    Given,
    It,
    Keep,
    Label,
    Lift,
    Max,
    Min,
    Record,
    Sum,
    Tag,
    Take,
    x0to1,
    x0toN,
    x1to1,
    x1toN

include("layouts.jl")
include("vectors.jl")
include("shapes.jl")
include("knots.jl")
include("pipelines.jl")
include("queries.jl")

end
