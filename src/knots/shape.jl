#
# Representing the shape of the data.
#

# Shape types.

abstract type AbstractShape end

syntax(shp::AbstractShape) =
    Expr(:call, nameof(typeof(shp)), Symbol(" … "))

syntax_abbr(shp::AbstractShape) =
    syntax(shp::AbstractShape)

show(io::IO, shp::AbstractShape) =
    Layouts.print_code(io, syntax(shp))

struct DecoratedShape{S<:AbstractShape} <: AbstractShape
    vals::S
    decors::Vector{Pair{Symbol,Any}}
end

syntax(shp::DecoratedShape) =
    Expr(:call, :|>, syntax(shp.vals), Expr(:call, decorate, shp.decors...))

decoration(::AbstractShape, ::Symbol, ::Type=Any, default=missing) =
    default

function decoration(shp::DecoratedShape, name::Symbol, ty::Type=Any, default=missing)
    for decor in shp.decors
        if decor.first == name
            val = decor.second
            if val isa ty
                return val
            end
            break
        end
    end
    return default
end

isclosed(shp::DecoratedShape) = isclosed(shp.vals)

undecorate(shp::AbstractShape) = shp

undecorate(shp::DecoratedShape) = shp.vals

function decorate(shp::AbstractShape, decors::Vector{Pair{Symbol,Any}})
    if isempty(decors)
        return shp
    end
    return DecoratedShape(shp, decors)
end

function decorate(shp::DecoratedShape, decors::Vector{Pair{Symbol,Any}})
    if isempty(decors)
        return shp
    end
    return DecoratedShape(shp.vals, merge(shp.decors, decors))
end

decorate(decors::Pair{Symbol}...) =
    let decors = sort(collect(Pair{Symbol,Any}, decors), by=(decor -> decor.first))
        obj -> decorate(obj, decors)
    end

struct AnyShape <: AbstractShape
    closed::Bool
end

AnyShape() = AnyShape(false)

syntax(shp::AnyShape) =
    if shp.closed
        Expr(:call, nameof(AnyShape), true)
    else
        Expr(:call, nameof(AnyShape))
    end

isclosed(shp::AnyShape) = shp.closed

struct NoneShape <: AbstractShape
end

syntax(::NoneShape) = Expr(:call, nameof(NoneShape))

isclosed(::NoneShape) = true

struct NativeShape <: AbstractShape
    ty::Type
end

convert(::Type{AbstractShape}, ty::Type) =
    NativeShape(ty)

syntax(shp::NativeShape) = Expr(:call, nameof(NativeShape), shp.ty)

eltype(shp::NativeShape) = shp.ty

eltype(shp::DecoratedShape{NativeShape}) = eltype(undecorate(shp))

isclosed(::NativeShape) = true

struct TupleShape <: AbstractShape
    cols::Vector{AbstractShape}
    closed::Bool

    TupleShape(cols::Vector{AbstractShape}) =
        new(cols, all(isclosed, cols))
end

TupleShape(itr...) =
    TupleShape(collect(AbstractShape, itr))

syntax(shp::TupleShape) =
    Expr(:call, nameof(TupleShape), map(syntax, shp.cols)...)

getindex(shp::TupleShape, ::Colon) = shp.cols

getindex(shp::DecoratedShape{TupleShape}, ::Colon) = getindex(undecorate(shp), :)

getindex(shp::TupleShape, i) = shp.cols[i]

getindex(shp::DecoratedShape{TupleShape}, i) = getindex(undecorate(shp), i)

isclosed(shp::TupleShape) = shp.closed

struct BlockShape <: AbstractShape
    card::Cardinality
    elts::AbstractShape
end

syntax(shp::BlockShape) =
    Expr(:call, nameof(BlockShape), shp.card, syntax(shp.elts))

cardinality(shp::BlockShape) = shp.card

cardinality(shp::DecoratedShape{BlockShape}) = cardinality(undecorate(shp))

getindex(shp::BlockShape) = shp.elts

