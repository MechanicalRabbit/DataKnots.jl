#
# Custom vector types for representing data in columnar form.
#

using Tables

import Base:
    IndexStyle,
    OneTo,
    convert,
    eltype,
    getindex,
    iterate,
    show,
    size,
    summary,
    &, |, ~


#
# Vector of tuples in columnar form.
#

# Constructors.

"""
    TupleVector([lbls::Vector{Symbol},] len::Int, cols::Vector{AbstractVector})
    TupleVector([lbls::Vector{Symbol},] idxs::AbstractVector{Int}, cols::Vector{AbstractVector})
    TupleVector(lcols::Pair{<:Union{Symbol,AbstractString},<:AbstractVector}...)

Vector of tuples stored as a collection of column vectors.

- `cols` is a vector of columns; optional `lbls` is a vector of column labels.
  Alternatively, labels and columns could be provided as a list of pairs
  `lcols`.
- `len` is the vector length, which must coincide with the length of all the
  columns.  Alternatively, the vector could be constructed from a subset of the
  column data using a vector of indexes `idxs`.
"""
struct TupleVector{I<:AbstractVector{Int}} <: AbstractVector{Any}
    lbls::Vector{Symbol}            # isempty(lbls) means plain tuples
    idxs::I
    cols::Vector{AbstractVector}
    icols::Vector{AbstractVector}   # [col[idxs] for col in cols]

    @inline function TupleVector{I}(lbls::Vector{Symbol}, idxs::I, cols::Vector{AbstractVector}) where {I<:AbstractVector{Int}}
        @boundscheck _checktuple(lbls, idxs, cols)
        icols = Vector{AbstractVector}(undef, length(cols))
        new{I}(lbls, idxs, cols, icols)
    end

    @inline function TupleVector{I}(lbls::Vector{Symbol}, len::Int, cols::Vector{AbstractVector}) where {I<:OneTo{Int}}
        @boundscheck _checktuple(lbls, len, cols)
        idxs = OneTo(len)
        new{I}(lbls, idxs, cols, cols)
    end
end

@inline TupleVector(lbls::Vector{Symbol}, idxs::I, cols::Vector{AbstractVector}) where {I<:AbstractVector{Int}} =
    TupleVector{I}(lbls, idxs, cols)

@inline TupleVector(lbls::Vector{Symbol}, len::Int, cols::Vector{AbstractVector}) =
    TupleVector{OneTo{Int}}(lbls, len, cols)

@inline TupleVector(idxs::AbstractVector{Int}, cols::Vector{AbstractVector}) =
    TupleVector(Symbol[], idxs, cols)

@inline TupleVector(len::Int, cols::Vector{AbstractVector}) =
    TupleVector(Symbol[], len, cols)

@inline TupleVector(len::Int) =
    TupleVector(Symbol[], len, AbstractVector[])

function TupleVector(lcol1::Pair{<:Union{Symbol,AbstractString},<:AbstractVector},
                     more::Pair{<:Union{Symbol,AbstractString},<:AbstractVector}...)
    len = length(lcol1.second)
    lcols = (lcol1, more...)
    lbls = collect(Symbol, Symbol.(first.(lcols)))
    cols = collect(AbstractVector, last.(lcols))
    TupleVector(lbls, len, cols)
end

function _checklabels(lbls::Vector{Symbol}, width::Int)
    if !isempty(lbls)
        length(lbls) == width || error("number of labels ≠ number of columns")
        seen = Set{Symbol}()
        for lbl in lbls
            !(lbl in seen) || error("duplicate column label $(repr(lbl))")
            push!(seen, lbl)
        end
    end
end

function _checktuple(lbls::Vector{Symbol}, idxs::AbstractVector{Int}, cols::Vector{AbstractVector})
    _checklabels(lbls, length(cols))
    if !isempty(idxs)
        m = maximum(idxs)
        for col in cols
            length(col) >= m || error("insufficient column height")
        end
    end
end

