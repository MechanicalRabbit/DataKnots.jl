# Data Knots

A `DataKnot` object contains a single data value serialized in a
column-oriented form.

    using DataKnots:
        @VectorTree,
        DataKnot,
        Lift,
        It,
        Record,
        ValueOf,
        cell,
        fromtable,
        shape,
        unitknot

To integrate with other tabular systems, we need the following:

    using Tables
    using CSV
    using DataFrames

## Overview

Any Julia value can be converted to a `DataKnot`.

    hello = convert(DataKnot, "Hello World!")
    #=>
    ┼──────────────┼
    │ Hello World! │
    =#

To obtain a Julia value from a DataKnot object, we use the `get()` function.

    get(hello)
    #-> "Hello World!"

To preserve the column-oriented structure of the data, `DataKnot` keeps the
value in a one-element vector.

    cell(hello)
    #-> ["Hello World!"]

`DataKnot` also stores the shape of the data.

    shape(hello)
    #-> ValueOf(String)

We use indexing notation to apply a `Query` to a `DataKnot`.  The output of a
query is also a `DataKnot` object.

    hello[length.(It)]
    #=>
    ┼────┼
    │ 12 │
    =#

To place several datasets into a single `DataKnot` we use a special constructor
that takes datasets with their names.

    sets = DataKnot(:main=>'a':'c', :more=>"data")
    #=>
    │ main     more │
    ┼───────────────┼
    │ a; b; c  data │
    =#

A specific dataset could be focused by navigating.

    sets[It.main]
    #=>
      │ main │
    ──┼──────┼
    1 │ a    │
    2 │ b    │
    3 │ c    │
    =#

## Importing & Exporting

We support the conversion to/from objects with the `Tables.jl`
interface. For example, we could import CSV data.

    chicago_file = """
    name,department,position,salary,rate
    "JEFFERY A","POLICE","SERGEANT",101442,
    "NANCY A","POLICE","POLICE OFFICER",80016,
    "JAMES A","FIRE","FIRE ENGINEER-EMT",103350,
    "DANIEL A","FIRE","FIRE FIGHTER-EMT",95484,
    "LAKENYA A","OEMC","CROSSING GUARD",,17.68
    "DORIS A","OEMC","CROSSING GUARD",,19.38
    """ |> IOBuffer |> CSV.File

    chicago = DataKnot(:employee => chicago_file)

    chicago[It.employee]
    #=>
      │ employee                                                │
      │ name       department  position           salary  rate  │
    ──┼─────────────────────────────────────────────────────────┼
    1 │ JEFFERY A  POLICE      SERGEANT           101442        │
    2 │ NANCY A    POLICE      POLICE OFFICER      80016        │
    3 │ JAMES A    FIRE        FIRE ENGINEER-EMT  103350        │
    4 │ DANIEL A   FIRE        FIRE FIGHTER-EMT    95484        │
    5 │ LAKENYA A  OEMC        CROSSING GUARD             17.68 │
    6 │ DORIS A    OEMC        CROSSING GUARD             19.38 │
    =#

This knot could then be queried and exported to a `DataFrame`.

    chicago[It.employee >>
            Record(It.name, It.department, It.salary)
           ] |> DataFrame
    #=>
    6×3 DataFrames.DataFrame
    │ Row │ name      │ department │ salary  │
    │     │ String    │ String     │ Int64⍰  │
    ├─────┼───────────┼────────────┼─────────┤
    │ 1   │ JEFFERY A │ POLICE     │ 101442  │
    │ 2   │ NANCY A   │ POLICE     │ 80016   │
    │ 3   │ JAMES A   │ FIRE       │ 103350  │
    │ 4   │ DANIEL A  │ FIRE       │ 95484   │
    │ 5   │ LAKENYA A │ OEMC       │ missing │
    │ 6   │ DORIS A   │ OEMC       │ missing │
    =#

## API Reference
```@autodocs
Modules = [DataKnots]
Pages = ["knots.jl"]
Public = false
```

## Test Suite


### Constructors

A `DataKnot` object is created from a one-element *cell* vector and its shape.

    hello = DataKnot(ValueOf(String), ["Hello World"])
    #=>
    ┼─────────────┼
    │ Hello World │
    =#

It is an error if the cell length is different from 1.

    DataKnot(ValueOf(String), String[])
    #-> ERROR: AssertionError: length(cell) == 1

