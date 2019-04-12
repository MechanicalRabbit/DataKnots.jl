# Column Store

This section describes how `DataKnots` implements an in-memory column store.
We will need the following definitions:

    using DataKnots:
        @VectorTree,
        BlockVector,
        Cardinality,
        TupleVector,
        cardinality,
        column,
        columns,
        elements,
        ismandatory,
        issingular,
        labels,
        offsets,
        width,
        x0to1,
        x0toN,
        x1to1,
        x1toN

## Tabular Data and `TupleVector`

Structured data can often be represented in a tabular form.  For example,
information about city employees can be arranged in the following table.

| name      | position          | salary  |
| --------- | ----------------- | ------- |
| JEFFERY A | SERGEANT          | 101442  |
| JAMES A   | FIRE ENGINEER-EMT | 103350  |
| TERRY A   | POLICE OFFICER    | 93354   |

Internally, a database engine stores tabular data using composite data
structures such as *tuples* and *vectors*.

A tuple is a fixed-size collection of heterogeneous values and can represent a
table row.

    (name = "JEFFERY A", position = "SERGEANT", salary = 101442)

A vector is a variable-size collection of homogeneous values and can store a
table column.

    ["JEFFERY A", "JAMES A", "TERRY A"]

For a table as a whole, we have two options: either store it as a vector of
tuples or store it as a tuple of vectors.  The former is called a *row-oriented
format*, commonly used in programming and traditional database engines.

    [(name = "JEFFERY A", position = "SERGEANT", salary = 101442),
     (name = "JAMES A", position = "FIRE ENGINEER-EMT", salary = 103350),
     (name = "TERRY A", position = "POLICE OFFICER", salary = 93354)]

The other option, "tuple of vectors" layout, is called a *column-oriented
format*.  It is often used by analytical databases as it is more suited for
processing complex analytical queries.

The `DataKnots` package implements data structures to support column-oriented
data format.  In particular, tabular data is represented using `TupleVector`
objects.

    TupleVector(:name => ["JEFFERY A", "JAMES A", "TERRY A"],
                :position => ["SERGEANT", "FIRE ENGINEER-EMT", "POLICE OFFICER"],
                :salary => [101442, 103350, 93354])

Since creating `TupleVector` objects by hand is tedious and error prone,
`DataKnots` provides a convenient macro `@VectorTree`, which lets you create
column-oriented data using regular tuple and vector literals.

    @VectorTree (name = String, position = String, salary = Int) [
        (name = "JEFFERY A", position = "SERGEANT", salary = 101442),
        (name = "JAMES A", position = "FIRE ENGINEER-EMT", salary = 103350),
        (name = "TERRY A", position = "POLICE OFFICER", salary = 93354),
    ]


## Hierarchical Data and `BlockVector`

Structured data could also be organized in hierarchical fashion.  For example,
consider a collection of departments, where each department contains a list of
associated employees.

| name    | employee           |
| ------- | ------------------ |
| POLICE  | JEFFERY A; NANCY A |
| FIRE    | JAMES A; DANIEL A  |
| OEMC    | LAKENYA A; DORIS A |

In the row-oriented format, this data is represented using nested vectors.

    [(name = "POLICE", employee = ["JEFFERY A", "NANCY A"]),
     (name = "FIRE", employee = ["JAMES A", "DANIEL A"]),
     (name = "OEMC", employee = ["LAKENYA A", "DORIS A"])]

To represent this data in column-oriented format, we need to serialize *name* and
*employee* as column vectors.  The *name* column is straightforward.

    name_col = ["POLICE", "FIRE", "OEMC"]

As for the *employee* column, naively, we could store it as a vector of
vectors.

    [["JEFFERY A", "NANCY A"], ["JAMES A", "DANIEL A"], ["LAKENYA A", "DORIS A"]]

