#
# Combinator algebra of vectorized data transformations.
#

import Base:
    OneTo,
    show

using Base.Cartesian


#
# Query interface.
#

"""
    Runtime()

Runtime state for query evaluation.
"""
mutable struct Runtime
end

"""
    Query(op, args...)

A query object represents a vectorized data transformation.

Parameter `op` is a function that performs the transformation; `args` are
extra arguments to be passed to the function.

The query transforms any input vector by invoking `op` with the following
arguments:

    op(rt::Runtime, input::AbstractVector, args...)

The result of `op` must be the output vector, which should be of the same
length as the input vector.
"""
struct Query
    op
    args::Vector{Any}
    sig::Signature

    Query(op, args::Vector{Any}, sig::Signature) =
        new(op, args, sig)
end

let NO_SIG = Signature()

    global Query

    Query(op, args...) =
        Query(op, collect(Any, args), NO_SIG)
end

"""
    designate(::Query, ::Signature) :: Query
    designate(::Query, ::InputShape, ::OutputShape) :: Query
    q::Query |> designate(::Signature) :: Query
    q::Query |> designate(::InputShape, ::OutputShape) :: Query

Sets the query signature.
"""
function designate end

designate(q::Query, sig::Signature) =
    Query(q.op, q.args, sig)

designate(q::Query, ishp::InputShape, shp::OutputShape) =
    Query(q.op, q.args, Signature(ishp, shp))

designate(sig::Signature) =
    q::Query -> designate(q, sig)

designate(ishp::InputShape, shp::OutputShape) =
    q::Query -> designate(q, Signature(ishp, shp))

"""
    signature(::Query) :: Signature

Returns the query signature.
"""
signature(q::Query) = q.sig

shape(q::Query) = shape(q.sig)

ishape(q::Query) = ishape(q.sig)

decoration(q::Query) = decoration(q.sig)

idecoration(q::Query) = idecoration(q.sig)

domain(q::Query) = domain(q.sig)

idomain(q::Query) = idomain(q.sig)

mode(q::Query) = mode(q.sig)

imode(q::Query) = imode(q.sig)

cardinality(q::Query) = cardinality(q.sig)

isregular(q::Query) = isregular(q.sig)

isoptional(q::Query) = isoptional(q.sig)

isplural(q::Query) = isplural(q.sig)

isfree(q::Query) = isfree(q.sig)

isframed(q::Query) = isframed(q.sig)

slots(q::Query) = slots(q.sig)

function (q::Query)(input::AbstractVector)
    rt = Runtime()
    output = q(rt, input)
end

function (q::Query)(rt::Runtime, input::AbstractVector)
    q.op(rt, input, q.args...)
end

syntax(q::Query) =
    syntax(q.op, q.args)

show(io::IO, q::Query) =
    print_expr(io, syntax(q))

"""
    optimize(::Query) :: Query

Rewrites the query to make it (hopefully) faster.
"""
optimize(q::Query) =
    simplify(q) |> designate(q.sig)


#
# Vectorizing scalar functions.
#

"""
    lift(f) :: Query

`f` is any scalar unary function.

The query applies `f` to each element of the input vector.
"""
lift(f) = Query(lift, f)

lift(rt::Runtime, input::AbstractVector, f) =
    f.(input)

"""
    tuple_lift(f) :: Query

`f` is an n-ary function.

The query applies `f` to each row of an n-tuple vector.
"""
tuple_lift(f) = Query(tuple_lift, f)

function tuple_lift(rt::Runtime, input::AbstractVector, f)
    @assert input isa TupleVector
    _tuple_lift(f, length(input), columns(input)...)
end

@generated function _tuple_lift(f, len::Int, cols::AbstractVector...)
    D = length(cols)
    return quote
        I = Tuple{eltype.(cols)...}
        O = Core.Compiler.return_type(f, I)
        output = Vector{O}(undef, len)
        @inbounds for k = 1:len
            output[k] = @ncall $D f (d -> cols[d][k])
        end
        output
    end
end

"""
    block_lift(f) :: Query
    block_lift(f, default) :: Query

`f` is a function that expects a vector argument.

The query applies `f` to each block of the input block vector.  When a block is
empty, `default` (if specified) is used as the output value.
"""
function block_lift end

block_lift(f) = Query(block_lift, f)

