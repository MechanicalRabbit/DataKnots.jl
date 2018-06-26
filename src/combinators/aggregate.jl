#
# Aggregate combinators.
#

Max(X::SomeCombinator) =
    Combinator(Max, X)

convert(::Type{SomeCombinator}, ::typeof(Max)) =
    Then(Max)

Min(X::SomeCombinator) =
    Combinator(Min, X)

convert(::Type{SomeCombinator}, ::typeof(Min)) =
    Then(Min)

Mean(X::SomeCombinator) =
    Combinator(Mean, X)

convert(::Type{SomeCombinator}, ::typeof(Mean)) =
    Then(Mean)

translate(::Type{Val{:max}}, ::Tuple{}) =
    Then(Max)

translate(::Type{Val{:max}}, args::Tuple{Any}) =
    Max(translate(args[1]))

translate(::Type{Val{:min}}, ::Tuple{}) =
    Then(Min)

translate(::Type{Val{:min}}, args::Tuple{Any}) =
    Min(translate(args[1]))

translate(::Type{Val{:mean}}, ::Tuple{}) =
    Then(Mean)

translate(::Type{Val{:mean}}, args::Tuple{Any}) =
    Mean(translate(args[1]))

function Max(env::Environment, q::Query, X)
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

function Min(env::Environment, q::Query, X)
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

function Mean(env::Environment, q::Query, X)
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

