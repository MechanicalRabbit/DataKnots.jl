#
# Pagination.
#

take_by(N::Union{Missing,Int}, rev::Bool=false) =
    Query(take_by, N, rev)

function take_by(rt::Runtime, input::AbstractVector, N::Missing, rev::Bool)
    input isa SomeBlockVector || error("expected a block vector; got $input at\n$(take_by(N, rev))")
    input
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

take_by(rev::Bool=false) =
    Query(take_by, rev)

function take_by(rt::Runtime, input::AbstractVector, rev::Bool)
    input isa SomeTupleVector || error("expected a tuple vector; got $input at\n$(take_by(rev))")
    cols = columns(input)
    length(cols) == 2 || error("expected two columns; got $cols at\n$(take_by(rev))")
    vals, Ns = cols
    vals isa SomeBlockVector || error("expected a block vector; got $vals at\n$(take_by(rev))")
    eltype(Ns) <: Union{Missing,Int} || error("expected an integer vector; got $Ns at\n$(take_by(rev))")
    len = length(input)
    offs = offsets(vals)
    elts = elements(vals)
    R = 1
    sz = 0
    for k = 1:len
        L = R
        @inbounds N = Ns[k]
        @inbounds R = offs[k+1]
        (l, r) = _take_range(N, R-L, rev)
        sz += r - l + 1
    end
    if sz == length(elts)
        return val_col
    end
    offs′ = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs′[1] = top = 1
    R = 1
    for k = 1:len
        L = R
        @inbounds N = Ns[k]
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

@inline _take_range(n::Int, l::Int, rev::Bool) =
    if !rev
        (1, n >= 0 ? min(l, n) : max(0, l + n))
    else
        (n >= 0 ? min(l + 1, n + 1) : max(1, l + n + 1), l)
    end

@inline _take_range(::Missing, l::Int, ::Bool) =
    (1, l)

