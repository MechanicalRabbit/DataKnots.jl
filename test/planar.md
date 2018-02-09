# Planar Vectors

For efficient data processing, the data can be stored in a planar (also known
as columnar or SoA) form.

    using QueryCombinators.Planar


## `TupleVector`

`TupleVector` is a vector of tuples stored as a tuple of vectors.

    tv = TupleVector(:name => ["GARRY M", "ANTHONY R", "DANA A"],
                     :salary => [260004, 185364, 170112])
    #-> @Planar (name = String, salary = Int) [(name = "GARRY M", salary = 260004) … ]

    display(tv)
    #=>
    TupleVector of 3 × (name = String, salary = Int):
     (name = "GARRY M", salary = 260004)
     (name = "ANTHONY R", salary = 185364)
     (name = "DANA A", salary = 170112)
    =#

It is possible to construct a `TupleVector` without labels.

    TupleVector(length(tv), columns(tv))
    #-> @Planar (String, Int) [("GARRY M", 260004) … ]

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


## `BlockVector`

`BlockVector` is a vector of homogeneous vectors (blocks) stored as a vector of
elements partitioned into individual blocks by a vector of offsets.

    bv = BlockVector([["HEALTH"], ["FINANCE", "HUMAN RESOURCES"], [], ["POLICE", "FIRE"]])
    #-> @Planar [String] ["HEALTH", ["FINANCE", "HUMAN RESOURCES"], missing, ["POLICE", "FIRE"]]

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
    #-> @Planar [String] ["HEALTH", ["FINANCE", "HUMAN RESOURCES"], missing, ["POLICE", "FIRE"]]

It is possible to specify the offset and the element vectors separately.

    BlockVector([1, 2, 4, 4, 6], ["HEALTH", "FINANCE", "HUMAN RESOURCES", "POLICE", "FIRE"])
    #-> @Planar [String] ["HEALTH", ["FINANCE", "HUMAN RESOURCES"], missing, ["POLICE", "FIRE"]]

If each block contains exactly one element, we could use `:` in place of the
offset vector.

    BlockVector(:, ["HEALTH", "FINANCE", "HUMAN RESOURCES", "POLICE", "FIRE"])
    #-> @Planar [String] ["HEALTH", "FINANCE", "HUMAN RESOURCES", "POLICE", "FIRE"]

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
    showcompact(reg_bv)
    #-> ["POLICE", "FIRE", "HEALTH", "AVIATION", "WATER MGMNT", "FINANCE"]

    opt_bv = BlockVector([1, 2, 3, 3, 4, 4, 5, 6, 6, 6, 7], elts)
    showcompact(opt_bv)
    #-> ["POLICE", "FIRE", missing, "HEALTH", missing, "AVIATION", "WATER MGMNT", missing, missing, "FINANCE"]

    plu_bv = BlockVector([1, 1, 1, 2, 2, 4, 4, 6, 7], elts)
    showcompact(plu_bv)
    #-> [missing, missing, "POLICE", missing, ["FIRE", "HEALTH"], missing, ["AVIATION", "WATER MGMNT"], "FINANCE"]

    showcompact(reg_bv[[1,3,5,3]])
    #-> ["POLICE", "HEALTH", "WATER MGMNT", "HEALTH"]

    showcompact(plu_bv[[1,3,5,3]])
    #-> [missing, "POLICE", ["FIRE", "HEALTH"], "POLICE"]

    showcompact(reg_bv[Base.OneTo(4)])
    #-> ["POLICE", "FIRE", "HEALTH", "AVIATION"]

    showcompact(reg_bv[Base.OneTo(6)])
    #-> ["POLICE", "FIRE", "HEALTH", "AVIATION", "WATER MGMNT", "FINANCE"]

    showcompact(plu_bv[Base.OneTo(6)])
    #-> [missing, missing, "POLICE", missing, ["FIRE", "HEALTH"], missing]

    showcompact(opt_bv[Base.OneTo(10)])
    #-> ["POLICE", "FIRE", missing, "HEALTH", missing, "AVIATION", "WATER MGMNT", missing, missing, "FINANCE"]


## `IndexVector`

`IndexVector` is a vector of indexes in some named vector.

    iv = IndexVector(:REF, [1, 1, 1, 2])
    #-> @Planar &REF [1, 1, 1, 2]

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
    #-> @Planar &REF [2, 1]

`IndexVector` can be deferenced against a list of named vectors, which can be
used to traverse self-referential data structures.

    refv = ["COMISSIONER", "DEPUTY COMISSIONER", "ZONING ADMINISTRATOR", "PROJECT MANAGER"]

    dereference(iv, [:REF => refv])
    #-> ["COMISSIONER", "COMISSIONER", "COMISSIONER", "DEPUTY COMISSIONER"]

