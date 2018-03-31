#
# Encapsulates reference vectors for any nested indexes.
#

"""
    CapsuleVector(vals::AbstractVector, refs::Pair{Symbol,<:AbstractVector}...)

To any composite vector, attaches the reference vectors for any nested indexes.
"""
struct CapsuleVector{W<:AbstractVector,T,V<:AbstractVector} <: WrapperVector{W,T}
    vals::V
    refs::Vector{Pair{Symbol,AbstractVector}}
end

CapsuleVector(vals::V, refs::Vector{Pair{Symbol,AbstractVector}}) where {T,V<:AbstractVector{T}} =
    CapsuleVector{wrappertype(V),T,V}(vals, refs)

CapsuleVector(vals, refs::Pair{Symbol,<:AbstractVector}...) =
    CapsuleVector(vals, sort(collect(Pair{Symbol,AbstractVector}, refs), by=first))

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

@inline encapsulate(cv::CapsuleVector, refs::Vector{Pair{Symbol,AbstractVector}}) =
    cv.refs === refs ? cv : CapsuleVector(cv.vals, merge(cv.refs, refs))

# Printing.

signature_syntax(cv::CapsuleVector) = signature_syntax(cv.vals)

function show(io::IO, cv::CapsuleVector)
    show_columnar(io, cv)
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
    display_columnar(io, cv)
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

IndexStyle(::Type{<:CapsuleVector{W,T,V}}) where {W,T,V} = IndexStyle(V)

@inline getindex(cv::CapsuleVector, k::Int) = cv.vals[k]

@inline getindex(cv::CapsuleVector, ks::AbstractVector) =
    CapsuleVector(cv.vals[ks], cv.refs)

# Tuple vector interface.

labels(cv::CapsuleVector{<:AbstractTupleVector}) =
    labels(cv.vals)

width(cv::CapsuleVector{<:AbstractTupleVector}) =
    width(cv.vals)

locate(cv::CapsuleVector{<:AbstractTupleVector}, j::Union{Int,Symbol}) =
    locate(cv.vals, j)

columns(cv::CapsuleVector{<:AbstractTupleVector}) =
    AbstractVector[encapsulate(col, cv.refs) for col in columns(cv.refs)]

column(cv::CapsuleVector{<:AbstractTupleVector}, j::Union{Int,Symbol}) =
    encapsulate(column(cv.vals, j), cv.refs)

getindex(cv::CapsuleVector{<:AbstractTupleVector}, ::Colon, j::Union{Int,Symbol}) =
    column(cv, j)

getindex(cv::CapsuleVector{<:AbstractTupleVector}, ::Colon, js::AbstractVector) =
    encapsulate(cv.vals[:, js], cv.refs)

# Block vector interface.

offsets(cv::CapsuleVector{<:AbstractBlockVector}) =
    offsets(cv.vals)

elements(cv::CapsuleVector{<:AbstractBlockVector}) =
    encapsulate(elements(cv.vals), cv.refs)

# Index vector interface.

identifier(cv::CapsuleVector{<:AbstractIndexVector}) =
    identifier(cv.vals)

indexes(cv::CapsuleVector{<:AbstractIndexVector}) =
    indexes(cv.vals)

dereference(cv::CapsuleVector{<:AbstractIndexVector}) =
    dereference(cv.vals, cv.refs)