function _checktuple(lbls::Vector{Symbol}, len::Int, cols::Vector{AbstractVector})
    _checklabels(lbls, length(cols))
    for col in cols
        length(col) == len || error("unexpected column height")
    end
end

# Printing.

show(io::IO, tv::TupleVector) =
    show_vectortree(io, tv)

show(io::IO, ::MIME"text/plain", tv::TupleVector) =
    display_vectortree(io, tv)

# Properties.

@inline labels(tv::TupleVector) = tv.lbls

@inline width(tv::TupleVector) = length(tv.cols)

function columns(tv::TupleVector)
    for j = 1:length(tv.cols)
        if !isassigned(tv.icols, j)
            @inbounds tv.icols[j] = tv.cols[j][tv.idxs]
        end
    end
    tv.icols
end

function column(tv::TupleVector, j::Int)
    if !isassigned(tv.icols, j)
        @inbounds tv.icols[j] = tv.cols[j][tv.idxs]
    end
    tv.icols[j]
end

@inline column(tv::TupleVector, lbl::Symbol) =
    column(tv, findfirst(isequal(lbl), tv.lbls))

@inline locate(tv::TupleVector, j::Int) =
    1 <= j <= length(tv.cols) ? j : nothing

@inline locate(tv::TupleVector, lbl::Symbol) =
    findfirst(isequal(lbl), tv.lbls)

# Vector interface.

@inline size(tv::TupleVector) = size(tv.idxs)

IndexStyle(::Type{<:TupleVector}) = IndexLinear()

eltype(tv::TupleVector) =
    if !isempty(tv.lbls)
        NamedTuple{(tv.lbls...,),Tuple{eltype.(tv.cols)...}}
    else
        Tuple{eltype.(tv.cols)...}
    end

@inline function getindex(tv::TupleVector, k::Int)
    @boundscheck checkbounds(tv, k)
    @inbounds k′ = tv.idxs[k]
    @inbounds t = getindex.((tv.cols...,), k′)
    if !isempty(tv.lbls)
        NamedTuple{(tv.lbls...,)}(t)
    else
        t
    end
end

# Tables.jl export interface.

Tables.istable(tv::TupleVector) = !isempty(tv.lbls)

Tables.columnaccess(::TupleVector) = true

Tables.columns(tv::TupleVector) =
    NamedTuple{(labels(tv)...,)}(collect.(columns(tv)))

"""
    (::TupleVector)[ks::AbstractVector{Int}] :: TupleVector

Returns a new `TupleVector` with a subset of rows specified by indexes `ks`.
"""
@inline function getindex(tv::TupleVector, ks::AbstractVector)
    @boundscheck checkbounds(tv, ks)
    @inbounds idxs′ = tv.idxs[ks]
    @inbounds tv′ = TupleVector(tv.lbls, idxs′, tv.cols)
    tv′
end


#
# Cardinality of a data block.
#

"""
    x1to1::Cardinality
    x0to1::Cardinality
    x1toN::Cardinality
    x0toN::Cardinality

Cardinality constraints on a block of data.
"""
Cardinality

@enum Cardinality::UInt8 x1to1 x0to1 x1toN x0toN

convert(::Type{Cardinality}, c::Symbol) =
    c == :x1to1 ? x1to1 : c == :x0to1 ? x0to1 : c == :x1toN ? x1toN : c ==:x0toN ? x0toN :
    error("invalid cardinality literal: $c")

quoteof(c::Cardinality) =
    c == x1to1 ? :x1to1 : c == x0to1 ? :x0to1 : c == x1toN ? :x1toN : :x0toN

syntaxof(c::Cardinality) =
    c == x1to1 ? :(1:1) : c == x0to1 ? :(0:1) : c == x1toN ? :(1:N) : :(0:N)

# Bitwise operations.

(~)(c::Cardinality) =
    Base.bitcast(Cardinality, (~UInt8(c))&UInt8(x0toN))

(|)(c1::Cardinality, c2::Cardinality) =
    Base.bitcast(Cardinality, UInt8(c1)|UInt8(c2))

