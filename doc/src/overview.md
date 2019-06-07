# Queries for Data Analysts

DataKnots is a toolkit for representing and querying complex
structured data. It is designed for data analysts and domain
experts (e.g. accountants, engineers, researchers) who need to
build and share domain-specific queries. 

This overview shows how typical query operations can be performed
upon a simplified in-memory dataset using DataKnot's macro syntax.

## Data Navigation

Consider a tiny cross-section of public data from Chicago,
represented as nested `Vector` and `NamedTuple` objects.

    department_data = [
      (name = "POLICE",
       employee = [
        (name = "ANTHONY A", position = "POLICE OFFICER", salary = 72510),
        (name = "JEFFERY A", position = "SERGEANT", salary = 101442),
        (name = "NANCY A", position = "POLICE OFFICER", salary = 80016)]),
      (name = "FIRE",
       employee = [
        (name = "DANIEL A", position = "FIREFIGHTER-EMT", salary = 95484),
        (name = "ROBERT K", position = "FIREFIGHTER-EMT", salary = 103272)])]

This hierarchical dataset contains a list of departments, with
each department containing associated employees.

To query this dataset, we convert it into a `DataKnot`, or *knot*.

    using DataKnots

    chicago = DataKnot(:department => department_data)

Let's say we want to return the list of department names. We query
the `chicago` knot with `department.name`.

    @query chicago department.name
    #=>
      │ name   │
    ──┼────────┼
    1 │ POLICE │
    2 │ FIRE   │
    =#

The dotted notation lets one navigate a hierarchical dataset.
Let's continue our dataset exploration by listing employee names.

    @query chicago department.employee.name
    #=>
      │ name      │
    ──┼───────────┼
    1 │ ANTHONY A │
    2 │ JEFFERY A │
    3 │ NANCY A   │
    4 │ DANIEL A  │
    5 │ ROBERT K  │
    =#

We could write the query above, without the period delimiter, as a
multi-line macro block.

    @query chicago begin
        department
        employee
        name
    end

Navigation context matters. For example, `employee` tuples are not
directly accessible from the root of the knot. When a field label,
such as `employee`, can't be found, an appropriate error message
is displayed.

    @query chicago employee
    #-> ERROR: cannot find "employee" ⋮

Instead, `employee` tuples can be queried by navigating through
`department` tuples. When tuples are returned, they are displayed
as a table.

    @query chicago department.employee
    #=>
      │ employee                           │
      │ name       position         salary │
    ──┼────────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER    72510 │
    2 │ JEFFERY A  SERGEANT         101442 │
    3 │ NANCY A    POLICE OFFICER    80016 │
    4 │ DANIEL A   FIREFIGHTER-EMT   95484 │
    5 │ ROBERT K   FIREFIGHTER-EMT  103272 │
    =#

## Counting & Context

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

## Records & Filters

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

Additionally, we could list the employee names associated
with each of these departments.

    @query chicago begin
       department
       { name,
         size => count(employee),
         employee_names => employee.name }
    end
    #=>
      │ department                                  │
      │ name    size  employee_names                │
    ──┼─────────────────────────────────────────────┼
    1 │ POLICE     3  ANTHONY A; JEFFERY A; NANCY A │
    2 │ FIRE       2  DANIEL A; ROBERT K            │
    =#

In this display `employee_names` is a plural value. Hence the
output cell for each department is delimited by a semi-colon.

We can extend the previous query to show only departments with
more than `2` employees.

    @query chicago begin
       department
       { name,
         size => count(employee),
         employee_names => employee.name }
       filter(size > 2)
    end
    #=>
      │ department                                  │
      │ name    size  employee_names                │
    ──┼─────────────────────────────────────────────┼
    1 │ POLICE     3  ANTHONY A; JEFFERY A; NANCY A │
    =#

The argument to `filter` can be any query expression that is valid
for the current context.

    @query chicago begin
        department
        filter(count(employee) < 3)
        { name,
          employee_names => employee.name }
    end
    #=>
      │ department               │
      │ name  employee_names     │
    ──┼──────────────────────────┼
    1 │ FIRE  DANIEL A; ROBERT K │
    =#

With these queries we've seen how to navigate, count, record and
filter. These operations form the base of our query language.

## Aggregate Queries

So far we've only seen *elementwise* queries which emit an output
for each of its input elements. Informally, we can see this with
the query `department.count(employee)`.

    @query chicago department.count(employee)
    #=>
    ──┼───┼
    1 │ 3 │
    2 │ 2 │
    =#

