#
# Displaying DataKnot objects.
#

function show(io::IO, knot::DataKnot)
    maxy, maxx = displaysize(io)
    lines = render_dataknot(maxx, maxy, knot.shp, knot.elts)
    for line in lines
        println(io, line)
    end
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
    @assert 1 <= y <= c.maxy
    @assert c.tws[y] < x
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
            if y >= 1
                text = text * "…"
                tw += 1
            end
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
    x > c.maxx

struct TableHeader
    text::String
    nodes::Vector{TableHeader}
    width::Int
    depth::Int

    TableHeader(text::String) =
        new(text, TableHeader[], 1, isempty(text) ? 0 : 1)

    TableHeader(text::String, nodes::Vector{TableHeader}) =
        new(text,
            nodes,
            isempty(nodes) ? 1 : sum(n -> n.width, nodes),
            (isempty(text) ? 0 : 1) + (isempty(nodes) ? 0 : maximum(n -> n.depth, nodes)))
end

header(shp::OutputShape) =
    TableHeader(String(decoration(shp, :tag, Symbol, :DataKnot)),
                header_nodes(domain(shp)))

header_nodes(::AbstractShape) = TableHeader[]

header_nodes(shp::DecoratedShape) =
    header_nodes(undecorate(shp))

header_nodes(shp::Union{TupleShape,RecordShape}) =
    [TableHeader(String(decoration(col, :tag, Symbol, Symbol("#i"))))
     for (i, col) in enumerate(shp[:])]

struct TableCell
    text::String
    align::Int
end

TableCell() = TableCell("", 0)

TableCell(text) = TableCell(text, 0)

struct TableData
    width::Int
    height::Int
    head::TableHeader
    idxs::AbstractVector{Int}
    tear::Int
    cells::Array{TableCell,2}
    sizes::Vector{Tuple{Int,Int}}

    TableData(header, idxs, tears) =
        let w = header.width, h = header.depth + length(idxs)
            new(w, h, header, idxs, tears, fill(TableCell(), (w, h)), fill((0, 0), w))
        end
end

function render_dataknot(maxx::Int, maxy::Int, shp::OutputShape, elts::AbstractVector)
    head = header(shp)
    width = head.width
    hheight = head.depth
    L = length(elts)
    bheight = min(L, max(3, maxy - hheight - 4))
    tear = bheight + 1
    idxs = 1:L
    if bheight < L
        tear = 1 + bheight ÷ 2
        idxs = [1:tear; L-bheight+tear+2:L]
    end
    data = TableData(head, idxs, tear)
    populate_body!(data, shp, elts, maxx)
    populate_head!(data, shp, maxx)
    render(data, shp, maxx, maxy)
end

function populate_body!(data::TableData, shp::OutputShape, elts::AbstractVector, maxx::Int)
    extent = 2
    for col = 1:data.width
        row = data.head.depth + 1
        sz = 0
        rsz = 0
        for idx in data.idxs
            cell = render_cell(domain(shp), col, elts, idx, maxx-extent)
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
            data.cells[col,row] = cell
            row += 1
        end
        data.sizes[col] = (sz, rsz)
        extent += sz + 2
        if extent >= maxx
            break
        end
    end
end

populate_head!(data::TableData, shp::OutputShape, maxx::Int) =
    populate_head!(data.head, data, 1)

function populate_head!(head::TableHeader, data::TableData, col::Int)
    node_col = col
    for node in head.nodes
        populate_head!(node, data, node_col)
        node_col += node.width
    end
    if isempty(head.text)
        return
    end
    text = escape_string(head.text)
    tw = textwidth(text)
    avail = sum(data.sizes[k][1] + 2 for k = col:col+head.width-1) - 2
    if avail < tw
        extra = 1 + (tw - avail - 1) ÷ head.width
        k = col
        while avail < tw
            data.sizes[k] = (data.sizes[k][1] + extra, data.sizes[k][2])
            avail += extra
            k += 1
        end
    end
    row = data.head.depth - head.depth + 1
    data.cells[col,row] = TableCell(text)
