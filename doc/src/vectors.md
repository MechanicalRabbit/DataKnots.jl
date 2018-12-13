# Column Store


## Overview

This section describes how `DataKnots` implements an in-memory column store.
We will need the following definitions:

    using DataKnots:
        @VectorTree,
        OPT,
        PLU,
        REG,
        BlockVector,
        Cardinality,
        TupleVector,
        cardinality,
        column,
        columns,
        elements,
        isoptional,
        isplural,
        isregular,
        labels,
        offsets,
        width


### Tabular data

Structured data can often be represented in a tabular form.  For example,
information about city employees can be arranged in the following table.

| name      | position          | salary    |
| --------- | ----------------- | --------- |
| JEFFERY A | SERGEANT          | 101442    |
| JAMES A   | FIRE ENGINEER-EMT | 103350    |
| TERRY A   | POLICE OFFICER    | 93354     |

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

The module `DataKnot` implements data structures to support column-oriented
data format.  In particular, tabular data is represented using `TupleVector`
objects.

    TupleVector(:name => ["JEFFERY A", "JAMES A", "TERRY A"],
                :position => ["SERGEANT", "FIRE ENGINEER-EMT", "POLICE OFFICER"],
                :salary => [101442, 103350, 93354])


### Blank cells

As we arrange data in a tabular form, we may need to leave some cells blank.

For example, consider that a city employee could be compensated either with
salary or with hourly pay.  To display the compensation data in a table, we add
two columns: the annual salary and the hourly rate.  However, only one of the
columns per each row is filled.

| name      | position          | salary    | rate  |
| --------- | ----------------- | --------- | ----- |
| JEFFERY A | SERGEANT          | 101442    |       |
| JAMES A   | FIRE ENGINEER-EMT | 103350    |       |
| TERRY A   | POLICE OFFICER    | 93354     |       |
| LAKENYA A | CROSSING GUARD    |           | 17.68 |

How can this data be serialized in a column-oriented format?  To retain the
advantages of the format, we'd like to keep the column data in tightly packed
vectors of *elements*.

    name_elts = ["JEFFERY A", "JAMES A", "TERRY A", "LAKENYA A"]
    position_elts = ["SERGEANT", "FIRE ENGINEER-EMT", "POLICE OFFICER", "CROSSING GUARD"]
    salary_elts = [101442, 103350, 93354]
    rate_elts = [17.68]

These vectors are partitioned into table cells by the vectors of *offsets*.

    name_offs = [1, 2, 3, 4, 5]
    position_offs = [1, 2, 3, 4, 5]
    salary_offs = [1, 2, 3, 4, 4]
    rate_offs = [1, 1, 1, 1, 2]

Each pair of adjacent offsets maps a slice of the element vector to the
corresponding column cell.  For example, here is how we fetch the 4-th row of
the table:

    (name_elts[name_offs[4]:name_offs[5]-1],
     position_elts[position_offs[4]:position_offs[5]-1],
     salary_elts[salary_offs[4]:salary_offs[5]-1],
     rate_elts[rate_offs[4]:rate_offs[5]-1])
    #-> (["LAKENYA A"], ["CROSSING GUARD"], Int[], [17.68])

Together, elements and offsets faithfully reproduce the layout of the column.
A pair of the offset and the element vectors is encapsulated with a
`BlockVector` instance.

    name_col = BlockVector(name_offs, name_elts, REG)
    position_col = BlockVector(position_offs, position_elts, REG)
    salary_col = BlockVector(salary_offs, salary_elts, OPT)
    rate_col = BlockVector(rate_offs, rate_elts, OPT)

`BlockVector` is a column-oriented encoding of a vector of variable-size
blocks.  The last parameter of the `BlockVector` constructor is the
*cardinality* constraint on the size of the blocks.  `REG` indicates that each
block has exactly one element; `OPT` allows a block to be empty.  The
constraint `PLU` is used to indicate that a block may contain more than one
element.

In this specific case, each block corresponds to a table cell: an empty block
to a blank cell and a one-element block to a filled cell.  To represent the
whole table, the columns should be wrapped with a `TupleVector`.

    TupleVector(
        :name => name_col,
        :position => position_col,
        :salary => salary_col,
        :rate => rate_col)


### Nested data

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
            :name => BlockVector(:, ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"]),
            :position => BlockVector(:, ["SERGEANT", "POLICE OFFICER", "FIRE ENGINEER-EMT", "FIRE FIGHTER-EMT", "CROSSING GUARD", "CROSSING GUARD"]),
            :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484], OPT),
            :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38], OPT))

