#
# XML parser.
#

struct XMLError <: Exception
    msg::String
    line::Int
    ctx::String
end

XMLError(msg, line, buf, spn) =
    XMLError(msg, line, SubString(buf, spn))

function _xml_text(buf, span, cache)
    us = UnsafeString(pointer(buf, first(span)), length(span))
    get!(() -> convert(String, us), cache, us)
end

function _xml_etext(buf, span)
    io = IOBuffer(maxsize=length(span))
    pos = first(span)
    while pos <= last(span)
        @inbounds c = codeunit(buf, pos)
        pos += 1
        if c == 0x26    # '&'
            if codeunit(buf, pos) == 0x61 && codeunit(buf, pos+1) == 0x6D && codeunit(buf, pos+2) == 0x70 && codeunit(buf, pos+3) == 0x3B   # 'a' 'm' 'p' ';'
                pos += 4
                write(io, '&')
            elseif codeunit(buf, pos) == 0x6C && codeunit(buf, pos+1) == 0x74 && codeunit(buf, pos+2) == 0x3B   # 'l' 't' ';'
                pos += 3
                write(io, '<')
            elseif codeunit(buf, pos) == 0x67 && codeunit(buf, pos+1) == 0x74 && codeunit(buf, pos+2) == 0x3B   # 'g' 't' ';'
                pos += 3
                write(io, '>')
            elseif codeunit(buf, pos) == 0x61 && codeunit(buf, pos+1) == 0x70 && codeunit(buf, pos+2) == 0x6F && codeunit(buf, pos+3) == 0x73 && codeunit(buf, pos+4) == 0x3B   # 'a' 'p' 'o' 's' ';'
                pos += 5
                write(io, '\'')
            elseif codeunit(buf, pos) == 0x71 && codeunit(buf, pos+1) == 0x75 && codeunit(buf, pos+2) == 0x6F && codeunit(buf, pos+3) == 0x74 && codeunit(buf, pos+4) == 0x3B   # 'q' 'u' 'o' 't' ';'
                pos += 5
                write(io, '"')
            elseif codeunit(buf, pos) == 0x23 && codeunit(buf, pos+1) == 0x78 && codeunit(buf, pos+2) != 0x3B   # '#' 'x'
                pos += 2
                @inbounds c = codeunit(buf, pos)
                pos += 1
                u = 0x00000000
                while c != 0x3B
                    d = if 0x30 <= c <= 0x39    # '0' .. '9'
                            c - 0x30
                        elseif 0x41 <= c <= 0x46    # 'a' .. 'f'
                            c - 0x41 + 0x0a
                        elseif 0x61 <= c <= 0x66    # 'a' .. 'f'
                            c - 0x61 + 0x0a
                        else
                            return false, ""
                        end
                    u = u << 4 + d
                    u <= 0x10FFFF || return false, ""
                    @inbounds c = codeunit(buf, pos)
                    pos += 1
                end
                write(io, Char(u))
            elseif codeunit(buf, pos) == 0x23 && codeunit(buf, pos+1) != 0x3B   # '#'
                pos += 1
                @inbounds c = codeunit(buf, pos)
                pos += 1
                u = 0x00000000
                while c != 0x3B
                    d = if 0x30 <= c <= 0x39    # '0' .. '9'
                            c - 0x30
                            return false, ""
                        end
                    u = u * 0x0A + d
                    u <= 0x10FFFF || return false, ""
                    @inbounds c = codeunit(buf, pos)
                    pos += 1
                end
                write(io, Char(u))
            else
                return false, ""
            end
        else
            write(io, c)
        end
    end
    return true, String(take!(io))
end

const _xml_name = _xml_text

_xml_cdata(buf, span) =
    unsafe_string(pointer(buf, first(span)+9), length(span)-12)

_xml_str(buf, span, cache) =
    _xml_text(buf, first(span)+1:last(span)-1, cache)

_xml_estr(buf, span) =
    _xml_etext(buf, first(span)+1:last(span)-1)

