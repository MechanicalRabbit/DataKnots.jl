#
# Customized ordering.
#

struct ValueOrdering{Ord<:Base.Ordering,V<:AbstractVector} <: Base.Ordering
    ord::Ord
    vals::V
end

Base.@propagate_inbounds function Base.lt(o::ValueOrdering, a::Int, b::Int)
    Base.lt(o.ord, o.vals[a], o.vals[b])
end

ordering(v::AbstractVector, ::Nothing=nothing) =
    ValueOrdering(Base.Forward, v)

ordering(v::AbstractVector, rev::Bool) =
    ValueOrdering(!rev ? Base.Forward : Base.Reverse, v)

struct ValuePairOrdering{V1<:AbstractVector,V2<:AbstractVector} <: Base.Ordering
    vals1::V1
    vals2::V2
end

Base.@propagate_inbounds function Base.lt(o::ValuePairOrdering, a::Int, b::Int)
    x = a > 0 ? o.vals1[a] : o.vals2[-a]
    y = b > 0 ? o.vals1[b] : o.vals2[-b]
    Base.lt(Base.Forward, x, y)
end

ordering_pair(v1::AbstractVector, v2::AbstractVector) =
    ValuePairOrdering(v1, v2)

