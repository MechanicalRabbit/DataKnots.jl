#
# Operations on block vectors.
#


"""
    as_block()

Wraps input values to one-element blocks.
"""
as_block() = Query(as_block)

as_block(rt::Runtime, input::AbstractVector) =
    BlockVector(:, input)


"""
    in_block(q)

Using q, transfors the elements of the input blocks.
"""
in_block(q) = Query(in_block, q)

function in_block(rt::Runtime, input::AbstractVector, q)
    input isa SomeBlockVector || error("expected a block vector; got $input")
    BlockVector(offsets(input), q(rt, elements(input)))
end


"""
    flat_block()

Flattens a nested block vector.
"""
flat_block() = Query(flat_block)

function flat_block(rt::Runtime, input::AbstractVector)
    input isa SomeBlockVector || error("expected a block vector; got $input")
    offs = offsets(input)
    nested = elements(input)
    nested isa SomeBlockVector || error("expected a block vector; got $nested")
    nested_offs = offsets(nested)
    elts = elements(nested)
    BlockVector(_flat_block(offs, nested_offs), elts)
end

_flat_block(offs1::AbstractVector{Int}, offs2::AbstractVector{Int}) =
    Int[offs2[off] for off in offs1]

_flat_block(offs1::OneTo{Int}, offs2::OneTo{Int}) = offs1

_flat_block(offs1::OneTo{Int}, offs2::AbstractVector{Int}) = offs2

_flat_block(offs1::AbstractVector{Int}, offs2::OneTo{Int}) = offs1


"""
    pull_block(lbl)

Converts a tuple with a block column to a block of tuples.
"""
pull_block(lbl) = Query(pull_block, lbl)

function pull_block(rt::Runtime, input::AbstractVector, lbl)
    input isa SomeTupleVector || error("expected a tuple vector; got $input")
    j = locate(input, lbl)
    j !== nothing || error("invalid column $lbl of $input")
    len = length(input)
    lbls = labels(input)
    cols = columns(input)
    col = cols[j]
    col isa SomeBlockVector || error("expected a block vector; got $col")
    offs = offsets(col)
    col′ = elements(col)
    cols′ = copy(cols)
    if offs isa OneTo{Int}
        cols′[j] = col′
        return BlockVector(offs, TupleVector(lbls, len, cols′))
    end
    len′ = length(col′)
    perm = Vector{Int}(undef, len′)
    l = r = 1
    @inbounds for k = 1:len
        l = r
        r = offs[k+1]
        for n = l:r-1
            perm[n] = k
        end
    end
    for i in eachindex(cols′)
        cols′[i] =
            if i == j
                col′
            else
                cols′[i][perm]
            end
    end
    return BlockVector(offs, TupleVector(lbls, len′, cols′))
end


"""
    pull_every_block()

Converts a tuple vector with block columns to a block vector over a tuple
vector.
"""
pull_every_block() = Query(pull_every_block)

function pull_every_block(rt::Runtime, input::AbstractVector)
    input isa SomeTupleVector || error("expected a tuple vector; got $input")
    cols = columns(input)
    for col in cols
        col isa SomeBlockVector || error("expected a block vector; got $col")
    end
    _pull_every_block(labels(input), length(input), cols...)
end

@generated function _pull_every_block(lbls::Vector{Symbol}, len::Int, cols::SomeBlockVector...)
    D = length(cols)
    return quote
        @nextract $D offs (d -> offsets(cols[d]))
        @nextract $D elts (d -> elements(cols[d]))
        if @nall $D (d -> offs_d isa OneTo{Int})
            return BlockVector(:, TupleVector(lbls, len, AbstractVector[(@ntuple $D elts)...]))
        end
        len′ = 0
        regular = true
        @inbounds for k = 1:len
            sz = @ncall $D (*) (d -> (offs_d[k+1] - offs_d[k]))
            len′ += sz
            regular = regular && sz == 1
        end
        if regular
            return BlockVector(:, TupleVector(lbls, len, AbstractVector[(@ntuple $D elts)...]))
        end
        offs′ = Vector{Int}(undef, len+1)
        @nextract $D perm (d -> Vector{Int}(undef, len′))
        @inbounds offs′[1] = top = 1
        @inbounds for k = 1:len
            @nloops $D n (d -> offs_{$D-d+1}[k]:offs_{$D-d+1}[k+1]-1) begin
                @nexprs $D (d -> perm_{$D-d+1}[top] = n_d)
                top += 1
            end
            offs′[k+1] = top
        end
        cols′ = @nref $D AbstractVector (d -> elts_d[perm_d])
        return BlockVector(offs′, TupleVector(lbls, len′, cols′))
    end
end


"""
    count_block()

Maps a block vector to a vector of block lengths.
"""
count_block() = Query(count_block)

function count_block(rt::Runtime, input::AbstractVector)
    input isa SomeBlockVector || error("expected a block vector; got $input")
    _count_block(offsets(input))
end

_count_block(offs::OneTo{Int}) =
    fill(1, length(offs)-1)

function _count_block(offs::AbstractVector{Int})
    len = length(offs) - 1
    output = Vector{Int}(undef, len)
    @inbounds for k = 1:len
        output[k] = offs[k+1] - offs[k]
    end
    output
end


"""
    any_block()

Checks if there is one `true` value in a block of `Bool` values.
"""
any_block() = Query(any_block)

function any_block(rt::Runtime, input::AbstractVector)
    input isa SomeBlockVector || error("expected a block vector; got $input")
    len = length(input)
    offs = offsets(input)
    elts = elements(input)
    elts isa AbstractVector{Bool} || error("expected a Bool vector; got $elts")
    if offs isa OneTo
        return elts
    end
    output = Vector{Bool}(undef, len)
    l = r = 1
    @inbounds for k = 1:len
        val = false
        l = r
        r = offs[k+1]
        for i = l:r-1
            if elts[i]
                val = true
                break
            end
        end
        output[k] = val
    end
    return output
end

