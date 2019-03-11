# Query Algebra


## Overview

In this section, we sketch the design and implementation of the query algebra.
We will need the following definitions.

    using DataKnots:
        @VectorTree,
        Count,
        DataKnot,
        Drop,
        Each,
        Environment,
        Filter,
        Get,
        Given,
        It,
        Label,
        Lift,
        Max,
        Min,
        Record,
        Tag,
        Take,
        compile,
        elements,
        optimize,
        stub,
        uncover

As a running example, we will use the following dataset of city departments
with associated employees.  This dataset is serialized as a nested structure
with a singleton root record, which holds all department records, each of which
holds associated employee records.

    chicago_data =
        @VectorTree (department = [(name     = (1:1)String,
                                    employee = [(name     = (1:1)String,
                                                 position = (1:1)String,
                                                 salary   = (0:1)Int,
                                                 rate     = (0:1)Float64)])],) [
            (department = [
                (name     = "POLICE",
                 employee = ["JEFFERY A"  "SERGEANT"           101442   missing
                             "NANCY A"    "POLICE OFFICER"     80016    missing]),
                (name     = "FIRE",
                 employee = ["JAMES A"    "FIRE ENGINEER-EMT"  103350   missing
                             "DANIEL A"   "FIRE FIGHTER-EMT"   95484    missing]),
                (name     = "OEMC",
                 employee = ["LAKENYA A"  "CROSSING GUARD"     missing  17.68
                             "DORIS A"    "CROSSING GUARD"     missing  19.38])],
            )
        ]

    chicago = DataKnot(chicago_data, :x1to1)
    #=>
    │ department                                                                   …
    ┼──────────────────────────────────────────────────────────────────────────────…
    │ POLICE, [JEFFERY A, SERGEANT, 101442, missing; NANCY A, POLICE OFFICER, 80016…
    =#


### Assembling queries

In DataKnots, we query data by assembling and running `Query` objects.  Queries
are assembled algebraically: they either come a set of atomic *primitive*
queries, or are built from other queries using query *combinators*.

For example, consider the query:

    Employees = Get(:department) >> Get(:employee)
    #-> Get(:department) >> Get(:employee)

This query traverses the dataset through fields *department* and *employee*.
It is assembled from two primitive queries `Get(:department)` and
`Get(:employee)` connected using the query composition combinator `>>`.

Since attribute traversal is so common, DataKnots provides a shorthand notation.

    Employees = It.department.employee
    #-> It.department.employee

To apply a query to a `DataKnot`, we use indexing notation.  The output of a
query is also a `DataKnot`.

    chicago[Employees]
    #=>
      │ employee                                    │
      │ name       position           salary  rate  │
    ──┼─────────────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT           101442        │
    2 │ NANCY A    POLICE OFFICER      80016        │
    3 │ JAMES A    FIRE ENGINEER-EMT  103350        │
    4 │ DANIEL A   FIRE FIGHTER-EMT    95484        │
    5 │ LAKENYA A  CROSSING GUARD             17.68 │
    6 │ DORIS A    CROSSING GUARD             19.38 │
    =#

Regular Julia values and functions could be used to create query components.
Specifically, any Julia value could be converted to a query primitive, and
any Julia function could be converted to a query combinator.

For example, let us find find employees whose salary is greater than \$100k.
For this purpose, we need to construct a predicate query that compares the
*salary* field with a specific number.

If we were constructing an ordinary predicate function, we would write:

    salary_over_100k(emp) = emp.salary > 100000

An equivalent query is constructed as follows:

    SalaryOver100K = Lift(>, (Get(:salary), Lift(100000)))
    #-> Lift(>, (Get(:salary), Lift(100000)))

This query expression is assembled from two primitive components:
`Get(:salary)` and `Lift(100000)`, which serve as parameters of the `Lift(>)`
combinator.  Here, `Lift` is used twice.  `Lift` applied to a regular Julia
value converts it to a *constant* query primitive while `Lift` applied to a
function *lifts* it to a query combinator.

As a shorthand notation for lifting functions and operators, DataKnots supports
broadcasting syntax:

    SalaryOver100K = It.salary .> 100000
    #-> It.salary .> 100000

To test this query, we can append it to the `Employees` query using the
composition combinator.

    chicago[Employees >> SalaryOver100K]
    #=>
      │ It    │
    ──┼───────┼
    1 │  true │
    2 │ false │
    3 │  true │
    4 │ false │
    =#

However, this only gives us a list of bare Boolean values disconnected from the
respective employees.  To contextualize this output, we can use the `Record`
combinator.

    chicago[Employees >> Record(It.name,
                                It.salary,
                                :salary_over_100k => SalaryOver100K)]
    #=>
      │ employee                            │
      │ name       salary  salary_over_100k │
    ──┼─────────────────────────────────────┼
    1 │ JEFFERY A  101442              true │
    2 │ NANCY A     80016             false │
    3 │ JAMES A    103350              true │
    4 │ DANIEL A    95484             false │
    5 │ LAKENYA A                           │
    6 │ DORIS A                             │
    =#

To actually filter the data using this predicate query, we need to use the
`Filter` combinator.

    EmployeesWithSalaryOver100K = Employees >> Filter(SalaryOver100K)
    #-> It.department.employee >> Filter(It.salary .> 100000)

    chicago[EmployeesWithSalaryOver100K]
    #=>
      │ employee                                   │
      │ name       position           salary  rate │
    ──┼────────────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT           101442       │
    2 │ JAMES A    FIRE ENGINEER-EMT  103350       │
    =#

DataKnots provides a number of useful query constructors.  For example, to find
the number of items produced by a query, we can use the `Count` combinator.

    chicago[Count(EmployeesWithSalaryOver100K)]
    #=>
    │ It │
    ┼────┼
    │  2 │
    =#

In general, query algebra forms an XPath-like domain-specific language.  It is
designed to let the user construct queries incrementally, with each step being
individually crafted and tested.  It also encourages the user to create
reusable query components and remix them in creative ways.


### Compiling queries

In DataKnots, applying a query to the input data is a two-phase process.
First, the query is compiled to a pipeline.  Second, this pipeline transforms
the input data to the output data.

Let us elaborate on the role of pipelines and queries.  In DataKnots, just like
pipelines are used to transform data, a query can transform pipelines.  That
is, a query can be applied to a pipeline to produce a new pipeline.

To run a query on the given data, we apply the query to a *trivial* pipeline.
The generated pipeline is used to actually transform the data.

To demonstrate how to compile a query, let us use `EmployeesWithSalaryOver100K`
from the previous section.  Recall that it could be represented as follows:

    Get(:department) >> Get(:employee) >> Filter(Get(:salary) .> 100000)
    #-> Get(:department) >> Get(:employee) >> Filter(Get(:salary) .> 100000)

This query is constructed using a composition combinator.  A query composition
transforms a pipeline by sequentially applying the component queries.
Therefore, to find the pipeline of `EmployeesWithSalaryOver100K`, we need to
start with a trivial pipeline and sequentially tranfrorm it with the queries
`Get(:department)`, `Get(:employee)` and `Filter(SalaryOver100K)`.

The trivial pipeline can be obtained from the input data.

    p0 = stub(chicago)
    #-> pass()

We use the function `compile()` to apply a query to a pipeline.  To run
`compile()` we need to create the *environment* object.

    env = Environment()

    p1 = compile(Get(:department), env, p0)
    #-> chain_of(with_elements(column(:department)), flatten())

The pipeline `p1` fetches the attribute *department* from the input data.  In
general, `Get(name)` maps a pipeline to its monadic composition with
`column(name)`.  For example, when we apply `Get(:employee)` to `p1`, what we
get is the result of `compose(p1, column(:employee))`.

    p2 = compile(Get(:employee), env, p1)
    #=>
    chain_of(chain_of(with_elements(column(:department)), flatten()),
             chain_of(with_elements(column(:employee)), flatten()))
    =#

To finish assembling the pipeline, we apply `Filter(SalaryOver100K)` to `p2`.
`Filter` acts on the input pipeline as follows.  First, it compiles the
predicate query using the trivial pipeline on the output of `p2`.

    pc0 = stub(p2)
    #-> wrap()

    pc1 = compile(SalaryOver100K, env, pc0)
    #=>
    chain_of(wrap(),
             chain_of(
                 with_elements(
                     chain_of(
                         chain_of(
                             ⋮
                             tuple_lift(>)),
                         adapt_missing())),
                 flatten()))
    =#

`Filter(SalaryOver100K)` then combines the pipelines `p2` and `pc1` using the
pipeline primitive `sieve()`.

    p3 = compile(Filter(SalaryOver100K), env, p2)
    #=>
    chain_of(
        chain_of(chain_of(with_elements(column(:department)), flatten()),
                 chain_of(with_elements(column(:employee)), flatten())),
        chain_of(
            with_elements(
                chain_of(
                    ⋮
                    sieve())),
            flatten()))
    =#

The resulting pipeline could be compacted by simplifying the pipeline
expression.

    p = optimize(uncover(p3))
    #=>
    chain_of(with_elements(chain_of(column(:department),
                                    with_elements(column(:employee)))),
             flatten(),
             flatten(),
             with_elements(chain_of(tuple_of(pass(),
                                             chain_of(tuple_of(column(:salary),
                                                               chain_of(
                                                                   filler(100000),
                                                                   wrap())),
                                                      tuple_lift(>),
                                                      adapt_missing(),
                                                      block_any())),
                                    sieve())),
             flatten())
    =#

Applying this pipeline to the input data gives us the output of the query.

    p(chicago)
    #=>
      │ employee                                   │
      │ name       position           salary  rate │
    ──┼────────────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT           101442       │
    2 │ JAMES A    FIRE ENGINEER-EMT  103350       │
    =#


## API Reference
```@autodocs
Modules = [DataKnots]
Pages = ["queries.jl"]
```


## Test Suite


### Querying

A `Query` is applied to a `DataKnot` using the array indexing syntax.

    Q = Count(It.department)

    chicago[Q]
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#

Any parameters to the query should be be passed as keyword arguments.

    Q = It.department >>
        Filter(Count(It.employee >> Filter(It.salary .> It.AMT)) .>= It.SZ) >>
        Count

    chicago[Q, AMT=100000, SZ=1]
    #=>
    │ It │
    ┼────┼
    │  2 │
    =#

We can use the function `compile()` to see the query plan.

    p = compile(chicago, Count(It.department))
    #=>
    chain_of(with_elements(chain_of(column(:department), block_length(), wrap())),
             flatten())
    =#

    p(chicago)
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#


### Composition

Queries can be composed sequentially using the `>>` combinator.

    Q = Lift(3) >> (It .+ 4) >> (It .* 6)
    #-> Lift(3) >> (It .+ 4) >> It .* 6

    chicago[Q]
    #=>
    │ It │
    ┼────┼
    │ 42 │
    =#

The `It` query primitive is the identity with respect to `>>`.

    Q = It >> Q >> It
    #-> It >> Lift(3) >> (It .+ 4) >> It .* 6 >> It

    chicago[Q]
    #=>
    │ It │
    ┼────┼
    │ 42 │
    =#


### `Record`

The query `Record(X₁, X₂ … Xₙ)` emits records with the fields generated by
`X₁`, `X₂` … `Xₙ`.

    Q = It.department >>
        Record(It.name,
               :size => Count(It.employee))
    #-> It.department >> Record(It.name, :size => Count(It.employee))

    chicago[Q]
    #=>
      │ department   │
      │ name    size │
    ──┼──────────────┼
    1 │ POLICE     2 │
    2 │ FIRE       2 │
    3 │ OEMC       2 │
    =#

If a field has no label, an ordinal label (`#A`, `#B` … `#AA`, `#AB` …)
is assigned.

    Q = It.department >> Record(It.name, Count(It.employee))
    #-> It.department >> Record(It.name, Count(It.employee))

    chicago[Q]
    #=>
      │ department │
      │ name    #B │
    ──┼────────────┼
    1 │ POLICE   2 │
    2 │ FIRE     2 │
    3 │ OEMC     2 │
    =#

Similarly, when there are duplicate labels, only the last one survives.

    Q = It.department >> Record(It.name, It.employee.name)
    #-> It.department >> Record(It.name, It.employee.name)

    chicago[Q]
    #=>
      │ department                 │
      │ #A      name               │
    ──┼────────────────────────────┼
    1 │ POLICE  JEFFERY A; NANCY A │
    2 │ FIRE    JAMES A; DANIEL A  │
    3 │ OEMC    LAKENYA A; DORIS A │
    =#


### `Lift`

The `Lift` constructor is used to convert Julia values and functions to
queries.

`Lift(val)` makes a query primitive from a Julia value.

    Q = Lift("Hello World!")
    #-> Lift("Hello World!")

    chicago[Q]
    #=>
    │ It           │
    ┼──────────────┼
    │ Hello World! │
    =#

Lifting `missing` produces no output.

    Q = Lift(missing)
    #-> Lift(missing)

    chicago[Q]
    #=>
    │ It │
    ┼────┼
    =#

Lifting a vector produces plural output.

    Q = Lift('a':'c')
    #-> Lift('a':1:'c')

    chicago[Q]
    #=>
      │ It │
    ──┼────┼
    1 │ a  │
    2 │ b  │
    3 │ c  │
    =#

`Lift` can also convert Julia functions to query combinators.

    Inc(X) = Lift(x -> x+1, (X,))

    Q = Lift(0) >> Inc(It)
    #-> Lift(0) >> Lift(x -> x + 1, (It,))

    chicago[Q]
    #=>
    │ It │
    ┼────┼
    │  1 │
    =#

Functions of multiple arguments are also supported.

    GT(X, Y) = Lift(>, (X, Y))

    Q = It.department.employee >>
        Record(It.name, It.salary, GT(It.salary, 100000))
    #=>
    It.department.employee >>
    Record(It.name, It.salary, Lift(>, (It.salary, 100000)))
    =#

    chicago[Q]
    #=>
      │ employee                 │
      │ name       salary  #C    │
    ──┼──────────────────────────┼
    1 │ JEFFERY A  101442   true │
    2 │ NANCY A     80016  false │
    3 │ JAMES A    103350   true │
    4 │ DANIEL A    95484  false │
    5 │ LAKENYA A                │
    6 │ DORIS A                  │
    =#

Just as functions with no arguments.

    using Random: seed!

    seed!(0)

    Q = Lift(rand, ())
    #-> Lift(rand, ())

    chicago[Q]
    #=>
    │ It       │
    ┼──────────┼
    │ 0.823648 │
    =#

Functions with vector arguments are supported.

    using Statistics: mean

    Mean(X) = Lift(mean, (X,))

    Q = Mean(It.department.employee.salary)
    #-> Lift(mean, (It.department.employee.salary,))

    chicago[Q]
    #=>
    │ It      │
    ┼─────────┼
    │ 95073.0 │
    =#

Just like with regular values, `missing` and vector results are interpreted as
no and plural output.

    Q = Inc(missing)
    #-> Lift(x -> x + 1, (missing,))

    chicago[Q]
    #=>
    │ It │
    ┼────┼
    =#

    OneTo(N) = Lift(UnitRange, (1, N))

    Q = OneTo(3)
    #-> Lift(UnitRange, (1, 3))

    chicago[Q]
    #=>
      │ It │
    ──┼────┼
    1 │  1 │
    2 │  2 │
    3 │  3 │
    =#

Julia functions are lifted when they are broadcasted over queries.

    Q = mean.(It.department.employee.salary)
    #-> mean.(It.department.employee.salary)

    chicago[Q]
    #=>
    │ It      │
    ┼─────────┼
    │ 95073.0 │
    =#


### `Each`

`Each` serves as a barrier for aggregate queries.

    Q = It.department >> (It.employee >> Count)
    #-> It.department >> It.employee >> Count

    chicago[Q]
    #=>
    │ It │
    ┼────┼
    │  6 │
    =#

    Q = It.department >> Each(It.employee >> Count)
    #-> It.department >> Each(It.employee >> Count)

    chicago[Q]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  2 │
    3 │  2 │
    =#

Note that `Record` and `Lift` also serve as natural barriers for aggregate
queries.

    Q = It.department >>
        Record(It.name, It.employee >> Count)
    #-> It.department >> Record(It.name, It.employee >> Count)

    chicago[Q]
    #=>
      │ department │
      │ name    #B │
    ──┼────────────┼
    1 │ POLICE   2 │
    2 │ FIRE     2 │
    3 │ OEMC     2 │
    =#

    Q = It.department >>
        (1 .* (It.employee >> Count))
    #-> It.department >> 1 .* (It.employee >> Count)

    chicago[Q]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  2 │
    3 │  2 │
    =#


### `Label`

We use the `Label()` primitive to assign a label to the output.

    Q = Count(It.department) >> Label(:num_dept)
    #-> Count(It.department) >> Label(:num_dept)

    chicago[Q]
    #=>
    │ num_dept │
    ┼──────────┼
    │        3 │
    =#

As a shorthand, we can use `=>`.

    Q = :num_dept => Count(It.department)
    #-> :num_dept => Count(It.department)

    chicago[Q]
    #=>
    │ num_dept │
    ┼──────────┼
    │        3 │
    =#


### `Tag`

We use `Tag()` constructor to assign a name to a query.

    DeptSize = Count(It.employee) >> Label(:dept_size)
    #-> Count(It.employee) >> Label(:dept_size)

    DeptSize = Tag(:DeptSize, DeptSize)
    #-> DeptSize

    Q = It.department >> Record(It.name, DeptSize)
    #-> It.department >> Record(It.name, DeptSize)

    chicago[Q]
    #=>
      │ department        │
      │ name    dept_size │
    ──┼───────────────────┼
    1 │ POLICE          2 │
    2 │ FIRE            2 │
    3 │ OEMC            2 │
    =#

`Tag()` is also used to assign a name to a query combinator.

    SalaryOver(X) = It.salary .> X

    SalaryOver(100000)
    #-> It.salary .> 100000

    SalaryOver(X) = Tag(SalaryOver, (X,), It.salary .> X)

    SalaryOver(100000)
    #-> SalaryOver(100000)

    Q = It.department.employee >>
        Filter(SalaryOver(100000))
    #-> It.department.employee >> Filter(SalaryOver(100000))

    chicago[Q]
    #=>
      │ employee                                   │
      │ name       position           salary  rate │
    ──┼────────────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT           101442       │
    2 │ JAMES A    FIRE ENGINEER-EMT  103350       │
    =#

