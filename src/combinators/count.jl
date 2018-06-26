#
# Count combinator.
#

Count(X::SomeCombinator) =
    Combinator(Count, X)

convert(::Type{SomeCombinator}, ::typeof(Count)) =
    Then(Count)

translate(::Type{Val{:count}}, ::Tuple{}) =
    Then(Count)

translate(::Type{Val{:count}}, args::Tuple{Any}) =
    Count(translate(args[1]))

function Count(env::Environment, q::Query, X)
    x = combine(X, env, stub(q))
    r = chain_of(
            x,
            count_block(),
            as_block(),
    ) |> designate(ishape(x), OutputShape(NativeShape(Int)))
    compose(q, r)
end