function block_lift(rt::Runtime, input::AbstractVector, f)
    @assert input isa BlockVector
    _block_lift(f, input)
end

block_lift(f, default) = Query(block_lift, f, default)

function block_lift(rt::Runtime, input::AbstractVector, f, default)
    @assert input isa BlockVector
    _block_lift(f, default, input)
end

function _block_lift(f, input)
    I = Tuple{typeof(cursor(input))}
    O = Core.Compiler.return_type(f, I)
    output = Vector{O}(undef, length(input))
    @inbounds for cr in cursor(input)
        output[cr.pos] = f(cr)
    end
    output
end

function _block_lift(f, default, input)
    I = Tuple{typeof(cursor(input))}
    O = Union{Core.Compiler.return_type(f, I), typeof(default)}
    output = Vector{O}(undef, length(input))
    @inbounds for cr in cursor(input)
        output[cr.pos] = !isempty(cr) ? f(cr) : default
    end
    output
end

"""
    record_lift(f) :: Query

`f` is an n-ary function.

This query expects the input to be an n-tuple vector with each column being a
block vector.  The query produces a block vector, where each block is generated
by applying `f` to every combination of values from the input blocks.
"""
record_lift(f) = Query(record_lift, f)

function record_lift(rt::Runtime, input::AbstractVector, f)
    @assert input isa TupleVector && all(col isa BlockVector for col in columns(input))
    _record_lift(f, length(input), columns(input)...)
end

@generated function _record_lift(f, len::Int, cols::BlockVector...)
    D = length(cols)
    CARD = |(x1to1, cardinality.(cols)...)
    return quote
        @nextract $D offs (d -> offsets(cols[d]))
        @nextract $D elts (d -> elements(cols[d]))
        if @nall $D (d -> offs_d isa Base.OneTo{Int})
            return BlockVector{$CARD}(:, _tuple_lift(f, len, (@ntuple $D elts)...))
        end
        len′ = 0
        regular = true
        @inbounds for k = 1:len
            sz = @ncall $D (*) (d -> (offs_d[k+1] - offs_d[k]))
            len′ += sz
            regular = regular && sz == 1
        end
        if regular
            return BlockVector{$CARD}(:, _tuple_lift(f, len, (@ntuple $D elts)...))
        end
        I = Tuple{eltype.(@ntuple $D elts)...}
        O = Core.Compiler.return_type(f, I)
        offs′ = Vector{Int}(undef, len+1)
        elts′ = Vector{O}(undef, len′)
        @inbounds offs′[1] = top = 1
        @inbounds for k = 1:len
            @nloops $D n (d -> offs_{$D-d+1}[k]:offs_{$D-d+1}[k+1]-1) (d -> elt_{$D-d+1} = elts_{$D-d+1}[n_d]) begin
                elts′[top] = @ncall $D f (d -> elt_d)
                top += 1
            end
            offs′[k+1] = top
        end
        return BlockVector{$CARD}(offs′, elts′)
    end
end

"""
    filler(val) :: Query

This query produces a vector filled with the given value.
"""
filler(val) = Query(filler, val)

filler(rt::Runtime, input::AbstractVector, val) =
    fill(val, length(input))

"""
    null_filler() :: Query

This query produces a block vector with empty blocks.
"""
null_filler() = Query(null_filler)

null_filler(rt::Runtime, input::AbstractVector) =
    BlockVector(fill(1, length(input)+1), Union{}[], x0to1)

"""
    block_filler(block::AbstractVector, card::Cardinality) :: Query

This query produces a block vector filled with the given block.
"""
block_filler(block, card::Cardinality=x0toN) = Query(block_filler, block, card)

function block_filler(rt::Runtime, input::AbstractVector, block::AbstractVector, card::Cardinality)
    if isempty(input)
        return BlockVector(:, block[[]], card)
    elseif length(input) == 1
        return BlockVector([1, length(block)+1], block, card)
    else
        len = length(input)
        sz = length(block)
        perm = Vector{Int}(undef, len*sz)
        for k in eachindex(input)
            copyto!(perm, 1 + sz * (k - 1), 1:sz)
        end
        return BlockVector(1:sz:(len*sz+1), block[perm], card)
    end
end


#
# Converting regular vectors to columnar vectors.
#

