#
# Grouping combinator.
#

group(Xs::SomeCombinator...) =
    Combinator(group, Xs...)

group(Xs...) =
    group(convert.(SomeCombinator, Xs)...)

translate(::Type{Val{:group}}, args::Tuple) =
    group(translate.(args)...)

function group(env::Environment, q::Query, Xs...)
    xs = combine.(Xs, Ref(env), Ref(stub(q)))
    xishp = ibound(ishape.(xs)...)
    x = tuple_of((chain_of(project_input(mode(xishp), imode(f)), f) for f in xs)...)
    imd = ibound(imode(q), mode(xishp))
    idom = idomain(q)
    md = mode(q)
    dom = RecordShape(shape.(xs)...,
                      OutputShape(domain(q),
                                  ibound(mode(q), OutputMode(PLU))))
    lbls = Symbol[decoration(domain(f), :tag, Symbol, Symbol("#$i")) for (i, f) in enumerate(xs)]
    push!(lbls, decoration(domain(q), :tag, Symbol, Symbol("#$(length(lbls)+1)")))
    spec = ordering_spec(shape(x), false)
    chain_of(
        duplicate_input(imd),
        in_input(imd, chain_of(project_input(imd, imode(q)), q)),
        distribute(imd, mode(q)),
        in_output(mode(q),
                  tuple_of(chain_of(project_input(imd, mode(xishp)), x),
                           project_input(imd, InputMode()))),
        group_by(spec),
        in_block(
            tuple_of(lbls,
                     [(chain_of(column(1), column(k)) for k = 1:length(xs))..., column(2)])),
    ) |> designate(InputShape(idom, imd), OutputShape(dom, md))
end

