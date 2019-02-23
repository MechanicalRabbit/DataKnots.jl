#
# Algebra of pipelines.
#

import Base:
    convert,
    run,
    show,
    >>


#
# Pipeline interface.
#

"""
    Pipeline(op, args...)

A pipeline is a transformation of monadic queries.

Parameter `op` is a function that performs the transformation; `args` are extra
arguments passed to the function.

The pipeline transforms an input monadic query `q` by invoking `op` with
the following arguments:

    op(env::Environment, q::Query, args...)

The result of `op` must again be a monadic query.
"""
struct Pipeline <: AbstractPipeline
    op
    args::Vector{Any}

    Pipeline(op, args::Vector{Any}) =
        new(op, args)
end

Pipeline(op, args...) =
    Pipeline(op, collect(Any, args))

syntax(F::Pipeline) =
    syntax(F.op, F.args)

show(io::IO, F::Pipeline) =
    print_expr(io, syntax(F))


#
# Navigation sugar.
#

"""
    It

Identity pipeline with respect to pipeline composition.

    It.a.b.c

Equivalent to `Get(:a) >> Get(:b) >> Get(:c)`.
"""
struct Navigation <: AbstractPipeline
    __path::Tuple{Vararg{Symbol}}
end

Base.getproperty(nav::Navigation, s::Symbol) =
    let path = getfield(nav, :__path)
        Navigation((path..., s))
    end

show(io::IO, nav::Navigation) =
    let path = getfield(nav, :__path)
        print(io, join((:It, path...), "."))
    end

const It = Navigation(())


#
# Running a pipeline.
#

"""
    run(F::AbstractPipeline; params...)

Runs the pipeline with the given parameters.
"""
run(F::AbstractPipeline; params...) =
    execute(F, sort(collect(Pair{Symbol,DataKnot}, params), by=first))

run(F::Pair{Symbol,<:AbstractPipeline}; params...) =
    run(Lift(F); params...)

run(db::DataKnot, F; params...) =
    run(db >> Each(F); params...)

function execute(F::AbstractPipeline, params::Vector{Pair{Symbol,DataKnot}}=Pair{Symbol,DataKnot}[])
    q = prepare(F, params)
    input = pack(q, params)
    output = q(input)
    return unpack(q, output)
end

prepare(F::AbstractPipeline, slots::Vector{Pair{Symbol,OutputShape}}=Pair{Symbol,OutputShape}[]) =
    optimize(apply(F, Environment(slots), stub()))

prepare(F::AbstractPipeline, params::Vector{Pair{Symbol,DataKnot}}) =
    prepare(F, Pair{Symbol,OutputShape}[param.first => shape(param.second) for param in params])

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
            push!(cols, BlockVector(length(elts) == 1 ? (:) : [1, length(elts)+1], elts, cardinality(slot.second)))
        end
        return TupleVector(1, AbstractVector[data, TupleVector(1, cols)])
    end
end

unpack(q, output) =
    DataKnot(elements(output), shape(q))


#
# Applying a pipeline to a query.
#

"""
    Environment()

Pipeline execution state.
"""
mutable struct Environment
    slots::Vector{Pair{Symbol,OutputShape}}
end

Environment() = Environment([])

apply(F, env::Environment, q::Query)::Query =
    apply(Lift(F), env, q)

function apply(db::DataKnot, env::Environment, q::Query)::Query
    r = block_filler(elements(db), cardinality(db)) |> designate(InputShape(AnyShape()), shape(db))
    compose(q, r)
end

apply(F::Pipeline, env::Environment, q::Query)::Query =
    F.op(env, q, F.args...)

function apply(nav::Navigation, env::Environment, q::Query)::Query
    for fld in getfield(nav, :__path)
        q = Get(env, q, fld)
    end
    q
end


#
# Monadic composition.
#

stub(dr::Decoration, shp::AbstractShape) =
    wrap() |> designate(InputShape(dr, shp), OutputShape(dr, shp))

stub() =
    stub(Decoration(), NativeShape(Nothing))

stub(db::DataKnot) =
    stub(decoration(db), domain(db))

