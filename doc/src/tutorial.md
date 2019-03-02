# DataKnots Tutorial

DataKnots is an embedded query language designed so that
accidental programmers could more easily solve complex data
analysis tasks. Specifically, DataKnots allows expert users to
construct friendly yet semantically consistent domain-specific
query languages having customized operations and data sources.

This tutorial is about the very basics. How mundane query
operations are performed upon an in-memory data source.

## Getting Started

Consider a tiny cross-section of public data from Chicago,
represented as nested `NamedTuple` and `Vector` objects.

    chicago_data =
      (department = [
        (name = "POLICE",
         employee = [
          (name = "JEFFERY A", position = "SERGEANT",
           salary = 101442),
          (name = "NANCY A", position = "POLICE OFFICER",
           salary = 80016)]),
        (name = "FIRE",
         employee = [
          (name = "DANIEL A", position = "FIRE FIGHTER-EMT",
           salary = 95484)])],);

In this hierarchical Chicago dataset, the root is a `NamedTuple`
with an entry `:department`, which is a `Vector` department
records, and so on. Notice that the label `name` occurs both
within the context of a department and an employee record.

To query this dataset, we convert it into a DataKnot.

    using DataKnots
    chicago = DataKnot(chicago_data)

### Our First Query

Let's say we want to query a list of department names from this
data source. We query this knot using Julia's index notation.

    department_names = chicago[It.department.name]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

The output of this query, `department_names`, is also a DataKnot.
The content of this knot could be accessed via `get` function.

    get(department_names)
    #-> ["POLICE", "FIRE"]

### Navigation

In this first query, `It` means "use the current input". The
dotted notation lets one navigate the hierarchy.

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
    #-> ERROR: cannot find employee ⋮

Instead, `employee` tuples can be queried by navigating though
`department` tuples.

    chicago[It.department.employee]
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ NANCY A    POLICE OFFICER     80016 │
    3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

Notice that nested lists traversed during navigation are flattened
into a single output.

### Composition & Identity

Dotted navigations, such as `It.department.name`, are a syntax
shorthand for the `Get()` primitive together with query
composition (`>>`).

    chicago[Get(:department) >> Get(:name)]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

The `Get()` query primitive reproduces contents from a named
container. Query composition `>>` merges results from nested
traversal. They can be used together creatively.

    chicago[Get(:department) >> Get(:employee)]
    #=>
      │ employee                            │
      │ name       position          salary │
    ──┼─────────────────────────────────────┼
    1 │ JEFFERY A  SERGEANT          101442 │
    2 │ NANCY A    POLICE OFFICER     80016 │
    3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │
    =#

In this query algebra, `It` is the identity relative to query
composition (`>>`). Since `It` can be mixed into any composition
without changing the result, we can write:

    chicago[It >> Get(:department) >> Get(:name)]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

This motivates our clever use of `It` as a syntax short hand.

    chicago[It.department.name]
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

This query, `It.department.name`, could be equivalently written
`Get(:department) >> Get(:name)`.

### Context & Counting

To return the number of departments in this Chicago dataset we
write the query `Count(It.department)`. Observe that the argument
provided to `Count()`, `It.department`, is itself a query.

    chicago[Count(It.department)]
    #=>
    │ It │
    ┼────┼
    │  2 │
    =#

Using query composition (`>>`), we can perform `Count` in a nested
context; for this next example, let's count `employee` records
within each `department`.

    chicago[It.department >> Count(It.employee)]
    #=>
      │ It │
    ──┼────┼
    1 │  2 │
    2 │  1 │
    =#

In this output we see that the 1st department, `"POLICE"`, has `2`
employees, while the 2nd, `"FIRE"` only has `1`. The occurrence of
`It` within the subordinate query `Count(It.employee)` refers to
each department individually, not to the dataset as a whole.

### Record Construction

Returning values in tandem can be done with `Record()`. Let's
improve the previous output by including each department's name
alongside employee counts.

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

Records can be nested. The following listing includes, for each
department, employee names and their salary.

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

In this nested display, commas are used to separate fields and
semi-colons separate values.

### Expressions & Output Labels

