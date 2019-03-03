#
# DataKnot definition and operations.
#

import Base:
    convert,
    get,
    show


#
# Definition.
#

"""
    DataKnot(cell::AbstractVector, shp::AbstractShape)

Encapsulates a data point in a column-oriented form.
"""
struct DataKnot
    cell::AbstractVector
    shp::AbstractShape

    function DataKnot(cell::AbstractVector, shp::AbstractShape)
        @assert length(cell) == 1
        #@assert fits(shapeof(cell), shp)
        new(cell, shp)
    end
end

DataKnot(elts::AbstractVector, card::Cardinality=x0toN) =
    DataKnot(BlockVector([1, length(elts)+1], elts, card), BlockOf(shapeof(elts), card))

DataKnot(::Missing) =
    DataKnot(Union{}[], x0to1)

DataKnot(ref::Base.RefValue{T}) where {T} =
    DataKnot(T[ref.x], ValueOf(T))

DataKnot(elt::T) where {T} =
    DataKnot(T[elt], ValueOf(T))

DataKnot() = DataKnot(nothing)

convert(::Type{DataKnot}, db::DataKnot) = db

convert(::Type{DataKnot}, val) = DataKnot(val)

get(db::DataKnot) = db.cell[1]

cell(db::DataKnot) = db.cell

shape(db::DataKnot) = db.shp

quoteof(db::DataKnot) =
    Symbol("DataKnot( … )")


#
# Rendering.
#

function show(io::IO, db::DataKnot)
    maxy, maxx = displaysize(io)
    lines = render_dataknot(maxx, maxy, db)
    for line in lines
        println(io, line)
    end
end

function render_dataknot(maxx::Int, maxy::Int, db::DataKnot)
    d = table_data(db, maxy)
    l = table_layout(d, maxx)
    c = table_draw(l, maxx)
    return lines!(c)
end

struct TableData
    head::Array{Tuple{String,Int},2}
    body::TupleVector
    flds::Vector{AbstractShape}
    idxs::AbstractVector{Int}
    tear::Int
end

TableData(head, body, flds) =
    TableData(head, body, flds, 1:0, 0)

function table_data(db::DataKnot, maxy::Int)
    shp = shape(db)
    title = ""
    if shp isa HasLabel
        title = String(label(shp))
        shp = subject(shp)
    end
    head = fill((title, 1), (title != "" ? 1 : 0, 1))
    body = TupleVector(1, AbstractVector[cell(db)])
    flds = AbstractShape[shp]
    d = TableData(head, body, flds)
    return _data_tear(_default_header(_data_focus(d, 1)), maxy)
end

_data_focus(d::TableData, pos) =
    _focus_tuple(_focus_block(d, pos), pos)

function _focus_block(d::TableData, pos::Int)
    col_fld = _prepare_focus_block(column(d.body, pos), d.flds[pos])
    col_fld !== nothing || return d
    col, fld = col_fld
    offs = offsets(col)
    elts = elements(col)
    perm = Vector{Int}(undef, length(elts))
    l = r = 1
    @inbounds for k = 1:length(col)
        l = r
        r = offs[k+1]
        for n = l:r-1
            perm[n] = k
        end
    end
    cols′ = copy(columns(d.body))
    for i in eachindex(cols′)
        cols′[i] =
            if i == pos
                elts
            else
                cols′[i][perm]
            end
    end
    body′ = TupleVector(length(elts), cols′)
    flds′ = copy(d.flds)
    flds′[pos] = fld[]
    idxs′ = !isempty(d.idxs) ? d.idxs[perm] :
            !issingular(cardinality(fld)) ? (1:length(elts)) : (1:0)
    return TableData(d.head, body′, flds′, idxs′, 0)
end

_prepare_focus_block(col::BlockVector, shp::BlockOf) =
    (col, shp)

_prepare_focus_block(col::AbstractVector, shp::AbstractShape) =
    nothing

