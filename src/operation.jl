#
# Type of a query or a combinator.
#


abstract type AbstractOperation end

abstract type AbstractPrimitive <: AbstractOperation end

struct WrapOp{P<:AbstractPrimitive} <: AbstractOperation
    prim::P
end

struct PipeOp{P<:AbstractPrimitive} <: AbstractOperation
    prim::P
end

