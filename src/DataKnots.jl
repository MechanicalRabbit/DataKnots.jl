#
# Combinator-based embedded query language.
#

module DataKnots

export
    Combinator,
    Const,
    Count,
    DataKnot,
    Drop,
    Each,
    Field,
    Filter,
    Given,
    It,
    Label,
    Lift,
    Lookup,
    Max,
    Min,
    Range,
    Recall,
    Record,
    Sum,
    Take,
    Then

include("layouts.jl")
include("vectors.jl")
include("shapes.jl")
include("knots.jl")
include("queries.jl")
include("pipelines.jl")

end
