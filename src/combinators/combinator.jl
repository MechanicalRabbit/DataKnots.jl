#
# Combinator interface.
#

struct Combinator
    op
    args::Vector{Any}
    src

    Combinator(op, args::Vector{Any}) =
        new(op, args, nothing)
end

Combinator(op, args...) =
    Combinator(op, collect(Any, args))

syntax(F::Combinator) =
    syntax(F.op, F.args)

show(io::IO, F::Combinator) =
    print_code(io, syntax(F))