getindex(shp::DecoratedShape{BlockShape}) = getindex(undecorate(shp))

isclosed(shp::BlockShape) = isclosed(shp.elts)

struct IndexShape <: AbstractShape
    cls::Symbol
end

convert(::Type{AbstractShape}, cls::Symbol) =
    IndexShape(cls)

syntax(shp::IndexShape) =
    Expr(:call, nameof(IndexShape), QuoteNode(shp.cls))

class(shp::IndexShape) = shp.cls

class(shp::DecoratedShape{IndexShape}) = class(undecorate(shp))

isclosed(::IndexShape) = false

deferefence(shp::AbstractShape, refs::Vector{Pair{Symbol,AbstractShape}}) = shp

function dereference(shp::IndexShape, refs::Vector{Pair{Symbol,AbstractShape}})
    for ref in refs
        if ref.first == shp.cls
            return ref.second
        end
    end
    shp
end

abstract type NominalShape <: AbstractShape end

struct OutputShape <: NominalShape
    vals::AbstractShape
    card::Cardinality
end

OutputShape(vals) = OutputShape(vals, REG)

syntax(shp::OutputShape) =
    if shp.card == REG
        Expr(:call, nameof(OutputShape), syntax(shp.vals))
    else
        Expr(:call, nameof(OutputShape), syntax(shp.vals), shp.card)
    end

decoration(shp::OutputShape, name::Symbol, ty::Type=Any, default=missing) =
    decoration(shp.vals, name, ty, default)

decorate(shp::OutputShape, decors::Vector{Pair{Symbol,Any}}) =
    OutputShape(decorate(shp.vals, decors), shp.card)

cardinality(shp::OutputShape) = shp.card

getindex(shp::OutputShape) = shp.vals

isclosed(shp::OutputShape) = isclosed(shp.vals)

denominalize(shp::OutputShape) =
    BlockShape(shp.card, shp.vals)

struct InputShape <: NominalShape
    vals::AbstractShape
    slots::Vector{Pair{Symbol,OutputShape}}
    rel::Bool
end

let NO_SLOTS = Pair{Symbol,OutputShape}[]

    global InputShape

    InputShape(vals, slots::Vector{Pair{Symbol,OutputShape}}) =
        InputShape(vals, slots, false)

    InputShape(vals, rel::Bool) =
        InpuShape(vals, NO_SLOTS, rel)

    InputShape(vals) =
        Inputshape(vals, NO_SLOTS, false)
end

function syntax(shp::InputShape)
    args = Any[syntax(shp.vals)]
    if !isempty(shp.slots)
        push!(args, Expr(:vect, map(slot -> Expr(:call, :(=>), QuoteNode(slot.first), syntax(slot.second)),
                                    shp.slots)...))
    end
    if shp.rel
        push!(args, shp.rel)
    end
    Expr(:call, nameof(InputShape), args...)
end

decoration(shp::InputShape, name::Symbol, ty::Type=Any, default=missing) =
    decoration(shp.vals, name, ty, default)

decorate(shp::InputShape, decors::Vector{Pair{Symbol,Any}}) =
    InputShape(decorate(shp.vals, decors), shp.slots, shp.rel)

getindex(shp::InputShape) = shp.vals

isclosed(shp::InputShape) =
    isclosed(shp.vals) && all(slot -> isclosed(slot.second), shp.slots)

function denominalize(shp::InputShape)
    shp′ = shp.vals
    if !isempty(shp.slots)
        shp′ = TupleShape(shp′, map(slot -> slot.second, shp.slots)...)
    end
    if shp.rel
        shp′ = BlockShape(PLU, shp′)
    end
    shp′
end

struct CapsuleShape{S<:AbstractShape} <: AbstractShape
    vals::S
    refs::Vector{Pair{Symbol,AbstractShape}}
end

let NO_REFS = Pair{Symbol,AbstractShape}[]

    global CapsuleShape

    CapsuleShape(vals) = CapsuleShape(vals, NO_REFS)
