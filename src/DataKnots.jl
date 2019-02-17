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
    It,
    Label,
    Lift,
    Lookup,
    Max,
    Min,
    Record,
    Remember,
    Sum,
    Tag,
    Take,
    Then

include("layouts.jl")
include("vectors.jl")

end
