#
# Vector of tuples in a planar form.
#

# Constructors.

"""
    TupleVector([lbls::Vector{Symbol}, len::Int, cols::Vector{AbstractVector})
    TupleVector(cols::Pair{Symbol,<:AbstractVector}...)

Vector of tuples stored as a collection of column vectors.
"""
struct TupleVector{I<:AbstractVector{Int}} <: AbstractVector{Any}
    lbls::Vector{Symbol}            # isempty(lbls) means plain tuples
    idxs::I
    cols::Vector{AbstractVector}
    icols::Vector{AbstractVector}   # [col[idxs] for col in cols]
end

@inline function TupleVector(lbls::Vector{Symbol}, idxs::I, cols::Vector{AbstractVector}) where {I<:AbstractVector{Int}}
    @boundscheck _checktuple(lbls, idxs, cols)
    icols = Vector{AbstractVector}(uninitialized, length(cols))
    TupleVector{I}(lbls, idxs, cols, icols)
end

@inline function TupleVector(lbls::Vector{Symbol}, len::Int, cols::Vector{AbstractVector})
    @boundscheck _checktuple(lbls, len, cols)
    idxs = OneTo(len)
    TupleVector{OneTo{Int}}(lbls, idxs, cols, cols)
end

let NO_LBLS = Symbol[]

    global TupleVector

    @inline TupleVector(idxs::AbstractVector{Int}, cols::Vector{AbstractVector}) =
        TupleVector(NO_LBLS, idxs, cols)

    @inline TupleVector(len::Int, cols::Vector{AbstractVector}) =
        TupleVector(NO_LBLS, len, cols)

    @inline TupleVector(len::Int) =
        TupleVector(NO_LBLS, len, AbstractVector[])
end

function TupleVector(lc1::Pair{Symbol,<:AbstractVector}, lcrest::Pair{Symbol,<:AbstractVector}...)
    len = length(lc1.second)
    lcs = (lc1, lcrest...)
    lbls = Symbol[lbl for (lbl, col) in lcs]
    cols = AbstractVector[col for (lbl, col) in lcs]
    TupleVector(lbls, len, cols)
end

function _checktuple(lbls::Vector{Symbol}, idxs::AbstractVector{Int}, cols::Vector{AbstractVector})
    if !isempty(lbls)
        length(lbls) == length(cols) || error("number of labels ≠ number of columns")
        seen = Set{Symbol}()
        for lbl in lbls
            !(lbl in seen) || error("duplicate column label $(repr(lbl))")
            push!(lbl, seen)
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

signature_expr(tv::TupleVector) =
    if isempty(tv.lbls)
        Expr(:tuple, [signature_expr(col) for col in tv.cols]...)
    else
        Expr(:tuple, [Expr(:(=), lbl, signature_expr(col)) for (lbl, col) in zip(tv.lbls, tv.cols)]...)
    end

show(io::IO, tv::TupleVector) =
    show_planar(io, tv)

show(io::IO, ::MIME"text/plain", tv::TupleVector) =
    display_planar(io, tv)

# Properties.

@inline labels(tv::TupleVector) = tv.lbls

@inline width(tv::TupleVector) = length(tv.cols)

@inline function columns(tv::TupleVector)
    _indexcolumns(tv)
    tv.icols
end

@inline function column(tv::TupleVector, i::Int)
    _indexcolumn(tv, i)
    tv.icols[i]
end

@inline column(tv::TupleVector, lbl::Symbol) =
    column(tv, findfirst(equalto(lbl), tv.lbls))

function _indexcolumns(tv::TupleVector)
    for i = 1:length(tv.cols)
        if !isassigned(tv.icols, i)
            @inbounds tv.icols[i] = tv.cols[i][tv.idxs]
        end
    end
end

function _indexcolumn(tv::TupleVector, i)
    if !isassigned(tv.icols, i)
        @inbounds tv.icols[i] = tv.cols[i][tv.idxs]
    end
end

isclosed(tv::TupleVector) = all(isclosed, tv.cols)

# Vector interface.

@inline size(tv::TupleVector) = size(tv.idxs)

IndexStyle(::Type{<:TupleVector}) = IndexLinear()

@inline function getindex(tv::TupleVector, k::Int)
    @boundscheck checkbounds(tv, k)
    @inbounds k′ = tv.idxs[k]
    @inbounds t = ([col[k′] for col in tv.cols]...,)
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

