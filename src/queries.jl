#
# Algebra of queries.
#

import Base:
    convert,
    getindex,
    show,
    >>


#
# Query interface.
#

abstract type AbstractQuery end

"""
    Query(op, args...)

A query is implemented as a pipeline compiler.  Specifically, it takes a
pipeline that maps *origin* to *input* and generates a pipeline that maps
*origin* to *output*.

Parameter `op` is a function that performs the transformation; `args` are extra
arguments passed to the function.

The query transforms an input pipeline `p` by invoking `op` with the following
arguments:

    op(env::Environment, q::Pipeline, args...)

The result of `op` must be the output pipeline.
"""
struct Query <: AbstractQuery
    op
    args::Vector{Any}

    Query(op, args::Vector{Any}) =
        new(op, args)
end

Query(op, args...) =
    Query(op, collect(Any, args))

syntax(F::Query) =
    syntax(F.op, F.args)

show(io::IO, F::Query) =
    print_expr(io, syntax(F))


#
# Navigation sugar.
#

"""
    It

Identity query with respect to the query composition.

    It.a.b.c

Equivalent to `Get(:a) >> Get(:b) >> Get(:c)`.
"""
struct Navigation <: AbstractQuery
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
# Applying a query.
#

"""
    db::DataKnot[F::Query] :: DataKnot

Queries `db` with `F`.
"""
getindex(db::DataKnot, F; kws...) =
    execute(db, Lift(F), sort(collect(Pair{Symbol,DataKnot}, kws), by=first))

Base.run(db::DataKnot, F; kws...) =
    getindex(db, F; kws...)

Base.run(F::Union{AbstractQuery,DataKnot,Pair{Symbol,<:Union{AbstractQuery,DataKnot}}}; kws...) =
    run(DataKnot(), F; kws...)

function execute(db::DataKnot, F::AbstractQuery, params::Vector{Pair{Symbol,DataKnot}}=Pair{Symbol,DataKnot}[])
    db = pack(db, params)
    q = prepare(F, shape(db))
    db′ = q(db)
    return db′
end

prepare(db::DataKnot, F::AbstractQuery, params::Vector{Pair{Symbol,DataKnot}}=Pair{Symbol,DataKnot}[]) =
    prepare(F, shape(pack(db, params)))

function pack(db::DataKnot, params::Vector{Pair{Symbol,DataKnot}})
    !isempty(params) || return db
    ctx_lbls = first.(params)
    ctx_cols = collect(AbstractVector, cell.(last.(params)))
    ctx_shps = collect(AbstractShape, shape.(last.(params)))
    return DataKnot(TupleVector(1, AbstractVector[cell(db), TupleVector(ctx_lbls, 1, ctx_cols)]),
                    TupleOf(shape(db), TupleOf(ctx_lbls, ctx_shps)) |> IsScope)
end

function prepare(F::AbstractQuery, ishp::AbstractShape)
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
    p = tuple_of(pass(), tuple_of())
    shp = TupleOf(ishp, TupleOf()) |> IsScope
    q = adapt_input(shp)
    shp = shape(q)
    chain_of(p, q) |> designate(ishp, shp)
end

function adapt_output(ishp::IsFlow)
    p = adapt_output(elements(ishp))
    lbl = nothing
    shp = shape(p)
    if shp isa HasLabel
        lbl = label(shp)
        shp = subject(shp)
    end
    shp = BlockOf(shp, cardinality(ishp))
    if lbl !== nothing
        shp = shp |> HasLabel(lbl)
    end
    with_elements(p) |> designate(ishp, shp)
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
    p = adapt_flow(subject(ishp))
    shp = with_elements(shape(p), HasLabel(label(ishp)))
    p |> designate(ishp, shp)
end

adapt_flow(ishp::IsFlow) =
    pass() |> designate(ishp, ishp)

