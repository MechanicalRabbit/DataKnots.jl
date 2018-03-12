#
# Vector of tuples in the columnar form.
#

# Abstract interface.

abstract type AbstractTupleVector{T} <: AbstractVector{T} end

const SomeTupleVector{T} = Union{AbstractTupleVector{T},WrapperVector{<:AbstractTupleVector{T}}}

# Constructors.

"""
    TupleVector([lbls::Vector{Symbol}, len::Int, cols::Vector{AbstractVector})
    TupleVector(cols::Pair{Symbol,<:AbstractVector}...)

Vector of tuples stored as a collection of column vectors.
"""
struct TupleVector{I<:AbstractVector{Int}} <: AbstractTupleVector{Any}
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

@inline function columns(tv::TupleVector)
    _indexcolumns(tv)
    tv.icols
end

@inline function column(tv::TupleVector, j::Int)
    _indexcolumn(tv, j)
    tv.icols[j]
end

@inline locate(tv::TupleVector, j::Int) =
    1 <= j <= length(tv.cols) ? j : nothing

@inline locate(tv::TupleVector, lbl::Symbol) =
    findfirst(equalto(lbl), tv.lbls)

@inline column(tv::TupleVector, lbl::Symbol) =
    column(tv, findfirst(equalto(lbl), tv.lbls))

function _indexcolumns(tv::TupleVector)
    for j = 1:length(tv.cols)
        if !isassigned(tv.icols, j)
            @inbounds tv.icols[j] = tv.cols[j][tv.idxs]
        end
    end
end

function _indexcolumn(tv::TupleVector, j)
    if !isassigned(tv.icols, j)
        @inbounds tv.icols[j] = tv.cols[j][tv.idxs]
    end
end

isclosed(tv::TupleVector) = all(isclosed, tv.cols)

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

