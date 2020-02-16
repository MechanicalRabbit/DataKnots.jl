# Shapes and Signatures

To describe data shapes and pipeline signatures, we need the following
definitions.

    using DataKnots:
        @VectorTree,
        AnyShape,
        BlockOf,
        BlockVector,
        IsFlow,
        IsLabeled,
        IsScope,
        NoShape,
        Signature,
        TupleOf,
        TupleVector,
        ValueOf,
        cardinality,
        chain_of,
        column,
        columns,
        compose,
        context,
        designate,
        domain,
        elements,
        fits,
        label,
        labels,
        print_graph,
        replace_column,
        replace_elements,
        shapeof,
        signature,
        source,
        subject,
        target,
        tuple_lift,
        tuple_of,
        wrap,
        x0to1,
        x0toN,
        x1to1,
        x1toN

## Data Shapes

In `DataKnots`, the structure of composite data is represented using *shape*
objects.

For example, consider a collection of departments with associated employees.

    depts =
        @VectorTree (name = (1:1)String,
                     employee = (1:N)(name = (1:1)String,
                                      position = (1:1)String,
                                      salary = (0:1)Int64,
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
and `BlockVector` objects with regular `Vector` objects as the leaves.  Its
shape is described by a congruent tree composed of `TupleOf`, `BlockOf` and
`ValueOf` objects.

`ValueOf` corresponds to regular Julia `Vector` objects and specifies the type
of the vector elements.

    ValueOf(String)
    #-> ValueOf(String)

`BlockOf` specifies the shape of the elements and the cardinality of a
`BlockVector`.  As a shorthand, a regular Julia type is accepted in place of a
`ValueOf` shape, and the cardinality `x0toN` is assumed by default.

    BlockOf(ValueOf(String), x1to1)
    #-> BlockOf(String, x1to1)

`TupleOf` describes a `TupleVector` object with the given labels and the shapes
of the columns.

    emp_shp = TupleOf(:name => BlockOf(String, x1to1),
                      :position => BlockOf(String, x1to1),
                      :salary => BlockOf(Int, x0to1),
                      :rate => BlockOf(Float64, x0to1))

Using nested shape objects, we can accurately specify the structure of a nested
collection.

    dept_shp = TupleOf(:name => BlockOf(String, x1to1),
                       :employee => BlockOf(emp_shp, x1toN))
    #=>
    TupleOf(:name => BlockOf(String, x1to1),
            :employee => BlockOf(TupleOf(
                                     :name => BlockOf(String, x1to1),
                                     :position => BlockOf(String, x1to1),
                                     :salary => BlockOf(Int64, x0to1),
                                     :rate => BlockOf(Float64, x0to1)),
                                 x1toN))
    =#

## Traversing Nested Data

A field gives rise to a pipeline that maps the records to the field
values.  For example, the field *employee* corresponds to a pipeline which maps
a collection of departments to associated employees.

    dept_employee = column(:employee)

    dept_employee(depts) |> display
    #=>
    @VectorTree of 3 × (1:N) × (name = (1:1) × String,
                                position = (1:1) × String,
                                salary = (0:1) × Int64,
                                rate = (0:1) × Float64):
     [(name = "JEFFERY A", position = "SERGEANT", salary = 101442, rate = missing), (name = "NANCY A", position = "POLICE OFFICER", salary = 80016, rate = missing)]
     [(name = "JAMES A", position = "FIRE ENGINEER-EMT", salary = 103350, rate = missing), (name = "DANIEL A", position = "FIRE FIGHTER-EMT", salary = 95484, rate = missing)]
     [(name = "LAKENYA A", position = "CROSSING GUARD", salary = missing, rate = 17.68), (name = "DORIS A", position = "CROSSING GUARD", salary = missing, rate = 19.38)]
    =#

The expected input and output of a pipeline can be specified by its
*signature*.

    dept_employee =
        dept_employee |> designate(dept_shp, BlockOf(emp_shp, x1toN) |> IsFlow)

Here, we also annotate the output shape with `IsFlow` to indicate its special
role in pipeline composition.

Two adjacent field pipelines may form a *path*.  For example, consider the
*rate* pipeline.

    emp_rate =
        column(:rate) |> designate(emp_shp, BlockOf(Float64, x0to1) |> IsFlow)

    signature(emp_rate)
    #=>
    Signature(TupleOf(:name => BlockOf(String, x1to1),
                      :position => BlockOf(String, x1to1),
                      :salary => BlockOf(Int64, x0to1),
                      :rate => BlockOf(Float64, x0to1)),
              BlockOf(Float64, x0to1) |> IsFlow)
    =#

We wish to form a path through the fields *employee* and *rate*.  However, the
pipelines `dept_employee` and `emp_rate` cannot be chained into
`chain_of(dept_employee, emp_rate)` because their intermediate shapes do not
match.

    fits(target(dept_employee), source(emp_rate))   #-> false

On the other hand, these pipelines could be composed using the *elementwise
composition* combinator.

    dept_employee_rate = compose(dept_employee, emp_rate)
    #=>
    chain_of(column(:employee),
             chain_of(with_elements(column(:rate)), flatten()))
    =#

    dept_employee_rate(depts)
    #-> @VectorTree (0:N) × Float64 [[], [], [17.68, 19.38]]

    signature(dept_employee_rate)
    #=>
    Signature(TupleOf(:name => BlockOf(String, x1to1),
                      :employee =>
                          BlockOf(TupleOf(
                                      :name => BlockOf(String, x1to1),
                                      :position => BlockOf(String, x1to1),
                                      :salary => BlockOf(Int64, x0to1),
                                      :rate => BlockOf(Float64, x0to1)),
                                  x1toN)),
              BlockOf(Float64) |> IsFlow)
    =#

Elementwise composition connects the pipelines by fusing their output flows.
The least upper bound of the flow cardinalities is the cardinality of the fused
flow.

    dept_employee_card = cardinality(target(dept_employee))
    #-> x1toN

    emp_rate_card = cardinality(target(emp_rate))
    #-> x0to1

    dept_employee_rate_card = cardinality(target(dept_employee_rate))
    #-> x0toN

    dept_employee_card|emp_rate_card == dept_employee_rate_card
    #-> true

## Flow and Scope

Elementwise composition is a sequential composition with special handling of
two types of containers: *flow* and *scope*.

The flow is a `BlockVector` that wraps the output of the pipeline.  When two
pipelines are composed, their output flows are fused together.

The scope is a `TupleVector` that augments the input data with extra context
parameters.  When pipelines are composed, the context is passed along the
composition.

For example, consider a pipeline that wraps the function `round` and expects
the precision to be passed as a context parameter `:P`.

    round_digits(x, d) = round(x, digits=d)

    round_it =
        chain_of(
            tuple_of(column(1),
                     chain_of(column(2), column(:P))),
            tuple_lift(round_digits),
            wrap())

    round_it(@VectorTree (Float64, (P = (1:1)Int,)) [(17.68, (P = 1,)), (19.38, (P = 1,))])
    #-> @VectorTree (1:1) × Float64 [17.7, 19.4]

To be able to use this pipeline in composition, we assign it its signature.

    round_it =
        round_it |> designate(TupleOf(Float64, TupleOf(:P => Float64)) |> IsScope,
                              BlockOf(Float64, x1to1) |> IsFlow)

When two pipelines have compatible intermediate domains, they could be
composed.

    domain(target(dept_employee_rate))
    #-> ValueOf(Float64)

    domain(source(round_it))
    #-> ValueOf(Float64)

    dept_employee_round_rate = compose(dept_employee_rate, round_it)

The composition also has a signature assigned to it.  The input of the
composition should contain the department data together with a parameter `P`.

    signature(dept_employee_round_rate)
    #=>
    Signature(TupleOf(TupleOf(
                          :name => BlockOf(String, x1to1),
                          :employee =>
                              BlockOf(
                                  TupleOf(
                                      :name => BlockOf(String, x1to1),
                                      :position => BlockOf(String, x1to1),
                                      :salary => BlockOf(Int64, x0to1),
                                      :rate => BlockOf(Float64, x0to1)),
                                  x1toN)),
                      TupleOf(:P => Float64)) |>
              IsScope,
              BlockOf(Float64) |> IsFlow)
    =#

To run this pipeline, we pack the input data together with parameters.

    slots = @VectorTree (P = Int,) [(P = 1,), (P = 1,), (P = 1,)]

    input = TupleVector(:depts => depts, :slots => slots)

    dept_employee_round_rate(input)
    #-> @VectorTree (0:N) × Float64 [[], [], [17.7, 19.4]]


## API Reference

```@autodocs
Modules = [DataKnots]
Pages = ["shapes.jl"]
Public = false
```

## Test Suite

### Cardinality

`Cardinality` constraints are partially ordered.  For two `Cardinality`
constraints, we can determine whether one is more strict than the other.

    fits(x0to1, x1toN)          #-> false
    fits(x1to1, x0toN)          #-> true


### Data shapes

The structure of composite data is specified with *shape* objects.

A regular vector containing values of a specific type is indicated by the
`ValueOf` shape.

    str_shp = ValueOf(String)
    #-> ValueOf(String)

    eltype(str_shp)
    #-> String

The structure of a `BlockVector` object is described using `BlockOf` shape.

    rate_shp = BlockOf(Float64, x0to1)
    #-> BlockOf(Float64, x0to1)

    cardinality(rate_shp)
    #-> x0to1

    elements(rate_shp)
    #-> ValueOf(Float64)

    eltype(rate_shp)
    #-> Union{Missing, Float64}

For a `TupleVector`, the column shapes and their labels are described with
`TupleOf`.

    emp_shp = TupleOf(:name => BlockOf(String, x1to1),
                      :position => BlockOf(String, x1to1),
                      :salary => BlockOf(Int, x0to1),
                      :rate => BlockOf(Float64, x0to1))
    #=>
    TupleOf(:name => BlockOf(String, x1to1),
            :position => BlockOf(String, x1to1),
            :salary => BlockOf(Int64, x0to1),
            :rate => BlockOf(Float64, x0to1))
    =#

    labels(emp_shp)
    #-> [:name, :position, :salary, :rate]

    label(emp_shp, 4)
    #-> :rate

    columns(emp_shp)
    #-> DataKnots.AbstractShape[BlockOf(String, x1to1), BlockOf(String, x1to1), BlockOf(Int64, x0to1), BlockOf(Float64, x0to1)]

    column(emp_shp, :rate)
    #-> BlockOf(Float64, x0to1)

    column(emp_shp, 4)
    #-> BlockOf(Float64, x0to1)

It is possible to specify the shape of a `TupleVector` without labels.

    cmp_shp = TupleOf(BlockOf(Int, x0to1), BlockOf(Int, x1to1))
    #-> TupleOf(BlockOf(Int64, x0to1), BlockOf(Int64, x1to1))

In this case, the columns will be assigned *ordinal* labels.

    label(cmp_shp, 1)   #-> Symbol("#A")
    label(cmp_shp, 2)   #-> Symbol("#B")


### Annotations

Any shape can be assigned a label using `IsLabeled` annotation.

    lbl_shp = BlockOf(String, x1to1) |> IsLabeled(:name)

    subject(lbl_shp)
    #-> BlockOf(String, x1to1)

    label(lbl_shp)
    #-> :name

A `BlockOf` shape is annotated with `IsFlow` to indicate that the container
holds the output flow of a pipeline.

    flw_shp = BlockOf(String, x1to1) |> IsFlow

    subject(flw_shp)
    #-> BlockOf(String, x1to1)

The shape of the flow elements could be easily accessed or replaced.

    elements(flw_shp)
    #-> ValueOf(String)

    replace_elements(flw_shp, ValueOf(Int))
    #-> BlockOf(Int64, x1to1) |> IsFlow

A `TupleOf` shape is annotated with `IsScope` to indicate that the container
holds the scoping context of a pipeline.

    scp_shp = TupleOf(Float64, TupleOf(:P => Int)) |> IsScope

    subject(scp_shp)
    #-> TupleOf(Float64, TupleOf(:P => Int64))

We can get the shapes of the input data and the context parameters.

    context(scp_shp)
    #-> TupleOf(:P => Int64)

    column(scp_shp)
    #-> ValueOf(Float64)

    replace_column(scp_shp, ValueOf(Int))
    #-> TupleOf(Int64, TupleOf(:P => Int64)) |> IsScope


### Shape ordering

A single vector instance may satisfy many different shape constraints.

    bv = BlockVector(:, ["Chicago"])

    fits(bv, BlockOf(String, x1to1))        #-> true
    fits(bv, BlockOf(AbstractString))       #-> true
    fits(bv, AnyShape())                    #-> true

We can tell, for any two shape constraints, if one of them is more specific
than the other.

    fits(ValueOf(Int), ValueOf(Number))     #-> true
    fits(ValueOf(Int), ValueOf(String))     #-> false

    fits(BlockOf(Int, x1to1),
         BlockOf(Number, x0to1))            #-> true
    fits(BlockOf(Int, x1toN),
         BlockOf(Number, x0to1))            #-> false
    fits(BlockOf(Int, x1to1),
         BlockOf(String, x0to1))            #-> false

    fits(TupleOf(BlockOf(Int, x1to1),
                 BlockOf(String, x0to1)),
         TupleOf(BlockOf(Number, x1to1),
                 BlockOf(String, x0toN)))   #-> true
    fits(TupleOf(BlockOf(Int, x0to1),
                 BlockOf(String, x1to1)),
         TupleOf(BlockOf(Number, x1to1),
                 BlockOf(String, x0toN)))   #-> false
    fits(TupleOf(BlockOf(Int, x1to1)),
         TupleOf(BlockOf(Number, x1to1),
                 BlockOf(String, x0toN)))   #-> false

Shapes of different kinds are typically not compatible with each other.  The
exceptions are `AnyShape()` and `NoShape()`.

    fits(ValueOf(Int), BlockOf(Int))        #-> false
    fits(ValueOf(Int), AnyShape())          #-> true
    fits(NoShape(), ValueOf(Int))           #-> true

Column labels are treated as additional shape constraints.

    fits(TupleOf(:name => String),
         TupleOf(:name => String))          #-> true
    fits(TupleOf(String),
         TupleOf(:position => String))      #-> false
    fits(TupleOf(:name => String),
         TupleOf(String))                   #-> true
    fits(TupleOf(:name => String),
         TupleOf(:position => String))      #-> false

Similarly, annotations are treated as shape constraints.

    fits(String |> IsLabeled(:name),
         String |> IsLabeled(:name))        #-> true
    fits(ValueOf(String),
         String |> IsLabeled(:position))    #-> false
    fits(String |> IsLabeled(:name),
         ValueOf(String))                   #-> true
    fits(String |> IsLabeled(:name),
         String |> IsLabeled(:position))    #-> false

    fits(BlockOf(String, x1to1) |> IsFlow,
         BlockOf(String, x0toN) |> IsFlow)  #-> true
    fits(BlockOf(String, x1to1),
         BlockOf(String, x0toN) |> IsFlow)  #-> false
    fits(BlockOf(String, x1to1) |> IsFlow,
         BlockOf(String, x0toN))            #-> true

    fits(TupleOf(Int, TupleOf(:X => Int))
         |> IsScope,
         TupleOf(Int, TupleOf(:X => Int))
         |> IsScope)                        #-> true
    fits(TupleOf(Int, TupleOf(:X => Int)),
         TupleOf(Int, TupleOf(:X => Int))
         |> IsScope)                        #-> false
    fits(TupleOf(Int, TupleOf(:X => Int))
         |> IsScope,
         TupleOf(Int, TupleOf(:X => Int)))  #-> true


### Shape of a vector

Function `shapeof()` determines the shape of a given vector.

    shapeof(["GARRY M", "ANTHONY R", "DANA A"])
    #-> ValueOf(String)

    shapeof(@VectorTree ((1:1)String, (0:1)Int) [])
    #-> TupleOf(BlockOf(String, x1to1), BlockOf(Int64, x0to1))

    shapeof(@VectorTree (name = String, employee = [String]) [])
    #-> TupleOf(:name => String, :employee => BlockOf(String))


### Pipeline signature

A `Signature` object describes the shapes of a pipeline's input and output.

    sig = Signature(ValueOf(UInt),
                    BlockOf(TupleOf(:name => BlockOf(String, x1to1),
                                    :employee => BlockOf(UInt, x0toN))) |> IsFlow)
    #=>
    Signature(ValueOf(UInt64),
              BlockOf(TupleOf(:name => BlockOf(String, x1to1),
                              :employee => BlockOf(UInt64))) |>
              IsFlow)
    =#

Components of the signature can be easily extracted.

    target(sig)
    #=>
    BlockOf(TupleOf(:name => BlockOf(String, x1to1),
                    :employee => BlockOf(UInt64))) |>
    IsFlow
    =#

    source(sig)
    #-> ValueOf(UInt64)


## Rendering as a graph

Function `print_graph()` visualizes a shape constraint as a tree.

    print_graph(ValueOf(String))
    #-> #  String

    print_graph(BlockOf(String, x1to1))
    #-> #  1:1 × String

    print_graph(BlockOf(String, x1to1) |> IsLabeled(:name))
    #-> name  1:1 × String

    print_graph(
        TupleOf(
            :name => String,
            :position => String,
            :salary => Int) |> IsLabeled(:employee))
    #=>
    employee
    ├╴name      String
    ├╴position  String
    └╴salary    Int64
    =#

    print_graph(
        BlockOf(
            TupleOf(
                TupleOf(
                    :name => BlockOf(String, x1to1),
                    :position => BlockOf(String, x1to1),
                    :salary => BlockOf(Int, x0to1),
                    :rate => BlockOf(Float64, x0to1)) |> IsLabeled(:employee),
                TupleOf(:mean_salary => BlockOf(Float64, x0to1))) |> IsScope,
            x0toN) |> IsFlow)
    #=>
    #                0:N
    ├╴employee
    │ ├╴name         1:1 × String
    │ ├╴position     1:1 × String
    │ ├╴salary       0:1 × Int64
    │ └╴rate         0:1 × Float64
    └╴#B
      └╴mean_salary  0:1 × Float64
    =#

