#
# Formatting Julia expressions.
#

syntax(obj) =
    obj

syntax(s::Symbol) =
    QuoteNode(s)

function syntax(f::Function)
    s = nameof(f)
    if startswith(string(s), "#")
        ex = _reconstruct(f)
        if ex !== nothing
            s = ex
        end
    end
    s
end

syntax(f::Union{Function,Type}, args::Vector{Any}) =
    Expr(:call, nameof(f), syntax.(args)...)

syntax(::typeof(broadcast), args::Vector{Any}) =
    if length(args) >= 1 && args[1] isa Function
        syntax(broadcast, args[1], args[2:end])
    else
        Expr(:call, nameof(broadcast), syntax.(args)...)
    end

function syntax(::typeof(broadcast), f::Function, args::Vector{Any})
    ex = syntax(f)
    if ex isa Expr && ex.head == :(->) && length(ex.args) == 2
        names =
            if ex.args[1] isa Expr && ex.args[1].head == :tuple
                ex.args[1].args
            else
                [ex.args[1]]
            end
        repl = Dict(zip(names, args))
        return _broadcast(ex.args[2], repl)
    end
    return Expr(:(.), ex, Expr(:tuple, args...))
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

syntax(v::Vector) =
    Expr(:vect, syntax.(v)...)

tile_code(obj; precedence=0) =
    tile(obj)

tile_code(sym::Symbol; precedence=0) =
    literal(sym)

tile_code(qn::QuoteNode; precedence=0) =
    literal(string(qn))

function tile_code(ex::Expr; precedence=0)
    if ex.head == :call
        func = ex.args[1]
        if func isa Function
            func = nameof(func)
        end
        args = _flatten(func, ex.args[2:end])
        precedence′ = Base.operator_precedence(func)
        arg_lts = Layout[tile_code(arg, precedence=precedence′) for arg in args]
        if func == :(=>) && length(arg_lts) == 2
            key_lt, val_lt = arg_lts
            (key_lt * literal(" => ") | key_lt * literal(" =>") / indent(4)) * val_lt
        elseif precedence′ > 0
            sep = (" $func ", "$func ", "")
            brk =
                if precedence′ < precedence
                    ("(", ")")
                else
                    ("", "")
                end
            tile(arg_lts, brk=brk, sep=sep)
        else
            brk = ("$func(", ")")
            tile(arg_lts, brk=brk)
        end
    elseif ex.head == :vect
        tile(Layout[tile_code(arg) for arg in ex.args], brk=("[", "]"))
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
        if arg isa Expr && arg.head == :call && arg.args[1] == func
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
        if line isa Expr && line.head == :(=) && length(line.args) == 2 && line.args[1] isa Core.SSAValue
            ex = _reconstruct(line.args[2], ssa, info.slotnames)
            push!(ssa, ex)
        elseif line isa Expr && line.head == :return && length(line.args) == 1
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
    if ex isa Core.SSAValue
        ex = ssa[ex.id+1]
    elseif ex isa Core.SlotNumber
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