function adapt_flow(ishp::IsScope)
    p = adapt_flow(column(ishp))
    shp = shape(p)
    shp = with_elements(shp, TupleOf(elements(shp), context(ishp)) |> IsScope)
    if width(context(ishp)) > 0
        chain_of(with_column(1, p), distribute(1)) |> designate(ishp, shp)
    else
        chain_of(column(1), p, with_elements(tuple_of(pass(), tuple_of()))) |> designate(ishp, shp)
    end
end

function adapt_output(p::Pipeline)
    q = adapt_output(shape(p))
    chain_of(p, q) |> designate(ishape(p), shape(q))
end

function adapt_flow(p::Pipeline)
    q = adapt_flow(shape(p))
    chain_of(p, q) |> designate(ishape(p), shape(q))
end

function clone_context(ctx::TupleOf, p::Pipeline)
    ishp = TupleOf(ishape(p), ctx) |> IsScope
    shp = with_elements(shape(p), elts -> TupleOf(elts, ctx) |> IsScope)
    if width(ctx) > 0
        chain_of(with_column(1, p), distribute(1)) |> designate(ishp, shp)
    else
        chain_of(column(1), p, with_elements(tuple_of(pass(), tuple_of()))) |> designate(ishp, shp)
    end
end

function clone_context(p::Pipeline)
    ishp = ishape(p)
    ctx = context(ishp)
    shp = TupleOf(shape(p), ctx) |> IsScope
    tuple_of(p, column(2)) |> designate(ishp, shp)
end


#
# Applying a query to a pipeline.
#

"""
    Environment()

Query compilation state.
"""
mutable struct Environment
end

compile(F, env::Environment, p::Pipeline)::Pipeline =
    compile(Lift(F), env, p)

compile(F::Query, env::Environment, p::Pipeline)::Pipeline =
    F.op(env, p, F.args...)

function compile(nav::Navigation, env::Environment, p::Pipeline)::Pipeline
    for fld in getfield(nav, :__path)
        p = Get(env, p, fld)
    end
    p
end


#
# Monadic composition.
#

function stub(ishp::AbstractShape)
    @assert ishp isa IsScope
    shp = BlockOf(ishp, x1to1) |> IsFlow
    wrap() |> designate(ishp, shp)
end

function stub(p::Pipeline)
    shp = shape(p)
    @assert shp isa IsFlow
    stub(elements(shp))
end

function istub(p::Pipeline)
    stub(ishape(p))
end

compose(p::Pipeline) = p

compose(p1::Pipeline, p2::Pipeline, p3::Pipeline, ps::Pipeline...) =
    foldl(compose, ps, init=compose(compose(p1, p2), p3))

function compose(p1::Pipeline, p2::Pipeline)
    ishp1 = ishape(p1)
    shp1 = shape(p1)
    ishp2 = ishape(p2)
    shp2 = shape(p2)
    @assert shp1 isa IsFlow && shp2 isa IsFlow
    #@assert fits(elements(shp1), ishp2)
    ishp = ishp1
    shp = BlockOf(elements(shp2), cardinality(shp1)|cardinality(shp2)) |> IsFlow
    chain_of(
        p1,
        with_elements(p2),
        flatten(),
    ) |> designate(ishp, shp)
end

>>(X::Union{DataKnot,AbstractQuery,Pair{Symbol,<:Union{DataKnot,AbstractQuery}}}, Xs...) =
    Compose(X, Xs...)

Compose(X, Xs...) =
    Query(Compose, X, Xs...)

syntax(::typeof(Compose), args::Vector{Any}) =
    syntax(>>, args)

function Compose(env::Environment, p::Pipeline, Xs...)
    for X in Xs
        p = compile(X, env, p)
    end
    p
end


#
# Record combinator.
#

function monadic_record(p::Pipeline, xs::Vector{Pipeline})
    lbls = Symbol[]
    cols = Pipeline[]
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
    ishp = elements(shape(p))
    shp = TupleOf(lbls, shape.(cols))
    if column(ishp) isa HasLabel
        shp = shp |> HasLabel(label(column(ishp)))
    end
    q = tuple_of(lbls, cols) |> designate(ishp, shp)
    q = adapt_flow(clone_context(q))
    compose(p, q)
