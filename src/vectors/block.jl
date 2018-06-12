#
# Vector of vectors (blocks) in a columnar/SoA form.
#

# Abstract interface.

abstract type AbstractBlockVector{T} <: AbstractVector{T} end

const SomeBlockVector{T} = Union{AbstractBlockVector{T},WrapperVector{<:AbstractBlockVector{T}}}

# Constructors.

"""
    BlockVector(offs::AbstractVector{Int}, elts::AbstractVector)
    BlockVector(blks::AbstractVector)

Vector of vectors (blocks) stored as a vector of elements partitioned by a
vector of offsets.
"""
struct BlockVector{O<:AbstractVector{Int},E<:AbstractVector} <: AbstractBlockVector{Any}
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

@inline isclosed(bv::BlockVector) = isclosed(bv.elts)

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

# Ordering.

struct BlockOrdering{O<:AbstractVector{Int},EOrd<:Base.Ordering} <: Base.Ordering
    offs::O
    nullrev::Bool
    ord::EOrd
end

BlockOrdering(::OneTo{Int}, ::Bool, ord::Base.Ordering) = ord

Base.@propagate_inbounds function Base.lt(o::BlockOrdering, a::Int, b::Int)
    la = o.offs[a]
    ra = o.offs[a+1]
    lb = o.offs[b]
    rb = o.offs[b+1]
    while la < ra && lb < rb
        if Base.lt(o.ord, la, lb)
            return true
        end
        if Base.lt(o.ord, lb, la)
            return false
        end
        la += 1
        lb += 1
    end
    if la < ra
        return o.nullrev
    end
    if lb < rb
        return !o.nullrev
    end
    return false
end

ordering(bv::BlockVector, ::Nothing=nothing) =
    ordering(bv, (false, nothing))

ordering(bv::BlockVector, spec::Tuple{Bool,Any}) =
    let (nullrev, espec) = spec
        BlockOrdering(bv.offs, nullrev, ordering(bv.elts, espec))
    end

struct BlockPairOrdering{O1<:AbstractVector{Int},O2<:AbstractVector{Int},EOrd<:Base.Ordering} <: Base.Ordering
    offs1::O1
    offs2::O2
    ord::EOrd
end

BlockPairOrdering(::OneTo{Int}, ::OneTo{Int}, ord::Base.Ordering) = ord

Base.@propagate_inbounds function Base.lt(o::BlockPairOrdering, a::Int, b::Int)
    (la, ra, da) = a > 0 ? (o.offs1[a], o.offs1[a+1], 1) : (-o.offs2[-a], -o.offs2[-a+1], -1)
    (lb, rb, db) = b > 0 ? (o.offs1[b], o.offs1[b+1], 1) : (-o.offs2[-b], -o.offs2[-b+1], -1)
    while la != ra && lb != rb
        if Base.lt(o.ord, la, lb)
            return true
        end
        if Base.lt(o.ord, lb, la)
            return false
        end
        la += da
        lb += db
    end
    if la != ra
        return false
    end
    if lb != rb
        return true
    end
    return false
end

ordering_pair(bv1::BlockVector, bv2::BlockVector) =
    BlockPairOrdering(bv1.offs, bv2.offs, ordering_pair(bv1.elts, bv2.elts))

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

