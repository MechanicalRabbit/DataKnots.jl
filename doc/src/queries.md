# Query Algebra

In this section, we sketch the design and implementation of the query algebra.
We will need the following definitions.

    using DataKnots:
        @VectorTree,
        @query,
        Collect,
        Count,
        DataKnot,
        Drop,
        Each,
        Environment,
        Exists,
        Filter,
        First,
        Get,
        Given,
        Group,
        Is0to1,
        Is0toN,
        Is1to1,
        Is1toN,
        It,
        Join,
        Keep,
        Label,
        Last,
        Let,
        Lift,
        Max,
        Min,
        Mix,
        Nth,
        Record,
        Sum,
        Tag,
        Take,
        Unique,
        assemble,
        elements,
        rewrite_all,
        shape,
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
    │ department{name,employee{name,position,salary,rate}}                │
    ┼─────────────────────────────────────────────────────────────────────┼
    │ POLICE, [JEFFERY A, SERGEANT, 101442, missing; NANCY A, POLICE OFFI…│
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
    ┼───┼
    │ 3 │
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

    p1 = assemble(env, p0, Get(:department))
    #-> chain_of(with_elements(column(:department)), flatten())

The pipeline `p1` fetches the attribute *department* from the input data.  In
general, `Get(name)` maps a pipeline to its elementwise composition with
`column(name)`.  For example, when we apply `Get(:employee)` to `p1`, what we
get is the result of `compose(p1, column(:employee))`.

    p2 = assemble(env, p1, Get(:employee))
    #=>
    chain_of(chain_of(with_elements(column(:department)), flatten()),
             chain_of(with_elements(column(:employee)), flatten()))
    =#

To finish assembling the pipeline, we apply `Filter(SalaryOver100K)` to `p2`.
`Filter` acts on the input pipeline as follows.  First, it assembles the
predicate pipeline by applying the predicate query to a trivial pipeline.

    pc0 = target_pipe(p2)
    #-> wrap()

    pc1 = assemble(env, pc0, SalaryOver100K)
    #=>
    chain_of(
        wrap(),
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

    p3 = assemble(env, p2, Filter(SalaryOver100K))
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

    p = rewrite_all(uncover(p3))
    #=>
    chain_of(with_elements(column(:department)),
             flatten(),
             with_elements(column(:employee)),
             flatten(),
             with_elements(chain_of(tuple_of(pass(),
                                             chain_of(tuple_of(
                                                          column(:salary),
                                                          filler(100000)),
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
    ┼───┼
    │ 3 │
    =#

Any parameters to the query should be be passed as keyword arguments.

    Q = It.department >>
        Filter(Count(It.employee >> Filter(It.salary .> It.AMT)) .>= It.SZ) >>
        Count

    chicago[Q, AMT=100000, SZ=1]
    #=>
    ┼───┼
    │ 2 │
    =#

We can use the function `assemble()` to see the query plan.

    p = assemble(chicago, Count(It.department))
    #=>
    with_elements(chain_of(column(:department), block_length()))
    =#

    p(chicago)
    #=>
    ┼───┼
    │ 3 │
    =#

### `@query`

`Query` objects could be constructed using a convenient notation provided
by the macro `@query`.  For example, the query `Count(It.department)` could
also be written as:

    @query count(department)
    #-> Count(Get(:department))

The `@query` macro could also be used to apply the constructed query to
a `DataKnot`.

    @query chicago count(department)
    #=>
    ┼───┼
    │ 3 │
    =#

Query parameters could be passed as keyword arguments.

    @query chicago AMT=100000 SZ=1 begin
        department
        filter(count(employee.filter(salary > AMT)) >= SZ)
        count()
    end
    #=>
    ┼───┼
    │ 2 │
    =#

The following syntax is recognized by the `@query` macro.

A bare field identifier can be used to extract the value of the given field.

    @query department
    #-> Get(:department)

A sequence of statements in a `begin`/`end` block becomes a composition
of queries.

    @query begin
        department
        employee
        salary
        max()
    end
    #-> Get(:department) >> Get(:employee) >> Get(:salary) >> Then(Max)

Expressions separated by `.` are also converted to query composition.

    @query department.employee.salary.max()
    #-> Get(:department) >> Get(:employee) >> Get(:salary) >> Then(Max)

The `let` clause is converted to the `Given` combinator.

    @query begin
        department
        let max_salary => max(employee.salary)
            employee
            filter(salary == max_salary)
        end
    end
    #=>
    Get(:department) >>
    Given(Max(Get(:employee) >> Get(:salary)) >> Label(:max_salary),
          Get(:employee) >>
          Filter(Lift(==, (Get(:salary), Get(:max_salary)))))
    =#

Curly brackets are converted to the `Record` combinator.

    @query begin
        department
        { name, count(employee) }
    end
    #-> Get(:department) >> Record(Get(:name), Count(Get(:employee)))

    @query department.{name, count(employee)}
    #-> Get(:department) >> Record(Get(:name), Count(Get(:employee)))

    @query department{name, count(employee)}
    #-> Get(:department) >> Record(Get(:name), Count(Get(:employee)))

The `Pair` constructor `=>` can be used for label assignment.

    @query size => count(employee)
    #-> Count(Get(:employee)) >> Label(:size)

Constants, functions and operators are automatically lifted.

    @query department.titlecase(name)
    #-> Get(:department) >> Lift(titlecase, (Get(:name),))

    @query employee.filter(salary > 100_000)
    #-> Get(:employee) >> Filter(Lift(>, (Get(:salary), Lift(100000))))

Logical operators are comparison chains are also supported.

    @query employee.filter(50_000 < salary < 100_000)
    #=>
    Get(:employee) >> Filter(Lift(&,
                                  (Lift(<, (Lift(50000), Get(:salary))),
                                   Lift(<, (Get(:salary), Lift(100000))))))
    =#

    @query employee.filter(50_000 < salary && salary < 100_000)
    #=>
    Get(:employee) >> Filter(Lift(&,
                                  (Lift(<, (Lift(50000), Get(:salary))),
                                   Lift(<, (Get(:salary), Lift(100000))))))
    =#

    @query employee.filter(salary < 50_000 || salary > 100_000)
    #=>
    Get(:employee) >> Filter(Lift(|,
                                  (Lift(<, (Get(:salary), Lift(50000))),
                                   Lift(>, (Get(:salary), Lift(100000))))))
    =#

Queries defined elsewhere could be embedded in a `@query` expression using
interpolation syntax (`$`).

    Size = @query count(employee)
    #-> Count(Get(:employee))

    @query department{name, $Size}
    #-> Get(:department) >> Record(Get(:name), Count(Get(:employee)))

### Composition

Queries can be composed sequentially using the `>>` combinator.

    Q = Lift(3) >> (It .+ 4) >> (It .* 6)
    #-> Lift(3) >> (It .+ 4) >> It .* 6

    chicago[Q]
    #=>
    ┼────┼
    │ 42 │
    =#

The `It` query primitive is the identity with respect to `>>`.

    Q = It >> Q >> It
    #-> It >> Lift(3) >> (It .+ 4) >> It .* 6 >> It

    chicago[Q]
    #=>
    ┼────┼
    │ 42 │
    =#

In `@query` notation, the identity query is called `it`.

    @query it
    #-> It

Composition of queries is written as a sequence of statements in a
`begin`/`end` block.

    @query begin
        3
        it + 4
        it * 6
    end
    #-> Lift(3) >> Lift(+, (It, Lift(4))) >> Lift(*, (It, Lift(6)))

    @query (3; it + 4; it * 6)
    #-> Lift(3) >> Lift(+, (It, Lift(4))) >> Lift(*, (It, Lift(6)))

Alternatively, the `.` symbol is used as the composition combinator.

    @query (3).(it + 4).(it * 6)
    #-> Lift(3) >> Lift(+, (It, Lift(4))) >> Lift(*, (It, Lift(6)))

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

In `@query` notation, `Record(X₁, X₂ … Xₙ)` is written as
`record(X₁, X₂ … Xₙ)`.

    @query department.record(name, size => count(employee))
    #=>
    Get(:department) >> Record(Get(:name),
                               Count(Get(:employee)) >> Label(:size))
    =#

Alternatively, we could use the `{}` brackets.

    @query {count(department), max(department.count(employee))}
    #=>
    Record(Count(Get(:department)),
           Max(Get(:department) >> Count(Get(:employee))))
    =#

When `{}` is used in composition, the composition operator `.` could be
omitted.

    @query department.{name, size => count(employee)}
    #=>
    Get(:department) >> Record(Get(:name),
                               Count(Get(:employee)) >> Label(:size))
    =#

    @query department{name, size => count(employee)}
    #=>
    Get(:department) >> Record(Get(:name),
                               Count(Get(:employee)) >> Label(:size))
    =#

### `Collect`

The query `Collect(X)` adds a new field to the input record.

    Q = It.department >> Collect(:size => Count(It.employee))
    #-> It.department >> Collect(:size => Count(It.employee))

    chicago[Q]
    #=>
      │ department                                                        │
      │ name    employee{name,position,salary,rate}                  size │
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ POLICE  JEFFERY A, SERGEANT, 101442, missing; NANCY A, POLI…    4 │
    2 │ FIRE    JAMES A, FIRE ENGINEER-EMT, 103350, missing; DANIEL…    3 │
    3 │ OEMC    LAKENYA A, CROSSING GUARD, missing, 17.68; DORIS A,…    3 │
    =#

More than one field could be added at the same time.

    Q = It.department >>
        Collect(:size => Count(It.employee),
                :avg_salary => Sum(It.employee.salary) ./ It.size)

    chicago[Q]
    #=>
      │ department                                                        │
      │ name    employee{name,position,salary,rate}      size  avg_salary │
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ POLICE  JEFFERY A, SERGEANT, 101442, missing; N…    4     63492.0 │
    2 │ FIRE    JAMES A, FIRE ENGINEER-EMT, 103350, mis…    3    100702.0 │
    3 │ OEMC    LAKENYA A, CROSSING GUARD, missing, 17.…    3     21464.0 │
    =#

If the new field has no label, an ordinal label will be assigned to it.

    Q = It.department >> Collect(Count(It.employee))

    chicago[Q]
    #=>
      │ department                                                        │
      │ name    employee{name,position,salary,rate}                    #C │
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ POLICE  JEFFERY A, SERGEANT, 101442, missing; NANCY A, POLICE…  4 │
    2 │ FIRE    JAMES A, FIRE ENGINEER-EMT, 103350, missing; DANIEL A…  3 │
    3 │ OEMC    LAKENYA A, CROSSING GUARD, missing, 17.68; DORIS A, C…  3 │
    =#

If the record already has a field with the same name, that field is replaced
with the new field.

    Q = It.department >> Collect(:employee => It.employee.name >> titlecase.(It),
                                 :name => It.name >> titlecase.(It))

    chicago[Q]
    #=>
      │ department                                    │
      │ name    employee                              │
    ──┼───────────────────────────────────────────────┼
    1 │ Police  Jeffery A; Nancy A; Anthony A; Alba M │
    2 │ Fire    James A; Daniel A; Robert K           │
    3 │ Oemc    Lakenya A; Doris A; Brenda B          │
    =#

To remove a field from a record, replace it with the value `nothing`.

    Q = It.department >> Collect(:size => Count(It.employee),
                                 :employee => nothing)

    chicago[Q]
    #=>
      │ department   │
      │ name    size │
    ──┼──────────────┼
    1 │ POLICE     4 │
    2 │ FIRE       3 │
    3 │ OEMC       3 │
    =#

`Collect` can be used as an aggregate primitive.

    Q = It.department.employee >> Collect

    chicago[Q]
    #=>
    │ department{name,employee{name,pos… employee{name,position,salary,ra…│
    ┼─────────────────────────────────────────────────────────────────────┼
    │ POLICE, [JEFFERY A, SERGEANT, 101… JEFFERY A, SERGEANT, 101442, mis…│
    =#

In `@query` notation, `Collect(X)` is written as `collect(X)`.

    @query department.collect(size => count(employee), employee => nothing)
    #=>
    Get(:department) >> Collect(Count(Get(:employee)) >> Label(:size),
                                Lift(nothing) >> Label(:employee))
    =#

The aggregate primitive `Collect` is written as `collect()`.

    @query department.employee.collect()
    #-> Get(:department) >> Get(:employee) >> Then(Collect)

### `Join`

`Join(X)`, just like `Collect(X)`, adds a field to the input record.  As opposed to
`Collect`, `Join(X)` evaluates its argument against the input source.

    Q = It.department >> Each(It.employee >> Join(:dept_name => It.name))
    #-> It.department >> Each(It.employee >> Join(:dept_name => It.name))

    chicago[Q]
    #=>
       │ employee                                                  │
       │ name       position              salary  rate   dept_name │
    ───┼───────────────────────────────────────────────────────────┼
     1 │ JEFFERY A  SERGEANT              101442         POLICE    │
     2 │ NANCY A    POLICE OFFICER         80016         POLICE    │
     3 │ ANTHONY A  POLICE OFFICER         72510         POLICE    │
     4 │ ALBA M     POLICE CADET                   9.46  POLICE    │
     5 │ JAMES A    FIRE ENGINEER-EMT     103350         FIRE      │
     6 │ DANIEL A   FIREFIGHTER-EMT        95484         FIRE      │
     7 │ ROBERT K   FIREFIGHTER-EMT       103272         FIRE      │
     8 │ LAKENYA A  CROSSING GUARD                17.68  OEMC      │
     9 │ DORIS A    CROSSING GUARD                19.38  OEMC      │
    10 │ BRENDA B   TRAFFIC CONTROL AIDE   64392         OEMC      │
    =#

At the same time, `Join(X)` uses the target source, which allows us to
correlate the joined field with the input data.

    Q = It.department.employee >>
        Filter(Exists(It.salary)) >>
        Keep(:the_salary => It.salary) >>
        Join(:rank => Count(It.department.employee >> Filter(It.salary .>= It.the_salary)))

    chicago[Q]
    #=>
      │ employee                                            │
      │ name       position              salary  rate  rank │
    ──┼─────────────────────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT              101442           3 │
    2 │ NANCY A    POLICE OFFICER         80016           5 │
    3 │ ANTHONY A  POLICE OFFICER         72510           6 │
    4 │ JAMES A    FIRE ENGINEER-EMT     103350           1 │
    5 │ DANIEL A   FIREFIGHTER-EMT        95484           4 │
    6 │ ROBERT K   FIREFIGHTER-EMT       103272           2 │
    7 │ BRENDA B   TRAFFIC CONTROL AIDE   64392           7 │
    =#

If the new field has no label, it will have an ordinal label assigned to it.

    Q = It.department >>
        Keep(:the_size => Count(It.employee)) >>
        Join(Count(It.department >> Filter(Count(It.employee) .>= It.the_size)))

    chicago[Q]
    #=>
      │ department                                                        │
      │ name    employee{name,position,salary,rate}                    #C │
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ POLICE  JEFFERY A, SERGEANT, 101442, missing; NANCY A, POLICE…  1 │
    2 │ FIRE    JAMES A, FIRE ENGINEER-EMT, 103350, missing; DANIEL A…  3 │
    3 │ OEMC    LAKENYA A, CROSSING GUARD, missing, 17.68; DORIS A, C…  3 │
    =#

If the record already has a field with the same name, that field is replaced
with the new field.

    Q = It.department >>
        Each(It.employee >>
             Keep(:the_position => It.position) >>
             Join(:position => It.the_position .* " (" .* It.name .* ")"))

    chicago[Q]
    #=>
       │ employee                                              │
       │ name       position                     salary  rate  │
    ───┼───────────────────────────────────────────────────────┼
     1 │ JEFFERY A  SERGEANT (POLICE)            101442        │
     2 │ NANCY A    POLICE OFFICER (POLICE)       80016        │
     3 │ ANTHONY A  POLICE OFFICER (POLICE)       72510        │
     4 │ ALBA M     POLICE CADET (POLICE)                 9.46 │
     5 │ JAMES A    FIRE ENGINEER-EMT (FIRE)     103350        │
     6 │ DANIEL A   FIREFIGHTER-EMT (FIRE)        95484        │
     7 │ ROBERT K   FIREFIGHTER-EMT (FIRE)       103272        │
     8 │ LAKENYA A  CROSSING GUARD (OEMC)                17.68 │
     9 │ DORIS A    CROSSING GUARD (OEMC)                19.38 │
    10 │ BRENDA B   TRAFFIC CONTROL AIDE (OEMC)   64392        │
    =#

In `@query` notation, `Join(X)` is written as `join(X)`.

    @query department.each(employee.join(dept_name => name))
    #=>
    Get(:department) >> Each(Get(:employee) >> Join(Get(:name) >>
                                                    Label(:dept_name)))
    =#

### `Mix`

The query `Mix(X₁, X₂ … Xₙ)` emits records containing all combinations of elements
generated by `X₁`, `X₂` … `Xₙ`.

    Q = It.department >> Mix(It.name, It.employee)
    #-> It.department >> Mix(It.name, It.employee)

    chicago[Q]
    #=>
       │ department                                             │
       │ name    employee{name,position,salary,rate}            │
    ───┼────────────────────────────────────────────────────────┼
     1 │ POLICE  JEFFERY A, SERGEANT, 101442, missing           │
     2 │ POLICE  NANCY A, POLICE OFFICER, 80016, missing        │
     3 │ POLICE  ANTHONY A, POLICE OFFICER, 72510, missing      │
     4 │ POLICE  ALBA M, POLICE CADET, missing, 9.46            │
     5 │ FIRE    JAMES A, FIRE ENGINEER-EMT, 103350, missing    │
     6 │ FIRE    DANIEL A, FIREFIGHTER-EMT, 95484, missing      │
     7 │ FIRE    ROBERT K, FIREFIGHTER-EMT, 103272, missing     │
     8 │ OEMC    LAKENYA A, CROSSING GUARD, missing, 17.68      │
     9 │ OEMC    DORIS A, CROSSING GUARD, missing, 19.38        │
    10 │ OEMC    BRENDA B, TRAFFIC CONTROL AIDE, 64392, missing │
    =#

When a field has no label, an ordinal label is assigned.

    Q = It.department >> Mix(It.name, It.employee.rate >> round.(It))

    chicago[Q]
    #=>
      │ department   │
      │ name    #B   │
    ──┼──────────────┼
    1 │ POLICE   9.0 │
    2 │ OEMC    18.0 │
    3 │ OEMC    19.0 │
    =#

Similarly, duplicate fields are replaced by ordinal labels.

    Q = It.department >> Mix(It.name, It.employee.name)

    chicago[Q]
    #=>
       │ department        │
       │ #A      name      │
    ───┼───────────────────┼
     1 │ POLICE  JEFFERY A │
     2 │ POLICE  NANCY A   │
     3 │ POLICE  ANTHONY A │
     4 │ POLICE  ALBA M    │
     5 │ FIRE    JAMES A   │
     6 │ FIRE    DANIEL A  │
     7 │ FIRE    ROBERT K  │
     8 │ OEMC    LAKENYA A │
     9 │ OEMC    DORIS A   │
    10 │ OEMC    BRENDA B  │
    =#

In `@query` notation, `Mix(X₁, X₂ … Xₙ)` is written as `mix(X₁, X₂ … Xₙ)`.

    @query department.mix(name, employee)
    #-> Get(:department) >> Mix(Get(:name), Get(:employee))

### `Lift`

The `Lift` constructor is used to convert Julia values and functions to
queries.

`Lift(val)` makes a query primitive from a Julia value.

    Q = Lift("Hello World!")
    #-> Lift("Hello World!")

    chicago[Q]
    #=>
    ┼──────────────┼
    │ Hello World! │
    =#

Lifting `missing` produces no output.

    Q = Lift(missing)
    #-> Lift(missing)

    chicago[Q]
    #=>
    (empty)
    =#

Lifting a vector produces plural output.

    Q = Lift('a':'c')
    #-> Lift('a':1:'c')

    chicago[Q]
    #=>
    ──┼───┼
    1 │ a │
    2 │ b │
    3 │ c │
    =#

When lifting a vector, we can specify the cardinality constraint.

    Q = Lift('a':'c', :x1toN)
    #-> Lift('a':1:'c', :x1toN)

    chicago[Q]
    #=>
    ──┼───┼
    1 │ a │
    2 │ b │
    3 │ c │
    =#

`Lift` can also convert Julia functions to query combinators.

    Inc(X) = Lift(x -> x+1, (X,))

    Q = Lift(0) >> Inc(It)
    #-> Lift(0) >> Lift(x -> x + 1, (It,))

    chicago[Q]
    #=>
    ┼───┼
    │ 1 │
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
    ┼─────────┼
    │ 88638.0 │
    =#

Just like with regular values, `missing` and vector results are interpreted as
no and plural output.

    Q = Inc(missing)
    #-> Lift(x -> x + 1, (missing,))

    chicago[Q]
    #=>
    (empty)
    =#

    OneTo(N) = Lift(UnitRange, (1, N))

    Q = OneTo(3)
    #-> Lift(UnitRange, (1, 3))

    chicago[Q]
    #=>
    ──┼───┼
    1 │ 1 │
    2 │ 2 │
    3 │ 3 │
    =#

Julia functions are lifted when they are broadcasted over queries.

    Q = mean.(It.department.employee.salary)
    #-> mean.(It.department.employee.salary)

    chicago[Q]
    #=>
    ┼─────────┼
    │ 88638.0 │
    =#

In `@query` notation, values and functions are lifted automatically.

    @query "Hello World!"
    #-> Lift("Hello World!")

    @query missing
    #-> Lift(missing)

    @query 'a':'c'
    #-> Lift(Colon, (Lift('a'), Lift('c')))

    @query (0; it + 1)
    #-> Lift(0) >> Lift(+, (It, Lift(1)))

    @query department.employee{name, salary, salary > 100000}
    #=>
    Get(:department) >>
    Get(:employee) >>
    Record(Get(:name), Get(:salary), Lift(>, (Get(:salary), Lift(100000))))
    =#

    @query mean(department.employee.salary)
    #-> Lift(mean, (Get(:department) >> Get(:employee) >> Get(:salary),))

Query-valued functions are also supported.  They are not lifted, but applied
immediately.

    increment(x) = @query $x + 1

    @query $increment(1)
    #-> Lift(+, (Lift(1), Lift(1)))

Query value functions could also be defined via `Lift`.

    increment(x) = Lift(+, (x, 1))

    @query $increment(1 + 1)
    #-> Lift(+, (Lift(+, (Lift(1), Lift(1))), 1))

### `Each`

`Each` serves as a barrier for aggregate queries.

    Q = It.department >> (It.employee >> Count)
    #-> It.department >> It.employee >> Count

    chicago[Q]
    #=>
    ┼────┼
    │ 10 │
    =#

    Q = It.department >> Each(It.employee >> Count)
    #-> It.department >> Each(It.employee >> Count)

    chicago[Q]
    #=>
    ──┼───┼
    1 │ 4 │
    2 │ 3 │
    3 │ 3 │
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
    ──┼───┼
    1 │ 4 │
    2 │ 3 │
    3 │ 3 │
    =#

In `@query` notation, `Each(X)` is written as `each(X)`.

    @query department.each(employee.count())
    #-> Get(:department) >> Each(Get(:employee) >> Then(Count))

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

In `@query` notation, we could use `label(name)` or `=>` syntax.

    @query count(department).label(num_dept)
    #-> Count(Get(:department)) >> Label(:num_dept)

    @query num_dept => count(department)
    #-> Count(Get(:department)) >> Label(:num_dept)

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
    ──┼───┼
    1 │ 4 │
    2 │ 3 │
    3 │ 3 │
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

In `@query` notation, `Get(:name)` is written as `name`.

    @query department.name
    #-> Get(:department) >> Get(:name)

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

`Given` has an alias called `Let`.

    Let
    #-> DataKnots.Given

In `@query` notation, `Keep(X)` and `Given(X, Q)` are written as `keep(X)` and
`given(X, Q)`.

    @query department.keep(dept_name => name).employee{dept_name, name}
    #=>
    Get(:department) >>
    Keep(Get(:name) >> Label(:dept_name)) >>
    Get(:employee) >>
    Record(Get(:dept_name), Get(:name))
    =#

    @query begin
        department
        given(size => count(employee),
              half => size ÷ 2,
              employee.take(half))
    end
    #=>
    Get(:department) >> Given(Count(Get(:employee)) >> Label(:size),
                              Lift(div, (Get(:size), Lift(2))) >>
                              Label(:half),
                              Get(:employee) >> Take(Get(:half)))
    =#

Alternatively, the `let` clause is translated to a `Given` expression.

    @query begin
        department
        let dept_name => name
            employee{dept_name, name}
        end
    end
    #=>
    Get(:department) >> Given(Get(:name) >> Label(:dept_name),
                              Get(:employee) >> Record(Get(:dept_name),
                                                       Get(:name)))
    =#

    @query begin
        department
        let size => count(employee), half => size ÷ 2
            employee.take(half)
        end
    end
    #=>
    Get(:department) >> Given(Count(Get(:employee)) >> Label(:size),
                              Lift(div, (Get(:size), Lift(2))) >>
                              Label(:half),
                              Get(:employee) >> Take(Get(:half)))
    =#

### `Count`, `Exists`, `Sum`, `Max`, `Min`

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

`Exists(X)` evaluates `X` and emits a Boolean value that indicates whether `X`
produces at least one value or not.

    Q = It.department.employee >>
        Record(It.name,
               It.salary,
               :has_salary => Exists(It.salary),
               It.rate,
               :has_rate => It.rate >> Exists)
    #=>
    It.department.employee >> Record(It.name,
                                     It.salary,
                                     :has_salary => Exists(It.salary),
                                     It.rate,
                                     :has_rate => It.rate >> Exists)
    =#

    chicago[Q]
    #=>
       │ employee                                       │
       │ name       salary  has_salary  rate   has_rate │
    ───┼────────────────────────────────────────────────┼
     1 │ JEFFERY A  101442        true            false │
     2 │ NANCY A     80016        true            false │
     3 │ ANTHONY A   72510        true            false │
     4 │ ALBA M                  false   9.46      true │
     5 │ JAMES A    103350        true            false │
     6 │ DANIEL A    95484        true            false │
     7 │ ROBERT K   103272        true            false │
     8 │ LAKENYA A               false  17.68      true │
     9 │ DORIS A                 false  19.38      true │
    10 │ BRENDA B    64392        true            false │
    =#

These operations are also available in the `@query` notation.

    @query begin
        department.employee.rate.collect()
        {rate, count(rate), sum(rate), max(rate), min(rate)}
    end
    #=>
    Get(:department) >>
    Get(:employee) >>
    Get(:rate) >>
    Then(Collect) >>
    Record(Get(:rate),
           Count(Get(:rate)),
           Sum(Get(:rate)),
           Max(Get(:rate)),
           Min(Get(:rate)))
    =#

    @query begin
        department
        collect(employee.rate)
        {rate, rate.count(), rate.sum(), rate.max(), rate.min()}
    end
    #=>
    Get(:department) >>
    Collect(Get(:employee) >> Get(:rate)) >>
    Record(Get(:rate),
           Get(:rate) >> Then(Count),
           Get(:rate) >> Then(Sum),
           Get(:rate) >> Then(Max),
           Get(:rate) >> Then(Min))
    =#

    @query department.employee{name, exists(salary), rate.exists()}
    #=>
    Get(:department) >>
    Get(:employee) >>
    Record(Get(:name), Exists(Get(:salary)), Get(:rate) >> Then(Exists))
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

In `@query` notation, we write `filter(X)`.

    @query begin
        department
        filter(name == "POLICE")
        employee
        filter(name == "JEFFERY A")
    end
    #=>
    Get(:department) >>
    Filter(Lift(==, (Get(:name), Lift("POLICE")))) >>
    Get(:employee) >>
    Filter(Lift(==, (Get(:name), Lift("JEFFERY A"))))
    =#

### `First`, `Last`, `Nth`

We can use `First(X)`, `Last(X)` and `Nth(X, N)` to extract the first, the
last, or the `N`-th element of the output of `X`.

    chicago[It.department.name]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    3 │ OEMC   │
    =#

    Q = First(It.department.name)
    #-> First(It.department.name)

    chicago[Q]
    #=>
    │ name   │
    ┼────────┼
    │ POLICE │
    =#

    Q = Last(It.department.name)
    #-> Last(It.department.name)

    chicago[Q]
    #=>
    │ name │
    ┼──────┼
    │ OEMC │
    =#

    Q = Nth(It.department.name, 2)
    #-> Nth(It.department.name, 2)

    chicago[Q]
    #=>
    │ name │
    ┼──────┼
    │ FIRE │
    =#

These operations also have an aggregate form.

    Q = It.department.name >> First
    #-> It.department.name >> First

    chicago[Q]
    #=>
    │ name   │
    ┼────────┼
    │ POLICE │
    =#

    Q = It.department.name >> Last
    #-> It.department.name >> Last

    chicago[Q]
    #=>
    │ name │
    ┼──────┼
    │ OEMC │
    =#

    Q = It.department.name >> Nth(2)
    #-> It.department.name >> Nth(2)

    chicago[Q]
    #=>
    │ name │
    ┼──────┼
    │ FIRE │
    =#

`Nth` can take a query argument, which is evaluated against the input source
and must produce a singular mandatory integer value.

    chicago[Nth(It.department.name, Count(It.department) .- 1)]
    #=>
    │ name │
    ┼──────┼
    │ FIRE │
    =#

    chicago[It.department.name >> Nth(Count(It.department) .- 1)]
    #=>
    │ name │
    ┼──────┼
    │ FIRE │
    =#

In `@query` notation, we write `first()`, `last()` and `nth(N)`.

    @query first(department)
    #-> First(Get(:department))

    @query last(department)
    #-> Last(Get(:department))

    @query nth(department, 2)
    #-> Nth(Get(:department), Lift(2))

    @query department.first()
    #-> Get(:department) >> Then(First)

    @query department.last()
    #-> Get(:department) >> Then(Last)

    @query department.nth(2)
    #-> Get(:department) >> Nth(Lift(2))

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

In `@query` notation, we write `take(N)` and `drop(N)`.

    @query department.employee.take(3)
    #-> Get(:department) >> Get(:employee) >> Take(Lift(3))

    @query department.employee.drop(3)
    #-> Get(:department) >> Get(:employee) >> Drop(Lift(3))

### `Is0to1`, `Is0toN`, `Is1to1`, `Is1toN`

The `Is1to1` query asserts that the input exists and is singular.

    Q = It.department >>
        Take(1) >>
        Is1to1
    #-> It.department >> Take(1) >> Is1to1

    chicago[Q]
    #=>
    │ department                                                          │
    │ name    employee{name,position,salary,rate}                         │
    ┼─────────────────────────────────────────────────────────────────────┼
    │ POLICE  JEFFERY A, SERGEANT, 101442, missing; NANCY A, POLICE OFFIC…│
    =#

    shape(chicago[Q])
    #=>
    BlockOf(⋮
            x1to1) |>
    IsLabeled(:department)
    =#

This operation can also be used in a combinator form.

    Q >>= Is1to1(It.employee >> Take(1))
    #-> It.department >> Take(1) >> Is1to1 >> Is1to1(It.employee >> Take(1))

    chicago[Q]
    #=>
    │ employee                          │
    │ name       position  salary  rate │
    ┼───────────────────────────────────┼
    │ JEFFERY A  SERGEANT  101442       │
    =#

Other cardinality constraints can also be asserted.

    chicago[It.department.name >> Take(1) >> Is0to1] |> shape
    #-> BlockOf(String, x0to1) |> IsLabeled(:name)

    chicago[It.department.name >> Take(1) >> Is0toN] |> shape
    #-> BlockOf(String) |> IsLabeled(:name)

    chicago[It.department.name >> Take(1) >> Is1toN] |> shape
    #-> BlockOf(String, x1toN) |> IsLabeled(:name)

    chicago[Is0to1(It.department.name >> Take(1))] |> shape
    #-> BlockOf(String, x0to1) |> IsLabeled(:name)

    chicago[Is0toN(It.department.name >> Take(1))] |> shape
    #-> BlockOf(String) |> IsLabeled(:name)

    chicago[Is1toN(It.department.name >> Take(1))] |> shape
    #-> BlockOf(String, x1toN) |> IsLabeled(:name)

When the constraint is not satisfied, an error is reported.

    Q = It.department >> Record(It.name, It.employee >> Is1to1)

    chicago[Q]
    #-> ERROR: "employee": expected a singular value, relative to "department"

These operations could also be used to widen the cardinality constraint.

    Q = Count(It.department) >> Is1toN

    chicago[Q]
    #=>
    ──┼───┼
    1 │ 3 │
    =#

    shape(chicago[Q])
    #-> BlockOf(Int64, x1toN)

In `@query` notation, these operations are written as `is0to1()`, `is0toN()`,
`is1to1()`, `is1toN()`.

    @query chicago department.name.take(1).is1to1()
    #=>
    │ name   │
    ┼────────┼
    │ POLICE │
    =#

    @query chicago is1to1(department.name.take(1))
    #=>
    │ name   │
    ┼────────┼
    │ POLICE │
    =#

    shape(@query chicago department.name.take(1).is0to1())
    #-> BlockOf(String, x0to1) |> IsLabeled(:name)

    shape(@query chicago department.name.take(1).is0toN())
    #-> BlockOf(String) |> IsLabeled(:name)

    shape(@query chicago department.name.take(1).is1toN())
    #-> BlockOf(String, x1toN) |> IsLabeled(:name)

    shape(@query chicago is0to1(department.name.take(1)))
    #-> BlockOf(String, x0to1) |> IsLabeled(:name)

    shape(@query chicago is0toN(department.name.take(1)))
    #-> BlockOf(String) |> IsLabeled(:name)

    shape(@query chicago is1toN(department.name.take(1)))
    #-> BlockOf(String, x1toN) |> IsLabeled(:name)

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

In `@query` notation, `Unique(X)` is written as `unique(X)`.

    @query department{name, unique(employee.position)}
    #=>
    Get(:department) >> Record(Get(:name),
                               Unique(Get(:employee) >> Get(:position)))
    =#

The aggregate query form of `Unique` is written as `unique()`.

    @query department.employee.position.unique()
    #=>
    Get(:department) >> Get(:employee) >> Get(:position) >> Then(Unique)
    =#

We use the `Group` combinator to group the input by the given key.

    Q = It.department.employee >>
        Group(It.position)
    #-> It.department.employee >> Group(It.position)

    chicago[Q]
    #=>
      │ position              employee{name,position,salary,rate}         │
    ──┼───────────────────────────────────────────────────────────────────┼
    1 │ CROSSING GUARD        LAKENYA A, CROSSING GUARD, missing, 17.68; …│
    2 │ FIRE ENGINEER-EMT     JAMES A, FIRE ENGINEER-EMT, 103350, missing │
    3 │ FIREFIGHTER-EMT       DANIEL A, FIREFIGHTER-EMT, 95484, missing; …│
    4 │ POLICE CADET          ALBA M, POLICE CADET, missing, 9.46         │
    5 │ POLICE OFFICER        NANCY A, POLICE OFFICER, 80016, missing; AN…│
    6 │ SERGEANT              JEFFERY A, SERGEANT, 101442, missing        │
    7 │ TRAFFIC CONTROL AIDE  BRENDA B, TRAFFIC CONTROL AIDE, 64392, miss…│
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

In `@query` notation, we write `group()`.

    @query begin
        department
        group(size => count(employee))
        {size, count => count(department)}
    end
    #=>
    Get(:department) >>
    Group(Count(Get(:employee)) >> Label(:size)) >>
    Record(Get(:size), Count(Get(:department)) >> Label(:count))
    =#

