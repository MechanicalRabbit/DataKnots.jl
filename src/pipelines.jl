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

A pipeline is a query transformation.  Specifically, it takes a query that maps
*origin* to *input* and generates a query that maps *origin* to *output*.

Parameter `op` is a function that performs the transformation; `args` are extra
arguments passed to the function.

The pipeline transforms an input query `q` by invoking `op` with the following
arguments:

    op(env::Environment, q::Query, args...)

The result of `op` must again be the output query.
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

Equivalent to `Lookup(:a) >> Lookup(:b) >> Lookup(:c)`.
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
    run(db::DataKnot, F::AbstractPipeline; params...)

Runs the pipeline with the given parameters.
"""
run(db::DataKnot, F; params...) =
    execute(db, Lift(F), sort(collect(Pair{Symbol,DataKnot}, params), by=first))

run(F::Union{AbstractPipeline,Pair{Symbol,<:AbstractPipeline}}; params...) =
    run(DataKnot(nothing), F; params...)

function execute(db::DataKnot, F::AbstractPipeline, params::Vector{Pair{Symbol,DataKnot}}=Pair{Symbol,DataKnot}[])
    db = pack(db, params)
    q = prepare(F, shape(db))
    println(F)
    println(q)
    db′ = q(db)
    return db′
end

prepare(db::DataKnot, F::AbstractPipeline, params::Vector{Pair{Symbol,DataKnot}}=Pair{Symbol,DataKnot}[]) =
    prepare(F, shape(pack(db, params)))

function pack(db::DataKnot, params::Vector{Pair{Symbol,DataKnot}})
    !isempty(params) || return db
    ctx_lbls = first.(params)
    ctx_cols = collect(AbstractVector, cell.(last.(params)))
    ctx_shps = collect(AbstractShape, shape.(last.(params)))
    return DataKnot(TupleVector(1, AbstractVector[cell(db), TupleVector(ctx_lbls, 1, ctx_cols)]),
                    TupleOf(shape(db), TupleOf(ctx_lbls, ctx_shps)) |> IsScope)
end

function prepare(F::AbstractPipeline, ishp::AbstractShape)
    env = Environment()
    q_i = adapt_input(ishp)
    q_F = compile(Each(F), env, stub(q_i))
    q_o = adapt_output(BlockOf(elements(shape(q_F)), cardinality(shape(q_i))|cardinality(shape(q_F))) |> IsFlow)
    shp = shape(q_o)
    return chain_of(q_i, with_elements(q_F), flatten(), q_o) |> designate(ishp, shp) |> optimize
end

adapt_input(ishp::IsScope) =
    adapt_flow(ishp)

function adapt_input(ishp::AbstractShape)
    q = tuple_of(pass(), tuple_of())
    shp = TupleOf(ishp, TupleOf()) |> IsScope
    t = adapt_input(shp)
    shp = shape(t)
    chain_of(q, t) |> designate(ishp, shp)
end

function adapt_output(ishp::IsFlow)
    q = adapt_output(elements(ishp))
    lbl = nothing
    shp = shape(q)
    if shp isa HasLabel
        lbl = label(shp)
        shp = subject(shp)
    end
    shp = BlockOf(shp, cardinality(ishp))
    if lbl !== nothing
        shp = shp |> HasLabel(lbl)
    end
    with_elements(q) |> designate(ishp, shp)
end

adapt_output(ishp::IsScope) =
    column(1) |> designate(ishp, column(ishp))

adapt_output(ishp::AbstractShape) =
    pass() |> designate(ishp, ishp)

adapt_flow(ishp::AbstractShape) =
    wrap() |> designate(ishp, BlockOf(ishp, x1to1) |> IsFlow)

adapt_flow(ishp::BlockOf) =
    pass() |> designate(ishp, ishp |> IsFlow)

function adapt_flow(ishp::ValueOf)
    ty = eltype(ishp)
    if ty <: AbstractVector
        ty′ = eltype(ty)
        adapt_vector() |> designate(ishp, BlockOf(ty′, x0toN) |> IsFlow)
    elseif Missing <: ty
        ty′ = Base.nonmissingtype(ty)
        adapt_missing() |> designate(ishp, BlockOf(ty′, x0to1) |> IsFlow)
    else
        wrap() |> designate(ishp, BlockOf(ishp, x1to1) |> IsFlow)
    end
end

function adapt_flow(ishp::HasLabel)
    q = adapt_flow(subject(ishp))
    shp = with_elements(shape(q), HasLabel(label(ishp)))
    q |> designate(ishp, shp)
end

adapt_flow(ishp::IsFlow) =
    pass() |> designate(ishp, ishp)

function adapt_flow(ishp::IsScope)
    q = adapt_flow(column(ishp))
    shp = shape(q)
    shp = with_elements(shp, TupleOf(elements(shp), context(ishp)) |> IsScope)
    if width(context(ishp)) > 0
        chain_of(with_column(1, q), distribute(1)) |> designate(ishp, shp)
    else
        chain_of(column(1), q, with_elements(tuple_of(pass(), tuple_of()))) |> designate(ishp, shp)
    end
end

function adapt_output(q::Query)
    r = adapt_output(shape(q))
    chain_of(q, r) |> designate(ishape(q), shape(r))
end

function adapt_flow(q::Query)
    r = adapt_flow(shape(q))
    chain_of(q, r) |> designate(ishape(q), shape(r))
end

function clone_context(ctx::TupleOf, q::Query)
    ishp = TupleOf(ishape(q), ctx) |> IsScope
    shp = with_elements(shape(q), elts -> TupleOf(elts, ctx) |> IsScope)
    if width(ctx) > 0
        chain_of(with_column(1, q), distribute(1)) |> designate(ishp, shp)
    else
        chain_of(column(1), q, with_elements(tuple_of(pass(), tuple_of()))) |> designate(ishp, shp)
    end
end

function clone_context(q::Query)
    ishp = ishape(q)
    ctx = context(ishp)
    shp = TupleOf(shape(q), ctx) |> IsScope
    tuple_of(q, column(2)) |> designate(ishp, shp)
end



#
# Applying a pipeline to a query.
#

"""
    Environment()

