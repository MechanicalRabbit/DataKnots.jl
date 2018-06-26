#
# Assign a label.
#

Tag(lbl::Symbol) =
    Combinator(Tag, lbl)

Tag(env::Environment, q::Query, lbl::Symbol) =
    q |> designate(ishape(q), shape(q) |> decorate(:tag => lbl))

convert(::Type{SomeCombinator}, p::Pair{Symbol}) =
    Compose(convert(SomeCombinator, p.second), Tag(p.first))

