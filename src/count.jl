#
# Count and ThenCount combinators.
#

struct CountPrim <: AbstractPrimitive
end

CountOp() = WrapOp(CountPrim())

ThenCountOp() = PipeOp(CountPrim())

Count(X::Combinator) =
    Combinator(CountOp(), [X])

Count(X) =
    Count(convert(Combinator, X))

const ThenCount =
    Combinator(ThenCountOp(), [])

const ThenCountIt =
    Combinator(CountPrim(), [])

combine(q::Query, op::WrapOp{CountPrim}, X::Combinator) =
    let it = stub(q)
        q >> box(combine(it, X)) >> sig.prim
    end

combine(q::Query, op::PipeOp{CountPrim}) =
    box(q) >> sig.prim