Pipeline execution state.
"""
mutable struct Environment
end

compile(F, env::Environment, q::Query)::Query =
    compile(Lift(F), env, q)

function compile(db::DataKnot, env::Environment, q::Query)::Query
    r = block_filler(cell(db), x1to1)
    t = adapt_flow(shape(db))
    r = chain_of(r, with_elements(t), flatten()) |> designate(AnyShape(), shape(t))
    r = clone_context(context(elements(shape(q))), r)
    compose(q, r)
end

compile(F::Pipeline, env::Environment, q::Query)::Query =
    F.op(env, q, F.args...)

function compile(nav::Navigation, env::Environment, q::Query)::Query
    for fld in getfield(nav, :__path)
        q = Lookup(env, q, fld)
    end
    q
end


#
# Monadic composition.
#

function stub(ishp::AbstractShape)
    @assert ishp isa IsScope
    shp = BlockOf(ishp, x1to1) |> IsFlow
    wrap() |> designate(ishp, shp)
end

function stub(q::Query)
    shp = shape(q)
    @assert shp isa IsFlow
    stub(elements(shp))
end

function istub(q::Query)
    stub(ishape(q))
end

compose(q::Query) = q

compose(q1::Query, q2::Query, q3::Query, qs::Query...) =
    foldl(compose, qs, init=compose(compose(q1, q2), q3))

function compose(q1::Query, q2::Query)
    ishp1 = ishape(q1)
    shp1 = shape(q1)
    ishp2 = ishape(q2)
    shp2 = shape(q2)
    @assert shp1 isa IsFlow && shp2 isa IsFlow
    #@assert fits(elements(shp1), ishp2)
    ishp = ishp1
    shp = BlockOf(elements(shp2), cardinality(shp1)|cardinality(shp2)) |> IsFlow
    chain_of(
        q1,
        with_elements(q2),
        flatten(),
    ) |> designate(ishp, shp)
end

>>(X::Union{AbstractPipeline,Pair{Symbol,<:AbstractPipeline}}, Xs...) =
    Compose(X, Xs...)

Compose(X, Xs...) =
    Pipeline(Compose, X, Xs...)

syntax(::typeof(Compose), args::Vector{Any}) =
    syntax(>>, args)

function Compose(env::Environment, q::Query, Xs...)
    for X in Xs
        q = compile(X, env, q)
    end
    q
end


#
# Record combinator.
#

function monadic_record(q::Query, xs::Vector{Query})
    lbls = Symbol[]
    cols = Query[]
    seen = Dict{Symbol,Int}()
    for (i, x) in enumerate(xs)
        x = adapt_output(x)
        shp = shape(x)
        lbl = label(i)
        if shp isa HasLabel
            lbl = label(shp)
            shp = subject(shp)
            x = x |> designate(ishape(x), shp)
        end
        if lbl in keys(seen)
            lbls[seen[lbl]] = label(seen[lbl])
        end
        seen[lbl] = i
        push!(lbls, lbl)
        push!(cols, x)
    end
    ishp = elements(shape(q))
    shp = TupleOf(lbls, shape.(cols))
    r = tuple_of(lbls, cols) |> designate(ishp, shp)
    r = adapt_flow(clone_context(r))
    compose(q, r)
end

"""
    Record(Xs...)

