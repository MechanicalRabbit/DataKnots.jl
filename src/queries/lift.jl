#
# Lifting scalar functions to vector operations.
#

"""
    lift(f)

Applies a unary function to each element of an input vector.
"""
lift(f) =
    Query(lift, f) do env, input
        f.(input)
    end


"""
    lift_to_tuple(f)

Applies an n-ary function to each element of an n-tuple vector.
"""
lift_to_tuple(f) =
    Query(lift_to_tuple, f) do env, input
        input isa SomeTupleVector || error("expected a tuple vector; got $input")
        _lift_to_tuple(f, length(input), columns(input)...)
    end

function _lift_to_tuple(f, len::Int, cols::AbstractVector...)
    I = Tuple{eltype.(cols)...}
    O = Core.Compiler.return_type(f, I)
    output = Vector{O}(uninitialized, len)
    @inbounds for k = 1:len
        output[k] = f(getindex.(cols, k)...)
    end
    output
end


"""
    lift_to_block(f)
    lift_to_block(f, default)

Applies a vector function to each block of a block vector.
"""
lift_to_block(f) =
    Query(lift_to_block, f) do env, input
        input isa SomeBlockVector || error("expected a block vector; got $input")
        _lift_to_block(f, input)
    end

lift_to_block(f, default) =
    Query(lift_to_block, f, default) do env, input
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

