#
# Combinator-based embedded query language.
#

module DataKnots

export
    Count,
    DataKnot,
    Drop,
    Field,
    Filter,
    Given,
    It,
    Lift,
    Max,
    Min,
    Recall,
    Record,
    Take,
    query,
    signature

include("layouts.jl")
include("vectors.jl")
include("shapes.jl")
include("knots.jl")
include("queries.jl")
include("combinators.jl")

end