@enum XMLTokenType begin
    XML_END_TOK
    XML_COMMENT_TOK
    XML_INSTR_TOK
    XML_WS_TOK
    XML_TEXT_TOK
    XML_ETEXT_TOK
    XML_CDATA_TOK
    XML_OPEN_TOK
    XML_SOPEN_TOK
    XML_XOPEN_TOK
    XML_CLOSE_TOK
    XML_SCLOSE_TOK
    XML_NAME_TOK
    XML_EQ_TOK
    XML_STR_TOK
    XML_ESTR_TOK
end

struct XMLToken
    typ::XMLTokenType
    spn::UnitRange{Int}
end

_xml_nl(buf) =
    if occursin('\r', buf)
        replace(replace(buf, "\r\n" => '\n'), '\r' => '\n')
    else
        buf
    end

mutable struct XMLScanner
    buf::String
    pos::Int
    line::Int
    inside::Bool

    XMLScanner(buf) = new(_xml_nl(buf), 1, 1, false)
end

function _xml_peek!(s::XMLScanner, str::String)
    l = ncodeunits(str)
    if ncodeunits(s.buf) - s.pos + 1 >= l &&
       ccall(:memcmp, Int32, (Ptr{UInt8}, Ptr{UInt8}, UInt), pointer(s.buf, s.pos), pointer(str), l) == 0
        s.pos += l
        return true
    else
        return false
    end
end

function _xml_peek!(s::XMLScanner, ch::UInt8)
    if s.pos <= ncodeunits(s.buf)
        @inbounds c = codeunit(s.buf, s.pos)
        if c == ch
            s.pos += 1
            return true
        end
    end
    return false
end