end

"""
    Record(Xs...)

Creates a query component for building a record.
"""
Record(Xs...) =
    Query(Record, Xs...)

function Record(env::Environment, p::Pipeline, Xs...)
    xs = compile.(collect(AbstractQuery, Xs), Ref(env), Ref(stub(p)))
    monadic_record(p, xs)
end


#
# Lifting Julia values and functions.
#

function monadic_lift(p::Pipeline, f, xs::Vector{Pipeline})
    cols = Pipeline[]
    for x in xs
        x = adapt_output(x)
        push!(cols, x)
    end
    ity = Tuple{eltype.(shape.(cols))...}
    oty = Core.Compiler.return_type(f, ity)
    oty != Union{} || error("cannot apply $f to $ity")
    ishp = elements(shape(p))
    shp = ValueOf(oty)
    q = if length(cols) == 1
            if (cardinality(shape(xs[1])) & x1toN == x1toN) && !(oty <: AbstractVector)
                chain_of(cols[1], block_lift(f))
            else
                chain_of(cols[1], lift(f))
            end
        else
            chain_of(tuple_of(Symbol[], cols), tuple_lift(f))
        end |> designate(ishp, shp)
    q = adapt_flow(clone_context(q))
    compose(p, q)
end

Lift(X::AbstractQuery) = X

"""
    Lift(val)

Converts a Julia value to a query primitive.
"""
Lift(val) =
    Query(Lift, val)

"""
    Lift(f, Xs)

Converts a Julia function to a query combinator.
"""
Lift(f, Xs::Tuple) =
    Query(Lift, f, Xs)

convert(::Type{AbstractQuery}, val) =
    Lift(val)

convert(::Type{AbstractQuery}, F::AbstractQuery) =
    F

Lift(env::Environment, p::Pipeline, val) =
    Lift(env, p, convert(DataKnot, val))

function Lift(env::Environment, p::Pipeline, f, Xs::Tuple)
    xs = compile.(collect(AbstractQuery, Xs), Ref(env), Ref(stub(p)))
    monadic_lift(p, f, xs)
end

function Lift(env::Environment, p::Pipeline, db::DataKnot)
    q = block_filler(cell(db), x1to1)
    t = adapt_flow(shape(db))
    q = chain_of(q, with_elements(t), flatten()) |> designate(AnyShape(), shape(t))
    q = clone_context(context(elements(shape(p))), q)
    compose(p, q)
end

# Broadcasting.

struct QueryStyle <: Base.BroadcastStyle
end

Base.BroadcastStyle(::Type{<:Union{AbstractQuery,DataKnot,Pair{Symbol,<:Union{AbstractQuery,DataKnot}}}}) = QueryStyle()

Base.BroadcastStyle(s::QueryStyle, ::Broadcast.DefaultArrayStyle) = s

Base.broadcastable(X::Union{AbstractQuery,DataKnot,Pair{Symbol,<:Union{AbstractQuery,DataKnot}}}) = X

Base.Broadcast.instantiate(bc::Broadcast.Broadcasted{QueryStyle}) = bc

Base.copy(bc::Broadcast.Broadcasted{QueryStyle}) =
    BroadcastLift(bc)

BroadcastLift(bc::Broadcast.Broadcasted{QueryStyle}) =
    BroadcastLift(bc.f, (BroadcastLift.(bc.args)...,))

BroadcastLift(val) = val

BroadcastLift(f, Xs) = Query(BroadcastLift, f, Xs)

BroadcastLift(env::Environment, p::Pipeline, args...) =
    Lift(env, p, args...)

syntax(::typeof(BroadcastLift), args::Vector{Any}) =
    syntax(broadcast, Any[args[1], syntax.(args[2])...])

Lift(bc::Broadcast.Broadcasted{QueryStyle}) =
    BroadcastLift(bc)


#
# Each combinator.
#

