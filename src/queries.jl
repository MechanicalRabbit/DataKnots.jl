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

A query is implemented as a pipeline transformation that preserves pipeline
source.  Specifically, a query takes the input pipeline that maps the *source*
to the *input target* and generates a pipeline that maps the *source* to the
*output target*.

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

    Query(op; args::Vector{Any}=Any[]) =
        new(op, args)
end

Query(op, args...) =
    Query(op; args=collect(Any, args))

quoteof(F::Query) =
    quoteof(F.op, F.args)

show(io::IO, F::Query) =
    print_expr(io, quoteof(F))


#
# Navigation sugar.
#

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

"""
    It :: AbstractQuery

In a query expression, use `It` to refer to the query's input.

```jldoctest
julia> unitknot[Lift(3) >> (It .+ 1)]
┼───┼
│ 4 │
```

`It` is the identity with respect to query composition.

```jldoctest
julia> unitknot[Lift('a':'c') >> It]
──┼───┼
1 │ a │
2 │ b │
3 │ c │
```

`It` provides a shorthand notation for data navigation using
`Get`, so that `It.a.x` is equivalent to `Get(:a) >> Get(:x)`.

```jldoctest
julia> unitknot[Lift((a=(x=1,y=2),)) >> It.a]
│ a    │
│ x  y │
┼──────┼
│ 1  2 │

julia> unitknot[Lift((a=(x=1,y=2),)) >> It.a.x]
│ x │
┼───┼
│ 1 │
```
"""
const It = Navigation(())

translate(mod::Module, ::Val{:it}) = It


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
    q = assemble(shape(db), F)
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
    return DataKnot(scp_shp, scp_cell)
end

assemble(db::DataKnot, F::AbstractQuery, params::Vector{Pair{Symbol,DataKnot}}=Pair{Symbol,DataKnot}[]; rewrite=rewrite_all) =
    assemble(shape(pack(db, params)), F; rewrite=rewrite)

function assemble(src::AbstractShape, F::AbstractQuery; rewrite=rewrite_all)
    p = uncover(assemble(nothing, cover(src), F))
    if rewrite isa Vector
        for pass in rewrite
            p = pass(p)
        end
        p
    elseif rewrite !== nothing
        p = rewrite(p)
    end
    p
end

assemble(::Nothing, p::Pipeline, F) =
    assemble(Environment(), p, F)

#
# External syntax.
#
"""
     @query expr

Creates a query object from a specialized path-like notation:

* bare identifiers are translated to navigation with `Get`;
* query combinators, such as `Count(X)`, use lower-case names;
* the period (`.`) is used for query composition (`>>`);
* aggregate queries, such as `Count`, require parentheses;
* records can be constructed using curly brackets, `{}`; and
* functions and operators are lifted automatically.

```jldoctest
julia> @query 2x+1
Lift(+, (Lift(*, (Lift(2), Get(:x))), Lift(1)))
```
"""
macro query(ex)
    return :( translate($__module__, $(Expr(:quote, ex)) ) )
end

"""
     @query dataset expr param=...

Applies the query to a dataset with a given set of parameters.

```jldoctest
julia> @query unitknot 2x+1 x=1
┼───┼
│ 3 │
```
"""
macro query(db, exs...)
    exs = map(exs) do ex
        if Meta.isexpr(ex, :(=), 2)
            esc(Expr(:kw, ex.args...))
        else
            :( Each(translate($__module__, $(Expr(:quote, ex)) )) )
        end
    end
    return quote
        query($(esc(db)), $(exs...))
    end
end

function translate(mod::Module, ex::Expr)::AbstractQuery
    head = ex.head
    args = ex.args
    if head === :block
        return Compose(translate.(Ref(mod), filter(arg -> !(arg isa LineNumberNode), args))...)
    elseif head === :. && length(args) == 2 && Meta.isexpr(args[2], :tuple, 1)
        return Compose(translate(mod, args[1]), translate(mod, args[2].args[1]))
    elseif head === :.
        return Compose(translate.(Ref(mod), args)...)
    elseif head === :let && length(args) == 2
        return Given(translate.(Ref(mod), Meta.isexpr(args[1], :block) ? args[1].args : (args[1],))...,
                     translate(mod, args[2]))
    elseif head === :braces
        return Record(translate.(Ref(mod), args)...)
    elseif head === :quote && length(args) == 1 && Meta.isexpr(args[1], :braces)
        return Record(translate.(Ref(mod), args[1].args)...)
    elseif head === :curly && length(args) >= 1
        return Compose(translate(mod, args[1]), Record(translate.(Ref(mod), args[2:end])...))
    elseif head === :call && length(args) >= 1
        call = args[1]
        if call isa QuoteNode
            call = call.value
        end
        if call === :(=>) && length(args) == 3 && args[2] isa Symbol
            return Compose(translate(mod, args[3]), Label(args[2]))
        elseif call isa Symbol
            return translate(mod, Val(call), (args[2:end]...,))
        elseif Meta.isexpr(call, :.) && !isempty(call.args)
            return Compose(translate.(Ref(mod), call.args[1:end-1])...,
                           translate(mod, Expr(:call, call.args[end], args[2:end]...)))
        elseif call isa Base.Callable
            return Lift(call(translate.(Ref(mod), args[2:end])...))
        end
    elseif head == :comparison && length(args) == 3
        return translate(mod, Expr(:call, args[2], args[1], args[3]))
    elseif head == :comparison && length(args) > 3
        return translate(mod, Expr(:&&, Expr(:call, args[2], args[1], args[3]), Expr(head, args[3:end]...)))
    elseif head == :&&
        return Lift(&, (translate.(Ref(mod), args)...,))
    elseif head == :||
        return Lift(|, (translate.(Ref(mod), args)...,))
    end
    error("invalid query expression: $(repr(ex))")
end

translate(mod::Module, sym::Symbol) =
    translate(mod, Val(sym))

translate(::Module, ::Val{:nothing}) =
    Lift(nothing)

translate(::Module, ::Val{:missing}) =
    Lift(missing)

translate(mod::Module, qn::QuoteNode) =
    translate(mod, qn.value)

translate(mod::Module, @nospecialize(v::Val{N})) where {N} =
    Get(N)

function translate(mod::Module, @nospecialize(v::Val{N}), args::Tuple) where {N}
    fn = getfield(mod, N)
    Lift(fn, translate.(Ref(mod), args))
end

translate(mod::Module, val) =
    Lift(val)


#
# Compiling a query.
#

"""
    Environment()

Query compilation state.
"""
mutable struct Environment
end

assemble(env::Environment, p::Pipeline, F)::Pipeline =
    assemble(env, p, Lift(F))

assemble(env::Environment, p::Pipeline, F::Query)::Pipeline =
    F.op(env, p, F.args...)

function assemble(env::Environment, p::Pipeline, nav::Navigation)::Pipeline
    for name in getfield(nav, :__path)
        p = Get(env, p, name)
    end
    p
end


#
# Adapters.
#

# The underlying data shape below flow and scope containers.

domain(shp::AbstractShape) =
    shp

domain(shp::IsFlow) =
    domain(elements(shp))

domain(shp::IsScope) =
    domain(column(shp))

replace_domain(shp::AbstractShape, f) =
    f isa AbstractShape ? f : f(shp)

