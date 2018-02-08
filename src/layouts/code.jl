#
# Formatting Julia expressions.
#

tile_code(obj; precedence=0) =
    tile(obj)

tile_code(sym::Symbol; precedence=0) =
    literal(sym)

tile_code(qn::QuoteNode; precedence=0) =
    literal(string(qn))

function tile_code(ex::Expr; precedence=0)
    if ex.head == :call
        func = ex.args[1]
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
    else
        literal(string(ex))
    end
end

function _flatten(func::Symbol, args)
    if !(func == :(>>) || func == :(|>))
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

