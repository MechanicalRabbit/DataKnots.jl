#
# Structure of query input and query output.
#

struct OutputMode
    card::Cardinality
end

struct OutputSignature
    dom::Domain
    mode::OutputMode
end

const OutputBinding = Pair{Symbol,OutputSignature}

struct InputMode
    rel::Bool
    slots::Vector{OutputBinding}
end

struct InputSignature
    dom::Domain
    mode::InputMode
end

