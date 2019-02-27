# Reference

DataKnots are a Julia library for building and evaluating data
processing pipelines. Each `Pipeline` represents a context-aware
data transformation; a pipeline's input and output is represented
by a `DataKnot`. Besides a few overloaded `Base` functions, such
as `run` and `get`, the bulk of this reference focuses on pipeline
constructors.

## Concept Overview

The DataKnots package exports two data types: `DataKnot` and
`Pipeline`. A `DataKnot` represents a data set, which may be
composite, hierarchical or cyclic; hence the monkier *knot*.
A `Pipeline` represents a context-aware data transformation from
an input knot to an output knot.

Consider the following example containing a cross-section of
public data from Chicago. This data could be modeled in native
Julia as a hierarchy of `NamedTuple` and `Vector` objects. Within
each `department` is a set of `employee` records.

    Emp = NamedTuple{(:name,:position,:salary,:rate),
                      Tuple{String,String,Union{Int,Missing},
                            Union{Float64,Missing}}}
    Dep = NamedTuple{(:name, :employee), 
                      Tuple{String,Vector{Emp}}}

    chicago_data = 
      (department = Dep[
       (name = "POLICE", employee = Emp[
         (name = "JEFFERY A", position = "SERGEANT", 
          salary = 101442, rate = missing), 
         (name = "NANCY A", position = "POLICE OFFICER", 
          salary = 80016, rate = missing)]), 
       (name = "FIRE", employee = Emp[
         (name = "JAMES A", position = "FIRE ENGINEER-EMT", 
          salary = 103350, rate = missing), 
         (name = "DANIEL A", position = "FIRE FIGHTER-EMT", 
          salary = 95484, rate = missing)]), 
       (name = "OEMC", employee = Emp[
         (name = "LAKENYA A", position = "CROSSING GUARD", 
          salary = missing, rate = 17.68), 
         (name = "DORIS A", position = "CROSSING GUARD", 
          salary = missing, rate = 19.38)])]
      ,);

We can inquire the maximum salary for each department using the
DataKnots system. Here we define a `MaxSalary` pipeline and then
incorporate it into the broader `DeptStats` pipeline. This
pipeline can then be `run` on the `ChicagoData` knot.

    using DataKnots
    MaxSalary = :max_salary => Max(It.employee.salary)
    DeptStats = Record(It.name, MaxSalary)
    ChicagoData = DataKnot(chicago_data)

    run(ChicagoData, It.department >> DeptStats)
    #=>
      │ department         │
      │ name    max_salary │
    ──┼────────────────────┼
    1 │ POLICE      101442 │
    2 │ FIRE        103350 │
    3 │ OEMC               │
    =#

The `MaxSalary` pipeline is context-aware: it assumes a list of
`employee` data found within a given `department`. It could be
used independently by first extracting a particular department.

     FindDept(X) = It.department >> Filter(It.name .== X)
     PoliceData = run(ChicagoData, FindDept("POLICE"))
     run(PoliceData, DeptStats)
    #=>
      │ department         │
      │ name    max_salary │
    ──┼────────────────────┼
    1 │ POLICE      101442 │
    =#

When the `MaxSalary` pipeline is invoked, it sees employee data
having an *origin* relative to each department. This is what we
mean by DataKnots being context-aware. In the `DeptStats` pipeline,
after each `MaxSalary` is computed, the results are integrated
to provide output of the `DeptStats` pipeline.

#### `DataKnots.Cardinality`

In DataKnots, the elementary unit is a collection of values, we
call a data *knot*. Besides the Julia datatype for a knot's
values, each data knot also has a *cardinality*. The bookkeeping
of cardinality is an essential aspect of pipeline evaluation.

Cardinality is a constraint on the number of values in a knot. A
knot is called *mandatory* if it must contain at least one value;
*optional* otherwise. Similarly, a knot is called *singular* if it
must contain at most one value; *plural* otherwise.

