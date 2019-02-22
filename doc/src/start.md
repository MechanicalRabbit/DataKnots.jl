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

Consider the following example database containing a tiny
cross-section of public data from Chicago, represented as nested
`NamedTuple` and `Vector` objects.

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
a *knot* structure. This data could be converted back into Julia
structure via `get` function.

    using DataKnots
    ChicagoData = DataKnot(chicago_data)
    typeof(get(ChicagoData))
    #-> NamedTuple{(:department,),⋮

By convention, it is helpful if the top-level object in a data
structure be a named tuple. In our source dataset, the very top of
the tree is named `"department"`.

### Navigating

Pipeline queries can then be `run` on data knot. For example, to
list all department names, we write:

    run(ChicagoData, It.department.name)
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

In this pipeline, `It` means "use the current input" and the
period operator lets one navigate via the names provided. During
this navigation context matters. For example, given the data
provided, `employee` tuples are not directly accessible.

    run(ChicagoData, It.employee)
    #-> ERROR: cannot find employee ⋮

In DataKnots, nested lists are flatted as necessary, hence, we can
list all of the employees in the dataset as follows.

    run(ChicagoData, It.department.employee.name)
    #=>
      │ name      │
    ──┼───────────┤
    1 │ JEFFERY A │
    2 │ NANCY A   │
    3 │ DANIEL A  │
    =#

### Composition

The dotted expressions above are actually a syntax shorthand for
the `Lookup` operation together with composition (`>>`).

    Department = Lookup(:department)
    Name = Lookup(:name)

    run(ChicagoData, Department >> Name)
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

Since the pipeline `It` is the identity, the query above
could be equivalently written:

    run(ChicagoData, It >> Department >> It >> Name)
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    2 │ FIRE   │
    =#

From here on, we'll use `It.department`, and not
`Lookup(:department)`.

### Counting

We can count records. Here we return number of departments.

    get(run(ChicagoData, Count(It.department)))
    #-> 2

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

To aid in debugging expressions, the content of a pipeline
expression can be displayed.

    EmployeeCount
    #-> Count(It.employee) >> Label(:count)

### Records & Labels

Sometimes it is helpful to return two or more values in tandem;
this can be done with `Record`.

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

Showing department statistics might be generally useful, so let's
also assign it to a reusable pipeline.

    DeptStats =
      Record(It.name,
             EmployeeCount)

No matter how nested, pipeline expressions can be displayed

    DeptStats
    #-> Record(It.name, Count(It.employee) >> Label(:count))

### Filtering Data

Filtering data is also contextual. Here we list department names
who have exactly one employee.

    run(ChicagoData,
        It.department
        >> Filter(EmployeeCount .== 1)
        >> DeptStats)
    #=>
      │ department  │
      │ name  count │
    ──┼─────────────┤
    1 │ FIRE      1 │
    =#

Pipeline expressions can use arguments.

    HavingSize(N) = Filter(EmployeeCount .== N)

    run(ChicagoData,
        It.department
        >> HavingSize(2)
        >> DeptStats)
    #=>
      │ department    │
      │ name    count │
    ──┼───────────────┤
    1 │ POLICE      2 │
    =#

### Query Parameters

Query expressions may use outside parameters. The `run` command
can take a set of additional values that are accessible anywhere
within the query.

    DeptNameWith(N) = (
      It.department
      >> HavingSize(N)
      >> It.name)

    run(ChicagoData, DeptNameWith(It.no), no=1)
    #=>
      │ name │
    ──┼──────┤
    1 │ FIRE │
    =#

Parameters can also be set as part of the query.

    run(ChicagoData,
        Given(:no => 1,
          DeptNameWith(It.no)))
    #=>
      │ name │
    ──┼──────┤
    1 │ FIRE │
    =#

In both of these variants, the parameter `It.no` is accessible
anywhere in the query, at root of the data structure, within each
`department`, and within each `employee`.

### Nested Aggregates

Aggregates can be nested. In this case we calculate the maximum
employee count to which a department might have.

    MaximalEmployees = Max(It.department >> EmployeeCount)

    run(ChicagoData, MaximalEmployees)
    #=>
    │ DataKnot │
    ├──────────┤
    │        2 │
    =#

### Scoping Rules

It's important to realize that this pipeline is only valid at
the top of the tree, where `Lookup(:department)` can succeed.
Conversely, if this same pipeline is used in the context of a
department, it will fail.

    run(ChicagoData, It.department >> MaximalEmployees)
    #-> ERROR: cannot find department ⋮

It's for the same reason that `DeptNameWith(MaximalEmployees)`
will also fail. However this scoping problem can be overcome
by using parameters.

    run(ChicagoData,
        Given(:no => MaximalEmployees,
              DeptNameWith(It.no)))
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    =#

This scope challenge can be solved be rewriting `DeptNameWith` to
use a `Given` parameter.

    ImprovedWith(N) =
      Given(:no => N,
        It.department
        >> HavingSize(It.no)
        >> It.name)

    run(ChicagoData, ImprovedWith(MaximalEmployees))
    #=>
      │ name   │
    ──┼────────┤
    1 │ POLICE │
    =#

