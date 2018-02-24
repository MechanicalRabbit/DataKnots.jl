#
# Wrapper vector that supports specialized vector interfaces.
#

abstract type WrapperVector{W<:AbstractVector,T} <: AbstractVector{T} end

wrappertype(::Type{<:WrapperVector{W}}) where {W} = W

wrappertype(V::Type{<:AbstractVector}) = V

wrappertype(vals) = wrappertype(typeof(vals))

