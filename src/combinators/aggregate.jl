#
# Aggregate combinators.
#

Base.maximum(X::SomeCombinator) =
    Combinator(maximum, X)

convert(::Type{SomeCombinator}, ::typeof(maximum)) =
    then(maximum)

function Base.maximum(env::Environment, q::Query, X)
    x = combine(X, env, stub(q))
    r = chain_of(
            x,
            lift_to_block(maximum, missing),
            decode_missing(),
    ) |> designate(ishape(x), OutputShape(domain(q), OPT))
    compose(q, r)
end

