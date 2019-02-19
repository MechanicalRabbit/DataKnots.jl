#
# Representing signatures of monadic queries.
#

import Base:
    convert,
    getindex,
    eltype,
    show


#
# Generic lattice operations.
#

# Generic upper bound.  Concrete types must define
# `bound(::Type{T})` and `bound(x::T, y::T)`.

"""
    bound(::Type{T}) :: T

The most specific constraint of the type `T`.

    bound(xs::T...) :: T
    bound(xs::Vector{T}) :: T

The tight upper bound of the given sequence of constraints.
"""
function bound end

bound(x) = x

bound(x1, x2, x3, xs...) =
    foldl(bound, xs; init=bound(bound(x1, x2), x3))

bound(xs::Vector{T}) where {T} =
    foldl(bound, xs, init=bound(T))

# Dually, generic lower bound.  Concrete types must define
# `ibound(::Type{T})` and `ibound(x::T, y::T)`.

"""
    ibound(::Type{T}) :: T

The least specific constraint of the type `T`.

    ibound(xs::T...) :: T
    ibound(xs::Vector{T}) :: T

The tight lower bound of the given sequence of constraints.
"""
function ibound end

ibound(x) = x

ibound(x1, x2, x3, xs...) =
    foldl(ibound, xs, init=ibound(ibound(x1, x2), x3))

ibound(xs::Vector{T}) where {T} =
    foldl(ibound, xs, init=ibound(T))

# Ordering test.

"""
    fits(x::T, y::T) :: Bool

Checks if constraint `x` implies constraint `y`.
"""
function fits end


#
# Order on cardinalities.
#

bound(::Type{Cardinality}) = x1to1

bound(c1::Cardinality, c2::Cardinality) = c1 | c2

ibound(::Type{Cardinality}) = x0toN

ibound(c1::Cardinality, c2::Cardinality) = c1 & c2

fits(c1::Cardinality, c2::Cardinality) = (c1 | c2) == c2


#
# Data shapes.
#

"""
    AbstractShape

Represents the shape of column-oriented data.
"""
abstract type AbstractShape end

syntax(shp::AbstractShape) =
    Expr(:call, nameof(typeof(shp)), Symbol(" … "))

syntax(p::Pair{Symbol,AbstractShape}) =
    Expr(:call, :(=>), p.first, syntax(p.second))

sigsyntax(shp::AbstractShape) =
    nameof(typeof(shp))

sigsyntax(p::Pair{Symbol,AbstractShape}) =
    Expr(:(=), p.first, sigsyntax(p.second))

show(io::IO, shp::AbstractShape) =
    print_expr(io, syntax(shp))

"""
    AnyShape()

No constraints on the data.
"""
struct AnyShape <: AbstractShape
end

syntax(::AnyShape) =
    Expr(:call, nameof(AnyShape))

sigsyntax(::AnyShape) =
    :Any

eltype(::AnyShape) = Any

"""
    NoneShape()

Inconsistent constraints on the data.
"""
struct NoneShape <: AbstractShape
end

syntax(::NoneShape) = Expr(:call, nameof(NoneShape))

sigsyntax(::NoneShape) =
    :None

eltype(::NoneShape) = Union{}

"""
    Decoration(label::Union{Nothing,Symbol}=nothing)

Annotations on the query input and output.
"""
struct Decoration
    lbl::Union{Nothing,Symbol}

    Decoration(; label::Union{Nothing,Symbol}=nothing) =
        new(label)
end

function syntax(dr::Decoration)
    args = []
    dr.lbl == nothing || push!(args, QuoteNode(dr.lbl))
    Expr(:call, nameof(Decoration), args...)
end

show(io::IO, dr::Decoration) =
    print_epxr(io, syntax(dr))

label(dr::Decoration) = dr.lbl

decorate(dr::Decoration; label::Union{Missing,Nothing,Symbol}=missing) =
    Decoration(label=(label !== missing ? label : dr.lbl))

decorate(; label::Union{Missing,Nothing,Symbol}=missing) =
    dr -> decorate(dr; label=label)