Creates a pipeline component for building a record.
"""
Record(Xs...) =
    Pipeline(Record, Xs...)

function Record(env::Environment, q::Query, Xs...)
    xs = compile.(collect(AbstractPipeline, Xs), Ref(env), Ref(stub(q)))
    monadic_record(q, xs)
end


#
# Lifting Julia values and functions.
#

function monadic_lift(q::Query, f, xs::Vector{Query})
    cols = Query[]
    for x in xs
        x = adapt_output(x)
        push!(cols, x)
    end
    ity = Tuple{eltype.(shape.(cols))...}
    oty = Core.Compiler.return_type(f, ity)
    oty != Union{} || error("cannot compile $f to $ity")
    ishp = elements(shape(q))
    shp = ValueOf(oty)
    r = if length(cols) == 1
            if (cardinality(shape(xs[1])) & x1toN == x1toN) && !(oty <: AbstractVector)
                chain_of(cols[1], block_lift(f))
            else
                chain_of(cols[1], lift(f))
            end
        else
            chain_of(tuple_of(Symbol[], cols), tuple_lift(f))
        end |> designate(ishp, shp)
    r = adapt_flow(clone_context(r))
    compose(q, r)
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
    compile(convert(DataKnot, val), env, q)

function Lift(env::Environment, q::Query, f, Xs::Tuple)
    xs = compile.(collect(AbstractPipeline, Xs), Ref(env), Ref(stub(q)))
    monadic_lift(q, f, xs)
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
    compose(q, compile(X, env, stub(q)))


#
# Assigning labels.
#

replace_label(shp::AbstractShape, ::Nothing) =
    shp

replace_label(shp::AbstractShape, lbl::Symbol) =
    shp |> HasLabel(lbl)

replace_label(shp::HasLabel, ::Nothing) =
    subject(shp)

replace_label(shp::HasLabel, lbl::Symbol) =
    subject(shp) |> HasLabel(lbl)

replace_label(shp::IsFlow, ::Nothing) =
    with_elements(shp, elts -> replace_label(elts, nothing))

replace_label(shp::IsFlow, lbl::Symbol) =
    with_elements(shp, elts -> replace_label(elts, lbl))

replace_label(shp::IsScope, ::Nothing) =
    with_column(shp, col -> replace_label(col, nothing))

replace_label(shp::IsScope, lbl::Symbol) =
    with_column(shp, col -> replace_label(col, lbl))

"""
    Label(lbl::Symbol)

Assigns a label.
"""
Label(lbl::Symbol) =
    Pipeline(Label, lbl)

Label(env::Environment, q::Query, lbl::Symbol) =
    q |> designate(ishape(q), replace_label(shape(q), lbl))

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
    compile(X, env, q)

Tag(env::Environment, q::Query, name, args, X) =
    compile(X, env, q)

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
    shp = shape(q)
    r = lookup(context(elements(shp)), name)
    if r !== nothing
        r = chain_of(column(2), r) |> designate(elements(shp), shape(r))
    else
        r = lookup(column(elements(shp)), name)
        if r !== nothing
            r = chain_of(column(1), r) |> designate(elements(shp), shape(r))
        else
            error("cannot find $name at\n$(sigsyntax(column(elements(shp))))")
        end
    end
    r = adapt_flow(clone_context(r))
    compose(q, r)
end

const Lookup = Get

lookup(::AbstractShape, ::Any) = nothing

lookup(shp::HasLabel, name::Any) =
    lookup(subject(shp), name)

function lookup(lbls::Vector{Symbol}, name::Symbol)
    j = findlast(isequal(name), lbls)
    if j === nothing
        j = findlast(isequal(Symbol("#$name")), lbls)
    end
    j
end

function lookup(ishp::TupleOf, name::Symbol)
    lbls = labels(ishp)
    if isempty(lbls)
        lbls = Symbol[label(i) for i = 1:width(ishp)]
    end
    j = lookup(lbls, name)
    j !== nothing || return nothing
    shp = replace_label(column(ishp, j), name == lbls[j] ? name : nothing)
    column(lbls[j]) |> designate(ishp, shp)
end

lookup(shp::ValueOf, name) =
    lookup(shp.ty, name)

lookup(::Type, ::Any) =
    nothing

function lookup(ity::Type{<:NamedTuple}, name::Symbol)
    j = lookup(collect(Symbol, ity.parameters[1]), name)
    j !== nothing || return nothing
    oty = ity.parameters[2].parameters[j]
    lift(t -> t[j]) |> designate(ValueOf(ity), ValueOf(oty) |> HasLabel(name))
end


#
# Specifying parameters.
#

function monadic_keep(q::Query, p::Query)
    p = adapt_output(p)
    shp = shape(p)
    shp isa HasLabel || error("parameter name is not specified")
    name = label(shp)
    shp = subject(shp)
    ishp = ishape(p)
    ctx = context(ishp)
    lbls′ = Symbol[]
    cols′ = AbstractShape[]
    perm = Int[]
    for j = 1:width(ctx)
        lbl = label(ctx, j)
        if lbl != name
            push!(lbls′, lbl)
            push!(cols′, column(ctx, j))
            push!(perm, j)
        end
    end
    push!(lbls′, name)
    push!(cols′, shp)
    ctx′ = TupleOf(lbls′, cols′)
    ps = Query[chain_of(column(2), column(j)) for j in perm]
    push!(ps, p)
    shp = BlockOf(TupleOf(column(ishp), ctx′) |> IsScope, x1to1) |> IsFlow
    r = chain_of(tuple_of(column(1),
                          tuple_of(lbls′, ps)),
                 wrap(),
    ) |> designate(ishp, shp)
    compose(q, r)
end

"""
    Keep(P)

