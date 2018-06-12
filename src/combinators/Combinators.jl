#
# Frontend.
#

module Combinators

export
    @query,
    @translate,
    Combinator,
    asc,
    execute,
    desc,
    drop,
    field,
    filesystem,
    given,
    graft,
    group,
    index,
    it,
    json_field,
    json_value,
    load_json,
    load_xml,
    parse_json,
    parse_xml,
    prepare,
    query,
    recall,
    record,
    tag,
    take,
    unique_index,
    xml_attr,
    xml_child,
    xml_tag

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
include("sort.jl")
include("take.jl")
include("group.jl")
include("index.jl")
include("graft.jl")
include("fs.jl")
include("json.jl")
include("xml.jl")

end
