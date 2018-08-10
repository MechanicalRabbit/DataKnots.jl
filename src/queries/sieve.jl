#
# Sieve a vector.
#

"""
    sieve()

Filters the vector of pairs by the second column.
"""
sieve() = Query(sieve)

function sieve(rt::Runtime, input::AbstractVector)
    @ensure_fits input TupleShape(AnyShape(), NativeShape(Bool))
    len = length(input)
    val_col, pred_col = columns(input)
    sz = count(pred_col)
    if sz == len
        return BlockVector(:, val_col)
    elseif sz == 0
        return BlockVector(fill(1, len+1), val_col[[]])
    end
    offs = Vector{Int}(undef, len+1)
    perm = Vector{Int}(undef, sz)
    @inbounds offs[1] = top = 1
    for k = 1:len
        if pred_col[k]
            perm[top] = k
            top += 1
        end
        offs[k+1] = top
    end
    return BlockVector(offs, val_col[perm])
end