The cell and its shape can be retrieved.

    cell(hello)
    #-> ["Hello World"]

    shape(hello)
    #-> ValueOf(String)

The shape could be specified by the element type.

    hello = DataKnot(String, ["Hello World"])

    shape(hello)
    #-> ValueOf(String)

The shape could also be introspected from the given cell.

    hello = DataKnot(Any, ["Hello World"])

    shape(hello)
    #-> ValueOf(String)

To make a `DataKnot` with a block cell, we can provide the block elements and
its cardinality.

    abc = DataKnot(Any, 'a':'c', :x1toN)
    #=>
    ──┼───┼
    1 │ a │
    2 │ b │
    3 │ c │
    =#

    cell(abc)
    #-> @VectorTree (1:N) × Char ['a':'\x01':'c']

    shape(abc)
    #-> BlockOf(Char, x1toN)

The default constructor creates the unit `DataKnot`, which holds an empty
tuple.  This knot is exported under the name `unitknot`.

    unitknot
    #=>
    ┼──┼
    │  │
    =#

    cell(unitknot)
    #-> @VectorTree (1:1) × () [()]

We can also construct a `DataKnot` containing a single top-level named tuple
with the given fields.

    recknot = DataKnot(:hello => "Hello World!", :main => 'a':'c')
    #=>
    │ hello         main    │
    ┼───────────────────────┼
    │ Hello World!  a; b; c │
    =#

    cell(recknot)
    #-> @VectorTree (1:1) × (hello = String, main = (0:N) × Char) [(hello = "Hello World!", main = 'a':'\x01':'c')]

Any Julia value can be converted to a `DataKnot` object using the `convert()`
function.

    hello = convert(DataKnot, "Hello World!")
    #=>
    ┼──────────────┼
    │ Hello World! │
    =#

Scalar values are stored as is.

    shape(hello)
    #-> ValueOf(String)

The value `missing` is converted to an empty `DataKnot`.

    nullknot = convert(DataKnot, missing)
    #=>
    (empty)
    =#

    shape(nullknot)
    #-> BlockOf(NoShape(), x0to1)

A vector value is converted to a block.

    vecknot = convert(DataKnot, 'a':'c')
    #=>
    ──┼───┼
    1 │ a │
    2 │ b │
    3 │ c │
    =#

    shape(vecknot)
    #-> BlockOf(Char)

A `Ref` object is converted into the referenced value.

    int_ty = convert(DataKnot, Base.broadcastable(Int))
    #=>
    ┼───────┼
    │ Int64 │
    =#

    shape(int_ty)
    #-> ValueOf(Type{Int64})

`Tables.jl` interface is used for conversion when it is supported by the given
value.

    convert(DataKnot, DataFrame(:name => ["JEFFERY A", "NANCY A"],
                                :position => ["SERGEANT", "POLICE OFFICER"],
                                :salary => [101442, 80016]))
    #=>
      │ name       position        salary │
    ──┼───────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT        101442 │
    2 │ NANCY A    POLICE OFFICER   80016 │
    =#

### Rendering

On output, a `DataKnot` object is rendered as a table.

    emp = convert(DataKnot,
                  [(name = "JEFFERY A", position = "SERGEANT", salary = 101442),
                   (name = "NANCY A", position = "POLICE OFFICER", salary = 80016),
                   (name = "JAMES A", position = "FIRE ENGINEER-EMT", salary = 103350),
                   (name = "DANIEL A", position = "FIRE FIGHTER-EMT", salary = 95484)])
    #=>
      │ name       position           salary │
    ──┼──────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT           101442 │
    2 │ NANCY A    POLICE OFFICER      80016 │
    3 │ JAMES A    FIRE ENGINEER-EMT  103350 │
    4 │ DANIEL A   FIRE FIGHTER-EMT    95484 │
    =#

If the table columns do not fit the output screen, some table cells could be
truncated.

    small = IOContext(stdout, :displaysize => (24, 35))

    show(small, emp)
    #=>
      │ name       position   salary │
    ──┼──────────────────────────────┼
    1 │ JEFFERY A  SERGEANT   101442 │
    2 │ NANCY A    POLICE OF…  80016 │
    3 │ JAMES A    FIRE ENGI… 103350 │
    4 │ DANIEL A   FIRE FIGH…  95484 │
    =#