However, this representation loses the advantages of the column-oriented format
since the data is no longer serialized with a fixed number of vectors.
Instead, we should keep the column data in a tightly-packed vector of
*elements*.

    employee_elts = ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"]

This vector could be partitioned into separate blocks by the vector of
*offsets*.

    employee_offs = [1, 3, 5, 7]

Each pair of adjacent offsets corresponds a slice of the element vector.

    employee_elts[employee_offs[1]:employee_offs[2]-1]
    #-> ["JEFFERY A", "NANCY A"]
    employee_elts[employee_offs[2]:employee_offs[3]-1]
    #-> ["JAMES A", "DANIEL A"]
    employee_elts[employee_offs[3]:employee_offs[4]-1]
    #-> ["LAKENYA A", "DORIS A"]

Together, elements and offsets faithfully reproduce the layout of the column.
A pair of the offset and the element vectors is encapsulated with a
`BlockVector` object, which represents a column-oriented encoding of a vector
of variable-size blocks.

    employee_col = BlockVector(employee_offs, employee_elts)

Now we can wrap the columns using `TupleVector`.

    TupleVector(:name => name_col, :employee => employee_col)

`@VectorTree` provides a convenient way to create `BlockVector` objects from
regular vector literals.

    @VectorTree (name = String, employee = (0:N)String) [
        (name = "POLICE", employee = ["JEFFERY A", "NANCY A"]),
        (name = "FIRE", employee = ["JAMES A", "DANIEL A"]),
        (name = "OEMC", employee = ["LAKENYA A", "DORIS A"]),
    ]


## Optional Values

As we arrange data in a tabular form, we may need to leave some cells blank.

For example, consider that a city employee could be compensated either with
salary or with hourly pay.  To display the compensation data in a table, we add
two columns: the annual salary and the hourly rate.  However, only one of the
columns per each row is filled.

| name      | position          | salary  | rate  |
| --------- | ----------------- | ------- | ----- |
| JEFFERY A | SERGEANT          | 101442  |       |
| JAMES A   | FIRE ENGINEER-EMT | 103350  |       |
| TERRY A   | POLICE OFFICER    | 93354   |       |
| LAKENYA A | CROSSING GUARD    |         | 17.68 |

As in the previous section, the cells in this table may contain a variable
number of values.  Therefore, the table columns could be represented using
`BlockVector` objects.  We start with packing the column data as element
vectors.

    salary_elts = [101442, 103350, 93354]
    rate_elts = [17.68]

Element vectors are partitioned into table cells by offset vectors.

    salary_offs = [1, 2, 3, 4, 4]
    rate_offs = [1, 1, 1, 1, 2]

The pairs of element and offset vectors are wrapped as `BlockVector` objects.

    salary_col = BlockVector(salary_offs, salary_elts, x0to1)
    rate_col = BlockVector(rate_offs, rate_elts, x0to1)

Here, the last parameter of the `BlockVector` constructor is the cardinality
constraint on the size of the blocks.  The constraint `x0to1` indicates that
each block should contain from 0 to 1 elements.  The default constraint `x0toN`
does not restrict the block size.

The first two columns of the table do not contain empty cells, and therefore
could be represented by regular vectors.  If we choose to wrap these columns
with `BlockVector`, we should use the constraint `x1to1` to indicate that each
block must contain exactly one element.  Alternatively, `BlockVector` provides
the following shorthand notation.

    name_col = BlockVector(:, ["JEFFERY A", "JAMES A", "TERRY A", "LAKENYA A"])
    position_col = BlockVector(:, ["SERGEANT", "FIRE ENGINEER-EMT", "POLICE OFFICER", "CROSSING GUARD"])

To represent the whole table, the columns should be wrapped with a
`TupleVector`.

    TupleVector(
        :name => name_col,
        :position => position_col,
        :salary => salary_col,
        :rate => rate_col)

