#
# Combinators for vector functions.
#

module Queries

export
    as_block,
    chain_of,
    column,
    decode_missing,
    decode_tuple,
    decode_vector,
    dereference,
    flat_block,
    flat_tuple,
    in_block,
    in_tuple,
    lift,
    lift_block,
    lift_const,
    lift_null,
    lift_to_block,
    lift_to_block_tuple,
    lift_to_tuple,
    pass,
    pull_block,
    pull_every_block,
    tuple_of

using ..Layouts

using ..Planar
import ..Planar:
    column,
    dereference

using Base: OneTo
import Base:
    show

using Base.Cartesian

mutable struct QueryEnvironment
    refs::Vector{Pair{Symbol,AbstractVector}}
end

struct Query
    impl
    ctor::Function
    args::Vector{Any}

    Query(impl, ctor::Function, args...; kws...) =
        new(impl, ctor, collect(Any, args))
end

function (q::Query)(input::AbstractVector)
    input, refs = decapsulate(input)
    env = QueryEnvironment(copy(refs))
    output = q(env, input)
    encapsulate(output, env.refs)
end

(q::Query)(env::QueryEnvironment, input::AbstractVector) = q.impl(env, input)

Layouts.tile(q::Query) =
    Layouts.tile(Layouts.Layout[Layouts.tile(arg) for arg in q.args], brk=("$(nameof(q.ctor))(", ")"))

show(io::IO, q::Query) =
    pretty_print(io, q)

include("queries/lift.jl")
include("queries/decode.jl")
include("queries/chain.jl")
include("queries/tuple.jl")
include("queries/block.jl")
include("queries/index.jl")

end
