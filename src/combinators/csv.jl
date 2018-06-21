#
# CSV-related combinators.
#

parse_csv(; kws...) = Combinator(parse_csv, kws)

function parse_csv(env::Environment, q::Query, kws)
    r = csv_parse(; kws...) |> designate(InputShape(String), OutputShape(AnyShape(), OPT|PLU))
    compose(q, r)
end

load_csv(filename::String; kws...) = Combinator(load_csv, filename, kws)

function load_csv(env::Environment, q::Query, filename, kws)
    r = chain_of(
            lift(_ -> read(filename, String)),
            csv_parse(; kws...),
    ) |> designate(InputShape(Nothing), OutputShape(AnyShape(), OPT|PLU))
    compose(q, r)
end