As usual, we could create this data from tuple and vector literals.

    @VectorTree (name = (1:1)String,
                 position = (1:1)String,
                 salary = (0:1)Int,
                 rate = (0:1)Float64) [
        (name = "JEFFERY A", position = "SERGEANT", salary = 101442, rate = missing),
        (name = "JAMES A", position = "FIRE ENGINEER-EMT", salary = 103350, rate = missing),
        (name = "TERRY A", position = "POLICE OFFICER", salary = 93354, rate = missing),
        (name = "LAKENYA A", position = "CROSSING GUARD", salary = missing, rate = 17.68),
    ]


## Nested Data

When data does not fit a single table, it can often be presented in a top-down
fashion.  For example, HR data can be seen as a collection of departments, each
of which containing the associated employees.  Such data is serialized using
*nested* data structures, which, in row-oriented format, may look as follows:

    [(name = "POLICE",
      employee = [(name = "JEFFERY A", position = "SERGEANT", salary = 101442, rate = missing),
                  (name = "NANCY A", position = "POLICE OFFICER", salary = 80016, rate = missing)]),
     (name = "FIRE",
      employee = [(name = "JAMES A", position = "FIRE ENGINEER-EMT", salary = 103350, rate = missing),
                  (name = "DANIEL A", position = "FIRE FIGHTER-EMT", salary = 95484, rate = missing)]),
     (name = "OEMC",
      employee = [(name = "LAKENYA A", position = "CROSSING GUARD", salary = missing, rate = 17.68),
                  (name = "DORIS A", position = "CROSSING GUARD", salary = missing, rate = 19.38)])]

To store this data in a column-oriented format, we should use nested
`TupleVector` and `BlockVector` instances.  We start with representing employee
data.

    employee_elts =
        TupleVector(
            :name => ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"],
            :position => ["SERGEANT", "POLICE OFFICER", "FIRE ENGINEER-EMT", "FIRE FIGHTER-EMT", "CROSSING GUARD", "CROSSING GUARD"],
            :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484], x0to1),
            :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38], x0to1))

Then we partition employee data by departments:

    employee_col = BlockVector([1, 3, 5, 7], employee_elts)

Adding a column of department names, we obtain HR data in a column-oriented
format.

    TupleVector(
        :name => ["POLICE", "FIRE", "OEMC"],
        :employee => employee_col)

Another way to assemble this data in column-oriented format is to use
`@VectorTree`.

    @VectorTree (name = String,
                 employee = [(name = String,
                              position = String,
                              salary = (0:1)Int,
                              rate = (0:1)Float64)]) [
        (name = "POLICE",
         employee = [(name = "JEFFERY A", position = "SERGEANT", salary = 101442, rate = missing),
                     (name = "NANCY A", position = "POLICE OFFICER", salary = 80016, rate = missing)]),
        (name = "FIRE",
         employee = [(name = "JAMES A", position = "FIRE ENGINEER-EMT", salary = 103350, rate = missing),
                     (name = "DANIEL A", position = "FIRE FIGHTER-EMT", salary = 95484, rate = missing)]),
        (name = "OEMC",
         employee = [(name = "LAKENYA A", position = "CROSSING GUARD", salary = missing, rate = 17.68),
                     (name = "DORIS A", position = "CROSSING GUARD", salary = missing, rate = 19.38)])
    ]


## API Reference

```@autodocs
Modules = [DataKnots]
Pages = ["vectors.jl"]
Public = false
```


## Test Suite


### `TupleVector`

`TupleVector` is a vector of tuples stored as a collection of parallel vectors.

    tv = TupleVector(:name => ["GARRY M", "ANTHONY R", "DANA A"],
                     :salary => [260004, 185364, 170112])
    #-> @VectorTree (name = String, salary = Int64) [(name = "GARRY M", salary = 260004) … ]

    display(tv)
    #=>
    @VectorTree of 3 × (name = String, salary = Int64):
     (name = "GARRY M", salary = 260004)
     (name = "ANTHONY R", salary = 185364)
     (name = "DANA A", salary = 170112)
    =#

