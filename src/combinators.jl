#
# Frontend.
#

import Base:
    convert,
    show,
    >>

using Statistics

# Combinator interface.

struct Combinator
    op
    args::Vector{Any}
    src

    Combinator(op, args::Vector{Any}) =
        new(op, args, nothing)
end

Combinator(op, args...) =
    Combinator(op, collect(Any, args))

syntax(F::Combinator) =
    syntax(F.op, F.args)

show(io::IO, F::Combinator) =
    print_expr(io, syntax(F))

# Navigation syntax.

struct Navigation
    _path::Tuple{Vararg{Symbol}}
end

Base.getproperty(nav::Navigation, s::Symbol) =
    let path = getfield(nav, :_path)
        Navigation((path..., s))
    end

show(io::IO, nav::Navigation) =
    let path = getfield(nav, :_path)
        print(io, join((:It, path...), "."))
    end

const It = Navigation(())

# Applying combinator to a query.

struct DataValue{T}
    val::T
end

show(io::IO, data::DataValue) = show(io, data.val)

const SomeCombinator = Union{DataKnot, DataValue, Combinator, Navigation}

convert(::Type{SomeCombinator}, val::Union{Number,String}) =
    DataValue(val)

convert(::Type{SomeCombinator}, val::Base.RefValue) =
    DataValue(val.x)

mutable struct Environment
    slots::Vector{Pair{Symbol,OutputShape}}
end

combine(knot::DataKnot, env::Environment, q::Query) =
    compose(
        q,
        lift_block(elements(knot)) |> designate(InputShape(AnyShape()), shape(knot)))

combine(data::DataValue, env::Environment, q::Query) =
    combine(convert(DataKnot, data.val), env, q)

combine(F::Combinator, env::Environment, q::Query) =
    F.op(env, q, F.args...)

function combine(nav::Navigation, env::Environment, q::Query)
    for fld in getfield(nav, :_path)
        q = combine(Field(fld), env, q)
    end
    q
end

stub(shp::AbstractShape) =
    as_block() |> designate(InputShape(shp), OutputShape(shp))

stub(dr::Decoration, shp::AbstractShape) =
    as_block() |> designate(InputShape(dr, shp), OutputShape(dr, shp))

stub() = stub(NativeShape(Nothing))

stub(q::Query) =
    stub(decoration(q), domain(q))

istub(q::Query) =
    stub(idecoration(q), idomain(q))

# Executing a query.

query(; params...) =
    F -> query(F; params...)

query(F; params...) =
    query(nothing, F; params...)

query(data, F; params...) =
    execute(convert(DataKnot, data) >> convert(SomeCombinator, F),
            sort(collect(Pair{Symbol,DataKnot}, params), by=first))

execute(data::DataKnot, params::Vector{Pair{Symbol,DataKnot}}=Pair{Symbol,DataKnot}[]) =
    data

function execute(F::SomeCombinator, params::Vector{Pair{Symbol,DataKnot}}=Pair{Symbol,DataKnot}[])
    q = prepare(F, params)
    input = pack(q, params)
    output = q(input)
    return unpack(q, output)
end

function prepare(F::SomeCombinator, slots::Vector{Pair{Symbol,OutputShape}}=Pair{Symbol,OutputShape}[])
    env = Environment(slots)
    optimize(combine(F, env, stub()))
end

function prepare(F::SomeCombinator, params::Vector{Pair{Symbol,DataKnot}})
    slots = Pair{Symbol,OutputShape}[param.first => shape(param.second) for param in params]
    prepare(F, slots)
end

function pack(q, params)
    data = [nothing]
    md = imode(q)
    if isfree(md)
        return data
    else
        cols = AbstractVector[]
        if isframed(md)
            push!(cols, [1])
        end
        k = 1
        for slot in slots(md)
            while k <= length(params) && params[k].first < slot.first
                k += 1
            end
            if k > length(params) || params[k].first != slot.first
                error("parameter is not specified: $(slot.first)")
            end
            elts = elements(params[k].second)
            push!(cols, BlockVector(length(elts) == 1 ? (:) : [1, length(elts)+1], elts))
        end
        return TupleVector(1, AbstractVector[data, TupleVector(1, cols)])
    end
