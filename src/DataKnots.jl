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
    Given,
    It,
    Label,
    Lift,
    Lookup,
    Max,
    Min,
    Record,
    Sum,
    Tag,
    Take,
    Then,
    x0to1,
    x0toN,
    x1to1,
    x1toN

include("layouts.jl")
include("vectors.jl")
include("shapes.jl")
include("knots.jl")
include("queries.jl")
#include("pipelines.jl")

end
