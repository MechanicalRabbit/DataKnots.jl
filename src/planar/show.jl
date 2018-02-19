#
# Printing planar vectors.
#

const SomePlanarVector = Union{BlockVector,IndexVector,TupleVector,CapsuleVector}

signature_syntax(v::AbstractVector) = eltype(v)

Base.typeinfo_prefix(io::IO, pv::SomePlanarVector) =
    if !get(io, :compact, false)::Bool
        "@Planar $(signature_syntax(pv)) "
    else
        ""
    end

summary(io::IO, pv::SomePlanarVector) =
    print(io, "$(typeof(pv).name.name) of $(length(pv)) × $(signature_syntax(pv))")

show_planar(io::IO, v::AbstractVector) =
    Base.show_vector(io, v)

function display_planar(io::IO, v::AbstractVector)
    summary(io, v)
    !isempty(v) || return
    println(io, ":")
    if !haskey(io, :compact)
        io = IOContext(io, :compact => true)
    end
    Base.print_array(io, v)
end