"""
    OutputMode(card::Cardinality=x1to1)

Monadic constraints on the query output.

Parameter `card` is the cardinality of the query output.
"""
struct OutputMode
    card::Cardinality
end

OutputMode() = OutputMode(x1to1)

convert(::Type{OutputMode}, card::Cardinality) =
    OutputMode(card)

syntax(md::OutputMode) =
    md.card == x1to1 ?
        Expr(:call, nameof(OutputMode)) :
        Expr(:call, nameof(OutputMode), syntax(md.card))

show(io::IO, md::OutputMode) =
    print_expr(io, syntax(md))

cardinality(md::OutputMode) = md.card

isregular(md::OutputMode) = isregular(md.card)

isoptional(md::OutputMode) = isoptional(md.card)

isplural(md::OutputMode) = isplural(md.card)

"""
    OutputShape(::Decoration, ::AbstractShape, ::OutputMode)

The shape of the output of a monadic query.
"""
struct OutputShape <: AbstractShape
    dr::Decoration
    dom::AbstractShape
    md::OutputMode
end

OutputShape(dom::Union{Type,AbstractShape}) =
    OutputShape(Decoration(), dom, x1to1)

OutputShape(lbl::Symbol, dom::Union{Type,AbstractShape}) =
    OutputShape(Decoration(label=lbl), dom, x1to1)

OutputShape(dr::Decoration, dom::Union{Type,AbstractShape}) =
    OutputShape(dr, dom, x1to1)

OutputShape(dom::Union{Type,AbstractShape}, md::Union{Cardinality,OutputMode}) =
    OutputShape(Decoration(), dom, md)

OutputShape(lbl::Symbol, dom::Union{Type,AbstractShape}, md::Union{Cardinality,OutputMode}) =
    OutputShape(Decoration(label=lbl), dom, md)

function syntax(shp::OutputShape)
    args = []
    shp.dr.lbl == nothing || push!(args, QuoteNode(shp.dr.lbl))
    push!(args, shp.dom isa NativeShape ? shp.dom.ty : syntax(shp.dom))
    shp.md.card == x1to1 || push!(args, syntax(shp.md.card))
    Expr(:call, nameof(OutputShape), args...)
end

function sigsyntax(shp::OutputShape)
    ex =
        shp.md.card == x0toN ?
            Expr(:vect, sigsyntax(shp.dom)) :
            Expr(:vect, sigsyntax(shp.dom), syntax(shp.md.card))
    if shp.dr.lbl !== nothing && shp.dr.lbl != Symbol("")
        ex = Expr(:(=), shp.dr.lbl, ex)
    end
    ex
end

eltype(shp::OutputShape) =
    let ty = eltype(shp.dom)
        shp.md.card == x1to1 ?
            ty :
        shp.md.card == x0to1 ?
            Union{Missing,ty} :
            Vector{ty}
    end

decoration(shp::OutputShape) = shp.dr

label(shp::OutputShape) = label(shp.dr)

decorate(shp::OutputShape; kws...) =
    OutputShape(decorate(shp.dr; kws...), shp.dom, shp.md)

domain(shp::OutputShape) = shp.dom

mode(shp::OutputShape) = shp.md

cardinality(shp::OutputShape) = shp.md.card

isregular(shp::OutputShape) = isregular(shp.md)

isoptional(shp::OutputShape) = isoptional(shp.md)

isplural(shp::OutputShape) = isplural(shp.md)

"""
    InputMode(slots::Union{Nothing,Vector{Pair{Symbol,OutputShape}}},
              framed::Bool)

Comonadic constraints on the query input.

Parameter `slots` is a list of named query parameters and their shapes.

Parameter `framed` indicates if the query input is partitioned into frames.
"""
struct InputMode
    slots::Union{Nothing,Vector{Pair{Symbol,OutputShape}}}
    framed::Bool
end

