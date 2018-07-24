#
# Specifying parameters.
#

Given(P, X) =
    Combinator(Given, convert(SomeCombinator, P), convert(SomeCombinator, X))

Given(P, Q, X...) =
    Given(P, Given(Q, X...))

translate(::Type{Val{:given}}, args::Tuple{Any,Any,Vararg{Any}}) =
    Given(translate.(args)...)

function Given(env::Environment, q::Query, param, X)
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
        imd = ibound(InputMode(filter(s -> s.first != name, slots(x)), isframed(x)), imode(p))
        cs = Query[]
        if isframed(x)
            push!(cs, chain_of(column(2), column(1)))
        end
        for slot in slots(x)
            if slot.first == name
                push!(cs, chain_of(project_input(imd, imode(p)), p))
            else
                idx = findfirst(islot -> islot.first == slot.first, slots(imd))
                @assert idx != nothing
                push!(cs, chain_of(column(2), column(idx + isframed(imd))))
            end
        end
        g = chain_of(
                tuple_of(
                    project_input(imd, InputMode()),
                    tuple_of(cs...)),
                x,
        ) |> designate(InputShape(ibound(idomain(x), idomain(p)), imd), shape(x))
        return compose(q, g)
    end
end

