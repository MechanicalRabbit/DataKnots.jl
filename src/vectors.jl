#
# Custom vector types for representing data in columnar form.
#

import Base:
    IndexStyle,
    OneTo,
    getindex,
    setindex!,
    show,
    size,
    summary

#
# Vector of tuples in columnar form.
#

# Constructors.

"""
    TupleVector([lbls::Vector{Symbol}], len::Int, cols::Vector{AbstractVector})
    TupleVector(cols::Pair{Symbol,<:AbstractVector}...)

Vector of tuples stored as a collection of column vectors.
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

function TupleVector(lcol1::Pair{Symbol,<:AbstractVector}, more::Pair{Symbol,<:AbstractVector}...)
    len = length(lcol1.second)
    lcols = (lcol1, more...)
    lbls = collect(Symbol, first.(lcols))
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

signature_syntax(tv::TupleVector) =
    if isempty(tv.lbls)
        Expr(:tuple, [signature_syntax(col) for col in tv.cols]...)
    else
        Expr(:tuple, [Expr(:(=), lbl, signature_syntax(col)) for (lbl, col) in zip(tv.lbls, tv.cols)]...)
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
    BlockVector(offs::AbstractVector{Int}, elts::AbstractVector)
    BlockVector(blks::AbstractVector)

Vector of vectors (blocks) stored as a vector of elements partitioned by a
vector of offsets.
"""
struct BlockVector{O<:AbstractVector{Int},E<:AbstractVector} <: AbstractVector{Any}
    offs::O
    elts::E

    @inline function BlockVector{O,E}(offs::O, elts::E) where {O<:AbstractVector{Int},E<:AbstractVector}
        @boundscheck _checkblock(length(elts), offs)
        new{O,E}(offs, elts)
    end
end

@inline BlockVector(offs::O, elts::E) where {O<:AbstractVector{Int},E<:AbstractVector} =
    BlockVector{O,E}(offs, elts)

@inline function BlockVector(::Colon, elts::AbstractVector)
    @inbounds bv = BlockVector(OneTo{Int}(length(elts)+1), elts)
    bv
end

function BlockVector(blks::AbstractVector)
    offs = [1]
    vals = []
    for blk in blks
        if blk isa AbstractVector
            append!(vals, blk)
        elseif blk !== missing
            push!(vals, blk)
        end
        push!(offs, length(vals)+1)
    end
    @inbounds bv = BlockVector(offs, Base.grow_to!(Vector{Union{}}(), vals))
    bv
end

function _checkblock(len::Int, offs::OneTo{Int})
    !isempty(offs) || error("partition must be non-empty")
    offs[end] == len+1 || error("partition must enclose the elements")
end

function _checkblock(len::Int, offs::AbstractVector{Int})
    !isempty(offs) || error("partition must be non-empty")
    @inbounds off = offs[1]
    off == 1 || error("partition must start with 1")
    for k = 2:lastindex(offs)
        @inbounds off′ = offs[k]
        off′ >= off || error("partition must be monotone")
        off = off′
    end
    off == len+1 || error("partition must enclose the elements")
end

# Printing.

signature_syntax(bv::BlockVector) =
    Expr(:vect, signature_syntax(bv.elts))

show(io::IO, bv::BlockVector) =
    show_columnar(io, bv)

show(io::IO, ::MIME"text/plain", bv::BlockVector) =
    display_columnar(io, bv)

# Properties.

@inline offsets(bv::BlockVector) = bv.offs

@inline elements(bv::BlockVector) = bv.elts

@inline partition(bv::BlockVector) = (bv.offs, bv.elts)

# Vector interface.

@inline size(bv::BlockVector) = (length(bv.offs)-1,)

IndexStyle(::Type{<:BlockVector}) = IndexLinear()

@inline function getindex(bv::BlockVector, k::Int)
    @boundscheck checkbounds(bv, k)
    @inbounds rng = bv.offs[k]:bv.offs[k+1]-1
    @inbounds blk =
        if rng.start > rng.stop
            missing
        elseif rng.start == rng.stop
            bv.elts[rng.start]
        else
            bv.elts[rng]
        end
    blk
end

@inline function getindex(bv::BlockVector, ks::AbstractVector)
    @boundscheck checkbounds(bv, ks)
    _getindex(bv, ks)
end

function _getindex(bv::BlockVector, ks::AbstractVector)
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
    @inbounds bv′ = BlockVector(offs′, elts′)
    bv′
end

function _getindex(bv::BlockVector{OneTo{Int}}, ks::AbstractVector)
    offs′ = OneTo(length(ks)+1)
    @inbounds elts′ = bv.elts[ks]
    @inbounds bv′ = BlockVector(offs′, elts′)
    bv′
end

function _getindex(bv::BlockVector, ks::OneTo)
    len = length(ks)
    if len == length(bv.offs)-1
        return bv
    end
    @inbounds offs′ = bv.offs[OneTo(len+1)]
    @inbounds top = bv.offs[len+1]
    @inbounds elts′ = bv.elts[OneTo(top-1)]
    @inbounds bv′ = BlockVector(offs′, elts′)
    bv′
end

function _getindex(bv::BlockVector{OneTo{Int}}, ks::OneTo)
    len = length(ks)
    if len == length(bv.offs)-1
        return bv
    end
    offs′ = OneTo(len+1)
    @inbounds elts′ = bv.elts[ks]
    @inbounds bv′ = BlockVector(offs′, elts′)
    bv′
end

# Mutable view over a block vector.

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