end

unpack(q, output) =
    let vals = elements(output),
        shp = shape(q)
        DataKnot(shp, vals)
    end

# Composition combinator.

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
    idr = idecoration(q1)
    idom = idomain(q1)
    imd = ibound(imode(q1), imode(q2))
    dr = decoration(q2)
    dom = domain(q2)
    md = bound(mode(q1), mode(q2))
    chain_of(
        duplicate_input(imd),
        in_input(imd, chain_of(project_input(imd, imode(q1)), q1)),
        distribute(imd, mode(q1)),
        in_output(mode(q1), chain_of(project_input(imd, imode(q2)), q2)),
        flatten_output(mode(q1), mode(q2)),
    ) |> designate(InputShape(idr, idom, imd), OutputShape(dr, dom, md))
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

# Extracting parameters.

Recall(name::Symbol) =
    Combinator(Recall, name)

function Recall(env::Environment, q::Query, name)
    for slot in env.slots
        if slot.first == name
            shp = slot.second
            ishp = InputShape(domain(q), InputMode([slot]))
            r = chain_of(
                    column(2),
                    column(1)
            ) |> designate(ishp, shp)
            return compose(q, r)
        end
    end
    error("undefined parameter: $name")
end

# Specifying parameters.

Given(P, X) =
    Combinator(Given, convert(SomeCombinator, P), convert(SomeCombinator, X))

Given(P, Q, X...) =
    Given(P, Given(Q, X...))

function Given(env::Environment, q::Query, param, X)
    q0 = stub(q)
    p = combine(param, env, q0)
    name = label(shape(p))
    if name === nothing
        error("parameter name is not specified")
    end
    slots′ = Pair{Symbol,OutputShape}[]
    merged = false
    for slot in env.slots
        if slot.first < name
            push!(slots′, slot)
        else
            if !merged
                push!(slots′, name => shape(p))
                merged = true
            end
            if slot.first > name
                push!(slots′, slot)
            end
        end
    end
    if !merged
        push!(slots′, name => shape(p))
    end
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

# Then.

Then(q::Query) =
    Combinator(Then, q)

Then(env::Environment, q::Query, q′::Query) =
    compose(q, q′)

Then(ctor, args...) =
    Combinator(Then, ctor, args...)

Then(env::Environment, q::Query, ctor, args...) =
    ctor(env, istub(q), Then(q), args...)

# Define.

Define(name::Symbol, X::SomeCombinator) =
    Combinator(Define, name, X)

syntax(::typeof(Define), args::Vector{Any}) =
    syntax(Define, args...)

syntax(::typeof(Define), name::Symbol, X::SomeCombinator) =
    name

Define(env::Environment, q::Query, name::Symbol, X::SomeCombinator) =
    combine(X, env, q)

# Assign a label.

Tag(lbl::Symbol) =
    Combinator(Tag, lbl)

Tag(env::Environment, q::Query, lbl::Symbol) =
    q |> designate(ishape(q), shape(q) |> decorate(label=lbl))

convert(::Type{SomeCombinator}, p::Pair{Symbol}) =
    Compose(convert(SomeCombinator, p.second), Tag(p.first))

# Lifting Julia functions.

struct BroadcastCombinator <: Base.BroadcastStyle
end

Base.BroadcastStyle(::Type{<:SomeCombinator}) = BroadcastCombinator()

Base.BroadcastStyle(s::BroadcastCombinator, ::Broadcast.DefaultArrayStyle) = s

Base.broadcastable(X::SomeCombinator) = X

Base.Broadcast.instantiate(bc::Broadcast.Broadcasted{BroadcastCombinator}) = bc

Base.copy(bc::Broadcast.Broadcasted{BroadcastCombinator}) =
    Lift(bc.f, bc.args...)

