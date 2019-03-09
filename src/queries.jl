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

A query is implemented as a pipeline transformation.  Specifically, a query
takes a pipeline that maps *origin* to *input* and generates a pipeline that
maps *origin* to *output*.

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

quoteof(F::Query) =
    quoteof(F.op, F.args)

show(io::IO, F::Query) =
    print_expr(io, quoteof(F))


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
# Querying a DataKnot.
#

"""
    db::DataKnot[F::Query; params...] :: DataKnot

Queries `db` with `F`.
"""
getindex(db::DataKnot, F; kws...) =
    query(db, Each(F); kws...)

query(db, F; kws...) =
    query(convert(DataKnot, db), Lift(F), sort(collect(Pair{Symbol,DataKnot}, kws), by=first))

function query(db::DataKnot, F::AbstractQuery, params::Vector{Pair{Symbol,DataKnot}}=Pair{Symbol,DataKnot}[])
    db = pack(db, params)
    q = compile(F, shape(db))
    db′ = q(db)
    return db′
end

function pack(db::DataKnot, params::Vector{Pair{Symbol,DataKnot}})
    !isempty(params) || return db
    ctx_lbls = first.(params)
    ctx_cols = collect(AbstractVector, cell.(last.(params)))
    ctx_shps = collect(AbstractShape, shape.(last.(params)))
    scp_cell = TupleVector(1, AbstractVector[cell(db), TupleVector(ctx_lbls, 1, ctx_cols)])
    scp_shp = TupleOf(shape(db), TupleOf(ctx_lbls, ctx_shps)) |> IsScope
    return DataKnot(scp_cell, scp_shp)
end

compile(db::DataKnot, F::AbstractQuery, params::Vector{Pair{Symbol,DataKnot}}=Pair{Symbol,DataKnot}[]) =
    compile(F, shape(pack(db, params)))

function  compile(F::AbstractQuery, ishp::AbstractShape)
    env = Environment()
    q = uncover(compile(F, env, cover(ishp)))
    return optimize(q)
end


#
# Compiling a query.
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
    for name in getfield(nav, :__path)
        p = Get(env, p, name)
    end
    p
end


#
# Adapters.
#

# The underlying data shape.

domain(shp::AbstractShape) =
    shp

domain(shp::IsLabeled) =
    domain(subject(shp))

domain(shp::IsFlow) =
    domain(elements(shp))

domain(shp::IsScope) =
    domain(column(shp))

replace_domain(shp::AbstractShape, f) =
    f isa AbstractShape ? f : f(shp)

replace_domain(shp::IsLabeled, f) =
    replace_subject(shp, sub -> replace_domain(sub, f))

replace_domain(shp::IsFlow, f) =
    replace_elements(shp, elts -> replace_domain(elts, f))

replace_domain(shp::IsScope, f) =
    replace_column(shp, col -> replace_domain(col, f))

# Finds the output label.

getlabel(p::Pipeline, default) =
    getlabel(shape(p), default)

getlabel(shp::AbstractShape, default) =
    default

getlabel(shp::IsLabeled, default) =
    label(shp)

getlabel(shp::IsFlow, default) =
    getlabel(elements(shp), default)

getlabel(shp::IsScope, default) =
    getlabel(column(shp), default)

# Reassigns the output label.

relabel(p::Pipeline, lbl::Union{Symbol,Nothing}) =
    p |> designate(ishape(p), relabel(shape(p), lbl))

relabel(shp::AbstractShape, ::Nothing) =
    shp

relabel(shp::AbstractShape, lbl::Symbol) =
    shp |> IsLabeled(lbl)

relabel(shp::IsLabeled, ::Nothing) =
    subject(shp)

relabel(shp::IsLabeled, lbl::Symbol) =
    subject(shp) |> IsLabeled(lbl)

relabel(shp::IsFlow, lbl::Symbol) =
    replace_elements(shp, elts -> relabel(elts, lbl))

