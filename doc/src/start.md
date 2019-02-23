# Getting Started

DataKnots is currently usable for contributors who wish to help
grow the ecosystem. However, it is not yet expected to be usable
for general audiences. In particular, with the v0.1 release, there
are no data source adapters. DataKnots currently lacks important
operators, such as `Sort`, among others. Many of these obvious
deficiencies have previously been implemented in prototype form.
Subsequent releases will add features incrementally.

## Installation

DataKnots.jl is a Julia library, but it is not yet registered with
the Julia package manager. To install it, run in the package shell
(enter with `]` from the Julia shell):

```juliarepl
pkg> add https://github.com/rbt-lang/DataKnots.jl
```

DataKnots.jl requires Julia 1.0 or higher.

If you want to modify the source code of DataKnots.jl, you need to
install it in development mode with:

```juliarepl
pkg> dev https://github.com/rbt-lang/DataKnots.jl
```

Our development chat is currently hosted on Gitter:
https://gitter.im/rbt-lang/rbt-proto

## Quick Tutorial

Consider a database with a tiny cross-section of public data from
Chicago, represented as nested `NamedTuple` and `Vector` objects.

    chicago_data =
      (department = [
        (name = "POLICE", employee = [
          (name = "JEFFERY A", position = "SERGEANT",
           salary = 101442),
          (name = "NANCY A", position = "POLICE OFFICER",
           salary = 80016)]),
        (name = "FIRE", employee = [
          (name = "DANIEL A", position = "FIRE FIGHTER-EMT",
           salary = 95484)])],);

To query this data via DataKnots, we need to first convert it into
a *knot* structure. A knot can be converted back to native Julia
via the `get` function.

    using DataKnots
    ChicagoData = DataKnot(chicago_data)
    typeof(get(ChicagoData))
    #-> NamedTuple{(:department,),⋮

It's helpful for the top-level object in a data source to be a
named tuple. In this Chicago data example, the very top of the
tree is named `"department"`.

### Navigation

Pipelines can be `run` on data knot. For example, to list all
department names in `ChicagoData`, we write `It.department.name`.
In this pipeline, `It` means "use the current input". The dotted
notation lets one navigate via hierarchy.

    run(ChicagoData, It.department.name)
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

Navigation context matters. For example, `employee` tuples are not
directly accessible from the root of the dataset provided.

    run(ChicagoData, It.employee)
    #-> ERROR: cannot find employee ⋮

In this case, `employee` tuples can be accessed by navigating
though `department` tuples.

    run(ChicagoData, It.department.employee)
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┤
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ NANCY A    POLICE OFFICER     80016 │
    3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

Notice that nested lists traversed during navigation are flattened
into a single output.

### Composition

Dotted navigations, such as `It.department.name`, are a syntax
shorthand for the `Get` primitive together with pipeline
composition (`>>`).

    run(ChicagoData, Get(:department) >> Get(:name))
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

The `Get(::Symbol)` primitive reproduces the contents from the
matching container. Pipeline composition `>>` combines results
across nested containers. For example, the next query shows
`employee` tuples across both departments.

    run(ChicagoData, Get(:department) >> Get(:employee))
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┤
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ NANCY A    POLICE OFFICER     80016 │
    3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

In this pipeline algebra, `It` is the identity relative to
pipeline composition (`>>`). Since `It` can be mixed into any
composition without changing the result, we can write:

    run(ChicagoData, It >> Get(:department) >> Get(:name))
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

This motivates our clever use of `It` as syntax short hand.

    run(ChicagoData, It.department.name)
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

Hence, subsequent examples using the `It.x.y` sugar could
equivalently be written `Get(:x) >> Get(:y)`.

### Counting

This next example returns the number of departments in the
dataset. Note that the argument to `Count`, `It.department`, is
itself a pipeline.

    run(ChicagoData, Count(It.department))
    #=>
    │ DataKnot │
    ├──────────┤
    │        2 │
    =#

Using pipeline composition (`>>`), we can perform `Count` in a
nested context; in this case, let's count `employee` records
within each `department`.

    run(ChicagoData,
        It.department
        >> Count(It.employee))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        1 │
    =#

Here we see that the 1st department, `"POLICE"`, has `2`
employees, while the 2nd, `"FIRE"` only has `1`. The occurance of
`It` within the subordinate pipeline `Count(It.employee)` refers
to each department individually, not to the dataset as a whole.

