#
# DataKnot definition, integration, and operations.
#

using Tables

import Base:
    convert,
    get,
    show

#
# Definition.
#

"""
    DataKnot(Pair{Symbol}...)

This constructor binds names to datasets, so that they
could be used to start a query. The knot created has a
single top-level record, each with its own value.

```jldoctest
julia> test_knot = DataKnot(:dataset=>'a':'c')
│ dataset │
┼─────────┼
│ a; b; c │

julia> test_knot[It.dataset]
  │ dataset │
──┼─────────┼
1 │ a       │
2 │ b       │
3 │ c       │
```

Arguments to this constructor are run though `convert`.

---

    convert(DataKnot, val)

This converter wraps a given value so that it could be used to
start a query.

An empty knot can be constructed with `missing`.

```jldoctest
julia> convert(DataKnot, missing)
(empty)
```

A plural knot is constructed from a vector.

```jldoctest
julia> convert(DataKnot, 'a':'c')
──┼───┼
1 │ a │
2 │ b │
3 │ c │
```

An object that complies with the `Table` interface, such as
a `CSV` file, can be converted to a DataKnot.

```jldoctest
julia> using CSV;

julia> csv_file = "k,v\\na,1\\nb" |> IOBuffer |> CSV.File;

julia> convert(DataKnot, csv_file)
  │ k  v │
──┼──────┼
1 │ a  1 │
2 │ b    │
```

---

    get(::DataKnot)

Use `get` to extract the underlying value held by a knot.

```jldoctest
julia> get(convert(DataKnot, "Hello World"))
"Hello World"
```

---

    getindex(::DataKnot, X; kwargs...)

We can query a knot using array indexing notation.

```jldoctest
julia> convert(DataKnot, (dataset='a':'c',))[Count(It.dataset)]
┼───┼
│ 3 │
```

Query parameters are provided as keyword arguments.

```jldoctest
julia> convert(DataKnot, 1:3)[PWR=2, It .^ It.PWR]
──┼───┼
1 │ 1 │
2 │ 4 │
3 │ 9 │
```
"""
struct DataKnot
    shp::AbstractShape
    cell::AbstractVector

    function DataKnot(shp::AbstractShape, cell::AbstractVector)
        @assert length(cell) == 1
        new(shp, cell)
    end
end

DataKnot(T::Type, cell::AbstractVector) =
    DataKnot(convert(AbstractShape, T), cell)

DataKnot(::Type{Any}, cell::AbstractVector) =
    DataKnot(shapeof(cell), cell)

function DataKnot(::Type{Any}, elts::AbstractVector, card::Union{Cardinality,Symbol})
    card = convert(Cardinality, card)
    shp = BlockOf(shapeof(elts), card)
    cell = BlockVector{card}([1, length(elts)+1], elts)
    return DataKnot(shp, cell)
end

DataKnot() =
    DataKnot(Any, TupleVector(1), x1to1)

function DataKnot(ps::Pair{Symbol}...)
    lbls = collect(first.(ps))
    cols = collect(convert.(DataKnot, last.(ps)))
    vals = collect(AbstractVector, cell.(cols))
    shp = BlockOf(TupleOf(lbls, shape.(cols)), x1to1)
    return DataKnot(shp, BlockVector(:, TupleVector(lbls, 1, vals)))
end

convert(::Type{DataKnot}, db::DataKnot) = db

convert(::Type{DataKnot}, ref::Base.RefValue{T}) where {T} =
    DataKnot(ValueOf(T), T[ref.x])

convert(::Type{DataKnot}, elts::AbstractVector) =
    DataKnot(Any, elts, x0toN)

convert(::Type{DataKnot}, ::Missing) =
    DataKnot(Any, Union{}[], x0to1)

convert(::Type{DataKnot}, elt::Union{Tuple, NamedTuple}) =
    DataKnot(Any, [elt])

convert(::Type{DataKnot}, elt) =
    if Tables.istable(elt)
        fromtable(elt)
    else
        DataKnot(Any, [elt])
    end

"""
    unitknot

The unit knot holds an empty tuple.

```jldoctest
julia> unitknot
┼──┼
│  │
```

The `unitknot` is useful for constructing queries that
do not originate from another datasource.

```jldoctest
julia> unitknot["Hello"]
┼───────┼
│ Hello │
```
"""
const unitknot = DataKnot()