(&)(c1::Cardinality, c2::Cardinality) =
    Base.bitcast(Cardinality, UInt8(c1)&UInt8(c2))

# Predicates.

ismandatory(c::Cardinality) =
    c & x0to1 != x0to1

issingular(c::Cardinality) =
    c & x1toN != x1toN


#
# Vector of data blocks in a columnar form.
#

# Constructors.

"""
    BlockVector(offs::AbstractVector{Int}, elts::AbstractVector, card::Cardinality=x0toN)
    BlockVector(:, elts::AbstractVector, card::Cardinality=x1to1)

Vector of data blocks stored as a vector of elements partitioned by a
vector of offsets.

- `elts` is a continuous vector of block elements.
- `offs` is a vector of indexes that subdivide `elts` into separate blocks.
  Should be monotonous with `offs[1] == 1` and `offs[end] == length(elts)+1`.
  Use `:` if the offset vector is a unit range.
- `card` is the cardinality constraint on the blocks.
"""
struct BlockVector{CARD,O<:AbstractVector{Int},E<:AbstractVector} <: AbstractVector{Any}
    offs::O
    elts::E

    @inline function BlockVector{CARD,O,E}(offs::O, elts::E) where {CARD,O<:AbstractVector{Int},E<:AbstractVector}
        @boundscheck _checkblock(length(elts), offs, CARD)
        new{CARD,O,E}(offs, elts)
    end
end

@inline BlockVector{CARD}(offs::O, elts::E) where {CARD,O<:AbstractVector{Int},E<:AbstractVector} =
    BlockVector{CARD,O,E}(offs, elts)

@inline BlockVector{CARD}(::Colon, elts::AbstractVector) where {CARD} =
    BlockVector{CARD}(OneTo{Int}(length(elts)+1), elts)

@inline BlockVector(offs::AbstractVector{Int}, elts::AbstractVector, card::Cardinality=x1toN|x0to1) =
    BlockVector{card}(offs, elts)

@inline BlockVector(::Colon, elts::AbstractVector, card::Cardinality=x1to1) =
    BlockVector{card}(:, elts)

function _checkblock(len::Int, offs::OneTo{Int}, ::Cardinality)
    !isempty(offs) || error("offsets must be non-empty")
    offs[end] == len+1 || error("offsets must enclose the elements")
end

function _checkblock(len::Int, offs::AbstractVector{Int}, card::Cardinality)
    !isempty(offs) || error("offsets must be non-empty")
    @inbounds off = offs[1]
    off == 1 || error("offsets must start with 1")
    for k = 2:lastindex(offs)
        @inbounds off′ = offs[k]
        off′ >= off || error("offsets must be monotone")
        !issingular(card) || off′ <= off+1 || error("singular blocks must have at most one element")
        !ismandatory(card) || off′ >= off+1 || error("mandatory blocks must have at least one element")
        off = off′
    end
    off == len+1 || error("offsets must enclose the elements")
end

# Printing.

show(io::IO, bv::BlockVector) =
    show_vectortree(io, bv)

show(io::IO, ::MIME"text/plain", bv::BlockVector) =
    display_vectortree(io, bv)

# Properties.

@inline offsets(bv::BlockVector) = bv.offs

@inline elements(bv::BlockVector) = bv.elts

@inline cardinality(bv::BlockVector{CARD}) where {CARD} = CARD

@inline cardinality(::Type{<:BlockVector{CARD}}) where {CARD} = CARD

# Vector interface.

@inline size(bv::BlockVector) = (length(bv.offs)-1,)

IndexStyle(::Type{<:BlockVector}) = IndexLinear()

eltype(bv::BlockVector) =
    Vector{eltype(bv.elts)}

eltype(bv::BlockVector{x0to1}) =
    Union{eltype(bv.elts),Missing}

eltype(bv::BlockVector{x1to1}) =
    eltype(bv.elts)

@inline function getindex(bv::BlockVector, k::Int)
    @boundscheck checkbounds(bv, k)
    @inbounds rng = bv.offs[k]:bv.offs[k+1]-1
    @inbounds elt = bv.elts[rng]
    elt