In this case, the query `count(employee)` input has two elements,
one for each department. It it emits output elements for each,
representing the number of employees for the given department.

Without arguments, `count()` counts the number of input elements
it receives. These *aggregate* queries produce an output relative
to their input as a whole.

    @query chicago department.employee.count()
    #=>
    ┼───┼
    │ 5 │
    =#

We may wish to count employees by department. Contrary to
expectation, adding parentheses will not change the result.

    @query chicago department.(employee.count())
    #=>
    ┼───┼
    │ 5 │
    =#

To count employees in *each* department, we use `each()`, which
evaluates its argument elementwise.

    @query chicago department.each(employee.count())
    #=>
    ──┼───┼
    1 │ 3 │
    2 │ 2 │
    =#

Equivalently, we could use `count(employee)`.

    @query chicago department.count(employee)
    #=>
    ──┼───┼
    1 │ 3 │
    2 │ 2 │
    =#

Which variant of `count` to use depends upon what is notationally
convenient: is the count of the input elements requested? or is a
count of something relative to each input needed?

## Paging Data

Sometimes query results can be quite large. In this case it's
helpful to `take` or `drop` items from the input. Let's return
only the first two of the employees.

    @query chicago department.employee.take(2)
    #=>
      │ employee                          │
      │ name       position        salary │
    ──┼───────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER   72510 │
    2 │ JEFFERY A  SERGEANT        101442 │
    =#

A negative index counts records from the end of the input. So, to
return all the records but the last two, we write:

    @query chicago department.employee.take(-2)
    #=>
      │ employee                          │
      │ name       position        salary │
    ──┼───────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER   72510 │
    2 │ JEFFERY A  SERGEANT        101442 │
    3 │ NANCY A    POLICE OFFICER   80016 │
    =#

To skip the first two records, returning the rest, we use `drop`.

    @query chicago department.employee.drop(2)
    #=>
      │ employee                          │
      │ name      position         salary │
    ──┼───────────────────────────────────┼
    1 │ NANCY A   POLICE OFFICER    80016 │
    2 │ DANIEL A  FIREFIGHTER-EMT   95484 │
    3 │ ROBERT K  FIREFIGHTER-EMT  103272 │
    =#

To return the 1st half of the employees in the database, we could
use `take` with an argument that computes how many to take.

    @query chicago begin
        department.employee
        take(count(department.employee) ÷ 2)
    end
    #=>
      │ employee                          │
      │ name       position        salary │
    ──┼───────────────────────────────────┼
    1 │ ANTHONY A  POLICE OFFICER   72510 │
    2 │ JEFFERY A  SERGEANT        101442 │
    =#

Unlike `filter`, `take` and `drop` are aggregates because the
output they generate depend not just upon each input element, but
also upon the position of that element with respect to the entire
input collection.

## Grouping Data

So far, we've navigated and counted data by exploiting its
hierarchical organization. But what if we want a query that isn't
supported by the existing hierarchy? For example, how could we
calculate the number of employees for each *position*?

A list of distinct positions could be obtained using `unique`.

    @query chicago department.employee.position.unique()
    #=>
      │ position        │
    ──┼─────────────────┼
    1 │ FIREFIGHTER-EMT │
    2 │ POLICE OFFICER  │
    3 │ SERGEANT        │
    =#

However, `unique` is not sufficient because positions are not
associated to the respective employees. To associate employee
records to their positions, we use `group`.

    @query chicago begin
         department
         employee
         group(position)
         { position, employee.name }
    end
    #=>
      │ position         name               │
    ──┼─────────────────────────────────────┼
    1 │ FIREFIGHTER-EMT  DANIEL A; ROBERT K │
    2 │ POLICE OFFICER   ANTHONY A; NANCY A │
    3 │ SERGEANT         JEFFERY A          │
    =#

The complement of each group is often plural, and in this case,
elements of from the complement are separated by the semi-colon.
We could see this by counting employees in each position.

    @query chicago begin
         department
         employee
         group(position)
         { position, count => count(employee) }
    end
    #=>
      │ position         count │
    ──┼────────────────────────┼
    1 │ FIREFIGHTER-EMT      2 │
    2 │ POLICE OFFICER       2 │
    3 │ SERGEANT             1 │
    =#

Here, `group` and `unique` are also aggregate. In particular, the
output they produce is quite distinct from their input. Generally,
it's the flexibility of aggregate queries like `group(position)`
that provide the operational power of this query language.

