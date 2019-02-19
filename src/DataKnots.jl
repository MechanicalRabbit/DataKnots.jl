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

export
    Cardinality,
    REG,
    OPT,
    PLU,
    OPT_PLU

include("layouts.jl")
include("vectors.jl")
include("shapes.jl")
include("knots.jl")
include("queries.jl")
include("pipelines.jl")

end