end

render_cell(shp::DecoratedShape, col::Int, vals::AbstractVector, idx::Int, avail::Int) =
    render_cell(undecorate(shp), col, vals, idx, avail)

render_cell(shp::Union{TupleShape,RecordShape}, col::Int, vals::AbstractVector, idx::Int, avail::Int) =
    if col == 0
        buf = IOBuffer()
        comma = false
        for i in eachindex(shp[:])
            if comma
                print(buf, ", ")
                avail -= 2
                comma = false
            end
            cell = render_cell(shp, i, vals, idx, avail)
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
    elseif col <= length(shp[:])
        render_cell(shp[col], 0, column(vals, col), idx, avail)
    else
        TableCell()
    end

function render_cell(shp::OutputShape, col::Int, vals::AbstractVector, idx::Int, avail::Int)
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
            cell = render_cell(domain(shp), col, elts, k, avail)
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
        return render_cell(domain(shp), col, elts, l, avail)
    end
end

render_cell(shp::NativeShape, col::Int, vals::AbstractVector, idx::Int, avail::Int) =
    render_cell(shp.ty, vals[idx], avail)

const render_context = :compact => true

function render_cell(::Type, val, avail::Int)
    buf = IOBuffer()
    io = IOContext(buf, :compact => true, :limit => true)
    print(io, val)
    text = escape_string(String(take!(buf)))
    return TableCell(text)
end

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

function render(data::TableData, shp::OutputShape, maxx::Int, maxy::Int)
    c = TableCanvas(maxx, data.height + (data.tear <= length(data.idxs)) + 1)
    extent = 0
    if fits(PLU, cardinality(shp))
        extent = draw_indexes!(c, extent, data)
        extent = draw_bar!(c, extent, data, 0)
    else
        extent = draw_bar!(c, extent, data, -1)
    end
    for col = 1:data.width
        extent = draw_column!(c, extent, data, col)
        if overflow(c, extent)
            break
        end
    end
    draw_bar!(c, extent, data, 1)
    lines!(c)
end

function draw_indexes!(c::TableCanvas, extent::Int, data::TableData)
    y = data.head.depth + 1
    if isempty(data.idxs)
        write!(c, 1, y, "─")
    else
        sz = length(string(data.idxs[end]))
        x = extent + 1
        write!(c, x, y, "─"^(sz+1))
        y += 1
        for k = eachindex(data.idxs)
            if k == data.tear
                write!(c, x + sz - 1, y, "⋮")
                y += 1
            end
            idx = data.idxs[k]
            s = string(idx)
            write!(c, x + sz - length(s), y, s)
            y += 1
        end
    end
    extent + sz + 1
end

function draw_bar!(c::TableCanvas, extent::Int, data::TableData, pos::Int)
    x = extent + 1
    y = 1
    for k = 1:data.head.depth
        write!(c, x, y, "│")
        y += 1
    end
    write!(c, x, y, pos < 0 ? "├" : pos > 0 ? "┤" : "┼")
    y += 1
    for k = eachindex(data.idxs)
        if k == data.tear
            y += 1
        end
        write!(c, x, y, "│")
        y += 1
    end
    extent + 1
end

function draw_column!(c::TableCanvas, extent::Int, data::TableData, col::Int)
    sz, rsz = data.sizes[col]
    y = 1
    for k = 1:data.head.depth
        x = extent + 2
        write!(c, x, y, data.cells[col, k].text)
        y += 1
    end
    write!(c, extent + 1, y, "─" ^ (sz + 2))
    y += 1
    for k = eachindex(data.idxs)
        if k == data.tear
            y += 1
        end
        x = extent + 2
        cell = data.cells[col, data.head.depth+k]
        if cell.align > 0
            x = extent + sz - rsz - textwidth(cell.text) + cell.align + 1
        end
        write!(c, x, y, data.cells[col, data.head.depth+k].text)
        y += 1
    end
    extent + sz + 2
end

