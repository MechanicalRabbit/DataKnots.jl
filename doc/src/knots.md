# Data Knots

A `DataKnot` object contains a single data value serialized in a
column-oriented form.

    using DataKnots:
        @VectorTree,
        DataKnot,
        It,
        ValueOf,
        cell,
        shape,
        unitknot

## Overview

Any Julia value can be converted to a `DataKnot`.

    hello = convert(DataKnot, "Hello World!")
    #=>
    │ It           │
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
    │ It │
    ┼────┼
    │ 12 │
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
    │ It          │
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
      │ It │
    ──┼────┼
    1 │ a  │
    2 │ b  │
    3 │ c  │
    =#

    cell(abc)
    #-> @VectorTree (1:N) × Char ['a':'\x01':'c']

    shape(abc)
    #-> BlockOf(Char, x1toN)

Any Julia value can be converted to a `DataKnot` object using the `convert()`
function.

    hello = convert(DataKnot, "Hello World!")
    #=>
    │ It           │
    ┼──────────────┼
    │ Hello World! │
    =#

Scalar values are stored as is.

    shape(hello)
    #-> ValueOf(String)

The value `missing` is converted to an empty `DataKnot`.

    nullknot = convert(DataKnot, missing)
    #=>
    │ It │
    ┼────┼
    =#

    shape(nullknot)
    #-> BlockOf(NoShape(), x0to1)

The value `nothing` is converted to the unit `DataKnot`.  The unit `DataKnot`
is exported under the name `unitknot`.

    unitknot
    #=>
    │ It │
    ┼────┼
    │    │
    =#

    shape(unitknot)
    #-> ValueOf(Nothing)

A vector value is converted to a block.

    vecknot = convert(DataKnot, 'a':'c')
    #=>
      │ It │
    ──┼────┼
    1 │ a  │
    2 │ b  │
    3 │ c  │
    =#

    shape(vecknot)
    #-> BlockOf(Char)

A `Ref` object is converted into the referenced value.

    int_ty = convert(DataKnot, Base.broadcastable(Int))
    #=>
    │ It  │
    ┼─────┼
    │ Int │
    =#

    shape(int_ty)
    #-> ValueOf(Type{Int})


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

The table is truncated if it does not fit the output screen.

    small = IOContext(stdout, :displaysize => (6, 20))

    show(small, emp)
    #=>
      │ name       posi…
    ──┼────────────────…
    1 │ JEFFERY A  SERG…
    ⋮
    4 │ DANIEL A   FIRE…
    =#

Top-level tuples are serialized as table columns while nested tuples are
rendered as comma-separated lists of tuple elements.

    convert(DataKnot, ("FIRE", [("JEFFERY A", (101442, missing)), ("NANCY A", (80016, missing))]))
    #=>
    │ #A    #B                                                      │
    ┼───────────────────────────────────────────────────────────────┼
    │ FIRE  JEFFERY A, (101442, missing); NANCY A, (80016, missing) │
    =#

    convert(DataKnot, (name = "FIRE", employee = [(name = "JEFFERY A", compensation = (salary = 101442, rate = missing)),
                                                  (name = "NANCY A", compensation = (salary = 80016, rate = missing))]))
    #=>
    │ name  employee                                                │
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
    │ name  employee                                                │
    ┼───────────────────────────────────────────────────────────────┼
    │ FIRE  JEFFERY A, (101442, missing); NANCY A, (80016, missing) │
    =#

Similarly, top-level vectors are represented as table rows while nested vectors
are rendered as semicolon-separated lists.

    convert(DataKnot, [["JEFFERY A", "NANCY A"], ["JAMES A", "DANIEL A"]])
    #=>
      │ It                 │
    ──┼────────────────────┼
    1 │ JEFFERY A; NANCY A │
    2 │ JAMES A; DANIEL A  │
    =#

    convert(DataKnot, @VectorTree [String] [["JEFFERY A", "NANCY A"], ["JAMES A", "DANIEL A"]])
    #=>
      │ It                 │
    ──┼────────────────────┼
    1 │ JEFFERY A; NANCY A │
    2 │ JAMES A; DANIEL A  │
    =#

Integer numbers are right-aligned while decimal numbers are centered around the
decimal point.

    convert(DataKnot, [true, false])
    #=>
      │ It    │
    ──┼───────┼
    1 │  true │
    2 │ false │
    =#

    convert(DataKnot, [101442, 80016])
    #=>
      │ It     │
    ──┼────────┼
    1 │ 101442 │
    2 │  80016 │
    =#

    convert(DataKnot, [35.6, 2.65])
    #=>
      │ It    │
    ──┼───────┼
    1 │ 35.6  │
    2 │  2.65 │
    =#

