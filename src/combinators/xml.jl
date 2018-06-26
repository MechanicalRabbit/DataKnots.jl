#
# XML-related combinators.
#

ParseXML() = Combinator(ParseXML)

function ParseXML(env::Environment, q::Query)
    r = chain_of(
            xml_parse(),
            dereference(),
            as_block(),
    ) |> designate(InputShape(String), OutputShape(XMLShape()))
    compose(q, r)
end

LoadXML(filename::String) = Combinator(LoadXML, filename)

function LoadXML(env::Environment, q::Query, filename)
    r = chain_of(
            lift(_ -> read(filename, String)),
            xml_parse(),
            dereference(),
            as_block(),
    ) |> designate(InputShape(Nothing), OutputShape(XMLShape()))
    compose(q, r)
end

XMLTag() = Combinator(XMLTag)

XMLTag(env::Environment, q::Query) =
    compose(
        q,
        column(:tag) |> designate(InputShape(XMLShape()), OutputShape(String)))

XMLChild() = Combinator(XMLChild)

XMLChild(tag::String) = Combinator(XMLChild, tag)

XMLChild(env::Environment, q::Query) =
    compose(
        q,
        chain_of(
            column(:child),
            in_block(dereference()),
        ) |> designate(InputShape(XMLShape()), OutputShape(XMLShape(), OPT|PLU)))

XMLChild(env::Environment, q::Query, tag::String) =
    compose(
        q,
        chain_of(
            column(:child),
            in_block(
                chain_of(
                    dereference(),
                    tuple_of(
                        pass(),
                        chain_of(
                            column(:tag),
                            in_block(lift(t -> t == tag)),
                            any_block())),
                    sieve())),
            flat_block(),
        ) |> designate(InputShape(XMLShape()), OutputShape(XMLShape(), OPT|PLU)))

XMLAttr(key::String) =
    Combinator(XMLAttr, key)

function XMLAttr(env::Environment, q::Query, key)
    r = chain_of(
            column(:attr),
            in_block(
                chain_of(
                    tuple_of(
                        column(:val),
                        chain_of(
                            column(:key),
                            lift(k -> k == key))),
                    sieve())),
            flat_block(),
    ) |> designate(InputShape(XMLShape()), OutputShape(String, OPT))
    compose(q, r)
end

