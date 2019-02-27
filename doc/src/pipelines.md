# Pipeline Algebra


## Overview

In this section, we describe the design and implementation of the pipeline
algebra.  We will need the following definitions.

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
        x1to1

As a running example, we will use the following dataset of city departments
with associated employees.  This dataset is serialized as a nested structure
with a singleton root record, which holds all department records, each of which
holds associated employee records.

    elts =
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

    db = DataKnot(elts, x1to1)
    #=>
    │ department                                                                   …
    ┼──────────────────────────────────────────────────────────────────────────────…
    │ POLICE, JEFFERY A, SERGEANT, 101442, ; NANCY A, POLICE OFFICER, 80016, ; FIRE…
    =#


### Assembling pipelines

In DataKnots, we query data by assembling and running query *pipelines*.
Pipeline are assembled algebraically: they either come a set of atomic
*primitive* pipelines, or are built from other pipelines using pipeline
*combinators*.

For example, consider the pipeline:

    Employees = Get(:department) >> Get(:employee)
    #-> Get(:department) >> Get(:employee)

This pipeline traverses the dataset through fields *department* and *employee*.
It is assembled from two primitive pipelines `Get(:department)` and
`Get(:employee)` connected using the pipeline composition combinator `>>`.

Since attribute traversal is very common, DataKnots provides a shorthand notation.

    Employees = It.department.employee
    #-> It.department.employee

To get the data from a pipeline, we use function `run()`.  This function takes
the input dataset and a pipeline object, and produces the output dataset.

    run(db, Employees)
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

Regular Julia values and functions could be used to create pipeline components.
Specifically, any Julia value could be converted to a pipeline primitive, and
any Julia function could be converted to a pipeline combinator.

For example, let us find find employees whose salary is greater than \$100k.
For this purpose, we need to construct a predicate pipeline that compares the
*salary* field with a specific number.

If we were constructing an ordinary predicate function, we would write:

    emp -> emp.salary > 100000

An equivalent pipeline is constructed as follows:

    SalaryOver100K = Lift(>, (Get(:salary), Lift(100000)))
    #-> Lift(>, (Get(:salary), Lift(100000)))

This pipeline expression is assembled from two primitive components:
`Get(:salary)` and `Lift(100000)`, which serve as parameters of the
`Lift(>)` combinator.  Here, `Lift` is used twice.  `Lift` applied to a regular
Julia value converts it to a *constant* pipeline primitive while `Lift` applied
to a function *lifts* it to a pipeline combinator.

As a shorthand notation for lifting functions and operators, DataKnots supports
broadcasting syntax:

    SalaryOver100K = It.salary .> 100000
    #-> It.salary .> 100000

To test this pipeline, we can append it to the `Employees` pipeline using the
composition combinator.

    run(db, Employees >> SalaryOver100K)
    #=>
      │ It    │
    ──┼───────┼
    1 │  true │
    2 │ false │
    3 │  true │
    4 │ false │
    =#

However, this only gives us a list of bare Boolean values disconnected from the
respective employees.  To improve this output, we can use the `Record`
combinator.

    run(db, Employees >> Record(It.name,
                                It.salary,
                                :salary_over_100k => SalaryOver100K))
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

To actually filter the data using this predicate pipeline, we need to use the
`Filter` combinator.

    EmployeesWithSalaryOver100K = Employees >> Filter(SalaryOver100K)
    #-> It.department.employee >> Filter(It.salary .> 100000)

    run(db, EmployeesWithSalaryOver100K)
    #=>
      │ employee                                   │
      │ name       position           salary  rate │
    ──┼────────────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT           101442       │
    2 │ JAMES A    FIRE ENGINEER-EMT  103350       │
    =#

DataKnots provides a number of useful pipeline constructors.  For example, to
find the number of items produced by a pipeline, we can use the `Count`
combinator.

    run(db, Count(EmployeesWithSalaryOver100K))
    #=>
    │ It │
    ┼────┼
    │  2 │
    =#

In general, pipeline algebra forms an XPath-like domain-specific language.  It
is designed to let the user construct pipelines incrementally, with each step
being individually crafted and tested.  It also encourages the user to create
reusable pipeline components and remix them in creative ways.


### Principal queries

In DataKnots, running a pipeline is a two-phase process.  First, the pipeline
generates its *principal* query.  Second, the principal query transforms the
input data to the output data.

Let us elaborate on the role of queries and pipelines.  In DataKnots, queries
are used to transform data, and pipelines are used to transform monadic
queries.  That is, just as a query can be applied to some dataset to produce a
new dataset, a pipeline can be applied to a monadic query to produce a new
monadic query.