Specifies the parameter.
"""

Keep(P, Qs...) =
    Pipeline(Keep, P, Qs...)

Keep(env::Environment, q::Query, P, Qs...) =
    Keep(env, Keep(env, q, P), Qs...)

function Keep(env::Environment, q::Query, P)
    p = compile(P, env, stub(q))
    monadic_keep(q, p)
end


#
# Scope of parameters.
#

function monadic_given(q::Query, x::Query)
    x = adapt_flow(clone_context(adapt_output(x)))
    compose(q, x)
end

"""
    Given(P, X)

Specifies the parameter in a bounded scope.
"""
Given(P, Qs...) =
    Pipeline(Given, P, Qs...)

Given(env::Environment, q::Query, Ps...) =
    Given(env, q, Keep(Ps[1:end-1]...) >> Ps[end])

function Given(env::Environment, q::Query, X)
    x = compile(X, env, stub(q))
    monadic_given(q, x)
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
    compile(ctor(Then(q), args...), env, istub(q))


#
# Count and other aggregate combinators.
#

function monadic_count(q::Query)
    q = adapt_output(q)
    r = chain_of(q,
                block_length(),
                wrap(),
    ) |> designate(ishape(q), ValueOf(Int))
    adapt_flow(clone_context(r))
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
    x = compile(X, env, stub(q))
    compose(q, monadic_count(x))
end

function monadic_aggregate(f, q::Query, hasdefault=true)
    ity = Tuple{AbstractVector{eltype(domain(q))}}
    oty = Core.Compiler.return_type(f, ity)
    oty != Union{} || error("cannot compile $f to $ity")
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
    x = compile(X, env, stub(q))
    monadic_lift(q, sum, Query[x])
end

maximum_missing(v) =
    !isempty(v) ? maximum(v) : missing

function Max(env::Environment, q::Query, X)
    x = compile(X, env, stub(q))
    optional = cardinality(shape(x)) & x0to1 == x0to1
    monadic_lift(q, optional ? maximum_missing : maximum, Query[x])
end

minimum_missing(v) =
    !isempty(v) ? minimum(v) : missing

function Min(env::Environment, q::Query, X)
    x = compile(X, env, stub(q))
    optional = cardinality(shape(x)) & x0to1 == x0to1
    monadic_lift(q, optional ? minimum_missing : minimum, Query[x])
end


#
# Filter combinator.
#

function monadic_filter(q::Query, p::Query)
    p = adapt_output(p)
    # fits(shape(p), BlockOf(ValueOf(Bool))) || error("expected a predicate")
    r = chain_of(tuple_of(pass(),
                          chain_of(p, block_any())),
                 sieve(),
    ) |> designate(ishape(p), BlockOf(ishape(p), x0to1) |> IsFlow)
    compose(q, r)
end

"""
    Filter(X)

Filters the input by condition.
"""
Filter(X) =
    Pipeline(Filter, X)

function Filter(env::Environment, q::Query, X)
    x = compile(X, env, stub(q))
    monadic_filter(q, x)
end


#
# Take and Drop combinators.
#

monadic_take(q::Query, n::Int, rev::Bool) =
    chain_of(
        q,
        slice(n, rev),
    ) |> designate(ishape(q),
                   BlockOf(elements(shape(q)), cardinality(shape(q))|x0to1) |> IsFlow)

function monadic_take(q::Query, n::Query, rev::Bool)
    n = adapt_output(n)
    #fits(elements(n), ValueOf(Int)) || error("expected an integer query")
    ishp = ishape(q)
    shp = BlockOf(elements(shape(q)), cardinality(shape(q))|x0to1) |> IsFlow
    chain_of(
        tuple_of(
            q,
            chain_of(n, fits(x0to1, cardinality(shape(n))) ? block_lift(first, missing) : block_lift(first))),
        slice(rev),
    ) |> designate(ishp, shp)
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
    n = compile(N, env, istub(q))
    monadic_take(q, n, rev)
end

Drop(env::Environment, q::Query, N) =
    Take(env, q, N, true)

