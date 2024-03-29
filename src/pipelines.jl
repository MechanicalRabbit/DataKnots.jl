#
# Combinator algebra of vectorized data transformations.
#

import Base:
    OneTo,
    show

using Base.Cartesian


#
# Pipeline interface.
#

"""
    Runtime()

Runtime state for pipeline evaluation.
"""
mutable struct Runtime
end

"""
    Pipeline(op, args...)

A pipeline object represents a vectorized data transformation.

Parameter `op` is a function that performs the transformation; `args` are extra
arguments to be passed to the function.

The pipeline transforms any input vector by invoking `op` with the following
arguments:

    op(rt::Runtime, input::AbstractVector, args...)

The result of `op` must be the output vector, which should be of the same
length as the input vector.
"""
struct Pipeline
    op
    args::Vector{Any}
    sig::Signature

    Pipeline(op; args::Vector{Any}=Any[], sig::Signature=Signature()) =
        new(op, args, sig)
end

Pipeline(op, args...) =
    Pipeline(op, args=Any[args...])

"""
    designate(::Pipeline, ::Signature) :: Pipeline
    designate(::Pipeline, ::AbstractShape, ::AbstractShape) :: Pipeline
    p::Pipeline |> designate(::Signature) :: Pipeline
    p::Pipeline |> designate(::AbstractShape, ::AbstractShape) :: Pipeline

Sets the pipeline signature.
"""
function designate end

designate(p::Pipeline, sig::Signature) =
    Pipeline(p.op, args=p.args, sig=sig)

designate(p::Pipeline, src::Union{AbstractShape,Type}, tgt::Union{AbstractShape,Type}) =
    Pipeline(p.op, args=p.args, sig=Signature(src, tgt))

designate(sig::Signature) =
    p::Pipeline -> designate(p, sig)

designate(src::Union{AbstractShape,Type}, tgt::Union{AbstractShape,Type}) =
    p::Pipeline -> designate(p, Signature(src, tgt))

"""
    signature(::Pipeline) :: Signature

Returns the pipeline signature.
"""
signature(p::Pipeline) = p.sig

source(p::Pipeline) = source(p.sig)

target(p::Pipeline) = target(p.sig)

function (p::Pipeline)(input::DataKnot)
    @assert fits(shape(input), source(p))
    DataKnot(target(p), p(cell(input)))
end

function (p::Pipeline)(@nospecialize input::AbstractVector)::AbstractVector
    rt = Runtime()
    output = p(rt, input)
end

function (p::Pipeline)(rt::Runtime, @nospecialize input::AbstractVector)::AbstractVector
    p.op(rt, input, p.args...)
end

quoteof(p::Pipeline) =
    quoteof(p.op, p.args)

show(io::IO, p::Pipeline) =
    print_expr(io, quoteof(p))


#
# Vectorizing scalar functions.
#

"""
    lift(f) :: Pipeline

`f` is any scalar unary function.

The pipeline applies `f` to each element of the input vector.
"""
lift(f) = Pipeline(lift, f)

lift(f, args...) = Pipeline(lift, f, args)

lift(rt::Runtime, input::AbstractVector, f) =
    f.(input)

lift(rt::Runtime, input::AbstractVector, f, args) =
    f.(input, Ref.(args)...)

"""
    tuple_lift(f) :: Pipeline

`f` is an n-ary function.

The pipeline applies `f` to each row of an n-tuple vector.
"""
tuple_lift(f) = Pipeline(tuple_lift, f)

function tuple_lift(rt::Runtime, input::AbstractVector, f)
    @assert input isa TupleVector
    _tuple_lift(f, length(input), columns(input)...)
end

@generated function _tuple_lift(f, len::Int, cols::AbstractVector...)
    D = length(cols)
    return quote
        I = Tuple{Any[eltype(col) for col in cols]...}
        O = Core.Compiler.return_type(f, I)
        output = Vector{O}(undef, len)
        @inbounds for k = 1:len
            output[k] = @ncall $D f (d -> cols[d][k])
        end
        output
    end
end

"""
    block_lift(f) :: Pipeline
    block_lift(f, default) :: Pipeline

`f` is a function that expects a vector argument.

The pipeline applies `f` to each block of the input block vector.  When a block
is empty, `default` (if specified) is used as the output value.
"""
function block_lift end

block_lift(f) = Pipeline(block_lift, f)

