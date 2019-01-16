# Monadic Signature


## Overview

To describe data shapes and monadic signatures, we need the following
definitions.

    using DataKnots:
        @VectorTree,
        OPT,
        PLU,
        REG,
        AnyShape,
        Cardinality,
        InputMode,
        InputShape,
        NativeShape,
        NoneShape,
        OutputMode,
        OutputShape,
        RecordShape,
        Signature,
        TupleVector,
        adapt_vector,
        bound,
        cardinality,
        chain_of,
        column,
        compose,
        decorate,
        designate,
        domain,
        fits,
        ibound,
        idomain,
        imode,
        ishape,
        isoptional,
        isplural,
        isregular,
        lift,
        mode,
        shape,
        shapeof,
        signature,
        slots,
        tuple_lift,
        tuple_of,
        wrap


### Data shapes

In `DataKnots`, the structure of composite data is represented using *shape*
objects.

For example, consider a collection of departments with associated employees.

    depts =
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

In this collection, each department record has two fields: *name* and
*employee*.  Each employee record has four fields: *name*, *position*,
*salary*, and *rate*.  The *employee* field is plural; *salary* and *rate* are
optional.

Physically, this collection is stored as a tree of interleaving `TupleVector`
and `BlockVector` objects with regular `Vector` objects as the tree leaves.
The structure of this collection can be described by a congruent tree composed
of `RecordShape`, `OutputShape`, and `NativeShape` objects.

`NativeShape` corresponds to regular Julia `Vector` objects and specifies the
type of the vector elements.

    NativeShape(String)
    #-> NativeShape(String)

`OutputShape` specifies the label, the domain and the cardinality of a record
field.  The data of a record field is stored in a `BlockVector` object.
Accordingly, the field domain is the shape of the `BlockVector` elements and
the field cardinality is the cardinality of the `BlockVector`.  When the domain
is represented by `NativeShape`, we could instead specify the respective Julia
type.  The `REG` cardinality is assumed by default.

    OutputShape(:position, NativeShape(String), REG)
    #-> OutputShape(:position, String)

`RecordShape` describes the structure of a record.  It contains a list of field
shapes and corresponds to a `TupleVector` with `BlockVector` columns.

    emp_shp =
        RecordShape(OutputShape(:name, String),
                    OutputShape(:position, String),
                    OutputShape(:salary, Int, OPT),
                    OutputShape(:rate, Float64, OPT))

Using nested shape objects, we can describe the structure of a nested
collection.

    dept_shp =
        RecordShape(OutputShape(:name, String),
                    OutputShape(:employee, emp_shp, PLU))


### Traversing nested data

A record field can be seen as a specialized query.  For example, the field
*employee* corresponds to a query which maps a collection of departments to
associated employees.

    dept_employee = column(:employee)

    dept_employee(depts) |> display
    #=>
    BlockVector of 3 × [(name = [String, REG], position = [String, REG], salary = [Int, OPT], rate = [Float64, OPT]), PLU]:
     [(name = "JEFFERY A", position = "SERGEANT", salary = 101442, rate = missing), (name = "NANCY A", position = "POLICE OFFICER", salary = 80016, rate = missing)]
     [(name = "JAMES A", position = "FIRE ENGINEER-EMT", salary = 103350, rate = missing), (name = "DANIEL A", position = "FIRE FIGHTER-EMT", salary = 95484, rate = missing)]
     [(name = "LAKENYA A", position = "CROSSING GUARD", salary = missing, rate = 17.68), (name = "DORIS A", position = "CROSSING GUARD", salary = missing, rate = 19.38)]
    =#

