#
# JSON parser.
#

struct UnsafeString
    ptr::Ptr{UInt8}
    len::Int
end

Base.convert(::Type{String}, us::UnsafeString) =
    unsafe_string(us.ptr, us.len)

function Base.hash(us::UnsafeString, h::UInt)
    h += Base.memhash_seed
    ccall(Base.memhash, UInt, (Ptr{UInt8}, Csize_t, UInt32), us.ptr, us.len, h % UInt32) + h
end

Base.:(==)(us1::UnsafeString, us2::UnsafeString) =
    us1.len == us2.len && ccall(:memcmp, Int32, (Ptr{UInt8}, Ptr{UInt8}, UInt), us1.ptr, us2.ptr, us1.len) == 0

function _json_str(buf, span, cache)
    us = UnsafeString(pointer(buf, first(span)+1), length(span)-2)
    get!(() -> convert(String, us), cache, us)
end

function _json_estr(buf, span)
    io = IOBuffer(maxsize=length(span)-2)
    pos = first(span) + 1
    while pos < last(span)
        @inbounds c = codeunit(buf, pos)
        pos += 1
        if c == 0x5C    # '\\'
            c = codeunit(buf, pos)
            pos += 1
            if c == 0x22 || c == 0x2F || c == 0x5C  # '"' | '/' | '\\'
                write(io, c)
            elseif c == 0x62    # 'b'
                write(io, '\b')
            elseif c == 0x66    # 'f'
                write(io, '\f')
            elseif c == 0x6E    # 'n'
                write(io, '\n')
            elseif c == 0x72    # 'r'
                write(io, '\r')
            elseif c == 0x74    # 't'
                write(io, '\t')
            elseif c == 0x75    # 'u'
                u = 0x0000
                for j = 1:4
                    pos < last(span) || return false, ""
                    @inbounds c = codeunit(buf, pos)
                    pos += 1
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
                end
                if u & 0xFC00 == 0xDC00 # low surrogate
                    return false, ""
                elseif u & 0xFC00 == 0xD800 # high surrogate
                    pos < last(span) || return false, ""
                    @inbounds c = codeunit(buf, pos)
                    pos += 1
                    c == 0x5C || return false, ""   # '\\'
                    pos < last(span) || return false, ""
                    @inbounds c = codeunit(buf, pos)
                    pos += 1
                    c == 0x75 || return false, ""   # 'u'
                    u′ = 0x0000
                    for j = 1:4
                        pos < last(span) || return false, ""
                        @inbounds c = codeunit(buf, pos)
                        pos += 1
                        d = if 0x30 <= c <= 0x39    # '0' .. '9'
                                c - 0x30
                            elseif 0x41 <= c <= 0x46    # 'a' .. 'f'
                                c - 0x41 + 0x0a
                            elseif 0x61 <= c <= 0x66    # 'a' .. 'f'
                                c - 0x61 + 0x0a
                            else
                                return false, ""
                            end
                        u′ = u′ << 4 + d
                    end
                    u′ & 0xFC00 == 0xDC00 || return false, ""   # low surrogate
                    write(io, Char(0x10000 + ((u & 0x003FF) << 10) + (u′ & 0x003FF)))
                else
                    write(io, Char(u))
                end
            else
                return false, ""
            end
        else
            write(io, c)
        end
    end
    return true, String(take!(io))
end

function _json_int(buf, span)
    sgn = 1
    pos = first(span)
    @inbounds c = codeunit(buf, pos)
    if c == 0x2D    # '-'
        sgn = -1
        pos += 1
    end
    val = 0
    while pos <= last(span)
        @inbounds c = codeunit(buf, pos)
        pos += 1
        val, over = Base.mul_with_overflow(val, 10)
        !over || return false, 0
        d = sgn * (c - 0x30)
        val, over = Base.add_with_overflow(val, d)
        !over || return false, 0
    end
    true, val
end

_json_float(buf, span) =
    ccall(:jl_try_substrtod, Tuple{Bool, Float64}, (Ptr{UInt8}, Csize_t, Csize_t), buf, first(span)-1, length(span))

struct JSONError <: Exception
    msg::String
    line::Int
    ctx::String