replace_domain(shp::IsFlow, f) =
    replace_elements(shp, elts -> replace_domain(elts, f))

replace_domain(shp::IsScope, f) =
    replace_column(shp, col -> replace_domain(col, f))

# Finds the output label.

getlabel(p::Pipeline, default) =
    getlabel(target(p), default)

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
    p |> designate(source(p), relabel(target(p), lbl))

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
    q = uncover(target(p))
    chain_of(p, q) |> designate(source(p), target(q))
end

function uncover(src::IsFlow)
    p = uncover(elements(src))
    lbl = getlabel(p, nothing)
    p = relabel(p, nothing)
    tgt = relabel(replace_domain(target(p), dom -> BlockOf(dom, cardinality(src))), lbl)
    with_elements(p) |> designate(src, tgt)
end

uncover(src::IsScope) =
    column(1) |> designate(src, column(src))

uncover(src::AbstractShape) =
    pass() |> designate(src, src)

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
    cover(source(p), p)

function cover(src::IsScope, p::Pipeline)
    ctx = context(src)
    tgt = TupleOf(target(p), ctx) |> IsScope
    p = tuple_of(p, column(2)) |> designate(src, tgt)
    cover(nothing, p)
end

cover(::AbstractShape, p::Pipeline) =
    cover(nothing, p)

function cover(::Nothing, p::Pipeline)
    q = cover(target(p))
    chain_of(p, q) |> designate(source(p), target(q))
end

cover(src::AbstractShape) =
    wrap() |> designate(src, BlockOf(src, x1to1) |> IsFlow)

cover(src::BlockOf) =
    pass() |> designate(src, src |> IsFlow)

function cover(src::ValueOf)
    ty = eltype(src)
    if ty <: AbstractVector
        ty′ = eltype(ty)
        adapt_vector() |> designate(src, BlockOf(ty′, x0toN) |> IsFlow)
    elseif Missing <: ty
        ty′ = Base.nonmissingtype(ty)
        adapt_missing() |> designate(src, BlockOf(ty′, x0to1) |> IsFlow)
    else
        wrap() |> designate(src, BlockOf(src, x1to1) |> IsFlow)
    end
end

function cover(src::IsLabeled)
    p = cover(subject(src))
    tgt = replace_elements(target(p), IsLabeled(label(src)))
    p |> designate(src, tgt)
end

cover(src::IsFlow) =
    pass() |> designate(src, src)

function cover(src::IsScope)
    p = cover(column(src))
    tgt = target(p)
    tgt = replace_elements(tgt, TupleOf(elements(tgt), context(src)) |> IsScope)
    chain_of(with_column(1, p), distribute(1)) |> designate(src, tgt)
end


#
# Elementwise composition.
#

# Trivial pipes at the source and target endpoints of a pipeline.

source_pipe(p::Pipeline) =
    trivial_pipe(source(p))

target_pipe(p::Pipeline) =
    trivial_pipe(target(p))

trivial_pipe(src::IsFlow) =
    trivial_pipe(elements(src))

trivial_pipe(src::AbstractShape) =
    cover(src)

trivial_pipe(db::DataKnot) =
    cover(shape(db))

# Align pipelines for composition.

realign(p::Pipeline, ::AbstractShape) =
    p

realign(p::Pipeline, ref::IsScope) =
    realign(p, target(p), ref)

realign(p::Pipeline, ::AbstractShape, ::IsScope) =
    p

realign(p::Pipeline, tgt::IsFlow, ref::IsScope) =
    realign(p, elements(tgt), tgt, ref)

realign(p::Pipeline, ::IsScope, ::IsFlow, ::IsScope) =
    p

function realign(p::Pipeline, elts::AbstractShape, tgt::IsFlow, ref::IsScope)
    p′ = chain_of(with_column(1, p), distribute(1))
    ctx = context(ref)
    src′ = TupleOf(source(p), ctx) |> IsScope
    tgt′ = replace_elements(tgt, elts -> TupleOf(elts, ctx) |> IsScope)
    p′ |> designate(src′, tgt′)
end

realign(::AbstractShape, p::Pipeline) =
    p

realign(ref::IsFlow, p::Pipeline) =
    realign(ref, source(p), p)

realign(::IsFlow, ::IsFlow, p::Pipeline) =
    p

realign(ref::IsFlow, ::AbstractShape, p::Pipeline) =
    realign(ref, p, target(p))

function realign(ref::IsFlow, p::Pipeline, ::AbstractShape)
    p′ = with_elements(p)
    src′ = replace_elements(ref, source(p))
    tgt′ = replace_elements(ref, target(p))
    p′ |> designate(src′, tgt′)
end

function realign(ref::IsFlow, p::Pipeline, tgt::IsFlow)
    p′ = chain_of(with_elements(p), flatten())
    src′ = replace_elements(ref, source(p))
    card′ = cardinality(ref)|cardinality(tgt)
    tgt′ = BlockOf(elements(tgt), card′) |> IsFlow
    p′ |> designate(src′, tgt′)
end

# Composition.

compose(p::Pipeline) = p

compose(p1::Pipeline, p2::Pipeline, p3::Pipeline, ps::Pipeline...) =
    foldl(compose, ps, init=compose(compose(p1, p2), p3))

function compose(p1::Pipeline, p2::Pipeline)
    p1 = realign(p1, source(p2))
    p2 = realign(target(p1), p2)
    @assert fits(target(p1), source(p2)) "cannot fit\n$(target(p1))\ninto\n$(source(p2))"
    chain_of(p1, p2) |> designate(source(p1), target(p2))
end

>>(X::Union{DataKnot,AbstractQuery,Pair{Symbol,<:Union{DataKnot,AbstractQuery}}}, Xs...) =
    Compose(X, Xs...)

Compose(Xs...) =
    Query(Compose, Xs...)

quoteof(::typeof(Compose), args::Vector{Any}) =
    quoteof(>>, args)

function Compose(env::Environment, p::Pipeline, Xs...)
    for X in Xs
        p = assemble(env, p, X)
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
            lbls[seen[lbl]] = ordinal_label(seen[lbl])
        end
        seen[lbl] = i
        push!(lbls, lbl)
        push!(cols, x)
    end
    src = elements(target(p))
    tgt = TupleOf(lbls, target.(cols))
    lbl = getlabel(p, nothing)
    if lbl !== nothing
        tgt = relabel(tgt, lbl)
    end
    q = tuple_of(lbls, cols) |> designate(src, tgt)
    q = cover(q)
    compose(p, q)
end

"""
    Record(X₁, X₂ … Xₙ) :: Query

This query emits a record with fields generated by `X₁`, `X₂` … `Xₙ`.

```jldoctest
julia> unitknot[Lift(1:3) >> Record(It, It .* It)]
  │ #A  #B │
──┼────────┼
1 │  1   1 │
2 │  2   4 │
3 │  3   9 │
```

Field labels are inherited from queries.

```jldoctest
julia> unitknot[Lift(1:3) >> Record(:x => It,
                                    :x² => It .* It)]
  │ x  x² │
──┼───────┼
1 │ 1   1 │
2 │ 2   4 │
3 │ 3   9 │
```
"""
Record(Xs...) =
    Query(Record, Xs...)

