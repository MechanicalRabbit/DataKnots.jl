#
# Sorting combinator.
#

Base.sort(Xs::SomeCombinator...) =
    Combinator(sort, Xs...)

convert(::Type{SomeCombinator}, ::typeof(sort)) =
    sort()

translate(::Type{Val{:sort}}, args::Tuple) =
    sort(translate.(args)...)

Base.sort(env::Environment, q::Query) =
    chain_of(
        q,
        sort_it(),
    ) |> designate(ishape(q), shape(q))

function Base.sort(env::Environment, q::Query, X::SomeCombinator)
    x = combine(X, env, stub(q))
    idom = idomain(q)
    imd = ibound(imode(q), imode(x))
    chain_of(
        duplicate_input(imd),
        in_input(imd, chain_of(project_input(imd, imode(q)), q)),
        distribute(imd, mode(q)),
        in_output(mode(q),
                  tuple_of(project_input(imd, InputMode()),
                           chain_of(project_input(imd, imode(x)), x))),
        sort_by(),
    ) |> designate(InputShape(idom, imd), shape(q))
end

Base.sort(env::Environment, q::Query, Xs...) =
        sort(env, q, record(Xs...))

