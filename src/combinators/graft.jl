#
# Grafting a link.
#

Graft(Xs::SomeCombinator...) =
    Combinator(Graft, Xs...)

Graft(Xs...) =
    graft(convert.(SomeCombinator, Xs)...)

translate(::Type{Val{:graft}}, args::Tuple) =
    Graft(translate.(args)...)

Graft(env::Environment, q::Query, Xs...) =
    Graft(env, q, record(Xs[1:end-1]...), Xs[end])

function Graft(env::Environment, q::Query, K, I)
    k = combine(K, env, stub(q))
    i = combine(I, env, istub(q))
    vdom = domain(i)
    if vdom isa DecoratedShape
        vdom = vdom[]
    end
    @assert vdom isa IndexShape "expected an index"
    imd = ibound(imode(q), imode(k), imode(i))
    idom = ibound(idomain(q), idomain(i))
    md = mode(q)
    dom = ShadowShape(domain(q), OutputShape[vdom.val])
    lbl = decoration(domain(q), :tag, Symbol)
    if lbl !== missing
        dom = dom |> decorate(:tag => lbl)
    end
    lbls = Symbol[Symbol("#1"),
                  decoration(domain(i), :tag, Symbol, decoration(vdom.val, :tag, Symbol, Symbol("#2")))]
    chain_of(
        tuple_of(
            chain_of(
                duplicate_input(imd),
                in_input(imd, chain_of(project_input(imd, imode(q)), q)),
                distribute(imd, mode(q)),
                in_output(mode(q),
                          tuple_of(chain_of(project_input(imd, imode(k)), k), pass()))),
            chain_of(project_input(imd, imode(i)), i)),
        correlate(),
        in_block(
            tuple_of(
                lbls,
                [column(1), chain_of(column(2), flat_block())])),
    ) |> designate(InputShape(idom, imd), OutputShape(dom, md))
end