### Records

Returning values in tandem can be done with `Record`. We can
improve on the previous example to additionally include each
department's name.

    run(ChicagoData,
        It.department
        >> Record(It.name,
                  Count(It.employee)))
    #=>
      │ department │
      │ name    #2 │
    ──┼────────────┤
    1 │ POLICE   2 │
    2 │ FIRE     1 │
    =#

Records can be nested. The following department listing includes,
for each department, employee names and their salary.

    run(ChicagoData,
        It.department
        >> Record(It.name,
             It.employee >>
             Record(It.name, It.salary)))
    #=>
      │ department                                │
      │ name    employee                          │
    ──┼───────────────────────────────────────────┤
    1 │ POLICE  JEFFERY A, 101442; NANCY A, 80016 │
    2 │ FIRE    DANIEL A, 95484                   │
    =#

In this nested display, commas are used to separate fields and
semi-colons separate values.

### Expression Labels

Since DataKnots is compositional, reusable pipeline expressions
can be factored. These expressions can also be given a `Label`.

    EmployeeCount = (
      Count(It.employee)
      >> Label(:count))

    run(ChicagoData,
        It.department
        >> Record(It.name,
                  EmployeeCount))
    #=>
      │ department    │
      │ name    count │
    ──┼───────────────┤
    1 │ POLICE      2 │
    2 │ FIRE        1 │
    =#

The pair syntax (`=>`) will also attach an expression label.

    run(ChicagoData,
        :dept_count =>
          Count(It.department))
    #=>
    │ dept_count │
    ├────────────┤
    │          2 │
    =#

### Filtering Data

What would a query language be without filtering? Here we list
department names who have exactly one employee.

    run(ChicagoData,
        It.department
        >> Filter(EmployeeCount .== 1)
        >> Record(It.name, EmployeeCount))
    #=>
      │ department  │
      │ name  count │
    ──┼─────────────┤
    1 │ FIRE      1 │
    =#

In in pipeline expressions, the broadcast variant of common
operators, such as `.==` are to be used.

    run(ChicagoData,
        It.department
        >> Filter(EmployeeCount == 1)
        >> Record(It.name, EmployeeCount))
    #=>
    ERROR: AssertionError: eltype(input) <: AbstractVector
    =#

Let's define a `GT100K` pipeline to compute if an employee's
salary is greater than 100K.

    GT100K =
      :gt100k =>
        It.salary .> 100000

    run(ChicagoData,
        It.department.employee
        >> Record(It.name, It.salary, GT100K))
    #=>
      │ employee                  │
      │ name       salary  gt100k │
    ──┼───────────────────────────┤
    1 │ JEFFERY A  101442    true │
    2 │ NANCY A     80016   false │
    3 │ DANIEL A    95484   false │
    =#

Since `Filter` uses takes boolean valued pipeline for an
argument, we could use it to filter employees employees.

    run(ChicagoData,
        It.department.employee
        >> Filter(GT100K)
        >> It.name)
    #=>
      │ name      │
    ──┼───────────┤
    1 │ JEFFERY A │
    =#

### Lifting

Besides operators, such as greater than (`>`), arbitrary functions
can also be used within DataKnots using the broadcast notation.
Let's define a function to extract an employee's first name.

    fname(x) = titlecase(split(x)[1])
    fname("NANCY A")
    #-> "Nancy"

This `fname` function can then be used within a pipeline
expression to return first names of all employees.

    run(ChicagoData,
        It.department.employee
        >> fname.(It.name)
        >> Label(:first_name))
    #=>
      │ first_name │
    ──┼────────────┤
    1 │ Jeffery    │
    2 │ Nancy      │
    3 │ Daniel     │
    =#

Aggregate Julia functions, such as `mean`, can also be used. In
this case, let's make it a reusable expression, with it's own
built-in label.

    using Statistics: mean

    MeanSalary =
      :mean_salary =>
         mean.(It.employee.salary)

    run(ChicagoData,
        It.department
        >> Record(It.name, MeanSalary))
    #=>
      │ department          │
      │ name    mean_salary │
    ──┼─────────────────────┤
    1 │ POLICE      90729.0 │
    2 │ FIRE        95484.0 │
    =#

The more general form of `Lift`, documented in the reference, can
be used to handle more complex situations.

### Query Parameters