function Record(env::Environment, p::Pipeline, Xs...)
    xs = assemble.(Ref(env), Ref(target_pipe(p)), collect(AbstractQuery, Xs))
    assemble_record(p, xs)
end

translate(mod::Module, ::Val{:record}, args::Tuple) =
    Record(translate.(Ref(mod), args)...)


#
# Mix combinator.
#

function assemble_mix(p::Pipeline, xs::Vector{Pipeline})
    lbls = Symbol[]
    cols = Pipeline[]
    card = x1to1
    seen = Dict{Symbol,Int}()
    for (i, x) in enumerate(xs)
        card |= cardinality(target(x))
        x = uncover(x)
        lbl = getlabel(x, nothing)
        if lbl !== nothing
            x = relabel(x, nothing)
        else
            lbl = ordinal_label(i)
        end
        if lbl in keys(seen)
            lbls[seen[lbl]] = ordinal_label(seen[lbl])
        end
        seen[lbl] = i
        push!(lbls, lbl)
        x = chain_of(
                x,
                with_elements(wrap()),
        ) |> designate(source(x), replace_elements(target(x), elts -> BlockOf(elts, x1to1)))
        push!(cols, x)
    end
    src = elements(target(p))
    tgt = BlockOf(TupleOf(lbls, elements.(target.(cols))), card)
    lbl = getlabel(p, nothing)
    if lbl !== nothing
        tgt = relabel(tgt, lbl)
    end
    q = chain_of(
            tuple_of(lbls, cols),
            distribute_all(),
    ) |> designate(src, tgt)
    q = cover(q)
    compose(p, q)
end

"""
    Mix(X₁, X₂ … Xₙ) :: Query

This query emits records containing every combination of elements
generated by `X₁`, `X₂` … `Xₙ`.

```jldoctest
julia> unitknot[Mix(Lift(1:2), Lift('a':'c'))]
  │ #A  #B │
──┼────────┼
1 │  1  a  │
2 │  1  b  │
3 │  1  c  │
4 │  2  a  │
5 │  2  b  │
6 │  2  c  │
```
"""
Mix(Xs...) =
    Query(Mix, Xs...)

function Mix(env::Environment, p::Pipeline, Xs...)
    xs = assemble.(Ref(env), Ref(target_pipe(p)), collect(AbstractQuery, Xs))
    assemble_mix(p, xs)
end

translate(mod::Module, ::Val{:mix}, args::Tuple) =
    Mix(translate.(Ref(mod), args)...)


#
# Collect combinator.
#

function as_record(p::Pipeline)
    q = as_record(elements(target(p)))
    q !== nothing ?
        compose(p, cover(q)) :
        p
end

as_record(src::AbstractShape) = nothing

as_record(::TupleOf) = nothing

function as_record(src::IsLabeled)
    p = as_record(subject(src))
    p !== nothing ?
        p |> designate(src, target(p) |> IsLabeled(label(src))) :
        nothing
end

as_record(src::IsFlow) =
    as_record(elements(src))

function as_record(src::IsScope)
    p = as_record(column(src))
    p !== nothing ?
        chain_of(column(1), p) |> designate(src, target(p)) :
        nothing
end

as_record(src::ValueOf) =
    as_record(src.ty)

as_record(::Type) =
    nothing

function as_record(ity::Type{<:NamedTuple})
    lbls = collect(Symbol, ity.parameters[1])
    cols = collect(AbstractShape, ity.parameters[2].parameters)
    adapt_tuple() |> designate(ity, TupleOf(lbls, cols))
end

function as_record(ity::Type{<:Tuple})
    cols = collect(AbstractShape, ity.parameters)
    adapt_tuple() |> designate(ity, TupleOf(cols))
end

function assemble_collect(p, x)
    p = as_record(p)
    src = elements(target(p))
    dom = deannotate(domain(src))
    dom isa TupleOf || error("expected a record; got\n$(syntaxof(dom))")
    x = uncover(x)
    x_lbl = getlabel(x, nothing)
    x = relabel(x, nothing)
    cols = Pipeline[]
    lbls = Symbol[]
    x_pos = width(dom)+1
    for i in 1:width(dom)
        lbl = label(dom, i)
        if lbl == x_lbl
            x_pos = i
            continue
        end
        col = lookup(src, i)
        push!(cols, col)
        if lbl == ordinal_label(i)
            lbl = ordinal_label(length(cols))
        end
        push!(lbls, lbl)
    end
    if !fits(target(x), BlockOf(Nothing, x1to1))
        splice!(cols, x_pos:x_pos-1, Ref(x))
        splice!(lbls, x_pos:x_pos-1, Ref(x_lbl !== nothing ? x_lbl : ordinal_label(length(cols))))
    end
    tgt = TupleOf(lbls, target.(cols))
    lbl = getlabel(p, nothing)
    if lbl !== nothing
        tgt = relabel(tgt, lbl)
    end
    q = tuple_of(lbls, cols) |> designate(src, tgt)
    q = cover(q)
    compose(p, q)
end

"""
    Collect(X₁, X₂ … Xₙ) :: Query

In the combinator form, `Collect(X₁, X₂ … Xₙ)` adds fields `X₁`,
`X₂` … `Xₙ` to the input record.

```jldoctest
julia> unitknot[Record(:x => 1) >> Collect(:y => 2 .* It.x)]
│ x  y │
┼──────┼
│ 1  2 │
```

If a field already exists, it is replaced.

```jldoctest
julia> unitknot[Record(:x => 1) >> Collect(:x => 2 .* It.x)]
│ x │
┼───┼
│ 2 │
```

To remove a field, assign it the value `nothing`.

```jldoctest
julia> unitknot[Record(:x => 1) >> Collect(:y => 2 .* It.x, :x => nothing)]
│ y │
┼───┼
│ 2 │
```

---

    Each(X >> Record) :: Query

In the query form, `Collect` appends a field to the source record.

```jldoctest
julia> unitknot[Lift(1) >> Label(:x) >> Collect]
│ x │
┼───┼
│ 1 │
```
"""
Collect(X, Ys...) =
    Query(Collect, X, Ys...)

Lift(::typeof(Collect)) =
    Then(Collect)

Collect(env::Environment, p::Pipeline, X, Ys...) =
    Collect(env, Collect(env, p, X), Ys...)

function Collect(env::Environment, p::Pipeline, X)
    x = assemble(env, target_pipe(p), X)
    assemble_collect(p, x)
end

translate(mod::Module, ::Val{:collect}, args::Tuple) =
    Collect(translate.(Ref(mod), args)...)

translate(mod::Module, ::Val{:collect}, ::Tuple{}) =
    Then(Collect)


#
# Join combinator.
#

join_pipe(p::Pipeline) =
    join_pipe(source(p), target(p))

join_pipe(src::AbstractShape, dst::AbstractShape) =
    trivial_pipe(replace_domain(dst, domain(src)))

function assemble_join(p::Pipeline, x::Pipeline)
    p = as_record(p)
    dom = deannotate(domain(target(p)))
    dom isa TupleOf || error("expected a record; got\n$(syntaxof(dom))")
    p0 = uncover(source(p))
    q = assemble_join(target(p), target(p0), x)
    chain_of(tuple_of(p, p0), q) |> designate(source(p), target(q))
end