function block_lift(rt::Runtime, input::AbstractVector, f)
    @assert input isa BlockVector
    _block_lift(f, input)
end

block_lift(f, default) = Pipeline(block_lift, f, default)

function block_lift(rt::Runtime, input::AbstractVector, f, default)
    @assert input isa BlockVector
    _block_lift(f, default, input)
end

function _block_lift(f, input)
    cr = cursor(input)
    I = Tuple{typeof(cr)}
    O = Core.Compiler.return_type(f, I)
    output = Vector{O}(undef, length(input))
    @inbounds while next!(cr)
        output[cr.pos] = f(cr)
    end
    output
end

function _block_lift(f, default, input)
    cr = cursor(input)
    I = Tuple{typeof(cr)}
    O = Union{Core.Compiler.return_type(f, I), typeof(default)}
    output = Vector{O}(undef, length(input))
    @inbounds while next!(cr)
        output[cr.pos] = !isempty(cr) ? f(cr) : default
    end
    output
end

"""
    filler(val) :: Pipeline

This pipeline produces a vector filled with the given value.
"""
filler(val) = Pipeline(filler, val)

filler(rt::Runtime, input::AbstractVector, val) =
    fill(val, length(input))

"""
    null_filler() :: Pipeline

This pipeline produces a block vector with empty blocks.
"""
null_filler() = Pipeline(null_filler)

null_filler(rt::Runtime, input::AbstractVector) =
    BlockVector(fill(1, length(input)+1), Union{}[], x0to1)

"""
    block_filler(block::AbstractVector, card::Cardinality) :: Pipeline

This pipeline produces a block vector filled with the given block.
"""
block_filler(block, card::Cardinality=x0toN) = Pipeline(block_filler, block, card)

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
    adapt_missing() :: Pipeline

This pipeline transforms a vector that contains `missing` elements to a block
vector with `missing` elements replaced by empty blocks.
"""
adapt_missing() = Pipeline(adapt_missing)

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
    adapt_vector() :: Pipeline

This pipeline transforms a vector with vector elements to a block vector.
"""
adapt_vector() = Pipeline(adapt_vector)

function adapt_vector(rt::Runtime, input::AbstractVector)
    @assert eltype(input) <: AbstractVector
    if eltype(input) === Union{}
        return BlockVector(fill(1, length(input)+1), Union{}[], x0toN)
    end
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
    adapt_tuple() :: Pipeline

This pipeline transforms a vector of tuples to a tuple vector.
"""
adapt_tuple() = Pipeline(adapt_tuple)

function adapt_tuple(rt::Runtime, input::AbstractVector)
    @assert eltype(input) <: Union{Tuple,NamedTuple}
    lbls = Symbol[]
    I = eltype(input)
    if typeof(I) == DataType && I <: NamedTuple
        lbls = collect(Symbol, I.parameters[1])
        I = I.parameters[2]
    end
    cols = _adapt_tuple(input, Val(Tuple{I.parameters...}))
    TupleVector(lbls, length(input), cols)
end

@generated function _adapt_tuple(input, vty)
    Is = (vty.parameters[1].parameters...,)
    D = length(Is)
    return quote
        len = length(input)
        @nexprs $D j -> col_j = Vector{$Is[j]}(undef, len)
        @inbounds for k in eachindex(input)
            t = input[k]
            @nexprs $D j -> col_j[k] = t[j]
        end
        @nref $D AbstractVector j -> col_j
    end
end

"""
    assert_type(T::Type, lbl) :: Pipeline

This pipeline asserts the types of the elements of the input vector.
"""
assert_type(T::Type, lbl::Union{Symbol,Nothing}) =
    Pipeline(assert_type, T, lbl)

assert_type(T::Type) =
    Pipeline(assert_type, T)

function assert_type(rt::Runtime, input::AbstractVector, T, lbl=nothing)
    if eltype(input) <: T
        return input
    end
    if isempty(input)
        return T[]
    end
    output = Vector{T}(undef, length(input))
    @inbounds for i in eachindex(input)
        val = input[i]
        val isa T || error(lbl !== nothing ? "\"$lbl\"" : "", "[$i]: expected a value of type $T; got $(typeof(val))")
        output[i] = val
    end
    output
end


#
# Identity and composition.
#

"""
    pass() :: Pipeline

