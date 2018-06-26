#
# Then combinator.
#

Then(q::Query) =
    Combinator(Then, q)

Then(env::Environment, q::Query, q′::Query) =
    compose(q, q′)

Then(ctor, args...) =
    Combinator(Then, ctor, args...)

Then(env::Environment, q::Query, ctor, args...) =
    ctor(env, istub(q), Then(q), args...)

