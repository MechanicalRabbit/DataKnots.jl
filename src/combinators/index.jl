#
# Grouping combinator.
#

Index(Xs::SomeCombinator...) =
    Combinator(Index, Xs...)

Index(Xs...) =
    Index(convert.(SomeCombinator, Xs)...)

UniqueIndex(Xs::SomeCombinator...) =
    Combinator(UniqueIndex, Xs...)

UniqueIndex(Xs...) =
    UniqueIndex(convert.(SomeCombinator, Xs)...)

translate(::Type{Val{:index}}, args::Tuple) =
    Index(translate.(args)...)

translate(::Type{Val{:unique_index}}, args::Tuple) =
    UniqueIndex(translate.(args)...)

Index(env::Environment, q::Query, Xs...) =
    Index(env, q, false, Xs...)

UniqueIndex(env::Environment, q::Query, Xs...) =
    Index(env, q, true, Xs...)

Index(env::Environment, q::Query, unique::Bool, Xs...) =
    Index(env, q, unique, Record(Xs...))

function Index(env::Environment, q::Query, unique::Bool, X)
    x = combine(X, env, stub(q))
    imd = ibound(imode(q), imode(x))
    idom = idomain(q)
    md = mode(q)
    dom = IndexShape(shape(x),
                     OutputShape(domain(q),
                                 ibound(mode(q), OutputMode(unique ? REG : PLU))))
    chain_of(
        duplicate_input(imd),
        in_input(imd, chain_of(project_input(imd, imode(q)), q)),
        distribute(imd, mode(q)),
        in_output(mode(q),
                  tuple_of(chain_of(project_input(imd, imode(x)), x),
                           project_input(imd, InputMode()))),
        group_by(),
    ) |> designate(InputShape(idom, imd), OutputShape(dom, md))
end

