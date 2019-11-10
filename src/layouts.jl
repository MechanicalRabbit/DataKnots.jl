#
# Formatting Julia expressions.
#

using PrettyPrinting:
    Layout,
    indent,
    list_layout,
    literal,
    pair_layout,
    pprint,
    tile

print_expr(io::IO, ex) =
    pprint(io, tile_expr(ex))

quoteof_auto(@nospecialize(obj)) =
    Expr(:call, nameof(typeof(obj)), (quoteof(getfield(obj, i)) for i = 1:nfields(obj))...)

quoteof(@nospecialize(obj)) =
    obj

quoteof_inner(obj) =
    quoteof(obj)

quoteof(ref::Base.RefValue) =
    quoteof(ref.x)

quoteof(s::Symbol) =
    QuoteNode(s)

function quoteof(f::Function)
    s = nameof(f)
    if startswith(string(s), "#")
        ex = _reconstruct(f)
        if ex !== nothing
            s = ex
        end
    end
    s
end

quoteof(f::Union{Function,Type}, args::Vector{Any}) =
    Expr(:call, nameof(f), quoteof.(args)...)

quoteof(::typeof(broadcast), args::Vector{Any}) =
    if length(args) >= 1 && args[1] isa Function
        quoteof(broadcast, args[1], args[2:end])
    else
        Expr(:call, nameof(broadcast), quoteof.(args)...)
    end

function quoteof(::typeof(broadcast), f::Function, args::Vector{Any})
    ex = quoteof(f)
    if Meta.isexpr(ex, :(->), 2)
        names =
            if Meta.isexpr(ex.args[1], :tuple)
                ex.args[1].args
            else
                [ex.args[1]]
            end
        repl = Dict(zip(names, args))
        return _broadcast(ex.args[2], repl)
    end
    if ex isa Symbol && Base.operator_precedence(ex) > 0
        return Expr(:call, Symbol(".$ex"), args...)
    else
        return Expr(:(.), ex, Expr(:tuple, args...))
    end
end

function _broadcast(ex, repl)
    if ex isa Symbol
        if ex in keys(repl)
            ex = repl[ex]
        end
    elseif ex isa Expr
        ex = Expr(ex.head, (_broadcast(arg, repl) for arg in ex.args)...)
        if ex.head == :call && length(ex.args) >= 1 && ex.args[1] isa Symbol
            func = ex.args[1]
            ex =
                if Base.operator_precedence(func) > 0
                    func = Symbol(".$func")
                    Expr(ex.head, func, ex.args[2:end]...)
                else
                    Expr(:(.), func, Expr(:tuple, ex.args[2:end]...))
                end
        end
    end
    ex
end

quoteof(v::Vector) =
    Expr(:vect, quoteof.(v)...)

quoteof(p::Pair) =
    Expr(:call, :(=>), quoteof(p.first), quoteof(p.second))

quoteof(d::Dict) =
    Expr(:call, :Dict, quoteof.(collect(d))...)

tile_expr(obj; precedence=0) =
    tile(obj)

tile_expr(sym::Symbol; precedence=0) =
    literal(sym)

tile_expr(qn::QuoteNode; precedence=0) =
    literal(string(qn))

function tile_expr(ex::Expr; precedence=0)
    if ex.head == :call
        func = ex.args[1]
        if func isa Function
            func = nameof(func)
        end
        args = _flatten(func, ex.args[2:end])
        precedence′ = Base.operator_precedence(func)
        arg_lts = Layout[tile_expr(arg, precedence=precedence′) for arg in args]
        if func == :(=>) && length(arg_lts) == 2
            key_lt, val_lt = arg_lts
            pair_layout(key_lt, val_lt)
        elseif precedence′ > 0
            sep = func == :(:) ? "$func" : " $func "
            par =
                if precedence′ < precedence
                    ("(", ")")
                else
                    ("", "")
                end
            if length(arg_lts) == 1
                literal(par[1]) *
                literal(sep) *
                arg_lts[1] *
                literal(par[2])
            elseif length(arg_lts) == 2
                literal(par[1]) *
                pair_layout(arg_lts..., sep=sep, tab=0) *
                literal(par[2])
            else
                list_layout(arg_lts, par=par, sep=sep)
            end
        else
            par = ("$func(", ")")
            list_layout(arg_lts, par=par)
        end
    elseif ex.head == :tuple
        list_layout(Layout[tile_expr(arg) for arg in ex.args])
    elseif ex.head == :vect
        list_layout(Layout[tile_expr(arg) for arg in ex.args], par=("[", "]"))
    elseif ex.head == :ref && length(ex.args) >= 1
        tile_expr(ex.args[1]) *
        list_layout(Layout[tile_expr(arg) for arg in ex.args[2:end]], par=("[", "]"))
    elseif ex.head in (:(=), :(->), :(<:)) && length(ex.args) == 2
        ilt = tile_expr(ex.args[1])
        olt = tile_expr(ex.args[2])
        pair_layout(ilt, olt, sep=(ex.head == :(<:) ? "$(ex.head)" : " $(ex.head) "))
    elseif ex.head == :(...) && length(ex.args) == 1
        tile_expr(ex.args[1]) * literal("...")
    else
        literal(string(ex))
    end
end

function _flatten(func, args)
    if !(func === :(>>) || func === :(|>))
        return args
    end
    args′ = []
    for arg in args
        if Meta.isexpr(arg, :call) && arg.args[1] == func
            append!(args′, _flatten(func, arg.args[2:end]))
        else
            push!(args′, arg)
        end
    end
    args′
end

function _reconstruct(f::Function)
    infos = code_lowered(f)
    if length(infos) != 1
        return
    end
    info = infos[1]
    ssa = []
    for line in info.code
        if line === nothing
            continue
        end
        if Meta.isexpr(line, :call)
            ex = _reconstruct(line, ssa, info.slotnames)
            push!(ssa, ex)
        elseif Meta.isexpr(line, :return, 1)
            body = _reconstruct(line.args[1], ssa, info.slotnames)
            if body === nothing
                return
            end
            args = [(startswith(string(n), "#") ? Symbol("_$i") : n) for (i, n) in enumerate(info.slotnames[2:end])]
            return Expr(:(->), length(args) == 1 ? args[1] : Expr(:tuple, args...), body)
        else
            return
        end
    end
    return
end

function _reconstruct(ex, ssa, slots)
    if ex isa Core.SSAValue && checkbounds(Bool, ssa, ex.id)
        ex = ssa[ex.id]
    elseif ex isa Core.SlotNumber && checkbounds(Bool, slots, ex.id)
        s = slots[ex.id]
        if startswith(string(s), "#")
            s = Symbol("_$(ex.id-1)")
        end
        ex = s
    elseif ex isa GlobalRef
        ex = ex.name
    elseif ex isa Expr
        ex = Expr(ex.head, (_reconstruct(arg, ssa, slots) for arg in ex.args)...)
    end
    return ex
end