relabel(shp::IsFlow, ::Nothing) =
    replace_elements(shp, elts -> relabel(elts, nothing))

relabel(shp::IsScope, lbl::Symbol) =
    replace_column(shp, col -> relabel(col, lbl))

relabel(shp::IsScope, ::Nothing) =
    replace_column(shp, col -> relabel(col, nothing))

# Removes the flow annotation and strips the scope container from the query output.

function uncover(p::Pipeline)
    q = uncover(shape(p))
    chain_of(p, q) |> designate(ishape(p), shape(q))
end

function uncover(ishp::IsFlow)
    p = uncover(elements(ishp))
    shp = replace_domain(shape(p), dom -> BlockOf(dom, cardinality(ishp)))
    with_elements(p) |> designate(ishp, shp)
end

uncover(ishp::IsScope) =
    column(1) |> designate(ishp, column(ishp))

uncover(ishp::AbstractShape) =
    pass() |> designate(ishp, ishp)

# Finds or creates a flow container and clones the scope container.

function cover(cell::BlockVector, sig::Signature)
    elts = elements(cell)
    card = cardinality(cell)
    q = elts isa Vector{Union{}} && card == x0to1 ? null_filler() : block_filler(elts, card)
    cover(q |> designate(sig))
end

cover(cell::AbstractVector, sig::Signature) =
    cover(filler(cell[1]) |> designate(sig))

cover(p::Pipeline) =
    cover(ishape(p), p)

function cover(ishp::IsScope, p::Pipeline)
    ctx = context(ishp)
    shp = TupleOf(shape(p), ctx) |> IsScope
    p = tuple_of(p, column(2)) |> designate(ishp, shp)
    cover(nothing, p)
end

cover(::AbstractShape, p::Pipeline) =
    cover(nothing, p)

function cover(::Nothing, p::Pipeline)
    q = cover(shape(p))
    chain_of(p, q) |> designate(ishape(p), shape(q))
end

cover(ishp::AbstractShape) =
    wrap() |> designate(ishp, BlockOf(ishp, x1to1) |> IsFlow)

cover(ishp::BlockOf) =
    pass() |> designate(ishp, ishp |> IsFlow)

function cover(ishp::ValueOf)
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

function cover(ishp::IsLabeled)
    p = cover(subject(ishp))
    shp = replace_elements(shape(p), IsLabeled(label(ishp)))
    p |> designate(ishp, shp)
end

cover(ishp::IsFlow) =
    pass() |> designate(ishp, ishp)

function cover(ishp::IsScope)
    p = cover(column(ishp))
    shp = shape(p)
    shp = replace_elements(shp, TupleOf(elements(shp), context(ishp)) |> IsScope)
    chain_of(with_column(1, p), distribute(1)) |> designate(ishp, shp)
end


#
# Monadic composition.
#

# Left and right stubs of a pipeline.

istub(p::Pipeline) =
    stub(ishape(p))

stub(p::Pipeline) =
    stub(shape(p))

stub(ishp::IsFlow) =
    stub(elements(ishp))

stub(ishp::AbstractShape) =
    cover(ishp)

# Align pipelines for composition.

realign(p::Pipeline, ::AbstractShape) =
    p

realign(p::Pipeline, ref::IsScope) =
    realign(p, shape(p), ref)

realign(p::Pipeline, ::AbstractShape, ::IsScope) =
    p

realign(p::Pipeline, shp::IsFlow, ref::IsScope) =
    realign(p, elements(shp), shp, ref)

realign(p::Pipeline, ::IsScope, ::IsFlow, ::IsScope) =
    p

function realign(p::Pipeline, elts::AbstractShape, shp::IsFlow, ref::IsScope)
    p′ = chain_of(with_column(1, p), distribute(1))
    ctx = context(ref)
    ishp′ = TupleOf(ishape(p), ctx) |> IsScope
    shp′ = replace_elements(shp, elts -> TupleOf(elts, ctx) |> IsScope)
    p′ |> designate(ishp′, shp′)