"""
    adapt_missing() :: Query

This query transforms a vector that contains `missing` elements to a block
vector with `missing` elements replaced by empty blocks.
"""
adapt_missing() = Query(adapt_missing)

function adapt_missing(rt::Runtime, input::AbstractVector)
    if !(Missing <: eltype(input))
        return BlockVector(:, input, x0to1)
    end
    sz = 0
    for elt in input
        if elt !== missing
            sz += 1
        end
    end
    O = Base.nonmissingtype(eltype(input))
    if sz == length(input)
        return BlockVector(:, collect(O, input), x0to1)
    end
    offs = Vector{Int}(undef, length(input)+1)
    elts = Vector{O}(undef, sz)
    @inbounds offs[1] = top = 1
    @inbounds for k in eachindex(input)
        elt = input[k]
        if elt !== missing
            elts[top] = elt
            top += 1
        end
        offs[k+1] = top
    end
    return BlockVector(offs, elts, x0to1)
end

"""
    adapt_vector() :: Query

This query transforms a vector with vector elements to a block vector.
"""
adapt_vector() = Query(adapt_vector)

function adapt_vector(rt::Runtime, input::AbstractVector)
    @assert eltype(input) <: AbstractVector
    sz = 0
    for v in input
        sz += length(v)
    end
    O = eltype(eltype(input))
    offs = Vector{Int}(undef, length(input)+1)
    elts = Vector{O}(undef, sz)
    @inbounds offs[1] = top = 1
    @inbounds for k in eachindex(input)
        v = input[k]
        copyto!(elts, top, v)
        top += length(v)
        offs[k+1] = top
    end
    return BlockVector(offs, elts, x0toN)
end

"""
    adapt_tuple() :: Query

This query transforms a vector of tuples to a tuple vector.
"""
adapt_tuple() = Query(adapt_tuple)

function adapt_tuple(rt::Runtime, input::AbstractVector)
    @assert eltype(input) <: Union{Tuple,NamedTuple}
    lbls = Symbol[]
    I = eltype(input)
    if typeof(I) == DataType && I <: NamedTuple
        lbls = collect(Symbol, I.parameters[1])
        I = I.parameters[2]
    end
    Is = (I.parameters...,)
    cols = _adapt_tuple(input, Is...)
    TupleVector(lbls, length(input), cols)
end

@generated function _adapt_tuple(input, Is...)
    width = length(Is)
    return quote
        len = length(input)
        cols = @ncall $width tuple j -> Vector{Is[j]}(undef, len)
        @inbounds for k in eachindex(input)
            t = input[k]
            @nexprs $width j -> cols[j][k] = t[j]
        end
        collect(AbstractVector, cols)
    end
end


#
# Identity and composition.
#

"""
    pass() :: Query

This query returns its input unchanged.
"""
pass() = Query(pass)

pass(rt::Runtime, input::AbstractVector) =
    input

"""
    chain_of(q₁::Query, q₂::Query … qₙ::Query) :: Query

This query sequentially applies `q₁`, `q₂` … `qₙ`.
"""
function chain_of end

chain_of() = pass()

chain_of(q) = q

function chain_of(qs...)
    qs′ = filter(q -> !(q isa Query && q.op == pass), collect(qs))
    isempty(qs′) ? pass() : length(qs′) == 1 ? qs′[1] : chain_of(qs′)
end

chain_of(qs::Vector) =
    Query(chain_of, qs)

syntax(::typeof(chain_of), args::Vector{Any}) =
    if length(args) == 1 && args[1] isa Vector
        Expr(:call, chain_of, syntax.(args[1])...)
    else
        Expr(:call, chain_of, syntax.(args)...)
    end

function chain_of(rt::Runtime, input::AbstractVector, qs)
    output = input
    for q in qs
        output = q(rt, output)
    end
    output
end


#
# Operations on tuple vectors.
#

"""
    tuple_of(q₁::Query, q₂::Query … qₙ::Query) :: Query

This query produces an n-tuple vector, whose columns are generated by applying
`q₁`, `q₂` … `qₙ` to the input vector.
"""
tuple_of(qs...) =
    tuple_of(Symbol[], collect(qs))

tuple_of(lqs::Pair{Symbol}...) =
    tuple_of(collect(Symbol, first.(lqs)), collect(last.(lqs)))

