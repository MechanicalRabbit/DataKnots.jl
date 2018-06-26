#
# CSV-related combinators.
#

ParseCSV(; kws...) = Combinator(ParseCSV, kws)

function ParseCSV(env::Environment, q::Query, kws)
    r = csv_parse(; kws...) |> designate(InputShape(String), OutputShape(AnyShape(), OPT|PLU))
    compose(q, r)
end

LoadCSV(filename::String; kws...) = Combinator(LoadCSV, filename, kws)

function LoadCSV(env::Environment, q::Query, filename, kws)
    r = chain_of(
            lift(_ -> read(filename, String)),
            csv_parse(; kws...),
    ) |> designate(InputShape(Nothing), OutputShape(AnyShape(), OPT|PLU))
    compose(q, r)
end

