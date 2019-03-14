# DataKnots Tutorial

DataKnots is an embedded query language designed so that
accidental programmers could more easily solve complex data
analysis tasks.

This tutorial shows how typical query operations can be performed
upon a simplified in-memory dataset. Currently DataKnots does not
include methods to read/write common data formats (such as CSV or
DataFrames). Feedback and contributions are welcome.

## Getting Started

Consider a tiny cross-section of public data from Chicago,
represented as nested `NamedTuple` and `Vector` objects.

    chicago_data =
      (department = [
        (name = "POLICE",
         employee = [
          (name = "JEFFERY A", position = "SERGEANT", salary = 101442),
          (name = "NANCY A", position = "POLICE OFFICER", salary = 80016)]),
        (name = "FIRE",
         employee = [
          (name = "DANIEL A", position = "FIRE FIGHTER-EMT", salary = 95484)])],)

In this hierarchical Chicago dataset, the root is a `NamedTuple`
with a field `department`, which is a `Vector` of department
records, and so on.

To query this dataset, we convert it into a `DataKnot`, or *knot*.

    using DataKnots
    chicago = DataKnot(chicago_data)

### Our First Query

Let's say we want to return the list of department names from this
dataset. We query the `chicago` knot using Julia's index notation
with `It.department.name`.

    department_names = chicago[It.department.name]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

The output, `department_names`, is also a DataKnot. The content of
this output knot could be accessed via `get` function.

    get(department_names)
    #-> ["POLICE", "FIRE"]

### Navigation

In DataKnot queries, `It` means "the current input". The dotted
notation lets one navigate a hierarchical dataset. Let's continue
our dataset exploration by listing employee names.

    chicago[It.department.employee.name]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    2 │ NANCY A   │
    3 │ DANIEL A  │
    =#

Navigation context matters. For example, `employee` tuples are not
directly accessible from the root of the dataset. When a label
can't be found, an appropriate error message is displayed.

    chicago[It.employee]
    #-> ERROR: cannot find "employee" ⋮

Instead, `employee` tuples can be queried by navigating though
`department` tuples. When tuples are returned, they are displayed
as a table.

    chicago[It.department.employee]
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ NANCY A    POLICE OFFICER     80016 │
    3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

Notice that nested vectors traversed during navigation are
flattened into a single output vector.

### Composition & Identity

Dotted navigation, such as `It.department.name`, is a syntax
shorthand for the `Get()` primitive together with query
composition (`>>`).

    chicago[Get(:department) >> Get(:name)]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

The `Get()` primitive returns values that match a given label.
Query composition (`>>`) chains two queries serially, with the
output of its first query as input to the second.

    chicago[Get(:department) >> Get(:employee)]
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ NANCY A    POLICE OFFICER     80016 │
    3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

The `It` query simply reproduces its input, which makes it the
identity with respect to composition (`>>`). Hence, `It` can be
woven into any composition without changing the result.

    chicago[It >> Get(:department) >> Get(:name)]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

This motivates our clever use of `It` as a syntax shorthand.

    chicago[It.department.name]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

In DataKnots, queries are either *primitives*, such as `Get` and
`It`, or built from other queries with *combinators*, such as
composition (`>>`). Let's explore some other combinators.

### Context & Counting

To count the number of departments in this `chicago` dataset we
write the query `Count(It.department)`. Observe that the argument
provided to `Count()`, `It.department`, is itself a query.

    chicago[Count(It.department)]
    #=>
    │ It │
    ┼────┼
    │  2 │
    =#