Function `dereference()` has no effect on other types of vectors, or when the
desired reference vector is not in the list.

    dereference(iv, [:REF′ => refv])
    #-> @Planar &REF [1, 1, 1, 2]

    dereference([1, 1, 1, 2], [:REF => refv])
    #-> [1, 1, 1, 2]


## `@Planar`

We can use `@Planar` macro to convert vector literals to a planar form.

`TupleVector` is created from a matrix or a vector of (named) tuples.

    @Planar (name = String, salary = Int) [
        "GARRY M"   260004
        "ANTHONY R" 185364
        "DANA A"    170112
    ]
    #-> @Planar (name = String, salary = Int) [(name = "GARRY M", salary = 260004) … ]

    @Planar (name = String, salary = Int) [
        ("GARRY M", 260004),
        ("ANTHONY R", 185364),
        ("DANA A", 170112),
    ]
    #-> @Planar (name = String, salary = Int) [(name = "GARRY M", salary = 260004) … ]

    @Planar (name = String, salary = Int) [
        (name = "GARRY M", salary = 260004),
        (name = "ANTHONY R", salary = 185364),
        (name = "DANA A", salary = 170112),
    ]
    #-> @Planar (name = String, salary = Int) [(name = "GARRY M", salary = 260004) … ]

For `TupleVector`, column labels are optional.

    @Planar (String, Int) ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112]
    #-> @Planar (String, Int) [("GARRY M", 260004) … ]

Ill-formed `TupleVector` contructors are rejected.

    @Planar (String, Int) ("GARRY M", 260004)
    #=>
    ERROR: LoadError: expected a vector literal; got :(("GARRY M", 260004))
    in expression starting at none:2
    =#

    @Planar (String, Int) [(position = "SUPERINTENDENT OF POLICE", salary = 260004)]
    #=>
    ERROR: LoadError: expected no label; got :(position = "SUPERINTENDENT OF POLICE")
    in expression starting at none:2
    =#

    @Planar (name = String, salary = Int) [(position = "SUPERINTENDENT OF POLICE", salary = 260004)]
    #=>
    ERROR: LoadError: expected label :name; got :(position = "SUPERINTENDENT OF POLICE")
    in expression starting at none:2
    =#

    @Planar (name = String, salary = Int) [("GARRY M", "SUPERINTENDENT OF POLICE", 260004)]
    #=>
    ERROR: LoadError: expected 2 column(s); got :(("GARRY M", "SUPERINTENDENT OF POLICE", 260004))
    in expression starting at none:2
    =#

    @Planar (name = String, salary = Int) ["GARRY M"]
    #=>
    ERROR: LoadError: expected a tuple or a row literal; got "GARRY M"
    in expression starting at none:2
    =#

`BlockVector` and `IndexVector` can also be constructed.

    @Planar [String] [
        "HEALTH",
        ["FINANCE", "HUMAN RESOURCES"],
        missing,
        ["POLICE", "FIRE"],
    ]
    #-> @Planar [String] ["HEALTH", ["FINANCE", "HUMAN RESOURCES"], missing, ["POLICE", "FIRE"]]

    @Planar &REF [1, 1, 1, 2]
    #-> @Planar &REF [1, 1, 1, 2]

Using `@Planar`, we can easily construct hierarchical and self-referential
data.

    ref_data = @Planar (position = [String], manager = [&SELF]) [
        "COMISSIONER"           missing
        "DEPUTY COMISSIONER"    1
        "ZONING ADMINISTRATOR"  1
        "PROJECT MANAGER"       2
    ]
    display(ref_data)
    #=>
    TupleVector of 4 × (position = [String], manager = [&SELF]):
     (position = "COMISSIONER", manager = missing)
     (position = "DEPUTY COMISSIONER", manager = 1)
     (position = "ZONING ADMINISTRATOR", manager = 1)
     (position = "PROJECT MANAGER", manager = 2)
    =#

    hier_data = @Planar (name = [String], employee = [(name = [String], salary = [Int])]) [
        "POLICE"    ["GARRY M" 260004; "ANTHONY R" 185364; "DANA A" 170112]
        "FIRE"      ["JOSE S" 202728; "CHARLES S" 197736]
    ]
    display(hier_data)
    #=>
    TupleVector of 2 × (name = [String], employee = [(name = [String], salary = [Int])]):
     (name = "POLICE", employee = [(name = "GARRY M", salary = 260004) … ])
     (name = "FIRE", employee = [(name = "JOSE S", salary = 202728) … ])
    =#

