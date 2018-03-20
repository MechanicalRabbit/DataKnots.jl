#
# The filter combinator.
#

Base.filter(X::SomeCombinator) =
    Combinator(filter, X)

translate(::Type{Val{:filter}}, args::Tuple{Any}) =
    filter(translate(args[1]))

function Base.filter(env::Environment, q::Query, X)
    x = combine(X, env, stub(q))
    r = chain_of(
            tuple_of(
                project_input(imode(x), InputMode()),
                chain_of(x, any_block())),
            sieve(),
    ) |> designate(ishape(x), OutputShape(domain(q), OPT))
    compose(q, r)
end