function assemble_join(src::IsFlow, src0::AbstractShape, x::Pipeline)
    q = assemble_join(elements(src), src0, x)
    q′ = chain_of(distribute(1), with_elements(q))
    q′ |> designate(TupleOf(src, src0), replace_elements(src, target(q)))
end

function assemble_join(src::IsScope, src0::AbstractShape, x::Pipeline)
    q = assemble_join(column(src), replace_column(src, src0), x)
    q′ = tuple_of(chain_of(tuple_of(chain_of(column(1), column(1)),
                                    tuple_of(column(2),
                                             chain_of(column(1), column(2)))),
                           q),
                  chain_of(chain_of(column(1), column(2))))
    q′ |> designate(TupleOf(src, src0), replace_column(src, target(q)))
end

function assemble_join(src::AbstractShape, src0::AbstractShape, x::Pipeline)
    dom = deannotate(domain(src))::TupleOf
    x = uncover(x)
    x_lbl = getlabel(x, nothing)
    x = relabel(x, nothing)
    cols = Pipeline[]
    col_shps = AbstractShape[]
    lbls = Symbol[]
    x_pos = width(dom)+1
    for i in 1:width(dom)
        lbl = label(dom, i)
        if lbl == x_lbl
            x_pos = i
            continue
        end
        col = lookup(src, i)
        push!(cols, chain_of(column(1), col))
        push!(col_shps, target(col))
        if lbl == ordinal_label(i)
            lbl = ordinal_label(length(cols))
        end
        push!(lbls, lbl)
    end
    splice!(cols, x_pos:x_pos-1, Ref(chain_of(column(2), x)))
    splice!(col_shps, x_pos:x_pos-1, Ref(target(x)))
    splice!(lbls, x_pos:x_pos-1, Ref(x_lbl !== nothing ? x_lbl : ordinal_label(length(cols))))
    tgt = TupleOf(lbls, col_shps)
    lbl = getlabel(src, nothing)
    if lbl !== nothing
        tgt = relabel(tgt, lbl)
    end
    tuple_of(lbls, cols) |> designate(TupleOf(src, src0), tgt)
end

"""
    Join(X) :: Query

`Join(X)` evaluates `X` in the source context and adds it
as a field to the input record.

```jldoctest
julia> unitknot[Record(:x => 1) >> Each(Record(:y => 2 .* It.x) >> Join(It.x))]
│ y  x │
┼──────┼
│ 2  1 │
```
"""
Join(X) =
    Query(Join, X)

function Join(env::Environment, p::Pipeline, X)
    x = assemble(env, join_pipe(p), X)
    assemble_join(p, x)
end

translate(mod::Module, ::Val{:join}, (arg,)::Tuple{Any}) =
    Join(translate(mod, arg))


#
# Lifting Julia values and functions.
#

function assemble_lift(p::Pipeline, f, xs::Vector{Pipeline})
    cols = uncover.(xs)
    ity = Tuple{eltype.(target.(cols))...}
    oty = Core.Compiler.return_type(f, ity)
    oty != Union{} || error("cannot apply $f to $ity")
    src = elements(target(p))
    tgt = ValueOf(oty)
    q = if length(cols) == 1
            card = cardinality(target(xs[1]))
            if fits(x1toN, card) && !(oty <: AbstractVector)
                chain_of(cols[1], block_lift(f))
            else
                chain_of(cols[1], lift(f))
            end
        else
            chain_of(tuple_of(Symbol[], cols), tuple_lift(f))
        end |> designate(src, tgt)
    q = cover(q)
    compose(p, q)
end

Lift(X::AbstractQuery) = X

"""
    Lift(val) :: Query

This converts any value to a constant query.

```jldoctest
julia> unitknot[Lift("Hello")]
┼───────┼
│ Hello │
```

`AbstractVector` objects become plural queries.

```jldoctest
julia> unitknot[Lift('a':'c')]
──┼───┼
1 │ a │
2 │ b │
3 │ c │
```

To specify the vector cardinality, add `:x0to1`, `:x0toN`,
`:x1to1`, or `:x1toN`.

```jldoctest
julia> unitknot[Lift('a':'c', :x1toN)]
──┼───┼
1 │ a │
2 │ b │
3 │ c │
```

The `missing` value makes an query with no output.

```jldoctest
julia> unitknot[Lift(missing)]
(empty)
```
"""
Lift(val) =
    Query(Lift, val)

Lift(elts::AbstractVector, card::Union{Cardinality,Symbol}) =
    Query(Lift, elts, card)

"""
    Lift(f, (X₁, X₂ … Xₙ)) :: Query

`Lift` lets you use a function as a query combinator.

```jldoctest
julia> unitknot[Lift((x=1, y=2)) >> Lift(+, (It.x, It.y))]
┼───┼
│ 3 │
```

`Lift` is implicitly used when a function is broadcast over
queries.

```jldoctest
julia> unitknot[Lift((x=1, y=2)) >> (It.x .+ It.y)]
┼───┼
│ 3 │
```

Functions accepting a `AbstractVector` can be used with plural
queries.

```jldoctest
julia> unitknot[sum.(Lift(1:3))]
┼───┼
│ 6 │
```

Functions returning `AbstractVector` become plural queries.

```jldoctest
julia> unitknot[Lift((x='a', y='c')) >> Lift(:, (It.x, It.y))]
──┼───┼
1 │ a │
2 │ b │
3 │ c │
```
"""
Lift(f, Xs::Tuple) =
    Query(Lift, f, Xs)

convert(::Type{AbstractQuery}, val) =
    Lift(val)

convert(::Type{AbstractQuery}, F::AbstractQuery) =
    F

Lift(env::Environment, p::Pipeline, val) =
    Lift(env, p, convert(DataKnot, val))

Lift(env::Environment, p::Pipeline, elts::AbstractVector, card::Union{Cardinality,Symbol}) =
    Lift(env, p, DataKnot(Any, elts, card))

function Lift(env::Environment, p::Pipeline, f, Xs::Tuple)
    xs = assemble.(Ref(env), Ref(target_pipe(p)), collect(AbstractQuery, Xs))
    assemble_lift(p, f, xs)
end

function Lift(env::Environment, p::Pipeline, db::DataKnot)
    q = cover(cell(db), Signature(elements(target(p)), shape(db)))
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
    Each(X) :: Query

This evaluates `X` elementwise.

```jldoctest
julia> X = Lift('a':'c') >> Count;

julia> unitknot[Lift(1:3) >> Each(X)]
──┼───┼
1 │ 3 │
2 │ 3 │
3 │ 3 │
```

Compare this with the query without `Each`.

```jldoctest
julia> X = Lift('a':'c') >> Count;

julia> unitknot[Lift(1:3) >> X]
┼───┼
│ 9 │
```
"""
Each(X) = Query(Each, X)

Each(env::Environment, p::Pipeline, X) =
    compose(p, assemble(env, target_pipe(p), X))

translate(mod::Module, ::Val{:each}, (arg,)::Tuple{Any}) =
    Each(translate(mod, arg))


#
# Assigning labels.
#

"""
    Label(lbl::Symbol) :: Query

This assigns a label to the output.

```jldoctest
julia> unitknot[Lift("Hello World") >> Label(:greeting)]
│ greeting    │
┼─────────────┼
│ Hello World │
```