stub(q::Query) =
    stub(decoration(q), domain(q))

istub(q::Query) =
    stub(idecoration(q), idomain(q))

compose(q::Query) = q

compose(q1::Query, q2::Query, q3::Query, qs::Query...) =
    foldl(compose, qs, init=compose(compose(q1, q2), q3))

function compose(q1::Query, q2::Query)
    @assert fits(domain(q1), idomain(q2))
    imd = ibound(imode(q1), imode(q2))
    md = bound(mode(q1), mode(q2))
    chain_of(
        duplicate_input(imd),
        within_input(imd, narrow_input(imd, q1)),
        distribute(imd, mode(q1)),
        within_output(mode(q1), narrow_input(imd, q2)),
        flatten_output(mode(q1), mode(q2)),
    ) |> designate(InputShape(idecoration(q1), idomain(q1), imd),
                   OutputShape(decoration(q2), domain(q2), md))
end

duplicate_input(md::InputMode) =
    if isfree(md)
        pass()
    else
        tuple_of(pass(), column(2))
    end

within_input(md::InputMode, q::Query) =
    if isfree(md)
        q
    else
        with_column(1, q)
    end

distribute(imd::InputMode, md::OutputMode) =
    if isfree(imd)
        pass()
    else
        distribute(1)
    end

within_output(md::OutputMode, q::Query) =
    with_elements(q)

function narrow_input(md1::InputMode, md2::InputMode)
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

narrow_input(md::InputMode) =
    narrow_input(md, InputMode())

narrow_input(md::InputMode, q::Query) =
    chain_of(narrow_input(md, imode(q)), q)

flatten_output(md1::OutputMode, md2::OutputMode) =
    flatten()

>>(X::Union{AbstractPipeline,Pair{Symbol,<:AbstractPipeline}}, Xs...) =
    Compose(X, Xs...)

Compose(X, Xs...) =
    Pipeline(Compose, X, Xs...)

syntax(::typeof(Compose), args::Vector{Any}) =
    syntax(>>, args)

function Compose(env::Environment, q::Query, Xs...)
    for X in Xs
        q = apply(X, env, q)
    end
    q
end


#
# Record combinator.
#

function monadic_record(q::Query, xs::Vector{Query})
    ishp = ibound(ishape.(xs))
    shp = OutputShape(decoration(q), RecordShape(shape.(xs)))
    lbls = Symbol[let lbl = label(shape(x)); lbl !== nothing ? lbl : Symbol("#$i") end for (i, x) in enumerate(xs)]
    r = chain_of(
        tuple_of(lbls, [narrow_input(mode(ishp), x) for x in xs]),
        wrap(),
    ) |> designate(ishp, shp)
    compose(q, r)
end

"""
    Record(Xs...)

Creates a pipeline component for building a record.
"""
Record(Xs...) =
    Pipeline(Record, Xs...)

function Record(env::Environment, q::Query, Xs...)
    xs = apply.(collect(AbstractPipeline, Xs), Ref(env), Ref(stub(q)))
    monadic_record(q, xs)
end


#
# Lifting Julia values and functions.
#

function monadic_lift(f, xs::Vector{Query})
    ity = Tuple{eltype.(shape.(xs))...}
    oty = Core.Compiler.return_type(f, ity)
    oty != Union{} || error("cannot apply $f to $ity")
    tail = wrap()
    card = x1to1
    if oty <: AbstractVector
        oty = eltype(oty)
        tail = adapt_vector()
        card = x0toN
    elseif Missing <: oty
        oty = Base.nonmissingtype(oty)
        tail = adapt_missing()
        card = x0to1
    end
    ishp = ibound(ishape.(xs))
    shp = OutputShape(NativeShape(oty), card)
    q = if length(xs) == 1
            chain_of(xs[1], lift(f), tail)
        else
            chain_of(
                tuple_of(Symbol[], [narrow_input(mode(ishp), x) for x in xs]),
                tuple_lift(f),
                tail)
        end
    q |> designate(ishp, shp)
end

Lift(X::AbstractPipeline) = X

