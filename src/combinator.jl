#
# Combinator type.
#


struct Combinator
    op::AbstractOperation
    args::Vector{Combinator}
end

