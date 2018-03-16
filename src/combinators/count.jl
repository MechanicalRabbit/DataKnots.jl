#
# Count combinator.
#

Base.count(X::SomeCombinator) =
    Combinator(count, X)

convert(::Type{SomeCombinator}, ::typeof(count)) =
    then(count)

function Base.count(env::Environment, q::Query, X)
    x = combine(X, env, stub(q))
    r = chain_of(
            x,
            count_block(),
            as_block(),
    ) |> designate(ishape(x), OutputShape(NativeShape(Int)))
    compose(q, r)
end

