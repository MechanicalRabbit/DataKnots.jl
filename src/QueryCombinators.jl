#
# Combinator-based embedded query language.
#

module QueryCombinators

using DataKnots

export
    Combinator,
    Count,
    ThenCount,
    Query

include("operation.jl")
include("signature.jl")
include("query.jl")
include("combinator.jl")
include("count.jl")

end