A label could also be assigned using the `=>` operator.

```jldoctest
julia> unitknot[:greeting => Lift("Hello World")]
│ greeting    │
┼─────────────┼
│ Hello World │
```
"""
Label(lbl::Symbol) =
    Query(Label, lbl)

Label(env::Environment, p::Pipeline, lbl::Symbol) =
    relabel(p, lbl)

Lift(p::Pair{Symbol}) =
    Compose(p.second, Label(p.first))

translate(mod::Module, ::Val{:label}, (arg,)::Tuple{Symbol}) =
    Label(arg)


#
# Assigning a name to a query.
#

"""
    Tag(name::Symbol, F) :: Query

This provides a substitute name for a query.

```jldoctest
julia> IncIt = It .+ 1
It .+ 1

julia> IncIt = Tag(:IncIt, It .+ 1)
IncIt
```

---

    Tag(name::Symbol, (X₁, X₂ … Xₙ), F) :: Query

This provides a substitute name for a query combinator.

```jldoctest
julia> Inc(X) = Lift(+, (X, 1));

julia> Inc(It)
Lift(+, (It, 1))

julia> Inc(X) = Tag(:Inc, (X,), Lift(+, (X, 1)));

julia> Inc(It)
Inc(It)
```
"""
Tag(name::Symbol, X) =
    Query(Tag, name, X)

Tag(name::Symbol, args::Tuple, X) =
    Query(Tag, name, args, X)

Tag(F::Union{Function,DataType}, args::Tuple, X) =
    Tag(nameof(F), args, X)

Tag(env::Environment, p::Pipeline, name, X) =
    assemble(env, p, X)

Tag(env::Environment, p::Pipeline, name, args, X) =
    assemble(env, p, X)

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
    Get(lbl::Symbol) :: Query

This query extracts a field value by its label.

```jldoctest
julia> unitknot[Lift((x=1, y=2)) >> Get(:x)]
│ x │
┼───┼
│ 1 │
```

This has a shorthand form using `It`.

```jldoctest
julia> unitknot[Lift((x=1, y=2)) >> It.x]
│ x │
┼───┼
│ 1 │
```

With unlabeled fields, ordinal labels (A, B, ...) can be used.

```jldoctest
julia> unitknot[Lift((1,2)) >> It.B]
┼───┼
│ 2 │
```
"""
Get(name) =
    Query(Get, name)

function Get(env::Environment, p::Pipeline, name)
    tgt = target(p)
    q = lookup(tgt, name)
    q !== nothing || error("cannot find \"$name\" at\n$(syntaxof(tgt))")
    q = cover(q)
    compose(p, q)
end

lookup(::AbstractShape, ::Any) = nothing

lookup(src::IsLabeled, name::Any) =
    lookup(subject(src), name)

lookup(src::IsFlow, name::Any) =
    lookup(elements(src), name)

function lookup(src::IsScope, name::Any)
    q = lookup(column(src), name)
    q !== nothing ?
        chain_of(column(1), q) |> designate(src, target(q)) :
        nothing
end

function lookup(src::IsScope, name::Symbol)
    q = lookup(context(src), name)
    q === nothing || return chain_of(column(2), q) |> designate(src, target(q))
    q = lookup(column(src), name)
    q === nothing || return chain_of(column(1), q) |> designate(src, target(q))
    nothing
end

function lookup(lbls::Vector{Symbol}, name::Symbol)
    j = findlast(isequal(name), lbls)
    if j === nothing
        j = findlast(isequal(Symbol("#$name")), lbls)
    end
    j
end

lookup(src::TupleOf, j::Int) =
    column(j) |> designate(src, column(src, j))

function lookup(src::TupleOf, name::Symbol)
    lbls = labels(src)
    if isempty(lbls)
        lbls = Symbol[ordinal_label(i) for i = 1:width(src)]
    end
    j = lookup(lbls, name)
    j !== nothing || return nothing

    tgt = relabel(column(src, j), name == lbls[j] ? name : nothing)
    column(lbls[j]) |> designate(src, tgt)
end

lookup(src::ValueOf, name) =
    lookup(src.ty, name)

lookup(::Type, ::Any) =
    nothing

function lookup(ity::Type{<:NamedTuple}, name::Symbol)
    j = lookup(collect(Symbol, ity.parameters[1]), name)
    j !== nothing || return nothing
    oty = ity.parameters[2].parameters[j]
    lift(getindex, j) |> designate(ity, oty |> IsLabeled(name))
end

function lookup(ity::Type{<:Tuple}, name::Symbol)
    lbls = Symbol[ordinal_label(i) for i = 1:length(ity.parameters)]
    j = lookup(lbls, name)
    j !== nothing || return nothing
    oty = ity.parameters[j]
    lift(getindex, j) |> designate(ity, oty)
end


#
# Specifying context parameters.
#

function assemble_keep(p::Pipeline, q::Pipeline)
    q = uncover(q)
    tgt = target(q)
    name = getlabel(tgt, nothing)
    name !== nothing || error("parameter name is not specified")
    tgt = relabel(tgt, nothing)
    lbls′ = Symbol[]
    cols′ = AbstractShape[]
    perm = Int[]
    src = source(q)
    if src isa IsScope
        ctx = context(src)
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
    push!(cols′, tgt)
    ctx′ = TupleOf(lbls′, cols′)
    qs = Pipeline[chain_of(column(2), column(j)) for j in perm]
    push!(qs, q)
    tgt = BlockOf(TupleOf(src isa IsScope ? column(src) : src, ctx′) |> IsScope,
                  x1to1) |> IsFlow
    q = chain_of(tuple_of(src isa IsScope ? column(1) : pass(),
                          tuple_of(lbls′, qs)),
                 wrap(),
    ) |> designate(src, tgt)
    compose(p, q)
end

"""
    Keep(X₁, X₂ … Xₙ) :: Query

`Keep` evaluates named queries, making their results available for
subsequent computation.

```jldoctest
julia> unitknot[Keep(:x => 2) >> It.x]
│ x │
┼───┼
│ 2 │
```

`Keep` does not otherwise change its input.

```jldoctest
julia> unitknot[Lift(1) >> Keep(:x => 2) >> (It .+ It.x)]
┼───┼
│ 3 │
```
"""
Keep(P, Qs...) =
    Query(Keep, P, Qs...)

Keep(env::Environment, p::Pipeline, P, Qs...) =
    Keep(env, Keep(env, p, P), Qs...)

function Keep(env::Environment, p::Pipeline, P)
    q = assemble(env, target_pipe(p), P)
    assemble_keep(p, q)
end

translate(mod::Module, ::Val{:keep}, args::Tuple{Any,Vararg{Any}}) =
    Keep(translate.(Ref(mod), args)...)


#
# Setting the scope for context parameters.
#

function assemble_given(p::Pipeline, q::Pipeline)
    q = cover(uncover(q))
    compose(p, q)
end

"""
    Given(X₁, X₂ … Xₙ, Q) :: Query

This evaluates `Q` in a context augmented with named parameters
added by a set of queries.

```jldoctest
julia> unitknot[Given(:x => 2, It.x .+ 1)]
┼───┼
│ 3 │
```
"""
Given(P, Xs...) =
    Query(Given, P, Xs...)

