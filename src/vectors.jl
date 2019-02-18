#
# Custom vector types for representing data in columnar form.
#

import Base:
    IndexStyle,
    OneTo,
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
    TupleVector(lcols::Pair{<:Union{Symbol,String},<:AbstractVector}...)

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

let NO_LBLS = Symbol[]

    global TupleVector

    @inline TupleVector(idxs::AbstractVector{Int}, cols::Vector{AbstractVector}) =
        TupleVector(NO_LBLS, idxs, cols)

    @inline TupleVector(len::Int, cols::Vector{AbstractVector}) =
        TupleVector(NO_LBLS, len, cols)

    @inline TupleVector(len::Int) =
        TupleVector(NO_LBLS, len, AbstractVector[])
end

function TupleVector(lcol1::Pair{<:Union{Symbol,String},<:AbstractVector}, more::Pair{<:Union{Symbol,String},<:AbstractVector}...)
    len = length(lcol1.second)
    lcols = (lcol1, more...)
    lbls = collect(Symbol.(first.(lcols)))
    cols = collect(AbstractVector, last.(lcols))
    TupleVector(lbls, len, cols)
end

function _checktuple(lbls::Vector{Symbol}, idxs::AbstractVector{Int}, cols::Vector{AbstractVector})
    if !isempty(lbls)
        length(lbls) == length(cols) || error("number of labels ≠ number of columns")
        seen = Set{Symbol}()
        for lbl in lbls
            !(lbl in seen) || error("duplicate column label $(repr(lbl))")
            push!(seen, lbl)
        end
    end
    if !isempty(idxs)
        m = maximum(idxs)
        for col in cols
            length(col) >= m || error("insufficient column height")
        end
    end
end

function _checktuple(lbls::Vector{Symbol}, len::Int, cols::Vector{AbstractVector})
    if !isempty(lbls)
        length(lbls) == length(cols) || error("number of labels ≠ number of columns")
        seen = Set{Symbol}()
        for lbl in lbls
            !(lbl in seen) || error("duplicate column label $(repr(lbl))")
            push!(seen, lbl)
        end
    end
    for col in cols
        length(col) == len || error("unexpected column height")
    end
end

# Printing.

summary(io::IO, tv::TupleVector) =
    print(io, "TupleVector of $(length(tv)) × $(sigsyntax(tv))")

siglabel(lbl::Symbol) =
    Base.isidentifier(lbl) ? lbl : string(lbl)

sigsyntax(tv::TupleVector) =
    if isempty(tv.lbls)
        Expr(:tuple, sigsyntax.(tv.cols)...)
    else
        Expr(:tuple, sigsyntax.(siglabel.(tv.lbls) .=> tv.cols)...)
    end

show(io::IO, tv::TupleVector) =
    show_columnar(io, tv)

show(io::IO, ::MIME"text/plain", tv::TupleVector) =
    display_columnar(io, tv)

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

@inline getindex(tv::TupleVector, ::Colon, j::Union{Int,Symbol}) =
    column(tv, j)

@inline function getindex(tv::TupleVector, ::Colon, js::AbstractVector)
    @boundscheck checkbounds(tv.cols, js)
    @inbounds tv′ = TupleVector(tv.lbls, tv.idxs, tv.cols[js])
    tv′
end


#
# Vector of vectors in a columnar form.
#

# Constructors.

"""
    BlockVector(offs::AbstractVector{Int}, elts::AbstractVector; plural=true, optional=true)
    BlockVector(:, elts::AbstractVector; plural=false, optional=false)

Vector of vectors (blocks) stored as a vector of elements partitioned by a
vector of offsets.

- `elts` is a continuous vector of block elements.
- `offs` is a vector of indexes that subdivide `elts` into separate blocks.
  Should be monotonous with `offs[1] == 1` and `offs[end] == length(elts)+1`.
  Use `:` if the offset vector is a unit range.
- `plural` is `false` if each block should contain at most 1 element
  (`offs[i+1] <= offs[i]+1` for all `i`); `true` otherwise.
- `optional` is `false` if each block should contain at least 1 element
  (`offs[i+1] >= offs[i]+1` for all `i`); `true` otherwise.
"""
struct BlockVector{PLU,OPT,O<:AbstractVector{Int},E<:AbstractVector} <: AbstractVector{Any}
    offs::O
    elts::E

    @inline function BlockVector{PLU,OPT,O,E}(offs::O, elts::E) where {PLU,OPT,O<:AbstractVector{Int},E<:AbstractVector}
        @boundscheck _checkblock(length(elts), offs, PLU, OPT)
        new{PLU,OPT,O,E}(offs, elts)
    end
