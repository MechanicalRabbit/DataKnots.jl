#
# Printing parallel vectors.
#

const SomeParallelVector = Union{BlockVector,IndexVector,TupleVector,CapsuleVector}

signature_syntax(v::AbstractVector) = eltype(v)

Base.typeinfo_prefix(io::IO, pv::SomeParallelVector) =
    if !get(io, :compact, false)::Bool
        "@Parallel $(signature_syntax(pv)) "
    else
        ""
    end

summary(io::IO, pv::SomeParallelVector) =
    print(io, "$(typeof(pv).name.name) of $(length(pv)) × $(signature_syntax(pv))")

show_parallel(io::IO, v::AbstractVector) =
    Base.show_vector(io, v)

function display_parallel(io::IO, v::AbstractVector)
    summary(io, v)
    !isempty(v) || return
    println(io, ":")
    if !haskey(io, :compact)
        io = IOContext(io, :compact => true)
    end
    Base.print_array(io, v)
end