Given(env::Environment, p::Pipeline, Xs...) =
    Given(env, p, Keep(Xs[1:end-1]...) >> Each(Xs[end]))

function Given(env::Environment, p::Pipeline, X)
    q = assemble(env, target_pipe(p), X)
    assemble_given(p, q)
end

const Let = Given

translate(mod::Module, ::Val{:given}, args::Tuple{Any,Vararg{Any}}) =
    Given(translate.(Ref(mod), args)...)


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
    assemble(env, source_pipe(p), ctor(Then(p), args...))


#
# Count and other aggregate combinators.
#

function assemble_count(p::Pipeline)
    p = uncover(p)
    q = chain_of(p,
                 block_length(),
    ) |> designate(source(p), Int)
    cover(q)
end

function assemble_exists(p::Pipeline)
    p = uncover(p)
    q = chain_of(p,
                 block_not_empty(),
    ) |> designate(source(p), Bool)
    cover(q)
end

"""
    Count(X) :: Query

In the combinator form, `Count(X)` emits the number of elements
produced by `X`.

```jldoctest
julia> X = Lift('a':'c');

julia> unitknot[Count(X)]
┼───┼
│ 3 │
```

---

    Each(X >> Count) :: Query

In the query form, `Count` emits the number of elements in its input.

```jldoctest
julia> X = Lift('a':'c');

julia> unitknot[X >> Count]
┼───┼
│ 3 │
```

To limit the scope of aggregation, use `Each`.

```jldoctest
julia> X = Lift('a':'c');

julia> unitknot[Lift(1:3) >> Each(X >> Count)]
──┼───┼
1 │ 3 │
2 │ 3 │
3 │ 3 │
```
"""
Count(X) =
    Query(Count, X)

Lift(::typeof(Count)) =
    Then(Count)

function Count(env::Environment, p::Pipeline, X)
    x = assemble(env, target_pipe(p), X)
    compose(p, assemble_count(x))
end

"""
    Exists(X) :: Query

In the combinator form, `Exists(X)` emits a boolean testing if `X` produces any elements.

```jldoctest
julia> X = Lift('a':'c');

julia> unitknot[Exists(X)]
┼──────┼
│ true │
```

When the query argument `X` is empty, `Exists(X)` produces `false`.

```jldoctest
julia> X = Lift([]);

julia> unitknot[Exists(X)]
┼───────┼
│ false │
```

---

    Each(X >> Exists) :: Query

In the query form, `Exists` emits a boolean testing if its input has any elements.

```jldoctest
julia> X = Lift('a':'c');

julia> unitknot[X >> Exists]
┼──────┼
│ true │
```

When the query input is empty, `Exists` produces `false`.

```jldoctest
julia> X = Lift([]);

julia> unitknot[X >> Exists]
┼───────┼
│ false │
```
"""
Exists(X) =
    Query(Exists, X)

Lift(::typeof(Exists)) =
    Then(Exists)

function Exists(env::Environment, p::Pipeline, X)
    x = assemble(env, target_pipe(p), X)
    compose(p, assemble_exists(x))
end

"""
    Sum(X) :: Query

In the combinator form, `Sum(X)` emits the sum of elements
produced by `X`.

```jldoctest
julia> X = Lift(1:3);

julia> unitknot[Sum(X)]
┼───┼
│ 6 │
```

The `Sum` of an empty input is `0`.

```jldoctest
julia> unitknot[Sum(Int[])]
┼───┼
│ 0 │
```

---

    Each(X >> Sum) :: Query

In the query form, `Sum` emits the sum of input elements.

```jldoctest
julia> X = Lift(1:3);

julia> unitknot[X >> Sum]
┼───┼
│ 6 │
```
"""
Sum(X) =
    Query(Sum, X)

Lift(::typeof(Sum)) =
    Then(Sum)

"""
     Max(X) :: Query

In the combinator form, `Max(X)` finds the maximum among the
elements produced by `X`.

```jldoctest
julia> X = Lift(1:3);

julia> unitknot[Max(X)]
┼───┼
│ 3 │
```

The `Max` of an empty input is empty.

```jldoctest
julia> unitknot[Max(Int[])]
(empty)
```

---

    Each(X >> Max) :: Query

In the query form, `Max` finds the maximum of its input elements.

```jldoctest
julia> X = Lift(1:3);

julia> unitknot[X >> Max]
┼───┼
│ 3 │
```
"""
Max(X) =
    Query(Max, X)

Lift(::typeof(Max)) =
    Then(Max)

"""
     Min(X) :: Query

In the combinator form, `Min(X)` finds the minimum among the
elements produced by `X`.

```jldoctest
julia> X = Lift(1:3);

julia> unitknot[Min(X)]
┼───┼
│ 1 │
```

The `Min` of an empty input is empty.

```jldoctest
julia> unitknot[Min(Int[])]
(empty)
```

---

    Each(X >> Min) :: Query

In the query form, `Min` finds the minimum of its input elements.

```jldoctest
julia> X = Lift(1:3);

julia> unitknot[X >> Min]
┼───┼
│ 1 │
```
"""
Min(X) =
    Query(Min, X)

Lift(::typeof(Min)) =
    Then(Min)

function Sum(env::Environment, p::Pipeline, X)
    x = assemble(env, target_pipe(p), X)
    assemble_lift(p, sum, Pipeline[x])
end

maximum_missing(v) =
    !isempty(v) ? maximum(v) : missing

function Max(env::Environment, p::Pipeline, X)
    x = assemble(env, target_pipe(p), X)
    card = cardinality(target(x))
    optional = fits(x0to1, card)
    assemble_lift(p, optional ? maximum_missing : maximum, Pipeline[x])
end

minimum_missing(v) =
    !isempty(v) ? minimum(v) : missing

function Min(env::Environment, p::Pipeline, X)
    x = assemble(env, target_pipe(p), X)
    card = cardinality(target(x))
    optional = fits(x0to1, card)
    assemble_lift(p, optional ? minimum_missing : minimum, Pipeline[x])
end

translate(mod::Module, ::Val{:count}, (arg,)::Tuple{Any}) =
    Count(translate(mod, arg))

translate(mod::Module, ::Val{:count}, ::Tuple{}) =
    Then(Count)

translate(mod::Module, ::Val{:exists}, (arg,)::Tuple{Any}) =
    Exists(translate(mod, arg))

translate(mod::Module, ::Val{:exists}, ::Tuple{}) =
    Then(Exists)

translate(mod::Module, ::Val{:sum}, (arg,)::Tuple{Any}) =
    Sum(translate(mod, arg))

translate(mod::Module, ::Val{:sum}, ::Tuple{}) =
    Then(Sum)

translate(mod::Module, ::Val{:max}, (arg,)::Tuple{Any}) =
    Max(translate(mod, arg))

translate(mod::Module, ::Val{:max}, ::Tuple{}) =
    Then(Max)

translate(mod::Module, ::Val{:min}, (arg,)::Tuple{Any}) =
    Min(translate(mod, arg))

translate(mod::Module, ::Val{:min}, ::Tuple{}) =
    Then(Min)


#
# Filter combinator.
#

function assemble_filter(p::Pipeline, x::Pipeline)
    x = uncover(x)
    fits(target(x), BlockOf(ValueOf(Bool))) || error("expected a predicate")
    q = chain_of(tuple_of(pass(),
                          chain_of(x, block_any())),
                 sieve_by(),
    ) |> designate(source(x), BlockOf(source(x), x0to1) |> IsFlow)
    compose(p, q)
