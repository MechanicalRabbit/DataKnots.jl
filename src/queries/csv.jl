#
# CSV parser.
#

struct CSVError <: Exception
    msg::String
    line::Int
    ctx::String
end

CSVError(msg, line, buf, spn) =
    CSVError(msg, line, SubString(buf, spn))

@enum CSVTokenType begin
    CSV_END_TOK
    CSV_NL_TOK
    CSV_SEP_TOK
    CSV_LIT_TOK
    CSV_TEXT_TOK
    CSV_ETEXT_TOK
end

struct CSVToken
    typ::CSVTokenType
    spn::UnitRange{Int}
end

_csv_nl(buf) =
    if occursin('\r', buf)
        replace(buf, "\r\n" => "\n")
    else
        buf
    end

mutable struct CSVScanner
    buf::String
    pos::Int
    line::Int
    sep::UInt8
    quot::UInt8

    CSVScanner(buf; sep=0x2C #= ',' =#, quot=0x22 #= '"' =#) = new(_csv_nl(buf), 1, 1, sep, quot)
end

function _csv_scan!(s::CSVScanner)
    z = ncodeunits(s.buf)
    s.pos <= z || return CSVToken(CSV_END_TOK, s.pos:s.pos-1)
    @inbounds c = codeunit(s.buf, s.pos)
    fst = s.pos
    s.pos += 1
    if c == 0x0A    # '\n'
        s.line += 1
        return CSVToken(CSV_NL_TOK, fst:fst)
    elseif c == s.sep
        return CSVToken(CSV_SEP_TOK, fst:fst)
    elseif c == s.quot
        escaped = false
        s.pos <= z || throw(CSVError("unexpected EOF while parsing CSV string", s.line, s.buf, fst:s.pos-1))
        @inbounds c = codeunit(s.buf, s.pos)
        s.pos += 1
        while !(c == s.quot && (s.pos > z || codeunit(s.buf, s.pos) != s.quot))
            if c == s.quot
                escaped = true
                s.pos += 1
            end
            s.pos <= z || throw(CSVError("unexpected EOF while parsing CSV string", s.line, s.buf, fst:s.pos-1))
            @inbounds c = codeunit(s.buf, s.pos)
            s.pos += 1
        end
        return CSVToken(escaped ? CSV_ETEXT_TOK : CSV_TEXT_TOK, fst:s.pos-1)
    else
        if s.pos <= z
            @inbounds c = codeunit(s.buf, s.pos)
            while c >= 0x20 && c != s.sep && c != s.quot
                s.pos += 1
                s.pos <= z || break
                @inbounds c = codeunit(s.buf, s.pos)
            end
        end
        return CSVToken(CSV_LIT_TOK, fst:s.pos-1)
    end
end

function _csv_str(buf, (spn, raw), cache, quot)
    if raw
        us = UnsafeString(pointer(buf, first(spn)), length(spn))
        return get!(() -> convert(String, us), cache, us)
    else
        io = IOBuffer(maxsize=length(spn))
        pos = first(spn)
        while pos <= last(spn)
            @inbounds c = codeunit(buf, pos)
            pos += 1
            write(io, c)
            if c == quot
                pos += 1
            end
        end
        return String(take!(io))
    end
end

struct CSVFormat
    separator::Char
    quoting::Char
    labels::Vector{Symbol}
    header::Bool

    CSVFormat(; separator::Char=',', quoting::Char='"', labels::Vector{Symbol}=Symbol[], header::Bool=true) =
        new(separator, quoting, labels, header)
end

csv_parse(fmt::CSVFormat) =
    Query(csv_parse, fmt)

csv_parse(; kws...) =
    csv_parse(CSVFormat(; kws...))

function csv_parse(rt::Runtime, input::AbstractVector, fmt::CSVFormat)
    @assert length(input) == 1
    cache = Dict{UnsafeString,String}()
    cells = Tuple{UnitRange{Int},Bool}[]
    w = h = l = 0
    sep = convert(UInt8, fmt.separator)
    quot = convert(UInt8, fmt.quoting)
    for data in input
        scanner = CSVScanner(data; sep=sep, quot=quot)
        fst = true
        tok = _csv_scan!(scanner)
        while true
            if tok.typ == CSV_NL_TOK || tok.typ == CSV_END_TOK
                if l > 0
                    cell = ((first(tok.spn):first(tok.spn)-1), true)
                    push!(cells, cell)
                    l += 1
                    if fst
                        w = l
                        fst = false
                    else
                        w == l || throw(CSVError("unexpected record length while parsing CSV string", scanner.line, scanner.buf, tok.spn))
                    end
                    l = 0
                    h += 1
                end
                if tok.typ == CSV_END_TOK
                    break
                end
            elseif tok.typ == CSV_SEP_TOK
                cell = ((first(tok.spn):first(tok.spn)-1), true)
                push!(cells, cell)
                l += 1
            else
                spn = tok.typ == CSV_LIT_TOK ? tok.spn : (first(tok.spn)+1:last(tok.spn)-1)
                raw = tok.typ != CSV_ETEXT_TOK
                cell = (spn, raw)
                push!(cells, cell)
                l += 1
                tok = _csv_scan!(scanner)
                if tok.typ == CSV_NL_TOK || tok.typ == CSV_END_TOK
                    if fst
                        w = l
                        fst = false
                    else
                        w == l || throw(CSVError("unexpected record length while parsing CSV string", scanner.line, scanner.buf, tok.spn))
                    end
                    l = 0
                    h += 1
                    if tok.typ == CSV_END_TOK
                        break
                    else
                        continue
                    end
                elseif tok.typ != CSV_SEP_TOK
                    throw(CSVError("unexpected data while parsing CSV string", scanner.line, scanner.buf, tok.spn))
                end
            end
            tok = _csv_scan!(scanner)
        end
    end
    lbls =
        if isempty(fmt.labels)
            fmt.header ?
                [Symbol(_csv_str(input[1], cells[k], cache, quot)) for k = 1:w] :
                [Symbol("#$k") for k = 1:w]
        else
            length(fmt.labels) == w || throw(CSVError("unexpected number of columns", 1, input[1], 1:1))
            fmt.labels
        end
    st = fmt.header ? w : 0
    fn = w*(h-1)
    len = fmt.header ? h-1 : h
    cols = AbstractVector[]
    for k = 1:w
        rng = (st+k):w:(fn+k)
        sz = 0
        for i in rng
            spn, raw = cells[i]
            sz += !isempty(spn)
        end
        col =
            if sz == len
                vals = String[_csv_str(input[1], cells[i], cache, quot) for i in rng]
                BlockVector(:, vals)
            else
                offs = Vector{Int}(undef, len+1)
                vals = Vector{String}(undef, sz)
                offs[1] = top = 1
                j = 1
                for i in rng
                    spn, raw = cells[i]
                    if !isempty(spn)
                        vals[top] = _csv_str(input[1], (spn, raw), cache, quot)
                        top += 1
                    end
                    j += 1
                    offs[j] = top
                end
                BlockVector(offs, vals)
            end
        push!(cols, col)
    end
    tv = TupleVector(lbls, len, cols)
    return BlockVector([1, len+1], tv)
end

