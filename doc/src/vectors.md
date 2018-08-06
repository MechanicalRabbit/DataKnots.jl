# Column Store


## Overview

Module `DataKnots.Vectors` implements an in-memory column store.

    using DataKnots.Vectors


### Tabular data

Structured data can often be represented in a tabular form.  For example,
information about city employees can be arranged in the following table.

| name      | position          | salary    |
| --------- | ----------------- | --------- |
| JEFFERY A | SERGEANT          | 101442    |
| JAMES A   | FIRE ENGINEER-EMT | 103350    |
| TERRY A   | POLICE OFFICER    | 93354     |

Internally, a database engine can store tabular data using composite data
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

The "tuple of vectors" layout is called a *column-oriented format*.  It is
often used by analytical databases as it is more suited for processing complex
analytical queries.

The module `DataKnots.Vectors` implements necessary data structures to support
column-oriented data format.  In particular, tabular data is represented using
`TupleVector` objects.

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

    ["JEFFERY A", "JAMES A", "TERRY A", "LAKENYA A"]
    ["SERGEANT", "FIRE ENGINEER-EMT", "POLICE OFFICER", "CROSSING GUARD"]
    [101442, 103350, 93354]
    [17.68]

Vectors of elements are partitioned into individual cells by the vectors of
*offsets*.

    [1, 2, 3, 4, 5]
    [1, 2, 3, 4, 5]
    [1, 2, 3, 4, 4]
    [1, 1, 1, 1, 2]

Together, elements and offsets faithfully reproduce the layout of the table
columns.  A pair of the offset and the element vectors is encapsulated with a
`BlockVector` instance.

    BlockVector(:, ["JEFFERY A", "JAMES A", "TERRY A", "LAKENYA A"])
    BlockVector(:, ["SERGEANT", "FIRE ENGINEER-EMT", "POLICE OFFICER", "CROSSING GUARD"])
    BlockVector([1, 2, 3, 4, 4], [101442, 103350, 93354])
    BlockVector([1, 1, 1, 1, 2], [17.68])

Here, the symbol `:` is used as a shortcut for a unit range vector.

A `BlockVector` instance is a column-oriented encoding of a vector of
variable-size blocks.  In this specific case, each block corresponds to a table
cell: an empty block for a blank cell and a one-element block for a filled
cell.

    [["JEFFERY A"], ["JAMES A"], ["TERRY A"], ["LAKENYA A"]]
    [["SERGEANT"], ["FIRE ENGINEER-EMT"], ["POLICE OFFICER"], ["CROSSING GUARD"]]
    [[101442], [103350], [93354], []]
    [[], [], [], [17.68]]

To represent the whole table, the columns should be wrapped with a
`TupleVector`.

    TupleVector(
        :name => BlockVector(:, ["JEFFERY A", "JAMES A", "TERRY A", "LAKENYA A"]),
        :position => BlockVector(:, ["SERGEANT", "FIRE ENGINEER-EMT", "POLICE OFFICER", "CROSSING GUARD"]),
        :salary => BlockVector([1, 2, 3, 4, 4], [101442, 103350, 93354]),
        :rate => BlockVector([1, 1, 1, 1, 2], [17.68]))


### Nested data

When data does not fit a single table, it can often be presented in a top-down
fashion.  For example, HR data can be seen as a collection of departments, each
of which containing the associated employees.

Such data is serialized using *nested* data structures.

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

    TupleVector(
        :name => BlockVector(:, ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"]),
        :position => BlockVector(:, ["SERGEANT", "POLICE OFFICER", "FIRE ENGINEER-EMT", "FIRE FIGHTER-EMT", "CROSSING GUARD", "CROSSING GUARD"]),
        :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484]),
        :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38]))

The aggregated employee data could be partitioned to individual departments
using a vector of offsets.

    BlockVector(
        [1, 3, 5, 7],
        TupleVector(
            :name => BlockVector(:, ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"]),
            :position => BlockVector(:, ["SERGEANT", "POLICE OFFICER", "FIRE ENGINEER-EMT", "FIRE FIGHTER-EMT", "CROSSING GUARD", "CROSSING GUARD"]),
            :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484]),
            :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38])))