tuple_of(lbls::Vector{Symbol}, qs::Vector) = Query(tuple_of, lbls, qs)

syntax(::typeof(tuple_of), args::Vector{Any}) =
    if length(args) == 2 && args[1] isa Vector{Symbol} && args[2] isa Vector
        if isempty(args[1])
            Expr(:call, tuple_of, syntax.(args[2])...)
        else
            Expr(:call, tuple_of, syntax.(args[1] .=> args[2])...)
        end
    else
        Expr(:call, tuple_of, syntax.(args)...)
    end

function tuple_of(rt::Runtime, input::AbstractVector, lbls, qs)
    len = length(input)
    cols = AbstractVector[q(rt, input) for q in qs]
    TupleVector(lbls, len, cols)
end

"""
    column(lbl::Union{Int,Symbol}) :: Query

This query extracts the specified column of a tuple vector.
"""
column(lbl::Union{Int,Symbol}) = Query(column, lbl)

function column(rt::Runtime, input::AbstractVector, lbl)
    @assert input isa TupleVector
    j = locate(input, lbl)
    column(input, j)
end

"""
    with_column(lbl::Union{Int,Symbol}, q::Query) :: Query

This query transforms a tuple vector by applying `q` to the specified column.
"""
with_column(lbl::Union{Int,Symbol}, q) = Query(with_column, lbl, q)

function with_column(rt::Runtime, input::AbstractVector, lbl, q)
    @assert input isa TupleVector
    j = locate(input, lbl)
    cols′ = copy(columns(input))
    cols′[j] = q(rt, cols′[j])
    TupleVector(labels(input), length(input), cols′)
end


#
# Operations on block vectors.
#

"""
    wrap() :: Query

This query produces a block vector with one-element blocks wrapping the values
of the input vector.
"""
wrap() = Query(wrap)

wrap(rt::Runtime, input::AbstractVector) =
    BlockVector(:, input, x1to1)


"""
    with_elements(q::Query) :: Query

This query transforms a block vector by applying `q` to its vector of elements.
"""
with_elements(q) = Query(with_elements, q)

function with_elements(rt::Runtime, input::AbstractVector, q)
    @assert input isa BlockVector
    BlockVector(offsets(input), q(rt, elements(input)), cardinality(input))
end

"""
    flatten() :: Query

This query flattens a nested block vector.
"""
flatten() = Query(flatten)

function flatten(rt::Runtime, input::AbstractVector)
    @assert input isa BlockVector && elements(input) isa BlockVector
    offs = offsets(input)
    nested = elements(input)
    nested_offs = offsets(nested)
    elts = elements(nested)
    card = cardinality(input)|cardinality(nested)
    BlockVector(_flatten(offs, nested_offs), elts, card)
end

_flatten(offs1::AbstractVector{Int}, offs2::AbstractVector{Int}) =
    Int[offs2[off] for off in offs1]

_flatten(offs1::OneTo{Int}, offs2::OneTo{Int}) = offs1

_flatten(offs1::OneTo{Int}, offs2::AbstractVector{Int}) = offs2

_flatten(offs1::AbstractVector{Int}, offs2::OneTo{Int}) = offs1

"""
    distribute(lbl::Union{Int,Symbol}) :: Query

This query transforms a tuple vector with a column of blocks to a block vector
with tuple elements.
"""
distribute(lbl) = Query(distribute, lbl)

function distribute(rt::Runtime, input::AbstractVector, lbl)
    @assert input isa TupleVector && column(input, lbl) isa BlockVector
    j = locate(input, lbl)
    len = length(input)
    lbls = labels(input)
    cols = columns(input)
    col = cols[j]
    card = cardinality(col)
    offs = offsets(col)
    col′ = elements(col)
    cols′ = copy(cols)
    if offs isa OneTo{Int}
        cols′[j] = col′
        return BlockVector(offs, TupleVector(lbls, len, cols′), card)
    end
    len′ = length(col′)
    perm = Vector{Int}(undef, len′)
    l = r = 1
    @inbounds for k = 1:len
        l = r
        r = offs[k+1]
        for n = l:r-1
            perm[n] = k
        end
    end
    for i in eachindex(cols′)
        cols′[i] =
            if i == j
                col′
            else
                cols′[i][perm]
            end
    end
    return BlockVector(offs, TupleVector(lbls, len′, cols′), card)