end

realign(::AbstractShape, p::Pipeline) =
    p

realign(ref::IsFlow, p::Pipeline) =
    realign(ref, ishape(p), p)

realign(::IsFlow, ::IsFlow, p::Pipeline) =
    p

realign(ref::IsFlow, ::AbstractShape, p::Pipeline) =
    realign(ref, p, shape(p))

function realign(ref::IsFlow, p::Pipeline, ::AbstractShape)
    p′ = with_elements(p)
    ishp′ = replace_elements(ref, ishape(p))
    shp′ = replace_elements(ref, shape(p))
    p′ |> designate(ishp′, shp′)
end

function realign(ref::IsFlow, p::Pipeline, shp::IsFlow)
    p′ = chain_of(with_elements(p), flatten())
    ishp′ = replace_elements(ref, ishape(p))
    card′ = cardinality(ref)|cardinality(shp)
    shp′ = BlockOf(elements(shp), card′) |> IsFlow
    p′ |> designate(ishp′, shp′)
end

# Composition.

compose(p::Pipeline) = p

compose(p1::Pipeline, p2::Pipeline, p3::Pipeline, ps::Pipeline...) =
    foldl(compose, ps, init=compose(compose(p1, p2), p3))

function compose(p1::Pipeline, p2::Pipeline)
    p1 = realign(p1, ishape(p2))
    p2 = realign(shape(p1), p2)
    @assert fits(shape(p1), ishape(p2)) "cannot fit\n$(shape(p1))\ninto\n$(ishape(p2))"
    chain_of(p1, p2) |> designate(ishape(p1), shape(p2))
end

>>(X::Union{DataKnot,AbstractQuery,Pair{Symbol,<:Union{DataKnot,AbstractQuery}}}, Xs...) =
    Compose(X, Xs...)

Compose(X, Xs...) =
    Query(Compose, X, Xs...)

quoteof(::typeof(Compose), args::Vector{Any}) =
    quoteof(>>, args)

function Compose(env::Environment, p::Pipeline, Xs...)
    for X in Xs
        p = compile(X, env, p)
    end
    p
end


#
# Record combinator.
#

function assemble_record(p::Pipeline, xs::Vector{Pipeline})
    lbls = Symbol[]
    cols = Pipeline[]
    seen = Dict{Symbol,Int}()
    for (i, x) in enumerate(xs)
        x = uncover(x)
        lbl = getlabel(x, nothing)
        if lbl !== nothing
            x = relabel(x, nothing)
        else
            lbl = ordinal_label(i)
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
    lbl = getlabel(p, nothing)
    if lbl !== nothing
        shp = relabel(shp, lbl)
    end
    q = tuple_of(lbls, cols) |> designate(ishp, shp)
    q = cover(q)
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
    assemble_record(p, xs)
end


#
# Lifting Julia values and functions.
#

function assemble_lift(p::Pipeline, f, xs::Vector{Pipeline})
    cols = uncover.(xs)
    ity = Tuple{eltype.(shape.(cols))...}
    oty = Core.Compiler.return_type(f, ity)
    oty != Union{} || error("cannot apply $f to $ity")
    ishp = elements(shape(p))
    shp = ValueOf(oty)
    q = if length(cols) == 1
            card = cardinality(shape(xs[1]))
            if fits(x1toN, card) && !(oty <: AbstractVector)
                chain_of(cols[1], block_lift(f))
            else
                chain_of(cols[1], lift(f))
            end
        else
            chain_of(tuple_of(Symbol[], cols), tuple_lift(f))
        end |> designate(ishp, shp)
    q = cover(q)
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
    assemble_lift(p, f, xs)
end

function Lift(env::Environment, p::Pipeline, db::DataKnot)
    q = cover(cell(db), Signature(elements(shape(p)), shape(db)))
    compose(p, q)
end

# Broadcasting.