Adding a column of department names, we obtain HR data in a column-oriented
format.

    TupleVector(
        :name => BlockVector(:, ["POLICE", "FIRE", "OEMC"]),
        :employee =>
            BlockVector(
                [1, 3, 5, 7],
                TupleVector(
                    :name => BlockVector(:, ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"]),
                    :position => BlockVector(:, ["SERGEANT", "POLICE OFFICER", "FIRE ENGINEER-EMT", "FIRE FIGHTER-EMT", "CROSSING GUARD", "CROSSING GUARD"]),
                    :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484]),
                    :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38]))))

Since writing offset vectors manually is tedious, `DataKnots` provides a
convenient macro `@VectorTree`, which lets you specify column-oriented data
using regular tuple and vector literals.

    @VectorTree (name = [String],
                 employee = [(name = [String], position = [String], salary = [Int], rate = [Float64])]) [
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


### Circular data

Some relationships cannot be represented using tabular or nested data
structures.  Consider, for example, the relationship between an employee and
their manager.  To serialize this relationship, we need to use references.

    emp_1 = (name = "RHAM E", position = "MAYOR", manager = missing)
    emp_2 = (name = "EDDIE J", position = "SUPERINTENDENT OF POLICE", manager = emp_1)
    emp_3 = (name = "KEVIN N", position = "FIRST DEPUTY SUPERINTENDENT", manager = emp_2)
    emp_4 = (name = "FRED W", position = "CHIEF", manager = emp_2)

In the column-oriented format, we replace references with array indexes.

    [1, 2, 2]

To specify the name of the target array, we wrap the indexes with an
`IndexVector` instance.

    IndexVector(:EMP, [1, 2, 2])

After adding the regular columns, we obtain the following structure.

    TupleVector(
        :name => BlockVector(:, ["RHAM E", "EDDIE J", "KEVIN N", "FRED W"]),
        :position => BlockVector(:, ["MAYOR", "SUPERINTENDENT OF POLICE", "FIRST DEPUTY SUPERINTENDENT", "CHIEF"]),
        :manager => BlockVector([1, 1, 2, 3, 4], IndexVector(:EMP, [1, 2, 2])))

We still need to associate the array name `EMP` with the actual array.  This
array is provided by a `CapsuleVector` instance.

    CapsuleVector(
        IndexVector(:EMP, 1:4),
        :EMP =>
            TupleVector(
                :name => BlockVector(:, ["RHAM E", "EDDIE J", "KEVIN N", "FRED W"]),
                :position => BlockVector(:, ["MAYOR", "SUPERINTENDENT OF POLICE", "FIRST DEPUTY SUPERINTENDENT", "CHIEF"]),
                :manager => BlockVector([1, 1, 2, 3, 4], IndexVector(:EMP, [1, 2, 2]))))


### Databases

Using a combination of `TupleVector`, `BlockVector`, and `IndexVector` wrapped
in a `CapsuleVector` instance, we can serialize an entire database in a
column-oriented format.

For example, consider a database with two types of entities: *departments* and
*employees*, where each employee belongs to a department.  Two collections
of entities can be represented as follows.

    TupleVector(
        :name => BlockVector(:, ["POLICE", "FIRE", "OEMC"]),
        :employee => BlockVector([1, 3, 5, 7], IndexVector(:EMP, [1, 2, 3, 4, 5, 6])))

    TupleVector(
        :name => BlockVector(:, ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"]),
        :department => BlockVector(:, IndexVector(:DEPT, [1, 1, 2, 2, 3, 3])),
        :position => BlockVector(:, ["SERGEANT", "POLICE OFFICER", "FIRE ENGINEER-EMT", "FIRE FIGHTER-EMT", "CROSSING GUARD", "CROSSING GUARD"]),
        :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484]),
        :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38]))

The collections are linked to each other with a pair of `IndexVector` instances.

