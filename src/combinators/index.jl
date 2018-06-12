#
# Grouping combinator.
#

index(Xs::SomeCombinator...) =
    Combinator(index, Xs...)

index(Xs...) =
    index(convert.(SomeCombinator, Xs)...)

unique_index(Xs::SomeCombinator...) =
    Combinator(unique_index, Xs...)

unique_index(Xs...) =
    unique_index(convert.(SomeCombinator, Xs)...)

translate(::Type{Val{:index}}, args::Tuple) =
    index(translate.(args)...)

translate(::Type{Val{:unique_index}}, args::Tuple) =
    unique_index(translate.(args)...)

index(env::Environment, q::Query, Xs...) =
    index(env, q, false, Xs...)

unique_index(env::Environment, q::Query, Xs...) =
    index(env, q, true, Xs...)

index(env::Environment, q::Query, unique::Bool, Xs...) =
    index(env, q, unique, record(Xs...))

function index(env::Environment, q::Query, unique::Bool, X)
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