Using query composition (`>>`), we can perform `Count` in a nested
context. For this next example, let's count `employee` records
within each `department`.

    chicago[It.department >> Count(It.employee)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  1 │
    =#

In this output, we see that one department has `2` employees,
while the other has only `1`.

### Record Construction

Let's improve the previous query by including each department's
name alongside employee counts. This can be done by using the
`Record` combinator.

    chicago[
        It.department >>
        Record(It.name,
               Count(It.employee))]
    #=>
      │ department │
      │ name    #B │
    ──┼────────────┼
    1 │ POLICE   2 │
    2 │ FIRE     1 │
    =#

To label a record field we use Julia's `Pair` syntax, (`=>`).

    chicago[
        It.department >>
        Record(It.name,
               :employee_count =>
                   Count(It.employee))]
    #=>
      │ department             │
      │ name    employee_count │
    ──┼────────────────────────┼
    1 │ POLICE               2 │
    2 │ FIRE                 1 │
    =#

This is syntax shorthand for the `Label` primitive.

    chicago[
        It.department >>
        Record(It.name,
               Count(It.employee) >>
               Label(:employee_count))]
    #=>
      │ department             │
      │ name    employee_count │
    ──┼────────────────────────┼
    1 │ POLICE               2 │
    2 │ FIRE                 1 │
    =#

Records can be nested. The following listing includes, for each
department, employees' name and salary.

    chicago[
        It.department >>
        Record(It.name,
               It.employee >>
               Record(It.name,
                      It.salary))]
    #=>
      │ department                                │
      │ name    employee                          │
    ──┼───────────────────────────────────────────┼
    1 │ POLICE  JEFFERY A, 101442; NANCY A, 80016 │
    2 │ FIRE    DANIEL A, 95484                   │
    =#

In this output, commas separate tuple fields and semi-colons
separate vector elements.

### Reusable Queries

Queries can be reused. Let's define `EmployeeCount` to be a query
that computes the number of employees in a department.

    EmployeeCount =
        :employee_count =>
            Count(It.employee)

This query can be used in different contexts.

    chicago[Max(It.department >> EmployeeCount)]
    #=>
    │ It │
    ┼────┼
    │  2 │
    =#

    chicago[
        It.department >>
        Record(It.name,
               EmployeeCount)]
    #=>
      │ department             │
      │ name    employee_count │
    ──┼────────────────────────┼
    1 │ POLICE               2 │
    2 │ FIRE                 1 │
    =#

### Filtering Data

Let's extend the previous query to only show departments with more
than one employee. This can be done using the `Filter` combinator.

    chicago[
        It.department >>
        Record(It.name, EmployeeCount) >>
        Filter(It.employee_count .> 1)]
    #=>
      │ department             │
      │ name    employee_count │
    ──┼────────────────────────┼
    1 │ POLICE               2 │
    =#

To use regular operators in query expressions, we need to use
broadcasting notation, such as `.>` rather than `>`. Forgetting
the period is an easy mistake to make.

    chicago[
        It.department >>
        Record(It.name, EmployeeCount) >>
        Filter(It.employee_count > 1)]
    #=>
    ERROR: MethodError: no method matching isless(::Int, ::DataKnots.Navigation)
    ⋮
    =#

### Incremental Composition

Combinators let us construct queries incrementally. Let's explore
our Chicago data starting with a list of employees.

    Q = It.department.employee

    chicago[Q]
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ NANCY A    POLICE OFFICER     80016 │
    3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

Let's extend this query to show if the salary is over 100k.
Notice how the query definition is tracked.

    GT100K = :gt100k => It.salary .> 100000

    Q >>= Record(It.name, It.salary, GT100K)
    #=>
    It.department.employee >>
    Record(It.name, It.salary, :gt100k => It.salary .> 100000)
    =#

Let's run `Q` again.

    chicago[Q]
    #=>
      │ employee                  │
      │ name       salary  gt100k │
    ──┼───────────────────────────┼
    1 │ JEFFERY A  101442    true │
    2 │ NANCY A     80016   false │
    3 │ DANIEL A    95484   false │
    =#

We can now filter the dataset to include only high-paid employees.

    Q >>= Filter(It.gt100k)
    #=>
    It.department.employee >>
    Record(It.name, It.salary, :gt100k => It.salary .> 100000) >>
    Filter(It.gt100k)
    =#

Let's run `Q` again.

    chicago[Q]
    #=>
      │ employee                  │
      │ name       salary  gt100k │
    ──┼───────────────────────────┼
    1 │ JEFFERY A  101442    true │
    =#

Well-tested queries may benefit from a `Tag` so that their
definitions are suppressed in larger compositions.

    HighlyCompensated = Tag(:HighlyCompensated, Q)
    #-> HighlyCompensated

    chicago[HighlyCompensated]
    #=>
      │ employee                  │
      │ name       salary  gt100k │
    ──┼───────────────────────────┼
    1 │ JEFFERY A  101442    true │
    =#

This tagging can make subsequent compositions easier to read.

    Q = HighlyCompensated >> It.name
    #=>
    HighlyCompensated >> It.name
    =#

    chicago[Q]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    =#

### Accessing Data

Given any `DataKnot`, its content can be accessed via `get`. For
scalar outputs, `get` returns a typed Julia value.

    get(chicago[Count(It.department)])
    #-> 2

For simple lists, `get` returns a typed `Vector`.

    get(chicago[It.department.employee.name])
    #-> ["JEFFERY A", "NANCY A", "DANIEL A"]

For more complex outputs, `get` may return a `@VectorTree`, a
column-oriented storage for our `DataKnot` system.

    query = It.department >>
            Record(It.name,
                   :employee_count => Count(It.employee))
    vt = get(chicago[query])
    display(vt)
    #=>
    @VectorTree of 2 × (name = (1:1) × String, employee_count = (1:1) × Int):
     (name = "POLICE", employee_count = 2)
     (name = "FIRE", employee_count = 1)
    =#

The `@VectorTree` datatype is considered an implemention detail,
upon which specific input/output converters will be written.

## Query Combinators

We've seen how DataKnots' queries are assembled algebraically:
they either come from a set of atomic *primitives* or are built
from other queries using *combinators*.

Query primitives include the identity (`It`), constant values
(like `100000`), and data navigation via `Get(:Symbol)`. Besides
query composition (`>>`), query combinators include `Count()`,
`Record()`, `Label()`, `Filter()`, `Tag()` and broadcast operators
such as equality `(.==)` and greater than `(.>)`.

This next section describes additional primitives and combinators
included with DataKnots' core library.

### Aggregate queries

Aggregates, such as `Count` may be used as a query primitive,
providing incremental refinement without additional nesting. In
this next example, `Count` takes an input of filtered employees,
and returns the size of its input.

    chicago[
        It.department.employee >>
        Filter(It.salary .> 100000) >>
        Count]
    #=>
    │ It │
    ┼────┼
    │  1 │
    =#

Aggregate query primitives operate contextually. In the following
example, `Count` is performed relative to each department.

    chicago[
        It.department >>
        Record(
            It.name,
            :over_100k =>
                It.employee >>
                Filter(It.salary .> 100000) >>
                Count)]
    #=>
      │ department        │
      │ name    over_100k │
    ──┼───────────────────┼
    1 │ POLICE          1 │
    2 │ FIRE            0 │
    =#

Note that in the query `It.department.employee >> Count`, the
`Count` primitive aggregates the number of employees across all
departments. This doesn't change even if we add parentheses:

    chicago[It.department >> (It.employee >> Count)]
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#

To count employees in *each* department, we use `Each()`. This
combinator applies its input *elementwise* to its argument.
Therefore, we get two counts, one for each department.

    chicago[It.department >> Each(It.employee >> Count)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  1 │
    =#

Naturally, we could use the `Count()` query combinator to get the
same result.

    chicago[It.department >> Count(It.employee)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  1 │
    =#

Which form of an aggregate to use depends upon what is
notationally convenient. For incremental construction, being able
to simply append `>> Count` is often very helpful.

    our_query = It.department.employee
    chicago[our_query >> Count]
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#

We could then refine the query, and run the exact same command.

    our_query >>= Filter(It.salary .> 100000)
    chicago[our_query >> Count]
    #=>
    │ It │
    ┼────┼
    │  1 │
    =#

### Function broadcasting

Besides operators, such as greater than (`.>`), arbitrary
functions can also be used as a query combinator with the
broadcast notation. Let's define a function to extract an
employee's first name.

    fname(x) = titlecase(split(x)[1])
    fname("NANCY A")
    #-> "Nancy"

This `fname` function can then be used within a query expression
to return first names of all employees.

    chicago[
        It.department.employee >>
        fname.(It.name) >>
        Label(:first_name)]
    #=>
      │ first_name │
    ──┼────────────┼
    1 │ Jeffery    │
    2 │ Nancy      │
    3 │ Daniel     │
    =#

Aggregate Julia functions, such as `mean`, can also be used.

    using Statistics: mean

    chicago[
        It.department >>
        Record(
            It.name,
            :mean_salary => mean.(It.employee.salary))]
    #=>
      │ department          │
      │ name    mean_salary │
    ──┼─────────────────────┼
    1 │ POLICE      90729.0 │
    2 │ FIRE        95484.0 │
    =#

The conversion of a function into a combinator is accomplished by
`Lift`, as documented in the reference. How a lifted function is
treated as a query combinator depends upon that function's input
and output signature.

### Keeping Values

Suppose we'd like a list of employee names together with the
corresponding department name. The naive approach won't work,
because `department` is not a label in the context of an employee.

    chicago[
        It.department >>
        It.employee >>
        Record(It.name, It.department.name)]
    #-> ERROR: cannot find "department" ⋮

This can be overcome by using `Keep` to label an expression's
result, so that it is available within subsequent computations.

    chicago[
        It.department >>
        Keep(:dept_name => It.name) >>
        It.employee >>
        Record(It.name, It.dept_name)]
    #=>
      │ employee             │
      │ name       dept_name │
    ──┼──────────────────────┼
    1 │ JEFFERY A  POLICE    │
    2 │ NANCY A    POLICE    │
    3 │ DANIEL A   FIRE      │
    =#

This pattern also emerges with aggregate computations which need
to be done in a parent scope. For example, let's compute employees
with a higher than average salary for their department.

    using Statistics: mean
    chicago[
        It.department >>
        Keep(:mean_salary => mean.(It.employee.salary)) >>
        It.employee >>
        Filter(It.salary .> It.mean_salary)]
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┼
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

In this last query, `mean` simply can't be moved into `Filter`'s
argument, since this argument is evaluated for *each* employee.

### Paging Data

Sometimes query results can be quite large. In this case it's
helpful to `Take` or `Drop` items from the input stream. Let's
start by listing all 3 employees of our toy database.

    Employee = It.department.employee
    chicago[Employee]
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ NANCY A    POLICE OFFICER     80016 │
    3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

To return up to the 2nd employee record, we use `Take`.

    chicago[Employee >> Take(2)]
    #=>
      │ employee                          │
      │ name       position        salary │
    ──┼───────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT        101442 │
    2 │ NANCY A    POLICE OFFICER   80016 │
    =#

A negative index can be used, counting records from the end of the
query's input. So, to return up to, but not including, the very
last item in the stream, we could write:

    chicago[Employee >> Take(-1)]
    #=>
      │ employee                          │
      │ name       position        salary │
    ──┼───────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT        101442 │
    2 │ NANCY A    POLICE OFFICER   80016 │
    =#

To return the last record of the query's input, we could `Drop` up
to the last item in the stream:

    chicago[Employee >> Drop(-1)]
    #=>
      │ employee                           │
      │ name      position          salary │
    ──┼────────────────────────────────────┼
    1 │ DANIEL A  FIRE FIGHTER-EMT   95484 │
    =#

To return the 1st half of the employees in the database, we could
use `Take` with an argument that computes how many to take.

    chicago[Employee >> Take(Count(Employee) .÷ 2)]
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┼
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

### Query Parameters

Julia's index notation permits named parameters. Each argument
passed via named parameter is converted into a `DataKnot` and then
made available as a label accessible anywhere in the query.

    chicago[AMT=100000, It.AMT]
    #=>
    │ AMT    │
    ┼────────┼
    │ 100000 │
    =#

This technique permits complex queries to be re-used with
different argument values. By convention we capitalize parameters
so they standout from regular data labels.

    PaidOverAmt =
        It.department >>
        It.employee >>
        Filter(It.salary .> It.AMT) >>
        It.name

    chicago[PaidOverAmt, AMT=100000]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    =#

What if we want to return employee names who have a greater than
average salary? This average could be computed first.

    using Statistics
    mean_salary = chicago[mean.(It.department.employee.salary)]
    #=>
    │ It      │
    ┼─────────┼
    │ 92314.0 │
    =#

Then, this value could be used as a query parameter.

    chicago[PaidOverAmt, AMT=mean_salary]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    2 │ DANIEL A  │
    =#

While this approach works, it performs composition outside of the
query language. If the dataset changes, a new `mean_salary` would
have to be computed before the query above could be performed.

### Parameterized Queries

Suppose we want parameterized query that could take other queries
as arguments. Using `Given`, we could build a query that returns
`employee` records with `salary` over a given amount.

    EmployeesOver(X) =
        Given(:AMT => X,
            It.department >>
            It.employee >>
            Filter(It.salary .> It.AMT))

    chicago[EmployeesOver(100000)]
    #=>
      │ employee                    │
      │ name       position  salary │
    ──┼─────────────────────────────┼
    1 │ JEFFERY A  SERGEANT  101442 │
    =#

But what if we wished to find employees with higher than average
salary? Let's compute the average value as a query.

    using Statistics: mean
    AvgSalary = mean.(It.department.employee.salary)

    chicago[AvgSalary]
    #=>
    │ It      │
    ┼─────────┼
    │ 92314.0 │
    =#

We could then combine these two queries.

    chicago[EmployeesOver(AvgSalary)]
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

Note that this combined expression is yet another query that could
be further refined.

    chicago[EmployeesOver(AvgSalary) >> It.name]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    2 │ DANIEL A  │
    =#

Unlike its cousin `Having`, `Given` doesn't leak its definitions.
Specifically, `It.amt` is not available outside `EmployeesOver()`.

    chicago[EmployeesOver(AvgSalary) >> It.amt]
    #-> ERROR: cannot find "amt" ⋮

### Aggregate Combinators

There are other aggregate combinators, such as `Min`, `Max`, and
`Sum`. They could be used to create a statistical measure.

    using Statistics: mean
    Stats(X) =
        Record(
            :count => Count(X),
            :mean => floor.(Int, mean.(X)),
            :min => Min(X),
            :max => Max(X),
            :sum => Sum(X))

    chicago[
        :salary_stats_for_all_employees =>
            Stats(It.department.employee.salary)]
    #=>
    │ salary_stats_for_all_employees      │
    │ count  mean   min    max     sum    │
    ┼─────────────────────────────────────┼
    │     3  92314  80016  101442  276942 │
    =#

These statistics could be computed for each department.

    chicago[
        It.department >>
        Record(
            It.name,
            :salary_stats => Stats(It.employee.salary))]
    #=>
      │ department                              │
      │ name    salary_stats                    │
    ──┼─────────────────────────────────────────┼
    1 │ POLICE  2, 90729, 80016, 101442, 181458 │
    2 │ FIRE    1, 95484, 95484, 95484, 95484   │
    =#

To inspect the definition of `Stats` you could build a query,
`Stats(It)`, and show it.

    Stats(It)
    #=>
    Record(:count => Count(It),
           :mean => floor.(Int, mean.(It)),
           :min => Min(It),
           :max => Max(It),
           :sum => Sum(It))
    =#

Parameterized queries, such as `Stats`, can also be tagged. Then,
when they are displayed with an argument, the definition is
suppressed.

    Stats(X) =
      Tag(:Stats, (X,),
        Record(
            :count => Count(X),
            :mean => floor.(Int, mean.(X)),
            :min => Min(X),
            :max => Max(X),
            :sum => Sum(X)))
    Stats(It)
    #-> Stats(It)

Suppressing the definition of parameterized queries such as
`Stats` makes the incremental composition easier to follow.

    MyQuery = It.department
    MyQuery >>= Stats(It.employee.salary)
    #=>
    It.department >> Stats(It.employee.salary)
    =#