end

CapsuleShape(vals, refs::Pair{Symbol,<:AbstractShape}...) =
    CapsuleShape(vals, sort(collect(Pair{Symbol,AbstractShape}, refs), by=(ref -> ref.first)))

syntax(shp::CapsuleShape) =
    Expr(:call, nameof(CapsuleShape),
                syntax(shp.vals),
                map(ref -> Expr(:call, :(=>), QuoteNode(ref.first), syntax(ref.second)), shp.refs)...)

isclosed(::CapsuleShape) = true

undecorate(shp::CapsuleShape) = shp.vals

function with(fn, shp::CapsuleShape)
    vals′ = fn(shp.vals)::AbstractShape
    if vals′ == shp.vals
        return shp
    end
    if !isempty(shp.refs)
        vals′ = dereference(vals′, shp.refs)
    end
    if isclosed(vals′)
        CapsuleShape(vals′)
    else
        CapsuleShape(vals′, shp.refs)
    end
end

# Subshape relation.

fits(shp1::AbstractShape, shp2::AbstractShape) = false

fits(shp1::S, shp2::S) where {S<:AbstractShape} =
    shp1 == shp2

fits(shp1::AbstractShape, shp2::AnyShape) =
    !isclosed(shp2) || isclosed(shp1)

fits(shp1::AnyShape, shp2::AnyShape) =
    !isclosed(shp2) || isclosed(shp1)

fits(::NoneShape, ::AbstractShape) = true

fits(::NoneShape, ::AnyShape) = true

fits(::NoneShape, ::NoneShape) = true

fits(shp1::DecoratedShape, shp2::AbstractShape) =
    fits(shp1.vals, shp2)

fits(shp1::DecoratedShape, shp2::AnyShape) =
    fits(shp1.vals, shp2)

fits(shp1::AbstractShape, shp2::DecoratedShape) =
    isempty(shp2.decors) && fits(shp1, shp2.vals)

fits(shp1::NoneShape, shp2::DecoratedShape) =
    isempty(shp2.decors) && fits(shp1, shp2.vals)

fits(shp1::DecoratedShape, shp2::DecoratedShape) =
    fits(shp1.vals, shp2.vals) && fits(shp1.decors, shp2.decors)

fits(shp1::S, shp2::S) where {S<:DecoratedShape} =
    shp1 == shp2 ||
    fits(shp1.vals, shp2.vals) && fits(shp1.decors, shp2.decors)

function fits(decors1::Vector{Pair{Symbol,Any}}, decors2::Vector{Pair{Symbol,Any}})
    j = 1
    for decor2 in decors2
        while j <= length(decors1) && decors1[j].first < decor2.first
            j += 1
        end
        if j > length(decors1) || decors1[j].first != decor2.first
            return false
        end
        if !(decors1[j].second === nothing || isequal(decors1[j].second, decor2.second))
            return false
        end
    end
    return true
end

fits(shp1::NativeShape, shp2::NativeShape) =
    shp1.ty <: shp2.ty

fits(shp1::TupleShape, shp2::TupleShape) =
    shp1 == shp2 || shp1.cols == shp2.cols ||
    length(shp1.cols) == length(shp2.cols) &&
    all(fits(col1, col2) for (col1, col2) in zip(shp1.cols, shp2.cols))

fits(shp1::BlockShape, shp2::BlockShape) =
    shp1 == shp2 ||
    fits(shp1.card, shp2.card) &&
    fits(shp1.elts, shp2.elts)

fits(shp1::IndexShape, shp2::IndexShape) =
    shp1.cls == shp2.cls

fits(shp1::OutputShape, shp2::OutputShape) =
    shp1 == shp2 ||
    fits(shp1.card, shp2.card) &&
    fits(shp1.vals, shp2.vals)

fits(shp1::InputShape, shp2::InputShape) =
    shp1 == shp2 ||
    shp1.rel >= shp2.rel &&
    fits(shp1.slots, shp2.slots) &&
    fits(shp1.vals, shp2.vals)