end

@inline function getindex(bv::BlockVector{x0to1}, k::Int)
    @boundscheck checkbounds(bv, k)
    @inbounds rng = bv.offs[k]:bv.offs[k+1]-1
    @inbounds elt = !isempty(rng) ? bv.elts[rng.start] : missing
    elt
end

@inline function getindex(bv::BlockVector{x1to1}, k::Int)
    @boundscheck checkbounds(bv, k)
    @inbounds elt = bv.elts[k]
    elt
end

"""
    (::BlockVector)[ks::AbstractVector{Int}] :: BlockVector

Returns a new `BlockVector` with a selection of blocks specified by indexes
`ks`.
"""
@inline function getindex(bv::BlockVector, ks::AbstractVector)
    @boundscheck checkbounds(bv, ks)
    _getindex(bv, ks)
end

function _getindex(bv::BlockVector{CARD}, ks::AbstractVector) where {CARD}
    offs′ = Vector{Int}(undef, length(ks)+1)
    @inbounds offs′[1] = top = 1
    i = 1
    @inbounds for k in ks
        l = bv.offs[k]
        r = bv.offs[k+1]
        offs′[i+1] = top = top + r - l
        i += 1
    end
    perm = Vector{Int}(undef, top-1)
    j = 1
    @inbounds for k in ks
        l = bv.offs[k]
        r = bv.offs[k+1]
        copyto!(perm, j, l:r-1)
        j += r - l
    end
    @inbounds elts′ = bv.elts[perm]
    @inbounds bv′ = BlockVector{CARD}(offs′, elts′)
    bv′
end

function _getindex(bv::BlockVector{CARD,OneTo{Int}}, ks::AbstractVector) where {CARD}
    offs′ = OneTo(length(ks)+1)
    @inbounds elts′ = bv.elts[ks]
    @inbounds bv′ = BlockVector{CARD}(offs′, elts′)
    bv′
end

function _getindex(bv::BlockVector{CARD}, ks::OneTo) where {CARD}
    len = length(ks)
    if len == length(bv.offs)-1
        return bv
    end
    @inbounds offs′ = bv.offs[OneTo(len+1)]
    @inbounds top = bv.offs[len+1]
    @inbounds elts′ = bv.elts[OneTo(top-1)]
    @inbounds bv′ = BlockVector{CARD}(offs′, elts′)
    bv′
end

function _getindex(bv::BlockVector{CARD,OneTo{Int}}, ks::OneTo) where {CARD}
    len = length(ks)
    if len == length(bv.offs)-1
        return bv
    end
    offs′ = OneTo(len+1)
    @inbounds elts′ = bv.elts[ks]
    @inbounds bv′ = BlockVector{CARD}(offs′, elts′)
    bv′
end

# Allocation-free view.

mutable struct BlockCursor{T,O<:AbstractVector{Int},E<:AbstractVector{T}} <: AbstractVector{T}
    pos::Int
    l::Int
    r::Int
    offs::O
    elts::E

    @inline BlockCursor{T,O,V}(bv::BlockVector) where {T,O<:AbstractVector{Int},V<:AbstractVector{T}} =
        new{T,O,V}(0, 1, 1, bv.offs, bv.elts)

    @inline function BlockCursor{T,O,V}(pos, bv::BlockVector) where {T,O<:AbstractVector{Int},V<:AbstractVector{T}}
        @boundscheck checkbounds(bv.offs, pos:pos+1)
        @inbounds cr = new{T,O,V}(pos, bv.offs[pos], bv.offs[pos+1], bv.offs, bv.elts)
        cr
    end
end

BlockCursor(bv::BlockVector{CARD,O,E}) where {CARD,T,O<:AbstractVector{Int},E<:AbstractVector{T}} =
    BlockCursor{T,O,E}(bv)

BlockCursor(pos, l, r, bv::BlockVector{CARD,O,E}) where {CARD,T,O<:AbstractVector{Int},E<:AbstractVector{T}} =
    BlockCursor{T,V}(pos, l, r, bv)