function _xml_scan!(s::XMLScanner)
    z = ncodeunits(s.buf)
    s.pos <= z || return XMLToken(XML_END_TOK, s.pos:s.pos-1)
    @inbounds c = codeunit(s.buf, s.pos)
    if !s.inside
        if c == 0x3C    # '<'
            fst = s.pos
            s.pos += 1
            if _xml_peek!(s, 0x3F)   # '?'
                while !_xml_peek!(s, "?>")
                    s.pos <= z || throw(XMLError("unexpected EOF while parsing XML processing instruction", s.line, s.buf, fst:s.pos-1))
                    @inbounds c = codeunit(s.buf, s.pos)
                    s.pos += 1
                    if c == 0x09 || c == 0x0A || c == 0x0D || c == 0x20 # '\t' | '\n' | '\r' | ' '
                        if c == 0x0A
                            s.line += 1
                        end
                    elseif c <= 0x20     # ' '
                        throw(XMLError("unexpected character while parsing XML processing instruction", s.line, s.buf, fst:s.pos-1))
                    end
                end
                return XMLToken(XML_INSTR_TOK, fst:s.pos-1)
            elseif _xml_peek!(s, "!--")
                while true
                    s.pos <= z || throw(XMLError("unexpected EOF while parsing XML comment", s.line, s.buf, fst:s.pos-1))
                    @inbounds c = codeunit(s.buf, s.pos)
                    s.pos += 1
                    if c == 0x09 || c == 0x0A || c == 0x0D || c == 0x20 # '\t' | '\n' | '\r' | ' '
                        if c == 0x0A
                            s.line += 1
                        end
                    elseif c == 0x2D    # '-'
                        if _xml_peek!(s, "->")
                            break
                        elseif _xml_peek!(s, "-")
                            throw(XMLError("unexpected character while parsing XML comment", s.line, s.buf, fst:s.pos-1))
                        end
                    elseif c < 0x20     # ' '
                        throw(XMLError("unexpected character while parsing XML comment", s.line, s.buf, fst:s.pos-1))
                    end
                end
                return XMLToken(XML_COMMENT_TOK, fst:s.pos-1)
            elseif _xml_peek!(s, "![CDATA[")
                while true
                    s.pos <= z || throw(XMLError("unexpected EOF while parsing XML CDATA section", s.line, s.buf, fst:s.pos-1))
                    @inbounds c = codeunit(s.buf, s.pos)
                    s.pos += 1
                    if c == 0x09 || c == 0x0A || c == 0x0D || c == 0x20 # '\t' | '\n' | '\r' | ' '
                        if c == 0x0A
                            s.line += 1
                        end
                    elseif c == 0x5D    # ']'
                        if _xml_peek!(s, "]>")
                            break
                        end
                    elseif c < 0x20     # ' '
                        throw(XMLError("unexpected character while parsing XML comment", s.line, s.buf, fst:s.pos-1))
                    end
                end
                return XMLToken(XML_CDATA_TOK, fst:s.pos-1)
            elseif _xml_peek!(s, 0x21)   # '!'
                s.inside = true
                return XMLToken(XML_XOPEN_TOK, fst:s.pos-1)
            elseif _xml_peek!(s, 0x2F)   # '/'
                s.inside = true
                return XMLToken(XML_SOPEN_TOK, fst:s.pos-1)
            else
                s.inside = true
                return XMLToken(XML_OPEN_TOK, fst:s.pos-1)
            end
        else
            hastext = false
            hasentity = false
            fst = s.pos
            while c != 0x3C         # '<'
                s.pos += 1
                if c == 0x09 || c == 0x0A || c == 0x0D || c == 0x20 # '\t' | '\n' | '\r' | ' '
                    if c == 0x0A
                        s.line += 1
                    end
                elseif c == 0x26    # '&'
                    hasentity = true
                    s.pos <= z || throw(XMLError("unexpected EOF while parsing XML entity", s.line, s.buf, s.pos:s.pos-1))
                    @inbounds c = codeunit(s.buf, s.pos)
                    while c != 0x3B # ';'
                        if c > 0x20     # ' '
                            s.pos += 1
                        else
                            throw(XMLError("unexpected character while parsing XML entity", s.line, s.buf, s.pos:s.pos))
                        end
                        s.pos <= z || throw(XMLError("unexpected EOF while parsing XML entity", s.line, s.buf, s.pos:s.pos-1))
                        @inbounds c = codeunit(s.buf, s.pos)
                    end
                    s.pos += 1
                elseif c > 0x20     # ' '
                    hastext = true
                else
                    throw(XMLError("unexpected character while parsing XML data", s.line, s.buf, s.pos:s.pos))
                end
                s.pos <= z || break
                @inbounds c = codeunit(s.buf, s.pos)
            end
            return XMLToken(hasentity ? XML_ETEXT_TOK : hastext ? XML_TEXT_TOK : XML_WS_TOK, fst:s.pos-1)
        end
    else
        fst = s.pos
        if c == 0x3E    # '>'
            s.pos += 1
            s.inside = false
            return XMLToken(XML_CLOSE_TOK, fst:fst)
        elseif c == 0x2F    # '/'
            s.pos += 1
            if _xml_peek!(s, 0x3E)   # '>'
                s.inside = false
                return XMLToken(XML_SCLOSE_TOK, fst:s.pos-1)
            else
                throw(XMLError("unexpected character while parsing XML element", s.line, s.buf, fst:fst))
            end
        elseif c == 0x3D    # '='
            s.pos += 1
            return XMLToken(XML_EQ_TOK, fst:fst)
        elseif c == 0x22 || c == 0x27   # '"' | '\''
            d = c
            hasentity = false
            s.pos += 1
            s.pos <= z || throw(XMLError("unexpected EOF while parsing XML element", s.line, s.buf, fst:s.pos-1))
            @inbounds c = codeunit(s.buf, s.pos)
            s.pos += 1
            while c != d
                if c == 0x09 || c == 0x0A || c == 0x0D || c == 0x20 # '\t' | '\n' | '\r' | ' '
                    if c == 0x0A
                        s.line += 1
                    end
                elseif c == 0x26    # '&'
                    hasentity = true
                    s.pos <= z || throw(XMLError("unexpected EOF while parsing XML entity", s.line, s.buf, s.pos:s.pos-1))
                    @inbounds c = codeunit(s.buf, s.pos)
                    while c != 0x3B # ';'
                        if c > 0x20     # ' '
                            s.pos += 1
                        else
                            throw(XMLError("unexpected character while parsing XML entity", s.line, s.buf, s.pos:s.pos))
                        end
                        s.pos <= z || throw(XMLError("unexpected EOF while parsing XML entity", s.line, s.buf, s.pos:s.pos-1))
                        @inbounds c = codeunit(s.buf, s.pos)
                    end
                    s.pos += 1
                elseif c < 0x20     # ' '
                    throw(XMLError("unexpected character while parsing XML data", s.line, s.buf, s.pos:s.pos))
                end
                s.pos <= z || throw(XMLError("unexpected EOF while parsing XML element", s.line, s.buf, fst:s.pos-1))
                @inbounds c = codeunit(s.buf, s.pos)
                s.pos += 1
            end
            return XMLToken(hasentity ? XML_ESTR_TOK : XML_STR_TOK, fst:s.pos-1)
        elseif c == 0x09 || c == 0x0A || c == 0x0D || c == 0x20 # '\t' | '\n' | '\r' | ' '
            while c == 0x09 || c == 0x0A || c == 0x0D || c == 0x20
                if c == 0x0A
                    s.line += 1
                end
                s.pos += 1
                s.pos <= z || throw(XMLError("unexpected EOF while parsing XML element", s.line, s.buf, fst:s.pos-1))
                @inbounds c = codeunit(s.buf, s.pos)
            end
            return XMLToken(XML_WS_TOK, fst:s.pos-1)
        elseif c == 0x3A || c == 0x5F || 0x41 <= c <= 0x5A || 0x61 <= c <= 0x7A || c >= 0x80    # ':' | '_' | 'A' .. 'Z' | 'a' .. 'z'
            while c == 0x2D || c == 0x2E || c == 0x3A || c == 0x5F || 0x30 <= c <= 0x39 || 0x41 <= c <= 0x5A || 0x61 <= c <= 0x7A || c >= 0x80    # '-' | '.' | ':' | '_' | '0' .. '9' | 'A' .. 'Z' | 'a' .. 'z'
                s.pos += 1
                s.pos <= z || throw(XMLError("unexpected EOF while parsing XML element", s.line, s.buf, fst:s.pos-1))
                @inbounds c = codeunit(s.buf, s.pos)
            end
            return XMLToken(XML_NAME_TOK, fst:s.pos-1)
        end
    end