The `run` function takes named parameters. Each argument passed
via named parameter is converted into a `DataKnot` and made
available as a global label available anywhere in the pipeline.

    run(ChicagoData, It.AMT, AMT=100000)
    #=>
    │ DataKnot │
    ├──────────┤
    │   100000 │
    =#

This technique permits complex pipelines to be re-used with
different argument values. By convention we capitalize parameters
so they standout from regular data labels.

    PaidOverAmt = (
      It.department
      >> It.employee
      >> Filter(It.salary .> It.AMT)
      >> It.name)

    run(ChicagoData, PaidOverAmt, AMT=100000)
    #=>
      │ name      │
    ──┼───────────┤
    1 │ JEFFERY A │
    =#

With a different threshold amount, the result may change.

    run(ChicagoData, PaidOverAmt, AMT=85000)
    #=>
      │ name      │
    ──┼───────────┤
    1 │ JEFFERY A │
    2 │ DANIEL A  │
    =#

### Parameterized Pipelines

Suppose we want a parameterized pipeline that could be used
anywhere within another pipeline, or could take pipeline
arguments. Let's use an example returning `employee` records that
have salary greater than a given amount.

    EmployeesOver(N) =
      Given(:amt => N,
        It.department
        >> It.employee
        >> Filter(It.salary .> It.amt))

    run(ChicagoData, EmployeesOver(100000))
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┤
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

This pipeline could be passed an argument via a `run` parameter.

    run(ChicagoData, EmployeesOver(It.AMT), AMT=100000)
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┤
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

To return employees having greater than average salary, we must
first compute the average salary.

    AvgSalary =
       :avg_salary => mean.(It.department.employee.salary)

    run(ChicagoData, AvgSalary)
    #=>
    │ avg_salary │
    ├────────────┤
    │    92314.0 │
    =#

We could then combine these two pipelines.

    run(ChicagoData, EmployeesOver(AvgSalary))
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┤
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

Note that this high-level expression is yet another pipeline and
it could be combined within further computation.

    run(ChicagoData,
        EmployeesOver(AvgSalary)
        >> It.name)
    #=>
      │ name      │
    ──┼───────────┤
    1 │ JEFFERY A │
    2 │ DANIEL A  │
    =#

Although `Given` in this parameterized query defines `It.avg` it
doesn't leak this attribute.

     run(ChicagoData,
         EmployeesOver(AvgSalary)
         >> It.avg)
    #-> ERROR: cannot find avg ⋮

### Keeping Values

Suppose we'd like a list of employee names together with the
corresponding department name. The naive approach won't work,
because `department` is not a label in the context of an employee.

    run(ChicagoData,
         It.department
         >> It.employee
         >> Record(It.name, It.department.name))
    #-> ERROR: cannot find department ⋮

This can be overcome by using `Keep` to label an expression's
result, so that it is available within subsequent computations.

```julia
    run(ChicagoData,
         It.department
         >> Keep(:dept_name => It.name)
         >> It.employee
         >> Record(It.name, It.dept_name))
    #=>
      │ employee             │
      │ name       dept_name │
    ──┼──────────────────────┤
    1 │ JEFFERY A  POLICE    │
    2 │ NANCY A    POLICE    │
    3 │ DANIEL A   FIRE      │
    =#
```

This pattern also emerges with aggregate computations which need
to be done in a parent scope, for example, taking the `MeanSalary`
across all employees, before treating them individually.

```julia
    run(ChicagoData,
         It.department
         >> Keep(MeanSalary)
         >> It.employee
         >> Filter(It.salary .> It.mean_salary))
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┤
    1 │ JEFFERY A  SERGEANT  101442 │
    =#
```

While `Keep` and `Given` are similar, `Keep` deliberately leaks
the values that it defines.

# Paging

Sometimes query results can be quite large. In this case it's
helpful to `Take` or `Drop` items from a stream. Let's start by
listing all 3 employees of our toy database.

    run(ChicagoData, It.department.employee)
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┤
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ NANCY A    POLICE OFFICER     80016 │
    3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

To return the first 2 employee records, we use `Take`.

    run(ChicagoData,
        It.department.employee
        >> Take(2))
    #=>
      │ employee                          │
      │ name       position        salary │
    ──┼───────────────────────────────────┤
    1 │ JEFFERY A  SERGEANT        101442 │
    2 │ NANCY A    POLICE OFFICER   80016 │
    =#

