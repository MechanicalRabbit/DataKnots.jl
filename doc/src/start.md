# Getting Started

DataKnots is currently usable for contributors who wish to help
grow the ecosystem. However, DataKnots is not yet usable for
general audiences: with v0.1, there are no data source adapters
and we lack important operators, such as `Sort` and `Group`. Many
of these deficiencies were prototyped and subsequent releases will
address these feature gaps incrementally.

This is a Julia language library; hence, the DataKnot syntax is
necessarily in the Julia language. We've taken pride to provide a
usable notation even without using macros. In a future release we
will likely include a DataKnot macro syntax as well. Such a macro
syntax would be compatible with this language integrated approach.

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
        (name = "POLICE",
         employee = [
          (name = "JEFFERY A", position = "SERGEANT",
           salary = 101442),
          (name = "NANCY A", position = "POLICE OFFICER",
           salary = 80016)]),
        (name = "FIRE",
         employee = [
          (name = "DANIEL A", position = "FIRE FIGHTER-EMT",
           salary = 95484)])],);

To query this data, we convert it into a `DataKnot`. Any *knot*
can be converted back to native Julia via the `get` function.

    using DataKnots
    ChicagoData = DataKnot(chicago_data)
    typeof(get(ChicagoData))
    #-> NamedTuple{(:department,),⋮

In this hierarchical Chicago data, the root is a `NamedTuple` with
an entry `:department`, that `Vector` valued entry has another
vector of tuples labeled `:employee`. The label `name` occurs both
within the context of a department and an employee record.

### Navigation

To list all the department names we write `It.department.name`.
In this pipeline, `It` means "use the current input". The dotted
notation lets one navigate via hierarchy.

    run(ChicagoData, It.department.name)
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

Navigation context matters. For example, `employee` tuples are not
directly accessible from the root of the dataset provided. When a
label can't be found, an appropriate error message is displayed.

    run(ChicagoData, It.employee)
    #-> ERROR: cannot find employee ⋮

Instead, `employee` tuples can be accessed by navigating though
`department` tuples.

    run(ChicagoData, It.department.employee)
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
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
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

The `Get()` pipeline primitive reproduces contents from a named
container. Pipeline composition `>>` merges results from nested
traversal. They can be used together creatively.

    run(ChicagoData, Get(:department) >> Get(:employee))
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
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
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

This motivates our clever use of `It` as a syntax short hand.

    run(ChicagoData, It.department.name)
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

This pipeline, `It.department.name`, could be equivalently written
`Get(:department) >> Get(:name)`. In a Julia macro syntax, this
path could be written plainly `department.employee` without `It`.

### Context & Counting

To return the number of departments in this Chicago dataset we
write `Count(It.department)`. Observe that the argument provided
to `Count()`, `It.department`, is itself a pipeline.

    run(ChicagoData, Count(It.department))
    #=>
    │ It │
    ┼────┼
    │  2 │
    =#

Using pipeline composition (`>>`), we can perform `Count` in a
nested context; for this next example, let's count `employee`
records within each `department`.

    run(ChicagoData,
        It.department
        >> Count(It.employee))
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  1 │
    =#

In this output we see that the 1st department, `"POLICE"`, has `2`
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
      │ name    #B │
    ──┼────────────┼
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
    ──┼───────────────────────────────────────────┼
    1 │ POLICE  JEFFERY A, 101442; NANCY A, 80016 │
    2 │ FIRE    DANIEL A, 95484                   │
    =#

In this nested display, commas are used to separate fields and
semi-colons separate values.

### Expressions & Output Labels

Pipeline expressions can be named and reused. Further, the output
column of these named pipelines may be labeled using Julia's
`Pair` syntax (`=>`). For example, let's define `EmployeeCount` to
be the number of employees in a given department.

    EmployeeCount =
      :employee_count =>
        Count(It.employee)

    run(ChicagoData,
        It.department
        >> Record(It.name,
                  EmployeeCount))
    #=>
      │ department             │
      │ name    employee_count │
    ──┼────────────────────────┼
    1 │ POLICE               2 │
    2 │ FIRE                 1 │
    =#

Labels can be attached to an existing pipeline using the `Label`
primitive. This form is handy for use in successive pipeline
refinements (`>>=`).

    DeptCount = Count(It.department)
    DeptCount >>= Label(:dept_count)

    run(ChicagoData, DeptCount)
    #=>
    │ dept_count │
    ┼────────────┼
    │          2 │
    =#