Labels could be specified by strings.

    TupleVector(:salary => [260004, 185364, 170112], "#B" => [true, false, false])
    #-> @VectorTree (salary = Int64, "#B" = Bool) [(salary = 260004, #B = 1) … ]

It is also possible to construct a `TupleVector` without labels.

    TupleVector(length(tv), columns(tv))
    #-> @VectorTree (String, Int64) [("GARRY M", 260004) … ]

An error is reported in case of duplicate labels or columns of different height.

    TupleVector(:name => ["GARRY M", "ANTHONY R"],
                :name => ["DANA A", "JUAN R"])
    #-> ERROR: duplicate column label :name

    TupleVector(:name => ["GARRY M", "ANTHONY R"],
                :salary => [260004, 185364, 170112])
    #-> ERROR: unexpected column height

We can access individual components of the vector.

    labels(tv)
    #-> Symbol[:name, :salary]

    width(tv)
    #-> 2

    column(tv, 2)
    #-> [260004, 185364, 170112]

    column(tv, :salary)
    #-> [260004, 185364, 170112]

    columns(tv)
    #-> …[["GARRY M", "ANTHONY R", "DANA A"], [260004, 185364, 170112]]

When indexed by another vector, we get a new instance of `TupleVector`.

    tv′ = tv[[3,1]]
    display(tv′)
    #=>
    @VectorTree of 2 × (name = String, salary = Int64):
     (name = "DANA A", salary = 170112)
     (name = "GARRY M", salary = 260004)
    =#

Note that the new instance wraps the index and the original column vectors.
Updated column vectors are generated on demand.

    column(tv′, 2)
    #-> [170112, 260004]

A labeled `TupleVector` supports a Tables.jl export interface.  For example,
we can convert a `TupleVector` instance to a `DataFrame`.

    using DataFrames

    tv |> DataFrame |> display
    #=>
    3×2 DataFrames.DataFrame
    │ Row │ name      │ salary │
    │     │ String    │ Int64  │
    ├─────┼───────────┼────────┤
    │ 1   │ GARRY M   │ 260004 │
    │ 2   │ ANTHONY R │ 185364 │
    │ 3   │ DANA A    │ 170112 │
    =#


### `Cardinality`

Enumerated type `Cardinality` is used to constrain the cardinality of a data
block.  There are four different cardinality constraints: *just one* `(1:1)`,
*zero or one* `(0:1)`, *one or many* `(1:N)`, and *zero or many* `(0:N)`.

    display(Cardinality)
    #=>
    Enum Cardinality:
    x1to1 = 0x00
    x0to1 = 0x01
    x1toN = 0x02
    x0toN = 0x03
    =#

Cardinality values could be obtained from the matching symbols.

    convert(Cardinality, :x1toN)
    #-> x1toN

Cardinality values support bitwise operations.

    x1to1|x0to1|x1toN           #-> x0toN
    x1toN&~x1toN                #-> x1to1

We can use predicates `ismandatory()` and `issingular()` to check if a
constraint is present.

    ismandatory(x0to1)          #-> false
    ismandatory(x1toN)          #-> true
    issingular(x1toN)           #-> false
    issingular(x0to1)           #-> true


### `BlockVector`

