# Monadic Signature


## Overview

To describe data shapes and monadic signatures, we need the following
definitions.

    using DataKnots:
        @VectorTree,
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
        wrap,
        x0to1,
        x0toN,
        x1to1,
        x1toN


### Data shapes

In `DataKnots`, the structure of composite data is represented using *shape*
objects.

For example, consider a collection of departments with associated employees.

    depts =
        @VectorTree (name = (1:1)String,
                     employee = (1:N)(name = (1:1)String,
                                      position = (1:1)String,
                                      salary = (0:1)Int,
                                      rate = (0:1)Float64)) [
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
type.  The `x1to1` cardinality is assumed by default.

    OutputShape(:position, NativeShape(String), x1to1)
    #-> OutputShape(:position, String)

`RecordShape` describes the structure of a record.  It contains a list of field
shapes and corresponds to a `TupleVector` with `BlockVector` columns.

    emp_shp =
        RecordShape(OutputShape(:name, String),
                    OutputShape(:position, String),
                    OutputShape(:salary, Int, x0to1),
                    OutputShape(:rate, Float64, x0to1))

Using nested shape objects, we can describe the structure of a nested
collection.

    dept_shp =
        RecordShape(OutputShape(:name, String),
                    OutputShape(:employee, emp_shp, x1toN))


### Traversing nested data

A record field can be seen as a specialized query.  For example, the field
*employee* corresponds to a query which maps a collection of departments to
associated employees.

    dept_employee = column(:employee)

    dept_employee(depts) |> display
    #=>
    @VectorTree of 3 × (1:N) × (name = (1:1) × String,
                                position = (1:1) × String,
                                salary = (0:1) × Int,
                                rate = (0:1) × Float64):
     [(name = "JEFFERY A", position = "SERGEANT", salary = 101442, rate = missing), (name = "NANCY A", position = "POLICE OFFICER", salary = 80016, rate = missing)]
     [(name = "JAMES A", position = "FIRE ENGINEER-EMT", salary = 103350, rate = missing), (name = "DANIEL A", position = "FIRE FIGHTER-EMT", salary = 95484, rate = missing)]
     [(name = "LAKENYA A", position = "CROSSING GUARD", salary = missing, rate = 17.68), (name = "DORIS A", position = "CROSSING GUARD", salary = missing, rate = 19.38)]
    =#

To indicate the role of this query, we assign it a *monadic signature*, which
describes the shapes of the query input and output.

    dept_employee =
        dept_employee |> designate(InputShape(dept_shp), OutputShape(emp_shp, x1toN))

    signature(dept_employee)
    #=>
    (name = [String, x1to1],
     employee = [(name = [String, x1to1],
                  position = [String, x1to1],
                  salary = [Int, x0to1],
                  rate = [Float64, x0to1]),
                 x1toN]) ->
        [(name = [String, x1to1],
          position = [String, x1to1],
          salary = [Int, x0to1],
          rate = [Float64, x0to1]),
         x1toN]
    =#

A *path* could be assembled by composing two adjacent field queries.  For
example, consider a query that corresponds to the *rate* field.

    emp_rate =
        column(:rate) |> designate(InputShape(emp_shp), OutputShape(Float64, x0to1))

The output domain of the `dept_employee` coincides with the input domain of `emp_rate`.

    domain(dept_employee)
    #=>
    RecordShape(OutputShape(:name, String),
                OutputShape(:position, String),
                OutputShape(:salary, Int, x0to1),
                OutputShape(:rate, Float64, x0to1))
    =#

    idomain(emp_rate)
    #=>
    RecordShape(OutputShape(:name, String),
                OutputShape(:position, String),
                OutputShape(:salary, Int, x0to1),
                OutputShape(:rate, Float64, x0to1))
    =#

This means the queries are composable.  Note that we cannot simply chain the
queries using `chain_of(dept_employee, emp_rate)` because the output of
`dept_employee` is not compatible with `emp_rate`.  Indeed, `dept_employee`
produces a `BlockVector` while `emp_rate` expects a `TupleVector`.  So instead
we use the *monadic composition* combinator.

    dept_employee_rate = compose(dept_employee, emp_rate)
    #-> chain_of(column(:employee), with_elements(column(:rate)), flatten())

    dept_employee_rate(depts)
    #-> @VectorTree (0:N) × Float64 [[], [], [17.68, 19.38]]

This composition represents a path through the fields *employee* and *rate* and
has a signature assigned to it.

    signature(dept_employee_rate)
    #=>
    (name = [String, x1to1],
     employee = [(name = [String, x1to1],
                  position = [String, x1to1],
                  salary = [Int, x0to1],
                  rate = [Float64, x0to1]),
                 x1toN]) ->
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

    round_it(@VectorTree (Float64, (P = (1:1)Int,)) [(17.68, (P = 1,)), (19.38, (P = 1,))])
    #-> @VectorTree (1:1) × Float64 [17.7, 19.4]

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
    #-> x0toN

    slots(dept_employee_round_rate)
    #-> Pair{Symbol,DataKnots.OutputShape}[:P=>OutputShape(Float64)]

    slot_data = @VectorTree (P = (1:1)Int,) [(P = 1,), (P = 1,), (P = 1,)]

    input = TupleVector(:depts => depts, :slot_data => slot_data)

    dept_employee_round_rate(input)
    #-> @VectorTree (0:N) × Float64 [[], [], [17.7, 19.4]]


## API Reference

```@autodocs
Modules = [DataKnots]
Pages = ["shapes.jl"]
```


## Test Suite


### Cardinality

`Cardinality` constraints are partially ordered.  In particular, there are the
greatest and the least cardinalities.

    print(bound(Cardinality))   #-> x1to1
    print(ibound(Cardinality))  #-> x0toN

For a collection of cardinality constraints, we can determine their least upper
bound and their greatest lower bound.

    print(bound(x0to1, x1toN))      #-> x0toN
    print(ibound(x1toN, x0to1))     #-> x1to1

For two `Cardinality` constraints, we can determine whether one is more strict
than the other.

    fits(x0to1, x1toN)              #-> false
    fits(x1to1, x0toN)          #-> true


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

    o_shp = OutputShape(Int, x0toN)
    #-> OutputShape(Int, x0toN)

    print(cardinality(o_shp))
    #-> x0toN

    domain(o_shp)
    #-> NativeShape(Int)

    mode(o_shp)
    #-> OutputMode(x0toN)

It is possible to decorate `InputShape` and `OutputShape` objects to specify
additional attributes.  Currently, we can only specify the *label*.

    o_shp |> decorate(label=:output)
    #-> OutputShape(:output, Int, x0toN)

RecordShape` specifies the shape of a record value where each record field has
a certain shape and cardinality.

    dept_shp = RecordShape(OutputShape(:name, String),
                           OutputShape(:employee, UInt, x0toN))
    #=>
    RecordShape(OutputShape(:name, String), OutputShape(:employee, UInt, x0toN))
    =#

    emp_shp = RecordShape(OutputShape(:name, String),
                          OutputShape(:department, UInt),
                          OutputShape(:position, String),
                          OutputShape(:salary, Int),
                          OutputShape(:manager, UInt, x0to1),
                          OutputShape(:subordinate, UInt, x0toN))
    #=>
    RecordShape(OutputShape(:name, String),
                OutputShape(:department, UInt),
                OutputShape(:position, String),
                OutputShape(:salary, Int),
                OutputShape(:manager, UInt, x0to1),
                OutputShape(:subordinate, UInt, x0toN))
    =#

Using the combination of different shapes we can describe the structure of any
data source.

    db_shp = RecordShape(OutputShape(:department, dept_shp, x0toN),
                         OutputShape(:employee, emp_shp, x0toN))
    #=>
    RecordShape(OutputShape(:department,
                            RecordShape(OutputShape(:name, String),
                                        OutputShape(:employee, UInt, x0toN)),
                            x0toN),
                OutputShape(:employee,
                            RecordShape(OutputShape(:name, String),
                                        OutputShape(:department, UInt),
                                        OutputShape(:position, String),
                                        OutputShape(:salary, Int),
                                        OutputShape(:manager, UInt, x0to1),
                                        OutputShape(:subordinate, UInt, x0toN)),
                            x0toN))
    =#


### Shape ordering

The same data can satisfy many different shape constraints.  For example, a
vector `BlockVector(:, [Chicago])` can be said to have, among others, the shape
`OutputShape(String)`, the shape `OutputShape(AbstractString, x0toN)` or the
shape `AnyShape()`.  We can tell, for any two shapes, if one of them is more
specific than the other.

    fits(NativeShape(Int), NativeShape(Number))     #-> true
    fits(NativeShape(Int), NativeShape(String))     #-> false

    fits(InputShape(Int,
                    InputMode([:X => OutputShape(Int),
                               :Y => OutputShape(String)],
                              true)),
         InputShape(Number,
                    InputMode([:X => OutputShape(Int, x0to1)])))
    #-> true
    fits(InputShape(Int),
         InputShape(Number, InputMode(true)))
    #-> false
    fits(InputShape(Int,
                    InputMode([:X => OutputShape(Int, x0to1)])),
         InputShape(Number,
                    InputMode([:X => OutputShape(Int)])))
    #-> false

    fits(OutputShape(Int),
         OutputShape(Number, x0to1))                  #-> true
    fits(OutputShape(Int, x1toN),
         OutputShape(Number, x0to1))                  #-> false
    fits(OutputShape(Int),
         OutputShape(String, x0to1))                  #-> false

    fits(RecordShape(OutputShape(Int),
                     OutputShape(String, x0to1)),
         RecordShape(OutputShape(Number),
                     OutputShape(String, x0toN)))     #-> true
    fits(RecordShape(OutputShape(Int, x0to1),
                     OutputShape(String)),
         RecordShape(OutputShape(Number),
                     OutputShape(String, x0toN)))     #-> false
    fits(RecordShape(OutputShape(Int)),
         RecordShape(OutputShape(Number),
                     OutputShape(String, x0toN)))     #-> false

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

    bound(InputShape(Int, InputMode([:X => OutputShape(Int, x0to1), :Y => OutputShape(String)], true)),
          InputShape(Number, InputMode([:X => OutputShape(Int)])))
    #=>
    InputShape(Number, InputMode([:X => OutputShape(Int, x0to1)]))
    =#
    ibound(InputShape(Int, InputMode([:X => OutputShape(Int, x0to1), :Y => OutputShape(String)], true)),
           InputShape(Number, InputMode([:X => OutputShape(Int)])))
    #=>
    InputShape(Int,
               InputMode([:X => OutputShape(Int), :Y => OutputShape(String)],
                         true))
    =#

    bound(OutputShape(String, x0to1), OutputShape(String, x1toN))
    #-> OutputShape(String, x0toN)
    ibound(OutputShape(String, x0to1), OutputShape(String, x1toN))
    #-> OutputShape(String)

    bound(RecordShape(OutputShape(Int, x1toN),
                      OutputShape(String, x0to1)),
          RecordShape(OutputShape(Number),
                      OutputShape(UInt, x0toN)))
    #=>
    RecordShape(OutputShape(Number, x1toN), OutputShape(AnyShape(), x0toN))
    =#
    ibound(RecordShape(OutputShape(Int, x1toN),
                       OutputShape(String, x0to1)),
           RecordShape(OutputShape(Number),
                       OutputShape(UInt, x0toN)))
    #=>
    RecordShape(OutputShape(Int), OutputShape(NoneShape(), x0to1))
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
                                            OutputShape(:employee, UInt, x0toN))))
    #-> UInt -> [(name = [String, x1to1], employee = [UInt]), x1to1]

Different components of the signature can be easily extracted.

    shape(sig)
    #=>
    OutputShape(RecordShape(OutputShape(:name, String),
                            OutputShape(:employee, UInt, x0toN)))
    =#

    ishape(sig)
    #-> InputShape(UInt)

    domain(sig)
    #=>
    RecordShape(OutputShape(:name, String), OutputShape(:employee, UInt, x0toN))
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
        @VectorTree ((1:1)String,
                     (1:N)(name = (1:1)String,
                           position = (1:1)String,
                           salary = (0:1)Int,
                           rate = (0:1)Float64)) [])
    #=>
    RecordShape(OutputShape(String),
                OutputShape(RecordShape(OutputShape(:name, String),
                                        OutputShape(:position, String),
                                        OutputShape(:salary, Int, x0to1),
                                        OutputShape(:rate, Float64, x0to1)),
                            x1toN))
    =#

`TupleVector` and `BlockVector` objects that are not in the record layout are
treated as regular vectors.

    shapeof(@VectorTree (String, [String]) [])
    #-> NativeShape(Tuple{String,Array{String,1}})

    shapeof(@VectorTree (name = String, employee = [String]) [])
    #-> NativeShape(NamedTuple{(:name, :employee),Tuple{String,Array{String,1}}})
