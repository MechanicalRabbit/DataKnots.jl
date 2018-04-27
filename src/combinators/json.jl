#
# JSON-related combinators.
#

parse_json() = Combinator(parse_json)

function parse_json(env::Environment, q::Query)
    r = chain_of(
            json_parse(),
            dereference(),
            as_block(),
    ) |> designate(InputShape(String), OutputShape(JSONShape()))
    compose(q, r)
end

load_json(filename::String) = Combinator(load_json, filename)

function load_json(env::Environment, q::Query, filename)
    r = chain_of(
            lift(_ -> read(filename, String)),
            json_parse(),
            dereference(),
            as_block(),
    ) |> designate(InputShape(Nothing), OutputShape(JSONShape()))
    compose(q, r)
end

json_value(T::Type) = Combinator(json_value, T)

json_value(env::Environment, q::Query, ::Type{Any}) =
    q

json_value(env::Environment, q::Query, ::Type{Bool}) =
    compose(
        q,
        column(:bool) |> designate(InputShape(JSONShape()), OutputShape(Bool, OPT)))

json_value(env::Environment, q::Query, ::Type{Int}) =
    compose(
        q,
        column(:int) |> designate(InputShape(JSONShape()), OutputShape(Int, OPT)))

json_value(env::Environment, q::Query, ::Type{Float64}) =
    compose(
        q,
        column(:float) |> designate(InputShape(JSONShape()), OutputShape(Float64, OPT)))

json_value(env::Environment, q::Query, ::Type{String}) =
    compose(
        q,
        column(:str) |> designate(InputShape(JSONShape()), OutputShape(String, OPT)))

function json_value(env::Environment, q::Query, T::Type{<:Vector})
    r = compose(
        q,
        chain_of(
            column(:array),
            in_block(dereference()),
        ) |> designate(InputShape(JSONShape()), OutputShape(JSONShape(), OPT|PLU)))
    json_value(env, r, eltype(T))
end

json_field(key::String) =
    Combinator(json_field, key)

json_field(key::String, T::Type) =
    Combinator(json_field, key, T)

function json_field(env::Environment, q::Query, key)
    r = chain_of(
            column(:object),
            in_block(
                chain_of(
                    tuple_of(
                        column(:val),
                        chain_of(
                            column(:key),
                            lift(k -> k == key))),
                    sieve())),
            flat_block(),
            in_block(dereference()),
    ) |> designate(InputShape(JSONShape()), OutputShape(JSONShape(), OPT))
    compose(q, r)
end

json_field(env::Environment, q::Query, key, T) =
    json_value(env, json_field(env, q, key), T)