let NO_SLOTS = Pair{Symbol,OutputShape}[]

    global InputMode

    InputMode(slots::Union{Vector{Pair{Symbol,OutputShape}}}) =
        InputMode(slots, false)

    InputMode(framed::Bool) =
        InputMode(NO_SLOTS, framed)

    InputMode() =
        InputMode(NO_SLOTS, false)
end

convert(::Type{InputMode}, slots::Vector{Pair{Symbol,OutputShape}}) =
    InputMode(slots)

syntax(md::InputMode) =
    if md.slots !== nothing && isempty(md.slots) && !md.framed
        Expr(:call, nameof(InputMode))
    elseif md.slots !== nothing && isempty(md.slots)
        Expr(:call, nameof(InputMode), md.framed)
    elseif md.slots !== nothing && !md.framed
        Expr(:call, nameof(InputMode), syntax(md.slots))
    else
        Expr(:call, nameof(InputMode), syntax(md.slots), md.framed)
    end

show(io::IO, md::InputMode) =
    print_expr(io, syntax(md))

slots(md::InputMode) = md.slots

isframed(md::InputMode) = md.framed

isfree(md::InputMode) = md.slots !== nothing && isempty(md.slots) && !md.framed

"""
    InputShape(::Decoration, ::AbstractShape, ::InputMode)

The shape of the input of a monadic query.
"""
struct InputShape <: AbstractShape
    dr::Decoration
    dom::AbstractShape
    md::InputMode
end

InputShape(dom::Union{Type,AbstractShape}) = InputShape(Decoration(), dom, InputMode())

InputShape(dr::Decoration, dom::Union{Type,AbstractShape}) = InputShape(dr, dom, InputMode())

InputShape(dom::Union{Type,AbstractShape}, md::Union{Vector{Pair{Symbol,OutputShape}},InputMode}) =
    InputShape(Decoration(), dom, md)

function syntax(shp::InputShape)
    args = []
    shp.dr.lbl == nothing || push!(args, syntax(shp.dr))
    push!(args, shp.dom isa NativeShape ? shp.dom.ty : syntax(shp.dom))
    isfree(shp.md) || push!(args, syntax(shp.md))
    Expr(:call, nameof(InputShape), args...)
end

function sigsyntax(shp::InputShape)
    ex = sigsyntax(shp.dom)
    if shp.md.slots === nothing
        ex = Expr(:tuple, ex, Expr(:(=), :(*), sigsyntax(OutputShape(NoneShape()))))
    elseif !isempty(shp.md.slots)
        ex = Expr(:tuple, ex, map(slot -> Expr(:(=), slot.first, sigsyntax(slot.second)), shp.md.slots)...)
    end
    if shp.md.framed
        ex = Expr(:vect, Expr(:(...), ex))
    end
    ex
end

eltype(shp::InputShape) =
    let ty = eltype(shp.dom)
        if shp.md.framed
            ty = Tuple{ty,Int}
        end
        if shp.md.slots !== nothing && !isempty(shp.md.slots)
            ty = Tuple{ty, Tuple{eltype.(last.(shp.md.slots))...}}
        end
        ty
    end

decoration(shp::InputShape) = shp.dr

label(shp::InputShape) = label(shp.dr)

decorate(shp::InputShape; kws...) =
    InputShape(decorate(shp.dr; kws...), shp.dom, shp.md)

domain(shp::InputShape) = shp.dom

mode(shp::InputShape) = shp.md

slots(shp::InputShape) = slots(shp.md)

isframed(shp::InputShape) = isframed(shp.md)

isfree(shp::InputShape) = isfree(shp.md)

"""
    NativeShape(::Type)

Shape of an atomic Julia value.
"""

struct NativeShape <: AbstractShape
    ty::Type
end

NativeShape(::Type{Any}) =
    AnyShape()

NativeShape(::Type{Union{}}) =
    NoneShape()

convert(::Type{AbstractShape}, ty::Type) =
    NativeShape(ty)

syntax(shp::NativeShape) =
    Expr(:call, nameof(NativeShape), shp.ty)

sigsyntax(shp::NativeShape) = shp.ty

eltype(shp::NativeShape) = shp.ty