"""
    Lift(val)

Converts a Julia value to a pipeline primitive.
"""
Lift(val) =
    Pipeline(Lift, val)

"""
    Lift(f, Xs)

Converts a Julia function to a pipeline combinator.
"""
Lift(f, Xs::Tuple) =
    Pipeline(Lift, f, Xs)

convert(::Type{AbstractPipeline}, val) =
    Lift(val)

convert(::Type{AbstractPipeline}, F::AbstractPipeline) =
    F

Lift(env::Environment, q::Query, val) =
    apply(convert(DataKnot, val), env, q)

function Lift(env::Environment, q::Query, f, Xs::Tuple)
    xs = apply.(collect(AbstractPipeline, Xs), Ref(env), Ref(stub(q)))
    compose(q, monadic_lift(f, xs))
end

# Broadcasting.

struct PipelineStyle <: Base.BroadcastStyle
end

Base.BroadcastStyle(::Type{<:Union{AbstractPipeline,Pair{Symbol,<:AbstractPipeline}}}) = PipelineStyle()

Base.BroadcastStyle(s::PipelineStyle, ::Broadcast.DefaultArrayStyle) = s

Base.broadcastable(X::Union{AbstractPipeline,Pair{Symbol,<:AbstractPipeline}}) = X

Base.Broadcast.instantiate(bc::Broadcast.Broadcasted{PipelineStyle}) = bc

Base.copy(bc::Broadcast.Broadcasted{PipelineStyle}) =
    BroadcastLift(bc)

BroadcastLift(bc::Broadcast.Broadcasted{PipelineStyle}) =
    BroadcastLift(bc.f, (BroadcastLift.(bc.args)...,))

BroadcastLift(val) = val

BroadcastLift(f, Xs) = Pipeline(BroadcastLift, f, Xs)

BroadcastLift(env::Environment, q::Query, args...) =
    Lift(env, q, args...)

syntax(::typeof(BroadcastLift), args::Vector{Any}) =
    syntax(broadcast, Any[args[1], syntax.(args[2])...])

Lift(bc::Broadcast.Broadcasted{PipelineStyle}) =
    BroadcastLift(bc)


#
# Each combinator.
#

"""
    Each(X)

Makes `X` process its input elementwise.
"""
Each(X) = Pipeline(Each, X)

Each(env::Environment, q::Query, X) =
    compose(q, apply(X, env, stub(q)))


#
# Assigning labels.
#

"""
    Label(lbl::Symbol)

Assigns a label.
"""
Label(lbl::Symbol) =
    Pipeline(Label, lbl)

Label(env::Environment, q::Query, lbl::Symbol) =
    q |> designate(ishape(q), shape(q) |> decorate(label=lbl))

Lift(p::Pair{Symbol}) =
    Compose(p.second, Label(p.first))


#
# Assigning a name to a pipeline.
#

"""
    Tag(name::Symbol, X)

Assigns a name to a pipeline.
"""
Tag(name::Symbol, X) =
    Pipeline(Tag, name, X)

Tag(name::Symbol, args::Tuple, X) =
    Pipeline(Tag, name, args, X)

Tag(F::Union{Function,DataType}, args::Tuple, X) =
    Tag(nameof(F), args, X)

Tag(env::Environment, q::Query, name, X) =
    apply(X, env, q)

Tag(env::Environment, q::Query, name, args, X) =
    apply(X, env, q)

syntax(::typeof(Tag), args::Vector{Any}) =
    syntax(Tag, args...)

syntax(::typeof(Tag), name::Symbol, X) =
    name

syntax(::typeof(Tag), name::Symbol, args::Tuple, X) =
    Expr(:call, name, syntax.(args)...)


#
# Attributes and parameters.
#

"""
    Get(name)

Finds an attribute or a parameter.
"""
Get(name) =
    Pipeline(Get, name)

function Get(env::Environment, q::Query, name)
    r = lookup(env, name)
    if r == nothing
        r = lookup(domain(q), name)
    end
    if r == nothing
        error("cannot find $name at\n$(sigsyntax(domain(q)))")
    end
    compose(q, r)
