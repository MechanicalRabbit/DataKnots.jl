#
# The define combinator.
#

Define(name::Symbol, X::SomeCombinator) =
    Combinator(Define, name, X)

syntax(::typeof(Define), args::Vector{Any}) =
    syntax(Define, args...)

syntax(::typeof(Define), name::Symbol, X::SomeCombinator) =
    name

Define(env::Environment, q::Query, name::Symbol, X::SomeCombinator) =
    combine(X, env, q)