struct QueryStyle <: Base.BroadcastStyle
end

Base.BroadcastStyle(::Type{<:Union{AbstractQuery,DataKnot,Pair{Symbol,<:Union{AbstractQuery,DataKnot}}}}) =
    QueryStyle()

Base.BroadcastStyle(s::QueryStyle, ::Broadcast.DefaultArrayStyle) =
    s

Base.broadcastable(X::Union{AbstractQuery,DataKnot,Pair{Symbol,<:Union{AbstractQuery,DataKnot}}}) =
    X

Base.Broadcast.instantiate(bc::Broadcast.Broadcasted{QueryStyle}) =
    bc

Base.copy(bc::Broadcast.Broadcasted{QueryStyle}) =
    BroadcastLift(bc)

BroadcastLift(bc::Broadcast.Broadcasted{QueryStyle}) =
    BroadcastLift(bc.f, (BroadcastLift.(bc.args)...,))

BroadcastLift(val) = val

BroadcastLift(f, Xs) = Query(BroadcastLift, f, Xs)

BroadcastLift(env::Environment, p::Pipeline, args...) =
    Lift(env, p, args...)

quoteof(::typeof(BroadcastLift), args::Vector{Any}) =
    quoteof(broadcast, Any[args[1], quoteof.(args[2])...])

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

"""
    Label(lbl::Symbol)

Assigns a label.
"""
Label(lbl::Symbol) =
    Query(Label, lbl)

Label(env::Environment, p::Pipeline, lbl::Symbol) =
    relabel(p, lbl)

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

quoteof(::typeof(Tag), args::Vector{Any}) =
    quoteof(Tag, args...)

quoteof(::typeof(Tag), name::Symbol, X) =
    name

quoteof(::typeof(Tag), name::Symbol, args::Tuple, X) =
    Expr(:call, name, quoteof.(args)...)


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
    q = lookup(shp, name)
    q !== nothing || error("cannot find \"$name\" at\n$(syntaxof(shp))")
    q = cover(q)
    compose(p, q)
end

lookup(::AbstractShape, ::Any) = nothing

lookup(ishp::IsLabeled, name::Any) =
    lookup(subject(ishp), name)

lookup(ishp::IsFlow, name::Any) =
    lookup(elements(ishp), name)

function lookup(ishp::IsScope, name::Any)
    q = lookup(context(ishp), name)
    q === nothing || return chain_of(column(2), q) |> designate(ishp, shape(q))
    q = lookup(column(ishp), name)
    q === nothing || return chain_of(column(1), q) |> designate(ishp, shape(q))
    nothing
end

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
        lbls = Symbol[ordinal_label(i) for i = 1:width(ishp)]
    end
    j = lookup(lbls, name)
    j !== nothing || return nothing

    shp = relabel(column(ishp, j), name == lbls[j] ? name : nothing)
    column(lbls[j]) |> designate(ishp, shp)
end

lookup(ishp::ValueOf, name) =
    lookup(ishp.ty, name)

lookup(::Type, ::Any) =
    nothing

function lookup(ity::Type{<:NamedTuple}, name::Symbol)
    j = lookup(collect(Symbol, ity.parameters[1]), name)
    j !== nothing || return nothing
    oty = ity.parameters[2].parameters[j]
    lift(getindex, j) |> designate(ValueOf(ity), ValueOf(oty) |> IsLabeled(name))
end

function lookup(ity::Type{<:Tuple}, name::Symbol)
    lbls = Symbol[ordinal_label(i) for i = 1:length(ity.parameters)]
    j = lookup(lbls, name)
    j !== nothing || return nothing
    oty = ity.parameters[j]
    lift(getindex, j) |> designate(ValueOf(ity), ValueOf(oty))
end


#
# Specifying context parameters.
#

