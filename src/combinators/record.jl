#
# Record constructor.
#

Record(Xs...) =
    Combinator(Record, collect(SomeCombinator, Xs))

translate(::Type{Val{:record}}, args::Tuple) =
    Record(translate.(args)...)

function Record(env::Environment, q::Query, Xs)
    xs = combine.(Xs, Ref(env), Ref(stub(q)))
    ishp = ibound(ishape.(xs))
    shp = OutputShape(RecordShape(shape.(xs)))
    lbls = Symbol[decoration(domain(x), :tag, Symbol, Symbol("#$i")) for (i, x) in enumerate(xs)]
    r = chain_of(
            tuple_of(lbls, [chain_of(project_input(mode(ishp), imode(x)), x) for x in xs]),
            as_block()
    ) |> designate(ishp, shp)
    compose(q, r)
end

