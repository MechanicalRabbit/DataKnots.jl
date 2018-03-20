#
# Executing a query.
#

query(; params...) =
    F -> query(F; params...)

query(F; params...) =
    query(thedb(), F; params...)

query(data, F; params...) =
    execute(convert(DataKnot, data) >> convert(SomeCombinator, F),
            sort(collect(Pair{Symbol,DataKnot}, params), by=first))

execute(data::DataKnot, params::Vector{Pair{Symbol,DataKnot}}=Pair{Symbol,DataKnot}[]) =
    data

function execute(F::SomeCombinator, params::Vector{Pair{Symbol,DataKnot}}=Pair{Symbol,DataKnot}[])
    q = prepare(F, params)
    input = pack(q, params)
    output = q(input)
    return unpack(q, output)
end

function prepare(F::SomeCombinator, slots::Vector{Pair{Symbol,OutputShape}}=Pair{Symbol,OutputShape}[])
    env = Environment(slots)
    optimize(combine(F, env, stub()))
end

function prepare(F::SomeCombinator, params::Vector{Pair{Symbol,DataKnot}})
    slots = Pair{Symbol,OutputShape}[param.first => shape(param.second) for param in params]
    prepare(F, slots)
end

function pack(q, params)
    data = [nothing]
    md = imode(q)
    if isfree(md)
        return data
    else
        cols = AbstractVector[]
        if isframed(md)
            push!(cols, [1])
        end
        k = 1
        for slot in slots(md)
            while k <= length(params) && params[k].first < slot.first
                k += 1
            end
            if k > length(params) || params[k].first != slot.first
                error("parameter is not specified: $(slot.first)")
            end
            elts = elements(params[k].second)
            push!(cols, BlockVector(length(elts) == 1 ? (:) : [1, length(elts)+1], elts))
        end
        return TupleVector(1, AbstractVector[data, TupleVector(1, cols)])
    end
end

unpack(q, output) = DataKnot(shape(q), elements(output))

