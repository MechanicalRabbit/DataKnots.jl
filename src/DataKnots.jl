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
    Group,
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
    Unique,
    unitknot

include("layouts.jl")
include("vectors.jl")
include("shapes.jl")
include("knots.jl")
include("pipelines.jl")
include("queries.jl")

end
