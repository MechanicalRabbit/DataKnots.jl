#
# Lifting scalar functions to vector operations.
#

"""
    lift(f)

Applies a unary function to each element of an input vector.
"""
lift(f) = Query(lift, f)

lift(rt::Runtime, input::AbstractVector, f) =
    f.(input)


"""
    lift_to_tuple(f)

Applies an n-ary function to each element of an n-tuple vector.
"""
lift_to_tuple(f) = Query(lift_to_tuple, f)

function lift_to_tuple(rt::Runtime, input::AbstractVector, f)
    input isa SomeTupleVector || error("expected a tuple vector; got $input")
    _lift_to_tuple(f, length(input), columns(input)...)
end

@generated function _lift_to_tuple(f, len::Int, cols::AbstractVector...)
    D = length(cols)
    return quote
        I = Tuple{eltype.(cols)...}
        O = Core.Compiler.return_type(f, I)
        output = Vector{O}(uninitialized, len)
        @inbounds for k = 1:len
            output[k] = @ncall $D f (d -> cols[d][k])
        end
        output
    end
end


"""
    lift_to_block(f)
    lift_to_block(f, default)

Applies a vector function to each block of a block vector.
"""
lift_to_block(f) = Query(lift_to_block, f)

function lift_to_block(rt::Runtime, input::AbstractVector, f)
    input isa SomeBlockVector || error("expected a block vector; got $input")
    _lift_to_block(f, input)
end

lift_to_block(f, default) = Query(lift_to_block, f, default)

function lift_to_block(rt::Runtime, input::AbstractVector, f, default)
    input isa SomeBlockVector || error("expected a block vector; got $input")
    _lift_to_block(f, default, input)
end

function _lift_to_block(f, input)
    cr = cursor(input)
    I = Tuple{typeof(cr)}
    O = Core.Compiler.return_type(f, I)
    output = Vector{O}(uninitialized, length(input))
    @inbounds while !done(cr)
        next!(cr)
        output[cr.pos] = f(cr)
    end
    output
end

function _lift_to_block(f, default, input)
    cr = cursor(input)
    I = Tuple{typeof(cr)}
    O = Union{Core.Compiler.return_type(f, I), typeof(default)}
    output = Vector{O}(uninitialized, length(input))
    @inbounds while !done(cr)
        next!(cr)
        output[cr.pos] = !isempty(cr) ? f(cr) : default
    end
    output
end


"""
    lift_to_block_tuple(f)

Lifts an n-ary function to a tuple vector with block columns.  Applies the
function to every combinations of values from adjacent blocks.
"""
lift_to_block_tuple(f) = Query(lift_to_block_tuple, f)

function lift_to_block_tuple(rt::Runtime, input::AbstractVector, f)
    input isa SomeTupleVector || error("expected a tuple vector; got $input")
    cols = columns(input)
    for col in cols
        col isa SomeBlockVector || error("expected a block vector; got $col")
    end
    _lift_to_block_tuple(f, length(input), cols...)
end

@generated function _lift_to_block_tuple(f, len::Int, cols::SomeBlockVector...)
    D = length(cols)
    return quote
        @nextract $D offs (d -> offsets(cols[d]))
        @nextract $D elts (d -> elements(cols[d]))
        if @nall $D (d -> offs_d isa OneTo{Int})
            return BlockVector(:, _lift_to_tuple(f, len, (@ntuple $D elts)...))
        end
        len′ = 0
        regular = true
        @inbounds for k = 1:len
            sz = @ncall $D (*) (d -> (offs_d[k+1] - offs_d[k]))
            len′ += sz
            regular = regular && sz == 1
        end
        if regular
            return BlockVector(:, _lift_to_tuple(f, len, (@ntuple $D elts)...))
        end
        I = Tuple{eltype.(@ntuple $D elts)...}
        O = Core.Compiler.return_type(f, I)
        offs′ = Vector{Int}(uninitialized, len+1)
        elts′ = Vector{O}(uninitialized, len′)
        @inbounds offs′[1] = top = 1
        @inbounds for k = 1:len
            @nloops $D n (d -> offs_{$D-d+1}[k]:offs_{$D-d+1}[k+1]-1) (d -> elt_{$D-d+1} = elts_{$D-d+1}[n_d]) begin
                elts′[top] = @ncall $D f (d -> elt_d)
                top += 1
            end
            offs′[k+1] = top
        end
        return BlockVector(offs′, elts′)
    end
end


"""
    lift_const(val)

Produces a vector filled with the given value.
"""
lift_const(val) = Query(lift_const, val)

lift_const(rt::Runtime, input::AbstractVector, val) =
    fill(val, length(input))


"""
    lift_null()

Produces a block vector of empty blocks.
"""
lift_null() = Query(lift_null)

lift_null(rt::Runtime, input::AbstractVector) =
    BlockVector(fill(1, length(input)+1), Union{}[])


"""
    lift_block(block)

Produces a block vector filled with the given block.
"""
lift_block(block) = Query(lift_block, block)

function lift_block(rt::Runtime, input::AbstractVector, block)
    if isempty(input)
        return BlockVector(:, block[[]])
    elseif length(input) == 1
        return BlockVector([1, length(block)+1], block)
    else
        len = length(input)
        sz = length(block)
        perm = Vector{Int}(uninitialized, len*sz)
        for k in eachindex(input)
            copyto!(perm, 1 + sz * (k - 1), 1:sz)
        end
        return BlockVector(1:sz:(len*sz+1), block[perm])
    end
end