This pipeline returns its input unchanged.
"""
pass() = Pipeline(pass)

pass(rt::Runtime, @nospecialize input::AbstractVector) =
    input

"""
    chain_of(p₁::Pipeline, p₂::Pipeline … pₙ::Pipeline) :: Pipeline

This pipeline sequentially applies `p₁`, `p₂` … `pₙ`.
"""
function chain_of end

chain_of() = pass()

chain_of(p) = p

function chain_of(ps...)
    ps′ = filter(p -> !(p isa Pipeline && p.op == pass), collect(ps))
    isempty(ps′) ? pass() : length(ps′) == 1 ? ps′[1] : chain_of(ps′)
end

chain_of(ps::Vector) =
    Pipeline(chain_of, ps)

quoteof(::typeof(chain_of), args::Vector{Any}) =
    if length(args) == 1 && args[1] isa Vector
        Expr(:call, chain_of, Any[quoteof(arg) for arg in args[1]]...)
    else
        Expr(:call, chain_of, Any[quoteof(arg) for arg in args]...)
    end

function chain_of(rt::Runtime, @nospecialize(input::AbstractVector), ps)
    output = input
    for p in ps
        output = p(rt, output)
    end
    output
end


#
# Operations on tuple vectors.
#

"""
    tuple_of(p₁::Pipeline, p₂::Pipeline … pₙ::Pipeline) :: Pipeline

This pipeline produces an n-tuple vector, whose columns are generated by
applying `p₁`, `p₂` … `pₙ` to the input vector.
"""
tuple_of(ps...) =
    tuple_of(Symbol[], collect(ps))

tuple_of(lps::Pair{Symbol}...) =
    tuple_of(Symbol[first(lp) for lp in lps], Pipeline[last(lp) for lp in lps])

tuple_of(lbls::Vector{Symbol}, ps::Vector) = Pipeline(tuple_of, lbls, ps)

tuple_of(lbls::Vector{Symbol}, width::Int) = Pipeline(tuple_of, lbls, width)

tuple_of(width::Int) = tuple_of(Symbol[], width)

quoteof(::typeof(tuple_of), args::Vector{Any}) =
    if length(args) == 2 && args[1] isa Vector{Symbol} && args[2] isa Vector
        if isempty(args[1])
            Expr(:call, tuple_of, Any[quoteof(p) for p in args[2]]...)
        else
            Expr(:call, tuple_of, Any[quoteof(l => p) for (l, p) in zip(args[1], args[2])]...)
        end
    else
        Expr(:call, tuple_of, Any[quoteof(arg) for arg in args]...)
    end

function tuple_of(rt::Runtime, @nospecialize(input::AbstractVector), lbls::Vector{Symbol}, ps::Vector{Pipeline})
    len = length(input)
    cols = AbstractVector[p(rt, input) for p in ps]
    TupleVector(lbls, len, cols)
end

function tuple_of(rt::Runtime, @nospecialize(input::AbstractVector), lbls::Vector{Symbol}, width::Int)
    len = length(input)
    cols = AbstractVector[input for k in 1:width]
    TupleVector(lbls, len, cols)
end

"""
    column(lbl::Union{Int,Symbol}) :: Pipeline

This pipeline extracts the specified column of a tuple vector.
"""
column(lbl::Union{Int,Symbol}) = Pipeline(column, lbl)

function column(rt::Runtime, input::AbstractVector, lbl)
    @assert input isa TupleVector
    j = locate(input, lbl)
    column(input, j)
end

"""
    with_column(lbl::Union{Int,Symbol}, p::Pipeline) :: Pipeline

This pipeline transforms a tuple vector by applying `p` to the specified
column.
"""
with_column(lbl::Union{Int,Symbol}, p) = Pipeline(with_column, lbl, p)

function with_column(rt::Runtime, input::AbstractVector, lbl, p)
    @assert input isa TupleVector
    j = locate(input, lbl)
    cols′ = copy(columns(input))
    cols′[j] = p(rt, cols′[j])
    TupleVector(labels(input), length(input), cols′)
end


#
# Operations on block vectors.
#

"""
    wrap() :: Pipeline

This pipeline produces a block vector with one-element blocks wrapping the
values of the input vector.
"""
wrap() = Pipeline(wrap)

wrap(rt::Runtime, input::AbstractVector) =
    BlockVector(:, input, x1to1)


"""
    with_elements(p::Pipeline) :: Pipeline

