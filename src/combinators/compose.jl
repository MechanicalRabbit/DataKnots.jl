#
# Composition combinator.
#

>>(X::SomeCombinator, Xs...) =
    compose(X, convert.(SomeCombinator, Xs)...)

compose(X, Xs...) =
    Combinator(compose, X, Xs...)

syntax(::typeof(compose), args::Vector{Any}) =
    syntax(>>, args)

function compose(env::Environment, q::Query, Xs::SomeCombinator...)
    for X in Xs
        q = combine(X, env, q)
    end
    q
end

function compose(q1::Query, q2::Query)
    @assert fits(domain(q1), idomain(q2)) "!fits($q1 :: $(domain(q1)), $q2 :: $(idomain(q2)))"
    idom = idomain(q1)
    imd = ibound(imode(q1), imode(q2))
    dom = domain(q2)
    md = bound(mode(q1), mode(q2))
    chain_of(
        q1,
        in_block(q2),
        flat_block(),
    ) |> designate(InputShape(idom, imd), OutputShape(dom, md))
end


