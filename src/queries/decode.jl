#
# Decoding regular vectors of composite values as parallel vectors.
#


"""
    decode_missing()

Decodes a vector with `missing` elements as a block vector, where `missing`
elements are converted to empty blocks.
"""
decode_missing() =
    Query(decode_missing) do env, input
        if !(Missing <: eltype(input))
            return BlockVector(:, input)
    end
    sz = 0
    for elt in input
        if elt !== missing
            sz += 1
        end
    end
    O = Base.nonmissingtype(eltype(input))
    if sz == length(input)
        return BlockVector(:, collect(O, input))
    end
    offs = Vector{Int}(uninitialized, length(input)+1)
    elts = Vector{O}(uninitialized, sz)
    @inbounds offs[1] = top = 1
    @inbounds for k in eachindex(input)
        elt = input[k]
        if elt !== missing
            elts[top] = elt
            top += 1
        end
        offs[k+1] = top
    end
    return BlockVector(offs, elts)
end


"""
    decode_vector()

Decodes a vector with vector elements as a block vector.
"""
decode_vector() =
    Query(decode_vector) do env, input
        eltype(input) <: AbstractVector || error("expected a vector of vectors; got $input")
        sz = 0
        for v in input
            sz += length(v)
        end
        O = eltype(eltype(input))
        offs = Vector{Int}(uninitialized, length(input)+1)
        elts = Vector{O}(uninitialized, sz)
        @inbounds offs[1] = top = 1
        @inbounds for k in eachindex(input)
            v = input[k]
            copyto!(elts, top, v)
            top += length(v)
            offs[k+1] = top
        end
        return BlockVector(offs, elts)
    end

"""
    decode_tuple()

Decodes a vector with tuple elements as a tuple vector.
"""
decode_tuple() =
    Query(decode_tuple) do env, input
        lbls = Symbol[]
        I = eltype(input)
        if typeof(I) == DataType && I <: NamedTuple
            lbls = collect(Symbol, I.parameters[1])
            I = I.parameters[2]
        end
        I <: Tuple && !any(Vararg <: C for C in I.parameters) || error("expected a vector of tuples; got $input")
        Is = (I.parameters...,)
        cols = _decode_tuple(input, Is...)
        TupleVector(lbls, length(input), cols)
    end

@generated function _decode_tuple(input, Is...)
    width = length(Is)
    return quote
        len = length(input)
        cols = @ncall $width tuple j -> Vector{Is[j]}(uninitialized, len)
        @inbounds for k in eachindex(input)
            t = input[k]
            @nexprs $width j -> cols[j][k] = t[j]
        end
        collect(AbstractVector, cols)
    end
end