Query expressions can be named and reused. Further, the output
column of these named queries may be labeled using Julia's `Pair`
syntax (`=>`). Let's define `EmployeeCount` to be the number of
employees in a given department.

    EmployeeCount =
        :employee_count =>
            Count(It.employee)

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

Labels can be attached to an existing query using the `Label`
primitive. This form is handy for use in successive query
refinements (`>>=`).

    DeptCount = Count(It.department)
    DeptCount >>= Label(:dept_count)

    chicago[DeptCount]
    #=>
    │ dept_count │
    ┼────────────┼
    │          2 │
    =#

Besides providing a display title, labels also provide a way to
access fields within a record.

    chicago[
        Record(It, DeptCount) >>
        It.dept_count]
    #=>
    │ dept_count │
    ┼────────────┼
    │          2 │
    =#

### Filtering Data

Returning only wanted values can be done with `Filter()`. Here we
list department names who have exactly one employee.

    chicago[
        It.department >>
        Filter(EmployeeCount .== 1) >>
        Record(It.name, EmployeeCount)]
    #=>
      │ department           │
      │ name  employee_count │
    ──┼──────────────────────┼
    1 │ FIRE               1 │
    =#

In query expressions, the broadcast variant of common operators,
such as `.==`, are to be used. Forgetting the period is an easy
mistake to make and the resulting Julia language error message may
not be helpful.

    chicago[
        It.department >>
        Filter(EmployeeCount == 1) >>
        Record(It.name, EmployeeCount)]
    #=>
    ERROR: AssertionError: eltype(input) <: AbstractVector
    =#

Let's define `GT100K` to check if an employee's salary is greater
than 100K. The output of this query component is also labeled.

    GT100K =
        :gt100k =>
            It.salary .> 100000

    chicago[
        It.department.employee >>
        Record(It.name, It.salary, GT100K)]
    #=>
      │ employee                  │
      │ name       salary  gt100k │
    ──┼───────────────────────────┼
    1 │ JEFFERY A  101442    true │
    2 │ NANCY A     80016   false │
    3 │ DANIEL A    95484   false │
    =#

Since `Filter` takes a boolean valued query for an argument, we
could use `GTK100K` to filter employees.

    chicago[
        It.department.employee >>
        Filter(GT100K) >>
        It.name]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    =#

### Incremental Composition

This data discovery could have been done incrementally, with each
intermediate query being fully runnable. Let's start `our_query`
as a list of employees. We're not going to run it, but we could.

    our_query = It.department.employee
    #-> It.department.employee

Let's extend this query to compute if the salary is over 100k.
Notice how query composition is tracked for us. We could run
`our_query` also, if we wanted.

    GT100K = :gt100k => It.salary .> 100000
    our_query >>= Record(It.name, It.salary, GT100K)
    #=>
    It.department.employee >>
    Record(It.name, It.salary, :gt100k => It.salary .> 100000)
    =#

Since labeling permits direct Record access, we could further
extend `our_query` to filter unwanted rows.

    our_query >>= Filter(It.gt100k)
    #=>
    It.department.employee >>
    Record(It.name, It.salary, :gt100k => It.salary .> 100000) >>
    Filter(It.gt100k)
    =#

Let's run `our_query` against the `chicago` knot.

    chicago[our_query]
    #=>
      │ employee                  │
      │ name       salary  gt100k │
    ──┼───────────────────────────┼
    1 │ JEFFERY A  101442    true │
    =#

Well-tested queries may benefit from a `Tag` so that their
definitions are suppressed in larger compositions.

    GT100K = Tag(:GT100K, :gt100k => It.salary .> 100000)
    #-> GT100K

This tagging can make subsequent compositions easier to read, when
the definition of the named query is not being questioned.

    our_query = It.department.employee >>
                Record(It.name, It.salary, GT100K)
    #=>
    It.department.employee >> Record(It.name, It.salary, GT100K)
    =#

Notice that the tag (`:GT100K`) is distinct from the data label
(`:gt100k`), the tag names the query while the label names the
output column.

    our_query >>= Filter(It.gt100k)
    chicago[our_query]
    #=>
      │ employee                  │
      │ name       salary  gt100k │
    ──┼───────────────────────────┼
    1 │ JEFFERY A  101442    true │
    =#