end

JSONError(msg, line, buf, spn) =
    JSONError(msg, line, SubString(buf, spn))

@enum JSONTokenType begin
    JSON_END_TOK
    JSON_LBRCKT_TOK
    JSON_RBRCKT_TOK
    JSON_LBRC_TOK
    JSON_RBRC_TOK
    JSON_COLON_TOK
    JSON_COMMA_TOK
    JSON_NULL_TOK
    JSON_TRUE_TOK
    JSON_FALSE_TOK
    JSON_INT_TOK
    JSON_FRAC_TOK
    JSON_STR_TOK
    JSON_ESTR_TOK
end

struct JSONToken
    typ::JSONTokenType
    spn::UnitRange{Int}
end

JSONToken(typ, ptr, len) =
    JSONToken(typ, UnsafeString(ptr, len))

mutable struct JSONScanner
    buf::String
    pos::Int
    line::Int

    JSONScanner(buf) = new(buf, 1, 1)
end

function _json_char!(s::JSONScanner, expect::UInt8)
    if s.pos <= ncodeunits(s.buf)
        @inbounds c = codeunit(s.buf, s.pos)
        s.pos += 1
        c == expect
    else
        false
    end
end

function _json_scan!(s::JSONScanner)
    z = ncodeunits(s.buf)
    s.pos <= z || return JSONToken(JSON_END_TOK, s.pos:s.pos-1)
    @inbounds c = codeunit(s.buf, s.pos)
    while c == 0x09 || c == 0x0A || c == 0x0D || c == 0x20  # '\t' | '\n' | '\r' | ' '
        s.pos += 1
        if c == 0x0A    # '\n'
            s.line += 1
        end
        s.pos <= z || return JSONToken(JSON_END_TOK, s.pos:s.pos-1)
        @inbounds c = codeunit(s.buf, s.pos)
    end
    fst = s.pos
    s.pos += 1
    if c == 0x2C        # ','
        return JSONToken(JSON_COMMA_TOK, fst:fst)
    elseif c == 0x3A    # ':'
        return JSONToken(JSON_COLON_TOK, fst:fst)
    elseif c == 0x5B    # '['
        return JSONToken(JSON_LBRCKT_TOK, fst:fst)
    elseif c == 0x5D    # ']'
        return JSONToken(JSON_RBRCKT_TOK, fst:fst)
    elseif c == 0x7B    # '{'
        return JSONToken(JSON_LBRC_TOK, fst:fst)
    elseif c == 0x7D    # '}'
        return JSONToken(JSON_RBRC_TOK, fst:fst)
    elseif c == 0x6E    # 'n'
        if _json_char!(s, 0x75) && _json_char!(s, 0x6C) && _json_char!(s, 0x6C) # 'u' 'l' 'l'
            return JSONToken(JSON_NULL_TOK, fst:s.pos-1)
        end
        throw(JSONError("ill-formed JSON value", s.line, s.buf, fst:s.pos-1))
    elseif c == 0x74    # 't'
        if _json_char!(s, 0x72) && _json_char!(s, 0x75) && _json_char!(s, 0x65) # 'r' 'u' 'e'
            return JSONToken(JSON_TRUE_TOK, fst:s.pos-1)
        end
        throw(JSONError("ill-formed JSON value", s.line, s.buf, fst:s.pos-1))
    elseif c == 0x66    # 'f'
        if _json_char!(s, 0x61) && _json_char!(s, 0x6C) && _json_char!(s, 0x73) && _json_char!(s, 0x65) # 'a' 'l' 's' 'e'
            return JSONToken(JSON_FALSE_TOK, fst:s.pos-1)
        end
        throw(JSONError("ill-formed JSON value", s.line, s.buf, fst:s.pos-1))
    elseif c == 0x22    # '"'
        escaped = false
        s.pos <= z || throw(JSONError("unexpected EOF while parsing JSON string", s.line, s.buf, fst:s.pos-1))
        @inbounds c = codeunit(s.buf, s.pos)
        s.pos += 1
        while c != 0x22 # '"'
            if c == 0x5C    # '\\'
                escaped = true
                s.pos <= z || throw(JSONError("unexpected EOF while parsing JSON string", s.line, s.buf, fst:s.pos-1))
                @inbounds c = codeunit(s.buf, s.pos)
                s.pos += 1
            end
            0x20 <= c || throw(JSONError("unexpected character while parsing JSON string", s.line, s.buf, fst:s.pos-1))
            s.pos <= z || throw(JSONError("unexpected EOF while parsing JSON string", s.line, s.buf, fst:s.pos-1))
            @inbounds c = codeunit(s.buf, s.pos)
            s.pos += 1
        end
        return JSONToken(escaped ? JSON_ESTR_TOK : JSON_STR_TOK, fst:s.pos-1)
    elseif c == 0x2D || 0x30 <= c <= 0x39   # '-' | '0' .. '9'
        fractional = false
        if c == 0x2D    # '-'
            s.pos <= z || throw(JSONError("unexpected EOF while parsing JSON number", s.line, s.buf, fst:s.pos-1))
            @inbounds c = codeunit(s.buf, s.pos)
            s.pos += 1
        end
        if c == 0x30    # '0'
            s.pos <= z || return JSONToken(JSON_INT_TOK, fst:s.pos-1)
            @inbounds c = codeunit(s.buf, s.pos)
        elseif 0x31 <= c <= 0x39    # '1' .. '9'
            s.pos <= z || return JSONToken(JSON_INT_TOK, fst:s.pos-1)
            @inbounds c = codeunit(s.buf, s.pos)
            while 0x30 <= c <= 0x39 # '0' .. '9'
                s.pos += 1
                s.pos <= z || return JSONToken(JSON_INT_TOK, fst:s.pos-1)
                @inbounds c = codeunit(s.buf, s.pos)
            end
        else
            throw(JSONError("unexpected character while parsing JSON number", s.line, s.buf, fst:s.pos-1))
        end
        if c == 0x2E    # '.'
            s.pos += 1
            fractional = true
            s.pos <= z || throw(JSONError("unexpected EOF while parsing JSON number", s.line, s.buf, fst:s.pos-1))
            @inbounds c = codeunit(s.buf, s.pos)
            if 0x30 <= c <= 0x39    # '0' .. '9'
                while 0x30 <= c <= 0x39 # '0' .. '9'
                    s.pos += 1
                    s.pos <= z || return JSONToken(JSON_FRAC_TOK, fst:s.pos-1)
                    @inbounds c = codeunit(s.buf, s.pos)
                end
            else
                throw(JSONError("unexpected character while parsing JSON number", s.line, s.buf, fst:s.pos-1))
            end
        end
        if c == 0x45 || c == 0x65   # 'E' | 'e'
            s.pos += 1
            fractional = true
            s.pos <= z || throw(JSONError("unexpected EOF while parsing JSON number", s.line, s.buf, fst:s.pos-1))
            @inbounds c = codeunit(s.buf, s.pos)
            if c == 0x2B || c == 0x2D   # '+' | '-'
                s.pos += 1
                s.pos <= z || throw(JSONError("unexpected EOF while parsing JSON number", s.line, s.buf, fst:s.pos-1))
                @inbounds c = codeunit(s.buf, s.pos)
            end
            if 0x30 <= c <= 0x39    # '0' .. '9'
                while 0x30 <= c <= 0x39 # '0' .. '9'
                    s.pos += 1
                    s.pos <= z || return JSONToken(JSON_FRAC_TOK, fst:s.pos-1)
                    @inbounds c = codeunit(s.buf, s.pos)
                end
            else
                throw(JSONError("unexpected character while parsing JSON number", s.line, s.buf, fst:s.pos-1))
            end
        end
        return JSONToken(fractional ? JSON_FRAC_TOK : JSON_INT_TOK, fst:s.pos-1)
    end
    throw(JSONError("unexpected character", s.line, s.buf, fst:fst))
