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

Consider a tiny cross-section of public data from Chicago,
represented as nested `NamedTuple` and `Vector` objects.

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

In this hierarchical Chicago data, the root is a `NamedTuple` with
an entry `:department`. This entry is a `Vector` of nested tuples,
one for each department. Each of those department tuples in turn
have a `:name` entry and an entry for `:employee` tuples.

### Navigation

To list all the department names we write `It.department.name`.
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

Instead, the `employee` tuples can be accessed by navigating
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

### Composition & Identity

Dotted navigations, such as `It.department.name`, are a syntax
shorthand for the `Get()` primitive together with pipeline
composition (`>>`).

    run(ChicagoData, Get(:department) >> Get(:name))
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

The `Get(:Symbol)` primitive reproduces the contents from a named
container. Pipeline composition `>>` combines results from nested
traversal. For example, the next pipeline returns employee tuples
across both departments.

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

Subsequent use of `It.x.y` syntax could be equivalently written
`Get(:x) >> Get(:y)`.

### Counting Data

To return the number of departments in this Chicago dataset we
write `Count(It.department)`. Observe that the argument provided
to `Count()`, `It.department`, is itself a pipeline.

    run(ChicagoData, Count(It.department))
    #=>
    │ DataKnot │
    ├──────────┤
    │        2 │
    =#

Using pipeline composition (`>>`), we can perform `Count` in a
nested context; for this next example, let's count `employee`
records within each `department`.

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
employees, while the 2nd, `"FIRE"` only has `1`. The occurrence of
`It` within the subordinate pipeline `Count(It.employee)` refers
to each department individually, not to the dataset as a whole.

### Record Construction

Returning values in tandem can be done with `Record()`. Let's
improve the output of the previous pipeline by including each
department's name alongside employee counts.

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

Records can be nested. The following listing includes, for each
department, employee names and their salary.

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

### Expressions & Output Labels

Pipeline expressions can be independently defined, encapsulating
logic and enabling reuse. Further, the output column of these
named pipelines may be labeled using the pair syntax (`=>`).
Consider an `EmployeeCount` pipeline that, within the context of a
department, returns the number of employees in that department.

    EmployeeCount =
      :count =>
        Count(It.employee)

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

Labels can also be attached to an existing pipeline using the
`Label` primitive. This form is handy for use in successive
pipeline refinements (`>>=`).

    DeptCount = Count(It.department)
    DeptCount >>= Label(:dept_count)

    run(ChicagoData, DeptCount)
    #=>
    │ dept_count │
    ├────────────┤
    │          2 │
    =#

Besides providing a lovely display title, labels also provide a
way to access fields within a record.

    run(ChicagoData,
        Record(It, DeptCount)
        >> It.dept_count)
    #=>
    │ dept_count │
    ├────────────┤
    │          2 │
    =#

### Filtering Data

Returning only wanted values can be done with `Filter()`. Here we
list department names who have exactly one employee.

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

In pipeline expressions, the broadcast variant of common
operators, such as `.==` are to be used. Forgetting the period is
an easy mistake to make and the Julia language error message can
be unhelpful to figuring out what went wrong.

    run(ChicagoData,
        It.department
        >> Filter(EmployeeCount == 1)
        >> Record(It.name, EmployeeCount))
    #=>
    ERROR: AssertionError: eltype(input) <: AbstractVector
    =#

Let's define a `GT100K` pipeline to decide if an employee's salary
is greater than 100K. The output of this pipeline is also labeled.

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

Since `Filter` uses takes boolean valued pipeline for an argument,
we could use `GTK100K` to filter employees.

    run(ChicagoData,
        It.department.employee
        >> Filter(GT100K)
        >> It.name)
    #=>
      │ name      │
    ──┼───────────┤
    1 │ JEFFERY A │
    =#

### Incremental Composition

This data discovery could have been done incrementally, with each
intermediate pipeline being fully runnable. Let's start `OurQuery`
as a list of employees. We're not going to `run` it, but we could.

    OurQuery = It.department.employee
    #-> It.department.employee

Let's extend this pipeline to inspect the `GT100K` computation.
Notice how pipeline composition is tracked for us. We could `run`
this step also, if we wanted.

    OurQuery >>= Record(It.name, It.salary, GT100K)
    #=>
    It.department.employee >>
    Record(It.name, It.salary, :gt100k => It.salary .> 100000)
    =#