Among all queries produced by a pipeline, we distinguish its principal query,
which is obtained when the pipeline is applied to a *trivial* monadic query.

To demonstrate how the principal query is constructed, let us use the pipeline
`EmployeesWithSalaryOver100K` from the previous section.  Recall that it could
be represented as follows:

    Get(:department) >> Get(:employee) >> Filter(Get(:salary) .> 100000)
    #-> Get(:department) >> Get(:employee) >> Filter(Get(:salary) .> 100000)

The pipeline `P` is constructed using a composition combinator.  A composition
transforms a query by sequentially applying its components.  Therefore, to find
the principal query of `P`, we need to start with a trivial query and
sequentially tranfrorm it with the pipelines `Get(:department)`,
`Get(:employee)` and `Filter(SalaryOver100K)`.

The trivial query is a monadic identity on the input dataset.

    q0 = stub(db)
    #-> wrap()

To compile a pipeline to a query, we need to create application *environment*.
Then we use the function `compile()`.

    env = Environment()

    q1 = compile(Get(:department), env, q0)
    #-> chain_of(wrap(), with_elements(column(:department)), flatten())

Here, the query `q1` is a monadic composition of `q0` with
`column(:department)`.  Since `q0` is a monadic identity, this query is
actually equivalent to `column(:department)`.

In general, `Get(name)` maps a query to its monadic composition with
`column(name)`.  For example, when we compile `Get(:employee)` to `q1`, we get
`compose(q1, column(:employee))`.

    q2 = compile(Get(:employee), env, q1)
    #=>
    chain_of(chain_of(wrap(), with_elements(column(:department)), flatten()),
             with_elements(column(:employee)),
             flatten())
    =#

We conclude assembling the principal query by applying
`Filter(SalaryOver100K)` to `q2`.  `Filter` acts on the input query as follows.
First, it finds the principal query of the condition pipeline.  For that, we
need a trivial monadic query on the output of `q2`.

    qc0 = stub(q2)
    #-> wrap()

Passing `qc0` through `SalaryOver100K` gives us a query that generates
the result of the condition.

    qc1 = compile(SalaryOver100K, env, qc0)
    #=>
    chain_of(wrap(),
             with_elements(
                 chain_of(tuple_of(chain_of(wrap(),
                                            with_elements(column(:salary)),
                                            flatten()),
                                   chain_of(wrap(),
                                            with_elements(block_filler([100000],
                                                                       x1to1)),
                                            flatten())),
                          tuple_lift(>),
                          adapt_missing())),
             flatten())
    =#

`Filter(SalaryOver100K)` then combines the outputs of `q2` and `qc1` using
`sieve()`.

    q3 = compile(Filter(SalaryOver100K), env, q2)
    #=>
    chain_of(
        chain_of(chain_of(wrap(), with_elements(column(:department)), flatten()),
                 with_elements(column(:employee)),
                 flatten()),
        with_elements(
            chain_of(tuple_of(pass(),
                              chain_of(chain_of(
                                           wrap(),
                                           with_elements(
                                               chain_of(
                                                   tuple_of(
                                                       chain_of(wrap(),
                                                                with_elements(
                                                                    column(
                                                                        :salary)),
                                                                flatten()),
                                                       chain_of(wrap(),
                                                                with_elements(
                                                                    block_filler(
                                                                        [100000],
                                                                        x1to1)),
                                                                flatten())),
                                                   tuple_lift(>),
                                                   adapt_missing())),
                                           flatten()),
                                       block_any())),
                     sieve())),
        flatten())
    =#

The resulting query could be compacted by simplifying the query expression.

    q = optimize(q3)
    #=>
    chain_of(column(:department),
             with_elements(column(:employee)),
             flatten(),
             with_elements(chain_of(tuple_of(pass(),
                                             chain_of(tuple_of(column(:salary),
                                                               block_filler(
                                                                   [100000],
                                                                   x1to1)),
                                                      tuple_lift(>),
                                                      adapt_missing(),
                                                      block_any())),
                                    sieve())),
             flatten())
    =#

Applying the principal query to the input data gives us the output of the
pipeline.

    input = elements(db)
    output = q(input)

    display(elements(output))
    #=>
    @VectorTree of 2 × (name = (1:1) × String,
                        position = (1:1) × String,
                        salary = (0:1) × Int,
                        rate = (0:1) × Float64):
     (name = "JEFFERY A", position = "SERGEANT", salary = 101442, rate = missing)
     (name = "JAMES A", position = "FIRE ENGINEER-EMT", salary = 103350, rate = missing)
    =#



## API Reference
```@autodocs
Modules = [DataKnots]
Pages = ["pipelines.jl"]
```


## Test Suite