end

@enum JSONType JSON_NULL JSON_BOOL JSON_INT JSON_FLOAT JSON_STRING JSON_ARRAY JSON_OBJECT

parse_json() = Query(parse_json)

function parse_json(rt::Runtime, input::AbstractVector)
    eltype(input) <: AbstractString || error("expected a String vector; got $input at\n$(parse_json())")

    len = 0
    doc_elts = Int[]
    root_elts = Int[]
    parent_offs = [1]
    parent_elts = Int[]
    idx_offs = [1]
    idx_elts = Int[]
    key_offs = [1]
    key_elts = String[]
    type_elts = JSONType[]
    bool_offs = [1]
    bool_elts = Bool[]
    int_offs = [1]
    int_elts = Int[]
    float_offs = [1]
    float_elts = Float64[]
    str_offs = [1]
    str_elts = String[]
    arrsize_elts = Int[]
    objsize_elts = Int[]
    strcache = Dict{UnsafeString,String}()

    for data in input
        scanner = JSONScanner(data)
        root = len+1
        push!(doc_elts, root)
        parent_stk = Int[]
        parent = 0
        push!(idx_offs, length(idx_elts)+1)
        push!(key_offs, length(key_elts)+1)
        tok = _json_scan!(scanner)
        while true
            comma = true
            len += 1
            push!(root_elts, root)
            if parent != 0
                push!(parent_elts, parent)
            end
            if tok.typ == JSON_NULL_TOK
                push!(type_elts, JSON_NULL)
            elseif tok.typ == JSON_TRUE_TOK || tok.typ == JSON_FALSE_TOK
                push!(type_elts, JSON_BOOL)
                push!(bool_elts, tok.typ == JSON_TRUE_TOK)
            elseif tok.typ == JSON_INT_TOK
                push!(type_elts, JSON_INT)
                has_intval, intval = _json_int(scanner.buf, tok.spn)
                has_floatval, floatval = _json_float(scanner.buf, tok.spn)
                has_intval && has_floatval || throw(JSONError("invalid JSON number", scanner.line, scanner.buf, tok.spn))
                push!(int_elts, intval)
                push!(float_elts, floatval)
            elseif tok.typ == JSON_FRAC_TOK
                push!(type_elts, JSON_FLOAT)
                has_floatval, floatval = _json_float(scanner.buf, tok.spn)
                has_floatval || throw(JSONError("invalid JSON number", scanner.line, scanner.buf, tok.spn))
                push!(float_elts, floatval)
            elseif tok.typ == JSON_STR_TOK || tok.typ == JSON_ESTR_TOK
                push!(type_elts, JSON_STRING)
                if tok.typ == JSON_STR_TOK
                    push!(str_elts, _json_str(scanner.buf, tok.spn, strcache))
                else
                    has_strval, strval = _json_estr(scanner.buf, tok.spn)
                    has_strval || throw(JSONError("invalid JSON string", scanner.line, scanner.buf, tok.spn))
                    push!(str_elts, strval)
                end
            elseif tok.typ == JSON_LBRCKT_TOK
                push!(type_elts, JSON_ARRAY)
                push!(parent_stk, parent)
                parent = len
                comma = false
            elseif tok.typ == JSON_LBRC_TOK
                push!(type_elts, JSON_OBJECT)
                push!(parent_stk, parent)
                parent = len
                comma = false
            else
                throw(JSONError("expected JSON value", scanner.line, scanner.buf, tok.spn))
            end
            push!(arrsize_elts, 0)
            push!(objsize_elts, 0)
            push!(parent_offs, length(parent_elts)+1)
            push!(bool_offs, length(bool_elts)+1)
            push!(int_offs, length(int_elts)+1)
            push!(float_offs, length(float_elts)+1)
            push!(str_offs, length(str_elts)+1)
            while true
                tok = _json_scan!(scanner)
                if parent == 0
                    tok.typ == JSON_END_TOK || throw(JSONError("expected EOF", scanner.line, scanner.buf, tok.spn))
                    break
                else
                    @inbounds parent_type = type_elts[parent]
                    if parent_type == JSON_ARRAY
                        if tok.typ == JSON_RBRCKT_TOK
                            @inbounds parent = pop!(parent_stk)
                            comma = true
                        else
                            if comma
                                tok.typ == JSON_COMMA_TOK || throw(JSONError("expected ','", scanner.line, scanner.buf, tok.spn))
                                tok = _json_scan!(scanner)
                            end
                            @inbounds idx = arrsize_elts[parent] += 1
                            push!(idx_elts, idx)
                            push!(idx_offs, length(idx_elts)+1)
                            push!(key_offs, length(key_elts)+1)
                            break
                        end
                    elseif parent_type == JSON_OBJECT
                        if tok.typ == JSON_RBRC_TOK
                            @inbounds parent = pop!(parent_stk)
                            comma = true
                        else
                            if comma
                                tok.typ == JSON_COMMA_TOK || throw(JSONError("expected ','", scanner.line, scanner.buf, tok.spn))
                                tok = _json_scan!(scanner)
                            end
                            @inbounds objsize_elts[parent] += 1
                            tok.typ == JSON_STR_TOK || tok.typ == JSON_ESTR_TOK || throw(JSONError("expected JSON string", scanner.line, scanner.buf, tok.spn))
                            key =
                                if tok.typ == JSON_STR_TOK
                                    _json_str(scanner.buf, tok.spn, strcache)
                                else
                                    has_strval, strval = _json_estr(scanner.buf, tok.spn)
                                    has_strval || throw(JSONError("invalid JSON string", scanner.line, scanner.buf, tok.spn))
                                    strval
                                end
                            push!(key_elts, key)
                            push!(idx_offs, length(idx_elts)+1)
                            push!(key_offs, length(key_elts)+1)
                            tok = _json_scan!(scanner)
                            tok.typ == JSON_COLON_TOK || throw(JSONError("expected ':'", scanner.line, scanner.buf, tok.spn))
                            tok = _json_scan!(scanner)
                            break
                        end
                    end
                end
            end
            if parent == 0
                break
            end
        end
    end

    arritem_sz = sum(arrsize_elts)
    objentry_sz = sum(objsize_elts)

    arritem_offs = Vector{Int}(undef, len+1)
    arritem_elts = Vector{Int}(undef, arritem_sz)

    objentry_offs = Vector{Int}(undef, len+1)
    objkey_elts = Vector{String}(undef, objentry_sz)
    objval_elts = Vector{Int}(undef, objentry_sz)

    @inbounds arritem_offs[1] = arritem_offs[2] = 1
    @inbounds objentry_offs[1] = objentry_offs[2] = 1
    for val = 2:len
        @inbounds arritem_offs[val+1] = arritem_offs[val] + arrsize_elts[val-1]
        @inbounds objentry_offs[val+1] = objentry_offs[val] + objsize_elts[val-1]
    end
    @inbounds for val = 1:len
        if parent_offs[val] == parent_offs[val+1]
            continue
        end
        parent = parent_elts[parent_offs[val]]
        if idx_offs[val] < idx_offs[val+1]
            arritem_elts[arritem_offs[parent+1]] = val
            arritem_offs[parent+1] += 1
        end
        if key_offs[val] < key_offs[val+1]
            key = key_elts[key_offs[val]]
            objkey_elts[objentry_offs[parent+1]] = key
            objval_elts[objentry_offs[parent+1]] = val
            objentry_offs[parent+1] += 1
        end
    end
    ident = gensym("json")
    json = TupleVector(:root => BlockVector(:, IndexVector(ident, root_elts)),
                       :parent => BlockVector(parent_offs, IndexVector(ident, parent_elts)),
                       :idx => BlockVector(idx_offs, idx_elts),
                       :key => BlockVector(key_offs, key_elts),
                       :type => BlockVector(:, type_elts),
                       :bool => BlockVector(bool_offs, bool_elts),
                       :int => BlockVector(int_offs, int_elts),
                       :float => BlockVector(float_offs, float_elts),
                       :str => BlockVector(str_offs, str_elts),
                       :array => BlockVector(arritem_offs, IndexVector(ident, arritem_elts)),
                       :object => BlockVector(objentry_offs,
                                              TupleVector(:key => BlockVector(:, objkey_elts),
                                                          :val => BlockVector(:, IndexVector(ident, objval_elts)))))
    return CapsuleVector(IndexVector(ident, doc_elts), ident => json)
end

