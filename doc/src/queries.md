# Query Algebra

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
        Group,
        It,
        Keep,
        Label,
        Lift,
        Max,
        Min,
        Record,
        Sum,
        Tag,
        Take,
        Unique,
        assemble,
        elements,
        optimize,
        trivial_pipe,
        target_pipe,
        uncover

## Example Dataset

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
                 employee = ["JEFFERY A"    "SERGEANT"              101442      missing
                             "NANCY A"      "POLICE OFFICER"        80016       missing
                             "ANTHONY A"    "POLICE OFFICER"        72510       missing
                             "ALBA M"       "POLICE CADET"          missing     9.46]),
                (name     = "FIRE",
                 employee = ["JAMES A"      "FIRE ENGINEER-EMT"     103350      missing
                             "DANIEL A"     "FIREFIGHTER-EMT"       95484       missing
                             "ROBERT K"     "FIREFIGHTER-EMT"       103272      missing]),
                (name     = "OEMC",
                 employee = ["LAKENYA A"    "CROSSING GUARD"        missing     17.68
                             "DORIS A"      "CROSSING GUARD"        missing     19.38
                             "BRENDA B"     "TRAFFIC CONTROL AIDE"  64392       missing])],
            )
        ]

    chicago = DataKnot(Any, chicago_data, :x1to1)
    #=>
    │ department                                                                   …
    ┼──────────────────────────────────────────────────────────────────────────────…
    │ POLICE, [JEFFERY A, SERGEANT, 101442, missing; NANCY A, POLICE OFFICER, 80016…
    =#

## Constructing Queries

In DataKnots, we query data by assembling and running `Query` objects.  Queries
are constructed algebraically: they either come a set of atomic *primitive*
queries, or are built from other queries using query *combinators*.

For example, consider the query:

    Employees = Get(:department) >> Get(:employee)
    #-> Get(:department) >> Get(:employee)

This query traverses the dataset through fields *department* and *employee*.
It is constructed from two primitive queries `Get(:department)` and
`Get(:employee)` connected using the query composition combinator `>>`.

Since attribute traversal is so common, DataKnots provides a shorthand notation.

    Employees = It.department.employee
    #-> It.department.employee

To apply a query to a `DataKnot`, we use indexing notation.  The output of a
query is also a `DataKnot`.

    chicago[Employees]
    #=>
       │ employee                                       │
       │ name       position              salary  rate  │
    ───┼────────────────────────────────────────────────┼
     1 │ JEFFERY A  SERGEANT              101442        │
     2 │ NANCY A    POLICE OFFICER         80016        │
     3 │ ANTHONY A  POLICE OFFICER         72510        │
     4 │ ALBA M     POLICE CADET                   9.46 │
     5 │ JAMES A    FIRE ENGINEER-EMT     103350        │
     6 │ DANIEL A   FIREFIGHTER-EMT        95484        │
     7 │ ROBERT K   FIREFIGHTER-EMT       103272        │
     8 │ LAKENYA A  CROSSING GUARD                17.68 │
     9 │ DORIS A    CROSSING GUARD                19.38 │
    10 │ BRENDA B   TRAFFIC CONTROL AIDE   64392        │
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

This query expression is constructed from two primitive components:
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
    3 │ false │
    4 │  true │
    5 │ false │
    6 │  true │
    7 │ false │
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
    ───┼─────────────────────────────────────┼
     1 │ JEFFERY A  101442              true │
     2 │ NANCY A     80016             false │
     3 │ ANTHONY A   72510             false │
     4 │ ALBA M                              │
     5 │ JAMES A    103350              true │
     6 │ DANIEL A    95484             false │
     7 │ ROBERT K   103272              true │
     8 │ LAKENYA A                           │
     9 │ DORIS A                             │
    10 │ BRENDA B    64392             false │
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
    3 │ ROBERT K   FIREFIGHTER-EMT    103272       │
    =#

DataKnots provides a number of useful query constructors.  For example, to find
the number of items produced by a query, we can use the `Count` combinator.

    chicago[Count(EmployeesWithSalaryOver100K)]
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#

In general, query algebra forms an XPath-like domain-specific language.  It is
designed to let the user construct queries incrementally, with each step being
individually crafted and tested.  It also encourages the user to create
reusable query components and remix them in creative ways.

## Compiling Queries

In DataKnots, applying a query to the input data is a two-phase process.
First, the query generates a pipeline.  Second, this pipeline transforms
the input data to the output data.

Let us elaborate on the role of pipelines and queries.  In DataKnots, just like
pipelines are used to transform data, a query can transform pipelines.  That
is, a query can be applied to a pipeline to produce a new pipeline.

To run a query on the given data, we apply the query to a *trivial* pipeline.
The generated pipeline is used to actually transform the data.

To demonstrate how to apply a query, let us use `EmployeesWithSalaryOver100K`
from the previous section.  Recall that it could be represented as follows:

    Get(:department) >> Get(:employee) >> Filter(Get(:salary) .> 100000)
    #-> Get(:department) >> Get(:employee) >> Filter(Get(:salary) .> 100000)

This query is constructed using a composition combinator.  A query composition
transforms a pipeline by sequentially applying the component queries.
Therefore, to find the pipeline of `EmployeesWithSalaryOver100K`, we need to
start with a trivial pipeline and sequentially tranfrorm it with the queries
`Get(:department)`, `Get(:employee)` and `Filter(SalaryOver100K)`.

The trivial pipeline can be obtained from the input data.

    p0 = trivial_pipe(chicago)
    #-> pass()

We use the function `assemble()` to apply a query to a pipeline.  To run
`assemble()` we need to create the *environment* object.

    env = Environment()

    p1 = assemble(Get(:department), env, p0)
    #-> chain_of(with_elements(column(:department)), flatten())

The pipeline `p1` fetches the attribute *department* from the input data.  In
general, `Get(name)` maps a pipeline to its elementwise composition with
`column(name)`.  For example, when we apply `Get(:employee)` to `p1`, what we
get is the result of `compose(p1, column(:employee))`.

    p2 = assemble(Get(:employee), env, p1)
    #=>
    chain_of(chain_of(with_elements(column(:department)), flatten()),
             chain_of(with_elements(column(:employee)), flatten()))
    =#

To finish assembling the pipeline, we apply `Filter(SalaryOver100K)` to `p2`.
`Filter` acts on the input pipeline as follows.  First, it assembles the
predicate pipeline by applying the predicate query to a trivial pipeline.

    pc0 = target_pipe(p2)
    #-> wrap()

    pc1 = assemble(SalaryOver100K, env, pc0)
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
pipeline primitive `sieve_by()`.

    p3 = assemble(Filter(SalaryOver100K), env, p2)
    #=>
    chain_of(
        chain_of(chain_of(with_elements(column(:department)), flatten()),
                 chain_of(with_elements(column(:employee)), flatten())),
        chain_of(
            with_elements(
                chain_of(
                    ⋮
                    sieve_by())),
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
                                    sieve_by())),
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
    3 │ ROBERT K   FIREFIGHTER-EMT    103272       │
    =#

## API Reference
```@autodocs
Modules = [DataKnots]
Pages = ["queries.jl"]
Public = false
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

We can use the function `assemble()` to see the query plan.

    p = assemble(chicago, Count(It.department))
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
    1 │ POLICE     4 │
    2 │ FIRE       3 │
    3 │ OEMC       3 │
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
    1 │ POLICE   4 │
    2 │ FIRE     3 │
    3 │ OEMC     3 │
    =#

Similarly, when there are duplicate labels, only the last one survives.

    Q = It.department >> Record(It.name, It.employee.name)
    #-> It.department >> Record(It.name, It.employee.name)

    chicago[Q]
    #=>
      │ department                                    │
      │ #A      name                                  │
    ──┼───────────────────────────────────────────────┼
    1 │ POLICE  JEFFERY A; NANCY A; ANTHONY A; ALBA M │
    2 │ FIRE    JAMES A; DANIEL A; ROBERT K           │
    3 │ OEMC    LAKENYA A; DORIS A; BRENDA B          │
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

When lifting a vector, we can specify the cardinality constraint.

    Q = Lift('a':'c', :x1toN)
    #-> Lift('a':1:'c', :x1toN)

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
    ───┼──────────────────────────┼
     1 │ JEFFERY A  101442   true │
     2 │ NANCY A     80016  false │
     3 │ ANTHONY A   72510  false │
     4 │ ALBA M                   │
     5 │ JAMES A    103350   true │
     6 │ DANIEL A    95484  false │
     7 │ ROBERT K   103272   true │
     8 │ LAKENYA A                │
     9 │ DORIS A                  │
    10 │ BRENDA B    64392  false │
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
    │ 88638.0 │
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
    │ 88638.0 │
    =#


### `Each`

`Each` serves as a barrier for aggregate queries.

    Q = It.department >> (It.employee >> Count)
    #-> It.department >> It.employee >> Count

    chicago[Q]
    #=>
    │ It │
    ┼────┼
    │ 10 │
    =#

    Q = It.department >> Each(It.employee >> Count)
    #-> It.department >> Each(It.employee >> Count)

    chicago[Q]
    #=>
      │ It │
    ──┼────┼
    1 │  4 │
    2 │  3 │
    3 │  3 │
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
    1 │ POLICE   4 │
    2 │ FIRE     3 │
    3 │ OEMC     3 │
    =#

    Q = It.department >>
        (1 .* (It.employee >> Count))
    #-> It.department >> 1 .* (It.employee >> Count)

    chicago[Q]
    #=>
      │ It │
    ──┼────┼
    1 │  4 │
    2 │  3 │
    3 │  3 │
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
    1 │ POLICE          4 │
    2 │ FIRE            3 │
    3 │ OEMC            3 │
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
    3 │ ROBERT K   FIREFIGHTER-EMT    103272       │
    =#


### `Get`

We use the `Get(name)` to extract the value of a record field.

    Q = Get(:department) >> Get(:name)
    #-> Get(:department) >> Get(:name)

    chicago[Q]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    3 │ OEMC   │
    =#

As a shorthand, extracting an attribute of `It` generates a `Get()` query.

    Q = It.department.name
    #-> It.department.name

    chicago[Q]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    3 │ OEMC   │
    =#

We can also extract fields that have ordinal labels, but the label name is not
preserved.

    Q = It.department >>
        Record(It.name, Count(It.employee)) >>
        It.B

    chicago[Q]
    #=>
      │ It │
    ──┼────┼
    1 │  4 │
    2 │  3 │
    3 │  3 │
    =#

Same notation is used to extract values of context parameters defined with
`Keep()` or `Given()`.

    Q = It.department >>
        Keep(:dept_name => It.name) >>
        It.employee >>
        Record(It.dept_name, It.name)

    chicago[Q]
    #=>
       │ employee             │
       │ dept_name  name      │
    ───┼──────────────────────┼
     1 │ POLICE     JEFFERY A │
     2 │ POLICE     NANCY A   │
     3 │ POLICE     ANTHONY A │
     4 │ POLICE     ALBA M    │
     5 │ FIRE       JAMES A   │
     6 │ FIRE       DANIEL A  │
     7 │ FIRE       ROBERT K  │
     8 │ OEMC       LAKENYA A │
     9 │ OEMC       DORIS A   │
    10 │ OEMC       BRENDA B  │
    =#

A context parameter is preferred if it has the same name as a record field.

    Q = It.department >>
        Keep(It.name) >>
        It.employee >>
        Record(It.name, It.position)

    chicago[Q]
    #=>
       │ employee                     │
       │ name    position             │
    ───┼──────────────────────────────┼
     1 │ POLICE  SERGEANT             │
     2 │ POLICE  POLICE OFFICER       │
     3 │ POLICE  POLICE OFFICER       │
     4 │ POLICE  POLICE CADET         │
     5 │ FIRE    FIRE ENGINEER-EMT    │
     6 │ FIRE    FIREFIGHTER-EMT      │
     7 │ FIRE    FIREFIGHTER-EMT      │
     8 │ OEMC    CROSSING GUARD       │
     9 │ OEMC    CROSSING GUARD       │
    10 │ OEMC    TRAFFIC CONTROL AIDE │
    =#

If there is no attribute with the given name, an error is reported.

    Q = It.department.employee.ssn

    chicago[Q]
    #=>
    ERROR: cannot find "ssn" at
    (0:N) × (name = (1:1) × String, position = (1:1) × String, salary = (0:1) × Int64, rate = (0:1) × Float64)
    =#

Regular and named tuples also support attribute lookup.

    Q = Lift((name = "JEFFERY A", position = "SERGEANT", salary = 101442)) >>
        It.position

    chicago[Q]
    #=>
    │ position │
    ┼──────────┼
    │ SERGEANT │
    =#

    Q = Lift((name = "JEFFERY A", position = "SERGEANT", salary = 101442)) >>
        It.ssn

    chicago[Q]
    #=>
    ERROR: cannot find "ssn" at
    (1:1) × NamedTuple{(:name, :position, :salary),Tuple{String,String,Int64}}
    =#

    Q = Lift(("JEFFERY A", "SERGEANT", 101442)) >>
        It.B

    chicago[Q]
    #=>
    │ It       │
    ┼──────────┼
    │ SERGEANT │
    =#

    Q = Lift(("JEFFERY A", "SERGEANT", 101442)) >>
        It.Z

    chicago[Q]
    #=>
    ERROR: cannot find "Z" at
    (1:1) × Tuple{String,String,Int64}
    =#


### `Keep` and `Given`

We use the combinator `Keep()` to assign a value to a context parameter.

    Q = It.department >>
        Keep(:dept_name => It.name) >>
        It.employee >>
        Record(It.dept_name, It.name)
    #=>
    It.department >>
    Keep(:dept_name => It.name) >>
    It.employee >>
    Record(It.dept_name, It.name)
    =#

    chicago[Q]
    #=>
       │ employee             │
       │ dept_name  name      │
    ───┼──────────────────────┼
     1 │ POLICE     JEFFERY A │
     2 │ POLICE     NANCY A   │
     3 │ POLICE     ANTHONY A │
     4 │ POLICE     ALBA M    │
     5 │ FIRE       JAMES A   │
     6 │ FIRE       DANIEL A  │
     7 │ FIRE       ROBERT K  │
     8 │ OEMC       LAKENYA A │
     9 │ OEMC       DORIS A   │
    10 │ OEMC       BRENDA B  │
    =#

Several context parameters could be defined together.

    Q = It.department >>
        Keep(:size => Count(It.employee),
             :half => It.size .÷ 2) >>
        Each(It.employee >> Take(It.half))

    chicago[Q]
    #=>
      │ employee                                    │
      │ name       position           salary  rate  │
    ──┼─────────────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT           101442        │
    2 │ NANCY A    POLICE OFFICER      80016        │
    3 │ JAMES A    FIRE ENGINEER-EMT  103350        │
    4 │ LAKENYA A  CROSSING GUARD             17.68 │
    =#

`Keep()` requires that the parameter is labeled.

    Q = It.department >>
        Keep(Count(It.employee))

    chicago[Q]
    #-> ERROR: parameter name is not specified

`Keep()` will override an existing parameter with the same name.

    Q = It.department >>
        Keep(:current_name => It.name) >>
        It.employee >>
        Filter(It.current_name .== "POLICE") >>
        Keep(:current_name => It.name) >>
        It.current_name

    chicago[Q]
    #=>
      │ current_name │
    ──┼──────────────┼
    1 │ JEFFERY A    │
    2 │ NANCY A      │
    3 │ ANTHONY A    │
    4 │ ALBA M       │
    =#

Combinator `Given()` is used to evaluate a query with the given context
parameters.

    Q = It.department >>
        Given(:size => Count(It.employee),
              :half => It.size .÷ 2,
              It.employee >> Take(It.half))
    #=>
    It.department >> Given(:size => Count(It.employee),
                           :half => div.(It.size, 2),
                           It.employee >> Take(It.half))
    =#

    chicago[Q]
    #=>
      │ employee                                    │
      │ name       position           salary  rate  │
    ──┼─────────────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT           101442        │
    2 │ NANCY A    POLICE OFFICER      80016        │
    3 │ JAMES A    FIRE ENGINEER-EMT  103350        │
    4 │ LAKENYA A  CROSSING GUARD             17.68 │
    =#

`Given()` does not let any parameters defined within its scope escape it.

    Q = It.department >>
        Given(Keep(It.name)) >>
        It.employee >>
        It.name

    chicago[Q]
    #=>
       │ name      │
    ───┼───────────┼
     1 │ JEFFERY A │
     2 │ NANCY A   │
     3 │ ANTHONY A │
     4 │ ALBA M    │
     5 │ JAMES A   │
     6 │ DANIEL A  │
     7 │ ROBERT K  │
     8 │ LAKENYA A │
     9 │ DORIS A   │
    10 │ BRENDA B  │
    =#


### `Count`, `Sum`, `Max`, `Min`

`Count(X)`, `Sum(X)`, `Max(X)`, `Min(X)` evaluate the `X` and emit the number
of elements, their sum, maximum, and minimum respectively.

    Rate = It.department.employee.rate

    Q = Record(Rate,
               :count => Count(Rate),
               :sum => Sum(Rate),
               :max => Max(Rate),
               :min => Min(Rate))
    #=>
    Record(It.department.employee.rate,
           :count => Count(It.department.employee.rate),
           :sum => Sum(It.department.employee.rate),
           :max => Max(It.department.employee.rate),
           :min => Min(It.department.employee.rate))
    =#

    chicago[Q]
    #=>
    │ rate                count  sum    max    min  │
    ┼───────────────────────────────────────────────┼
    │ 9.46; 17.68; 19.38      3  46.52  19.38  9.46 │
    =#

`Count`, `Sum`, `Max`, and `Min` could also be used as aggregate primitives.

    Q = Record(Rate,
               :count => Rate >> Count,
               :sum => Rate >> Sum,
               :max => Rate >> Max,
               :min => Rate >> Min)
    #=>
    Record(It.department.employee.rate,
           :count => It.department.employee.rate >> Count,
           :sum => It.department.employee.rate >> Sum,
           :max => It.department.employee.rate >> Max,
           :min => It.department.employee.rate >> Min)
    =#

    chicago[Q]
    #=>
    │ rate                count  sum    max    min  │
    ┼───────────────────────────────────────────────┼
    │ 9.46; 17.68; 19.38      3  46.52  19.38  9.46 │
    =#

When applied to an empty input, `Sum` emits `0`, `Min` and `Max` emit no
output.

    Rate = It.employee.rate

    Q = It.department >>
        Record(It.name,
               Rate,
               :count => Count(Rate),
               :sum => Sum(Rate),
               :max => Max(Rate),
               :min => Min(Rate))

    chicago[Q]
    #=>
      │ department                                       │
      │ name    rate          count  sum    max    min   │
    ──┼──────────────────────────────────────────────────┼
    1 │ POLICE  9.46              1   9.46   9.46   9.46 │
    2 │ FIRE                      0   0.0                │
    3 │ OEMC    17.68; 19.38      2  37.06  19.38  17.68 │
    =#


### `Filter`

We use `Filter()` to filter the input by the given predicate.

    Q = It.department >>
        Filter(It.name .== "POLICE") >>
        It.employee >>
        Filter(It.name .== "JEFFERY A")
    #=>
    It.department >>
    Filter(It.name .== "POLICE") >>
    It.employee >>
    Filter(It.name .== "JEFFERY A")
    =#

    chicago[Q]
    #=>
      │ employee                          │
      │ name       position  salary  rate │
    ──┼───────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT  101442       │
    =#

The predicate must produce `true` of `false` values.

    Q = It.department >>
        Filter(Count(It.employee))

    chicago[Q]
    #-> ERROR: expected a predicate

The input data is dropped when the output of the predicate contains only
`false` elements.

    Q = It.department >>
        Filter(It.employee >> (It.salary .> 100000)) >>
        Record(It.name, It.employee.salary)

    chicago[Q]
    #=>
      │ department                    │
      │ name    salary                │
    ──┼───────────────────────────────┼
    1 │ POLICE  101442; 80016; 72510  │
    2 │ FIRE    103350; 95484; 103272 │
    =#


### `Take` and `Drop`

We use `Take(N)` and `Drop(N)` to pass or drop the first `N` input elements.

    Employee =
        It.department >>
        Filter(It.name .== "POLICE") >>
        It.employee

    Q = Employee >> Take(3)
    #-> It.department >> Filter(It.name .== "POLICE") >> It.employee >> Take(3)

    chicago[Q]
    #=>
      │ employee                                │
      │ name       position        salary  rate │
    ──┼─────────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT        101442       │
    2 │ NANCY A    POLICE OFFICER   80016       │
    3 │ ANTHONY A  POLICE OFFICER   72510       │
    =#

    Q = Employee >> Drop(3)
    #-> It.department >> Filter(It.name .== "POLICE") >> It.employee >> Drop(3)

    chicago[Q]
    #=>
      │ employee                           │
      │ name    position      salary  rate │
    ──┼────────────────────────────────────┼
    1 │ ALBA M  POLICE CADET          9.46 │
    =#

`Take(-N)` drops the last `N` elements, while `Drop(-N)` keeps the last `N`
elements.

    Q = Employee >> Take(-3)

    chicago[Q]
    #=>
      │ employee                          │
      │ name       position  salary  rate │
    ──┼───────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT  101442       │
    =#

    Q = Employee >> Drop(-3)

    chicago[Q]
    #=>
      │ employee                                │
      │ name       position        salary  rate │
    ──┼─────────────────────────────────────────┼
    1 │ NANCY A    POLICE OFFICER   80016       │
    2 │ ANTHONY A  POLICE OFFICER   72510       │
    3 │ ALBA M     POLICE CADET            9.46 │
    =#

`Take` and `Drop` accept a query argument, which is evaluated against the input
source and must produce a singular integer.

    Half = Count(Employee) .÷ 2

    Q = Employee >> Take(Half)

    chicago[Q]
    #=>
      │ employee                                │
      │ name       position        salary  rate │
    ──┼─────────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT        101442       │
    2 │ NANCY A    POLICE OFFICER   80016       │
    =#

    Q = Take(Employee >> It.name)

    chicago[Q]
    #-> ERROR: expected a singular integer


### `Unique` and `Group`

We use the `Unique` combinator to produce unique elements of a collection.

    Q = It.department >>
        Record(It.name, Unique(It.employee.position))
    #-> It.department >> Record(It.name, Unique(It.employee.position))

    chicago[Q]
    #=>
      │ department                                     │
      │ name    position                               │
    ──┼────────────────────────────────────────────────┼
    1 │ POLICE  POLICE CADET; POLICE OFFICER; SERGEANT │
    2 │ FIRE    FIRE ENGINEER-EMT; FIREFIGHTER-EMT     │
    3 │ OEMC    CROSSING GUARD; TRAFFIC CONTROL AIDE   │
    =#

`Unique` also has a primitive query form.

    Q = It.department.employee.position >> Unique
    #-> It.department.employee.position >> Unique

    chicago[Q]
    #=>
      │ position             │
    ──┼──────────────────────┼
    1 │ CROSSING GUARD       │
    2 │ FIRE ENGINEER-EMT    │
    3 │ FIREFIGHTER-EMT      │
    4 │ POLICE CADET         │
    5 │ POLICE OFFICER       │
    6 │ SERGEANT             │
    7 │ TRAFFIC CONTROL AIDE │
    =#

We use the `Group` combinator to group the input by the given key.

    Q = It.department.employee >>
        Group(It.position)
    #-> It.department.employee >> Group(It.position)

    chicago[Q]
    #=>
      │ position              employee                                             …
    ──┼────────────────────────────────────────────────────────────────────────────…
    1 │ CROSSING GUARD        LAKENYA A, CROSSING GUARD, missing, 17.68; DORIS A, C…
    2 │ FIRE ENGINEER-EMT     JAMES A, FIRE ENGINEER-EMT, 103350, missing          …
    3 │ FIREFIGHTER-EMT       DANIEL A, FIREFIGHTER-EMT, 95484, missing; ROBERT K, …
    4 │ POLICE CADET          ALBA M, POLICE CADET, missing, 9.46                  …
    5 │ POLICE OFFICER        NANCY A, POLICE OFFICER, 80016, missing; ANTHONY A, P…
    6 │ SERGEANT              JEFFERY A, SERGEANT, 101442, missing                 …
    7 │ TRAFFIC CONTROL AIDE  BRENDA B, TRAFFIC CONTROL AIDE, 64392, missing       …
    =#

Arbitrary key expressions are supported.

    Q = It.department >>
        Group(:size => Count(It.employee)) >>
        Record(It.size, :count => Count(It.department))

    chicago[Q]
    #=>
      │ size  count │
    ──┼─────────────┼
    1 │    3      2 │
    2 │    4      1 │
    =#

Empty keys are placed on top.

    Q = It.department.employee >>
        Group(:grade => It.salary .÷ 10000) >>
        Record(It.grade, :n => Count(It.employee))

    chicago[Q]
    #=>
      │ grade  n │
    ──┼──────────┼
    1 │        3 │
    2 │     6  1 │
    3 │     7  1 │
    4 │     8  1 │
    5 │     9  1 │
    6 │    10  3 │
    =#

More than one key column could be provided.

    Q = It.department.employee >>
        Group(ismissing.(It.salary),
              ismissing.(It.rate)) >>
        Record(It.A, It.B, Count(It.employee))

    chicago[Q]
    #=>
      │ #A     #B     #C │
    ──┼──────────────────┼
    1 │ false   true   7 │
    2 │  true  false   3 │
    =#

