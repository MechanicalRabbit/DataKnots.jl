#
# JSON-related combinators.
#

ParseJSON() = Combinator(ParseJSON)

function ParseJSON(env::Environment, q::Query)
    r = chain_of(
            json_parse(),
            dereference(),
            as_block(),
    ) |> designate(InputShape(String), OutputShape(JSONShape()))
    compose(q, r)
end

LoadJSON(filename::String) = Combinator(LoadJSON, filename)

function LoadJSON(env::Environment, q::Query, filename)
    r = chain_of(
            lift(_ -> read(filename, String)),
            json_parse(),
            dereference(),
            as_block(),
    ) |> designate(InputShape(Nothing), OutputShape(JSONShape()))
    compose(q, r)
end

JSONValue(T::Type) = Combinator(JSONValue, T)

JSONValue(env::Environment, q::Query, ::Type{Any}) =
    q

JSONValue(env::Environment, q::Query, ::Type{Bool}) =
    compose(
        q,
        column(:bool) |> designate(InputShape(JSONShape()), OutputShape(Bool, OPT)))

JSONValue(env::Environment, q::Query, ::Type{Int}) =
    compose(
        q,
        column(:int) |> designate(InputShape(JSONShape()), OutputShape(Int, OPT)))

JSONValue(env::Environment, q::Query, ::Type{Float64}) =
    compose(
        q,
        column(:float) |> designate(InputShape(JSONShape()), OutputShape(Float64, OPT)))

JSONValue(env::Environment, q::Query, ::Type{String}) =
    compose(
        q,
        column(:str) |> designate(InputShape(JSONShape()), OutputShape(String, OPT)))

function JSONValue(env::Environment, q::Query, T::Type{<:Vector})
    r = compose(
        q,
        chain_of(
            column(:array),
            in_block(dereference()),
        ) |> designate(InputShape(JSONShape()), OutputShape(JSONShape(), OPT|PLU)))
    JSONValue(env, r, eltype(T))
end

JSONField(key::String) =
    Combinator(JSONField, key)

JSONField(key::String, T::Type) =
    Combinator(JSONField, key, T)

function JSONField(env::Environment, q::Query, key)
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

JSONField(env::Environment, q::Query, key, T) =
    JSONValue(env, JSONField(env, q, key), T)

