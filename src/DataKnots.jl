#
# Combinator-based embedded query language.
#

module DataKnots

export
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
    Take

include("layouts.jl")
include("vectors.jl")
include("shapes.jl")
include("knots.jl")
include("pipelines.jl")
include("queries.jl")

end
