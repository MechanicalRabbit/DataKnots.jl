#
# @Planar constructor.
#

macro Planar(sig, ex)
    ctor = sig2ctor(sig)
    ex = planarize(ctor, ex)
    return esc(ex)
end

function sig2ctor(sig)
    if sig isa Expr && sig.head == :tuple
        lbls = Symbol[]
        col_ctors = AbstractVectorConstructor[]
        for arg in sig.args
            if arg isa Expr && arg.head == :(=) && length(arg.args) == 2 && arg.args[1] isa Symbol
                push!(lbls, arg.args[1])
                push!(col_ctors, sig2ctor(arg.args[2]))
            else
                push!(col_ctors, sig2ctor(arg))
            end
        end
        return TupleVectorConstructor(lbls, col_ctors)
    elseif sig isa Expr && sig.head == :vect && length(sig.args) == 1
        elts_ctor = sig2ctor(sig.args[1])
        return BlockVectorConstructor(elts_ctor)
    elseif sig isa Expr && sig.head == :& && length(sig.args) == 1 && sig.args[1] isa Symbol
        ident = sig.args[1]
        return IndexVectorConstructor(ident)
    else
        ty = sig
        return VectorConstructor(ty)
    end
end

abstract type AbstractVectorConstructor end

mutable struct TupleVectorConstructor <: AbstractVectorConstructor
    lbls::Vector{Symbol}
    col_ctors::Vector{AbstractVectorConstructor}
    len::Int

    TupleVectorConstructor(lbls, col_ctors) = new(lbls, col_ctors, 0)
end

mutable struct BlockVectorConstructor <: AbstractVectorConstructor
    elts_ctor::AbstractVectorConstructor
    offs::Vector{Int}
    top::Int

    BlockVectorConstructor(elts_ctor) = new(elts_ctor, [1], 1)
end

mutable struct IndexVectorConstructor <: AbstractVectorConstructor
    ident::Symbol
    idxs::Vector{Any}

    IndexVectorConstructor(ident) = new(ident, [])
end

mutable struct VectorConstructor <: AbstractVectorConstructor
    ty::Any
    vals::Vector{Any}

    VectorConstructor(ty) = new(ty, [])
end

function planarize(ctor::AbstractVectorConstructor, ex)
    if ex isa Expr && ex.head == :where && length(ex.args) >= 1
        vec = planarize(ctor, ex.args[1])
        refs = Any[]
        for arg in ex.args[2:end]
            if arg isa Expr && arg.head == :(=) && length(arg.args) == 2 && arg.args[1] isa Symbol
                push!(refs, Expr(:call, :(=>), QuoteNode(arg.args[1]), arg.args[2]))
            else
                error("expected an assignment; got $(repr(arg))")
            end
        end
        return Expr(:call, CapsuleVector, vec, refs...)
    elseif ex isa Expr && (ex.head == :vect || ex.head == :vcat)
        for arg in ex.args
            rearrange!(ctor, arg)
        end
        return reconstruct(ctor)
    else
        error("expected a vector literal; got $(repr(ex))")
    end
end

function rearrange!(ctor::TupleVectorConstructor, ex)
    if ex isa Expr && (ex.head == :tuple || ex.head == :row)
        if length(ex.args) == length(ctor.col_ctors)
            for (j, (arg, col_ctor)) in enumerate(zip(ex.args, ctor.col_ctors))
                if arg isa Expr && arg.head == :(=) && length(arg.args) == 2
                    if j <= length(ctor.lbls) && arg.args[1] == ctor.lbls[j]
                        arg = arg.args[2]
                    elseif j < length(ctor.lbls)
                        error("expected label $(repr(ctor.lbls[j])); got $(repr(arg))")
                    else
                        error("expected no label; got $(repr(arg))")
                    end
                end
                rearrange!(col_ctor, arg)
            end
        else
            error("expected $(length(ctor.col_ctors)) column(s); got $(repr(ex))")
        end
        ctor.len += 1
    else
        error("expected a tuple or a row literal; got $(repr(ex))")
    end
end

function rearrange!(ctor::BlockVectorConstructor, ex)
    if ex isa Expr && (ex.head == :vect || ex.head == :vcat)
        for arg in ex.args
            rearrange!(ctor.elts_ctor, arg)
            ctor.top += 1
        end
    elseif ex !== :missing
        rearrange!(ctor.elts_ctor, ex)
        ctor.top += 1
    end
    push!(ctor.offs, ctor.top)
end

function rearrange!(ctor::IndexVectorConstructor, ex)
    push!(ctor.idxs, ex)
end

function rearrange!(ctor::VectorConstructor, ex)
    push!(ctor.vals, ex)
end

reconstruct(ctor::TupleVectorConstructor) =
    Expr(:call, TupleVector,
                ctor.lbls,
                ctor.len,
                Expr(:ref, AbstractVector, map(reconstruct, ctor.col_ctors)...))

reconstruct(ctor::BlockVectorConstructor) =
    Expr(:call, BlockVector, ctor.offs, reconstruct(ctor.elts_ctor))

reconstruct(ctor::IndexVectorConstructor) =
    Expr(:call, IndexVector, QuoteNode(ctor.ident), Expr(:vect, ctor.idxs...))

reconstruct(ctor::VectorConstructor) =
    Expr(:ref, ctor.ty, ctor.vals...)