get(db::DataKnot) = db.cell[1]

cell(db::DataKnot) = db.cell

shape(db::DataKnot) = db.shp

quoteof(db::DataKnot) =
    Symbol("DataKnot( … )")

#
# Tables.jl interface.
#

Tables.istable(db::DataKnot) =
    Tables.istable(eltype(db.cell))

Tables.columnaccess(db::DataKnot) =
    Tables.istable(db)

Tables.columns(db::DataKnot) =
    cell_columns(db.cell)

cell_columns(cell::AbstractVector) =
    Tables.columns(cell[1])

cell_columns(cell::Union{BlockVector{x0toN},BlockVector{x1toN}}) =
    Tables.columns(elements(cell))

function fromtable(table, card::Union{Cardinality, Symbol}=x0toN)
    card = convert(Cardinality, card)
    cols = Tables.columns(table)
    flds = Pair{Symbol,AbstractVector}[]
    for lbl in propertynames(cols)
        col = getproperty(cols, lbl)
        push!(flds, lbl => col)
    end
    tv = TupleVector(flds...)
    return DataKnot(Any, tv, card)
end

#
# Rendering.
#

summary(io::IO, db::DataKnot) =
    print(io, "$(cell_length(db.cell))-element DataKnot")

cell_length(cell::AbstractVector) =
    eltype(cell) <: AbstractVector ? length(cell[1]) : 1

cell_length(cell::BlockVector) =
    length(elements(cell))

"""
    show(::DataKnot[; as=:table])

This displays a `DataKnot` as a table, truncating the data
to fit the current display.

```jldoctest
julia> using DataKnots

julia> show(unitknot[Lift(1:3) >> Record(:x => It, :y => It .* It)])
  │ x  y │
──┼──────┼
1 │ 1  1 │
2 │ 2  4 │
3 │ 3  9 │
```

    show(::DataKnot; as=:shape)

This visualizes the shape of a `DataKnot` in a form of a tree.

```jldoctest
julia> using DataKnots

julia> show(as=:shape, unitknot[Lift(1:3) >> Record(:x => It, :y => It .* It)])
3-element DataKnot:
  #    0:N
  ├╴x  1:1 × Int64
  └╴y  1:1 × Int64
```
"""
show(db::DataKnot; kws...) =
    show(stdout, db; kws...)

function show(io::IO, db::DataKnot; as::Symbol=:table)
    if as == :shape
        print_shape(io, db)
    else
        print_table(io, db)
    end
end

function print_shape(io::IO, db::DataKnot)
    summary(io, db)
    println(":")
    print_graph(io, shape(db); indent=2)
end

function print_table(io::IO, db::DataKnot)
    maxy, maxx = displaysize(io)
    lines = render_table(maxx, maxy, db)
    for line in lines
        println(io, line)
    end
end

function render_table(maxx::Int, maxy::Int, db::DataKnot)
    d = table_data(db, maxy)
    l = table_layout(d, maxx)
    c = table_draw(l, maxx)
    return lines!(c)
end

# Mapping data to tabular form.

struct TableData
    head::Array{Tuple{String,Int},2}
    body::TupleVector
    shp::TupleOf
    idxs::AbstractVector{Int}
    tear::Int
end

TableData(head, body, shp) =
    TableData(head, body, shp, 1:0, 0)

TableData(d::TableData; head=nothing, body=nothing, shp=nothing, idxs=nothing, tear=nothing) =
    TableData(head !== nothing ? head : d.head,
              body !== nothing ? body : d.body,
              shp !== nothing ? shp : d.shp,
              idxs !== nothing ? idxs : d.idxs,
              tear !== nothing ? tear : d.tear)

function table_data(db::DataKnot, maxy::Int)
    shp = shape(db)
    title = String(getlabel(shp, ""))
    shp = relabel(shp, nothing)
    head = fill((title, 1), (title != "" ? 1 : 0, 1))
    body = TupleVector(1, AbstractVector[cell(db)])
    shp = TupleOf(shp)
    d = TableData(head, body, shp)
    return tear_data(nested_headers(focus_data(d, 1)), maxy)
