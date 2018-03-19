#
# Lifting a scalar function.
#

struct BroadcastCombinator <: Base.BroadcastStyle
end

Base.BroadcastStyle(::Type{<:SomeCombinator}) = BroadcastCombinator()

Base.broadcast(f, ::BroadcastCombinator, ::Nothing, ::Nothing, Xs...) =
    apply(f, Xs...)

apply(f, Xs...) =
    Combinator(apply, f, collect(SomeCombinator, Xs))

translate(::Type{Val{name}}, args::Tuple) where {name} =
    if isdefined(Base, name)
        apply(getfield(Base, name), translate.(args)...)
    else
        error("undefined combinator: $name")
    end

syntax(::typeof(apply), args::Vector{Any}) =
    syntax(broadcast, Any[args[1], args[2]...])

function apply(env::Environment, q::Query, f, Xs)
    xs = combine.(Xs, env, stub(q))
    if length(xs) == 1
        x = xs[1]
        ity = eltype(domain(x))
        oty = Core.Compiler.return_type(f, Tuple{ity})
        r = chain_of(
            x,
            in_block(lift(f))
        ) |> designate(ishape(x), OutputShape(NativeShape(oty), mode(q)))
        compose(q, r)
    else
        ity = eltype.(domain.(xs))
        oty = Core.Compiler.return_type(f, Tuple{ity...})
        ishp = ibound(ishape.(xs))
        shp = OutputShape(NativeShape(oty), bound(mode.(xs)))
        r = chain_of(
                tuple_of(Symbol[], xs),
                lift_to_block_tuple(f)
        ) |> designate(ishp, shp)
        compose(q, r)
    end
end

