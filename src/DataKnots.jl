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
    Exists,
    Filter,
    First,
    Get,
    Given,
    Group,
    Is0to1,
    Is0toN,
    Is1to1,
    Is1toN,
    It,
    Join,
    Keep,
    Label,
    Last,
    Let,
    Lift,
    Max,
    Min,
    Mix,
    Nth,
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
include("rewrites.jl")
include("queries.jl")

end
