#
# Lifting a scalar function.
#

struct BroadcastCombinator <: Base.BroadcastStyle
end

Base.BroadcastStyle(::Type{<:SomeCombinator}) = BroadcastCombinator()

Base.BroadcastStyle(s::BroadcastCombinator, ::Broadcast.DefaultArrayStyle) = s

Base.broadcastable(X::SomeCombinator) = X

Base.Broadcast.instantiate(bc::Broadcast.Broadcasted{BroadcastCombinator}) = bc

Base.copy(bc::Broadcast.Broadcasted{BroadcastCombinator}) =
    Lift(bc.f, bc.args...)

Lift(f, Xs...) =
    Combinator(Lift, f, collect(SomeCombinator, Xs))

translate(::Type{Val{name}}, args::Tuple) where {name} =
    if isdefined(Base, name)
        Lift(getfield(Base, name), translate.(args)...)
    else
        error("undefined combinator: $name")
    end

syntax(::typeof(Lift), args::Vector{Any}) =
    syntax(broadcast, Any[args[1], args[2]...])

function Lift(env::Environment, q::Query, f, Xs)
    xs = combine.(Xs, Ref(env), Ref(stub(q)))
    if length(xs) == 1
        x = xs[1]
        ity = eltype(domain(x))
        oty = Core.Compiler.return_type(f, Tuple{ity})
        if oty <: AbstractVector
            ety = oty.parameters[1]
            r = chain_of(
                x,
                in_block(
                  chain_of(
                    lift(f),
                    decode_vector())),
                flat_block()
            ) |> designate(ishape(x),
                     OutputShape(NativeShape(ety),
                                 OPT|PLU))
        else
            r = chain_of(
                x,
                in_block(lift(f))
            ) |> designate(ishape(x),
                     OutputShape(NativeShape(oty),
                                 mode(q)))
        end
        compose(q, r)
    else
        ity = eltype.(domain.(xs))
        oty = Core.Compiler.return_type(f, Tuple{ity...})
        ishp = ibound(ishape.(xs))
        dsx = tuple_of(Symbol[], [chain_of(project_input(mode(ishp), imode(x)), x) for x in xs])
        if oty <: AbstractVector
            ety = oty.parameters[1]
            r = chain_of(
                    dsx,
                    lift_to_block_tuple(f),
                    in_block(decode_vector()),
                    flat_block()
            ) |> designate(ishp,
                     OutputShape(NativeShape(ety),
                                 OPT|PLU))
        else
            r = chain_of(
                    dsx,
                    lift_to_block_tuple(f)
            ) |> designate(ishp,
                     OutputShape(NativeShape(oty),
                                 bound(mode.(xs))))
        end
        compose(q, r)
    end
end

