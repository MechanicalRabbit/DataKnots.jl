#
# Record constructor.
#

record(Xs...) =
    Combinator(record, collect(SomeCombinator, Xs))

translate(::Type{Val{:record}}, args::Tuple) =
    record(translate.(args)...)

function record(env::Environment, q::Query, Xs)
    xs = combine.(Xs, env, stub(q))
    ishp = ibound(ishape.(xs))
    shp = OutputShape(RecordShape(shape.(xs)))
    lbls = Symbol[decoration(domain(x), :tag, Symbol, Symbol("#$i")) for (i, x) in enumerate(xs)]
    r = chain_of(
            tuple_of(lbls, xs),
            as_block()
    ) |> designate(ishp, shp)
    compose(q, r)
end