function _focus_tuple(d::TableData, pos::Int)
    col_fld = _prepare_focus_tuple(column(d.body, pos), d.flds[pos])
    col_fld !== nothing || return d
    col, fld = col_fld
    cw = max(1, width(col))
    hh, hw = size(d.head)
    hh′ = hh + 1
    hw′ = hw + cw - 1
    head′ = fill(("", 0), (hh′, hw′))
    for row = 1:hh
        for col = 1:hw
            col′ = (col <= pos) ? col : col + cw - 1
            (text, span) = d.head[row, col]
            span′ = (col + span - 1 < pos || col > pos) ? span : span + cw - 1
            head′[row, col′] = (text, span′)
        end
    end
    for col = 1:hw
        col′ = (col <= pos) ? col : col + cw - 1
        head′[hh′, col′] = ("", 1)
    end
    for k = 1:cw
        col′ = pos + k - 1
        text = String(label(fld, k))
        head′[hh′, col′] = (text, 1)
    end
    cols′ = copy(columns(d.body))
    splice!(cols′, pos:pos, width(col) > 0 ? columns(col) : [BlockVector(fill(1, length(col)+1), Union{}[], x0to1)])
    body′ = TupleVector(length(d.body), cols′)
    flds′ = copy(d.flds)
    splice!(flds′, pos:pos, width(col) > 0 ? columns(fld) : [NoShape()])
    return TableData(head′, body′, flds′, d.idxs, d.tear)
end

_prepare_focus_tuple(col::TupleVector, shp::TupleOf) =
    width(shp) > 0 ? (col, shp) : nothing

function _prepare_focus_tuple(v::AbstractVector, shp::ValueOf)
    ty = eltype(shp)
    ty <: NamedTuple || return nothing
    lbls = collect(Symbol, ty.parameters[1])
    length(lbls) > 0 || return nothing
    shps = AbstractShape[]
    cols = AbstractVector[]
    for j = 1:length(lbls)
        cty = ty.parameters[2].parameters[j]
        push!(shps, ValueOf(cty))
        col = cty[e[j] for e in v]
        push!(cols, col)
    end
    return (TupleVector(lbls, length(v), cols), TupleOf(lbls, shps))
end

_prepare_focus_tuple(::AbstractVector, AbstractShape) =
    nothing

function _default_header(d::TableData)
    hh, hw = size(d.head)
    hh == 0 && hw > 0 || return d
    head′ = fill(("", 0), (1, hw))
    head′[1, 1] = ("It", hw)
    return TableData(head′, d.body, d.flds, d.idxs, d.tear)
end

function _data_tear(d::TableData, maxy::Int)
    L = length(d.body)
    avail = max(3, maxy - size(d.head, 1) - 4)
    avail < L || return d
    tear = avail ÷ 2
    perm = [1:tear; L-avail+tear+2:L]
    body′ = d.body[perm]
    idxs′ = !isempty(d.idxs) ? d.idxs[perm] : d.idxs
    return TableData(d.head, body′, d.flds, idxs′, tear)
end

struct TableCell
    text::String
    align::Int
end

TableCell() = TableCell("", 0)

TableCell(text) = TableCell(text, 0)

struct TableLayout
    cells::Array{TableCell,2}
    sizes::Vector{Tuple{Int,Int}}
    idxs_cols::Int
    head_rows::Int
    tear_row::Int

    TableLayout(w, h, idxs_cols, head_rows, tear_row) =
        new(fill(TableCell(), (h, w)), fill((0, 0), w), idxs_cols, head_rows, tear_row)
end

function table_layout(d::TableData, maxx::Int)
    w = (!isempty(d.idxs)) + width(d.body)
    h = size(d.head, 1) + length(d.body)
    idxs_cols = 0 + (!isempty(d.idxs))
    head_rows = size(d.head, 1)
    tear_row = d.tear > 0 ? head_rows + d.tear : 0
    l = TableLayout(w, h, idxs_cols, head_rows, tear_row)
    populate_body!(d, l, maxx)
    populate_head!(d, l)
    l
end

function populate_body!(d::TableData, l::TableLayout, maxx::Int)
    col = 1
    avail = maxx
    if !isempty(d.idxs)
        avail = populate_column!(l, col, ValueOf(Int), d.idxs, avail)
        col += 1
    end
    for (fld, vals) in zip(d.flds, columns(d.body))
        if avail < 0
            break
        end
        avail = populate_column!(l, col, fld, vals, avail)
        col += 1
    end
