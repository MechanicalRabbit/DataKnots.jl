# Pipeline Algebra


## Overview

In this section, we describe the usage and semantics of query pipelines.  We
will need the following definitions.

    using DataKnots:
        @VectorTree,
        OPT,
        REG,
        Count,
        DataKnot,
        Drop,
        Environment,
        Filter,
        Given,
        It,
        Lift,
        Lookup,
        Max,
        Min,
        Record,
        Take,
        apply,
        elements,
        optimize,
        stub


### Building and running pipelines

In DataKnots, we query data by assembling and running query *pipelines*.

For example, consider the following dataset of departments with associated
employees.  This dataset is serialized as a nested structure with a singleton
root record, which holds all department records, each of which holds associated
employee records.

    db = DataKnot(
        @VectorTree (department = [(name = [String, REG],
                                    employee = [(name = [String, REG],
                                                 position = [String, REG],
                                                 salary = [Int, OPT],
                                                 rate = [Float64, OPT])])],) [
            (department = [
                (name = "POLICE",
                 employee = [(name = "JEFFERY A", position = "SERGEANT", salary = 101442, rate = missing),
                             (name = "NANCY A", position = "POLICE OFFICER", salary = 80016, rate = missing)]),
                (name = "FIRE",
                 employee = [(name = "JAMES A", position = "FIRE ENGINEER-EMT", salary = 103350, rate = missing),
                             (name = "DANIEL A", position = "FIRE FIGHTER-EMT", salary = 95484, rate = missing)]),
                (name = "OEMC",
                 employee = [(name = "LAKENYA A", position = "CROSSING GUARD", salary = missing, rate = 17.68),
                             (name = "DORIS A", position = "CROSSING GUARD", salary = missing, rate = 19.38)])],)
        ]
    )
    #=>
    │ DataKnot                                                                     …
    │ department                                                                   …
    ├──────────────────────────────────────────────────────────────────────────────…
    │ POLICE, JEFFERY A, SERGEANT, 101442, ; NANCY A, POLICE OFFICER, 80016, ; FIRE…
    =#

To demonstrate how to query this dataset, let us find all employees with the
salary greater than \$100k.  We answer this question by constructing and
running an appropriate query pipeline.

This pipeline can be constructed incrementally.  We start with obtaining
the collection of all employees.

    P = Lookup(:department) >> Lookup(:employee)
    #-> Lookup(:department) >> Lookup(:employee)

The pipeline `P` traverses the dataset through attributes *department* and
*employee*.  It is assembled from two primitive pipelines `Lookup(:department)`
and `Lookup(:employee)` connected using the pipeline composition combinator
`>>`.

We *run* the pipeline to obtain the actual data.

    run(db, P)
    #=>
      │ employee                                    │
      │ name       position           salary  rate  │
    ──┼─────────────────────────────────────────────┤
    1 │ JEFFERY A  SERGEANT           101442        │
    2 │ NANCY A    POLICE OFFICER      80016        │
    3 │ JAMES A    FIRE ENGINEER-EMT  103350        │
    4 │ DANIEL A   FIRE FIGHTER-EMT    95484        │
    5 │ LAKENYA A  CROSSING GUARD             17.68 │
    6 │ DORIS A    CROSSING GUARD             19.38 │
    =#

Now we need to find the records that satisfy the condition that the salary is
greater than \$100k.  This condition is evaluated by the following pipeline
component.

    Condition = Lookup(:salary) .> 100000
    #-> Lookup(:salary) .> 100000

In this expression, broadcasting syntax is used to *lift* the predicate
function `>` to a pipeline combinator.

To show how this condition is evaluated, lets us display its result together
with the corresponding salary.  For this purpose, we can use the `Record`
combinator.

    run(db, P >> Record(Lookup(:salary), :condition => Condition))
    #=>
      │ employee          │
      │ salary  condition │
    ──┼───────────────────┤
    1 │ 101442       true │
    2 │  80016      false │
    3 │ 103350       true │
    4 │  95484      false │
    5 │                   │
    6 │                   │
    =#

To actually filter data by this condition, we can use the `Filter` combinator.
Specifically, we need to augment the pipeline `P` with a pipeline component
`Filter(Condition)`.

    P = P >> Filter(Condition)
    #-> Lookup(:department) >> Lookup(:employee) >> Filter(Lookup(:salary) .> 100000)