"""
    RecordShape(flds::OutputShape...)

Shape of a record with the given fields.
"""
struct RecordShape <: AbstractShape
    flds::Vector{OutputShape}
end

RecordShape(itr::OutputShape...) =
    RecordShape(collect(OutputShape, itr))

syntax(shp::RecordShape) =
    Expr(:call, nameof(RecordShape), syntax.(shp.flds)...)

sigsyntax(shp::RecordShape) =
    Expr(:tuple, sigsyntax.(shp.flds)...)

eltype(shp::RecordShape) =
    let lbls = Symbol[let lbl = label(fld); lbl !== nothing ? lbl : Symbol("#$i") end for (i, fld) in enumerate(shp.flds)]
        NamedTuple{(lbls...,),Tuple{eltype.(shp.flds)...}}
    end

getindex(shp::RecordShape, ::Colon) = shp.flds

getindex(shp::RecordShape, i) = shp.flds[i]


#
# Shape lattice.
#

# Subshape relation.

fits(shp1::AbstractShape, shp2::AbstractShape) = false

fits(shp1::S, shp2::S) where {S<:AbstractShape} =
    shp1 == shp2

fits(::AbstractShape, ::AnyShape) = true

fits(::AnyShape, ::AnyShape) = true

fits(::NoneShape, ::AbstractShape) = true

fits(::NoneShape, ::AnyShape) = true

fits(::NoneShape, ::NoneShape) = true

fits(dr1::Decoration, dr2::Decoration) =
    dr2.lbl === nothing || dr1.lbl == Symbol("") || dr1.lbl == dr2.lbl

fits(md1::OutputMode, md2::OutputMode) =
    fits(md1.card, md2.card)

fits(shp1::OutputShape, shp2::OutputShape) =
    shp1 == shp2 || fits(shp1.dr, shp2.dr) && fits(shp1.dom, shp2.dom) && fits(shp1.md, shp2.md)

function fits(slots1::Vector{Pair{Symbol,OutputShape}}, slots2::Vector{Pair{Symbol,OutputShape}})
    j = 1
    for slot2 in slots2
        while j <= length(slots1) && slots1[j].first < slot2.first
            j += 1
        end
        if j > length(slots1) || slots1[j].first != slot2.first || !fits(slots1[j].second, slot2.second)
            return false
        end
    end
    return true
end

fits(md1::InputMode, md2::InputMode) =
    md1 == md2 ||
    md1.framed >= md2.framed && (md1.slots === nothing || md2.slots !== nothing && fits(md1.slots, md2.slots))

fits(shp1::InputShape, shp2::InputShape) =
    shp1 == shp2 || fits(shp1.dr, shp2.dr) && fits(shp1.dom, shp2.dom) && fits(shp1.md, shp2.md)

fits(shp1::NativeShape, shp2::NativeShape) =
    shp1.ty <: shp2.ty

fits(shp1::RecordShape, shp2::RecordShape) =
    shp1 == shp2 ||
    length(shp1.flds) == length(shp2.flds) && all(fits(fld1, fld2) for (fld1, fld2) in zip(shp1.flds, shp2.flds))

# Upper and lower bounds.

bound(::Type{<:AbstractShape}) = NoneShape()

ibound(::Type{<:AbstractShape}) = AnyShape()

bound(::AbstractShape, ::AbstractShape) = AnyShape()

ibound(::AbstractShape, ::AbstractShape) = NoneShape()

bound(::NoneShape, shp2::AbstractShape) = shp2

bound(shp1::AbstractShape, ::NoneShape) = shp1

bound(shp1::NoneShape, ::NoneShape) = shp1

ibound(::AnyShape, shp2::AbstractShape) = shp2

ibound(shp1::AbstractShape, ::AnyShape) = shp1

ibound(shp1::AnyShape, ::AnyShape) = shp1

bound(::Type{Decoration}) = Decoration(label=Symbol(""))

ibound(::Type{Decoration}) = Decoration()

