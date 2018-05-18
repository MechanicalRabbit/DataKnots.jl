#
# Aggregate combinators.
#

Base.maximum(X::SomeCombinator) =
    Combinator(maximum, X)

convert(::Type{SomeCombinator}, ::typeof(maximum)) =
    then(maximum)

Base.minimum(X::SomeCombinator) =
    Combinator(minimum, X)

convert(::Type{SomeCombinator}, ::typeof(minimum)) =
    then(minimum)

Base.mean(X::SomeCombinator) =
    Combinator(mean, X)

convert(::Type{SomeCombinator}, ::typeof(mean)) =
    then(mean)

translate(::Type{Val{:max}}, ::Tuple{}) =
    then(maximum)

translate(::Type{Val{:max}}, args::Tuple{Any}) =
    maximum(translate(args[1]))

translate(::Type{Val{:min}}, ::Tuple{}) =
    then(minimum)

translate(::Type{Val{:min}}, args::Tuple{Any}) =
    minimum(translate(args[1]))

translate(::Type{Val{:mean}}, ::Tuple{}) =
    then(mean)

translate(::Type{Val{:mean}}, args::Tuple{Any}) =
    mean(translate(args[1]))

function Base.maximum(env::Environment, q::Query, X)
    x = combine(X, env, stub(q))
    if fits(OPT, cardinality(x))
        r = chain_of(
                x,
                lift_to_block(maximum, missing),
                decode_missing(),
        ) |> designate(ishape(x), OutputShape(domain(x), OPT))
    else
        r = chain_of(
                x,
                lift_to_block(maximum),
                as_block(),
        ) |> designate(ishape(x), OutputShape(domain(x)))
    end
    compose(q, r)
end

function Base.minimum(env::Environment, q::Query, X)
    x = combine(X, env, stub(q))
    if fits(OPT, cardinality(x))
        r = chain_of(
                x,
                lift_to_block(minimum, missing),
                decode_missing(),
        ) |> designate(ishape(x), OutputShape(domain(x), OPT))
    else
        r = chain_of(
                x,
                lift_to_block(minimum),
                as_block(),
        ) |> designate(ishape(x), OutputShape(domain(x)))
    end
    compose(q, r)
end

function Base.mean(env::Environment, q::Query, X)
    x = combine(X, env, stub(q))
    T = Core.Compiler.return_type(mean, Tuple{eltype(domain(x))})
    if fits(OPT, cardinality(x))
        r = chain_of(
                x,
                lift_to_block(mean, missing),
                decode_missing(),
        ) |> designate(ishape(x), OutputShape(T, OPT))
    else
        r = chain_of(
                x,
                lift_to_block(mean),
                as_block(),
        ) |> designate(ishape(x), OutputShape(T))
    end
    compose(q, r)
end