`BlockVector` is a vector of homogeneous vectors (blocks) stored as a vector of
elements partitioned into individual blocks by a vector of offsets.

    bv = BlockVector([1, 3, 5, 7], ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"])
    #-> @VectorTree (0:N) × String [["JEFFERY A", "NANCY A"], ["JAMES A", "DANIEL A"], ["LAKENYA A", "DORIS A"]]

    display(bv)
    #=>
    @VectorTree of 3 × (0:N) × String:
     ["JEFFERY A", "NANCY A"]
     ["JAMES A", "DANIEL A"]
     ["LAKENYA A", "DORIS A"]
    =#

We can indicate that each block should contain at most one element or at least
one element.

    BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38], x0to1)
    #-> @VectorTree (0:1) × Float64 [missing, missing, missing, missing, 17.68, 19.38]

    BlockVector([1, 3, 5, 7], ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"], x1toN)
    #-> @VectorTree (1:N) × String [["JEFFERY A", "NANCY A"], ["JAMES A", "DANIEL A"], ["LAKENYA A", "DORIS A"]]

If each block contains exactly one element, we could use `:` in place of the
offset vector.

    BlockVector(:, ["POLICE", "FIRE", "OEMC"])
    #-> @VectorTree (1:1) × String ["POLICE", "FIRE", "OEMC"]

The `BlockVector` constructor verifies that the offset vector is well-formed.

    BlockVector(Base.OneTo(0), [])
    #-> ERROR: offsets must be non-empty

    BlockVector(Int[], [])
    #-> ERROR: offsets must be non-empty

    BlockVector([0], [])
    #-> ERROR: offsets must start with 1

    BlockVector([1,2,2,1], ["HEALTH"])
    #-> ERROR: offsets must be monotone

    BlockVector(Base.OneTo(4), ["HEALTH", "FINANCE"])
    #-> ERROR: offsets must enclose the elements

    BlockVector([1,2,3,6], ["HEALTH", "FINANCE"])
    #-> ERROR: offsets must enclose the elements

The constructor also validates the cardinality constraint.

    BlockVector([1, 3, 5, 7], ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"], x0to1)
    #-> ERROR: singular blocks must have at most one element

    BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38], x1toN)
    #-> ERROR: mandatory blocks must have at least one element

We can access individual components of the vector.

    offsets(bv)
    #-> [1, 3, 5, 7]

    elements(bv)
    #-> ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"]

    cardinality(bv)
    #-> x0toN

When indexed by a vector of indexes, an instance of `BlockVector` is returned.

    elts = ["POLICE", "FIRE", "HEALTH", "AVIATION", "WATER MGMNT", "FINANCE"]

    reg_bv = BlockVector(:, elts)
    #-> @VectorTree (1:1) × String ["POLICE", "FIRE", "HEALTH", "AVIATION", "WATER MGMNT", "FINANCE"]

    opt_bv = BlockVector([1, 2, 3, 3, 4, 4, 5, 6, 6, 6, 7], elts, x0to1)
    #-> @VectorTree (0:1) × String ["POLICE", "FIRE", missing, "HEALTH", missing, "AVIATION", "WATER MGMNT", missing, missing, "FINANCE"]

    plu_bv = BlockVector([1, 1, 1, 2, 2, 4, 4, 6, 7], elts)
    #-> @VectorTree (0:N) × String [[], [], ["POLICE"], [], ["FIRE", "HEALTH"], [], ["AVIATION", "WATER MGMNT"], ["FINANCE"]]

    reg_bv[[1,3,5,3]]
    #-> @VectorTree (1:1) × String ["POLICE", "HEALTH", "WATER MGMNT", "HEALTH"]

    plu_bv[[1,3,5,3]]
    #-> @VectorTree (0:N) × String [[], ["POLICE"], ["FIRE", "HEALTH"], ["POLICE"]]

    reg_bv[Base.OneTo(4)]
    #-> @VectorTree (1:1) × String ["POLICE", "FIRE", "HEALTH", "AVIATION"]

    reg_bv[Base.OneTo(6)]
    #-> @VectorTree (1:1) × String ["POLICE", "FIRE", "HEALTH", "AVIATION", "WATER MGMNT", "FINANCE"]

    plu_bv[Base.OneTo(6)]
    #-> @VectorTree (0:N) × String [[], [], ["POLICE"], [], ["FIRE", "HEALTH"], []]

    opt_bv[Base.OneTo(10)]
    #-> @VectorTree (0:1) × String ["POLICE", "FIRE", missing, "HEALTH", missing, "AVIATION", "WATER MGMNT", missing, missing, "FINANCE"]