"""
    Each(X)

Makes `X` process its input elementwise.
"""
Each(X) = Query(Each, X)

Each(env::Environment, p::Pipeline, X) =
    compose(p, compile(X, env, stub(p)))


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
    Query(Label, lbl)

Label(env::Environment, p::Pipeline, lbl::Symbol) =
    p |> designate(ishape(p), replace_label(shape(p), lbl))

Lift(p::Pair{Symbol}) =
    Compose(p.second, Label(p.first))


#
# Assigning a name to a query.
#

"""
    Tag(name::Symbol, X)

Assigns a name to a query.
"""
Tag(name::Symbol, X) =
    Query(Tag, name, X)

Tag(name::Symbol, args::Tuple, X) =
    Query(Tag, name, args, X)

Tag(F::Union{Function,DataType}, args::Tuple, X) =
    Tag(nameof(F), args, X)

Tag(env::Environment, p::Pipeline, name, X) =
    compile(X, env, p)

Tag(env::Environment, p::Pipeline, name, args, X) =
    compile(X, env, p)

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
    Query(Get, name)

function Get(env::Environment, p::Pipeline, name)
    shp = shape(p)
    q = lookup(context(elements(shp)), name)
    if q !== nothing
        q = chain_of(column(2), q) |> designate(elements(shp), shape(q))
    else
        q = lookup(column(elements(shp)), name)
        if q !== nothing
            q = chain_of(column(1), q) |> designate(elements(shp), shape(q))
        else
            error("cannot find $name at\n$(sigsyntax(column(elements(shp))))")
        end
    end
    q = adapt_flow(clone_context(q))
    compose(p, q)
end

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

function monadic_keep(p::Pipeline, q::Pipeline)
    q = adapt_output(q)
    shp = shape(q)
    shp isa HasLabel || error("parameter name is not specified")
    name = label(shp)
    shp = subject(shp)
    ishp = ishape(q)
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
    qs = Pipeline[chain_of(column(2), column(j)) for j in perm]
    push!(qs, q)
    shp = BlockOf(TupleOf(column(ishp), ctx′) |> IsScope, x1to1) |> IsFlow
    q = chain_of(tuple_of(column(1),
                          tuple_of(lbls′, qs)),
                 wrap(),
    ) |> designate(ishp, shp)
    compose(p, q)
end

"""
    Keep(P)

Specifies the parameter.
"""

Keep(P, Qs...) =
    Query(Keep, P, Qs...)

Keep(env::Environment, p::Pipeline, P, Qs...) =
    Keep(env, Keep(env, p, P), Qs...)

function Keep(env::Environment, p::Pipeline, P)
    q = compile(P, env, stub(p))
    monadic_keep(p, q)
end


#
# Scope of parameters.
#

function monadic_given(p::Pipeline, q::Pipeline)
    q = adapt_flow(clone_context(adapt_output(q)))
    compose(p, q)
end

"""
    Given(P, X)

Specifies the parameter in a bounded scope.
"""
Given(P, Xs...) =
    Query(Given, P, Xs...)

Given(env::Environment, p::Pipeline, Xs...) =
    Given(env, p, Keep(Xs[1:end-1]...) >> Xs[end])

function Given(env::Environment, p::Pipeline, X)
    q = compile(X, env, stub(p))
    monadic_given(p, q)
end


#
# Then sugar.
#

Then(q::Pipeline) =
    Query(Then, q)

Then(env::Environment, p::Pipeline, q::Pipeline) =
    compose(p, q)

Then(ctor) =
    Query(Then, ctor)

Then(ctor, args::Tuple) =
    Query(Then, ctor, args)

Then(env::Environment, p::Pipeline, ctor, args::Tuple=()) =
    compile(ctor(Then(p), args...), env, istub(p))


#
# Count and other aggregate combinators.
#

function monadic_count(p::Pipeline)
    p = adapt_output(p)
    q = chain_of(p,
                block_length(),
                wrap(),
    ) |> designate(ishape(p), ValueOf(Int))
    adapt_flow(clone_context(q))
