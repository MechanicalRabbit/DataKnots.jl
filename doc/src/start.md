# Getting Started

DataKnots is in active development and is not expected to be
usable for general audiences. In particular, with the v0.1
release, there are no data source adapters.

## Installation Instructions

DataKnots.jl is a Julia library, but it is not yet registered with
the Julia package manager.  To install it, run in the package
shell (enter with `]` from the Julia shell):

```juliarepl
pkg> add https://github.com/rbt-lang/DataKnots.jl
```

DataKnots.jl requires Julia 1.0 or higher.

If you want to modify the source code of DataKnots.jl, you need to
install it in development mode with:

```juliarepl
pkg> dev https://github.com/rbt-lang/DataKnots.jl
```

## Quick Tutorial

Consider the following database containing a tiny cross-section of
public data from Chicago, represented as nested `NamedTuple` and
`Vector` objects.

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
a *knot* structure. This data could then be converted back into
Julia structure via `get` function.

    using DataKnots
    ChicagoData = DataKnot(chicago_data)
    typeof(get(ChicagoData))
    #-> NamedTuple{(:department,),⋮

By convention, it is helpful if the top-level object in a data
structure be a named tuple. In our source dataset, the very top of
the tree is named `"department"`.

### Navigating

Pipeline queries can be `run` on data knot. For example, to list
all department names, we write `It.department.name`. In this
pipeline, `It` means "use the current input". The dotted notation
lets one navigate via hierarchy.

    run(ChicagoData, It.department.name)
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

Navigation context matters. For example, the `employee` tuples are
not directly accessible from the root of the dataset provided.

    run(ChicagoData, It.employee)
    #-> ERROR: cannot find employee ⋮

The `employee` tuples can be accessed by navigating though
`department` tuples.

    run(ChicagoData, It.department.employee)
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┤
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ NANCY A    POLICE OFFICER     80016 │
    3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

Notice that nested lists are flattened as necessary.

### Composition

Dotted expressions above are a syntax shorthand for the `Get`
primitive together with pipeline composition (`>>`). We could list
departments in this dataset more formally:

    Department, Employee, Name, Salary =
       Get.([:department, :employee, :name, :salary])

    run(ChicagoData, Department >> Name)
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

Since `It` is the pipeline identity, the query above could be
equivalently written:

    run(ChicagoData, It >> Department >> It >> Name)
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

We will use `It.department` in preference to `Department` as
defined to be `Get(:department)`.

### Counting

This example returns the number of departments in the dataset.

    run(ChicagoData, Count(It.department))
    #=>
    │ DataKnot │
    ├──────────┤
    │        2 │
    =#

Using pipeline composition (`>>`), we can perform `Count` in a
nested context; in this case, we count `employee` records within
each `department`.

    run(ChicagoData, 
        It.department 
        >> Count(It.employee))
    #=>
      │ DataKnot │
    ──┼──────────┤
    1 │        2 │
    2 │        1 │
    =#

In this toy dataset, we see that the 1st department, `"POLICE"`,
has `2` employees, while the 2nd, `"FIRE"` only has `1`.

### Labels

Since DataKnots is compositional, reusable pipeline expressions
can be factored. These expressions can be given a `Label`.

    EmployeeCount = (
      Count(It.employee) 
      >> Label(:count))

    run(ChicagoData,
        It.department
        >> EmployeeCount)
    #=>
      │ count │
    ──┼───────┤
    1 │     2 │
    2 │     1 │
    =#

The pair syntax (`=>`) sugar will also attach an expression label.

    run(ChicagoData,
        :dept_count =>
          Count(It.department))
    #=>
    │ dept_count │
    ├────────────┤
    │          2 │
    =#

### Records

Sometimes it is helpful to return two or more values in tandem;
this can be done with `Record`. In the following pipeline, `It`
refers to the current department; hence `It.name` refers to that
department's name.

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

Records can be nested. We could build a result that includes
department names and, within each department, employee names.

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

In the nested display, commas are used to separate fields and
semi-colons separate values.

### Filtering Data

Filtering data is also contextual. Here we list department names
who have exactly one employee.

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

Most broadcast operators just work.

    run(ChicagoData,
        It.department.employee
        >> Filter(It.salary .> 100000)
        >> It.name)
    #=>
      │ name      │
    ──┼───────────┤
    1 │ JEFFERY A │
    =#

### Lifting

Arbitrary Julia functions can also be used within DataKnots using
the broadcast notation. For example, `occursin` returns a boolean
value if its 1st argument is found within another. Hence, it could
be used within a filter expression.

    run(ChicagoData,
        It.department.employee.name
        >> Filter(occursin.("AN", It)))
    #=>
      │ name     │
    ──┼──────────┤
    1 │ NANCY A  │
    2 │ DANIEL A │
    =#

Aggregate julia functions, such as `mean`, can also be used.

    using Statistics: mean

    MeanSalary = (
      mean.(It.employee.salary)
      >> Label(:mean_salary))

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

The more general form of `Lift` can be used to handle more complex
situations. Its usage is documented in the reference.

### Keeping Values

It's possible to `Keep` an expression's result, so that it is
available within subsequent computations. For example, you may
want to return records of an employee's name with their
corresponding department's name.

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

Suppose we wish, for a given department, to return employees
having a salary greater than that department's average.

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

### Parameters

Suppose we want a parameterized pipeline that when passed a given
salary would return employees having greater than that salary.

    EmployeesOver(N) =
      Given(:avg => N,
       It.department
       >> It.employee
       >> Filter(It.salary .> It.avg))

    run(ChicagoData, EmployeesOver(100000))
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┤
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

This same query can be written as a parameter to `run`.

    run(ChicagoData, EmployeesOver(It.amt), amt=100000)
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┤
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

Now suppose we wish to run this to return employees having greater
than average salary?  We could compute the average salary across
all employees as follows.

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