Besides providing a lovely display title, labels also provide a
way to access fields within a record.

    run(ChicagoData,
        Record(It, DeptCount)
        >> It.dept_count)
    #=>
    │ dept_count │
    ┼────────────┼
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
      │ department           │
      │ name  employee_count │
    ──┼──────────────────────┼
    1 │ FIRE               1 │
    =#

In pipeline expressions, the broadcast variant of common
operators, such as `.==` are to be used. Forgetting the period is
an easy mistake to make and the Julia language error message can
be unhelpful.

    run(ChicagoData,
        It.department
        >> Filter(EmployeeCount == 1)
        >> Record(It.name, EmployeeCount))
    #=>
    ERROR: AssertionError: eltype(input) <: AbstractVector
    =#

Let's define `GT100K` to check if an employee's salary is greater
than 100K. The output of this pipeline is also labeled.

    GT100K =
      :gt100k =>
        It.salary .> 100000

    run(ChicagoData,
        It.department.employee
        >> Record(It.name, It.salary, GT100K))
    #=>
      │ employee                  │
      │ name       salary  gt100k │
    ──┼───────────────────────────┼
    1 │ JEFFERY A  101442    true │
    2 │ NANCY A     80016   false │
    3 │ DANIEL A    95484   false │
    =#

Since `Filter` takes a boolean valued pipeline for an argument, we
could use `GTK100K` to filter employees.

    run(ChicagoData,
        It.department.employee
        >> Filter(GT100K)
        >> It.name)
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    =#

### Incremental Composition

This data discovery could have been done incrementally, with each
intermediate pipeline being fully runnable. Let's start `OurQuery`
as a list of employees. We're not going to `run` it, but we could.

    OurQuery = It.department.employee
    #-> It.department.employee

Let's extend this pipeline to compute and show if the salary is
over 100k. Notice how pipeline composition is unwrapped and
tracked for us. We could `run` this step also, if we wanted.

    GT100K = :gt100k => It.salary .> 100000
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
    ──┼───────────────────────────┼
    1 │ JEFFERY A  101442    true │
    =#

Well-tested pipelines may benefit from being given a `Tag` so that
their definitions are suppressed in larger compositions.

    GT100K = Tag(:GT100K, :gt100k => It.salary .> 100000)
    #-> GT100K

This tagging can make subsequent compositions easier to read, when
the definition of the named pipeline is not being questioned.

    OurQuery = It.department.employee >>
                 Record(It.name, It.salary, GT100K)
    #=>
    It.department.employee >> Record(It.name, It.salary, GT100K)
    =#

Notice that the tag (`:GT100K`) is distinct from the data label
(`:gt100k`), the tag names the pipeline while the label names the
output column.

    OurQuery >>= Filter(It.gt100k)
    run(ChicagoData, OurQuery)
    #=>
      │ employee                  │
      │ name       salary  gt100k │
    ──┼───────────────────────────┼
    1 │ JEFFERY A  101442    true │
    =#

For the final step of our incremental construction, in the journey, let's only show the employee's
name that met the GT100K criteria.

    OurQuery >>= It.name
    run(ChicagoData, OurQuery)
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    =#

### Aggregate pipelines

Aggregates, such as `Count` may be used directly as a pipeline,
providing incremental refinement without additional nesting. In
this next example, `Count` takes an input of filtered employees,
and returns the size of its input.

    run(ChicagoData,
        It.department.employee
        >> Filter(It.salary .> 100000)
        >> Count)
    #=>
    │ It │
    ┼────┼
    │  1 │
    =#

Aggregate pipelines operate contextually. In the following
example, `Count` is performed relative to each department.

    run(ChicagoData,
        It.department
        >> Record(
            It.name,
            :over_100k =>
              It.employee
              >> Filter(It.salary .> 100000)
              >> Count))
    #=>
      │ department        │
      │ name    over_100k │
    ──┼───────────────────┼
    1 │ POLICE          1 │
    2 │ FIRE            0 │
    =#

Note that in `It.department.employee >> Count`, the `Count`
pipeline aggregates the number of employees across all
departments. This doesn't change even if we add parentheses:

    run(ChicagoData,
        It.department >> (It.employee >> Count))
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#

To count employees in *each* department, we use the `Each()`
pipeline constructor.

    run(ChicagoData,
        It.department >> Each(It.employee >> Count))
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  1 │
    =#