@inline function move!(cr::BlockCursor, pos::Int)
    @boundscheck checkbounds(cr.offs, pos:pos+1)
    cr.pos = pos
    @inbounds cr.l = cr.offs[pos]
    @inbounds cr.r = cr.offs[pos+1]
    cr
end

@inline function next!(cr::BlockCursor)
    @boundscheck checkbounds(cr.offs, cr.pos+1)
    cr.pos += 1
    cr.l = cr.r
    @inbounds cr.r = cr.offs[cr.pos+1]
    cr
end

@inline done(cr::BlockCursor) =
    cr.pos+1 >= length(cr.offs)

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

signature_syntax(v::AbstractVector) = eltype(v)

Base.typeinfo_prefix(io::IO, cv::Union{TupleVector,BlockVector}) =
    if !get(io, :compact, false)::Bool
        "@VectorTree $(signature_syntax(cv)) "
    else
        ""
    end

summary(io::IO, cv::Union{TupleVector,BlockVector}) =
    print(io, "$(typeof(cv).name.name) of $(length(cv)) × $(signature_syntax(cv))")

show_columnar(io::IO, v::AbstractVector) =
    Base.show_vector(io, v)

function display_columnar(io::IO, v::AbstractVector)
    summary(io, v)
    !isempty(v) || return
    println(io, ":")
    if !haskey(io, :compact)
        io = IOContext(io, :compact => true)
    end
    Base.print_array(io, v)
end

#
# @VectorTree constructor.
#

macro VectorTree(sig, ex)
    ctor = sig2ctor(sig)
    ex = vectorize(ctor, ex)
    return esc(ex)
end

function sig2ctor(sig)
    if sig isa Expr && sig.head == :tuple
        lbls = Symbol[]
        col_ctors = AbstractVectorConstructor[]
        for arg in sig.args
            if arg isa Expr && arg.head == :(=) && length(arg.args) == 2 && arg.args[1] isa Symbol
                push!(lbls, arg.args[1])
                push!(col_ctors, sig2ctor(arg.args[2]))
            else
                push!(col_ctors, sig2ctor(arg))
            end
        end
        return TupleVectorConstructor(lbls, col_ctors)
    elseif sig isa Expr && sig.head == :vect && length(sig.args) == 1
        elts_ctor = sig2ctor(sig.args[1])
        return BlockVectorConstructor(elts_ctor)
    else
        ty = sig
        return VectorConstructor(ty)
    end
end

abstract type AbstractVectorConstructor end

mutable struct TupleVectorConstructor <: AbstractVectorConstructor
    lbls::Vector{Symbol}
    col_ctors::Vector{AbstractVectorConstructor}
    len::Int

    TupleVectorConstructor(lbls, col_ctors) = new(lbls, col_ctors, 0)
end

mutable struct BlockVectorConstructor <: AbstractVectorConstructor
    elts_ctor::AbstractVectorConstructor
    offs::Vector{Int}
    top::Int

    BlockVectorConstructor(elts_ctor) = new(elts_ctor, [1], 1)
end

mutable struct VectorConstructor <: AbstractVectorConstructor
    ty::Any
    vals::Vector{Any}

    VectorConstructor(ty) = new(ty, [])
end

function vectorize(ctor::AbstractVectorConstructor, ex)
    if ex isa Expr && (ex.head == :vect || ex.head == :vcat)
        for arg in ex.args
            rearrange!(ctor, arg)
        end
        return reconstruct(ctor)
    else
        error("expected a vector literal; got $(repr(ex))")
    end
end

function rearrange!(ctor::TupleVectorConstructor, ex)
    if ex isa Expr && (ex.head == :tuple || ex.head == :row)
        if length(ex.args) == length(ctor.col_ctors)
            for (j, (arg, col_ctor)) in enumerate(zip(ex.args, ctor.col_ctors))
                if arg isa Expr && arg.head == :(=) && length(arg.args) == 2
                    if j <= length(ctor.lbls) && arg.args[1] == ctor.lbls[j]
                        arg = arg.args[2]
                    elseif j < length(ctor.lbls)
                        error("expected label $(repr(ctor.lbls[j])); got $(repr(arg))")
                    else
                        error("expected no label; got $(repr(arg))")
                    end
                end
                rearrange!(col_ctor, arg)
            end
        else
            error("expected $(length(ctor.col_ctors)) column(s); got $(repr(ex))")
        end
        ctor.len += 1
    elseif length(ctor.col_ctors) == 1
        rearrange!(ctor.col_ctors[1], ex)
        ctor.len += 1
    else
        error("expected a tuple or a row literal; got $(repr(ex))")
    end
end

function rearrange!(ctor::BlockVectorConstructor, ex)
    if ex isa Expr && (ex.head == :vect || ex.head == :vcat)
        for arg in ex.args
            rearrange!(ctor.elts_ctor, arg)
            ctor.top += 1
        end
    elseif ex !== :missing
        rearrange!(ctor.elts_ctor, ex)
        ctor.top += 1
    end
    push!(ctor.offs, ctor.top)
end

function rearrange!(ctor::VectorConstructor, ex)
    push!(ctor.vals, ex)
end

reconstruct(ctor::TupleVectorConstructor) =
    Expr(:call, TupleVector,
                ctor.lbls,
                ctor.len,
                Expr(:ref, AbstractVector, map(reconstruct, ctor.col_ctors)...))

reconstruct(ctor::BlockVectorConstructor) =
    Expr(:call, BlockVector, ctor.offs, reconstruct(ctor.elts_ctor))

reconstruct(ctor::VectorConstructor) =
    Expr(:ref, ctor.ty, ctor.vals...)