end

"""
    Filter(X) :: Query

This query emits the elements from its input that satisfy a given
condition.

```jldoctest
julia> unitknot[Lift(1:5) >> Filter(isodd.(It))]
──┼───┼
1 │ 1 │
2 │ 3 │
3 │ 5 │
```

When the predicate query produces an empty output, the condition
is presumed to have failed.

```jldoctest
julia> unitknot[Lift('a':'c') >> Filter(missing)]
(empty)
```

When the predicate produces plural output, the condition succeeds
if at least one output value is `true`.

```jldoctest
julia> unitknot[Lift('a':'c') >> Filter([true,false])]
──┼───┼
1 │ a │
2 │ b │
3 │ c │
```
"""
Filter(X) =
    Query(Filter, X)

function Filter(env::Environment, p::Pipeline, X)
    x = assemble(env, target_pipe(p), X)
    assemble_filter(p, x)
end

translate(mod::Module, ::Val{:filter}, (arg,)::Tuple{Any}) =
    Filter(translate(mod, arg))


#
# First, Last, Nth.
#

assemble_first(p::Pipeline, inv::Bool=false) =
    assemble_nth(p, !inv ? 1 : -1, cardinality(target(p))&x0to1)

function assemble_nth(p::Pipeline, n::Int, card::Cardinality=x0to1)
    elts = elements(target(p))
    chain_of(
        p,
        get_by(n, card),
    ) |> designate(source(p), BlockOf(elts, card) |> IsFlow)
end

function assemble_nth(p::Pipeline, n::Pipeline)
    n = uncover(n)
    fits(target(n), BlockOf(ValueOf(Int), x1to1)) || error("expected a singular mandatory integer")
    src = source(p)
    tgt = BlockOf(elements(target(p)), x0to1) |> IsFlow
    chain_of(
        tuple_of(p, n),
        get_by(),
    ) |> designate(src, tgt)
end
 
"""
    First(X) :: Query

In the combinator form, `First(X)` emits the first element produced by its argument `X`.

```jldoctest
julia> X = Lift('a':'c');

julia> unitknot[First(X)]
┼───┼
│ a │
```
---

    Each(X >> First) :: Query

In the query form, `First` emits the first element of its input.

```jldoctest
julia> X = Lift('a':'c');

julia> unitknot[X >> First]
┼───┼
│ a │
```
"""
First(X) = Query(First, X)

"""
    Last(X) :: Query

In the combinator form, `Last(X)` emits the last element produced by its argument `X`.

```jldoctest
julia> X = Lift('a':'c');

julia> unitknot[Last(X)]
┼───┼
│ c │
```
---

    Each(X >> Last) :: Query

In the query form, `Last` emits the last element of its input.

```jldoctest
julia> X = Lift('a':'c');

julia> unitknot[X >> Last]
┼───┼
│ c │
```
"""
Last(X) = Query(Last, X)

"""
    Nth(X, N) :: Query

In the combinator form, `Nth(X, N)` emits the `N`th element produced by its argument `X`.

```jldoctest
julia> X = Lift('a':'d');

julia> N = Count(X) .÷ 2;

julia> unitknot[Nth(X, N)]
┼───┼
│ b │
```
---

    Each(X >> Nth(N)) :: Query

In the query form, `Nth(N)` emits the `N`th element produced by its input.

```jldoctest
julia> X = Lift('a':'d');

julia> N = Count(X) .÷ 2;

julia> unitknot[X >> Nth(N)]
┼───┼
│ b │
```
"""
Nth(X, N) = Query(Nth, X, N)

Lift(::typeof(First)) =
    Then(First)

Lift(::typeof(Last)) =
    Then(Last)

Nth(N) = Query(Nth, N)

function First(env::Environment, p::Pipeline, X)
    x = assemble(env, target_pipe(p), X)
    compose(p, assemble_first(x))
end

function Last(env::Environment, p::Pipeline, X)
    x = assemble(env, target_pipe(p), X)
    compose(p, assemble_first(x, true))
end

function Nth(env::Environment, p::Pipeline, X, N::Int)
    x = assemble(env, target_pipe(p), X)
    compose(p, assemble_nth(x, N))
end

function Nth(env::Environment, p::Pipeline, X, N)
    p0 = target_pipe(p)
    x = assemble(env, p0, X)
    n = assemble(env, p0, N)
    compose(p, assemble_nth(x, n))
end

Nth(env::Environment, p::Pipeline, N::Int) =
    assemble_nth(p, N)

Nth(env::Environment, p::Pipeline, N) =
    assemble_nth(p, assemble(env, source_pipe(p), N))

translate(mod::Module, ::Val{:first}, (arg,)::Tuple{Any}) =
    First(translate(mod, arg))

translate(mod::Module, ::Val{:first}, ::Tuple{}) =
    Then(First)

translate(mod::Module, ::Val{:last}, (arg,)::Tuple{Any}) =
    Last(translate(mod, arg))

translate(mod::Module, ::Val{:last}, ::Tuple{}) =
    Then(Last)

translate(mod::Module, ::Val{:nth}, args::Tuple{Any,Any}) =
    Nth(translate.(Ref(mod), args)...)

translate(mod::Module, ::Val{:nth}, (arg,)::Tuple{Any}) =
    Nth(translate(mod, arg))


#
# Take and Drop combinators.
#

function assemble_take(p::Pipeline, n::Union{Int,Missing}, inv::Bool)
    elts = elements(target(p))
    card = cardinality(target(p))|x0to1
    chain_of(
        p,
        slice_by(n, inv),
    ) |> designate(source(p), BlockOf(elts, card) |> IsFlow)
end

function assemble_take(p::Pipeline, n::Pipeline, inv::Bool)
    n = uncover(n)
    fits(target(n), BlockOf(ValueOf(Int), x0to1)) || error("expected a singular integer")
    src = source(p)
    tgt = BlockOf(elements(target(p)), cardinality(target(p))|x0to1) |> IsFlow
    chain_of(
        tuple_of(p, n),
        slice_by(inv),
    ) |> designate(src, tgt)
end

"""
    Take(N) :: Query

This query preserves the first `N` elements of its input, dropping
the rest.

```jldoctest
julia> unitknot[Lift('a':'c') >> Take(2)]
──┼───┼
1 │ a │
2 │ b │
```

`Take(-N)` drops the last `N` elements.

```jldoctest
julia> unitknot[Lift('a':'c') >> Take(-2)]
──┼───┼
1 │ a │
```
"""
Take(N) =
    Query(Take, N)

"""
    Drop(N) :: Query

This query drops the first `N` elements of its input, preserving
the rest.

```jldoctest
julia> unitknot[Lift('a':'c') >> Drop(2)]
──┼───┼
1 │ c │
```

`Drop(-N)` takes the last `N` elements.

```jldoctest
julia> unitknot[Lift('a':'c') >> Drop(-2)]
──┼───┼
1 │ b │
2 │ c │
```
"""
Drop(N) =
    Query(Drop, N)

Take(env::Environment, p::Pipeline, n::Union{Int,Missing}, inv::Bool=false) =
    assemble_take(p, n, inv)

