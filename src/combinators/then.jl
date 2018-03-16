#
# Then combinator.
#

then(q::Query) =
    Combinator(then, q)

then(env::Environment, q::Query, q′::Query) =
    compose(q, q′)

then(ctor, args...) =
    Combinator(then, ctor, args...)

then(env::Environment, q::Query, ctor, args...) =
    ctor(env, istub(q), then(q), args...)

