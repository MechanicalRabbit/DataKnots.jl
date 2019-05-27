# Overview

DataKnots is a toolkit for representing and querying complex
structured data. It is designed for data analysts and domain
experts (e.g. accountants, engineers, clinicians) who need to
build and share domain-specific queries. This overview introduces
DataKnots and its query algebra.

## Answering an Inquiry

To focus our attention, let's discuss a particular inquiry: *Which
City of Chicago employees are paid more than the average for their
department?*

Let's use a tiny subset of public data from the City of Chicago.
It includes employees and their annual salary.

    using CSV

    chicago_csv_data = """
        name,department,position,salary
        "ANTHONY A","POLICE","POLICE OFFICER",72510
        "DANIEL A","FIRE","FIRE FIGHTER-EMT",95484
        "JAMES A","FIRE","FIRE ENGINEER-EMT",103350
        "JEFFERY A","POLICE","SERGEANT",101442
        "NANCY A","POLICE","POLICE OFFICER",80016
        "ROBERT K","FIRE","FIRE FIGHTER-EMT",103272
        """ |> IOBuffer |> CSV.File

To query this `chicago_csv_data`, we convert this tabular data to
a `DataKnot`, or just *knot*, and give it a label `employee`.

    using DataKnots

    chicago = DataKnot(:employee => chicago_csv_data)

Then, to answer this inquiry, we query `chicago` as follows.

    using Statistics: mean

    @query chicago begin
        employee
        group(department)
        keep(mean_salary => mean(employee.salary))
        employee
        filter(salary > mean_salary)
    end
    #=>
      │ employee                                         │
      │ name       department  position           salary │
    ──┼──────────────────────────────────────────────────┼
    1 │ JAMES A    FIRE        FIRE ENGINEER-EMT  103350 │
    2 │ ROBERT K   FIRE        FIRE FIGHTER-EMT   103272 │
    3 │ JEFFERY A  POLICE      SERGEANT           101442 │
    =#

Though this overview we will work towards reconstructing this
query, showing how an analyst could explore data and independently
arrive at the query above.

## Basic Queries

DataKnots implements an algebra of queries. This algebra's
elements, or *queries*, represent relationships among class
entities and datatypes. Nouns, such as `employee`, `department`,
and `salary`, are *query primitives*.

Let's query the `chicago` knot to list `employee` records. The
`@query` macro provides a convenient notation to do this.

    @query chicago employee
    #=>
      │ employee                                         │
      │ name       department  position           salary │
    ──┼──────────────────────────────────────────────────┼
    1 │ ANTHONY A  POLICE      POLICE OFFICER      72510 │
    2 │ DANIEL A   FIRE        FIRE FIGHTER-EMT    95484 │
    3 │ JAMES A    FIRE        FIRE ENGINEER-EMT  103350 │
    4 │ JEFFERY A  POLICE      SERGEANT           101442 │
    5 │ NANCY A    POLICE      POLICE OFFICER      80016 │
    6 │ ROBERT K   FIRE        FIRE FIGHTER-EMT   103272 │
    =#

Verbs, such as `group`, `keep`, `mean`, and `filter` are *query
combinators*. Combinators build new queries from existing ones.
For example, `count` is a combinator.

    @query chicago count(employee)
    #=>
    ┼───┼
    │ 6 │
    =#

Query *composition* (`.`) is also a combinator, it applies the
output of one query as the input to another. The query
`employee.name` lists all employee names.

    @query chicago employee.name
    #=>
      │ name      │
    ──┼───────────┼
    1 │ ANTHONY A │
    2 │ DANIEL A  │
    3 │ JAMES A   │
    4 │ JEFFERY A │
    5 │ NANCY A   │
    6 │ ROBERT K  │
    =#

Within a multi-line macro block, each individual statement is
composed with its predecessor. Hence, we could write the query
above without the period delimiter.

    @query chicago begin
        employee
        name
    end

Often it's helpful to see the combined output from correlated
queries. The *record* combinator, which is delimited with a pair
of curly braces `{}`, is used to build queries that produce
parallel results.

    @query chicago employee{name, salary}
    #=>
      │ employee          │
      │ name       salary │
    ──┼───────────────────┼
    1 │ ANTHONY A   72510 │
    2 │ DANIEL A    95484 │
    3 │ JAMES A    103350 │
    4 │ JEFFERY A  101442 │
    5 │ NANCY A     80016 │
    6 │ ROBERT K   103272 │
    =#

