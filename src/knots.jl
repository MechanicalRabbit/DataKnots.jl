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

abstract type AbstractPipeline end

"""
    DataKnot(::OutputShape, ::AbstractVector)

Encapsulates data in column-oriented format.
"""
struct DataKnot <: AbstractPipeline
    elts::AbstractVector
    shp::OutputShape
end

DataKnot(elts::AbstractVector, card::Cardinality=OPT|PLU) =
    DataKnot(elts, OutputShape(shapeof(elts), card))

DataKnot(elt::T, card::Cardinality=REG) where {T} =
    DataKnot(T[elt], OutputShape(NativeShape(T), card))

DataKnot(::Missing, card::Cardinality=OPT) =
    DataKnot(Union{}[], OutputShape(NoneShape(), card))

DataKnot(ref::Base.RefValue{T}, card::Cardinality=REG) where {T} =
    DataKnot(T[ref.x], OutputShape(NativeShape(T), card))

convert(::Type{DataKnot}, db::DataKnot) = db

convert(::Type{DataKnot}, val) = DataKnot(val)

get(db::DataKnot) =
    let card = cardinality(db.shp)
        card == REG || card == OPT && !isempty(db.elts) ? db.elts[1] :
        card == OPT ? missing : db.elts
    end

elements(db::DataKnot) = db.elts

shape(db::DataKnot) = db.shp

decoration(db::DataKnot) = decoration(db.shp)

domain(db::DataKnot) = domain(db.shp)

mode(db::DataKnot) = mode(db.shp)

cardinality(db::DataKnot) = cardinality(db.shp)

syntax(db::DataKnot) =
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
    doms::Vector{AbstractShape}
    idxs::AbstractVector{Int}
    tear::Int
end

TableData(head, body, doms) =
    TableData(head, body, doms, 1:0, 0)

function table_data(db::DataKnot, maxy::Int)
    elts = elements(db)
    dom = domain(db)
    card = cardinality(db)
    title =
        let lbl = label(shape(db))
            if lbl === nothing
                lbl = :DataKnot
            end
            String(lbl)
        end
    parts = data_parts(dom, elts)
    if isempty(parts)
        head = fill((title, 1), (!isempty(title) ? 1 : 0, 1))
        body = TupleVector(length(elts), AbstractVector[elts])
        doms = AbstractShape[NoneShape()]
    else
        hh = (!isempty(title) ? 1 : 0) + maximum(p -> size(p.head, 1), parts)
        hw = sum(p -> size(p.head, 2), parts)
        head = fill(("", 0), (hh, hw))
        if !isempty(title)
            head[1,1] = (title, hw)
        end
        cols = AbstractVector[]
        doms = AbstractShape[]
        l = 1
        for part in parts
            append!(cols, columns(part.body))
            append!(doms, part.doms)
            ph = size(part.head, 1)
            pw = size(part.head, 2)
            t = hh - ph + 1
            copyto!(head, CartesianIndices((t:t+ph-1, l:l+pw-1)), part.head, CartesianIndices(part.head))
            l += pw
        end
        body = TupleVector(length(elts), cols)
    end
    L = length(elts)
    idxs = 1:L
    tear = 0
    if !isplural(card)
        idxs = 1:0
    else
        avail = max(3, maxy - size(head, 1) - 4)
        if avail < L
            tear = 1 + avail ÷ 2
            idxs = [1:tear; L-avail+tear+2:L]
            body = body[idxs]
        end
    end
    return TableData(head, body, doms, idxs, tear)
end

data_parts(shp::AbstractShape, vals::AbstractVector) =
    [TableData(fill(("", 0), (0, 1)), TupleVector(length(vals), AbstractVector[vals]), AbstractShape[shp])]

function data_parts(shp::RecordShape, vals::TupleVector)
    parts = TableData[]
    for i in eachindex(shp[:])
        title =
            let lbl = label(shp[i])
                if lbl === nothing
                    lbl = Symbol("#$i")
                end
                String(lbl)
            end
        head = fill((title, 1), (!isempty(title) ? 1 : 0, 1))
        body = TupleVector(length(vals), AbstractVector[column(vals, i)])
        doms = AbstractShape[shp[i]]
        push!(parts, TableData(head, body, doms))
    end
    parts
end

function data_parts(::NativeShape, vals::AbstractVector{<:NamedTuple})
    ty = eltype(vals)
    lbls = collect(Symbol, ty.parameters[1])
    coltys = ty.parameters[2].parameters
    cols = AbstractVector[BlockVector(:, collect(coltys[j], map(t -> t[j], vals)))
                          for j = eachindex(coltys)]
    vals′ = TupleVector(lbls, length(vals), cols)
    data_parts(shapeof(vals′), vals′)
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
        avail = populate_column!(l, col, NativeShape(Int), d.idxs, avail)
        col += 1
    end
    for (dom, vals) in zip(d.doms, columns(d.body))
        if avail < 0
            break
        end
        avail = populate_column!(l, col, dom, vals, avail)
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

function render_cell(shp::RecordShape, vals::AbstractVector, idx::Int, avail::Int)
    buf = IOBuffer()
    comma = false
    for i in eachindex(shp[:])
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

function render_cell(::NativeShape, vals::AbstractVector{<:Union{Tuple,NamedTuple}}, idx::Int, avail::Int)
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

function render_cell(shp::OutputShape, vals::AbstractVector, idx::Int, avail::Int)
    offs = offsets(vals)
    elts = elements(vals)
    l = offs[idx]
    r = offs[idx+1]-1
    if l > r
        return TableCell()
    elseif fits(PLU, cardinality(shp))
        buf = IOBuffer()
        comma = false
        for k = l:r
            if comma
                print(buf, "; ")
                avail -= 2
                comma = false
            end
            cell = render_cell(domain(shp), elts, k, avail)
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
        return render_cell(domain(shp), elts, l, avail)
    end
end

render_cell(shp::NativeShape, vals::AbstractVector, idx::Int, avail::Int) =
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
        if row == l.head_rows + 1
            write!(c, x, y, pos < 0 ? "├" : pos > 0 ? "┤" : "┼")
            y += 1
        end
        if row == l.tear_row + 1 && l.tear_row > 0
            y += 1
        end
        write!(c, x, y, "│")
        y += 1
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
        if row == l.head_rows + 1
            write!(c, extent + 1, y, "─" ^ (sz + 2))
            y += 1
        end
        if row == l.tear_row + 1 && l.tear_row > 0
            if col == 1
                write!(c, x + sz - 1, y, "⋮")
            end
            y += 1
        end
        cell = l.cells[row, col]
        if !isempty(cell.text)
            if cell.align > 0
                x = extent + sz - rsz - textwidth(cell.text) + cell.align + 1
            end
            write!(c, x, y, cell.text)
        end
        y += 1
    end
    extent + sz + 2
end