To indicate the role of this query, we assign it a *monadic signature*, which
describes the shapes of the query input and output.

    dept_employee =
        dept_employee |> designate(InputShape(dept_shp), OutputShape(emp_shp, PLU))

    signature(dept_employee)
    #=>
    (name = [String, REG],
     employee = [(name = [String, REG],
                  position = [String, REG],
                  salary = [Int, OPT],
                  rate = [Float64, OPT]),
                 PLU]) ->
        [(name = [String, REG],
          position = [String, REG],
          salary = [Int, OPT],
          rate = [Float64, OPT]),
         PLU]
    =#

A *path* could be assembled by composing two adjacent field queries.  For
example, consider a query that corresponds to the *rate* field.

    emp_rate =
        column(:rate) |> designate(InputShape(emp_shp), OutputShape(Float64, OPT))

The output domain of the `dept_employee` coincides with the input domain of `emp_rate`.

    domain(dept_employee)
    #=>
    RecordShape(OutputShape(:name, String),
                OutputShape(:position, String),
                OutputShape(:salary, Int, OPT),
                OutputShape(:rate, Float64, OPT))
    =#

    idomain(emp_rate)
    #=>
    RecordShape(OutputShape(:name, String),
                OutputShape(:position, String),
                OutputShape(:salary, Int, OPT),
                OutputShape(:rate, Float64, OPT))
    =#

This means the queries are composable.  Note that we cannot simply chain the
queries using `chain_of(dept_employee, emp_rate)` because the output of
`dept_employee` is not compatible with `emp_rate`.  Indeed, `dept_employee`
produces a `BlockVector` while `emp_rate` expects a `TupleVector`.  So instead
we use the *monadic composition* combinator.

    dept_employee_rate = compose(dept_employee, emp_rate)
    #-> chain_of(column(:employee), with_elements(column(:rate)), flatten())

    dept_employee_rate(depts)
    #-> @VectorTree [Float64] [[], [], [17.68, 19.38]]

This composition represents a path through the fields *employee* and *rate* and
has a signature assigned to it.

    signature(dept_employee_rate)
    #=>
    (name = [String, REG],
     employee = [(name = [String, REG],
                  position = [String, REG],
                  salary = [Int, OPT],
                  rate = [Float64, OPT]),
                 PLU]) ->
        [Float64]
    =#


### Monadic queries

Among all queries, `DataKnots` distinguishes a special class of path-like
queries, which are called *monadic*.  We indicate that a query is monadic by
assigning it its monadic signature.

The query signature describes the shapes of its input and output using
`InputShape` and `OutputShape` objects.

`OutputShape` specifies the label, the domain and the cardinality of the query
output.  A monadic query always produces a `BlockVector` object.  Accordingly,
the output domain and cardinality specify the `BlockVector` elements and its
cardinality.

`InputShape` specifies the label, the domain and the named slots of the query
input.  The input of a monadic query is a `TupleVector` with two columns: the
first column is the regular input data described by the input domain, while the
second column is a record containing slot data.  When the query has no slots,
the outer `TupleVector` is omitted.

For example, consider a monadic query that wraps the `round` function with
precision specified in a named slot.

    round_digits(x, d) = round(x, digits=d)

    round_it =
        chain_of(
            tuple_of(chain_of(column(1), wrap()),
                     chain_of(column(2), column(:P))),
            tuple_lift(round_digits),
            wrap())

    round_it(@VectorTree (Float64, (P = [Int, REG],)) [(17.68, (P = 1,)), (19.38, (P = 1,))])
    #-> @VectorTree [Float64, REG] [17.7, 19.4]

To indicate that the query is monadic, we assign it its monadic signature.

    round_it =
        round_it |> designate(InputShape(Float64, [:P => OutputShape(Float64)]),
                              OutputShape(Float64))

When two monadic queries have compatible intermediate domains, they could be composed.

    domain(dept_employee_rate)
    #-> NativeShape(Float64)

    idomain(round_it)
    #-> NativeShape(Float64)

    dept_employee_round_rate = compose(dept_employee_rate, round_it)