end

focus_data(d::TableData, pos) =
    focus_tuples(focus_blocks(d, pos), pos)

function focus_blocks(d::TableData, pos::Int)
    col_shp = column(d.shp, pos)
    p = as_blocks(col_shp)
    p !== nothing || return d
    blks = chain_of(with_column(pos, p), distribute(pos))(d.body)
    body′ = elements(blks)
    col_shp′ = elements(target(p))
    shp′ = replace_column(d.shp, pos, col_shp′)
    card = cardinality(target(p))
    idxs′ =
        if !isempty(d.idxs)
            elements(chain_of(distribute(2), column(1))(TupleVector(:idxs => d.idxs, :blks => blks)))
        elseif !issingular(card)
            1:length(body′)
        else
            1:0
        end
    TableData(d, body=body′, shp=shp′, idxs=idxs′)
end

as_blocks(::AbstractShape) =
    nothing

as_blocks(shp::Annotation) =
    as_blocks(subject(shp))

as_blocks(src::BlockOf) =
    pass() |> designate(src, src)

as_blocks(src::ValueOf) =
    as_blocks(eltype(src))

as_blocks(::Type) =
    nothing

as_blocks(ity::Type{<:AbstractVector}) =
    adapt_vector() |> designate(ity, BlockOf(eltype(ity)))

as_blocks(ity::Type{>:Missing}) =
    adapt_missing() |> designate(ity, BlockOf(Base.nonmissingtype(ity), x0to1))

function focus_tuples(d::TableData, pos::Int)
    col_shp = column(d.shp, pos)
    p = as_tuples(col_shp)
    p !== nothing || return d
    col′ = p(column(d.body, pos))
    width(col′) > 0 || return d
    cols′ = copy(columns(d.body))
    splice!(cols′, pos:pos, columns(col′))
    body′ = TupleVector(length(d.body), cols′)
    col_shp′ = target(p)
    col_shps′ = copy(columns(d.shp))
    splice!(col_shps′, pos:pos, columns(col_shp′))
    shp′ = TupleOf(col_shps′)
    cw = width(col′)
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
        text = String(label(col_shp′, k))
        head′[hh′, col′] = (text, 1)
    end
    TableData(d, head=head′, body=body′, shp=shp′)
end

as_tuples(::AbstractShape) =
    nothing

as_tuples(shp::Annotation) =
    as_tuples(subject(shp))

as_tuples(src::TupleOf) =
    pass() |> designate(src, src)

as_tuples(src::ValueOf) =
    as_tuples(eltype(src))

as_tuples(::Type) =
    nothing

as_tuples(ity::Type{<:NamedTuple}) =
    adapt_tuple() |> designate(ity,
                               TupleOf(collect(Symbol, ity.parameters[1]),
                                       collect(AbstractShape, ity.parameters[2].parameters)))

as_tuples(ity::Type{<:Tuple}) =
    adapt_tuple() |> designate(ity,
                               TupleOf(collect(AbstractShape, ity.parameters)))

function nested_headers(d::TableData)
    hh, hw = size(d.head)
    hh > 0 || return d
    head′ = copy(d.head)
    for col = 1:hw
        row = hh
        d.head[row, col][2] == 1 || continue
        while d.head[row, col] == ("", 1) && row > 1 && d.head[row-1, col] == ("", 1)
            row -= 1
        end
        sel = nested_selector(column(d.shp, col))
        sel != "" || continue
        head′[row, col] = (d.head[row, col][1] * sel, 1)
    end
    TableData(d, head=head′)
end

function nested_selector(shp::AbstractShape)
    p = as_blocks(shp)
    if p !== nothing
        shp = elements(target(p))
    end
    p = as_tuples(shp)
    p !== nothing || return ""
    shp = target(p)
    sels = String[]
    for k = 1:width(shp)
        text = String(label(shp, k))
        push!(sels, text * nested_selector(column(shp, k)))
    end
    "{" * join(sels, ",") * "}"
end