function fits(nshps1::Vector{Pair{Symbol,S}}, nshps2::Vector{Pair{Symbol,S}}) where {S<:AbstractShape}
    j = 1
    for nshp2 in nshps2
        while j <= length(nshps1) && nshps1[j].first < nshps2.first
            j += 1
        end
        if j > length(nshps1) || nshps1[j].first != nshp2.first
            return false
        end
        if !fits(nshps1[j].second, nshp2.second)
            return false
        end
    end
    return true
end

fits(shp1::CapsuleShape, shp2::CapsuleShape) =
    shp1 == shp2 ||
    fits(shp1.refs, shp2.refs) &&
    fits(shp1.vals, shp2.vals)

# Upper and lower bounds.

bound(::Type{<:AbstractShape}) = NoneShape()

ibound(::Type{<:AbstractShape}) = AnyShape()

bound(shp1::AbstractShape, shp2::AbstractShape) =
    AnyShape(isclosed(shp1) && isclosed(shp2))

ibound(::AbstractShape, ::AbstractShape) = NoneShape()

bound(shp1::DecoratedShape, shp2::AbstractShape) =
    bound(shp1.vals, shp2)

ibound(shp1::DecoratedShape, shp2::AbstractShape) =
    DecoratedShape(ibound(shp1.vals, shp2), shp1.decors)

bound(shp1::AbstractShape, shp2::DecoratedShape) =
    bound(shp1, shp2.vals)

ibound(shp1::AbstractShape, shp2::DecoratedShape) =
    DecoratedShape(ibound(shp1, shp2.vals), shp2.decors)

bound(shp1::DecoratedShape, shp2::DecoratedShape) =
    shp1 == shp2 ? shp1 :
    let vals = bound(shp1.vals, shp2.vals),
        decors = bound(shp1.decors, shp2.decors)
        isempty(decors) ? vals : DecoratedShape(vals, decors)
    end

ibound(shp1::DecoratedShape, shp2::DecoratedShape) =
    shp1 == shp2 ? shp1 :
    let vals = ibound(shp1.vals, shp2.vals),
        decors = ibound(shp1.decors, shp2.decors)
        isempty(decors) ? vals : DecoratedShape(vals, decors)
    end

function bound(decors1::Vector{Pair{Symbol,Any}}, decors2::Vector{Pair{Symbol,Any}})
    decors = Pair{Symbol,Any}[]
    i = 1
    j = 1
    while i <= length(decors1) && j <= length(decors2)
        if decors1[i].first < decors2[j].first
            i += 1
        elseif decors1[i].first > decors2[j].first
            j += 1
        else
            if isequal(decors1[i].second, decors2[j].second) || decors2[j].second === nothing
                push!(decors, decors1[i])
            elseif decors1[i].second === nothing
                push!(decors, decors2[j])
            end
            i += 1
            j += 1
        end
    end
    decors
end

ibound(decors1::Vector{Pair{Symbol,Any}}, decors2::Vector{Pair{Symbol,Any}}) =
    merge((d1, d2) -> isequal(d1, d2) ? d1 : nothing, decors1, decors2)

bound(shp1::NoneShape, shp2::AbstractShape) = shp2

bound(shp1::NoneShape, shp2::DecoratedShape) = shp2

bound(shp1::AbstractShape, shp2::NoneShape) = shp1

bound(shp1::DecoratedShape, shp2::NoneShape) = shp1

bound(shp1::NoneShape, ::NoneShape) = shp1

ibound(shp1::AnyShape, shp2::AbstractShape) =
    !isclosed(shp1) || isclosed(shp2) ? shp2 : NoneShape()

ibound(shp1::AnyShape, shp2::DecoratedShape) =
    DecoratedShape(ibound(shp1, shp2.vals), shp2.decors)

ibound(shp1::AbstractShape, shp2::AnyShape) =
    !isclosed(shp2) || isclosed(shp1) ? shp1 : NoneShape()

