#
# Combinator-based embedded query language.
#

module QueryCombinators

using DataKnots

export
    Combinator,
    Count,
    Data,
    Field,
    It,
    ThenCount,
    ThenDecorate,
    Query,
    Record,
    domain,
    execute

import Base:
    OneTo,
    convert,
    show,
    >>

import DataKnots:
    Layouts,
    argument,
    arguments,
    bound,
    cardinality,
    domain,
    fits,
    ibound,
    items,
    shape

include("operation.jl")
include("signature.jl")
include("query.jl")
include("combinator.jl")
include("common.jl")

end
