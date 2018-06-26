#
# Cyclic record.
#

Weave(Xs...) =
    Combinator(Weave, collect(SomeCombinator, Xs))

translate(::Type{Val{:weave}}, args::Tuple) =
    Weave(translate.(args)...)

function Weave(env::Environment, q::Query, Xs)
    q0 = stub(q)
    lbls = Symbol[]
    for (i, X) in enumerate(Xs)
        dom = domain(combine(X, env, q0))
        lbl = decoration(dom, :tag, Symbol, Symbol("#$i"))
        push!(lbls, lbl)
    end
    names = gensym.(lbls)
    seeds = Query[combine(Field(lbl), env, q0) for lbl in lbls]
    ishp = ibound(ishape.(seeds))
    shp = OutputShape(RecordShape((OutputShape(ClosedShape(name, name => domain(seed)), mode(seed))
                                   for (name, seed) in zip(names, seeds))...))
    t = chain_of(
            tuple_of(lbls, [chain_of(project_input(mode(ishp), imode(seed)),
                                     seed,
                                     in_block(store(name)))
                            for (name, seed) in zip(names, seeds)]),
            as_block(),
    ) |> designate(ishp, shp)
    xs = Query[]
    for (i, (name, X)) in enumerate(zip(names, Xs))
        dom = RecordShape(((i != j ? fld : OutputShape(fld[][], mode(fld))) for (j, fld) in enumerate(shp[][:]))...)
        x = combine(X, env, stub(dom))
        x = chain_of(
            in_tuple(i, in_block(dereference())),
            x,
        ) |> designate(InputShape(shp[], imode(x)), shape(x))
        push!(xs, x)
    end
    ishp = ibound(ishape.(xs))
    bindings = Pair{Symbol,AbstractShape}[name => unbind(domain(x), names) for (name, x) in zip(names, xs)]
    shp = OutputShape(RecordShape((OutputShape(ClosedShape(name, bindings), mode(x))
                                   for (name, x) in zip(names, xs))...))
    w = chain_of(
            tuple_of(lbls, [chain_of(project_input(mode(ishp), imode(x)), x)
                            for (name, x) in zip(names, xs)]),
            tuple_of(lbls, [chain_of(column(i), in_block(store(name)))
                            for (i, name) in enumerate(names)]),
            as_block(),
    ) |> designate(ishp, shp)
    compose(compose(q, t), w)
end