```julia
    REG::Cardinality = 0      # singular and mandatory
    OPT::Cardinality = 1      # optional, but singular
    PLU::Cardinality = 2      # plural, but mandatory
    OPT_PLU::Cardinality = 3  # optional and plural
```

To record the knot cardinality constraint we use the `OPT`, `PLU`
and `REG` flags of the type `DataKnots.Cardinality`. The `OPT` and
`PLU` flags express relaxations of the mandatory and singular
constraint, respectively. A `REG` knot, which is both mandatory
and singular, is called *regular* and it must contain exactly one
value. Conversely, a knot with both `OPT|PLU` flags has
*unconstrained* cardinality and may contain any number of values.

For any knot with values of Julia type `T`, the knot's
cardinality has a correspondence to native Julia types: A regular
knot corresponds to a single Julia value of type `T`.  An
unconstrained knot corresponds to `Vector{T}`. An optional knot
corresponds to `Union{Missing, T}`. There is no correspondence for
mandatory yet plural knots; however, `Vector{T}` could be used
with the convention that it always has at least one element.

### Creating & Extracting DataKnots

The constructor `DataKnot()` takes a native Julia object,
typically a vector or scalar value. The `get()` function can be
used to retrieve the DataKnot's native Julia value. Like most
libraries, `show()` will produce a suitable display.

#### `DataKnots.DataKnot`

```julia
    DataKnot(elts::AbstractVector, card::Cardinality=OPT|PLU)
```

In the general case, a `DataKnot` can be constructed from an
`AbstractVector` to produce a `DataKnot` with a given cardinality.
By default, the `card` of the collection is unconstrained.

```julia
    DataKnot(elt, card::Cardinality=REG)
```

As a convenience, a non-vector constructor is also defined, it
marks the collection as being both singular and mandatory.

```julia
    DataKnot(::Missing, card::Cardinality=OPT)
```

There is an edge-case constructor for the creation of a singular
but empty collection.

```julia
    DataKnot()
```

Finally, there is the *unit* knot, with a single value `nothing`;
this is the default, implicit `DataKnot` used when `run` is
evaluated without an input data source.

    DataKnot(["GARRY M", "ANTHONY R", "DANA A"])
    #=>
      │ It        │
    ──┼───────────┼
    1 │ GARRY M   │
    2 │ ANTHONY R │
    3 │ DANA A    │

    =#

    DataKnot("GARRY M")
    #=>
    │ It      │
    ┼─────────┼
    │ GARRY M │
    =#

    DataKnot(missing)
    #=>
    │ It │
    ┼────┼
    =#

    DataKnot()
    #=>
    │ It │
    ┼────┼
    │    │
    =#

Note that plural DataKnots are shown with an index, while singular
knots are shown without. Further note that the `missing` knot
doesn't have a value in its data block, unlike the unit knot which
has a value of `nothing`. When showing a `DataKnot`, we follow
Julia's command line behavior of rendering `nothing` as a blank
since we wish to display short string values unquoted.

#### `show`

```julia
    show(data::DataKnot)
```

Besides displaying plural and singular knots differently, the
`show` method has special treatment for `Tuple` and `NamedTuple`.

    DataKnot((name = "GARRY M", salary = 260004))
    #=>
    │ name     salary │
    ┼─────────────────┼
    │ GARRY M  260004 │
    =#

This permits a vector-of-tuples to be displayed as tabular data.

    DataKnot([(name = "GARRY M", salary = 260004),
              (name = "ANTHONY R", salary = 185364),
              (name = "DANA A", salary = 170112)])
    #=>
      │ name       salary │
    ──┼───────────────────┼
    1 │ GARRY M    260004 │
    2 │ ANTHONY R  185364 │
    3 │ DANA A     170112 │
    =#

#### `get`

```julia
    get(data::DataKnot)
```

A `DataKnot` can be converted into native Julia values using
`get`. Regular values are returned as native Julia. Plural values
are returned as a vector.

    get(DataKnot("GARRY M"))
    #=>
    "GARRY M"
    =#

    get(DataKnot(["GARRY M", "ANTHONY R", "DANA A"]))
    #=>
    ["GARRY M", "ANTHONY R", "DANA A"]
    =#

    get(DataKnot(missing))
    #=>
    missing
    =#

    show(get(DataKnot()))
    #=>
    nothing
    =#

