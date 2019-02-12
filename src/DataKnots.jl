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
    Then

include("layouts.jl")
include("vectors.jl")
include("shapes.jl")
include("knots.jl")
include("queries.jl")
include("pipelines.jl")

end
