#
# Combinator-based embedded query language.
#

module DataKnots

export
    @query,
    Collect,
    Count,
    DataKnot,
    Drop,
    Each,
    Filter,
    Get,
    Given,
    Group,
    Is0to1,
    Is0toN,
    Is1to1,
    Is1toN,
    It,
    Keep,
    Label,
    Lift,
    Max,
    Min,
    Mix,
    Record,
    Sum,
    Tag,
    Take,
    Unique,
    unitknot

include("layouts.jl")
include("vectors.jl")
include("shapes.jl")
include("knots.jl")
include("pipelines.jl")
include("queries.jl")

end
