#
# Sieve a vector.
#

sieve() = Query(sieve)

function sieve(rt::Runtime, input::AbstractVector)
    input isa SomeTupleVector || error("expected a tuple vector; got $input at\n$(sieve())")
    len = length(input)
    cols = columns(input)
    length(cols) == 2 || error("expected two columns; got $cols at\n$(sieve())")
    val_col, pred_col = cols
    pred_col isa AbstractVector{Bool} || error("expected a Boolean vector; got $pred_col at\n$(sieve())")
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