function assemble_keep(p::Pipeline, q::Pipeline)
    q = uncover(q)
    shp = shape(q)
    name = getlabel(shp, nothing)
    name !== nothing || error("parameter name is not specified")
    shp = relabel(shp, nothing)
    lbls′ = Symbol[]
    cols′ = AbstractShape[]
    perm = Int[]
    ishp = ishape(q)
    if ishp isa IsScope
        ctx = context(ishp)
        for j = 1:width(ctx)
            lbl = label(ctx, j)
            if lbl != name
                push!(lbls′, lbl)
                push!(cols′, column(ctx, j))
                push!(perm, j)
            end
        end
    end
    push!(lbls′, name)
    push!(cols′, shp)
    ctx′ = TupleOf(lbls′, cols′)
    qs = Pipeline[chain_of(column(2), column(j)) for j in perm]
    push!(qs, q)
    shp = BlockOf(TupleOf(ishp isa IsScope ? column(ishp) : ishp, ctx′) |> IsScope,
                  x1to1) |> IsFlow
    q = chain_of(tuple_of(ishp isa IsScope ? column(1) : pass(),
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
    assemble_keep(p, q)
end


#
# Setting the scope for context parameters.
#

function assemble_given(p::Pipeline, q::Pipeline)
    q = cover(uncover(q))
    compose(p, q)
end

"""
    Given(P, X)

Specifies the parameter and bounds its scope.
"""
Given(P, Xs...) =
    Query(Given, P, Xs...)

Given(env::Environment, p::Pipeline, Xs...) =
    Given(env, p, Keep(Xs[1:end-1]...) >> Xs[end])

function Given(env::Environment, p::Pipeline, X)
    q = compile(X, env, stub(p))
    assemble_given(p, q)
end


#
# Then assembly.
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

function assemble_count(p::Pipeline)
    p = uncover(p)
    q = chain_of(p,
                 block_length(),
    ) |> designate(ishape(p), ValueOf(Int))
    cover(q)
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
    compose(p, assemble_count(x))
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
    assemble_lift(p, sum, Pipeline[x])
end

maximum_missing(v) =
    !isempty(v) ? maximum(v) : missing

function Max(env::Environment, p::Pipeline, X)
    x = compile(X, env, stub(p))
    card = cardinality(shape(x))
    optional = fits(x0to1, card)
    assemble_lift(p, optional ? maximum_missing : maximum, Pipeline[x])
end

minimum_missing(v) =
    !isempty(v) ? minimum(v) : missing

function Min(env::Environment, p::Pipeline, X)
    x = compile(X, env, stub(p))
    card = cardinality(shape(x))
    optional = fits(x0to1, card)
    assemble_lift(p, optional ? minimum_missing : minimum, Pipeline[x])
end


#
# Filter combinator.
#

function assemble_filter(p::Pipeline, x::Pipeline)
    x = uncover(x)
    fits(shape(x), BlockOf(ValueOf(Bool))) || error("expected a predicate")
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
    assemble_filter(p, x)
end


#
# Take and Drop combinators.
#

function assemble_take(p::Pipeline, n::Int, rev::Bool)
    elts = elements(shape(p))
    card = cardinality(shape(p))|x0to1
    chain_of(
        p,
        slice(n, rev),
    ) |> designate(ishape(p), BlockOf(elts, card) |> IsFlow)
end

function assemble_take(p::Pipeline, n::Pipeline, rev::Bool)
    n_card = cardinality(shape(n))
    n = uncover(n)
    fits(shape(n), BlockOf(ValueOf(Int), x0to1)) || error("expected a singular integer")
    ishp = ishape(p)
    shp = BlockOf(elements(shape(p)), cardinality(shape(p))|x0to1) |> IsFlow
    chain_of(
        tuple_of(p, n),
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
    assemble_take(p, n, rev)

function Take(env::Environment, p::Pipeline, N, rev::Bool=false)
    n = compile(N, env, istub(p))
    assemble_take(p, n, rev)
end

Drop(env::Environment, p::Pipeline, N) =
    Take(env, p, N, true)