bound(dr1::Decoration, dr2::Decoration) =
    dr1 == dr2 ? dr1 : Decoration(label=(dr1.lbl == Symbol("") || dr1.lbl == dr2.lbl ? dr2.lbl :
                                         dr2.lbl == Symbol("") ? dr1.lbl : nothing))

ibound(dr1::Decoration, dr2::Decoration) =
    dr1 == dr2 ? dr1 : Decoration(label=(dr1.lbl === nothing || dr1.lbl == dr2.lbl ? dr2.lbl :
                                         dr2.lbl === nothing ? dr1.lbl : Symbol("")))

bound(::Type{OutputMode}) = OutputMode(bound(Cardinality))

bound(md1::OutputMode, md2::OutputMode) =
    OutputMode(bound(md1.card, md2.card))

ibound(::Type{OutputMode}) = OutputMode(ibound(Cardinality))

ibound(md1::OutputMode, md2::OutputMode) =
    OutputMode(ibound(md1.card, md2.card))

bound(::Type{OutputShape}) =
    OutputShape(bound(Decoration), bound(AbstractShape), bound(OutputMode))

ibound(::Type{OutputShape}) =
    OutputShape(ibound(Decoration), ibound(AbstractShape), ibound(OutputMode))

bound(shp1::OutputShape, shp2::OutputShape) =
    shp1 == shp2 ? shp1 :
    OutputShape(bound(shp1.dr, shp2.dr), bound(shp1.dom, shp2.dom), bound(shp1.md, shp2.md))

ibound(shp1::OutputShape, shp2::OutputShape) =
    shp1 == shp2 ? shp1 :
    OutputShape(ibound(shp1.dr, shp2.dr), ibound(shp1.dom, shp2.dom), ibound(shp1.md, shp2.md))

function bound(slots1::Vector{Pair{Symbol,OutputShape}}, slots2::Vector{Pair{Symbol,OutputShape}})
    slots = Pair{Symbol,OutputShape}[]
    i = 1
    j = 1
    while i <= length(slots1) && j <= length(slots2)
        if slots1[i].first < slots2[j].first
            i += 1
        elseif slots1[i].first > slots2[j].first
            j += 1
        else
            if slots1[i].second == slots2[j].second
                push!(slots, slots1[i])
            else
                push!(slots, Pair{Symbol,OutputShape}(slots1[i].first, bound(slots1[i].second, slots2[j].second)))
            end
            i += 1
            j += 1
        end
    end
    slots
end

function ibound(slots1::Vector{Pair{Symbol,OutputShape}}, slots2::Vector{Pair{Symbol,OutputShape}})
    slots = Pair{Symbol,OutputShape}[]
    i = 1
    j = 1
    while i <= length(slots1) && j <= length(slots2)
        if slots1[i].first < slots2[j].first
            push!(slots, slots1[i])
            i += 1
        elseif slots1[i].first > slots2[j].first
            push!(slots, slots2[j])
            j += 1
        else
            if slots1[i].second ==  slots2[j].second
                push!(slots, slots1[i])
            else
                push!(slots, Pair{Symbol,OutputShape}(slots1[i].first, ibound(slots1[i].second, slots2[j].second)))
            end
            i += 1
            j += 1
        end
    end
    while i <= length(slots1)
        push!(slots, slots1[i])
        i += 1
    end
    while j <= length(slots2)
        push!(slots, slots2[j])
        j += 1
    end
    slots
end

bound(::Type{InputMode}) = InputMode(nothing, true)

bound(md1::InputMode, md2::InputMode) =
    md1 == md2 ? md1 :
    InputMode(md1.slots === nothing ? md2.slots :
              md2.slots === nothing ? md1.slots : bound(md1.slots, md2.slots),
              md1.framed && md2.framed)

ibound(::Type{InputMode}) = InputMode()

ibound(md1::InputMode, md2::InputMode) =
    md1 == md2 ? md1 :
    InputMode(md1.slots === nothing || md2.slots === nothing ? nothing : ibound(md1.slots, md2.slots),
              md1.framed || md2.framed)

bound(::Type{InputShape}) =
    InputShape(bound(Decoration), bound(AbstractShape), bound(InputMode))