Running this pipeline gives us the answer to the original question.

    run(db, P)
    #=>
      │ employee                                   │
      │ name       position           salary  rate │
    ──┼────────────────────────────────────────────┤
    1 │ JEFFERY A  SERGEANT           101442       │
    2 │ JAMES A    FIRE ENGINEER-EMT  103350       │
    =#


### Principal queries

In DataKnots, running a pipeline is a two-stage process.  On the first stage,
the pipeline is used to build the *principal* query.  On the second stage, the
principal query is used to transform the input data to the output data.

In general, a pipeline is a transformation of monadic queries.  That is, we can
apply a pipeline to a monadic query and get a new monadic query as the result.
The principal query of a pipeline is obtained when we apply the pipeline to a
*trivial* monadic query.

To demonstrate how the principal query is constructed, let us use the pipeline
`P` from the previous section.

    P
    #-> Lookup(:department) >> Lookup(:employee) >> Filter(Lookup(:salary) .> 100000)

The pipeline `P` is constructed using a composition combinator.  A composition
transforms a query by sequentially applying its components.  Therefore, to find
the principal query of `P`, we need to start with a trivial query and
sequentially tranfrorm it with the pipelines `Lookup(:department)`,
`Lookup(:employee)` and `Filter(Condition)`.

The trivial query is a monadic identity on the input dataset.

    q0 = stub(db)
    #-> wrap()

To apply a pipeline to a query, we need to create application *environment*.
Then we use the function `apply()`.

    env = Environment()

    q1 = apply(Lookup(:department), env, q0)
    #-> chain_of(wrap(), with_elements(column(:department)), flatten())

Here, the query `q1` is a monadic composition of `q0` with
`column(:department)`.  Since `q0` is a monadic identity, this query is
actually equivalent to `column(:department)`.

In general, `Lookup(name)` maps a query to its monadic composition with
`column(name)`.  For example, when we apply `Lookup(:employee)` to `q1`, we get
`compose(q1, column(:employee))`.

    q2 = apply(Lookup(:employee), env, q1)
    #=>
    chain_of(chain_of(wrap(), with_elements(column(:department)), flatten()),
             with_elements(column(:employee)),
             flatten())
    =#

We conclude assembling the principal query of `P` by applying
`Filter(Condition)` to `q2`.  `Filter` acts on the input query as follows.
First, it finds the principal query of the condition pipeline.  For that,
we need a trivial monadic query on the output of `q2`.

    qc0 = stub(q2)
    #-> wrap()

Passing `qc0` through `Condition` gives us a query that generates
the result of the condition.

    qc1 = apply(Condition, env, qc0)
    #=>
    chain_of(wrap(),
             with_elements(chain_of(tuple_of(
                                        chain_of(wrap(),
                                                 with_elements(column(:salary)),
                                                 flatten()),
                                        chain_of(wrap(),
                                                 with_elements(
                                                     block_filler([100000], REG)),
                                                 flatten())),
                                    tuple_lift(>),
                                    adapt_missing())),
             flatten())
    =#

`Filter(Condition)` then combines the outputs of `q2` and `qc1` using
`sieve()`.

    q3 = apply(Filter(Condition), env, q2)
    #=>
    chain_of(
        chain_of(chain_of(wrap(), with_elements(column(:department)), flatten()),
                 with_elements(column(:employee)),
                 flatten()),
        with_elements(
            chain_of(
                tuple_of(
                    pass(),
                    chain_of(
                        chain_of(
                            wrap(),
                            with_elements(
                                chain_of(
                                    tuple_of(
                                        chain_of(wrap(),
                                                 with_elements(column(:salary)),
                                                 flatten()),
                                        chain_of(wrap(),
                                                 with_elements(
                                                     block_filler([100000], REG)),
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
             with_elements(
                 chain_of(tuple_of(pass(),
                                   chain_of(tuple_of(column(:salary),
                                                     block_filler([100000], REG)),
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
    TupleVector of 2 × (name = [String, REG], position = [String, REG], salary = [Int, OPT], rate = [Float64, OPT]):
     (name = "JEFFERY A", position = "SERGEANT", salary = 101442, rate = missing)
     (name = "JAMES A", position = "FIRE ENGINEER-EMT", salary = 103350, rate = missing)
    =#



## API Reference
```@autodocs
Modules = [DataKnots]
Pages = ["pipelines.jl"]
```


## Test Suite