function tear_data(d::TableData, maxy::Int)
    L = length(d.body)
    avail = max(3, maxy - size(d.head, 1) - 4)
    avail < L || return d
    tear = avail ÷ 2
    perm = [1:tear; L-avail+tear+2:L]
    body′ = d.body[perm]
    idxs′ = !isempty(d.idxs) ? d.idxs[perm] : d.idxs
    TableData(d, body=body′, idxs=idxs′, tear=tear)
end

# Rendering table cells.

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
    empty::Bool

    TableLayout(w, h, idxs_cols, head_rows, tear_row, empty) =
        new(fill(TableCell(), (h, w)), fill((0, 0), w), idxs_cols, head_rows, tear_row, empty)
end

function table_layout(d::TableData, maxx::Int)
    w = (!isempty(d.idxs)) + width(d.body)
    h = size(d.head, 1) + length(d.body)
    idxs_cols = 0 + (!isempty(d.idxs))
    head_rows = size(d.head, 1)
    tear_row = d.tear > 0 ? head_rows + d.tear : 0
    l = TableLayout(w, h, idxs_cols, head_rows, tear_row, isempty(d.body))
    populate_body!(d, l, maxx)
    populate_head!(d, l)
    squeeze!(l, maxx)
    l
end

function populate_body!(d::TableData, l::TableLayout, maxx::Int)
    col = 1
    if !isempty(d.idxs)
        populate_column!(l, col, ValueOf(Int), d.idxs, maxx)
        col += 1
    end
    for (shp, vals) in zip(columns(d.shp), columns(d.body))
        populate_column!(l, col, shp, vals, maxx)
        col += 1
    end
end

function populate_column!(l::TableLayout, col::Int, shp::AbstractShape, vals::AbstractVector, avail::Int)
    row = l.head_rows + 1
    sz = 0
    rsz = 0
    for i in eachindex(vals)
        l.cells[row,col] = cell = render_cell(shp, vals, i, avail)
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
            l.cells[row,col+span-1] = TableCell(text, 1-span)
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

function squeeze!(l::TableLayout, avail::Int)
    total = 3
    for col = 1:size(l.cells, 2)
        sz, rsz = l.sizes[col]
        if col == 1 && l.idxs_cols > 0
            sz -= 1
        end
        total += sz + 2
    end
    total > avail || return
    cols = collect(1+l.idxs_cols:size(l.cells, 2))
    !isempty(cols) || return
    sort!(cols, by=(col -> -l.sizes[col][1]))
    maxsz = l.sizes[cols[1]][1]
    rem = 0
    for k = 1:length(cols)
        total > avail && maxsz > 8 || break
        sz = k < length(cols) ? max(l.sizes[cols[k+1]][1], 8) : 8
        extra = (maxsz - sz) * k
        if total - avail < extra
            d = 1 + (total - avail - 1) ÷ k
            maxsz -= d
            rem = d * k - total + avail
            total = avail
        else
            total -= extra
            maxsz = sz
        end
    end
    for col in cols
        sz, rsz = l.sizes[col]
        d = sz - maxsz
        if rem > 0
            d -= 1
            rem -= 1
        end
        d >= 0 || break
        l.sizes[col] = (sz-d, rsz-d)
    end
end

function render_cell(shp::TupleOf, vals::AbstractVector, idx::Int, avail::Int, depth::Int=0)
    buf = IOBuffer()
    comma = false
    for i in eachindex(columns(shp))
        if comma
            print(buf, ", ")
            avail -= 2
            comma = false
        end
        cell = render_cell(column(shp, i), column(vals, i), idx, avail, 2)
        print(buf, cell.text)
        avail -= textwidth(cell.text)
        if avail < 0
            break
        end
        if !isempty(cell.text)
            comma = true
        end
    end
    text = String(take!(buf))
    if depth >= 2
        text = "(" * text * ")"
    end
    return TableCell(text)
end