Within a `@query` macro, constants, such as `100_000` are query
primitives. Functions, such as `titlecase`, and operators, such as
greater-than (`>`), are treated as query combinators. We can label
each expression with the pair syntax (`=>`).

    @query chicago begin
        employee
        {name => titlecase(name), highly_paid => salary > 100_000}
    end
    #=>
      │ employee               │
      │ name       highly_paid │
    ──┼────────────────────────┼
    1 │ Anthony A        false │
    2 │ Daniel A         false │
    3 │ James A           true │
    4 │ Jeffery A         true │
    5 │ Nancy A          false │
    6 │ Robert K          true │
    =#

Combining queries is generative. Since we know that `salary >
100_000` is a query, so is `filter(salary > 100_000)`.

    @query chicago employee.filter(salary > 100_000)
    #=>
      │ employee                                         │
      │ name       department  position           salary │
    ──┼──────────────────────────────────────────────────┼
    1 │ JAMES A    FIRE        FIRE ENGINEER-EMT  103350 │
    2 │ JEFFERY A  POLICE      SERGEANT           101442 │
    3 │ ROBERT K   FIRE        FIRE FIGHTER-EMT   103272 │
    =#

In this section, we have built a query that produces
highly-compensated employees. More broadly, we've demonstrated how
an algebra of queries permits us to combine previously proven
queries in an intuitive way.

Before moving on to the original inquiry, we need to discuss how
queries see their input.

## What is a DataKnot?

Input and output of queries are serialized as `DataKnot` objects.
A DataKnot is a container that stores a hierarchy of labeled
elements, where each element is either a scalar value, such as an
integer or a string, or a collection of nested elements.

Our `chicago` knot is a hierarchy of three levels: a single
unlabeled root (shown with a `#`), branch level of `employee`
elements, and leaf elements `name`, `department`, etc.

```literal
    1-element DataKnot:
      #:
        employee:
          name: "ANTHONY A"
          department: "POLICE"
          position: "POLICE OFFICER"
          salary: 72510
        employee:
          name: "DANIEL A"
          department: "FIRE"
          position: "FIRE FIGHTER-EMT"
          salary: 95484
        ⋮
```

The structure of a DataKnot is called its *shape* and can be
visualized using `show(::DataKnot, as=:shape)`.

    show(as=:shape, chicago)
    #=>
    1-element DataKnot:
      #               1:1
      └╴employee      0:N
        ├╴name        String
        ├╴department  String
        ├╴position    String
        └╴salary      Int64
    =#

When we `show` a knot, its hierarchy is projected to a tabular
display. For `chicago`, the root element gets its own row with
`employee` elements packed into a single cell: each `employee` is
delimited by a semi-colon; and attribute values are separated by a
comma. For packed cells, such as `employee`, the header shows the
subordinate fields within a pair of curly braces.

    chicago
    #=>
    │ employee{name,department,position,salary}                                   │
    ┼─────────────────────────────────────────────────────────────────────────────┼
    │ ANTHONY A, POLICE, POLICE OFFICER, 72510; DANIEL A, FIRE, FIRE FIGHTER-EMT,…│
    =#

We could contrast this display with the tabular display of the
knot created by the query `employee{name, salary}`.

    @query chicago employee{name, salary}
    #=>
      │ employee          │
      │ name       salary │
    ──┼───────────────────┼
    1 │ ANTHONY A   72510 │
    2 │ DANIEL A    95484 │
    3 │ JAMES A    103350 │
    4 │ JEFFERY A  101442 │
    5 │ NANCY A     80016 │
    6 │ ROBERT K   103272 │
    =#

This particular output knot has a 2-level hierarchy, where the top
level, labeled `employee`, is plural.

    show(as=:shape, @query chicago employee{name, salary})
    #=>
    6-element DataKnot:
      employee  0:N
      ├╴name    1:1 × String
      └╴salary  1:1 × Int64
    =#

In the next section, we show how these hierarchies can be created
and collapsed.

## Hierarchical Transformations

DataKnots' combinators implement hierarchical transformations.
Summary combinators, such as `count`, collapse a subtree into a
single value. For example, we can compute average salary across
employees with `mean(employee.salary)`.

    using Statistics: mean

    @query chicago begin
        mean_salary => mean(employee.salary)
    end
    #=>
    │ mean_salary │
    ┼─────────────┼
    │     92679.0 │
    =#

The `group` combinator introduces a new level in the hierarchy by
constructing grouping records for each unique element produced by
its argument. For example, we could `group` employees by
`department`.

    @query chicago employee.group(department)
    #=>
      │ department  employee{name,department,position,salary}                     │
    ──┼───────────────────────────────────────────────────────────────────────────┼
    1 │ FIRE        DANIEL A, FIRE, FIRE FIGHTER-EMT, 95484; JAMES A, FIRE, FIRE …│
    2 │ POLICE      ANTHONY A, POLICE, POLICE OFFICER, 72510; JEFFERY A, POLICE, …│
    =#

