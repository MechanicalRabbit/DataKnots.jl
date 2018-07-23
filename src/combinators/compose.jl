#
# Composition combinator.
#

>>(X::SomeCombinator, Xs...) =
    Compose(X, convert.(SomeCombinator, Xs)...)

Compose(X, Xs...) =
    Combinator(Compose, X, Xs...)

syntax(::typeof(Compose), args::Vector{Any}) =
    syntax(>>, args)

function Compose(env::Environment, q::Query, Xs::SomeCombinator...)
    for X in Xs
        q = combine(X, env, q)
    end
    q
end

function compose(q1::Query, q2::Query)
    @assert fits(domain(q1), idomain(q2)) "!fits($q1 :: $(domain(q1)), $q2 :: $(idomain(q2)))"
    idom = idomain(q1)
    imd = ibound(imode(q1), imode(q2))
    dom = domain(q2)
    md = bound(mode(q1), mode(q2))
    chain_of(
        duplicate_input(imd),
        in_input(imd, chain_of(project_input(imd, imode(q1)), q1)),
        distribute(imd, mode(q1)),
        in_output(mode(q1), chain_of(project_input(imd, imode(q2)), q2)),
        flatten_output(mode(q1), mode(q2)),
    ) |> designate(InputShape(idom, imd), OutputShape(dom, md))
end

duplicate_input(md::InputMode) =
    if isfree(md)
        pass()
    else
        tuple_of(pass(), column(2))
    end

in_input(md::InputMode, q::Query) =
    if isfree(md)
        q
    else
        in_tuple(1, q)
    end

distribute(imd::InputMode, md::OutputMode) =
    if isfree(imd)
        pass()
    else
        pull_block(1)
    end

in_output(md::OutputMode, q::Query) =
    in_block(q)

function project_input(md1::InputMode, md2::InputMode)
    if isfree(md1) && isfree(md2) || slots(md1) == slots(md2) && isframed(md1) == isframed(md2)
        pass()
    elseif isfree(md2)
        column(1)
    else
        idxs = Int[]
        if isframed(md2)
            @assert isframed(md1)
            push!(idxs, 1)
        end
        for slot2 in slots(md2)
            idx = findfirst(slot1 -> slot1.first == slot2.first, slots(md1))
            @assert idx != nothing
            push!(idxs, idx + isframed(md1))
        end
        tuple_of(
            column(1),
            chain_of(
                column(2),
                tuple_of([column(i) for i in idxs]...)))
    end
end

flatten_output(md1::OutputMode, md2::OutputMode) =
    flat_block()