In addition, we create the database *root*, which contains indexes to each entity
array.

    TupleVector(
        :department => BlockVector([1, 4], IndexVector(:DEPT, 1:3)),
        :employee => BlockVector([1, 7], IndexVector(:EMP, 1:6)))

The database root is wrapped in a `CapsuleVector` to provide the arrays `DEPT`
and `EMP`.

    CapsuleVector(
        TupleVector(
            :department => BlockVector([1, 4], IndexVector(:DEPT, 1:3)),
            :employee => BlockVector([1, 7], IndexVector(:EMP, 1:6))),
        :DEPT =>
            TupleVector(
                :name => BlockVector(:, ["POLICE", "FIRE", "OEMC"]),
                :employee => BlockVector([1, 3, 5, 7], IndexVector(:EMP, [1, 2, 3, 4, 5, 6]))),
        :EMP =>
            TupleVector(
                :name => BlockVector(:, ["JEFFERY A", "NANCY A", "JAMES A", "DANIEL A", "LAKENYA A", "DORIS A"]),
                :department => BlockVector(:, IndexVector(:DEPT, [1, 1, 2, 2, 3, 3])),
                :position => BlockVector(:, ["SERGEANT", "POLICE OFFICER", "FIRE ENGINEER-EMT", "FIRE FIGHTER-EMT", "CROSSING GUARD", "CROSSING GUARD"]),
                :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484]),
                :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38])))


## API Reference