If the screen is too small, the whole table needs to be truncated.

    tiny = IOContext(stdout, :displaysize => (6, 20))

    show(tiny, emp)
    #=>
      │ name      posit…
    ──┼────────────────…
    1 │ JEFFERY … SERGE…
    ⋮
    4 │ DANIEL A  FIRE …
    =#

Top-level tuples are serialized as table columns while nested tuples are
rendered as comma-separated lists of tuple elements.

    convert(DataKnot, ("FIRE", [("JEFFERY A", (101442, missing)), ("NANCY A", (80016, missing))]))
    #=>
    │ #A    #B{#A,#B{#A,#B}}                                        │
    ┼───────────────────────────────────────────────────────────────┼
    │ FIRE  JEFFERY A, (101442, missing); NANCY A, (80016, missing) │
    =#

    convert(DataKnot, (name = "FIRE", employee = [(name = "JEFFERY A", compensation = (salary = 101442, rate = missing)),
                                                  (name = "NANCY A", compensation = (salary = 80016, rate = missing))]))
    #=>
    │ name  employee{name,compensation{salary,rate}}                │
    ┼───────────────────────────────────────────────────────────────┼
    │ FIRE  JEFFERY A, (101442, missing); NANCY A, (80016, missing) │
    =#

    DataKnot(
        Any,
        @VectorTree((name = (1:1)String,
                     employee = [(name = (1:1)String,
                                  compensation = (1:1)(salary = (0:1)Int,
                                                       rate = (0:1)Float64))]), [
            (name = "FIRE", employee = [(name = "JEFFERY A", compensation = (salary = 101442, rate = missing)),
                                        (name = "NANCY A", compensation = (salary = 80016, rate = missing))])]),)
    #=>
    │ name  employee{name,compensation{salary,rate}}                │
    ┼───────────────────────────────────────────────────────────────┼
    │ FIRE  JEFFERY A, (101442, missing); NANCY A, (80016, missing) │
    =#

Similarly, top-level vectors are represented as table rows while nested vectors
are rendered as semicolon-separated lists.

    convert(DataKnot, [["JEFFERY A", "NANCY A"], ["JAMES A", "DANIEL A"]])
    #=>
    ──┼────────────────────┼
    1 │ JEFFERY A; NANCY A │
    2 │ JAMES A; DANIEL A  │
    =#

    convert(DataKnot, @VectorTree [String] [["JEFFERY A", "NANCY A"], ["JAMES A", "DANIEL A"]])
    #=>
    ──┼────────────────────┼
    1 │ JEFFERY A; NANCY A │
    2 │ JAMES A; DANIEL A  │
    =#

Integer numbers are right-aligned while decimal numbers are centered around the
decimal point.

    convert(DataKnot, [true, false])
    #=>
    ──┼───────┼
    1 │  true │
    2 │ false │
    =#

    convert(DataKnot, [101442, 80016])
    #=>
    ──┼────────┼
    1 │ 101442 │
    2 │  80016 │
    =#

    convert(DataKnot, [35.6, 2.65])
    #=>
    ──┼───────┼
    1 │ 35.6  │
    2 │  2.65 │
    =#

`DataKnot` objects provide alternative output modes.  For example,
we can visualize the shape of a `DataKnot` as a tree.

    show(chicago, as=:shape)
    #=>
    1-element DataKnot:
      #               1:1
      └╴employee      0:N
        ├╴name        String
        ├╴department  String
        ├╴position    String
        ├╴salary      Union{Missing, Int64}
        └╴rate        Union{Missing, Float64}
    =#

### Exporting via Table.jl Interface

When a knot has a tabular form, it can be exported via `Tables.jl`.

This is the case when a `DataKnot` wraps a vector of named tuples.

    table = convert(DataKnot, [(x="A", y=1.0), (x="B", y=2.0)])

    Tables.istable(table)
    #-> true

    Tables.columnaccess(table)
    #-> true

    cols = Tables.columns(table)

    cols.x
    #-> ["A", "B"]

    cols.y
    #-> [1.0, 2.0]

A plural set of records will also be treated as a table.

    table = unitknot[Lift(1:3) >> Record(:idx => It, :val => "Test")]

    Tables.istable(table)
    #-> true

    Tables.columnaccess(table)
    #-> true

    cols = Tables.columns(table)

    cols.idx
    #-> [1, 2, 3]

    cols.val
    #-> ["Test", "Test", "Test"]

