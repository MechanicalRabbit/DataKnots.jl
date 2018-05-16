#
# Pagination.
#

take_by(N::Union{Missing,Int}, rev::Bool=false) =
    Query(take_by, N, rev)

function take_by(rt::Runtime, input::AbstractVector, N::Missing, rev::Bool)
    input isa SomeBlockVector || error("expected a block vector; got $input at\n$(take_by(N, rev))")
    input
end

@inline _take_range(n::Int, l::Int, rev::Bool) =
    if !rev
        (1, n >= 0 ? min(l, n) : max(0, l + n))
    else
        (n >= 0 ? min(l + 1, n + 1) : max(1, l + n + 1), l)
    end

function take_by(rt::Runtime, input::AbstractVector, N::Int, rev::Bool)
    input isa SomeBlockVector || error("expected a block vector; got $input at\n$(take_by(N, rev))")
    len = length(input)
    offs = offsets(input)
    elts = elements(input)
    sz = 0
    R = 1
    for k = 1:len
        L = R
        @inbounds R = offs[k+1]
        (l, r) = _take_range(N, R-L, rev)
        sz += r - l + 1
    end
    if sz == length(elts)
        return input
    end
    offs′ = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs′[1] = top = 1
    R = 1
    for k = 1:len
        L = R
        @inbounds R = offs[k+1]
        (l, r) = _take_range(N, R-L, rev)
        for j = (L + l - 1):(L + r - 1)
            perm[top] = j
            top += 1
        end
        offs′[k+1] = top
    end
    elts′ = elts[perm]
    return BlockVector(offs′, elts′)
end