ibound(::Type{InputShape}) =
    InputShape(ibound(Decoration), ibound(AbstractShape), ibound(InputMode))

bound(shp1::InputShape, shp2::InputShape) =
    shp1 == shp2 ? shp1 :
    InputShape(bound(shp1.dr, shp2.dr), bound(shp1.dom, shp2.dom), bound(shp1.md, shp2.md))

ibound(shp1::InputShape, shp2::InputShape) =
    shp1 == shp2 ? shp1 :
    InputShape(ibound(shp1.dr, shp2.dr), ibound(shp1.dom, shp2.dom), ibound(shp1.md, shp2.md))

bound(shp1::NativeShape, shp2::NativeShape) =
    shp1 == shp2 ? shp1 : NativeShape(typejoin(shp1.ty, shp2.ty))

ibound(shp1::NativeShape, shp2::NativeShape) =
        shp1 == shp2 ? shp1 : NativeShape(typeintersect(shp1.ty, shp2.ty))

bound(shp1::RecordShape, shp2::RecordShape) =
    shp1 == shp2 ? shp1 :
    length(shp1.flds) == length(shp2.flds) ?
        RecordShape(OutputShape[bound(fld1, fld2) for (fld1, fld2) in zip(shp1.flds, shp2.flds)]) :
        AnyShape()

ibound(shp1::RecordShape, shp2::RecordShape) =
    shp1 == shp2 ? shp1 :
    length(shp1.flds) == length(shp2.flds) ?
        RecordShape(OutputShape[ibound(fld1, fld2) for (fld1, fld2) in zip(shp1.flds, shp2.flds)]) :
        NoneShape()


#
# Signature of a query.
#

"""
    Signature(::InputShape, ::OutputShape)

Signature of a monadic query.
"""
struct Signature
    ishp::InputShape
    shp::OutputShape
end

let NO_ISHP = bound(InputShape),
    VOID_ISHP = InputShape(NativeShape(Nothing)),
    NO_SHP = ibound(OutputShape)

    global Signature

    Signature() = Signature(NO_ISHP, NO_SHP)

    Signature(shp::OutputShape) = Signature(VOID_ISHP, shp)
end

function sigsyntax(sig::Signature)
    iex = sigsyntax(sig.ishp)
    ex = sigsyntax(sig.shp)
    if iex !== :Nothing
        ex = Expr(:(->), iex, ex)
    end
    ex
end

show(io::IO, sig::Signature) =
    print_expr(io, sigsyntax(sig))

ishape(sig::Signature) = sig.ishp

shape(sig::Signature) = sig.shp

idecoration(sig::Signature) = decoration(sig.ishp)

idomain(sig::Signature) = domain(sig.ishp)

imode(sig::Signature) = mode(sig.ishp)

decoration(sig::Signature) = decoration(sig.shp)

domain(sig::Signature) = domain(sig.shp)

mode(sig::Signature) = mode(sig.shp)

isfree(sig::Signature) = isfree(sig.ishp)

isframed(sig::Signature) = isframed(sig.ishp)

slots(sig::Signature) = slots(sig.ishp)

cardinality(sig::Signature) = cardinality(sig.shp)

isregular(sig::Signature) = isregular(sig.shp)

isoptional(sig::Signature) = isoptional(sig.shp)

isplural(sig::Signature) = isplural(sig.shp)


#
# Guessing the shape of a vector.
#

shapeof(v::AbstractVector) =
    NativeShape(eltype(v))

function shapeof(tv::TupleVector)
    cols = columns(tv)
    if !all(col -> col isa BlockVector, cols)
        return NativeShape(eltype(tv))
    end
    lbls = labels(tv)
    fields = OutputShape[]
    for (j, col) in enumerate(cols)
        lbl = !isempty(lbls) ? lbls[j] : nothing
        dom = shapeof(elements(col))
        card = cardinality(col)
        shp = OutputShape(Decoration(label=lbl), dom, card)
        push!(fields, shp)
    end
    return RecordShape(fields)
end