# Cursor interface for block vector.

@inline cursor(bv::BlockVector) =
    BlockCursor(bv)

@inline function cursor(bv::BlockVector, pos::Int)
    BlockCursor(pos, bv)
end

@inline function iterate(cr::BlockCursor, ::Nothing=nothing)
    cr.pos += 1
    cr.l = cr.r
    cr.pos < length(cr.offs) || return nothing
    @inbounds cr.r = cr.offs[cr.pos+1]
    (cr, nothing)
end

# Vector interface for cursor.

@inline size(cr::BlockCursor) = (cr.r - cr.l,)

IndexStyle(::Type{<:BlockCursor}) = IndexLinear()

@inline function getindex(cr::BlockCursor, k::Int)
    @boundscheck checkbounds(cr, k)
    @inbounds elt = cr.elts[cr.l + k - 1]
    elt
end

@inline function setindex!(cr::BlockCursor, elt, k::Int)
    @boundscheck checkbounds(cr, k)
    @inbounds cr.elts[cr.l + k - 1] = elt
    cr
end

#
# Printing columnar vectors.
#

summary(io::IO, v::Union{TupleVector,BlockVector}) =
    pprint(io, summary_layout(v))

summary_layout(v::AbstractVector) =
    pair_layout(literal("@VectorTree"),
                tile_expr(Expr(:call, :×, length(v), syntaxof(shapeof(v)))),
                sep=" of ")

Base.typeinfo_prefix(io::IO, cv::Union{TupleVector,BlockVector}) =
    if get(io, :typeinfo, nothing) === nothing
        "@VectorTree $(syntaxof(shapeof(cv))) "
    else
        ""
    end

show_vectortree(io::IO, v::AbstractVector) =
    Base.show_vector(io, v)

function display_vectortree(io::IO, v::AbstractVector)
    summary(io, v)
    !isempty(v) || return
    println(io, ":")
    io = IOContext(io, :typeinfo => eltype(v), :compact => true)
    Base.print_array(io, v)
end


#
# @VectorTree constructor.
#

"""
    @VectorTree sig vec

Constructs a tree of columnar vectors from a plain vector literal.

The first parameter, `sig`, describes the tree structure.  It is defined
recursively:

- Julia type `T` indicates a regular vector of type `T`.
- Tuple `(col₁, col₂, ...)` indicates a `TupleVector` instance.
- Named tuple `(lbl₁ = col₁, lbl₂ = col₂, ...)` indicates a `TupleVector`
  instance with the given labels.
- Prefixes `(0:N)`, `(1:N)`, `(0:1)`, `(1:1)` indicate a `BlockVector` instance
  with the respective cardinality constraints (no constraints, mandatory,
  singular, mandatory+singular).

The second parameter, `vec`, is a vector literal in row-oriented format:

- `TupleVector` data is specified either by a matrix or by a vector of (regular
  or named) tuples.
- `BlockVector` data is specified by a vector of vectors.  A one-element block
  could be represented by its element; an empty block by `missing` literal.
"""
macro VectorTree(sig, vec)
    mk = sig2mk(sig)
    ex = vectorize(mk, vec)
    return esc(ex)
end

const CARD_MAP = Dict(:(0:N) => x0toN,
                      :(0:n) => x0toN,
                      :(1:N) => x1toN,
                      :(1:n) => x1toN,
                      :(0:1) => x0to1,
                      :(1:1) => x1to1)