This pipeline transforms a block vector by applying `p` to its vector of
elements.
"""
with_elements(p) = Pipeline(with_elements, p)

function with_elements(rt::Runtime, input::AbstractVector, p)
    @assert input isa BlockVector
    BlockVector(offsets(input), p(rt, elements(input)), cardinality(input))
end

"""
    flatten() :: Pipeline

This pipeline flattens a nested block vector.
"""
flatten() = Pipeline(flatten)

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
    distribute(lbl::Union{Int,Symbol}) :: Pipeline

This pipeline transforms a tuple vector with a column of blocks to a block
vector with tuple elements.
"""
distribute(lbl) = Pipeline(distribute, lbl)

function distribute(rt::Runtime, input::AbstractVector, lbl)
    @assert input isa TupleVector && column(input, lbl) isa BlockVector
    j = locate(input, lbl)
    _distribute(column(input, j), input, j)
end

function _distribute(col::BlockVector, tv::TupleVector, j)
    lbls = labels(tv)
    cols′ = copy(columns(tv))
    len = length(col)
    card = cardinality(col)
    offs = offsets(col)
    col′ = elements(col)
    if offs isa OneTo{Int}
        cols′[j] = col′
        return BlockVector{card}(offs, TupleVector(lbls, len, cols′))
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
    return BlockVector{card}(offs, TupleVector(lbls, len′, cols′))
end

"""
    distribute_all() :: Pipeline

This pipeline transforms a tuple vector with block columns to a block vector
with tuple elements.
"""
distribute_all() = Pipeline(distribute_all)

function distribute_all(rt::Runtime, input::AbstractVector)
    @assert input isa TupleVector && all(Bool[col isa BlockVector for col in columns(input)])
    cols = columns(input)
    _distribute_all(labels(input), length(input), cols...)
end

@generated function _distribute_all(lbls::Vector{Symbol}, len::Int, cols::BlockVector...)
    D = length(cols)
    CARD = x1to1
    for col in cols
        CARD |= cardinality(col)
    end
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
    block_cardinality(card::Cardinality, src_lbl, tgt_lbl) :: Pipeline

This pipeline asserts the cardinality of the input block vector.
"""
block_cardinality(card::Cardinality, src_lbl::Union{Symbol,Nothing}, tgt_lbl::Union{Symbol,Nothing}) =
    Pipeline(block_cardinality, card, src_lbl, tgt_lbl)

block_cardinality(card::Cardinality) =
    Pipeline(block_cardinality, card)

function block_cardinality(rt::Runtime, input::AbstractVector, card, src_lbl=nothing, tgt_lbl=nothing)
    @assert input isa BlockVector
    cardinality(input) != card || return input
    if !fits(cardinality(input), card) && !(offsets(input) isa OneTo)
        offs = offsets(input)
        @inbounds off = offs[1]
        for k = 2:lastindex(offs)
            @inbounds off′ = offs[k]
            !issingular(card) || off′ <= off+1 || _cardinality_error(src_lbl, tgt_lbl, "singular")
            !ismandatory(card) || off′ >= off+1 || _cardinality_error(src_lbl, tgt_lbl, "mandatory")
            off = off′
        end
    end
    card != x1to1 || return BlockVector(:, elements(input))
    @inbounds output = BlockVector(offsets(input), elements(input), card)
    return output
end

_cardinality_error(src_lbl, tgt_lbl, kind) =
    error(tgt_lbl !== nothing ? "\"$tgt_lbl\": " : "",
          "expected a $kind value",
          src_lbl !== nothing ? ", relative to \"$src_lbl\"" : "")

"""
    block_length() :: Pipeline

This pipeline converts a block vector to a vector of block lengths.
"""
block_length() = Pipeline(block_length)

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
    block_not_empty() :: Pipeline

This pipeline converts a block vector to a vector of Boolean values, where each
value indicates whether the corresponding block is empty or not.
"""
block_not_empty() = Pipeline(block_not_empty)

function block_not_empty(rt::Runtime, input::AbstractVector)
    @assert input isa BlockVector
    _block_not_empty(offsets(input))
end

_block_not_empty(offs::OneTo{Int}) =
    fill(true, length(offs)-1)

function _block_not_empty(offs::AbstractVector{Int})
    len = length(offs) - 1
    output = Vector{Bool}(undef, len)
    @inbounds for k = 1:len
        output[k] = offs[k+1] > offs[k]
    end
    output
