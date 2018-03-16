#
# Executing a query.
#

optimize(q::Query) = q

query(; params...) =
    F -> query(F, params...)

query(F; params...) =
    query(thedb(), F, params...)

query(data, F; params...) =
    execute(convert(DataKnot, data) >> convert(SomeCombinator, F),
            sort(collect(Pair{Symbol,DataKnot}, params), by=first))

execute(data::DataKnot, params::Vector{Pair{Symbol,DataKnot}}=Pair{Symbol,DataKnot}[]) =
    data

function execute(F::SomeCombinator, params::Vector{Pair{Symbol,DataKnot}}=[])
    q = prepare(F, params)
    input = pack(q, params)
    output = q(input)
    return unpack(q, output)
end

function prepare(F::SomeCombinator, slots::Vector{Pair{Symbol,OutputShape}}=[])
    env = Environment(slots)
    optimize(combine(F, env, stub()))
end

function prepare(F::SomeCombinator, params::Vector{Pair{Symbol,DataKnot}})
    slots = Pair{Symbol,OutputShape}[param.first => shape(param.second) for param in params]
    prepare(F, slots)
end

pack(q, params) = [nothing]

unpack(q, output) = DataKnot(shape(q), elements(output))