Nested vectors and other data, such as a `TupleVector`, round-trip
though the conversion to a `DataKnot` and back using `get`.

    get(DataKnot([[260004, 185364], [170112]]))
    #=>
    Array{Int,1}[[260004, 185364], [170112]]
    =#

    get(DataKnot((name = "GARRY M", salary = 260004)))
    #=>
    (name = "GARRY M", salary = 260004)
    =#

The Implementation Guide provides for lower level details as to
the internal representation of a `DataKnot`. Libraries built with
this internal API may provide more convenient ways to construct
knots and retrieve values.

### Running Pipelines & Parameters

Pipelines can be evaluated against an input `DataKnot` using
`run()` to produce an output `DataKnot`. If an input is not
specified, the default *unit* knot, `DataKnot()`, is used. There
are several sorts of pipelines that could be evaluated.

#### `DataKnots.AbstractPipeline`

```julia
    struct DataKnot <: AbstractPipeline ... end
```

A `DataKnot` is viewed as a pipeline that produces its entire data
block for each input value it receives.

```julia
    struct Navigation <: AbstractPipeline ... end
```

For convenience, path-based navigation is also seen as a pipeline.
The identity pipeline, `It`, simply reproduces its input. Further,
when a parameter `x` is provided via `run()` it is available for
lookup with `It`.`x`.

```julia
    struct Pipeline <: AbstractPipeline ... end
```

Besides the primitives identified above, the remainder of this
reference is dedicated to various ways of constructing `Pipeline`
instances from other pipelines.

#### `run`

```julia
    run(F::AbstractPipeline; params...)
```

In its simplest form, `run` takes a pipeline with a set of named
parameters and evaluates the pipeline with the unit knot as input.
The parameters are each converted to a `DataKnot` before being
made available within the pipeline's evaluation.

```julia
    run(F::Pair{Symbol,<:AbstractPipeline}; params...)
```

Using Julia's `Pair` syntax, this `run` method provides a
convenient way to label an output `DataKnot`.

```julia
    run(db::DataKnot, F; params...)
```

The general case `run` permits easy use of a specific input data
source. It `run` applies the pipeline `F` to the input dataset
`db` elementwise with the context `params`.  Since the 1st
argument is a `DataKnot` and dispatch is unambiguous, the second
argument to the method can be automatically converted to a
`Pipeline` using `Lift`.

Therefore, we can write the following examples.

    run(DataKnot("Hello World"))
    #=>
    │ It          │
    ┼─────────────┼
    │ Hello World │
    =#

    run(:greeting => DataKnot("Hello World"))
    #=>
    │ greeting    │
    ┼─────────────┼
    │ Hello World │
    =#

    run(DataKnot("Hello World"), It)
    #=>
    │ It          │
    ┼─────────────┼
    │ Hello World │
    =#

    run(DataKnot(), "Hello World")
    #=>
    │ It          │
    ┼─────────────┼
    │ Hello World │
    =#

Named arguments to `run()` become additional values that are
accessible via `It`. Those arguments are converted into a
`DataKnot` if they are not already.

    run(It.hello, hello=DataKnot("Hello World"))
    #=>
    │ hello       │
    ┼─────────────┼
    │ Hello World │
    =#

    run(It.a .* (It.b .+ It.c), a=7, b=7, c=-1)
    #=>
    │ It │
    ┼────┼
    │ 42 │
    =#

Once a pipeline is `run()` the resulting `DataKnot` value can be
retrieved via `get()`.

    get(run(DataKnot(1), It .+ 1))
    #=>
    2
    =#

Like `get` and `show`, the `run` function comes Julia's `Base`,
and hence the methods defined here are only chosen if an argument
matches the signature dispatch.

## Pipeline Construction

...

