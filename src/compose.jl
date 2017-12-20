#
# Identity and composition combinators.
#

struct ItOp <: AbstractPrimitive
end

const It = Combinator(ItOp(), [])

combine(q::Query, op::ItOp) =
    q

struct ComposeOp <: AbstractOperation
end

Base.>>(X::Combinator, Y::Combinator) =
    Combinator(ComposeOp(), [X, Y])

Base.>>(X, Y::Combinator) =
    convert(Combinator, X) >> Y

combine(q::Query, op::ComposeOp, X::Combinator, Y::Combinator) =
    combine(combine(q, X), Y)

