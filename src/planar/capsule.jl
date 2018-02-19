#
# Attaches the references for any nested indexes.
#

"""
    CapsuleVector(vals::AbstractVector, refs::Pair{Symbol,<:AbstractVector}...)

To any composite vector, attaches the references for any nested indexes.
"""
struct CapsuleVector{T,V<:AbstractVector{T}} <: AbstractVector{T}
    vals::V
    refs::Vector{Pair{Symbol,AbstractVector}}
end

CapsuleVector(vals::V, refs::Vector{Pair{Symbol,AbstractVector}}) where {T,V<:AbstractVector{T}} =
    CapsuleVector{T,V}(vals, refs)

CapsuleVector(vals, refs::Pair{Symbol,<:AbstractVector}...) =
    CapsuleVector(vals, sort(collect(Pair{Symbol,AbstractVector}, refs), by=(ref -> ref.first)))

# Properties and methods.

isclosed(::CapsuleVector) = true

@inline dereference(cv::CapsuleVector) =
    recapsulate(cv) do vals
        dereference(vals, cv.refs)
    end

@inline recapsulate(fn, vals::AbstractVector) = fn(vals)

@inline recapsulate(fn, cv::CapsuleVector) =
    encapsulate(fn(cv.vals), cv.refs)

@inline recapsulate(fn, vs::Vector{AbstractVector}) =
    let vs, refs = decapsulate(vs), vals = fn(vs)
        isempty(refs) ? vals : encapsulate(vals, refs)
    end

@inline decapsulate(cv::CapsuleVector) = cv.vals, cv.refs

let NO_REFS = Pair{Symbol,AbstractVector}[]

    global decapsulate

    @inline decapsulate(vals::AbstractVector) = vals, NO_REFS

    function decapsulate(vs::Vector{AbstractVector})
        vs′ = AbstractVector{}
        refs = Pair{Symbol,AbstractVector}[]
        for v in vs
            v′, refs′ = decapsulate(v)
            push!(vs′, v)
            if !isempty(refs′)
                if isempty(refs) || refs === refs′
                    refs = refs′
                else
                    merge!((ref1, ref2) -> ref1 === ref2 ? ref1 : error("duplicate reference name"),
                           refs, refs′)
                end
            end
        end
        (vs′, isempty(refs) ? NO_REFS : refs)
    end
end


@inline encapsulate(vals::AbstractVector, refs::Vector{Pair{Symbol,AbstractVector}}) =
    isclosed(vals) ? vals : CapsuleVector(vals, refs)

# Printing.

signature_syntax(cv::CapsuleVector) = signature_syntax(cv.vals)

function show(io::IO, cv::CapsuleVector)
    show_planar(io, cv)
    io = IOContext(io, :limit => true)
    print(io, " where {")
    first = true
    for ref in cv.refs
        if !first
            print(io, ", ")
        end
        first = false
        print(io, ref.first, " = ", ref.second)
    end
    print(io, "}")
end

function show(io::IO, ::MIME"text/plain", cv::CapsuleVector)
    display_planar(io, cv)
    io = IOContext(io, :limit => true)
    println(io)
    print(io, "where")
    for ref in cv.refs
        println(io)
        print(io, " ", ref.first, " = ", ref.second)
    end
end

# Vector interface.

@inline size(cv::CapsuleVector) = size(cv.vals)

IndexStyle(::Type{<:CapsuleVector{T,V}}) where {T,V} = IndexStyle(V)

@inline getindex(cv::CapsuleVector, k::Int) = cv.vals[k]

@inline getindex(cv::CapsuleVector, ks::AbstractVector) =
    CapsuleVector(cv.vals[ks], cv.refs)