end

"""
    block_any() :: Pipeline

This pipeline applies `any` to a block vector with `Bool` elements.
"""
block_any() = Pipeline(block_any)

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
    sieve_by() :: Pipeline

This pipeline filters a vector of pairs by the second column.  It expects a
pair vector, whose second column is a `Bool` vector, and produces a block
vector with 0- or 1-element blocks containing the elements of the first column.
"""
sieve_by() = Pipeline(sieve_by)

function sieve_by(rt::Runtime, input::AbstractVector)
    @assert input isa TupleVector && width(input) == 2 && eltype(column(input, 2)) <: Bool
    val_col, pred_col = columns(input)
    _sieve_by(val_col, pred_col)
end

function _sieve_by(@nospecialize(v), bv)
    len = length(bv)
    sz = count(bv)
    if sz == len
        return BlockVector(:, v, x0to1)
    elseif sz == 0
        return BlockVector(fill(1, len+1), v[[]], x0to1)
    end
    offs = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs[1] = top = 1
    for k = 1:len
        if bv[k]
            perm[top] = k
            top += 1
        end
        offs[k+1] = top
    end
    return BlockVector(offs, v[perm], x0to1)
end


#
# Extracting and slicing.
#

"""
    get_by(N::Int) :: Pipeline

This pipeline extracts the `N`-th element from the given block vector.
"""
get_by(N::Int) =
    Pipeline(get_by, N)

get_by(rt::Runtime, input::AbstractVector, N::Int) =
    get_by(rt, input, N, x0to1)

get_by(N::Int, card::Cardinality) =
    Pipeline(get_by, N, card)

function get_by(::Runtime, input::AbstractVector, N::Int, card::Cardinality)
    @assert input isa BlockVector
    len = length(input)
    offs = offsets(input)
    elts = elements(input)
    sz = 0
    R = 1
    for k = 1:len
        L = R
        @inbounds R = offs[k+1]
        sz += checkindex(Bool, L:R-1, _get_index(L, R-1, N))
    end
    if sz == len
        if N == 1
            elts′ = elts[view(offs, 1:len)]
            return BlockVector(:, elts′, card)
        end
        perm = Vector{Int}(undef, sz)
        R = 1
        for k = 1:len
            L = R
            @inbounds R = offs[k+1]
            @inbounds perm[k] = _get_index(L, R-1, N)
        end
        elts′ = elts[perm]
        return BlockVector(:, elts′, card)
    end
    offs′ = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs′[1] = top = 1
    R = 1
    for k = 1:len
        L = R
        @inbounds R = offs[k+1]
        i = _get_index(L, R-1, N)
        if checkindex(Bool, L:R-1, i)
            perm[top] = i
            top += 1
        end
        offs′[k+1] = top
    end
    elts′ = elts[perm]
    return BlockVector(offs′, elts′, card)
end

"""
    get_by() :: Pipeline

This pipeline takes a pair vector of blocks and integers, and returns the first
column indexed by the second column.
"""
get_by() =
    Pipeline(get_by)

function get_by(::Runtime, input::AbstractVector)
    @assert input isa TupleVector
    cols = columns(input)
    @assert length(cols) == 2
    vals, Ns = cols
    @assert vals isa BlockVector
    @assert eltype(Ns) <: Int
    _get_by(elements(vals), offsets(vals), Ns)
end

function _get_by(@nospecialize(elts), offs, Ns)
    len = length(Ns)
    R = 1
    sz = 0
    for k = 1:len
        L = R
        @inbounds N = Ns[k]
        @inbounds R = offs[k+1]
        sz += checkindex(Bool, L:R-1, _get_index(L, R-1, N))
    end
    if sz == len
        perm = Vector{Int}(undef, sz)
        R = 1
        for k = 1:len
            L = R
            @inbounds N = Ns[k]
            @inbounds R = offs[k+1]
            @inbounds perm[k] = _get_index(L, R-1, N)
        end
        elts′ = elts[perm]
        return BlockVector(:, elts′, x0to1)
    end
    offs′ = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs′[1] = top = 1
    R = 1
    for k = 1:len
        L = R
        @inbounds N = Ns[k]
        @inbounds R = offs[k+1]
        i = _get_index(L, R-1, N)
        if checkindex(Bool, L:R-1, i)
            perm[top] = i
            top += 1
        end
        offs′[k+1] = top
    end
    elts′ = elts[perm]
    return BlockVector(offs′, elts′, x0to1)
end

@inline _get_index(l, r, n) =
    n >= 0 ? l + n - 1 : r + n + 1

"""
    slice_by(N::Int, inv::Bool=false) :: Pipeline