function Take(env::Environment, p::Pipeline, N, inv::Bool=false)
    n = assemble(env, source_pipe(p), N)
    assemble_take(p, n, inv)
end

Drop(env::Environment, p::Pipeline, N) =
    Take(env, p, N, true)

translate(mod::Module, ::Val{:take}, (arg,)::Tuple{Any}) =
    Take(translate(mod, arg))

translate(mod::Module, ::Val{:drop}, (arg,)::Tuple{Any}) =
    Drop(translate(mod, arg))


#
# Unique and Group combinators.
#

function assemble_unique(p::Pipeline, x::Pipeline)
    x = uncover(x)
    q = chain_of(x, unique_by()) |> designate(source(x), target(x)) |> cover
    compose(p, q)
end

"""
    Unique(X) :: Query

This query produces all distinct elements emitted by `X`.

```jldoctest
julia> unitknot[Unique(['a','b','b','c','c','c'])]
──┼───┼
1 │ a │
2 │ b │
3 │ c │
```

---

    Each(X >> Unique) :: Query

In the query form, `Unique` produces all distinct elements of its input.

```jldoctest
julia> unitknot[Lift(['a','b','b','c','c','c']) >> Unique]
──┼───┼
1 │ a │
2 │ b │
3 │ c │
```
"""
Unique(X) =
    Query(Unique, X)

Lift(::typeof(Unique)) =
    Then(Unique)

function Unique(env::Environment, p::Pipeline, X)
    x = assemble(env, target_pipe(p), X)
    assemble_unique(p, x)
end

translate(mod::Module, ::Val{:unique}, (arg,)::Tuple{Any}) =
    Unique(translate(mod, arg))

translate(mod::Module, ::Val{:unique}, ::Tuple{}) =
    Then(Unique)

function assemble_group(p::Pipeline, xs::Vector{Pipeline})
    lbls = Symbol[]
    ks = Pipeline[]
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
            lbls[seen[lbl]] = ordinal_label(seen[lbl])
        end
        seen[lbl] = i
        push!(lbls, lbl)
        push!(ks, x)
    end
    p0 = uncover(target_pipe(p))
    lbl = getlabel(p0, nothing)
    if lbl !== nothing
        p0 = relabel(p0, nothing)
    else
        lbl = ordinal_label(length(xs)+1)
    end
    if lbl in keys(seen)
        lbls[seen[lbl]] = ordinal_label(seen[lbl])
    end
    push!(lbls, lbl)
    src = elements(target(p))
    tgt = TupleOf(target(p0), TupleOf(target.(ks)))
    q = tuple_of(p0, tuple_of(Symbol[], ks)) |> designate(src, tgt)
    r = uncover(compose(p, cover(q)))
    cols = Pipeline[]
    for (i, k) in enumerate(ks)
        col = chain_of(column(2), column(i)) |> designate(elements(target(r)), target(k))
        push!(cols, col)
    end
    card = cardinality(target(r)) & x1toN
    col = chain_of(column(1), flatten()) |> designate(elements(target(r)),
                                                      BlockOf(elements(target(p0)), card))
    push!(cols, col)
    src = source(r)
    tgt = replace_elements(target(r), TupleOf(lbls, target.(cols)))
    chain_of(
        r,
        group_by(),
        with_elements(tuple_of(lbls, cols)),
    ) |> designate(src, tgt) |> cover
end

"""
    Group(X₁, X₂ … Xₙ) :: Query

This query groups the input data by the keys `X₁`, `X₂` … `Xₙ`.

```jldoctest
julia> unitknot[Lift(1:5) >> Group(isodd.(It))]
  │ #A     #B      │
──┼────────────────┼
1 │ false  2; 4    │
2 │  true  1; 3; 5 │
```
"""
Group(Xs...) =
    Query(Group, Xs...)

function Group(env::Environment, p::Pipeline, Xs...)
    xs = assemble.(Ref(env), Ref(target_pipe(p)), collect(AbstractQuery, Xs))
    assemble_group(p, xs)
end

translate(mod::Module, ::Val{:group}, args::Tuple) =
    Group(translate.(Ref(mod), args)...)


#
# Cardinality assertions.
#

function assemble_cardinality(p::Pipeline, card::Cardinality)
    src = source(p)
    tgt = BlockOf(elements(target(p)), card) |> IsFlow
    q = block_cardinality(card, getlabel(src, nothing), getlabel(tgt, nothing))
    chain_of(p, q) |> designate(src, tgt)
end

"""
    Is0to1(X) :: Query

This query asserts that `X` emits 0 or 1 element.

---

    Each(X >> Is0to1) :: Query

In this form, `Is0to1` asserts that its input contains 0 or 1 element.
"""
Is0to1(X) = Query(Is0to1, X)

"""
    Is0toN(X) :: Query

This query asserts that `X` may emit any number of elements.

---

    Each(X >> Is0toN) :: Query

In this form, `Is0toN` asserts that its input contains any number of elements.
"""
Is0toN(X) = Query(Is0toN, X)

"""
    Is1to1(X) :: Query

This query asserts that `X` emits 1 element.

---

    Each(X >> Is1to1) :: Query

In this form, `Is1to1` asserts that its input contains 1 element.
"""
Is1to1(X) = Query(Is1to1, X)

"""
    Is1toN(X) :: Query

This query asserts that `X` emits 1 or more elements.

---

    Each(X >> Is1toN) :: Query

In this form, `Is1toN` asserts that its input contains 1 or more elements.
"""
Is1toN(X) = Query(Is1toN, X)

Lift(::typeof(Is0to1)) = Then(Is0to1)

Lift(::typeof(Is0toN)) = Then(Is0toN)

Lift(::typeof(Is1to1)) = Then(Is1to1)

Lift(::typeof(Is1toN)) = Then(Is1toN)

Is0to1(env::Environment, p::Pipeline, X) =
    assemble_cardinality(assemble(env, p, X), x0to1)

Is0toN(env::Environment, p::Pipeline, X) =
    assemble_cardinality(assemble(env, p, X), x0toN)

Is1to1(env::Environment, p::Pipeline, X) =
    assemble_cardinality(assemble(env, p, X), x1to1)

Is1toN(env::Environment, p::Pipeline, X) =
    assemble_cardinality(assemble(env, p, X), x1toN)

translate(mod::Module, ::Val{:is0to1}, (arg,)::Tuple{Any}) =
    Is0to1(translate(mod, arg))

translate(mod::Module, ::Val{:is0toN}, (arg,)::Tuple{Any}) =
    Is0toN(translate(mod, arg))

translate(mod::Module, ::Val{:is1to1}, (arg,)::Tuple{Any}) =
    Is1to1(translate(mod, arg))

translate(mod::Module, ::Val{:is1toN}, (arg,)::Tuple{Any}) =
    Is1toN(translate(mod, arg))

translate(mod::Module, ::Val{:is0to1}, ::Tuple{}) =
    Then(Is0to1)

translate(mod::Module, ::Val{:is0toN}, ::Tuple{}) =
    Then(Is0toN)

translate(mod::Module, ::Val{:is1to1}, ::Tuple{}) =
    Then(Is1to1)

translate(mod::Module, ::Val{:is1toN}, ::Tuple{}) =
    Then(Is1toN)