convert(::Type{SomeCombinator}, bc::Broadcast.Broadcasted{BroadcastCombinator}) =
    Lift(bc.f, bc.args...)

Lift(f, Xs...) =
    Combinator(Lift, f, collect(SomeCombinator, Xs))

syntax(::typeof(Lift), args::Vector{Any}) =
    syntax(broadcast, Any[args[1], args[2]...])

function Lift(env::Environment, q::Query, f, Xs)
    xs = combine.(Xs, Ref(env), Ref(stub(q)))
    if length(xs) == 1
        x = xs[1]
        ity = eltype(domain(x))
        oty = Core.Compiler.return_type(f, Tuple{ity})
        if oty <: AbstractVector
            ety = oty.parameters[1]
            r = chain_of(
                x,
                in_block(
                  chain_of(
                    lift(f),
                    decode_vector())),
                flat_block()
            ) |> designate(ishape(x),
                     OutputShape(NativeShape(ety),
                                 OPT|PLU))
        else
            r = chain_of(
                x,
                in_block(lift(f))
            ) |> designate(ishape(x),
                     OutputShape(NativeShape(oty),
                                 mode(q)))
        end
        compose(q, r)
    else
        ity = eltype.(domain.(xs))
        oty = Core.Compiler.return_type(f, Tuple{ity...})
        ishp = ibound(ishape.(xs))
        dsx = tuple_of(Symbol[], [chain_of(project_input(mode(ishp), imode(x)), x) for x in xs])
        if oty <: AbstractVector
            ety = oty.parameters[1]
            r = chain_of(
                    dsx,
                    lift_to_block_tuple(f),
                    in_block(decode_vector()),
                    flat_block()
            ) |> designate(ishp,
                     OutputShape(NativeShape(ety),
                                 OPT|PLU))
        else
            r = chain_of(
                    dsx,
                    lift_to_block_tuple(f)
            ) |> designate(ishp,
                     OutputShape(NativeShape(oty),
                                 bound(mode.(xs))))
        end
        compose(q, r)
    end
end

# Attributes.

Field(name) =
    Combinator(Field, name)

function Field(env::Environment, q::Query, name)
    if any(slot.first == name for slot in env.slots)
        return Recall(env, q, name)
    end
    r = lookup(domain(q), name)
    r !== missing || error("unknown attribute $name at\n$(domain(q))")
    compose(q, r)
end

function lookup(env::Environment, name)
    for slot in env.slots
        if slot.first == name
            shp = slot.second
            ishp = InputShape(domain(q), [slot])
            r = chain_of(
                    column(2),
                    column(1)
            ) |> designate(ishp, shp)
            return compose(q, r)
        end
    end
end

lookup(::AbstractShape, ::Any) = missing

function lookup(shp::RecordShape, name::Symbol)
    for fld in shp.flds
        lbl = label(fld)
        if lbl == name
            return column(lbl) |> designate(InputShape(shp), fld)
        end
    end
    return missing
end

lookup(shp::NativeShape, name) =
    lookup(shp.ty, name)

lookup(::Type, name) =
    missing

# Record constructor.

Record(Xs...) =
    Combinator(Record, collect(SomeCombinator, Xs))

function Record(env::Environment, q::Query, Xs)
    xs = combine.(Xs, Ref(env), Ref(stub(q)))
    ishp = ibound(ishape.(xs))
    shp = OutputShape(RecordShape(shape.(xs)))
    lbls = Symbol[let lbl = label(shape(x)); lbl !== nothing ? lbl : Symbol("#$i") end for (i, x) in enumerate(xs)]
    r = chain_of(
            tuple_of(lbls, [chain_of(project_input(mode(ishp), imode(x)), x) for x in xs]),
            as_block()
    ) |> designate(ishp, shp)
    compose(q, r)
end

# Count combinator.

Count(X::SomeCombinator) =
    Combinator(Count, X)

convert(::Type{SomeCombinator}, ::typeof(Count)) =
    Then(Count)

