#
# Specifying parameters.
#

given(P, X) =
    Combinator(given, convert(SomeCombinator, P), convert(SomeCombinator, X))

given(P, Q, X...) =
    given(P, given(Q, X...))

translate(::Type{Val{:given}}, args::Tuple{Any,Any,Vararg{Any}}) =
    given(translate.(args)...)

function given(env::Environment, q::Query, param, X)
    q0 = stub(q)
    p = combine(param, env, q0)
    name = decoration(domain(p), :tag, Symbol)
    if name === missing
        error("parameter name is not specified")
    end
    slots′ = merge(env.slots, Pair{Symbol,OutputShape}[name => shape(p)])
    env′ = Environment(slots′)
    x = combine(X, env′, q0)
    if !any(slot.first == name for slot in slots(ishape(x)))
        return compose(q, x)
    end
    if !isframed(x) && length(slots(x)) == 1
        imd = imode(p)
        g = chain_of(
                tuple_of(
                    project_input(imd, InputMode()),
                    tuple_of(p)),
                x,
        ) |> designate(InputShape(ibound(idomain(x), idomain(p)), imd), shape(x))
        return compose(q, g)
    else
        error("not implemented")
    end
end