The composition is again a monadic query.  Its signature is constructed from
the signatures of the components.  In particular, the cardinality of the
composition is the upper bound of the component cardinalities while its input
slots are formed from the slots of the components.

    print(cardinality(dept_employee_round_rate))
    #-> OPT_PLU

    slots(dept_employee_round_rate)
    #-> Pair{Symbol,DataKnots.OutputShape}[:P=>OutputShape(Float64)]

    slot_data = @VectorTree (P = [Int, REG],) [(P = 1,), (P = 1,), (P = 1,)]

    input = TupleVector(:depts => depts, :slot_data => slot_data)

    dept_employee_round_rate(input)
    #-> @VectorTree [Float64] [[], [], [17.7, 19.4]]


## API Reference

```@autodocs
Modules = [DataKnots]
Pages = ["shapes.jl"]
```


## Test Suite


### Cardinality

`Cardinality` constraints are partially ordered.  In particular, there are the
greatest and the least cardinalities.

    print(bound(Cardinality))   #-> REG
    print(ibound(Cardinality))  #-> OPT_PLU

For a collection of cardinality constraints, we can determine their least upper
bound and their greatest lower bound.

    print(bound(OPT, PLU))      #-> OPT_PLU
    print(ibound(PLU, OPT))     #-> REG

For two `Cardinality` constraints, we can determine whether one is more strict
than the other.

    fits(OPT, PLU)              #-> false
    fits(REG, OPT|PLU)          #-> true


### Data shapes

The structure of composite data is specified with *shape* objects.

`NativeShape` indicates a regular Julia value of a specific type.

    str_shp = NativeShape(String)
    #-> NativeShape(String)

    eltype(str_shp)
    #-> String

Two special shape types indicate values with no constraints and with
inconsistent constraints.

    any_shp = AnyShape()
    #-> AnyShape()

    none_shp = NoneShape()
    #-> NoneShape()

`InputShape` and `OutputShape` describe the structure of the input and the
output of a monadic query.

To describe the query input, we specify the shape of the input elements, the
shapes of the parameters, and whether or not the input is framed.

    i_shp = InputShape(UInt, InputMode([:D => OutputShape(String)], true))
    #-> InputShape(UInt, InputMode([:D => OutputShape(String)], true))

    domain(i_shp)
    #-> NativeShape(UInt)

    mode(i_shp)
    #-> InputMode([:D => OutputShape(String)], true)

To describe the query output, we specify the shape and the cardinality of the
output elements.

    o_shp = OutputShape(Int, OPT|PLU)
    #-> OutputShape(Int, OPT | PLU)

    print(cardinality(o_shp))
    #-> OPT_PLU

    domain(o_shp)
    #-> NativeShape(Int)

    mode(o_shp)
    #-> OutputMode(OPT | PLU)

It is possible to decorate `InputShape` and `OutputShape` objects to specify
additional attributes.  Currently, we can only specify the *label*.

    o_shp |> decorate(label=:output)
    #-> OutputShape(:output, Int, OPT | PLU)