This output is a different hierarchy than the `chicago` knot.
Unique `department` elements are listed with correlated `employee`
elements at the same hierarchical level.

    show(as=:shape, @query chicago employee.group(department))
    #=>
    2-element DataKnot:
      #               0:N
      ├╴department    1:1 × String
      └╴employee      1:N
        ├╴name        String
        ├╴department  String
        ├╴position    String
        └╴salary      Int64
    =#

Once constructed, grouping records can be used as any other input.
In this next query, we show salaries of employees by department.

    @query chicago begin
        employee
        group(department)
        {department, employee.salary}
    end
    #=>
      │ department  salary                │
    ──┼───────────────────────────────────┼
    1 │ FIRE        95484; 103350; 103272 │
    2 │ POLICE      72510; 101442; 80016  │
    =#

We can use summary operations relative to grouping records. In
this next example, `mean(employee.salary)` is computed for each
department, rather than across all employees.

    @query chicago begin
        employee
        group(department)
        {department, mean_salary => mean(employee.salary)}
    end
    #=>
      │ department  mean_salary │
    ──┼─────────────────────────┼
    1 │ FIRE           100702.0 │
    2 │ POLICE          84656.0 │
    =#

In this section, we have built a query that computes the average
employee compensation for each department. Further, we've shown
how `group` is used to transform hierarchies. Finally, we've
demonstrated that grouping and summary combinators are
independent, yet work fluidly together.

We're close to answering our original inquiry. We've built a query
that filters employees. We've built a query that produces average
salary by department. We need only connect these queries.

## Contextual Operations

DataKnots' queries are interpreted contextually, relative to the
input that they receive. We've seen this earlier: depending where
it is placed, `mean(employee.salary)` can produce either the
average salary over the entire dataset, or averages within each
department.

For our inquiry, we need to compare each employee's salary with
the the average salary. However, we cannot evaluate both `salary`
and `mean_salary` in the same context.

    @query chicago begin
        employee
        {name, salary, mean_salary => mean(employee.salary)}
    end
    #-> ERROR: cannot find "employee" ⋮

To evaluate an expression in one context and then use its value in
a different context, we could use the `keep` combinator. This next
query computes `mean_salary` relative to the entire dataset, and
then displays this value in the context of each employee.

    @query chicago begin
        keep(mean_salary => mean(employee.salary))
        employee
        {name, salary, mean_salary}
    end
    #=>
      │ employee                       │
      │ name       salary  mean_salary │
    ──┼────────────────────────────────┼
    1 │ ANTHONY A   72510      92679.0 │
    2 │ DANIEL A    95484      92679.0 │
    3 │ JAMES A    103350      92679.0 │
    4 │ JEFFERY A  101442      92679.0 │
    5 │ NANCY A     80016      92679.0 │
    6 │ ROBERT K   103272      92679.0 │
    =#

However, the inquiry asks us to use average salary *by department*.
This can be done by composing `employee.group(department)` with
the previous query.

    @query chicago begin
        employee
        group(department)
        keep(mean_salary => mean(employee.salary))
        employee
        {name, salary, mean_salary}
    end
    #=>
      │ employee                       │
      │ name       salary  mean_salary │
    ──┼────────────────────────────────┼
    1 │ DANIEL A    95484     100702.0 │
    2 │ JAMES A    103350     100702.0 │
    3 │ ROBERT K   103272     100702.0 │
    4 │ ANTHONY A   72510      84656.0 │
    5 │ JEFFERY A  101442      84656.0 │
    6 │ NANCY A     80016      84656.0 │
    =#

We can then answer our initial inquiry, *which employees are
paid more than the average for their department?*

    @query chicago begin
        employee
        group(department)
        keep(mean_salary => mean(employee.salary))
        employee
        filter(salary > mean_salary)
    end
    #=>
      │ employee                                         │
      │ name       department  position           salary │
    ──┼──────────────────────────────────────────────────┼
    1 │ JAMES A    FIRE        FIRE ENGINEER-EMT  103350 │
    2 │ ROBERT K   FIRE        FIRE FIGHTER-EMT   103272 │
    3 │ JEFFERY A  POLICE      SERGEANT           101442 │
    =#

In this section, we've completed our query. The remainder of this
overview will address specific topics, such as aggregation,
joining data, cardinality, among others.