end

lookup(env::Environment, ::Any) = nothing

function lookup(env::Environment, name::Symbol)
    for slot in env.slots
        if slot.first == name
            shp = slot.second
            ishp = InputShape(AnyShape(), [slot])
            return chain_of(
                    column(2),
                    column(1)
            ) |> designate(ishp, shp)
        end
    end
    return nothing
end

lookup(::AbstractShape, ::Any) = missing

function lookup(shp::RecordShape, name::Symbol)
    for fld in shp.flds
        lbl = label(fld)
        if lbl == name
            return column(lbl) |> designate(InputShape(shp), fld)
        end
    end
    return nothing
end

lookup(shp::NativeShape, name) =
    lookup(shp.ty, name)

lookup(::Type, ::Any) =
    nothing

function lookup(ity::Type{<:NamedTuple}, name::Symbol)
    j = findfirst(isequal(name), ity.parameters[1])
    if j === nothing
        return nothing
    end
    oty = ity.parameters[2].parameters[j]
    f = t -> t[j]
    tail = wrap()
    card = x1to1
    if oty <: AbstractVector
        oty = eltype(oty)
        tail = adapt_vector()
        card = x0toN
    elseif Missing <: oty
        oty = Base.nonmissingtype(oty)
        tail = adapt_missing()
        card = x0to1
    end
    ishp = InputShape(ity)
    shp = OutputShape(name, NativeShape(oty), card)
    r = chain_of(lift(f), tail) |> designate(ishp, shp)
    r
end


#
# Specifying parameters.
#

function monadic_given(p::Query, q::Query)
    name = label(shape(p))
    if name === nothing
        error("parameter name is not specified")
    end
    if !any(slot.first == name for slot in slots(ishape(q)))
        return q
    end
    slots′ = copy(slots(q))
    splice!(slots′, searchsorted(first.(slots′), name))
    imd = ibound(InputMode(slots′, isframed(q)), imode(p))
    cs = Query[]
    if isframed(q)
        push!(cs, chain_of(column(2), column(1)))
    end
    for slot in slots(q)
        if slot.first == name
            push!(cs, narrow_input(imd, p))
        else
            idx = searchsortedfirst(slots(imd), slot, by=first)
            push!(cs, chain_of(column(2), column(idx + isframed(imd))))
        end
    end
    chain_of(
        tuple_of(
            narrow_input(imd),
            tuple_of(cs...)),
        q,
    ) |> designate(InputShape(ibound(idomain(q), idomain(p)), imd), shape(q))
end

"""
    Given(P, X)

Specifies the parameter.
"""
Given(P, X) =
    Pipeline(Given, P, X)

Given(P, Q, rest...) =
    Pipeline(Given, P, Q, rest...)

Given(env::Environment, q::Query, P, Q, rest...) =
    Given(env, q, P, Given(Q, rest...))

function Given(env::Environment, q::Query, P, X)
    q0 = stub(q)
    p = apply(P, env, q0)
    name = label(shape(p))
    slots′ = copy(env.slots)
    if name !== nothing
        splice!(slots′, searchsorted(first.(slots′), name), [name => shape(p)])
    end
    env′ = Environment(slots′)
    x = apply(X, env′, q0)
    compose(q, monadic_given(p, x))
end


#
# Then sugar.
#

Then(q::Query) =
    Pipeline(Then, q)

Then(env::Environment, q::Query, q′::Query) =
    compose(q, q′)

Then(ctor) =
    Pipeline(Then, ctor)

Then(ctor, args::Tuple) =
    Pipeline(Then, ctor, args)

Then(env::Environment, q::Query, ctor, args::Tuple=()) =
    apply(ctor(Then(q), args...), env, istub(q))


#
# Count and other aggregate combinators.
#

function monadic_count(q::Query)
    chain_of(
        q,
        block_length(),
        wrap(),
    ) |> designate(ishape(q), OutputShape(Int))
end

"""
    Count(X)
    X >> Count

Counts the number of elements produced by `X`.
"""
Count(X) =
    Pipeline(Count, X)