RecordShape` specifies the shape of a record value where each record field has
a certain shape and cardinality.

    dept_shp = RecordShape(OutputShape(:name, String),
                           OutputShape(:employee, UInt, OPT|PLU))
    #=>
    RecordShape(OutputShape(:name, String),
                OutputShape(:employee, UInt, OPT | PLU))
    =#

    emp_shp = RecordShape(OutputShape(:name, String),
                          OutputShape(:department, UInt),
                          OutputShape(:position, String),
                          OutputShape(:salary, Int),
                          OutputShape(:manager, UInt, OPT),
                          OutputShape(:subordinate, UInt, OPT|PLU))
    #=>
    RecordShape(OutputShape(:name, String),
                OutputShape(:department, UInt),
                OutputShape(:position, String),
                OutputShape(:salary, Int),
                OutputShape(:manager, UInt, OPT),
                OutputShape(:subordinate, UInt, OPT | PLU))
    =#

Using the combination of different shapes we can describe the structure of any
data source.

    db_shp = RecordShape(OutputShape(:department, dept_shp, OPT|PLU),
                         OutputShape(:employee, emp_shp, OPT|PLU))
    #=>
    RecordShape(OutputShape(:department,
                            RecordShape(OutputShape(:name, String),
                                        OutputShape(:employee, UInt, OPT | PLU)),
                            OPT | PLU),
                OutputShape(:employee,
                            RecordShape(
                                OutputShape(:name, String),
                                OutputShape(:department, UInt),
                                OutputShape(:position, String),
                                OutputShape(:salary, Int),
                                OutputShape(:manager, UInt, OPT),
                                OutputShape(:subordinate, UInt, OPT | PLU)),
                            OPT | PLU))
    =#


### Shape ordering

The same data can satisfy many different shape constraints.  For example, a
vector `BlockVector(:, [Chicago])` can be said to have, among others, the shape
`OutputShape(String)`, the shape `OutputShape(AbstractString, OPT|PLU)` or the
shape `AnyShape()`.  We can tell, for any two shapes, if one of them is more
specific than the other.

    fits(NativeShape(Int), NativeShape(Number))     #-> true
    fits(NativeShape(Int), NativeShape(String))     #-> false

    fits(InputShape(Int,
                    InputMode([:X => OutputShape(Int),
                               :Y => OutputShape(String)],
                              true)),
         InputShape(Number,
                    InputMode([:X => OutputShape(Int, OPT)])))
    #-> true
    fits(InputShape(Int),
         InputShape(Number, InputMode(true)))
    #-> false
    fits(InputShape(Int,
                    InputMode([:X => OutputShape(Int, OPT)])),
         InputShape(Number,
                    InputMode([:X => OutputShape(Int)])))
    #-> false

    fits(OutputShape(Int),
         OutputShape(Number, OPT))                  #-> true
    fits(OutputShape(Int, PLU),
         OutputShape(Number, OPT))                  #-> false
    fits(OutputShape(Int),
         OutputShape(String, OPT))                  #-> false

    fits(RecordShape(OutputShape(Int),
                     OutputShape(String, OPT)),
         RecordShape(OutputShape(Number),
                     OutputShape(String, OPT|PLU)))     #-> true
    fits(RecordShape(OutputShape(Int, OPT),
                     OutputShape(String)),
         RecordShape(OutputShape(Number),
                     OutputShape(String, OPT|PLU)))     #-> false
    fits(RecordShape(OutputShape(Int)),
         RecordShape(OutputShape(Number),
                     OutputShape(String, OPT|PLU)))     #-> false

Shapes of different kinds are typically not compatible with each other.  The
exceptions are `AnyShape` and `NullShape`.

    fits(NativeShape(Int), OutputShape(Int))    #-> false
    fits(NativeShape(Int), AnyShape())          #-> true
    fits(NoneShape(), NativeShape(Int))         #-> true

Shape decorations are treated as additional shape constraints.

    fits(OutputShape(:name, String),
         OutputShape(:name, String))                            #-> true
    fits(OutputShape(String),
         OutputShape(:position, String))                        #-> false
    fits(OutputShape(:position, String),
         OutputShape(String))                                   #-> true
    fits(OutputShape(:position, String),
         OutputShape(:name, String))                            #-> false

For any given number of shapes, we can find their upper bound, the shape that
is more general than each of them.  We can also find their lower bound.

    bound(NativeShape(Int), NativeShape(Number))
    #-> NativeShape(Number)
    ibound(NativeShape(Int), NativeShape(Number))
    #-> NativeShape(Int)

    bound(InputShape(Int, InputMode([:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true)),
          InputShape(Number, InputMode([:X => OutputShape(Int)])))
    #=>
    InputShape(Number, InputMode([:X => OutputShape(Int, OPT)]))
    =#
    ibound(InputShape(Int, InputMode([:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true)),
           InputShape(Number, InputMode([:X => OutputShape(Int)])))
    #=>
    InputShape(Int,
               InputMode([:X => OutputShape(Int), :Y => OutputShape(String)],
                         true))
    =#

    bound(OutputShape(String, OPT), OutputShape(String, PLU))
    #-> OutputShape(String, OPT | PLU)
    ibound(OutputShape(String, OPT), OutputShape(String, PLU))
    #-> OutputShape(String)

    bound(RecordShape(OutputShape(Int, PLU),
                      OutputShape(String, OPT)),
          RecordShape(OutputShape(Number),
                      OutputShape(UInt, OPT|PLU)))
    #=>
    RecordShape(OutputShape(Number, PLU), OutputShape(AnyShape(), OPT | PLU))
    =#
    ibound(RecordShape(OutputShape(Int, PLU),
                       OutputShape(String, OPT)),
           RecordShape(OutputShape(Number),
                       OutputShape(UInt, OPT|PLU)))
    #=>
    RecordShape(OutputShape(Int), OutputShape(NoneShape(), OPT))
    =#

For decorated shapes, incompatible labels are replaced with an empty label.

    bound(OutputShape(:name, String), OutputShape(:name, String))
    #-> OutputShape(:name, String)

    ibound(OutputShape(:name, String), OutputShape(:name, String))
    #-> OutputShape(:name, String)

    bound(OutputShape(:position, String), OutputShape(:salary, Number))
    #-> OutputShape(AnyShape())

    ibound(OutputShape(:position, String), OutputShape(:salary, Number))
    #-> OutputShape(Symbol(""), NoneShape())

    bound(OutputShape(Int), OutputShape(:salary, Number))
    #-> OutputShape(Number)

    ibound(OutputShape(Int), OutputShape(:salary, Number))
    #-> OutputShape(:salary, Int)


### Monadic signature

The signature of a monadic query is a pair of an `InputShape` object and an
`OutputShape` object.

    sig = Signature(InputShape(UInt),
                    OutputShape(RecordShape(OutputShape(:name, String),
                                            OutputShape(:employee, UInt, OPT|PLU))))
    #-> UInt -> [(name = [String, REG], employee = [UInt]), REG]

Different components of the signature can be easily extracted.

    shape(sig)
    #=>
    OutputShape(RecordShape(OutputShape(:name, String),
                            OutputShape(:employee, UInt, OPT | PLU)))
    =#

    ishape(sig)
    #-> InputShape(UInt)

    domain(sig)
    #=>
    RecordShape(OutputShape(:name, String),
                OutputShape(:employee, UInt, OPT | PLU))
    =#

    mode(sig)
    #-> OutputMode()

    idomain(sig)
    #-> NativeShape(UInt)

    imode(sig)
    #-> InputMode()


### Determining the vector shape

Function `shapeof()` determines the shape of a given vector.

    shapeof(["GARRY M", "ANTHONY R", "DANA A"])
    #-> NativeShape(String)

In particular, it detects the record layout.

    shapeof(
        @VectorTree ([String, REG],
                     [(name = [String, REG],
                       position = [String, REG],
                       salary = [Int, OPT],
                       rate = [Float64, OPT]), PLU]) [])
    #=>
    RecordShape(OutputShape(String),
                OutputShape(RecordShape(OutputShape(:name, String),
                                        OutputShape(:position, String),
                                        OutputShape(:salary, Int, OPT),
                                        OutputShape(:rate, Float64, OPT)),
                            PLU))
    =#

`TupleVector` and `BlockVector` objects that are not in the record layout are
treated as regular vectors.

    shapeof(@VectorTree (String, [String]) [])
    #-> NativeShape(Tuple{String,Array{String,1}})

    shapeof(@VectorTree (name = String, employee = [String]) [])
    #-> NativeShape(NamedTuple{(:name, :employee),Tuple{String,Array{String,1}}})