```@docs
DataKnots.Vectors.TupleVector
DataKnots.Vectors.BlockVector
DataKnots.Vectors.IndexVector
DataKnots.Vectors.CapsuleVector
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

Note that the new instance keeps a reference to the index and the original
column vectors.  Updated column vectors are generated on demand.

    column(tv′, 2)
    #-> [170112, 260004]


### `BlockVector`

`BlockVector` is a vector of homogeneous vectors (blocks) stored as a vector of
elements partitioned into individual blocks by a vector of offsets.

    bv = BlockVector([["HEALTH"], ["FINANCE", "HUMAN RESOURCES"], [], ["POLICE", "FIRE"]])
    #-> @VectorTree [String] ["HEALTH", ["FINANCE", "HUMAN RESOURCES"], missing, ["POLICE", "FIRE"]]

    display(bv)
    #=>
    BlockVector of 4 × [String]:
     "HEALTH"
     ["FINANCE", "HUMAN RESOURCES"]
     missing
     ["POLICE", "FIRE"]
    =#

We can omit brackets for singular blocks and use `missing` in place of empty
blocks.

    BlockVector(["HEALTH", ["FINANCE", "HUMAN RESOURCES"], missing, ["POLICE", "FIRE"]])
    #-> @VectorTree [String] ["HEALTH", ["FINANCE", "HUMAN RESOURCES"], missing, ["POLICE", "FIRE"]]

It is possible to specify the offset and the element vectors separately.

    BlockVector([1, 2, 4, 4, 6], ["HEALTH", "FINANCE", "HUMAN RESOURCES", "POLICE", "FIRE"])
    #-> @VectorTree [String] ["HEALTH", ["FINANCE", "HUMAN RESOURCES"], missing, ["POLICE", "FIRE"]]

If each block contains exactly one element, we could use `:` in place of the
offset vector.

    BlockVector(:, ["HEALTH", "FINANCE", "HUMAN RESOURCES", "POLICE", "FIRE"])
    #-> @VectorTree [String] ["HEALTH", "FINANCE", "HUMAN RESOURCES", "POLICE", "FIRE"]

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

We can access individual components of the vector.

    offsets(bv)
    #-> [1, 2, 4, 4, 6]

    elements(bv)
    #-> ["HEALTH", "FINANCE", "HUMAN RESOURCES", "POLICE", "FIRE"]

    partition(bv)
    #-> ([1, 2, 4, 4, 6], ["HEALTH", "FINANCE", "HUMAN RESOURCES", "POLICE", "FIRE"])

When indexed by a vector of indexes, an instance of `BlockVector` is returned.

    elts = ["POLICE", "FIRE", "HEALTH", "AVIATION", "WATER MGMNT", "FINANCE"]

    reg_bv = BlockVector(:, elts)
    #-> @VectorTree [String] ["POLICE", "FIRE", "HEALTH", "AVIATION", "WATER MGMNT", "FINANCE"]

    opt_bv = BlockVector([1, 2, 3, 3, 4, 4, 5, 6, 6, 6, 7], elts)
    #-> @VectorTree [String] ["POLICE", "FIRE", missing, "HEALTH", missing, "AVIATION", "WATER MGMNT", missing, missing, "FINANCE"]

    plu_bv = BlockVector([1, 1, 1, 2, 2, 4, 4, 6, 7], elts)
    #-> @VectorTree [String] [missing, missing, "POLICE", missing, ["FIRE", "HEALTH"], missing, ["AVIATION", "WATER MGMNT"], "FINANCE"]

    reg_bv[[1,3,5,3]]
    #-> @VectorTree [String] ["POLICE", "HEALTH", "WATER MGMNT", "HEALTH"]

    plu_bv[[1,3,5,3]]
    #-> @VectorTree [String] [missing, "POLICE", ["FIRE", "HEALTH"], "POLICE"]

    reg_bv[Base.OneTo(4)]
    #-> @VectorTree [String] ["POLICE", "FIRE", "HEALTH", "AVIATION"]

    reg_bv[Base.OneTo(6)]
    #-> @VectorTree [String] ["POLICE", "FIRE", "HEALTH", "AVIATION", "WATER MGMNT", "FINANCE"]

    plu_bv[Base.OneTo(6)]
    #-> @VectorTree [String] [missing, missing, "POLICE", missing, ["FIRE", "HEALTH"], missing]

    opt_bv[Base.OneTo(10)]
    #-> @VectorTree [String] ["POLICE", "FIRE", missing, "HEALTH", missing, "AVIATION", "WATER MGMNT", missing, missing, "FINANCE"]


### `IndexVector`

`IndexVector` is a vector of indexes in some named vector.

    iv = IndexVector(:REF, [1, 1, 1, 2])
    #-> @VectorTree &REF [1, 1, 1, 2]

    display(iv)
    #=>
    IndexVector of 4 × &REF:
     1
     1
     1
     2
    =#

We can obtain the components of the vector.

    identifier(iv)
    #-> :REF

    indexes(iv)
    #-> [1, 1, 1, 2]

Indexing an `IndexVector` by a vector produces another `IndexVector` instance.

    iv[[4,2]]
    #-> @VectorTree &REF [2, 1]

`IndexVector` can be deferenced against a list of named vectors.

    refv = ["COMISSIONER", "DEPUTY COMISSIONER", "ZONING ADMINISTRATOR", "PROJECT MANAGER"]

    dereference(iv, [:REF => refv])
    #-> ["COMISSIONER", "COMISSIONER", "COMISSIONER", "DEPUTY COMISSIONER"]

Function `dereference()` has no effect on other types of vectors, or when the
desired reference vector is not in the list.

    dereference(iv, [:REF′ => refv])
    #-> @VectorTree &REF [1, 1, 1, 2]

    dereference([1, 1, 1, 2], [:REF => refv])
    #-> [1, 1, 1, 2]


### `CapsuleVector`

`CapsuleVector` provides references for a composite vector with nested indexes.
We use `CapsuleVector` to represent self-referential and mutually referential
data.

    cv = CapsuleVector(TupleVector(:ref => iv), :REF => refv)
    #-> @VectorTree (ref = &REF,) [(ref = 1,), (ref = 1,), (ref = 1,), (ref = 2,)] where {REF = [ … ]}

    display(cv)
    #=>
    CapsuleVector of 4 × (ref = &REF,):
     (ref = 1,)
     (ref = 1,)
     (ref = 1,)
     (ref = 2,)
    where
     REF = ["COMISSIONER", "DEPUTY COMISSIONER" … ]
    =#

Function `decapsulate()` decomposes a capsule into the underlying vector and a
list of references.

    decapsulate(cv)
    #-> (@VectorTree (ref = &REF,) [ … ], Pair{Symbol,AbstractArray{T,1} where T}[ … ])

Function `recapsulate()` applies the given function to the underlying vector
and encapsulates the output of the function.

    cv′ = recapsulate(v -> v[:, :ref], cv)
    #-> @VectorTree &REF [1, 1, 1, 2] where {REF = [ … ]}

We could dereference `CapsuleVector` if it wraps an `IndexVector` instance.
Function `dereference()` has no effect otherwise.

    dereference(cv′)
    #-> ["COMISSIONER", "COMISSIONER", "COMISSIONER", "DEPUTY COMISSIONER"]

    dereference(cv)
    #-> @VectorTree (ref = &REF,) [(ref = 1,), (ref = 1,), (ref = 1,), (ref = 2,)] where {REF = [ … ]}

Indexing `CapsuleVector` by a vector produces another instance of
`CapsuleVector`.

    cv[[4,2]]
    #-> @VectorTree (ref = &REF,) [(ref = 2,), (ref = 1,)] where {REF = [ … ]}


### `@VectorTree`

We can use `@VectorTree` macro to convert vector literals to the columnar form
assembled with `TupleVector`, `BlockVector`, `IndexVector`, and
`CapsuleVector`.

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

`BlockVector` and `IndexVector` can also be constructed.

    @VectorTree [String] [
        "HEALTH",
        ["FINANCE", "HUMAN RESOURCES"],
        missing,
        ["POLICE", "FIRE"],
    ]
    #-> @VectorTree [String] ["HEALTH", ["FINANCE", "HUMAN RESOURCES"], missing, ["POLICE", "FIRE"]]

    @VectorTree &REF [1, 1, 1, 2]
    #-> @VectorTree &REF [1, 1, 1, 2]

A `CapsuleVector` could be constructed using `where` syntax.

    @VectorTree &REF [1, 1, 1, 2] where {REF = refv}
    #-> @VectorTree &REF [1, 1, 1, 2] where {REF = ["COMISSIONER", "DEPUTY COMISSIONER"  … ]}

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

    @VectorTree &REF [[]] where (:REF => [])
    #=>
    ERROR: LoadError: expected an assignment; got :(:REF => [])
    ⋮
    =#

Using `@VectorTree`, we can easily construct hierarchical and mutually
referential data.

    hier_data = @VectorTree (name = [String], employee = [(name = [String], salary = [Int])]) [
        "POLICE"    ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112]
        "FIRE"      ["JOSE S" 202728; "CHARLES S" 197736]
    ]
    display(hier_data)
    #=>
    TupleVector of 2 × (name = [String], employee = [(name = [String], salary = [Int])]):
     (name = "POLICE", employee = [(name = "GARRY M", salary = 260004) … ])
     (name = "FIRE", employee = [(name = "JOSE S", salary = 202728) … ])
    =#

    mref_data = @VectorTree (department = [&DEPT], employee = [&EMP]) [
        [1, 2]  [1, 2, 3, 4, 5]
    ] where {
        DEPT = @VectorTree (name = [String], employee = [&EMP]) [
            "POLICE"    [1, 2, 3]
            "FIRE"      [4, 5]
        ]
        ,
        EMP = @VectorTree (name = [String], department = [&DEPT], salary = [Int]) [
            "GARRY M"   1   260004
            "ANTHONY R" 1   185364
            "DANA A"    1   170112
            "JOSE S"    2   202728
            "CHARLES S" 2   197736
        ]
    }
    display(mref_data)
    #=>
    CapsuleVector of 1 × (department = [&DEPT], employee = [&EMP]):
     (department = [1, 2], employee = [1, 2, 3, 4, 5])
    where
     DEPT = @VectorTree (name = [String], employee = [&EMP]) [(name = "POLICE", employee = [1, 2, 3]) … ]
     EMP = @VectorTree (name = [String], department = [&DEPT], salary = [Int]) [(name = "GARRY M", department = 1, salary = 260004) … ]
    =#