This pipeline transforms a block vector by keeping the first `N` elements of
each block.  If `inv` is true, the pipeline drops the first `N` elements of
each block.
"""
slice_by(N::Union{Int,Missing}, inv::Bool=false) =
    Pipeline(slice_by, N, inv)

slice_by(N::Union{Int,Missing}, card::Cardinality, inv::Bool=false) =
    Pipeline(splice_by, N, card, inv)

slice_by(rt::Runtime, input::AbstractVector, N::Union{Int,Missing}, inv::Bool) =
    slice_by(rt, input, N, cardinality(input)|x0to1, inv)

function slice_by(rt::Runtime, input::AbstractVector, ::Missing, card::Cardinality, inv::Bool)
    @assert input isa BlockVector
    offs′ = !inv ? offsets(input) : fill(1, length(input)+1)
    elts′ = !inv ? elements(input) : elements(input)[Int[]]
    return BlockVector(offs′, elts′, card)
end

function slice_by(rt::Runtime, input::AbstractVector, N::Int, card::Cardinality, inv::Bool)
    @assert input isa BlockVector
    len = length(input)
    offs = offsets(input)
    elts = elements(input)
    sz = 0
    R = 1
    for k = 1:len
        L = R
        @inbounds R = offs[k+1]
        (l, r) = _slice_range(N, R-L, inv)
        sz += r - l + 1
    end
    if sz == length(elts)
        return BlockVector(offs, elts, card)
    end
    offs′ = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs′[1] = top = 1
    R = 1
    for k = 1:len
        L = R
        @inbounds R = offs[k+1]
        (l, r) = _slice_range(N, R-L, inv)
        for j = (L + l - 1):(L + r - 1)
            perm[top] = j
            top += 1
        end
        offs′[k+1] = top
    end
    elts′ = elts[perm]
    return BlockVector(offs′, elts′, card)
end

"""
    slice_by(inv::Bool=false) :: Pipeline