ibound(shp1::DecoratedShape, shp2::AnyShape) =
    DecoratedShape(ibound(shp1.vals, shp2), shp1.decors)

ibound(shp1::AnyShape, shp2::AnyShape) =
    isclosed(shp1) ? shp1 : shp2

bound(shp1::NativeShape, shp2::NativeShape) =
    shp1 == shp2 ? shp1 :
    let ty = typejoin(shp1.ty, shp2.ty)
        ty == Any ? AnyShape(true) : NativeShape(ty)
    end

ibound(shp1::NativeShape, shp2::NativeShape) =
    shp1 == shp2 ? shp1 :
    let ty = typeintersect(shp1.ty, shp2.ty)
        ty == Union{} ? NoneShape() : NativeShape(ty)
    end

bound(shp1::IndexShape, shp2::IndexShape) =
    shp1.cls == shp2.cls ? shp1 : AnyShape()

ibound(shp1::IndexShape, shp2::IndexShape) =
    shp1.cls == shp2.cls ? shp1 : NoneShape()

bound(shp1::TupleShape, shp2::TupleShape) =
    shp1 == shp2 ? shp1 :
    length(shp1.cols) == length(shp2.cols) ?
        TupleShape(AbstractShape[bound(col1, col2) for (col1, col2) in zip(shp1.cols, shp2.cols)]) :
        AnyShape(isclosed(shp1) && isclosed(shp2))

ibound(shp1::TupleShape, shp2::TupleShape) =
    shp1 == shp2 ? shp1 :
    length(shp1.cols) == length(shp2.cols) ?
        TupleShape(AbstractShape[ibound(col1, col2) for (col1, col2) in zip(shp1.cols, shp2.cols)]) :
        NoneShape()

bound(shp1::BlockShape, shp2::BlockShape) =
    shp1 == shp2 ? shp1 :
    BlockShape(shp1.card|shp2.card, bound(shp1.elts, shp2.elts))

ibound(shp1::BlockShape, shp2::BlockShape) =
    shp1 == shp2 ? shp1 :
    BlockShape(shp1.card&shp2.card, ibound(shp1.elts, shp2.elts))

bound(shp1::OutputShape, shp2::OutputShape) =
    shp1 == shp2 ? shp1 :
    OutputShape(bound(shp1.vals, shp2.vals), shp1.card|shp2.card)

ibound(shp1::OutputShape, shp2::OutputShape) =
    shp1 == shp2 ? shp1 :
    OutputShape(ibound(shp1.vals, shp2.vals), shp1.card&shp2.card)

bound(shp1::InputShape, shp2::InputShape) =
    shp1 == shp2 ? shp1 :
    InputShape(bound(shp1.vals, shp2.vals),
               bound(shp1.slots, shp2.slots),
               shp1.rel && shp2.rel)

ibound(shp1::InputShape, shp2::InputShape) =
    shp1 == shp2 ? shp1 :
    InputShape(ibound(shp1.vals, shp2.vals),
               ibound(shp1.slots, shp2.slots),
               shp1.rel && shp2.rel)

bound(slots1::Vector{Pair{Symbol,S}}, slots2::Vector{Pair{Symbol,S}}) where {S<:AbstractShape} =
    merge(ibound, slots1, slots2)

bound(shp1::CapsuleShape{OutputShape}, shp2::CapsuleShape{OutputShape}) =
    shp1 == shp2 ? shp1 :
    CapsuleShape(bound(shp1.vals, shp2.vals), bound(shp1.refs, shp2.refs))

ibound(shp1::CapsuleShape{InputShape}, shp2::CapsuleShape{InputShape}) =
    shp1 == shp2 ? shp1 :
    CapsuleShape(ibound(shp1.vals, shp2.vals), #= ? =# bound(shp1.refs, shp2.refs))

# Shape-aware vector.

struct ShapeAwareVector{T,V<:AbstractVector{T}} <: AbstractVector{T}
    shp::AbstractShape
    vals::V
end