function render_cell(shp::BlockOf, vals::AbstractVector, idx::Int, avail::Int, depth::Int=0)
    offs = offsets(vals)
    elts = elements(vals)
    l = offs[idx]
    r = offs[idx+1]-1
    card = cardinality(shp)
    if issingular(card)
        if l > r
            return depth >= 1 ? TableCell("missing") : TableCell()
        else
            return render_cell(elements(shp), elts, l, avail, depth)
        end
    else
        buf = IOBuffer()
        comma = false
        for k = l:r
            if comma
                print(buf, "; ")
                avail -= 2
                comma = false
            end
            cell = render_cell(elements(shp), elts, k, avail, 1)
            print(buf, cell.text)
            avail -= textwidth(cell.text)
            if avail < 0
                break
            end
            if !isempty(cell.text)
                comma = true
            end
        end
        text = String(take!(buf))
        if depth >= 1
            text = "[" * text * "]"
        end
        return TableCell(text)
    end
end

function render_cell(shp::AbstractShape, vals::AbstractVector, idx::Int, avail::Int, depth::Int=0)
    p = as_blocks(shp)
    p === nothing || return render_cell(target(p), p(vals[idx:idx]), 1, avail, depth)
    p = as_tuples(shp)
    p === nothing || return render_cell(target(p), p(vals[idx:idx]), 1, avail, depth)
    render_cell(vals[idx], avail)
end

function render_value(val)
    buf = IOBuffer()
    io = IOContext(buf, :compact => true, :limit => true)
    print(io, val)
    escape_string(String(take!(buf)))
end

render_cell(val, ::Int) =
    TableCell(render_value(val))

render_cell(::Nothing, ::Int) =
    TableCell("")

render_cell(val::Integer, ::Int) =
    TableCell(render_value(val), 1)

function render_cell(val::Real, ::Int)
    text = render_value(val)
    m = match(r"^(.*?)((?:[\.eE].*)?)$", text)
    alignment = m === nothing ? 1 : length(m.captures[2])+1
    return TableCell(text, alignment)
end

# Serializing table.

struct TableCanvas
    maxx::Int
    maxy::Int
    bufs::Vector{IOBuffer}
    tws::Vector{Int}

    TableCanvas(maxx, maxy) =
        new(maxx, maxy, [IOBuffer() for k = 1:maxy], fill(0, maxy))
end

function write!(c::TableCanvas, x::Int, y::Int, text::String, cut::Int=0)
    cut = cut > 0 ? min(cut, c.maxx) : c.maxx
    tw = textwidth(text)
    xend = x + tw - 1
    if isempty(text)
        return xend
    end
    @assert 1 <= y <= c.maxy "1 <= $y <= $(c.maxy)"
    @assert c.tws[y] < x "$(c.tws[y]) < $x"
    if x >= cut && c.tws[y] + 1 < cut
        x = cut - 1
        xend = cut
        text = " "
        tw = 1
    end
    if x < cut
        if xend >= cut
            tw = 0
            i = 0
            for i′ in eachindex(text)
                ch = text[i′]
                ctw = textwidth(ch)
                if x + tw + ctw - 1 < cut
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

function table_draw(l::TableLayout, maxx::Int)
    maxy = size(l.cells, 1) > 0 ? size(l.cells, 1) + (l.tear_row > 0) + l.empty + 1 : 1
    c = TableCanvas(maxx, maxy)
    if size(l.cells, 1) > 0
        extent = 0
        for col = 1:size(l.cells, 2)
            if col == l.idxs_cols + 1
                extent = draw_bar!(c, extent, l)
            end
            extent = draw_column!(c, extent, l, col)
        end
        draw_bar!(c, extent, l)
    end
    if l.empty
        write!(c, 1, maxy, "(empty)")
    end
    c
end

function draw_bar!(c::TableCanvas, extent::Int, l::TableLayout)
    x = extent + 1
    y = 1
    if l.head_rows == 0
        write!(c, x, y, "┼")
        y += 1
    end
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
    cut = extent + sz + 2
    if col == 1 && l.idxs_cols > 0
        sz -= 1
    end
    y = 1
    if l.head_rows == 0
        write!(c, extent + 1, y, "─" ^ (sz + 2))
        y += 1
    end
    for row = 1:size(l.cells, 1)
        x = extent + 2
        cell = l.cells[row, col]
        if !isempty(cell.text)
            if cell.align > 0
                x = extent + sz - rsz - textwidth(cell.text) + cell.align + 1
            elseif cell.align < 0
                for k = cell.align:-1
                    x -= l.sizes[col+k][1] + 2
                end
            end
            write!(c, x, y, cell.text, cut)
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

