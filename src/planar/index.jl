#
# Vector of indexes in some named vector.
#

# Abstract interface.

abstract type AbstractIndexVector{T} <: AbstractVector{T} end

const SomeIndexVector{T} = Union{AbstractIndexVector{T},WrapperVector{<:AbstractIndexVector{T}}}

# Constructor.

"""
    IndexVector(ident::Symbol, idxs::AbstractVector{Int})

Vector of indexes in some named vector.
"""
struct IndexVector{I<:AbstractVector{Int}} <: AbstractIndexVector{Int}
    ident::Symbol
    idxs::I
end

# Printing.

signature_expr(iv::IndexVector) =
    Expr(:&, iv.ident)

show(io::IO, iv::IndexVector) =
    show_planar(io, iv)

show(io::IO, ::MIME"text/plain", iv::IndexVector) =
    display_planar(io, iv)

# Properties.

identifier(iv::IndexVector) = iv.ident

indexes(iv::IndexVector) = iv.idxs

isclosed(v::AbstractVector) = true

isclosed(iv::IndexVector) = false

# Dereferencing.

dereference(v::AbstractVector, refs::Vector{<:Pair{Symbol,<:AbstractVector}}) = v

function dereference(iv::IndexVector, refs::Vector{<:Pair{Symbol,<:AbstractVector}})
    for ref in refs
        if ref.first == iv.ident
            return ref.second[iv.idxs]
        end
    end
    iv
end

# Vector interface.

size(iv::IndexVector) = size(iv.idxs)

IndexStyle(::Type{<:IndexVector}) = IndexLinear()

getindex(iv::IndexVector, k::Int) = iv.idxs[k]

@inline function getindex(iv::IndexVector, ks::AbstractVector{Int})
    @boundscheck checkbounds(iv, ks)
    @inbounds iv′ = IndexVector(iv.ident, iv.idxs[ks])
    iv′
end