Lift(::typeof(Count)) =
    Then(Count)

function Count(env::Environment, q::Query, X)
    x = apply(X, env, stub(q))
    compose(q, monadic_count(x))
end

function monadic_aggregate(f, q::Query, hasdefault=true)
    ity = Tuple{AbstractVector{eltype(domain(q))}}
    oty = Core.Compiler.return_type(f, ity)
    oty != Union{} || error("cannot apply $f to $ity")
    if hasdefault || !fits(x0to1, cardinality(q))
        chain_of(
            q,
            block_lift(f),
            wrap(),
        ) |> designate(ishape(q), OutputShape(domain(q)))
    else
        chain_of(
            q,
            block_lift(f, missing),
            adapt_missing(),
        ) |> designate(ishape(q), OutputShape(domain(q), x0to1))
    end
end

"""
    Sum(X)
    X >> Sum

Sums the elements produced by `X`.
"""
Sum(X) =
    Pipeline(Sum, X)

Lift(::typeof(Sum)) =
    Then(Sum)

"""
    Max(X)
    X >> Max

Finds the maximum.
"""
Max(X) =
    Pipeline(Max, X)

Lift(::typeof(Max)) =
    Then(Max)

"""
    Min(X)
    X >> Min

Finds the minimum.
"""
Min(X) =
    Pipeline(Min, X)

Lift(::typeof(Min)) =
    Then(Min)

function Sum(env::Environment, q::Query, X)
    x = apply(X, env, stub(q))
    compose(q, monadic_aggregate(sum, x))
end

function Max(env::Environment, q::Query, X)
    x = apply(X, env, stub(q))
    compose(q, monadic_aggregate(maximum, x, false))
end

function Min(env::Environment, q::Query, X)
    x = apply(X, env, stub(q))
    compose(q, monadic_aggregate(minimum, x, false))
end


#
# Filter combinator.
#

function monadic_filter(q::Query, p::Query)
    fits(domain(p), NativeShape(Bool)) || error("expected a predicate")
    r = chain_of(
        tuple_of(
            narrow_input(imode(p)),
            chain_of(p, block_any())),
        sieve(),
    ) |> designate(ishape(p), OutputShape(decoration(q), domain(q), x0to1))
    compose(q, r)
end

"""
    Filter(X)

Filters the input by condition.
"""
Filter(X) =
    Pipeline(Filter, X)

function Filter(env::Environment, q::Query, X)
    x = apply(X, env, stub(q))
    monadic_filter(q, x)
end


#
# Take and Drop combinators.
#

monadic_take(q::Query, n::Int, rev::Bool) =
    chain_of(
        q,
        slice(n, rev),
    ) |> designate(ishape(q), OutputShape(decoration(q), domain(q), bound(mode(q), OutputMode(x0to1))))

function monadic_take(q::Query, n::Query, rev::Bool)
    fits(domain(n), NativeShape(Int)) || error("expected an integer query")
    ishp = ibound(ishape(q), ishape(n))
    chain_of(
        tuple_of(
            narrow_input(mode(ishp), q),
            chain_of(narrow_input(mode(ishp), n),
                     fits(x0to1, cardinality(n)) ?
                        block_lift(first, missing) :
                        block_lift(first))),
        slice(rev),
    ) |> designate(ishp, OutputShape(decoration(q), domain(q), bound(mode(q), OutputMode(x0to1))))
end

"""
    Take(N)

Takes the first `N` elements.
"""
Take(N) =
    Pipeline(Take, N)

"""
    Drop(N)

Drops the first `N` elements.
"""
Drop(N) =
    Pipeline(Drop, N)

Take(env::Environment, q::Query, ::Missing, rev::Bool=false) =
    q

Take(env::Environment, q::Query, n::Int, rev::Bool=false) =
    monadic_take(q, n, rev)

function Take(env::Environment, q::Query, N, rev::Bool=false)
    n = apply(N, env, istub(q))
    monadic_take(q, n, rev)
end

Drop(env::Environment, q::Query, N) =
    Take(env, q, N, true)