end

function populate_column!(l::TableLayout, col::Int, dom::AbstractShape, vals::AbstractVector, avail::Int)
    row = l.head_rows + 1
    sz = 0
    rsz = 0
    for i in eachindex(vals)
        l.cells[row,col] = cell = render_cell(dom, vals, i, avail)
        tw = textwidth(cell.text)
        if cell.align > 0
            rtw = textwidth(cell.text[end-cell.align+2:end])
            ltw = tw - rtw
            lsz = max(sz - rsz, ltw)
            rsz = max(rsz, rtw)
            sz = lsz + rsz
        else
            sz = max(sz, tw)
        end
        row += 1
    end
    l.sizes[col] = (sz, rsz)
    return avail - sz - 2
end

function populate_head!(d::TableData, l::TableLayout)
    for row = size(d.head, 1):-1:1
        for col = 1:size(d.head, 2)
            (text, span) = d.head[row,col]
            if isempty(text)
                continue
            end
            col += l.idxs_cols
            text = escape_string(text)
            l.cells[row,col] = TableCell(text)
            tw = textwidth(text)
            avail = sum(l.sizes[k][1] + 2 for k = col:col+span-1) - 2
            if avail < tw
                extra = 1 + (tw - avail - 1) ÷ span
                k = col
                while avail < tw
                    l.sizes[k] = (l.sizes[k][1] + extra, l.sizes[k][2])
                    avail += extra
                    k += 1
                end
            end
        end
    end
end

function render_cell(shp::TupleOf, vals::AbstractVector, idx::Int, avail::Int)
    buf = IOBuffer()
    comma = false
    for i in eachindex(columns(shp))
        if comma
            print(buf, ", ")
            avail -= 2
            comma = false
        end
        cell = render_cell(shp[i], column(vals, i), idx, avail)
        print(buf, cell.text)
        avail -= textwidth(cell.text)
        if avail < 0
            break
        end
        if !isempty(cell.text)
            comma = true
        end
    end
    return TableCell(String(take!(buf)))
end

function render_cell(::ValueOf, vals::AbstractVector{<:Union{Tuple,NamedTuple}}, idx::Int, avail::Int)
    ty = eltype(vals)
    w = length(ty <: Tuple ? ty.parameters : ty.parameters[2].parameters)
    buf = IOBuffer()
    comma = false
    for i in 1:w
        if comma
            print(buf, ", ")
            avail -= 2
            comma = false
        end
        val = vals[idx][i]
        cell = render_cell(typeof(val), val, avail)
        print(buf, cell.text)
        avail -= textwidth(cell.text)
        if avail < 0
            break
        end
        if !isempty(cell.text)
            comma = true
        end
    end
    return TableCell(String(take!(buf)))
end

function render_cell(shp::BlockOf, vals::AbstractVector, idx::Int, avail::Int)
    offs = offsets(vals)
    elts = elements(vals)
    l = offs[idx]
    r = offs[idx+1]-1
    if l > r
        return TableCell()
    elseif fits(x1toN, cardinality(shp))
        buf = IOBuffer()
        comma = false
        for k = l:r
            if comma
                print(buf, "; ")
                avail -= 2
                comma = false
            end
            cell = render_cell(shp[], elts, k, avail)
            print(buf, cell.text)
            avail -= textwidth(cell.text)
            if avail < 0
                break
            end
            if !isempty(cell.text)
                comma = true
            end
        end
        return TableCell(String(take!(buf)))
    else
        return render_cell(shp[], elts, l, avail)
    end
end

render_cell(shp::ValueOf, vals::AbstractVector, idx::Int, avail::Int) =
    render_cell(shp.ty, vals[idx], avail)

const render_context = :compact => true

function render_cell(::Type, val, avail::Int)
    buf = IOBuffer()
    io = IOContext(buf, :compact => true, :limit => true)
    print(io, val)
    text = escape_string(String(take!(buf)))
    return TableCell(text)
end

