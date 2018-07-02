#
# Frontend.
#

module Combinators

export
    @query,
    @translate,
    Asc,
    Combinator,
    Count,
    Desc,
    Drop,
    Field,
    Filesystem,
    Filter,
    Given,
    Graft,
    Group,
    Index,
    It,
    JSONField,
    JSONValue,
    Lift,
    LoadCSV,
    LoadJSON,
    LoadXML,
    Max,
    Mean,
    Min,
    ParseCSV,
    ParseJSON,
    ParseXML,
    Recall,
    Record,
    Sort,
    Tag,
    Take,
    UniqueIndex,
    Weave,
    XMLAttr,
    XMLChild,
    XMLTag,
    execute,
    prepare,
    query

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

using Statistics

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
include("sort.jl")
include("take.jl")
include("group.jl")
include("index.jl")
include("graft.jl")
include("weave.jl")
include("fs.jl")
include("json.jl")
include("xml.jl")
include("csv.jl")

end
