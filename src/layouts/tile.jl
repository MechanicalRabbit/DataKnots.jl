#
# Layout combinators, tiling, and rendering.
#

# Layout tree.

abstract type AbstractBlock end

struct Layout
    blk::AbstractBlock
    args::Vector{Layout}
end

struct TextBlock <: AbstractBlock
    text::String
end

struct HorizontalBlock <: AbstractBlock
end

struct VerticalBlock <: AbstractBlock
end

struct ChoiceBlock <: AbstractBlock
end

let NO_ARGS = Layout[],
    INDENTS = Layout[Layout(TextBlock(" " ^ i), NO_ARGS) for i = 1:DEFAULT_LINE_WIDTH]

    global literal, indent

    literal(str::String) =
        Layout(TextBlock(str), NO_ARGS)

    literal(sym::Symbol) =
        Layout(TextBlock(string(sym)), NO_ARGS)

    indent(i::Int) =
        1 <= i <= length(INDENTS) ? INDENTS[i] : Layout(TextBlock(" " ^ i), NO_ARGS)
end

# Visualization.

show(io::IO, lt::Layout) =
    pretty_print(io, tile(lt))

# Layout combinators.

function _flatten(T::Type{<:AbstractBlock}, args::Vector{Layout})
    if isempty(args) || all(!(arg.blk isa T) for arg in args)
        return _collapse(T, args)
    end
    args′ = Layout[]
    for arg in args
        if arg.blk isa T
            append!(args′, arg.args)
        else
            push!(args′, arg)
        end
    end
    return _collapse(T, args′)
end

function _collapse(T::Type{<:AbstractBlock}, args::Vector{Layout})
    if !(T <: HorizontalBlock)
        return Layout(T(), args)
    end
    args′ = Layout[]
    istext = false
    for arg in args
        if istext && arg.blk isa TextBlock
            args′[end] = literal(args′[end].blk.text * arg.blk.text)
        else
            push!(args′, arg)
        end
        istext = arg.blk isa TextBlock
    end
    length(args′) == 1 ?
        args′[1] : Layout(T(), length(args′) < length(args) ? args′ : args)
end

(*)(lt::Layout, lts::Layout...) =
    _flatten(HorizontalBlock, collect(Layout, (lt, lts...)))

(/)(lt::Layout, lts::Layout...) =
    _flatten(VerticalBlock, collect(Layout, (lt, lts...)))

(|)(lt::Layout, lts::Layout...) =
    _flatten(ChoiceBlock, collect(Layout, (lt, lts...)))

# Convert to a single-line layout.

function nobreaks(lt::Layout)
    if lt.blk isa VerticalBlock && length(lt.args) > 1
        return nothing
    end
    if isempty(lt.args)
        return lt
    end
    if lt.blk isa ChoiceBlock
        for arg in lt.args
            arg′ = nobreaks(arg)
            if arg′ !== nothing
                return arg′
            end
        end
        return nothing
    end
    same = true
    args′ = Layout[]
    for arg in lt.args
        arg′ = nobreaks(arg)
        if arg′ === nothing
            return nothing
        elseif arg′ == arg
            push!(args′, arg)
        else
            push!(args′, arg′)
            same = false
        end
    end
    if same
        lt
    else
        return _flatten(typeof(lt.blk), args′)
    end
end

function nobreaks(lts::Vector{Layout})
    lts′ = Layout[]
    for lt in lts
        lt′ = nobreaks(lt)
        if lt′ === nothing
            return nothing
        end
        push!(lts′, lt′)
    end
    lts′
end

# Fallback layout.

tile(obj) = literal(repr(obj))

# Layout for a function or an operator.

function tile(args::Vector{Layout};
              brk::Tuple{String,String}=("(", ")"),
              sep::Tuple{String,String,String}=(", ","", ","),
              tab::Int=4)
    if isempty(args)
        return literal("$(brk[1])$(brk[2])")
    end
    hd_lt, tl_lt = map(literal, brk)
    noc, nol, nor = map(isempty, sep)
    sepc_lt, sepl_lt, sepr_lt = map(literal, sep)
    tab_lt = indent(tab)
    vlt = args[1]
    for arg in args[2:end]
        vlt = (nor ? vlt : vlt * sepr_lt) / (nol ? arg : sepl_lt * arg)
    end
    vlt = (hd_lt | (hd_lt / tab_lt)) * vlt * tl_lt
    lt = vlt
    hargs = nobreaks(args)
    if hargs !== nothing
        hlt = hargs[1]
        for harg in hargs[2:end]
            hlt = noc ? hlt * harg : hlt * sepc_lt * harg
        end
        hlt = hd_lt * hlt * tl_lt
        lt = hlt | lt
    end
    return lt
end

# Layout of a key-value pair.

tile(pair::Pair; tab::Int=4) =
    let key_lt = tile(pair.first),
        val_lt = tile(pair.second),
        tab_lt = indent(tab)
        (key_lt * literal(" => ") | key_lt * literal(" =>") / tab_lt) * val_lt
    end

# Layout for sequences.

tile(xs::Vector) =
    tile(Layout[tile(x) for x in xs], brk=("[", "]"))

tile(xs::Tuple) =
    tile(Layout[tile(x) for x in xs])

tile(xs::NamedTuple; tab::Int=4) =
    let sepc_lt = literal(" = "),
        sepr_lt = literal(" ="),
        tab_lt = indent(tab)
        tile(Layout[let key_lt = literal(key),
                        val_lt = tile(val)
                        (key_lt * sepc_lt | key_lt * sepr_lt / tab_lt) * val_lt
                    end
                    for (key, val) in pairs(xs)])
    end

# Layout of the layout tree.

function tile(lt::Layout; precedence::Int=0)
    if lt.blk isa TextBlock
        text = lt.blk.text
        if length(text) > 0 && all(ch == ' ' for ch in text)
            literal("indent($(length(text)))")
        else
            literal("literal($(repr(text)))")
        end
    else
        precedence′ = lt.blk isa ChoiceBlock ? 0 : 1
        args = Layout[]
        first = true
        for arg in lt.args
            arg = tile(arg, precedence=(first ? precedence′ : precedence′ + 1))
            push!(args, arg)
            first = false
        end
        brk = precedence > precedence′ ? ("(", ")") : ("", "")
        sep = lt.blk isa HorizontalBlock ? (" * ", "* ", "") :
              lt.blk isa VerticalBlock ? (" / ", "/ ", "") :
              lt.blk isa ChoiceBlock ? (" | ", "| ", "") : ("", "", "")
        return tile(args, brk=brk, sep=sep)
    end
end

# Rendering.

render(io::IO, lt::Layout, col::Int=0) =
    render(io, lt.blk, lt.args, col)

function render(io::IO, blk::TextBlock, ::Vector{Layout}, col::Int)
    print(io, blk.text)
    col + length(blk.text)
end

function render(io::IO, ::HorizontalBlock, args::Vector{Layout}, col::Int)
    for arg in args
        col = render(io, arg, col)
    end
    col
end

function render(io::IO, ::VerticalBlock, args::Vector{Layout}, col::Int)
    nl = "\n" * " " ^ col
    col′ = col
    first = true
    for arg in args
        if !first
            print(io, nl)
        end
        col′ = render(io, arg, col)
        first = false
    end
    col′
end

render(io::IO, ::ChoiceBlock, args::Vector{Layout}, col::Int) =
    !isempty(args) ? render(io, args[1], col) : col