### `@VectorTree`

We can use `@VectorTree` macro to convert vector literals to the columnar form
assembled with `TupleVector` and `BlockVector` objects.

`TupleVector` is created from a matrix or a vector of (named) tuples.

    @VectorTree (name = String, salary = Int) [
        "GARRY M"   260004
        "ANTHONY R" 185364
        "DANA A"    170112
    ]
    #-> @VectorTree (name = String, salary = Int64) [(name = "GARRY M", salary = 260004) … ]

    @VectorTree (name = String, salary = Int) [
        ("GARRY M", 260004),
        ("ANTHONY R", 185364),
        ("DANA A", 170112),
    ]
    #-> @VectorTree (name = String, salary = Int64) [(name = "GARRY M", salary = 260004) … ]

    @VectorTree (name = String, salary = Int) [
        (name = "GARRY M", salary = 260004),
        (name = "ANTHONY R", salary = 185364),
        (name = "DANA A", salary = 170112),
    ]
    #-> @VectorTree (name = String, salary = Int64) [(name = "GARRY M", salary = 260004) … ]

Column labels are optional.

    @VectorTree (String, Int) ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112]
    #-> @VectorTree (String, Int64) [("GARRY M", 260004) … ]

`BlockVector` is constructed from a vector of vector literals.  A one-element
block could be represented by the element itself; an empty block by `missing`.

    @VectorTree [String] [
        "HEALTH",
        ["FINANCE", "HUMAN RESOURCES"],
        missing,
        ["POLICE", "FIRE"],
    ]
    #-> @VectorTree (0:N) × String [["HEALTH"], ["FINANCE", "HUMAN RESOURCES"], [], ["POLICE", "FIRE"]]

Ill-formed `@VectorTree` constructors are rejected.

    @VectorTree "String" ["POLICE", "FIRE"]
    #=>
    ERROR: expected a type; got "String"
    =#

    @VectorTree (String, Int) ("GARRY M", 260004)
    #=>
    ERROR: LoadError: expected a vector literal; got :(("GARRY M", 260004))
    ⋮
    =#

    @VectorTree (String, Int) [(position = "SUPERINTENDENT OF POLICE", salary = 260004)]
    #=>
    ERROR: LoadError: expected no label; got :(position = "SUPERINTENDENT OF POLICE")
    ⋮
    =#

    @VectorTree (name = String, salary = Int) [(position = "SUPERINTENDENT OF POLICE", salary = 260004)]
    #=>
    ERROR: LoadError: expected label :name; got :(position = "SUPERINTENDENT OF POLICE")
    ⋮
    =#

    @VectorTree (name = String, salary = Int) [("GARRY M", "SUPERINTENDENT OF POLICE", 260004)]
    #=>
    ERROR: LoadError: expected 2 column(s); got :(("GARRY M", "SUPERINTENDENT OF POLICE", 260004))
    ⋮
    =#

    @VectorTree (name = String, salary = Int) ["GARRY M"]
    #=>
    ERROR: LoadError: expected a tuple or a row literal; got "GARRY M"
    ⋮
    =#

Using `@VectorTree`, we can easily construct hierarchical data.

    hier_data = @VectorTree (name = (1:1)String, employee = (0:N)(name = (1:1)String, salary = (0:1)Int)) [
        "POLICE"    ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112]
        "FIRE"      ["JOSE S" 202728; "CHARLES S" 197736]
    ]
    display(hier_data)
    #=>
    @VectorTree of 2 × (name = (1:1) × String,
                        employee = (0:N) × (name = (1:1) × String,
                                            salary = (0:1) × Int64)):
     (name = "POLICE", employee = [(name = "GARRY M", salary = 260004) … ])
     (name = "FIRE", employee = [(name = "JOSE S", salary = 202728) … ])
    =#