Naturally, we could use the `Count()` pipeline constructor to
get the same result.

    run(ChicagoData,
        It.department >> Count(It.employee))
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  1 │
    =#

Which form of an aggregate to use depends upon what is
notationally convenient.  For incremental construction, being
able to simply append `>> Count` is often very helpful.

    OurQuery = It.department.employee
    run(ChicagoData, OurQuery >> Count)
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#

### Paging Data

Sometimes query results can be quite large. In this case it's
helpful to `Take` or `Drop` items from the input stream. Let's
start by listing all 3 employees of our toy database.

    Employee = It.department.employee
    run(ChicagoData, Employee)
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ NANCY A    POLICE OFFICER     80016 │
    3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

To return up to the 2nd employee record, we use `Take`.

    run(ChicagoData, Employee >> Take(2))
    #=>
      │ employee                          │
      │ name       position        salary │
    ──┼───────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT        101442 │
    2 │ NANCY A    POLICE OFFICER   80016 │
    =#

A negative index can be used to count records from the end of the
pipeline's input. So, to return up to, but not including, the very
last item in the stream, we could write:

    run(ChicagoData, Employee >> Take(-1))
    #=>
      │ employee                          │
      │ name       position        salary │
    ──┼───────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT        101442 │
    2 │ NANCY A    POLICE OFFICER   80016 │
    =#

To return the last record of the pipeline's input, we could `Drop`
up to the last item in the stream:

    run(ChicagoData, Employee >> Drop(-1))
    #=>
      │ employee                           │
      │ name      position          salary │
    ──┼────────────────────────────────────┼
    1 │ DANIEL A  FIRE FIGHTER-EMT   95484 │
    =#

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
    ──┼────────────┼
    1 │ Jeffery    │
    2 │ Nancy      │
    3 │ Daniel     │
    =#

Aggregate Julia functions, such as `mean`, can also be used.

    using Statistics: mean

    run(ChicagoData,
        It.department
        >> Record(
            It.name,
            :mean_salary =>
              mean.(It.employee.salary)))
    #=>
      │ department          │
      │ name    mean_salary │
    ──┼─────────────────────┼
    1 │ POLICE      90729.0 │
    2 │ FIRE        95484.0 │
    =#

The more general form of `Lift`, documented in the reference. How
a lifted function is treated as a pipeline constructor depends
upon that function's input and output signature.

### Query Parameters

The `run` function takes named parameters. Each argument passed
via named parameter is converted into a `DataKnot` and then made
available as a label accessible anywhere in the pipeline.

    run(ChicagoData, It.AMT, AMT=100000)
    #=>
    │ AMT    │
    ┼────────┼
    │ 100000 │
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
    ──┼───────────┼
    1 │ JEFFERY A │
    =#

With a different threshold amount, the result may change.

    run(ChicagoData, PaidOverAmt, AMT=85000)
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    2 │ DANIEL A  │
    =#

### Parameterized Pipelines

Suppose we want a parameterized pipeline that could take other
pipelines as arguments. Let's define `EmployeesOver()` to return
`employee` records that have salary greater than a given amount.

    EmployeesOver(X) = (
        It.department
        >> It.employee
        >> Filter(It.salary .> X))

    run(ChicagoData, EmployeesOver(100000))
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┼
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

Let's list employees having greater than average salary. To start,
we must first compute the average salary.

    AvgSalary = mean.(It.department.employee.salary)

    run(ChicagoData, AvgSalary)
    #=>
    │ It      │
    ┼─────────┼
    │ 92314.0 │
    =#

We could use this *knot* value as a parameter to a subsequent
`run` of `EmployeesOver()`. This works, but is not elegant.

    run(ChicagoData,
        EmployeesOver(It.AMT),
        AMT=run(ChicagoData, AvgSalary))
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

However, if we try to combine these two pipelines directly, we get
a naming error.

    run(ChicagoData, EmployeesOver(AvgSalary))
    #-> ERROR: cannot find department ⋮

By looking at the definition, we can see the problem: in the scope
of `employee` there is no attribute `department`.

    EmployeesOver(AvgSalary)
    #=>
    It.department >>
    It.employee >>
    Filter(It.salary .> mean.(It.department.employee.salary))
    =#

This challenge can be overcome with `Given`, which evaluates its
named arguments in the current scope and makes those values
available within a subordinate pipeline.

    EmployeesOver(X) =
      Given(:AMT => X,
        It.department
        >> It.employee
        >> Filter(It.salary .> It.AMT))