function Count(env::Environment, q::Query, X)
    x = combine(X, env, stub(q))
    r = chain_of(
            x,
            count_block(),
            as_block(),
    ) |> designate(ishape(x), OutputShape(NativeShape(Int)))
    compose(q, r)
end

# Aggregate combinators.

Max(X::SomeCombinator) =
    Combinator(Max, X)

convert(::Type{SomeCombinator}, ::typeof(Max)) =
    Then(Max)

Min(X::SomeCombinator) =
    Combinator(Min, X)

convert(::Type{SomeCombinator}, ::typeof(Min)) =
    Then(Min)

Mean(X::SomeCombinator) =
    Combinator(Mean, X)

convert(::Type{SomeCombinator}, ::typeof(Mean)) =
    Then(Mean)

function Max(env::Environment, q::Query, X)
    x = combine(X, env, stub(q))
    if fits(OPT, cardinality(x))
        r = chain_of(
                x,
                lift_to_block(maximum, missing),
                decode_missing(),
        ) |> designate(ishape(x), OutputShape(domain(x), OPT))
    else
        r = chain_of(
                x,
                lift_to_block(maximum),
                as_block(),
        ) |> designate(ishape(x), OutputShape(domain(x)))
    end
    compose(q, r)
end

function Min(env::Environment, q::Query, X)
    x = combine(X, env, stub(q))
    if fits(OPT, cardinality(x))
        r = chain_of(
                x,
                lift_to_block(minimum, missing),
                decode_missing(),
        ) |> designate(ishape(x), OutputShape(domain(x), OPT))
    else
        r = chain_of(
                x,
                lift_to_block(minimum),
                as_block(),
        ) |> designate(ishape(x), OutputShape(domain(x)))
    end
    compose(q, r)
end

function Mean(env::Environment, q::Query, X)
    x = combine(X, env, stub(q))
    T = Core.Compiler.return_type(mean, Tuple{eltype(domain(x))})
    if fits(OPT, cardinality(x))
        r = chain_of(
                x,
                lift_to_block(mean, missing),
                decode_missing(),
        ) |> designate(ishape(x), OutputShape(T, OPT))
    else
        r = chain_of(
                x,
                lift_to_block(mean),
                as_block(),
        ) |> designate(ishape(x), OutputShape(T))
    end
    compose(q, r)
end

# Filter combinator.

Filter(X::SomeCombinator) =
    Combinator(Filter, X)

function Filter(env::Environment, q::Query, X)
    x = combine(X, env, stub(q))
    r = chain_of(
            tuple_of(
                project_input(imode(x), InputMode()),
                chain_of(x, any_block())),
            sieve(),
    ) |> designate(ishape(x), OutputShape(decoration(q), domain(q), OPT))
    compose(q, r)
end

# Pagination.

Take(N) =
    Combinator(Take, N)

Drop(N) =
    Combinator(Drop, N)

Take(env::Environment, q::Query, ::Missing, rev::Bool=false) =
    q

Take(env::Environment, q::Query, N::Int, rev::Bool=false) =
    chain_of(
        q,
        take_by(N, rev),
    ) |> designate(ishape(q), OutputShape(decoration(q), domain(q), bound(mode(q), OutputMode(OPT))))

function Take(env::Environment, q::Query, N::SomeCombinator, rev::Bool=false)
    n = combine(N, env, istub(q))
    ishp = ibound(ishape(q), ishape(n))
    chain_of(
        tuple_of(
            chain_of(project_input(mode(ishp), imode(q)),
                     q),
            chain_of(project_input(mode(ishp), imode(n)),
                     n,
                     fits(OPT, cardinality(n)) ?
                        lift_to_block(first, missing) :
                        lift_to_block(first))),
        take_by(rev),
    ) |> designate(ishp, OutputShape(decoration(q), domain(q), bound(mode(q), OutputMode(OPT))))
end

Drop(env::Environment, q::Query, N) =
    Take(env, q, N, true)
