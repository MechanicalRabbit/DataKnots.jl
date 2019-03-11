# Query Algebra


## Overview

In this section, we sketch the design and implementation of the query algebra.
We will need the following definitions.

    using DataKnots:
        @VectorTree,
        Count,
        DataKnot,
        Drop,
        Environment,
        Filter,
        Get,
        Given,
        It,
        Lift,
        Max,
        Min,
        Record,
        Take,
        compile,
        elements,
        optimize,
        stub,
        uncover,
        x1to1

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

    chicago = DataKnot(chicago_data, x1to1)
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


