#
# Assign a label.
#

tag(lbl::Symbol) =
    Combinator(tag, lbl)

tag(env::Environment, q::Query, lbl::Symbol) =
    q |> designate(ishape(q), shape(q) |> decorate(:tag => lbl))

convert(::Type{SomeCombinator}, p::Pair{Symbol}) =
    compose(convert(SomeCombinator, p.second), tag(p.first))

