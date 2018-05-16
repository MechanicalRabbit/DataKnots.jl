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