This pipeline takes a pair vector of blocks and integers, and returns the first
column sliced by the second column.
"""
slice_by(inv::Bool=false) =
    Pipeline(slice_by, inv)

function slice_by(rt::Runtime, input::AbstractVector, inv::Bool)
    @assert input isa TupleVector
    cols = columns(input)
    @assert length(cols) == 2
    vals, Ns = cols
    @assert vals isa BlockVector
    @assert eltype(Ns) <: Union{Missing,Int}
    _slice_by(elements(vals), offsets(vals), cardinality(vals), Ns, inv)
end

function _slice_by(@nospecialize(elts), offs, card, Ns, inv)
    card′ = card|x0to1
    len = length(Ns)
    R = 1
    sz = 0
    for k = 1:len
        L = R
        @inbounds N = Ns[k]
        @inbounds R = offs[k+1]
        (l, r) = _slice_range(N, R-L, inv)
        sz += r - l + 1
    end
    if sz == length(elts)
        return BlockVector(offs, elts, card′)
    end
    offs′ = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs′[1] = top = 1
    R = 1
    for k = 1:len
        L = R
        @inbounds N = Ns[k]
        @inbounds R = offs[k+1]
        (l, r) = _slice_range(N, R-L, inv)
        for j = (L + l - 1):(L + r - 1)
            perm[top] = j
            top += 1
        end
        offs′[k+1] = top
    end
    elts′ = elts[perm]
    return BlockVector(offs′, elts′, card′)
end

@inline _slice_range(n::Int, l::Int, inv::Bool) =
    if !inv
        (1, n >= 0 ? min(l, n) : max(0, l + n))
    else
        (n >= 0 ? min(l + 1, n + 1) : max(1, l + n + 1), l)
    end

@inline _slice_range(::Missing, l::Int, inv::Bool) =
    !inv ? (1, l) : (1, 0)


#
# Ordering extensions.
#

struct LexOrdering{O<:Base.Ordering} <: Base.Ordering
    order::O
end

Base.@propagate_inbounds function Base.lt(o::LexOrdering, a, b)
    b > zero(b) && (a == zero(a) || Base.lt(o.order, a, b))
end

Base.ordtype(o::LexOrdering, vs::AbstractArray) = ordtype(o.order, vs)

ord_eq(o::Base.ForwardOrdering, a, b) = isequal(a, b)
ord_eq(o::Base.ReverseOrdering, a, b) = ord_eq(o.fwd, b, a)
ord_eq(o::Base.By, a, b) = isequal(o.by(a), o.by(b))
ord_eq(o::Base.Lt, a, b) = !o.lt(a, b) && !o.lt(b, a)
Base.@propagate_inbounds ord_eq(o::Base.Perm, a, b) =
    ord_eq(o.order, o.data[a], o.data[b])   # intentionally does not match `lt(::Perm)`
Base.@propagate_inbounds ord_eq(o::LexOrdering, a, b) =
    isequal(a, b) || (a > zero(a) && b > zero(b) && ord_eq(o.order, a, b))

#
# Grouping.
#

unique_by() = Pipeline(unique_by)

function unique_by(::Runtime, input::AbstractVector)
    @assert input isa BlockVector
    card = cardinality(input)
    offs = offsets(input)
    elts = elements(input)
    len = length(elts)
    perm = collect(1:len)
    sep = falses(len+1)
    for off in offs
        sep[off] = true
    end
    if len > 1
        _group_by!(elts, sep, perm, OneTo(len))
    end
    offs_outer, offs_inner = _partition(offs, sep)
    elts′ = elts[perm[view(offs_inner, 1:length(offs_inner)-1)]]
    BlockVector{card}(offs_outer, elts′)
end

sort_by() = Pipeline(sort_by)

function sort_by(::Runtime, input::AbstractVector)
    @assert input isa BlockVector
    card = cardinality(input)
    offs = offsets(input)
    elts = elements(input)
    @assert elts isa TupleVector
    cols = columns(elts)
    @assert length(cols) == 2
    vals, keys = cols
    len = length(elts)
    perm = collect(1:len)
    sep = falses(len+1)
    for off in offs
        sep[off] = true
    end
    if len > 1
        _group_by!(keys, sep, perm, OneTo(len))
    end
    output = BlockVector{card}(offs, vals[perm])
    output
end

group_by() = Pipeline(group_by)

function group_by(::Runtime, input::AbstractVector)
    @assert input isa BlockVector
    card = cardinality(input)
    offs = offsets(input)
    elts = elements(input)
    @assert elts isa TupleVector
    cols = columns(elts)
    @assert length(cols) == 2
    vals, keys = cols
    len = length(elts)
    perm = collect(1:len)
    sep = falses(len+1)
    for off in offs
        sep[off] = true
    end
    if len > 1
        _group_by!(keys, sep, perm, OneTo(len))
    end
    offs_outer, offs_inner = _partition(offs, sep)
    card′ = card & x1toN
    vals′ = BlockVector{card′}(offs_inner, vals[perm])
    sz = length(vals′)
    keys′ = keys[perm[view(offs_inner, 1:sz)]]
    output = BlockVector{card}(offs_outer, TupleVector(sz, AbstractVector[vals′, keys′]))
    output
end

function _group_by!(keys::TupleVector, sep, perm, idxs)
    for col in columns(keys)
        _group_by!(col, sep, perm, idxs)
    end
end

_group_by!(keys::BlockVector{CARD,OneTo{Int}}, sep, perm, idxs) where {CARD} =
    _group_by!(elements(keys), sep, perm, idxs)

function _group_by!(keys::BlockVector{CARD}, sep, perm, idxs) where {CARD}
    if CARD == x1to1
        return _group_by!(elements(keys), sep, perm, idxs)
    end
    offs = offsets(keys)
    elts = elements(keys)
    pos = 0
    idxs′ = Vector{Int}(undef, length(perm))
    done = false
    while !done
        for k = 1:length(perm)
            idx = idxs[k]
            if idx > 0
                l = offs[idx]
                r = offs[idx+1]
                if l + pos < r
                    idxs′[k] = l + pos
                else
                    idxs′[k] = 0
                end
            else
                idxs′[k] = 0
            end
        end
        done = true
        p = idxs′[perm[1]]
        for k = 2:length(perm)
            q = idxs′[perm[k]]
            if !sep[k] && p != q
                done = false
                break
            end
            p = q
        end
        if !done
            _group_by!(elts, sep, perm, idxs′)
        end
        if CARD == x0to1
            done = true
        end
        pos += 1
    end
end

_group_order(keys, ::OneTo) =
    Base.Perm(Base.Forward, keys)

_group_order(keys, idxs) =
    Base.Perm(LexOrdering(Base.Perm(Base.Forward, keys)), idxs)

function _group_by!(keys, sep, perm, idxs)
    o = _group_order(keys, idxs)
    _group_by!(o, sep, perm)
end

function _group_by!(o::Base.Perm, sep, perm)
    l = 1
    for r = 2:length(sep)
        if sep[r]
            if l < r-1
                sort!(perm, l, r-1, QuickSort, o)
            end
            da = o.data[perm[l]]
            for n = l+1:r-1
                db = o.data[perm[n]]
                if !ord_eq(o.order, da, db)
                    sep[n] = true
                end
                da = db
            end
            l = r
        end
    end
end

function _partition(offs, sep)
    sz = 0
    l = 1
    for k = 1:length(offs)-1
        r = offs[k+1]
        for n = l+1:r
            sz += sep[n]
        end
        l = r
    end
    offs_inner = Vector{Int}(undef, sz+1)
    offs_inner[1] = 1
    offs_outer = Vector{Int}(undef, length(offs))
    offs_outer[1] = top = 1
    l = 1
    for k = 1:length(offs)-1
        r = offs[k+1]
        for n = l+1:r
            if sep[n]
                top += 1
                offs_inner[top] = n
            end
        end
        offs_outer[k+1] = top
        l = r
    end
    return (offs_outer, offs_inner)
end


#
# Pipeline matching.
#

macro match_pipeline(ex)
    return esc(_match_pipeline(ex))
end

function _match_pipeline(@nospecialize ex)
    if Meta.isexpr(ex, :call, 3) && ex.args[1] == :~
        val = gensym()
        p = ex.args[2]
        pat = ex.args[3]
        cs = Expr[]
        as = Expr[]
        _match_pipeline!(val, pat, cs, as)
        c = foldl((l, r) -> :($l && $r), cs)
        quote
            local $val = $p
            if $c
                $(as...)
                true
            else
                false
            end
        end
    elseif ex isa Expr
        Expr(ex.head, Any[_match_pipeline(arg) for arg in ex.args]...)
    else
        ex
    end
end

function _match_pipeline!(val, pat, cs, as)
    if pat === :_
        return
    elseif pat isa Symbol
        push!(as, :(local $pat = $val))
        return
    elseif Meta.isexpr(pat, :(::), 2)
        ty = pat.args[2]
        pat = pat.args[1]
        push!(cs, :($val isa $ty))
        _match_pipeline!(val, pat, cs, as)
        return
    elseif Meta.isexpr(pat, :call) && length(pat.args) >= 1 && pat.args[1] isa Symbol
        fn = pat.args[1]
        args = pat.args[2:end]
        push!(cs, :($val isa $DataKnots.Pipeline))
        push!(cs, :($val.op === $DataKnots.$fn))
        _match_pipeline!(:($val.args), args, cs, as)
        return
    elseif Meta.isexpr(pat, :vect)
        push!(cs, :($val isa Vector{$DataKnots.Pipeline}))
        _match_pipeline!(val, pat.args, cs, as)
        return
    end
    error("expected a pipeline pattern; got $(repr(pat))")
end

function _match_pipeline!(val, pats::Vector{Any}, cs, as)
    minlen = 0
    varlen = false
    for pat in pats
        if Meta.isexpr(pat, :..., 1)
            !varlen || error("duplicate vararg pattern in $(repr(:([$pat])))")
            varlen = true
        else
            minlen += 1
        end
    end
    push!(cs, !varlen ? :(length($val) == $minlen) : :(length($val) >= $minlen))
    nearend = false
    for (k, pat) in enumerate(pats)
        if Meta.isexpr(pat, :..., 1)
            pat = pat.args[1]
            k = Expr(:call, :(:), k, Expr(:call, :-, :end, minlen-k+1))
            nearend = true
        elseif nearend
            k = Expr(:call, :-, :end, minlen-k+1)
        end
        _match_pipeline!(:($val[$k]), pat, cs, as)
    end
end

