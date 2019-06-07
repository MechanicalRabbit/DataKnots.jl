# Exploring Chicago Data

This is an overview of DataKnots to provide a taste of the
functionality it has. This overview is not an exhaustive account
of features, just the ones you are likely to use right away.

We use a tiny selection of public data from the City of Chicago.
This dataset includes employees and their annual salary. Let's
skip past [data preparation](#Data-Preparation-1") and use a
script that builds a DataKnot, or *knot*, called `chicago`.

    include("overview.jl")

## Data Navigation

To display the structure of this `chicago` knot we use
`show(as=:shape, ::DataKnot)`. We find it's a hierarchy with
`department` and `employee` records.

    show(as=:shape, chicago)
    #=>
    1-element DataKnot:
      #               1:1
      └╴department    0:N
        ├╴name        1:1 × String
        └╴employee    1:N
          ├╴name      String
          ├╴position  String
          └╴salary    Int64
    =#

Let's say we want to return the list of department names. We query
the `chicago` knot with `department.name`.

    @query chicago department.name
    #=>
      │ name   │
    ──┼────────┼
    1 │ FIRE   │
    2 │ POLICE │
    =#

The dotted notation lets one navigate a hierarchical dataset.
Let's continue our dataset exploration by listing employee names.

    @query chicago department.employee.name
    #=>
      │ name      │
    ──┼───────────┼
    1 │ DANIEL A  │
    2 │ ROBERT K  │
    3 │ ANTHONY A │
    4 │ JEFFERY A │
    5 │ NANCY A   │
    =#

We could write the query above, without the period delimiter, as a
multi-line macro block.

    @query chicago begin
        department
        employee
        name
    end

Navigation context matters. For example, `employee` records are
not directly accessible from the root of the knot. When a field
label, such as `employee`, can't be found, an appropriate error
message is displayed.

    @query chicago employee
    #-> ERROR: cannot find "employee" ⋮

Instead, `employee` records can be queried by navigating through
`department` records. When records are returned, they are
displayed as a table.

    @query chicago department.employee
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
    1 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    2 │ ROBERT K   FIRE FIGHTER-EMT  103272 │
    3 │ ANTHONY A  POLICE OFFICER     72510 │
    4 │ JEFFERY A  SERGEANT          101442 │
    5 │ NANCY A    POLICE OFFICER     80016 │
    =#

The output knot from a query can also be shown as a hierarchy of
labeled data elements. Here we see each of the two departments,
and for each department the correlated employees.

```
    show(as=:flow, @chicago department)
    #=>
    2-element DataKnot:
      department:
        name: FIRE
        employee:
          name: DANIEL A
          position: FIRE FIGHTER-EMT
          salary: 95484
        employee:
          name: ROBERT K
          position: FIRE FIGHTER-EMT
          salary: 103272
      department:
        name: POLICE
        employee:
          name: ANTHONY A
          position: POLICE OFFICER
          salary: 72510
        employee:
          name: JEFFERY A
          position: SERGEANT
          salary: 101442
        ⋮
    =#
```

When knots like this are shown as a table, the nested collections
are packed into a single cell: `employee` records are delimited by
a semi-colon and fields for employee are separated by the comma. 

    @query chicago department
    #=>
      │ department                                                   │
      │ name    employee{name,position,salary}                       │
    ──┼──────────────────────────────────────────────────────────────┼
    1 │ FIRE    DANIEL A, FIRE FIGHTER-EMT, 95484; ROBERT K, FIRE FI…│
    2 │ POLICE  ANTHONY A, POLICE OFFICER, 72510; JEFFERY A, SERGEAN…│
    =#

## Counting & Contexts

To count the number of departments in this `chicago` dataset we
write the query `count(department)`. Observe that the argument
provided to `count()`, `department`, is itself a query.

    @query chicago count(department)
    #=>
    ┼───┼
    │ 2 │
    =#

We could also count the total number of employees across all
departments.

    @query chicago count(department.employee)
    #=>
    ┼───┼
    │ 5 │
    =#

What if we wanted to count employees by department? Using query
composition (`.`), we can perform `count` in a nested context.

    @query chicago department.count(employee)
    #=>
    ──┼───┼
    1 │ 3 │
    2 │ 2 │
    =#

In this output, we see that one department has `3` employees,
while the other has `2`.

## Record Construction

Let's improve the previous query by including each department's
name alongside employee counts. This can be done by constructing a
record using paired curly brackets `{}`.

    @query chicago department{name, count(employee)}
    #=>
      │ department │
      │ name    #B │
    ──┼────────────┼
    1 │ POLICE   3 │
    2 │ FIRE     2 │
    =#

To label a record field we use the `Pair` syntax, (`=>`).

    @query chicago department{name, size => count(employee)}
    #=>
      │ department   │
      │ name    size │
    ──┼──────────────┼
    1 │ POLICE     3 │
    2 │ FIRE       2 │
    =#

Rather than building a record from scratch, one could add a field
to an existing record using `collect`.

    @query chicago department.collect(size=>count(employee))
    #=>
      │ department                                                   │
      │ name    employee{name,position,salary}                  size │
    ──┼──────────────────────────────────────────────────────────────┼
    1 │ FIRE    DANIEL A, FIRE FIGHTER-EMT, 95484; ROBERT K, F…    2 │
    2 │ POLICE  ANTHONY A, POLICE OFFICER, 72510; JEFFERY A, S…    3 │
    =#

If a label is set to `nothing` then that field is excluded. This
would let us restructure a record as we see fit.

    @query chicago begin
        department
        collect(size=>count(employee))
        collect(employee=>nothing)
    end
    #=>
      │ department   │
      │ name    size │
    ──┼──────────────┼
    1 │ POLICE     3 │
    2 │ FIRE       2 │
    =#

## Data Preparation

How this data was prepared is out of the scope of this overview.
Even so, the content of [overview.jl](overview.jl) is shown below.

````@eval
using Markdown
Markdown.parse("""
```julia
$(read(open("overview.jl"),String))
```
""")
````