end

@inline BlockVector{PLU,OPT}(offs::O, elts::E) where {PLU,OPT,O<:AbstractVector{Int},E<:AbstractVector} =
    BlockVector{PLU,OPT,O,E}(offs, elts)

@inline BlockVector{PLU,OPT}(::Colon, elts::AbstractVector) where {PLU,OPT} =
    BlockVector{PLU,OPT}(OneTo{Int}(length(elts)+1), elts)

@inline BlockVector(offs::AbstractVector{Int}, elts::AbstractVector; plural=true, optional=true) =
    BlockVector{plural,optional}(offs, elts)

@inline BlockVector(::Colon, elts::AbstractVector; plural=false, optional=false) =
    BlockVector{plural,optional}(:, elts)

function _checkblock(len::Int, offs::OneTo{Int}, ::Bool, ::Bool)
    !isempty(offs) || error("partition must be non-empty")
    offs[end] == len+1 || error("partition must enclose the elements")
end

function _checkblock(len::Int, offs::AbstractVector{Int}, plu::Bool, opt::Bool)
    !isempty(offs) || error("partition must be non-empty")
    @inbounds off = offs[1]
    off == 1 || error("partition must start with 1")
    for k = 2:lastindex(offs)
        @inbounds off′ = offs[k]
        off′ >= off || error("partition must be monotone")
        plu || off′ <= off+1 || error("singular blocks must have at most one element")
        opt || off′ >= off+1 || error("mandatory blocks must have at least one element")
        off = off′
    end
    off == len+1 || error("partition must enclose the elements")
end

# Printing.

summary(io::IO, bv::BlockVector) =
    print(io, "BlockVector of $(length(bv)) × $(sigsyntax(bv))")

sigsyntax(bv::BlockVector{PLU,OPT}) where {PLU,OPT} =
    Expr(:call, :×, PLU && OPT ? :* : PLU ? :+ : OPT ? :- : 1, sigsyntax(bv.elts))

show(io::IO, bv::BlockVector) =
    show_columnar(io, bv)

show(io::IO, ::MIME"text/plain", bv::BlockVector) =
    display_columnar(io, bv)

# Properties.

@inline offsets(bv::BlockVector) = bv.offs

@inline elements(bv::BlockVector) = bv.elts

@inline isplural(bv::BlockVector{PLU}) where {PLU} = PLU

@inline isplural(::Type{<:BlockVector{PLU}}) where {PLU} = PLU

@inline isoptional(bv::BlockVector{PLU,OPT}) where {PLU,OPT} = OPT

@inline isoptional(::Type{<:BlockVector{PLU,OPT}}) where {PLU,OPT} = OPT

# Vector interface.

@inline size(bv::BlockVector) = (length(bv.offs)-1,)

IndexStyle(::Type{<:BlockVector}) = IndexLinear()

eltype(bv::BlockVector{true}) =
    AbstractVector{eltype(bv.elts)}

eltype(bv::BlockVector{false,true}) =
    Union{eltype(bv.elts),Missing}

eltype(bv::BlockVector{false,false}) =
    eltype(bv.elts)

@inline function getindex(bv::BlockVector{true}, k::Int)
    @boundscheck checkbounds(bv, k)
    @inbounds rng = bv.offs[k]:bv.offs[k+1]-1
    @inbounds elt = bv.elts[rng]
    elt
end

@inline function getindex(bv::BlockVector{false,true}, k::Int)
    @boundscheck checkbounds(bv, k)
    @inbounds rng = bv.offs[k]:bv.offs[k+1]-1
    @inbounds elt = !isempty(rng) ? bv.elts[rng.start] : missing
    elt
end

@inline function getindex(bv::BlockVector{false,false}, k::Int)
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

function _getindex(bv::BlockVector{PLU,OPT}, ks::AbstractVector) where {PLU,OPT}
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
    @inbounds bv′ = BlockVector{PLU,OPT}(offs′, elts′)
    bv′
end

function _getindex(bv::BlockVector{PLU,OPT,OneTo{Int}}, ks::AbstractVector) where {PLU,OPT}
    offs′ = OneTo(length(ks)+1)
    @inbounds elts′ = bv.elts[ks]
    @inbounds bv′ = BlockVector{PLU,OPT}(offs′, elts′)
    bv′
end