We could then combine these two pipelines.

    run(ChicagoData, EmployeesOver(AvgSalary))
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

Note that this expression is yet another pipeline that could be
refined with further computation.

    run(ChicagoData,
        EmployeesOver(AvgSalary)
        >> It.name)
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    2 │ DANIEL A  │
    =#

Although `Given` in this parameterized query defines `It.amt`,
this computation's label doesn't leak outside the definition.

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

    run(ChicagoData,
         It.department
         >> Keep(:dept_name => It.name)
         >> It.employee
         >> Record(It.name, It.dept_name))
    #=>
      │ employee             │
      │ name       dept_name │
    ──┼──────────────────────┼
    1 │ JEFFERY A  POLICE    │
    2 │ NANCY A    POLICE    │
    3 │ DANIEL A   FIRE      │
    =#

This pattern also emerges with aggregate computations which need
to be done in a parent scope. For example, let's compute employees
with a higher than average salary within their department.

    run(ChicagoData,
         It.department
         >> Keep(:mean_salary => mean.(It.employee.salary))
         >> It.employee
         >> Filter(It.salary .> It.mean_salary))
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┼
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

Compare this with an equivalent query prepared via `Given`.

    run(ChicagoData,
         It.department
         >> Given(:mean_salary => mean.(It.employee.salary),
              It.employee
               >> Filter(It.salary .> It.mean_salary)))
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┼
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

While `Keep` and `Given` are similar, `Keep` deliberately leaks
the values that it defines while not increasing the nesting. On
the other hand, `Given` increases nesting but doesn't leak.

### More Aggregates

There are other aggregate functions, such as `Min`, `Max`, and
`Sum`. They could be used to create a statistical measure.

    using Statistics: mean
    Stats(X) =
      Record(
        :count => Count(X),
        :mean => Int.(floor.(mean.(X))),
        :min => Min(X),
        :max => Max(X),
        :sum => Sum(X))

    run(ChicagoData,
        :salary_stats_for_all_employees =>
           Stats(It.department.employee.salary))
    #=>
    │ salary_stats_for_all_employees      │
    │ count  mean   min    max     sum    │
    ┼─────────────────────────────────────┼
    │     3  92314  80016  101442  276942 │
    =#

This `Stats()` pipeline constructor could be made usable as a
pipeline primitive using `Then()` as follows:

    run(ChicagoData,
        It.department
        >> Record(It.name,
             It.employee.salary
             >> Then(Stats)
             >> Label(:salary_stats)))
    #=>
      │ department                              │
      │ name    salary_stats                    │
    ──┼─────────────────────────────────────────┼
    1 │ POLICE  2, 90729, 80016, 101442, 181458 │
    2 │ FIRE    1, 95484, 95484, 95484, 95484   │
    =#

To avoid having to type in `Then()`, one could register an
automatic type conversion for the `Stats` function.

    DataKnots.Lift(::typeof(Stats)) = Then(Stats)

    run(ChicagoData,
        It.department.employee.salary
        >> Filter(It .< 100000)
        >> Stats)
    #=>
    │ count  mean   min    max    sum    │
    ┼────────────────────────────────────┼
    │     2  87750  80016  95484  175500 │
    =#

As an aside, `Stats` could also be tagged so that higher-level
pipelines don't `show` an expansion of its entire definition.

    Stats(X) =
      Tag(:Stats, (X,),
          Record(
            :count => Count(X),
            :mean => Int.(floor.(mean.(X))),
            :min => Min(X),
            :max => Max(X),
            :sum => Sum(X)))

    Stats(It.department.employee.salary)
    #-> Stats(It.department.employee.salary)

### Input Origin

When a pipeline is `run`, the input for a pipeline isn't simply a
data set, instead, it is a path between an *origin* and a set of
*target* values. For most pipeline constructors, such as
`Count()`, only the target is considered. However, sometimes the
origin of the input can be used as well.

For example, how could we return the first half of a pipeline's
input? We could start by computing the half-way point, using
integer division (`.÷`).

    Employee = It.department.employee
    Halfway = Count(Employee) .÷ 2
    run(ChicagoData, Halfway)
    #=>
    │ It │
    ┼────┼
    │  1 │
    =#

Then, use `Take` with this computed index.

    run(ChicagoData, Employee >> Take(Halfway))
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┼
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

This evaluation works because the pipeline that is built by `Take`
evaluates its argument, `Halfway` against the origin and not the
target of the pipeline's input stream.

