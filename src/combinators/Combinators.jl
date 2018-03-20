#
# Frontend.
#

module Combinators

export
    @query,
    @translate,
    Combinator,
    execute,
    field,
    given,
    it,
    prepare,
    query,
    recall,
    record,
    tag

using ..Layouts
import ..Layouts: syntax

using ..Vectors

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
include("recall.jl")
include("given.jl")
include("then.jl")
include("define.jl")
include("tag.jl")
include("broadcast.jl")
include("field.jl")
include("record.jl")
include("count.jl")
include("aggregate.jl")
include("filter.jl")

end