render_cell(::Type{Nothing}, ::Nothing, ::Int) =
    TableCell("")

function render_cell(::Type{<:Integer}, val, avail::Int)
    buf = IOBuffer()
    io = IOContext(buf, :compact => true, :limit => true)
    print(io, val)
    text = escape_string(String(take!(buf)))
    return TableCell(text, 1)
end

function render_cell(::Type{<:Real}, val, avail::Int)
    buf = IOBuffer()
    io = IOContext(buf, :compact => true, :limit => true)
    print(io, val)
    text = escape_string(String(take!(buf)))
    m = match(r"^(.*?)((?:[\.eE].*)?)$", text)
    alignment = m === nothing ? 1 : length(m.captures[2])+1
    return TableCell(text, alignment)
end

struct TableCanvas
    maxx::Int
    maxy::Int
    bufs::Vector{IOBuffer}
    tws::Vector{Int}

    TableCanvas(maxx, maxy) =
        new(maxx, maxy, [IOBuffer() for k = 1:maxy], fill(0, maxy))
end

function write!(c::TableCanvas, x::Int, y::Int, text::String)
    tw = textwidth(text)
    xend = x + tw - 1
    if isempty(text)
        return xend
    end
    @assert 1 <= y <= c.maxy "1 <= $y <= $(c.maxy)"
    @assert c.tws[y] < x "$(c.tws[y]) < $x"
    if x >= c.maxx && c.tws[y] + 1 < c.maxx
        x = c.maxx - 1
        xend = c.maxx
        text = " "
        tw = 1
    end
    if x < c.maxx
        if xend >= c.maxx
            tw = 0
            i = 0
            for i′ in eachindex(text)
                ch = text[i′]
                ctw = textwidth(ch)
                if x + tw + ctw - 1 < c.maxx
                    tw += ctw
                else
                    text = text[1:i]
                    break
                end
                i = i′
            end
            text = text * "…"
            tw += 1
            xend = x + tw - 1
        end
        if x > c.tws[y] + 1
            print(c.bufs[y], " " ^ (x - c.tws[y] - 1))
        end
        print(c.bufs[y], text)
        c.tws[y] = xend
    end
    xend
end

lines!(c::TableCanvas) =
    String.(take!.(c.bufs))

overflow(c::TableCanvas, x::Int) =
    x >= c.maxx

function table_draw(l::TableLayout, maxx::Int)
    maxy = size(l.cells, 1) + (l.tear_row > 0) + 1
    c = TableCanvas(maxx, maxy)
    extent = 0
    for col = 1:size(l.cells, 2)
        if col == l.idxs_cols + 1
            extent = draw_bar!(c, extent, l, l.idxs_cols == 0 ? -1 : 0)
        end
        extent = draw_column!(c, extent, l, col)
        if overflow(c, extent)
            break
        end
    end
    draw_bar!(c, extent, l, 1)
    c
end

function draw_bar!(c::TableCanvas, extent::Int, l::TableLayout, pos::Int)
    x = extent + 1
    y = 1
    for row = 1:size(l.cells, 1)
        write!(c, x, y, "│")
        y += 1
        if row == l.head_rows
            write!(c, x, y, "┼")
            y += 1
        end
        if row == l.tear_row
            y += 1
        end
    end
    extent + 1
end

function draw_column!(c::TableCanvas, extent::Int, l::TableLayout, col::Int)
    sz, rsz = l.sizes[col]
    if col == 1 && l.idxs_cols > 0
        sz -= 1
    end
    y = 1
    for row = 1:size(l.cells, 1)
        x = extent + 2
        cell = l.cells[row, col]
        if !isempty(cell.text)
            if cell.align > 0
                x = extent + sz - rsz - textwidth(cell.text) + cell.align + 1
            end
            write!(c, x, y, cell.text)
        end
        y += 1
        x = extent + 2
        if row == l.head_rows
            write!(c, extent + 1, y, "─" ^ (sz + 2))
            y += 1
        end
        if row == l.tear_row
            if col == 1
                write!(c, x + sz - 1, y, "⋮")
            end
            y += 1
        end
    end
    extent + sz + 2
end