end

"""
    Count(X)
    X >> Count

Counts the number of elements produced by `X`.
"""
Count(X) =
    Query(Count, X)

Lift(::typeof(Count)) =
    Then(Count)

function Count(env::Environment, p::Pipeline, X)
    x = compile(X, env, stub(p))
    compose(p, monadic_count(x))
end

"""
    Sum(X)
    X >> Sum

Sums the elements produced by `X`.
"""
Sum(X) =
    Query(Sum, X)

Lift(::typeof(Sum)) =
    Then(Sum)

"""
    Max(X)
    X >> Max

Finds the maximum.
"""
Max(X) =
    Query(Max, X)

Lift(::typeof(Max)) =
    Then(Max)

"""
    Min(X)
    X >> Min

Finds the minimum.
"""
Min(X) =
    Query(Min, X)

Lift(::typeof(Min)) =
    Then(Min)

function Sum(env::Environment, p::Pipeline, X)
    x = compile(X, env, stub(p))
    monadic_lift(p, sum, Pipeline[x])
end

maximum_missing(v) =
    !isempty(v) ? maximum(v) : missing

function Max(env::Environment, p::Pipeline, X)
    x = compile(X, env, stub(p))
    optional = cardinality(shape(x)) & x0to1 == x0to1
    monadic_lift(p, optional ? maximum_missing : maximum, Pipeline[x])
end

minimum_missing(v) =
    !isempty(v) ? minimum(v) : missing

function Min(env::Environment, p::Pipeline, X)
    x = compile(X, env, stub(p))
    optional = cardinality(shape(x)) & x0to1 == x0to1
    monadic_lift(p, optional ? minimum_missing : minimum, Pipeline[x])
end


#
# Filter combinator.
#

function monadic_filter(p::Pipeline, x::Pipeline)
    x = adapt_output(x)
    # fits(shape(p), BlockOf(ValueOf(Bool))) || error("expected a predicate")
    q = chain_of(tuple_of(pass(),
                          chain_of(x, block_any())),
                 sieve(),
    ) |> designate(ishape(x), BlockOf(ishape(x), x0to1) |> IsFlow)
    compose(p, q)
end

"""
    Filter(X)

Filters the input by condition.
"""
Filter(X) =
    Query(Filter, X)

function Filter(env::Environment, p::Pipeline, X)
    x = compile(X, env, stub(p))
    monadic_filter(p, x)
end


#
# Take and Drop combinators.
#

monadic_take(p::Pipeline, n::Int, rev::Bool) =
    chain_of(
        p,
        slice(n, rev),
    ) |> designate(ishape(p),
                   BlockOf(elements(shape(p)), cardinality(shape(p))|x0to1) |> IsFlow)

function monadic_take(p::Pipeline, n::Pipeline, rev::Bool)
    n_card = cardinality(shape(n))
    n = adapt_output(n)
    #fits(elements(n), ValueOf(Int)) || error("expected an integer")
    ishp = ishape(p)
    shp = BlockOf(elements(shape(p)), cardinality(shape(p))|x0to1) |> IsFlow
    chain_of(
        tuple_of(
            p,
            chain_of(n, fits(x0to1, n_card) ? block_lift(first, missing) : block_lift(first))),
        slice(rev),
    ) |> designate(ishp, shp)
end

"""
    Take(N)

Takes the first `N` elements.
"""
Take(N) =
    Query(Take, N)

"""
    Drop(N)

Drops the first `N` elements.
"""
Drop(N) =
    Query(Drop, N)

Take(env::Environment, p::Pipeline, ::Missing, rev::Bool=false) =
    p

Take(env::Environment, p::Pipeline, n::Int, rev::Bool=false) =
    monadic_take(p, n, rev)

function Take(env::Environment, p::Pipeline, N, rev::Bool=false)
    n = compile(N, env, istub(p))
    monadic_take(p, n, rev)
end

Drop(env::Environment, p::Pipeline, N) =
    Take(env, p, N, true)

