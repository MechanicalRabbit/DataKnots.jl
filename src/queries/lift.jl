#
# Lifting scalar functions to vectors.
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