end


"""
    xml_parse()

Parses XML-formatted text.
"""
xml_parse() = Query(xml_parse)

function xml_parse(rt::Runtime, input::AbstractVector)
    eltype(input) <: AbstractString || error("expected a String vector; got $input at\n$(xml_parse())")

    len = 0
    doc_elts = Int[]
    root_elts = Int[]
    parent_offs = [1]
    parent_elts = Int[]
    tag_elts = String[]
    itext_elts = String[]
    otext_elts = String[]
    attrentry_offs = [1]
    attrkey_elts = String[]
    attrval_elts = String[]
    childsize_elts = Int[]
    strcache = Dict{UnsafeString,String}()
    chunks = String[]

    for data in input
        scanner = XMLScanner(data)
        root = len+1
        push!(doc_elts, root)
        parent_stk = Int[]
        parent_tag_stk = String[]
        previous = 0
        parent = 0
        parent_tag = ""

        tok = _xml_scan!(scanner)
        while tok.typ == XML_COMMENT_TOK || tok.typ == XML_INSTR_TOK || tok.typ == XML_WS_TOK || tok.typ == XML_XOPEN_TOK
            if tok.typ == XML_XOPEN_TOK
                tok = _xml_scan!(scanner)
                tok.typ == XML_NAME_TOK || throw(XMLError("expected XML name", scanner.line, scanner.buf, tok.spn))
                nm = _xml_name(scanner.buf, tok.spn, strcache)
                nm == "DOCTYPE" || throw(XMLError("expected DOCTYPE", scanner.line, scanner.buf, tok.spn))
                tok = _xml_scan!(scanner)
                tok.typ == XML_WS_TOK || throw(XMLError("expected XML whitespace", scanner.line, scanner.buf, tok.spn))
                tok = _xml_scan!(scanner)
                tok.typ == XML_NAME_TOK || throw(XMLError("expected XML name", scanner.line, scanner.buf, tok.spn))
                while tok.typ == XML_WS_TOK || tok.typ == XML_NAME_TOK || tok.typ == XML_STR_TOK || tok.typ == XML_ESTR_TOK
                    tok = _xml_scan!(scanner)
                end
                tok.typ == XML_CLOSE_TOK || throw(XMLError("expected '>'", scanner.line, scanner.buf, tok.spn))
            end
            tok = _xml_scan!(scanner)
        end

        tok.typ == XML_OPEN_TOK || throw(XMLError("expected '<'", scanner.line, scanner.buf, tok.spn))
        while true
            len += 1
            push!(root_elts, root)
            if parent != 0
                push!(parent_elts, parent)
                childsize_elts[parent] += 1
            end
            push!(childsize_elts, 0)
            push!(parent_offs, length(parent_elts)+1)
            tok = _xml_scan!(scanner)
            tok.typ == XML_NAME_TOK || throw(XMLError("expected XML name", scanner.line, scanner.buf, tok.spn))
            tag = _xml_name(scanner.buf, tok.spn, strcache)
            push!(tag_elts, tag)
            tok = _xml_scan!(scanner)
            tok.typ != XML_WS_TOK || (tok = _xml_scan!(scanner))
            while tok.typ == XML_NAME_TOK
                attrkey = _xml_name(scanner.buf, tok.spn, strcache)
                push!(attrkey_elts, attrkey)
                tok = _xml_scan!(scanner)
                tok.typ != XML_WS_TOK || (tok = _xml_scan!(scanner))
                tok.typ == XML_EQ_TOK || throw(XMLError("expected '='", scanner.line, scanner.buf, tok.spn))
                tok = _xml_scan!(scanner)
                tok.typ != XML_WS_TOK || (tok = _xml_scan!(scanner))
                tok.typ == XML_STR_TOK || tok.typ == XML_ESTR_TOK || throw(XMLError("expected XML string", scanner.line, scanner.buf, tok.spn))
                attrval =
                    if tok.typ == XML_STR_TOK
                        _xml_str(scanner.buf, tok.spn, strcache)
                    else
                        hastext, text = _xml_estr(scanner.buf, tok.spn)
                        hastext || throw(XMLError("invalid XML string", scanner.line, scanner.buf, tok.spn))
                        text
                    end
                push!(attrval_elts, attrval)
                tok = _xml_scan!(scanner)
                tok.typ != XML_WS_TOK || (tok = _xml_scan!(scanner))
            end
            push!(attrentry_offs, length(attrkey_elts)+1)
            push!(itext_elts, "")
            push!(otext_elts, "")
            tok.typ == XML_CLOSE_TOK || tok.typ == XML_SCLOSE_TOK || throw(XMLError("expected '>' or '/>'", scanner.line, scanner.buf, tok.spn))
            if tok.typ == XML_CLOSE_TOK
                previous = 0
                push!(parent_stk, parent)
                push!(parent_tag_stk, parent_tag)
                parent = len
                parent_tag = tag
            else
                previous = len
            end
            tok = _xml_scan!(scanner)
            while tok.typ == XML_WS_TOK || tok.typ == XML_TEXT_TOK || tok.typ == XML_ETEXT_TOK || tok.typ == XML_CDATA_TOK || tok.typ == XML_COMMENT_TOK || tok.typ == XML_SCLOSE_TOK
                while tok.typ == XML_WS_TOK || tok.typ == XML_TEXT_TOK || tok.typ == XML_ETEXT_TOK || tok.typ == XML_CDATA_TOK || tok.typ == XML_COMMENT_TOK
                    if tok.typ == XML_WS_TOK || tok.typ == XML_TEXT_TOK
                        push!(chunks, _xml_text(scanner.buf, tok.spn, strcache))
                    elseif tok.typ == XML_ETEXT_TOK
                        hastext, text = _xml_etext(scanner.buf, tok.spn)
                        hastext || throw(XMLError("invalid XML text", scanner.line, scanner.buf, tok.spn))
                        push!(chunks, text)
                    elseif tok.typ == XML_CDATA_TOK
                        push!(chunks, _xml_cdata(scanner.buf, tok.spn))
                    end
                    tok = _xml_scan!(scanner)
                end
                if !isempty(chunks)
                    text = length(chunks) == 1 ? chunks[1] : join(chunks)
                    if previous > 0
                        otext_elts[previous] = text
                    else
                        itext_elts[parent] = text
                    end
                    empty!(chunks)
                end
                if tok.typ == XML_SOPEN_TOK
                    tok = _xml_scan!(scanner)
                    tok.typ == XML_NAME_TOK || throw(XMLError("expected XML name", scanner.line, scanner.buf, tok.spn))
                    tag = _xml_name(scanner.buf, tok.spn, strcache)
                    tag == parent_tag || throw(XMLError("expected </$parent_tag>", scanner.line, scanner.buf, tok.spn))
                    tok = _xml_scan!(scanner)
                    tok.typ != XML_WS_TOK || (tok = _xml_scan!(scanner))
                    tok.typ == XML_CLOSE_TOK || throw(XMLError("expected '>'", scanner.line, scanner.buf, tok.spn))
                    tok = _xml_scan!(scanner)
                    previous = parent
                    parent = pop!(parent_stk)
                    parent_tag = pop!(parent_tag_stk)
                    if parent == 0
                        break
                    end
                end
            end
            if parent == 0
                break
            end
            tok.typ == XML_OPEN_TOK || throw(XMLError("expected '<'", scanner.line, scanner.buf, tok.spn))
        end

        while tok.typ == XML_COMMENT_TOK || tok.typ == XML_INSTR_TOK || tok.typ == XML_WS_TOK
            tok = _xml_scan!(scanner)
        end
        tok.typ == XML_END_TOK || throw(XMLError("expected EOF", scanner.line, scanner.buf, tok.spn))
    end

    childsize = sum(childsize_elts)
    child_offs = Vector{Int}(undef, len+1)
    child_elts = Vector{Int}(undef, childsize)
    @inbounds child_offs[1] = child_offs[2] = 1
    for val = 2:len
        @inbounds child_offs[val+1] = child_offs[val] + childsize_elts[val-1]
    end
    @inbounds for val = 1:len
        if parent_offs[val] == parent_offs[val+1]
            continue
        end
        parent = parent_elts[parent_offs[val]]
        child_elts[child_offs[parent+1]] = val
        child_offs[parent+1] += 1
    end

    ident = gensym("xml")
    xml = TupleVector(:root => BlockVector(:, IndexVector(ident, root_elts)),
                      :tag => BlockVector(:, tag_elts),
                      :parent => BlockVector(parent_offs, IndexVector(ident, parent_elts)),
                      :child => BlockVector(child_offs, IndexVector(ident, child_elts)),
                      :attr => BlockVector(attrentry_offs,
                                           TupleVector(:key => attrkey_elts,
                                                       :val => attrval_elts)),
                      :itext => BlockVector(:, itext_elts),
                      :otext => BlockVector(:, otext_elts))
    merge!(rt.refs, Pair{Symbol,AbstractVector}[ident => xml])
    return IndexVector(ident, doc_elts)
end