Then we partition employee data by departments:

    employee_col = BlockVector([1, 3, 5, 7], employee_elts, PLU)

Adding a column of department names, we obtain HR data in a column-oriented
format.

    TupleVector(
        :name => BlockVector(:, ["POLICE", "FIRE", "OEMC"]),
        :employee => employee_col)

Since writing offset vectors manually is tedious, `DataKnots` provides a
convenient macro `@VectorTree`, which lets you specify column-oriented data
using regular tuple and vector literals.

    @VectorTree (name = [String, REG],
                 employee = [(name = [String, REG],
                              position = [String, REG],
                              salary = [Int, OPT],
                              rate = [Float64, OPT]), PLU]) [
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
```


## Test Suite


### `TupleVector`

`TupleVector` is a vector of tuples stored as a collection of parallel vectors.

    tv = TupleVector(:name => ["GARRY M", "ANTHONY R", "DANA A"],
                     :salary => [260004, 185364, 170112])
    #-> @VectorTree (name = String, salary = Int) [(name = "GARRY M", salary = 260004) … ]

    display(tv)
    #=>
    TupleVector of 3 × (name = String, salary = Int):
     (name = "GARRY M", salary = 260004)
     (name = "ANTHONY R", salary = 185364)
     (name = "DANA A", salary = 170112)
    =#

It is possible to construct a `TupleVector` without labels.

    TupleVector(length(tv), columns(tv))
    #-> @VectorTree (String, Int) [("GARRY M", 260004) … ]

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
    TupleVector of 2 × (name = String, salary = Int):
     (name = "DANA A", salary = 170112)
     (name = "GARRY M", salary = 260004)
    =#

Note that the new instance wraps the index and the original column vectors.
Updated column vectors are generated on demand.

    column(tv′, 2)
    #-> [170112, 260004]


### `Cardinality`

Enumerated type `Cardinality` is used to constrain the cardinality of a data
block.  A block of data is called *regular* if it must contain exactly one
element; *optional* if it may have no elements; and *plural* if it may have
more than one element.  This gives us four different cardinality constraints.

    display(Cardinality)
    #=>
    Enum Cardinality:
    REG = 0x00
    OPT = 0x01
    PLU = 0x02
    OPT_PLU = 0x03
    =#

Cardinality values support bitwise operations.

    REG|OPT|PLU             #-> OPT_PLU::Cardinality = 3
    PLU&~PLU                #-> REG::Cardinality = 0

We can use predicates `isregular()`, `isoptional()`, `isplural()` to check
cardinality values.

    isregular(REG)          #-> true
    isregular(OPT)          #-> false
    isregular(PLU)          #-> false
    isoptional(OPT)         #-> true
    isoptional(PLU)         #-> false
    isplural(PLU)           #-> true
    isplural(OPT)           #-> false


### `BlockVector`

`BlockVector` is a vector of homogeneous vectors (blocks) stored as a vector of
elements partitioned into individual blocks by a vector of offsets.

    bv = BlockVector([1, 3, 5, 7], ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"], PLU)
    #-> @VectorTree [String, PLU] [["JEFFERY A", "NANCY A"], ["JAMES A", "DANIEL A"], ["LAKENYA A", "DORIS A"]]

    display(bv)
    #=>
    BlockVector of 3 × [String, PLU]:
     ["JEFFERY A", "NANCY A"]
     ["JAMES A", "DANIEL A"]
     ["LAKENYA A", "DORIS A"]
    =#

If each block contains exactly one element, we could use `:` in place of the
offset vector.

    BlockVector(:, ["POLICE", "FIRE", "OEMC"])
    #-> @VectorTree [String, REG] ["POLICE", "FIRE", "OEMC"]

The `BlockVector` constructor verifies that the offset vector is well-formed.

    BlockVector(Base.OneTo(0), [])
    #-> ERROR: partition must be non-empty

    BlockVector(Int[], [])
    #-> ERROR: partition must be non-empty

    BlockVector([0], [])
    #-> ERROR: partition must start with 1

    BlockVector([1,2,2,1], ["HEALTH"])
    #-> ERROR: partition must be monotone

    BlockVector(Base.OneTo(4), ["HEALTH", "FINANCE"])
    #-> ERROR: partition must enclose the elements

    BlockVector([1,2,3,6], ["HEALTH", "FINANCE"])
    #-> ERROR: partition must enclose the elements

The constructor also validates the cardinality constraint.

    BlockVector([1, 3, 5, 7], ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"], OPT)
    #-> ERROR: singular blocks must have at most one element

    BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38], REG)
    #-> ERROR: mandatory blocks must have at least one element

We can access individual components of the vector.

    offsets(bv)
    #-> [1, 3, 5, 7]

    elements(bv)
    #-> ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"]

    cardinality(bv)
    #-> PLU::Cardinality = 2

When indexed by a vector of indexes, an instance of `BlockVector` is returned.

    elts = ["POLICE", "FIRE", "HEALTH", "AVIATION", "WATER MGMNT", "FINANCE"]

    reg_bv = BlockVector(:, elts, REG)
    #-> @VectorTree [String, REG] ["POLICE", "FIRE", "HEALTH", "AVIATION", "WATER MGMNT", "FINANCE"]

    opt_bv = BlockVector([1, 2, 3, 3, 4, 4, 5, 6, 6, 6, 7], elts, OPT)
    #-> @VectorTree [String, OPT] ["POLICE", "FIRE", missing, "HEALTH", missing, "AVIATION", "WATER MGMNT", missing, missing, "FINANCE"]

    plu_bv = BlockVector([1, 1, 1, 2, 2, 4, 4, 6, 7], elts, OPT|PLU)
    #-> @VectorTree [String] [[], [], ["POLICE"], [], ["FIRE", "HEALTH"], [], ["AVIATION", "WATER MGMNT"], ["FINANCE"]]

    reg_bv[[1,3,5,3]]
    #-> @VectorTree [String, REG] ["POLICE", "HEALTH", "WATER MGMNT", "HEALTH"]

    plu_bv[[1,3,5,3]]
    #-> @VectorTree [String] [[], ["POLICE"], ["FIRE", "HEALTH"], ["POLICE"]]

    reg_bv[Base.OneTo(4)]
    #-> @VectorTree [String, REG] ["POLICE", "FIRE", "HEALTH", "AVIATION"]

    reg_bv[Base.OneTo(6)]
    #-> @VectorTree [String, REG] ["POLICE", "FIRE", "HEALTH", "AVIATION", "WATER MGMNT", "FINANCE"]

    plu_bv[Base.OneTo(6)]
    #-> @VectorTree [String] [[], [], ["POLICE"], [], ["FIRE", "HEALTH"], []]

    opt_bv[Base.OneTo(10)]
    #-> @VectorTree [String, OPT] ["POLICE", "FIRE", missing, "HEALTH", missing, "AVIATION", "WATER MGMNT", missing, missing, "FINANCE"]


### `@VectorTree`

We can use `@VectorTree` macro to convert vector literals to the columnar form
assembled with `TupleVector` and `BlockVector` objects.

`TupleVector` is created from a matrix or a vector of (named) tuples.

    @VectorTree (name = String, salary = Int) [
        "GARRY M"   260004
        "ANTHONY R" 185364
        "DANA A"    170112
    ]
    #-> @VectorTree (name = String, salary = Int) [(name = "GARRY M", salary = 260004) … ]

    @VectorTree (name = String, salary = Int) [
        ("GARRY M", 260004),
        ("ANTHONY R", 185364),
        ("DANA A", 170112),
    ]
    #-> @VectorTree (name = String, salary = Int) [(name = "GARRY M", salary = 260004) … ]

    @VectorTree (name = String, salary = Int) [
        (name = "GARRY M", salary = 260004),
        (name = "ANTHONY R", salary = 185364),
        (name = "DANA A", salary = 170112),
    ]
    #-> @VectorTree (name = String, salary = Int) [(name = "GARRY M", salary = 260004) … ]

Column labels are optional.

    @VectorTree (String, Int) ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112]
    #-> @VectorTree (String, Int) [("GARRY M", 260004) … ]

`BlockVector` is constructed from a vector of vector literals.  A one-element
block could be represented by the element itself; an empty block by `missing`.

    @VectorTree [String] [
        "HEALTH",
        ["FINANCE", "HUMAN RESOURCES"],
        missing,
        ["POLICE", "FIRE"],
    ]
    #-> @VectorTree [String] [["HEALTH"], ["FINANCE", "HUMAN RESOURCES"], [], ["POLICE", "FIRE"]]

Ill-formed `@VectorTree` contructors are rejected.

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

    hier_data = @VectorTree (name = [String, REG], employee = [(name = [String, REG], salary = [Int, OPT])]) [
        "POLICE"    ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112]
        "FIRE"      ["JOSE S" 202728; "CHARLES S" 197736]
    ]
    display(hier_data)
    #=>
    TupleVector of 2 × (name = [String, REG], employee = [(name = [String, REG], salary = [Int, OPT])]):
     (name = "POLICE", employee = [(name = "GARRY M", salary = 260004) … ])
     (name = "FIRE", employee = [(name = "JOSE S", salary = 202728) … ])
    =#

