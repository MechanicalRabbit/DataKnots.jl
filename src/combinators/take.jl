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

function take(env::Environment, q::Query, N::SomeCombinator, rev::Bool=false)
    n = combine(N, env, istub(q))
    ishp = ibound(ishape(q), ishape(n))
    chain_of(
        tuple_of(
            chain_of(project_input(mode(ishp), imode(q)),
                     q),
            chain_of(project_input(mode(ishp), imode(n)),
                     n,
                     fits(OPT, cardinality(n)) ?
                        lift_to_block(first, missing) :
                        lift_to_block(first))),
        take_by(rev),
    ) |> designate(ishp, OutputShape(domain(q), bound(mode(q), OutputMode(OPT))))
end

drop(env::Environment, q::Query, N) =
    take(env, q, N, true)

