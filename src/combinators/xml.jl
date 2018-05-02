#
# XML-related combinators.
#

parse_xml() = Combinator(parse_xml)

function parse_xml(env::Environment, q::Query)
    r = chain_of(
            xml_parse(),
            dereference(),
            as_block(),
    ) |> designate(InputShape(String), OutputShape(XMLShape()))
    compose(q, r)
end

load_xml(filename::String) = Combinator(load_xml, filename)

function load_xml(env::Environment, q::Query, filename)
    r = chain_of(
            lift(_ -> read(filename, String)),
            xml_parse(),
            dereference(),
            as_block(),
    ) |> designate(InputShape(Nothing), OutputShape(XMLShape()))
    compose(q, r)
end

xml_tag() = Combinator(xml_tag)

xml_tag(env::Environment, q::Query) =
    compose(
        q,
        column(:tag) |> designate(InputShape(XMLShape()), OutputShape(String)))

xml_child() = Combinator(xml_child)

xml_child(tag::String) = Combinator(xml_child, tag)

xml_child(env::Environment, q::Query) =
    compose(
        q,
        chain_of(
            column(:child),
            in_block(dereference()),
        ) |> designate(InputShape(XMLShape()), OutputShape(XMLShape(), OPT|PLU)))

xml_child(env::Environment, q::Query, tag::String) =
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

xml_attr(key::String) =
    Combinator(xml_attr, key)

function xml_attr(env::Environment, q::Query, key)
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