function sig2mk(sig)
    if Meta.isexpr(sig, :tuple)
        lbls = Symbol[]
        col_mks = MakeAbstractVector[]
        for arg in sig.args
            if Meta.isexpr(arg, (:(=), :kw), 2) && arg.args[1] isa Union{Symbol,String}
                push!(lbls, Symbol(arg.args[1]))
                push!(col_mks, sig2mk(arg.args[2]))
            else
                push!(col_mks, sig2mk(arg))
            end
        end
        return MakeTupleVector(lbls, col_mks)
    elseif Meta.isexpr(sig, :vect, 1)
        elts_mk = sig2mk(sig.args[1])
        return MakeBlockVector(elts_mk, x0toN)
    elseif Meta.isexpr(sig, :call, 3) &&
           sig.args[1] in (:×, :*) && sig.args[2] in keys(CARD_MAP)
        elts_mk = sig2mk(sig.args[3])
        card = CARD_MAP[sig.args[2]]
        return MakeBlockVector(elts_mk, card)
    elseif Meta.isexpr(sig, :call) && length(sig.args) >= 1 && sig.args[1] in keys(CARD_MAP)
        elts_mk = sig2mk(Expr(:tuple, sig.args[2:end]...))
        card = CARD_MAP[sig.args[1]]
        return MakeBlockVector(elts_mk, card)
    else
        ty = sig == :Bottom ? :(Union{}) : sig
        return MakeVector(ty)
    end
end

abstract type MakeAbstractVector end

mutable struct MakeTupleVector <: MakeAbstractVector
    lbls::Vector{Symbol}
    col_mks::Vector{MakeAbstractVector}
    len::Int

    MakeTupleVector(lbls, col_mks) = new(lbls, col_mks, 0)
end

mutable struct MakeBlockVector <: MakeAbstractVector
    elts_mk::MakeAbstractVector
    offs::Vector{Int}
    card::Cardinality
    top::Int

    MakeBlockVector(elts_mk, card) = new(elts_mk, [1], card, 1)
end

mutable struct MakeVector <: MakeAbstractVector
    ty::Any
    vals::Vector{Any}

    MakeVector(ty) = new(ty, [])
end

function vectorize(mk::MakeAbstractVector, ex)
    if Meta.isexpr(ex, (:vect, :vcat))
        for arg in ex.args
            _rearrange!(mk, arg)
        end
        return _reconstruct(mk)
    else
        error("expected a vector literal; got $(repr(ex))")
    end
end

function _rearrange!(mk::MakeTupleVector, ex)
    if Meta.isexpr(ex, (:tuple, :row))
        if length(ex.args) == length(mk.col_mks)
            for (j, (arg, col_mk)) in enumerate(zip(ex.args, mk.col_mks))
                if Meta.isexpr(arg, :(=), 2)
                    if j <= length(mk.lbls) && arg.args[1] == mk.lbls[j]
                        arg = arg.args[2]
                    elseif j < length(mk.lbls)
                        error("expected label $(repr(mk.lbls[j])); got $(repr(arg))")
                    else
                        error("expected no label; got $(repr(arg))")
                    end
                end
                _rearrange!(col_mk, arg)
            end
        else
            error("expected $(length(mk.col_mks)) column(s); got $(repr(ex))")
        end
        mk.len += 1
    elseif length(mk.col_mks) == 1
        _rearrange!(mk.col_mks[1], ex)
        mk.len += 1
    else
        error("expected a tuple or a row literal; got $(repr(ex))")
    end
end

function _rearrange!(mk::MakeBlockVector, ex)
    if Meta.isexpr(ex, (:vect, :vcat))
        for arg in ex.args
            _rearrange!(mk.elts_mk, arg)
            mk.top += 1
        end
    elseif ex !== :missing
        _rearrange!(mk.elts_mk, ex)
        mk.top += 1
    end
    push!(mk.offs, mk.top)
end

function _rearrange!(mk::MakeVector, ex)
    push!(mk.vals, ex)
end

_reconstruct(mk::MakeTupleVector) =
    Expr(:call, TupleVector,
                mk.lbls,
                mk.len,
                Expr(:ref, AbstractVector, _reconstruct.(mk.col_mks)...))

_reconstruct(mk::MakeBlockVector) =
    Expr(:call, Expr(:curly, BlockVector, mk.card),
                mk.offs == (1:length(mk.offs)) ? :(:) : mk.offs,
                _reconstruct(mk.elts_mk))

_reconstruct(mk::MakeVector) =
    Expr(:ref, :(try $(mk.ty)::Type catch; error("expected a type; got $($(repr(mk.ty)))") end), mk.vals...)

