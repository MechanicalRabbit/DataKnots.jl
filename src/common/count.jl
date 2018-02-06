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

function count_map(dv::AbstractVector)
    isdata(dv) || error("expected a data vector")
    len = length(dv)
    if isregular(dv)
        return DataVector{REG}(FillVector(1, len))
    end
    if length(items(dv)) == 0
        return DataVector{REG}(FillVector(0, len))
    end
    offsets(dv) do offs
        itms′ = Vector{Int}(len)
        for k = 1:len
            @inbounds itms′[k] = offs[k+1] - offs[k]
        end
        DataVector{REG}(itms′)
    end
end

