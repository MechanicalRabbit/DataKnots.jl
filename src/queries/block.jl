#
# Operations on block vectors.
#


"""
    as_block()

Wraps input values to one-element blocks.
"""
as_block() =
    Query(as_block) do env, input
        BlockVector(:, input)
    end


"""
    in_block(q)

Using q, transfors the elements of the input blocks.
"""
in_block(q) =
    Query(in_block, q) do env, input
        input isa SomeBlockVector || error("expected a block vector; got $input")
        BlockVector(offsets(input), q(env, elements(input)))
    end


"""
    flat_block()

Flattens a nested block vector.
"""
flat_block() =
    Query(flat_block) do env, input
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

