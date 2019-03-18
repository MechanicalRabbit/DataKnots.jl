# Data Knots


## Overview

A `DataKnot` object contains a single data value serialized in a
column-oriented form.

    using DataKnots:
        @VectorTree,
        DataKnot,
        It,
        cell,
        shape

Any Julia value can be converted to a `DataKnot`.

    hello = DataKnot("Hello World!")
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

A `DataKnot` object is created from a one-element vector and its shape.

    DataKnot(["Hello World"], String)
    #=>
    │ It          │
    ┼─────────────┼
    │ Hello World │
    =#

It is an error to provide a vector of a length different from 1.

    DataKnot(String[], String)
    #-> ERROR: AssertionError: length(cell) == 1

Any Julia value can be converted to a `DataKnot` object using the `convert()`
function or a one-argument `DataKnot` constructor.

    convert(DataKnot, "Hello World!")
    #=>
    │ It           │
    ┼──────────────┼
    │ Hello World! │
    =#

    hello = DataKnot("Hello World!")
    #=>
    │ It           │
    ┼──────────────┼
    │ Hello World! │
    =#

Scalar values are stored as is.

    shape(hello)
    #-> ValueOf(String)

The value `missing` is converted to an empty `DataKnot`.

    null = DataKnot(missing)
    #=>
    │ It │
    ┼────┼
    =#

    shape(null)
    #-> BlockOf(NoShape(), x0to1)

The value `nothing` is converted to the void `DataKnot`.  The same `DataKnot`
is created by the constructor with no arguments.

    void = DataKnot()
    #=>
    │ It │
    ┼────┼
    │    │
    =#

    shape(void)
    #-> ValueOf(Nothing)

A vector value is converted to a block.

    blk = DataKnot('a':'c')
    #=>
      │ It │
    ──┼────┼
    1 │ a  │
    2 │ b  │
    3 │ c  │
    =#

    shape(blk)
    #-> BlockOf(Char)

By default, the block has no cardinality constraint, but we could specify it
explicitly.

    int_null = DataKnot(Int[], :x0to1)
    #=>
    │ It │
    ┼────┼
    =#

    shape(int_null)
    #-> BlockOf(Int, x0to1)

A `Ref` object is converted into the referenced value.

    int_ty = DataKnot(Base.broadcastable(Int))
    #=>
    │ It  │
    ┼─────┼
    │ Int │
    =#

    shape(int_ty)
    #-> ValueOf(Type{Int})


### Rendering

On output, a `DataKnot` object is rendered as a table.

    emp = DataKnot([(name = "JEFFERY A", position = "SERGEANT", salary = 101442),
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

    DataKnot(("FIRE", [("JEFFERY A", (101442, missing)), ("NANCY A", (80016, missing))]))
    #=>
    │ #A    #B                                                      │
    ┼───────────────────────────────────────────────────────────────┼
    │ FIRE  JEFFERY A, (101442, missing); NANCY A, (80016, missing) │
    =#

    DataKnot((name = "FIRE", employee = [(name = "JEFFERY A", compensation = (salary = 101442, rate = missing)),
                                         (name = "NANCY A", compensation = (salary = 80016, rate = missing))]))
    #=>
    │ name  employee                                                │
    ┼───────────────────────────────────────────────────────────────┼
    │ FIRE  JEFFERY A, (101442, missing); NANCY A, (80016, missing) │
    =#

    DataKnot(
        @VectorTree((name = (1:1)String,
                     employee = [(name = (1:1)String,
                                  compensation = (1:1)(salary = (0:1)Int,
                                                       rate = (0:1)Float64))]), [
            (name = "FIRE", employee = [(name = "JEFFERY A", compensation = (salary = 101442, rate = missing)),
                                        (name = "NANCY A", compensation = (salary = 80016, rate = missing))])]),
        :x1to1)

    #=>
    │ name  employee                                                │
    ┼───────────────────────────────────────────────────────────────┼
    │ FIRE  JEFFERY A, (101442, missing); NANCY A, (80016, missing) │
    =#

Similarly, top-level vectors are represented as table rows while nested vectors
are rendered as semicolon-separated lists.

    DataKnot([["JEFFERY A", "NANCY A"], ["JAMES A", "DANIEL A"]])
    #=>
      │ It                 │
    ──┼────────────────────┼
    1 │ JEFFERY A; NANCY A │
    2 │ JAMES A; DANIEL A  │
    =#

    DataKnot(@VectorTree [String] [["JEFFERY A", "NANCY A"], ["JAMES A", "DANIEL A"]])
    #=>
      │ It                 │
    ──┼────────────────────┼
    1 │ JEFFERY A; NANCY A │
    2 │ JAMES A; DANIEL A  │
    =#

Integer numbers are right-aligned while decimal numbers are centered around the
decimal point.

    DataKnot([true, false])
    #=>
      │ It    │
    ──┼───────┼
    1 │  true │
    2 │ false │
    =#

    DataKnot([101442, 80016])
    #=>
      │ It     │
    ──┼────────┼
    1 │ 101442 │
    2 │  80016 │
    =#

    DataKnot([35.6, 2.65])
    #=>
      │ It    │
    ──┼───────┼
    1 │ 35.6  │
    2 │  2.65 │
    =#