For the final step of our query's incremental construction, let's
only show the employee's name that met the GT100K criteria.

    our_query >>= It.name
    chicago[our_query]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    =#

As we see, queries can be combined in series or as arguments to
make new queries. Queries can then be performed on a DataKnot to
produce a new DataKnot. Hence, the construction and performance of
a query are distinct and separate operations.

### Accessing Data

Given any `DataKnot`, its content can be accessed via `get`. For
scalar outputs, `get` returns a typed Julia value.

    get(chicago[Count(It.department)])
    #-> 2

For simple lists, `get` returns a typed `Vector`.

    get(chicago[It.department.employee.name])
    #-> ["JEFFERY A", "NANCY A", "DANIEL A"]

For more complex outputs, `get` often returns a `@VectorTree`, a
column-oriented storage for our `DataKnot` system.

    query = It.department >>
            Record(It.name,
                   :employee_count => Count(It.employee))
    vt = get(chicago[query])
    display(vt)
    #=>
    @VectorTree of 2 × (name = (1:1) × String,
                        employee_count = (1:1) × (1:1) × Int):
     (name = "POLICE", employee_count = 2)
     (name = "FIRE", employee_count = 1)
    =#

This result type can be directly used quite naturally.

    [dept[:name] for dept in vt]
    #-> ["POLICE", "FIRE"]

Or converted into a standard row-oriented vector structure.

    display(collect(vt))
    #=>
    2-element Array{NamedTuple{(:name, :employee_count),…},1}:
     (name = "POLICE", employee_count = 2)
     (name = "FIRE", employee_count = 1)
    =#

Further information about `@VectorTree` can be found in the
DataKnots reference.

## Query Combinators

We've seen how DataKnots' queries are assembled algebraically:
they either come from a set of atomic *primitives* or are built
from other queries using *combinators*. Query primitives include
the identity (`It`), constant values (like `100000`), and data
navigation via `Get(:Symbol)`. Besides composition (`>>`), query
combinators include `Count()`, `Record()`, `Label()`, `Filter()`,
`Tag()` and broadcast operators such as equality `(.==)` and
greater than `(.>)`.

This next section describes additional combinators and primitives
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

Note that in `It.department.employee >> Count`, the `Count`
primitive aggregates the number of employees across all
departments. This doesn't change even if we add parentheses:

    chicago[It.department >> (It.employee >> Count)]
    #=>
    │ It │
    ┼────┼
    │  3 │
    =#

To count employees in *each* department, we use the `Each()` query
combinator.

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

### Function broadcasting

Besides broadcast operators, such as greater than (`.>`),
arbitrary functions can also be used as a query combinator with
the broadcast notation. Let's define a function to extract an
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

The more general conversion of a function into a combinator is
accomplished by `Lift`, as documented in the reference. How a
lifted function is treated as a query combinator depends upon that
function's input and output signature.

### Keeping Values

Suppose we'd like a list of employee names together with the
corresponding department name. The naive approach won't work,
because `department` is not a label in the context of an employee.

    chicago[
        It.department >>
        It.employee >>
        Record(It.name, It.department.name)]
    #-> ERROR: cannot find department ⋮

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
with a higher than average salary within their department.

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

In this last query, `mean` simply can't be moved into the scope of
the `Filter` combinator, since its arguments are evaluated for
*each* employee.

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

A negative index can be used to count records from the end of the
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

This last query deserves a bit of explanation, but the reference
is a more appropriate place for this discussion. For now, we could
say the query above is equivalent to the following.

    Employee = It.department.employee
    chicago[
        Keep(:no => Count(Employee) .÷ 2) >>
        Each(Employee >> Take(It.no))]
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

With a different threshold amount, the result may change.

    chicago[PaidOverAmt, AMT=85000]
    #=>
      │ name      │
    ──┼───────────┼
    1 │ JEFFERY A │
    2 │ DANIEL A  │
    =#

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
be refined with further computation.

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
    #-> ERROR: cannot find amt ⋮

### More Aggregates

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

These statistics could be run by department.

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
`Stats(It)`.

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