function _getindex(bv::BlockVector{PLU,OPT}, ks::OneTo) where {PLU,OPT}
    len = length(ks)
    if len == length(bv.offs)-1
        return bv
    end
    @inbounds offs′ = bv.offs[OneTo(len+1)]
    @inbounds top = bv.offs[len+1]
    @inbounds elts′ = bv.elts[OneTo(top-1)]
    @inbounds bv′ = BlockVector{PLU,OPT}(offs′, elts′)
    bv′
end

function _getindex(bv::BlockVector{PLU,OPT,OneTo{Int}}, ks::OneTo) where {PLU,OPT}
    len = length(ks)
    if len == length(bv.offs)-1
        return bv
    end
    offs′ = OneTo(len+1)
    @inbounds elts′ = bv.elts[ks]
    @inbounds bv′ = BlockVector{PLU,OPT}(offs′, elts′)
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

BlockCursor(bv::BlockVector{O,E}) where {T,O<:AbstractVector{Int},E<:AbstractVector{T}} =
    BlockCursor{T,O,E}(bv)

BlockCursor(pos, l, r, bv::BlockVector{O,E}) where {T,O<:AbstractVector{Int},E<:AbstractVector{T}} =
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

sigsyntax(v::AbstractVector) = eltype(v)

sigsyntax(p::Pair{<:Union{Symbol,String},<:AbstractVector}) =
    Expr(:(=), p.first, sigsyntax(p.second))

Base.typeinfo_prefix(io::IO, cv::Union{TupleVector,BlockVector}) =
    if !get(io, :compact, false)::Bool
        "@VectorTree $(sigsyntax(cv)) "
    else
        ""
    end

show_columnar(io::IO, v::AbstractVector) =
    Base.show_vector(io, v)

function display_columnar(io::IO, v::AbstractVector)
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
- Named tuple `(lbl₁ = col₁, lbl₂ = col₂, ...)` indicates a `TupleVector` instance
  with the given labels.
- Prefixes `(*)`, `(+)`, `(-)`, `(1)` indicate a `BlockVector` instance with
  the respective cardinality constraints (no constraints, mandatory, singular,
  mandatory+singular).

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

function sig2mk(sig)
    if sig isa Expr && sig.head == :tuple
        lbls = Symbol[]
        col_mks = MakeAbstractVector[]
        for arg in sig.args
            if arg isa Expr && arg.head == :(=) && length(arg.args) == 2 && arg.args[1] isa Union{Symbol,String}
                push!(lbls, Symbol(arg.args[1]))
                push!(col_mks, sig2mk(arg.args[2]))
            else
                push!(col_mks, sig2mk(arg))
            end
        end
        return MakeTupleVector(lbls, col_mks)
    elseif sig isa Expr && sig.head == :vect && length(sig.args) == 1
        elts_mk = sig2mk(sig.args[1])
        return MakeBlockVector(elts_mk, true, true)
    elseif sig isa Expr && sig.head == :call && length(sig.args) == 3 &&
           sig.args[1] in (:×, :*) && sig.args[2] in (:*, :+, :-, 1)
        elts_mk = sig2mk(sig.args[3])
        plu = sig.args[2] in (:*, :+)
        opt = sig.args[2] in (:*, :-)
        return MakeBlockVector(elts_mk, plu, opt)
    else
        ty = sig
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
    plu::Bool
    opt::Bool
    top::Int

    MakeBlockVector(elts_mk, plu, opt) = new(elts_mk, [1], plu, opt, 1)
end

mutable struct MakeVector <: MakeAbstractVector
    ty::Any
    vals::Vector{Any}

    MakeVector(ty) = new(ty, [])
end

function vectorize(mk::MakeAbstractVector, ex)
    if ex isa Expr && (ex.head == :vect || ex.head == :vcat)
        for arg in ex.args
            _rearrange!(mk, arg)
        end
        return _reconstruct(mk)
    else
        error("expected a vector literal; got $(repr(ex))")
    end
end

function _rearrange!(mk::MakeTupleVector, ex)
    if ex isa Expr && (ex.head == :tuple || ex.head == :row)
        if length(ex.args) == length(mk.col_mks)
            for (j, (arg, col_mk)) in enumerate(zip(ex.args, mk.col_mks))
                if arg isa Expr && arg.head == :(=) && length(arg.args) == 2
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
    if ex isa Expr && (ex.head == :vect || ex.head == :vcat)
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
    Expr(:call, Expr(:curly, BlockVector, mk.plu, mk.opt),
                mk.offs == (1:length(mk.offs)) ? :(:) : mk.offs,
                _reconstruct(mk.elts_mk))

_reconstruct(mk::MakeVector) =
    Expr(:ref, mk.ty, mk.vals...)

