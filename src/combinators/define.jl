#
# The define combinator.
#

define(name::Symbol, X::SomeCombinator) =
    Combinator(define, name, X)

syntax(::typeof(define), args::Vector{Any}) =
    syntax(define, args...)

syntax(::typeof(define), name::Symbol, X::SomeCombinator) =
    name

define(env::Environment, q::Query, name::Symbol, X::SomeCombinator) =
    combine(X, env, q)

