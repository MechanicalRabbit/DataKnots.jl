#
# Pagination.
#

take(N) =
    Combinator(take, N)

drop(N) =
    Combinator(drop, N)

take(env::Environment, q::Query, ::Missing, rev::Bool=false) =
    q

take(env::Environment, q::Query, N::Int, rev::Bool=false) =
    chain_of(
        q,
        take_by(N, rev),
    ) |> designate(ishape(q), OutputShape(domain(q), bound(mode(q), OutputMode(OPT))))

drop(env::Environment, q::Query, N) =
    take(env, q, N, true)