Since labeling permits direct Record access, we could further
extend this pipeline to filter unwanted rows.

    OurQuery >>= Filter(It.gt100k)
    #=>
    It.department.employee >>
    Record(It.name, It.salary, :gt100k => It.salary .> 100000) >>
    Filter(It.gt100k)
    =#

Let's run it.

    run(ChicagoData, OurQuery)
    #=>
      │ employee                  │
      │ name       salary  gt100k │
    ──┼───────────────────────────┤
    1 │ JEFFERY A  101442    true │
    =#

For the final step in the journey, let's only show the employee's
name that met the criteria.

    OurQuery >>= It.name
    run(ChicagoData, OurQuery)
    #=>
      │ name      │
    ──┼───────────┤
    1 │ JEFFERY A │
    =#

# Paging Data

Sometimes query results can be quite large. In this case it's
helpful to `Take` or `Drop` items from the input stream. Let's
start by listing all 3 employees of our toy database.

    Employee = It.department.employee)
    run(ChicagoData, Employee)
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┤
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ NANCY A    POLICE OFFICER     80016 │
    3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

To return upto the 2nd employee record, we use `Take`.

    run(ChicagoData, Employee >> Take(2))
    #=>
      │ employee                          │
      │ name       position        salary │
    ──┼───────────────────────────────────┤
    1 │ JEFFERY A  SERGEANT        101442 │
    2 │ NANCY A    POLICE OFFICER   80016 │
    =#

A negative index can be used to mark records from the end of the
pipeline's input. So, to return upto, but not including, the very
last item in the stream, we could write:

    run(ChicagoData, Employee >> Take(-1))
    #=>
      │ employee                          │
      │ name       position        salary │
    ──┼───────────────────────────────────┤
    1 │ JEFFERY A  SERGEANT        101442 │
    2 │ NANCY A    POLICE OFFICER   80016 │
    =#

To return the last record of the pipeline's input, we could `Drop`
upto the last item in the stream:

    run(ChicagoData, Employee >> Drop(-1))
    #=>
      │ employee                           │
      │ name      position          salary │
    ──┼────────────────────────────────────┤
    1 │ DANIEL A  FIRE FIGHTER-EMT   95484 │
    =#

How could we return the first half of the pipeline's input? Start
by computing the half-way point, using integer division (`.÷`).

    Halfway = Count(Employee) .÷ 2
    run(ChicagoData, Halfway)
    #=>
    │ DataKnot │
    ├──────────┤
    │        1 │
    =#

Then, use `Take` with this computed index.

    run(ChicagoData, Employee >> Take(Halfway))
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┤
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

This works because the arguments to `Take`/`Drop` can be arbitrary
pipelines. However, unlike `Filter`, the arguments are evaluated
in the *origin*, not the *target* of the pipeline's input.

### Lifting

Besides broadcast operators, such as greater than (`.>`),
arbitrary functions can also be used with the broadcast notation.
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
be used to handle more complex situations. How the lifted function
is treated as a pipeline constructor depends upon that function's
input and output signature.

### Query Parameters

The `run` function takes named parameters. Each argument passed
via named parameter is converted into a `DataKnot` and then made
available as a label accessible anywhere in the pipeline.

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

Suppose we want a parameterized pipeline that could take other
pipelines as arguments. For example, let's return `employee`
records that have salary greater than a given amount.

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

The `Given` wrapper above is needed when the argument `N` is an
arbitrary pipeline. With `Given`, `N` is evaluated with its result
recorded as `It.amt`. This value can then be accessed from within
the subordinate pipeline expression.

In this way, a parameterized pipeline such as `EmployeesOver` can
be passed an argument via a `run` parameter.

    run(ChicagoData, EmployeesOver(It.AMT), AMT=100000)
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┤
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

Let's make this example more interesting. To return employees
having greater than average salary, we must first compute the
average salary.

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

Although `Given` in this parameterized query defines `It.amt` it
doesn't leak this attribute.

     run(ChicagoData,
         EmployeesOver(AvgSalary)
         >> It.amt)
    #-> ERROR: cannot find amt ⋮

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