end

"""
    distribute_all() :: Query

This query transforms a tuple vector with block columns to a block vector with
tuple elements.
"""
distribute_all() = Query(distribute_all)

function distribute_all(rt::Runtime, input::AbstractVector)
    @assert input isa TupleVector && all(col isa BlockVector for col in columns(input))
    cols = columns(input)
    _distribute_all(labels(input), length(input), cols...)
end

@generated function _distribute_all(lbls::Vector{Symbol}, len::Int, cols::BlockVector...)
    D = length(cols)
    CARD = |(x1to1, cardinality.(cols)...)
    return quote
        @nextract $D offs (d -> offsets(cols[d]))
        @nextract $D elts (d -> elements(cols[d]))
        if @nall $D (d -> offs_d isa OneTo{Int})
            return BlockVector{$CARD}(:, TupleVector(lbls, len, AbstractVector[(@ntuple $D elts)...]))
        end
        len′ = 0
        regular = true
        @inbounds for k = 1:len
            sz = @ncall $D (*) (d -> (offs_d[k+1] - offs_d[k]))
            len′ += sz
            regular = regular && sz == 1
        end
        if regular
            return BlockVector{$CARD}(:, TupleVector(lbls, len, AbstractVector[(@ntuple $D elts)...]))
        end
        offs′ = Vector{Int}(undef, len+1)
        @nextract $D perm (d -> Vector{Int}(undef, len′))
        @inbounds offs′[1] = top = 1
        @inbounds for k = 1:len
            @nloops $D n (d -> offs_{$D-d+1}[k]:offs_{$D-d+1}[k+1]-1) begin
                @nexprs $D (d -> perm_{$D-d+1}[top] = n_d)
                top += 1
            end
            offs′[k+1] = top
        end
        cols′ = @nref $D AbstractVector (d -> elts_d[perm_d])
        return BlockVector{$CARD}(offs′, TupleVector(lbls, len′, cols′))
    end
end

"""
    block_length() :: Query

This query converts a block vector to a vector of block lengths.
"""
block_length() = Query(block_length)

function block_length(rt::Runtime, input::AbstractVector)
    @assert input isa BlockVector
    _block_length(offsets(input))
end

_block_length(offs::OneTo{Int}) =
    fill(1, length(offs)-1)

function _block_length(offs::AbstractVector{Int})
    len = length(offs) - 1
    output = Vector{Int}(undef, len)
    @inbounds for k = 1:len
        output[k] = offs[k+1] - offs[k]
    end
    output
end

"""
    block_any() :: Query

This query applies `any` to a block vector with `Bool` elements.
"""
block_any() = Query(block_any)

function block_any(rt::Runtime, input::AbstractVector)
    @assert input isa BlockVector && eltype(elements(input)) <: Bool
    len = length(input)
    offs = offsets(input)
    elts = elements(input)
    if offs isa OneTo
        return elts
    end
    output = Vector{Bool}(undef, len)
    l = r = 1
    @inbounds for k = 1:len
        val = false
        l = r
        r = offs[k+1]
        for i = l:r-1
            if elts[i]
                val = true
                break
            end
        end
        output[k] = val
    end
    return output
end


#
# Filtering.
#

"""
    sieve() :: Query

This query filters a vector of pairs by the second column.  The query expects a
pair vector, whose second column is a `Bool` vector.  It produces a block
vector with 0-element or 1-element blocks containing the elements of the first
column.
"""
sieve() = Query(sieve)

function sieve(rt::Runtime, input::AbstractVector)
    @assert input isa TupleVector && eltype(column(input, 2)) <: Bool
    len = length(input)
    val_col, pred_col = columns(input)
    sz = count(pred_col)
    if sz == len
        return BlockVector(:, val_col, x0to1)
    elseif sz == 0
        return BlockVector(fill(1, len+1), val_col[[]], x0to1)
    end
    offs = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs[1] = top = 1
    for k = 1:len
        if pred_col[k]
            perm[top] = k
            top += 1
        end
        offs[k+1] = top
    end
    return BlockVector(offs, val_col[perm], x0to1)
end


#
# Slicing.
#

