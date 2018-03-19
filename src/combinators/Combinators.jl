#
# Frontend.
#

module Combinators

export
    @query,
    @translate,
    Combinator,
    field,
    it,
    query

using ..Layouts
import ..Layouts: syntax

using ..Shapes

using ..Knots

using ..Queries

import Base:
    convert,
    show,
    >>

include("combinator.jl")
include("navigation.jl")
include("combine.jl")
include("query.jl")
include("translate.jl")
include("compose.jl")
include("then.jl")
include("define.jl")
include("broadcast.jl")
include("field.jl")
include("count.jl")
include("aggregate.jl")
include("filter.jl")

end
