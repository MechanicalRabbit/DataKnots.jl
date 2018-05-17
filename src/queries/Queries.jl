#
# Backend algebra.
#

module Queries

export
    Query,
    any_block,
    as_block,
    chain_of,
    column,
    count_block,
    decode_missing,
    decode_tuple,
    decode_vector,
    dereference,
    designate,
    flat_block,
    flat_tuple,
    group_by,
    in_block,
    in_tuple,
    ishape,
    json_parse,
    lift,
    lift_block,
    lift_const,
    lift_null,
    lift_to_block,
    lift_to_block_tuple,
    lift_to_tuple,
    optimize,
    pass,
    pull_block,
    pull_every_block,
    sieve,
    shape,
    sort_by,
    sort_it,
    take_by,
    tuple_of,
    xml_parse

using ..Layouts
import ..Layouts: syntax

using ..Vectors
import ..Vectors:
    column,
    dereference

using ..Shapes: Signature, InputShape, OutputShape
import ..Shapes:
    cardinality,
    idomain,
    imode,
    isframed,
    isfree,
    ishape,
    isoptional,
    isplural,
    isregular,
    domain,
    mode,
    signature,
    shape,
    slots

using Base: OneTo
import Base:
    show

using Base.Cartesian

include("query.jl")
include("lift.jl")
include("decode.jl")
include("chain.jl")
include("tuple.jl")
include("block.jl")
include("index.jl")
include("sieve.jl")
include("sort.jl")
include("take.jl")
include("group.jl")
include("json.jl")
include("xml.jl")
include("simplify.jl")

end