"""
    slice(N::Int, rev::Bool=false) :: Query

This query transforms a block vector by keeping the first `N` elements of each
block.  If `rev` is true, the query drops the first `N` elements of each block.
"""
slice(N::Union{Missing,Int}, rev::Bool=false) =
    Query(slice, N, rev)

function slice(rt::Runtime, input::AbstractVector, N::Missing, rev::Bool)
    @assert input isa BlockVector
    input
end

function slice(rt::Runtime, input::AbstractVector, N::Int, rev::Bool)
    @assert input isa BlockVector
    len = length(input)
    offs = offsets(input)
    elts = elements(input)
    sz = 0
    R = 1
    for k = 1:len
        L = R
        @inbounds R = offs[k+1]
        (l, r) = _take_range(N, R-L, rev)
        sz += r - l + 1
    end
    if sz == length(elts)
        return input
    end
    offs′ = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs′[1] = top = 1
    R = 1
    for k = 1:len
        L = R
        @inbounds R = offs[k+1]
        (l, r) = _take_range(N, R-L, rev)
        for j = (L + l - 1):(L + r - 1)
            perm[top] = j
            top += 1
        end
        offs′[k+1] = top
    end
    elts′ = elts[perm]
    card = cardinality(input)|x0to1
    return BlockVector(offs′, elts′, card)
end

"""
    slice(rev::Bool=false) :: Query

This query takes a pair vector of blocks and integers, and returns the first
column with blocks restricted by the second column.
"""
slice(rev::Bool=false) =
    Query(slice, rev)

function slice(rt::Runtime, input::AbstractVector, rev::Bool)
    @assert input isa TupleVector
    cols = columns(input)
    @assert length(cols) == 2
    vals, Ns = cols
    @assert vals isa BlockVector
    @assert eltype(Ns) <: Union{Missing,Int}
    len = length(input)
    offs = offsets(vals)
    elts = elements(vals)
    R = 1
    sz = 0
    for k = 1:len
        L = R
        @inbounds N = Ns[k]
        @inbounds R = offs[k+1]
        (l, r) = _take_range(N, R-L, rev)
        sz += r - l + 1
    end
    if sz == length(elts)
        return vals
    end
    offs′ = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs′[1] = top = 1
    R = 1
    for k = 1:len
        L = R
        @inbounds N = Ns[k]
        @inbounds R = offs[k+1]
        (l, r) = _take_range(N, R-L, rev)
        for j = (L + l - 1):(L + r - 1)
            perm[top] = j
            top += 1
        end
        offs′[k+1] = top
    end
    elts′ = elts[perm]
    card = cardinality(vals)|x0to1
    return BlockVector(offs′, elts′, card)
end

@inline _take_range(n::Int, l::Int, rev::Bool) =
    if !rev
        (1, n >= 0 ? min(l, n) : max(0, l + n))
    else
        (n >= 0 ? min(l + 1, n + 1) : max(1, l + n + 1), l)
    end

@inline _take_range(::Missing, l::Int, ::Bool) =
    (1, l)


#
# Optimizing a query expression.
#

function simplify(q::Query)
    qs = simplify_chain(q)
    if isempty(qs)
        return pass()
    elseif length(qs) == 1
        return qs[1]
    else
        return chain_of(qs)
    end
end

simplify(qs::Vector{Query}) =
    simplify.(qs)

simplify(other) = other

function simplify_chain(q::Query)
    if q.op == pass
        return Query[]
    elseif q.op == chain_of
        return simplify_block(vcat(simplify_chain.(q.args[1])...))
    else
        return [Query(q.op, simplify.(q.args)...)]
    end
end

function simplify_block(qs)
    while true
        if !any(qs[k].op == wrap && qs[k+1].op == with_elements && qs[k+2].op == flatten
                for k = 1:length(qs)-2)
            return qs
        end
        qs′ = Query[]
        k = 1
        while k <= length(qs)
            if k <= length(qs)-2 && qs[k].op == wrap && qs[k+1].op == with_elements && qs[k+2].op == flatten
                q = qs[k+1].args[1]
                if q.op == pass
                elseif q.op == chain_of
                    append!(qs′, q.args[1])
                else
                    push!(qs′, q)
                end
                k += 3
            else
                push!(qs′, qs[k])
                k += 1
            end
        end
        qs = qs′
    end
end
