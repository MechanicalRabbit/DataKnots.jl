var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "#DataKnots.jl-1",
    "page": "Home",
    "title": "DataKnots.jl",
    "category": "section",
    "text": "DataKnots aspires to be a Julia library for representing and querying data, including nested and circular structures. DataKnots will provide integration and analytics across CSV, JSON, XML and SQL data sources with an extensible, practical and coherent algebra of query combinators.At this time, while we welcome feedback and contributions, DataKnots is not yet usable for general audiences."
},

{
    "location": "#Contents-1",
    "page": "Home",
    "title": "Contents",
    "category": "section",
    "text": "Pages = [\n    \"tutorial.md\",\n    \"thinking.md\",\n    \"reference.md\",\n    \"implementation.md\",\n]\nDepth=2"
},

{
    "location": "#Index-1",
    "page": "Home",
    "title": "Index",
    "category": "section",
    "text": ""
},

{
    "location": "tutorial/#",
    "page": "DataKnots Tutorial",
    "title": "DataKnots Tutorial",
    "category": "page",
    "text": ""
},

{
    "location": "tutorial/#DataKnots-Tutorial-1",
    "page": "DataKnots Tutorial",
    "title": "DataKnots Tutorial",
    "category": "section",
    "text": "DataKnots is an embedded query language designed so that accidental programmers can more easily solve complex data analysis tasks. This tutorial shows how typical query operations can be performed upon a simplified in-memory dataset."
},

{
    "location": "tutorial/#Getting-Started-1",
    "page": "DataKnots Tutorial",
    "title": "Getting Started",
    "category": "section",
    "text": "Consider a tiny cross-section of public data from Chicago, represented as nested NamedTuple and Vector objects.chicago_data =\n  (department = [\n    (name = \"POLICE\",\n     employee = [\n      (name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442),\n      (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016)]),\n    (name = \"FIRE\",\n     employee = [\n      (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484)])],)In this hierarchical Chicago dataset, the root is a NamedTuple with a field department, which is a Vector of department records, and so on.To query this dataset, we convert it into a DataKnot, or knot.using DataKnots\nchicago = DataKnot(chicago_data)"
},

{
    "location": "tutorial/#Our-First-Query-1",
    "page": "DataKnots Tutorial",
    "title": "Our First Query",
    "category": "section",
    "text": "Let\'s say we want to return the list of department names from this dataset. We query the chicago knot using Julia\'s index notation with It.department.name.department_names = chicago[It.department.name]\n#=>\n  │ name   │\n──┼────────┼\n1 │ POLICE │\n2 │ FIRE   │\n=#The output, department_names, is also a DataKnot. The content of this output knot could be accessed via get function.get(department_names)\n#-> [\"POLICE\", \"FIRE\"]"
},

{
    "location": "tutorial/#Navigation-1",
    "page": "DataKnots Tutorial",
    "title": "Navigation",
    "category": "section",
    "text": "In DataKnot queries, It means \"the current input\". The dotted notation lets one navigate a hierarchical dataset. Let\'s continue our dataset exploration by listing employee names.chicago[It.department.employee.name]\n#=>\n  │ name      │\n──┼───────────┼\n1 │ JEFFERY A │\n2 │ NANCY A   │\n3 │ DANIEL A  │\n=#Navigation context matters. For example, employee tuples are not directly accessible from the root of the dataset. When a field label, such as employee, can\'t be found, an appropriate error message is displayed.chicago[It.employee]\n#-> ERROR: cannot find \"employee\" ⋮Instead, employee tuples can be queried by navigating though department tuples. When tuples are returned, they are displayed as a table.chicago[It.department.employee]\n#=>\n  │ employee                            │\n  │ name       position          salary │\n──┼─────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT          101442 │\n2 │ NANCY A    POLICE OFFICER     80016 │\n3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │\n=#Notice that nested vectors traversed during navigation are flattened into a single output vector."
},

{
    "location": "tutorial/#Composition-and-Identity-1",
    "page": "DataKnots Tutorial",
    "title": "Composition & Identity",
    "category": "section",
    "text": "Dotted navigation, such as It.department.name, is a syntax shorthand for the Get() primitive together with query composition (>>).chicago[Get(:department) >> Get(:name)]\n#=>\n  │ name   │\n──┼────────┼\n1 │ POLICE │\n2 │ FIRE   │\n=#The Get() primitive returns values that match a given label. Query composition (>>) chains two queries serially, with the output of the first query as input to the second.chicago[Get(:department) >> Get(:employee)]\n#=>\n  │ employee                            │\n  │ name       position          salary │\n──┼─────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT          101442 │\n2 │ NANCY A    POLICE OFFICER     80016 │\n3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │\n=#The It query simply reproduces its input, which makes it the identity with respect to composition (>>). Hence, It can be woven into any composition without changing the result.chicago[It >> Get(:department) >> Get(:name)]\n#=>\n  │ name   │\n──┼────────┼\n1 │ POLICE │\n2 │ FIRE   │\n=#This motivates our clever use of It as a syntax shorthand.chicago[It.department.name]\n#=>\n  │ name   │\n──┼────────┼\n1 │ POLICE │\n2 │ FIRE   │\n=#In DataKnots, queries are either primitives, such as Get and It, or built from other queries with combinators, such as composition (>>). Let\'s explore some other combinators."
},

{
    "location": "tutorial/#Context-and-Counting-1",
    "page": "DataKnots Tutorial",
    "title": "Context & Counting",
    "category": "section",
    "text": "To count the number of departments in this chicago dataset we write the query Count(It.department). Observe that the argument provided to Count(), It.department, is itself a query.chicago[Count(It.department)]\n#=>\n│ It │\n┼────┼\n│  2 │\n=#Using query composition (>>), we can perform Count in a nested context. For this next example, let\'s count employee records within each department.chicago[It.department >> Count(It.employee)]\n#=>\n  │ It │\n──┼────┼\n1 │  2 │\n2 │  1 │\n=#In this output, we see that one department has 2 employees, while the other has only 1."
},

{
    "location": "tutorial/#Record-Construction-1",
    "page": "DataKnots Tutorial",
    "title": "Record Construction",
    "category": "section",
    "text": "Let\'s improve the previous query by including each department\'s name alongside employee counts. This can be done by using the Record combinator.chicago[\n    It.department >>\n    Record(It.name,\n           Count(It.employee))]\n#=>\n  │ department │\n  │ name    #B │\n──┼────────────┼\n1 │ POLICE   2 │\n2 │ FIRE     1 │\n=#To label a record field we use Julia\'s Pair syntax, (=>).chicago[\n    It.department >>\n    Record(It.name,\n           :employee_count =>\n               Count(It.employee))]\n#=>\n  │ department             │\n  │ name    employee_count │\n──┼────────────────────────┼\n1 │ POLICE               2 │\n2 │ FIRE                 1 │\n=#This is syntax shorthand for the Label primitive.chicago[\n    It.department >>\n    Record(It.name,\n           Count(It.employee) >>\n           Label(:employee_count))]\n#=>\n  │ department             │\n  │ name    employee_count │\n──┼────────────────────────┼\n1 │ POLICE               2 │\n2 │ FIRE                 1 │\n=#Records can be nested. The following listing includes, for each department, employees\' name and salary.chicago[\n    It.department >>\n    Record(It.name,\n           It.employee >>\n           Record(It.name,\n                  It.salary))]\n#=>\n  │ department                                │\n  │ name    employee                          │\n──┼───────────────────────────────────────────┼\n1 │ POLICE  JEFFERY A, 101442; NANCY A, 80016 │\n2 │ FIRE    DANIEL A, 95484                   │\n=#In this output, commas separate tuple fields and semi-colons separate vector elements."
},

{
    "location": "tutorial/#Reusable-Queries-1",
    "page": "DataKnots Tutorial",
    "title": "Reusable Queries",
    "category": "section",
    "text": "Queries can be reused. Let\'s define EmployeeCount to be a query that computes the number of employees in a department.EmployeeCount =\n    :employee_count =>\n        Count(It.employee)This query can be used in different contexts.chicago[Max(It.department >> EmployeeCount)]\n#=>\n│ It │\n┼────┼\n│  2 │\n=#\n\nchicago[\n    It.department >>\n    Record(It.name,\n           EmployeeCount)]\n#=>\n  │ department             │\n  │ name    employee_count │\n──┼────────────────────────┼\n1 │ POLICE               2 │\n2 │ FIRE                 1 │\n=#"
},

{
    "location": "tutorial/#Filtering-Data-1",
    "page": "DataKnots Tutorial",
    "title": "Filtering Data",
    "category": "section",
    "text": "Let\'s extend the previous query to only show departments with more than one employee. This can be done using the Filter combinator.chicago[\n    It.department >>\n    Record(It.name, EmployeeCount) >>\n    Filter(It.employee_count .> 1)]\n#=>\n  │ department             │\n  │ name    employee_count │\n──┼────────────────────────┼\n1 │ POLICE               2 │\n=#To use regular operators in query expressions, we need to use broadcasting notation, such as .> rather than > ; forgetting the period is an easy mistake to make.chicago[\n    It.department >>\n    Record(It.name, EmployeeCount) >>\n    Filter(It.employee_count > 1)]\n#=>\nERROR: MethodError: no method matching isless(::Int, ::DataKnots.Navigation)\n⋮\n=#"
},

{
    "location": "tutorial/#Incremental-Composition-1",
    "page": "DataKnots Tutorial",
    "title": "Incremental Composition",
    "category": "section",
    "text": "Combinators let us construct queries incrementally. Let\'s explore our Chicago data starting with a list of employees.Q = It.department.employee\n\nchicago[Q]\n#=>\n  │ employee                            │\n  │ name       position          salary │\n──┼─────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT          101442 │\n2 │ NANCY A    POLICE OFFICER     80016 │\n3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │\n=#Let\'s extend this query to show if the salary is over 100k. Notice how the query definition is tracked.GT100K = :gt100k => It.salary .> 100000\n\nQ >>= Record(It.name, It.salary, GT100K)\n#=>\nIt.department.employee >>\nRecord(It.name, It.salary, :gt100k => It.salary .> 100000)\n=#Let\'s run Q again.chicago[Q]\n#=>\n  │ employee                  │\n  │ name       salary  gt100k │\n──┼───────────────────────────┼\n1 │ JEFFERY A  101442    true │\n2 │ NANCY A     80016   false │\n3 │ DANIEL A    95484   false │\n=#We can now filter the dataset to include only high-paid employees.Q >>= Filter(It.gt100k)\n#=>\nIt.department.employee >>\nRecord(It.name, It.salary, :gt100k => It.salary .> 100000) >>\nFilter(It.gt100k)\n=#Let\'s run Q again.chicago[Q]\n#=>\n  │ employee                  │\n  │ name       salary  gt100k │\n──┼───────────────────────────┼\n1 │ JEFFERY A  101442    true │\n=#Well-tested queries may benefit from a Tag so that their definitions are suppressed in larger compositions.HighlyCompensated = Tag(:HighlyCompensated, Q)\n#-> HighlyCompensated\n\nchicago[HighlyCompensated]\n#=>\n  │ employee                  │\n  │ name       salary  gt100k │\n──┼───────────────────────────┼\n1 │ JEFFERY A  101442    true │\n=#This tagging can make subsequent compositions easier to read.Q = HighlyCompensated >> It.name\n#=>\nHighlyCompensated >> It.name\n=#\n\nchicago[Q]\n#=>\n  │ name      │\n──┼───────────┼\n1 │ JEFFERY A │\n=#"
},

{
    "location": "tutorial/#Aggregate-Queries-1",
    "page": "DataKnots Tutorial",
    "title": "Aggregate Queries",
    "category": "section",
    "text": "We\'ve demonstrated the Count combinator, but Count could also be used as a query. In this next example, Count receives employees as input, and produces their number as output.chicago[It.department.employee >> Count]\n#=>\n│ It │\n┼────┼\n│  3 │\n=#Previously we\'ve only seen elementwise queries, which emit an output for each of its input elements. The Count query is an aggregate, which means it emits an output for its entire input.In this example, since It.department >> It.employee is the input for Count, the total spans all employees across all departments. Adding parenthesis to get counts by department doesn\'t work since composition (>>) is an associative operator.chicago[It.department >> (It.employee >> Count)]\n#=>\n│ It │\n┼────┼\n│  3 │\n=#To count employees in each department, we use Each(). This combinator evaluates its argument elementwise. Therefore, we get two numbers, one for each department.chicago[It.department >> Each(It.employee >> Count)]\n#=>\n  │ It │\n──┼────┼\n1 │  2 │\n2 │  1 │\n=#Alternatively, we could use the Count() combinator to get the same result.chicago[It.department >> Count(It.employee)]\n#=>\n  │ It │\n──┼────┼\n1 │  2 │\n2 │  1 │\n=#Which form of Count to use depends upon what is notationally convenient. For incremental construction, being able to simply append >> Count is often very helpful.Q = It.department.employee\nchicago[Q >> Count]\n#=>\n│ It │\n┼────┼\n│  3 │\n=#We could then refine the query, and run the exact same command.Q >>= Filter(It.salary .> 100000)\nchicago[Q >> Count]\n#=>\n│ It │\n┼────┼\n│  1 │\n=#"
},

{
    "location": "tutorial/#Summarizing-Data-1",
    "page": "DataKnots Tutorial",
    "title": "Summarizing Data",
    "category": "section",
    "text": "To summarize data, we could use combinators such as Min, Max, and Sum.Salary = It.department.employee.salary\n\nchicago[\n    Record(\n        :count => Count(Salary),\n        :min => Min(Salary),\n        :max => Max(Salary),\n        :sum => Sum(Salary))]\n#=>\n│ count  min    max     sum    │\n┼──────────────────────────────┼\n│     3  80016  101442  276942 │\n=#Just as Count has an aggregate query form, so do Min, Max, and Sum.Salary = It.employee.salary\n\nchicago[\n    It.department >>\n    Record(\n        It.name,\n        :count => Salary >> Count,\n        :min => Salary >> Min,\n        :max => Salary >> Max,\n        :sum => Salary >> Sum)]\n#=>\n  │ department                           │\n  │ name    count  min    max     sum    │\n──┼──────────────────────────────────────┼\n1 │ POLICE      2  80016  101442  181458 │\n2 │ FIRE        1  95484   95484   95484 │\n=#"
},

{
    "location": "tutorial/#Broadcasting-over-Queries-1",
    "page": "DataKnots Tutorial",
    "title": "Broadcasting over Queries",
    "category": "section",
    "text": "Any function could be used as a query combinator with the broadcasting notation.chicago[\n    It.department.employee >>\n    titlecase.(It.name)]\n#=>\n  │ It        │\n──┼───────────┼\n1 │ Jeffery A │\n2 │ Nancy A   │\n3 │ Daniel A  │\n=#Vector functions, such as mean, can also be broadcast.using Statistics: mean\n\nchicago[\n    It.department >>\n    Record(\n        It.name,\n        :mean_salary => mean.(It.employee.salary))]\n#=>\n  │ department          │\n  │ name    mean_salary │\n──┼─────────────────────┼\n1 │ POLICE      90729.0 │\n2 │ FIRE        95484.0 │\n=#"
},

{
    "location": "tutorial/#Keeping-Values-1",
    "page": "DataKnots Tutorial",
    "title": "Keeping Values",
    "category": "section",
    "text": "Suppose we\'d like a list of employee names together with their department.  The naive approach won\'t work, because department is not available in the context of an employee.chicago[\n    It.department >>\n    It.employee >>\n    Record(It.name, It.department.name)]\n#-> ERROR: cannot find \"department\" ⋮This can be overcome by using Keep to label an expression\'s result, so that it is available within subsequent computations.chicago[\n    It.department >>\n    Keep(:dept_name => It.name) >>\n    It.employee >>\n    Record(It.name, It.dept_name)]\n#=>\n  │ employee             │\n  │ name       dept_name │\n──┼──────────────────────┼\n1 │ JEFFERY A  POLICE    │\n2 │ NANCY A    POLICE    │\n3 │ DANIEL A   FIRE      │\n=#This pattern also emerges when a filter condition uses a parameter calculated in a parent context. For example, let\'s list employees with a higher than average salary for their department.chicago[\n    It.department >>\n    Keep(:mean_salary => mean.(It.employee.salary)) >>\n    It.employee >>\n    Filter(It.salary .> It.mean_salary)]\n#=>\n  │ employee                    │\n  │ name       position  salary │\n──┼─────────────────────────────┼\n1 │ JEFFERY A  SERGEANT  101442 │\n=#"
},

{
    "location": "tutorial/#Paging-Data-1",
    "page": "DataKnots Tutorial",
    "title": "Paging Data",
    "category": "section",
    "text": "Sometimes query results can be quite large. In this case it\'s helpful to Take or Drop items from the input. Let\'s start by listing all 3 employees of our toy database.Employee = It.department.employee\nchicago[Employee]\n#=>\n  │ employee                            │\n  │ name       position          salary │\n──┼─────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT          101442 │\n2 │ NANCY A    POLICE OFFICER     80016 │\n3 │ DANIEL A   FIRE FIGHTER-EMT   95484 │\n=#To return only the first 2 records, we use Take.chicago[Employee >> Take(2)]\n#=>\n  │ employee                          │\n  │ name       position        salary │\n──┼───────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT        101442 │\n2 │ NANCY A    POLICE OFFICER   80016 │\n=#A negative index counts records from the end of the input. So, to return all the records but the last two, we write:chicago[Employee >> Take(-2)]\n#=>\n  │ employee                    │\n  │ name       position  salary │\n──┼─────────────────────────────┼\n1 │ JEFFERY A  SERGEANT  101442 │\n=#To skip the first two records, returning the rest, we use Drop.chicago[Employee >> Drop(2)]\n#=>\n  │ employee                           │\n  │ name      position          salary │\n──┼────────────────────────────────────┼\n1 │ DANIEL A  FIRE FIGHTER-EMT   95484 │\n=#To return the 1st half of the employees in the database, we could use Take with an argument that computes how many to take.chicago[Employee >> Take(Count(Employee) .÷ 2)]\n#=>\n  │ employee                    │\n  │ name       position  salary │\n──┼─────────────────────────────┼\n1 │ JEFFERY A  SERGEANT  101442 │\n=#"
},

{
    "location": "tutorial/#Query-Parameters-1",
    "page": "DataKnots Tutorial",
    "title": "Query Parameters",
    "category": "section",
    "text": "A query may depend upon parameters, passed as keyword arguments. The parameter values are available in the query though It.chicago[AMT=100000, It.AMT]\n#=>\n│ AMT    │\n┼────────┼\n│ 100000 │\n=#Using parameters lets us reuse complex queries without changing their definition. By convention we capitalize parameters so they stand out from regular data labels.PaidOverAmt =\n    It.department >>\n    It.employee >>\n    Filter(It.salary .> It.AMT) >>\n    It.name\n\nchicago[AMT=100000, PaidOverAmt]\n#=>\n  │ name      │\n──┼───────────┼\n1 │ JEFFERY A │\n=#What if we want to return employees who have a greater than average salary? This average could be computed first.MeanSalary = mean.(It.department.employee.salary)\nmean_salary = chicago[MeanSalary]\n#=>\n│ It      │\n┼─────────┼\n│ 92314.0 │\n=#Then, this value could be passed as our parameter.chicago[PaidOverAmt, AMT=mean_salary]\n#=>\n  │ name      │\n──┼───────────┼\n1 │ JEFFERY A │\n2 │ DANIEL A  │\n=#This approach performs composition outside of the query language. To evaluate a query and immediately use it as a parameter within the same query expression, we could use the Given combinator.chicago[Given(:AMT => MeanSalary, PaidOverAmt)]\n#=>\n  │ name      │\n──┼───────────┼\n1 │ JEFFERY A │\n2 │ DANIEL A  │\n=#"
},

{
    "location": "tutorial/#Custom-Combinators-1",
    "page": "DataKnots Tutorial",
    "title": "Custom Combinators",
    "category": "section",
    "text": "Using Given lets us easily create new query combinators. Let\'s make a combinator EmployeesOver that produces employees with a salary greater than the given amount.EmployeesOver(X) =\n    Given(:AMT => X,\n        It.department >>\n        It.employee >>\n        Filter(It.salary .> It.AMT))\n\nchicago[EmployeesOver(100000)]\n#=>\n  │ employee                    │\n  │ name       position  salary │\n──┼─────────────────────────────┼\n1 │ JEFFERY A  SERGEANT  101442 │\n=#EmployeesOver can take another query as an argument. For example, let\'s find employees with higher than average salary.MeanSalary = mean.(It.department.employee.salary)\n\nchicago[EmployeesOver(MeanSalary)]\n#=>\n  │ employee                            │\n  │ name       position          salary │\n──┼─────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT          101442 │\n2 │ DANIEL A   FIRE FIGHTER-EMT   95484 │\n=#Note that this combination is yet another query that could be further refined.chicago[EmployeesOver(MeanSalary) >> It.name]\n#=>\n  │ name      │\n──┼───────────┼\n1 │ JEFFERY A │\n2 │ DANIEL A  │\n=#Alternatively, this combinator could have been defined using Keep. We use Given because it doesn\'t leak parameters. Specifically, It.AMT is not available outside EmployeesOver().chicago[EmployeesOver(MeanSalary) >> It.AMT]\n#-> ERROR: cannot find \"AMT\" ⋮"
},

{
    "location": "tutorial/#Extracting-Data-1",
    "page": "DataKnots Tutorial",
    "title": "Extracting Data",
    "category": "section",
    "text": "Given any DataKnot, its content can be extracted using get. For singular output, get returns a scalar value.get(chicago[Count(It.department)])\n#-> 2For plural output, get returns a Vector.get(chicago[It.department.employee.name])\n#-> [\"JEFFERY A\", \"NANCY A\", \"DANIEL A\"]For more complex outputs, get may return a @VectorTree, which is an AbstractVector specialized for column-oriented storage.query = It.department >>\n        Record(It.name,\n               :employee_count => Count(It.employee))\nvt = get(chicago[query])\ndisplay(vt)\n#=>\n@VectorTree of 2 × (name = (1:1) × String, employee_count = (1:1) × Int):\n (name = \"POLICE\", employee_count = 2)\n (name = \"FIRE\", employee_count = 1)\n=#"
},

{
    "location": "thinking/#",
    "page": "Thinking in Combinators",
    "title": "Thinking in Combinators",
    "category": "page",
    "text": ""
},

{
    "location": "thinking/#Thinking-in-Combinators-1",
    "page": "Thinking in Combinators",
    "title": "Thinking in Combinators",
    "category": "section",
    "text": "DataKnots is a Julia library for building database queries. In DataKnots, queries are assembled algebraically: they either come from a set of atomic primitives or are built from other queries using combinators. In this conceptual guide, we show how to build queries starting from smaller components and then combining them algebraically to implement complex processing tasks.To start working with DataKnots, we import the package:using DataKnots"
},

{
    "location": "thinking/#Constructing-Queries-1",
    "page": "Thinking in Combinators",
    "title": "Constructing Queries",
    "category": "section",
    "text": "A DataKnot, or just knot, is a container having structured, vectorized data.For this guide, we\'ll use a trivial knot, void as our data source. The void knot encapsulates the value nothing, which will serve as the input for our queries.void = DataKnot(nothing)\n#=>\n│ It │\n┼────┼\n│    │\n=#"
},

{
    "location": "thinking/#Constant-Queries-1",
    "page": "Thinking in Combinators",
    "title": "Constant Queries",
    "category": "section",
    "text": "Any Julia value could be converted to a query using the Lift constructor. Queries constructed this way are constant: for each input element they receive, they output the given value. Consider the query Hello, lifted from the string value \"Hello World\".Hello = Lift(\"Hello World\")To query void with Hello, we use indexing notation void[Hello]. In this case, Hello receives nothing from void and produces the value, \"Hello World\".void[Hello]\n#=>\n│ It          │\n┼─────────────┼\n│ Hello World │\n=#A Tuple lifted to a constant query is displayed as a table.void[Lift((name=\"DataKnots\", version=\"0.1\"))]\n#=>\n│ name       version │\n┼────────────────────┼\n│ DataKnots  0.1     │\n=#A Vector lifted to a constant query will produce plural output.void[Lift(\'a\':\'c\')]\n#=>\n  │ It │\n──┼────┼\n1 │ a  │\n2 │ b  │\n3 │ c  │\n=#We call queries constructed this way primitives, as they do not rely upon any other query. There are also combinators, which build new queries from existing ones."
},

{
    "location": "thinking/#Composition-and-Identity-1",
    "page": "Thinking in Combinators",
    "title": "Composition & Identity",
    "category": "section",
    "text": "Two queries can be connected sequentially using the composition combinator (>>). Consider the composition Lift(1:3) >> Hello. Since Hello produces a value for each input element, preceding it with Lift(1:3) generates three copies of \"Hello World\".void[Lift(1:3) >> Hello]\n#=>\n  │ It          │\n──┼─────────────┼\n1 │ Hello World │\n2 │ Hello World │\n3 │ Hello World │\n=#If we compose two plural queries, Lift(1:2) and Lift(\'a\':\'c\'), the output will contain the elements of \'a\':\'c\' repeated twice.void[Lift(1:2) >> Lift(\'a\':\'c\')]\n#=>\n  │ It │\n──┼────┼\n1 │ a  │\n2 │ b  │\n3 │ c  │\n4 │ a  │\n5 │ b  │\n6 │ c  │\n=#The identity with respect to query composition is called It. This primitive can be composed with any query without changing the query\'s output.void[Hello >> It]\n#=>\n│ It          │\n┼─────────────┼\n│ Hello World │\n=#The identity primitive, It, can be used to construct queries which rely upon the output from previous processing.Increment = It .+ 1\nvoid[Lift(1:3) >> Increment]\n#=>\n  │ It │\n──┼────┼\n1 │  2 │\n2 │  3 │\n3 │  4 │\n=#In DataKnots, queries are built algebraically, starting with query primitives, such as constants (Lift) or the identity (It), and then arranged with with combinators, such as composition (>>). This lets us define sophisticated query components and remix them in creative ways."
},

{
    "location": "thinking/#Lifting-Functions-1",
    "page": "Thinking in Combinators",
    "title": "Lifting Functions",
    "category": "section",
    "text": "Any function could be integrated into a DataKnots query. Consider the function double(x) that, when applied to a Number, produces a Number:double(x) = 2x\ndouble(3) #-> 6What we want is an analogue to double which, instead of operating on numbers, operates on queries. Such functions are called query combinators. We can convert any function to a combinator by passing the function and its arguments to Lift.Double(X) = Lift(double, (X,))In this case, double expects a scalar value. Therefore, for a query X, the combinator Double(X) evaluates X and then runs each output element though double. Thus, the query Double(It) would simply double its input.void[Lift(1:3) >> Double(It)]\n#=>\n  │ It │\n──┼────┼\n1 │  2 │\n2 │  4 │\n3 │  6 │\n=#Broadcasting a function over a query argument performs a Lift implicitly, building a query component.void[Lift(1:3) >> double.(It)]\n#=>\n  │ It │\n──┼────┼\n1 │  2 │\n2 │  4 │\n3 │  6 │\n=#Any existing function could be broadcast this way. For example, we could broadcast getfield to get a field value from a tuple.void[Lift((x=1,y=2)) >> getfield.(It, :y)]\n#=>\n│ It │\n┼────┼\n│  2 │\n=#Getting a field value is common enough to have its own notation, properties of It, such as It.y, are used for field access.void[Lift((x=1,y=2)) >> It.y]\n#=>\n│ y │\n┼───┼\n│ 2 │\n=#Implicit lifting also applies to built-in Julia operators (+) and values (1). The expression It .+ 1 is a query component that increments each of its input elements.void[Lift(1:3) >> (It .+ 1)]\n#=>\n  │ It │\n──┼────┼\n1 │  2 │\n2 │  3 │\n3 │  4 │\n=#In Julia, broadcasting lets the function\'s arguments control how the function is applied. When a function is broadcasted over queries, the result is a query. However, to make sure it works, we need to ensure that at least one argument is a query, and we can do this by wrapping at least one argument with Lift.OneTo(N) = UnitRange.(1, Lift(N))Note that the unit range constructor is vector-valued. Therefore, the resulting combinator builds queries with plural output.void[OneTo(3)]\n#=>\n  │ It │\n──┼────┼\n1 │  1 │\n2 │  2 │\n3 │  3 │\n=#This automated lifting lets us access rich statistical and data processing functions from within our queries."
},

{
    "location": "thinking/#Cardinality-1",
    "page": "Thinking in Combinators",
    "title": "Cardinality",
    "category": "section",
    "text": "We have seen that queries produce any number of output rows: Lift(1:3) produces 3 rows and Lift(\"Hello World\") produces exactly one row. Further, the value missing, lifted to a constant query, never produces any rows.void[Lift(missing)]\n#=>\n│ It │\n┼────┼\n=#The constraint on the number of output rows a query may produce is called its cardinality. A query is mandatory if its output must contain at least one row. It is singular if its output must contain at most one row.Example Data Type Singular Mandatory Cardinality\nLift(\"Hello\") scalar Yes Yes :x1to1\nLift(missing) Missing Yes No :x0to1\nLift(\'a\':\'c\') Vector No No :x0toN\n``  No Yes :x1toNThe last permutation in this chart, mandatory yet not singular, does not have a corresponding Julia type. However, data with this :x1toN cardinality could be created as a DataKnot and then lifted to a constant query.one_or_more = DataKnot(\'A\':\'B\', :x1toN)\n\nvoid[Lift(one_or_more)]\n#=>\n  │ It │\n──┼────┼\n1 │ A  │\n2 │ B  │\n=#"
},

{
    "location": "thinking/#Query-Combinators-1",
    "page": "Thinking in Combinators",
    "title": "Query Combinators",
    "category": "section",
    "text": "There are query operations which cannot be lifted from Julia functions. We\'ve met a few already, including the identity (It) and query composition (>>). There are many others involving aggregation, filtering, and paging."
},

{
    "location": "thinking/#Aggregate-Queries-1",
    "page": "Thinking in Combinators",
    "title": "Aggregate Queries",
    "category": "section",
    "text": "So far queries have been elementwise; that is, for each input element, they produce zero or more output elements. Consider the Count primitive; it returns the number of its input elements.void[OneTo(3) >> Count]\n#=>\n│ It │\n┼────┼\n│  3 │\n=#An aggregate query such as Count is computed over the input as a whole, and not for each individual element. The semantics of aggregates require discussion. Consider OneTo(3) >> OneTo(It).void[OneTo(3) >> OneTo(It)]\n#=>\n  │ It │\n──┼────┼\n1 │  1 │\n2 │  1 │\n3 │  2 │\n4 │  1 │\n5 │  2 │\n6 │  3 │\n=#By appending >> Sum we could aggregate the entire input flow, producing a single output element.void[OneTo(3) >> OneTo(It) >> Sum]\n#=>\n│ It │\n┼────┼\n│ 10 │\n=#What if we wanted to produce sums by the outer query, OneTo(3)? Since query composition (>>) is associative, adding parenthesis around OneTo(It) >> Sum will not change the result.void[OneTo(3) >> (OneTo(It) >> Sum)]\n#=>\n│ It │\n┼────┼\n│ 10 │\n=#We need the Each combinator, which acts as an elementwise barrier. For each input element, Each evaluates its argument, and then collects the outputs.void[OneTo(3) >> Each(OneTo(It) >> Sum)]\n#=>\n  │ It │\n──┼────┼\n1 │  1 │\n2 │  3 │\n3 │  6 │\n=#Following is an equivalent query, using the Sum combinator. Here, Sum(X) produces the same output as Each(X >> Sum). Although Sum(X) performs numerical aggregation, it is not an aggregate query since its input is treated elementwise.void[OneTo(3) >> Sum(OneTo(It))]\n#=>\n  │ It │\n──┼────┼\n1 │  1 │\n2 │  3 │\n3 │  6 │\n=#Julia functions taking a vector argument, such as mean, can be lifted to a combinator taking a plural query. When performed, the plural output is converted into the function\'s vector argument.using Statistics\nMean(X) = mean.(X)\nvoid[Mean(OneTo(3) >> Sum(OneTo(It)))]\n#=>\n│ It      │\n┼─────────┼\n│ 3.33333 │\n=#To use Mean as a query primitive, we use Then to build a query that aggregates elements from its input. Next, we register this query so it is used when Mean is treated as a query.DataKnots.Lift(::typeof(Mean)) = DataKnots.Then(Mean)Once these are done, one could take an average of sums as follows:void[Lift(1:3) >> Sum(OneTo(It)) >> Mean]\n#=>\n│ It      │\n┼─────────┼\n│ 3.33333 │\n=#In DataKnots, summary operations are expressed as aggregate query primitives or as query combinators taking a plural query argument. Moreover, custom aggregates can be constructed from native Julia functions and lifted into the query algebra."
},

{
    "location": "thinking/#Filtering-1",
    "page": "Thinking in Combinators",
    "title": "Filtering",
    "category": "section",
    "text": "The Filter combinator has one parameter, a predicate query that, for each input element, decides if this element should be included in the output.void[OneTo(6) >> Filter(It .> 3)]\n#=>\n  │ It │\n──┼────┼\n1 │  4 │\n2 │  5 │\n3 │  6 │\n=#Being a combinator, Filter builds a query component, which could then be composed with any data generating query.KeepEven = Filter(iseven.(It))\nvoid[OneTo(6) >> KeepEven]\n#=>\n  │ It │\n──┼────┼\n1 │  2 │\n2 │  4 │\n3 │  6 │\n=#Filter can work in a nested context.void[Lift(1:3) >> Filter(Sum(OneTo(It)) .> 5)]\n#=>\n  │ It │\n──┼────┼\n1 │  3 │\n=#The Filter combinator is elementwise. Furthermore, the predicate argument is evaluated for each input element. If the predicate evaluation is true for a given element, then that element is reproduced, otherwise it is discarded."
},

{
    "location": "thinking/#Paging-Data-1",
    "page": "Thinking in Combinators",
    "title": "Paging Data",
    "category": "section",
    "text": "Like Filter, the Take and Drop combinators can be used to choose elements from an input: Drop is used to skip over input, while Take ignores input past a particular point.void[OneTo(9) >> Drop(3) >> Take(3)]\n#=>\n  │ It │\n──┼────┼\n1 │  4 │\n2 │  5 │\n3 │  6 │\n=#Unlike Filter, which evaluates its argument for each element, the argument to Take is evaluated once, in the context of the input\'s source.void[OneTo(3) >> Each(Lift(\'a\':\'c\') >> Take(It))]\n#=>\n  │ It │\n──┼────┼\n1 │ a  │\n2 │ a  │\n3 │ b  │\n4 │ a  │\n5 │ b  │\n6 │ c  │\n=#In this example, the argument of Take evaluates in the context of OneTo(3). Therefore, Take will be performed three times, where It has the values 1, 2, and 3."
},

{
    "location": "thinking/#Processing-Model-1",
    "page": "Thinking in Combinators",
    "title": "Processing Model",
    "category": "section",
    "text": "DataKnots processing model has three levels.Combinators build queries.\nQueries extend pipelines.\nPipelines process data.In particular, queries don\'t process data, they are blueprints for assembling pipeline extensions. Pipelines then do processing.Every pipeline has two endpoints, a source and a target, such that each data element that enters at the source is processed to produce zero or more target elements.Combinators, which take queries as arguments and build an output query, have a choice for what to use for each of its arguments\' starting pipeline. For query composition, the starting pipeline for its 1st argument is the input pipeline and the starting pipeline for the 2nd argument is the output pipeline of the 1st.For Filter and other elementwise combinators, the argument queries get a starting pipeline which treats each target element individually. In in this way, they are evaluated locally, without consideration of a broader context.For Take and other aggregate combinators, the arguments (if any) could only have a starting pipeline constructed from the input\'s source. This is advantageous since it lets the aggregate\'s argument inspect the broader context in which it is used.We\'ve seen significant variation of processing approach among the queries we\'ve built thus far.|               |             | Output      | Argument | | Query         | Input Model | Cardinality | Context  | |–––––––-|––––––-|––––––-|–––––| | Lift(1:3)   | Elementwise | :x0toN    |          | | Count       | Aggregate   | :x1to1    |          | | Count(...)  | Elementwise | :x1to1    | Target   | | Filter(...) | Elementwise | :x0to1    | Target   | | Take(3)     | Aggregate   | :x0toN    | Source   |In DataKnots, how combinators construct their queries is given significant flexibility, with a simple interface for the queries themselves: they have an input and output pipeline. Each pipeline can be connected on both sides, the source, the target, or both."
},

{
    "location": "thinking/#Structuring-Data-1",
    "page": "Thinking in Combinators",
    "title": "Structuring Data",
    "category": "section",
    "text": "Thus far we\'ve seen how queries can be composed in heavily nested environments. DataKnots also supports nested data and contexts."
},

{
    "location": "thinking/#Records-and-Labels-1",
    "page": "Thinking in Combinators",
    "title": "Records & Labels",
    "category": "section",
    "text": "Data objects can be created using the Record combinator. Values can be labeled using Julia\'s Pair syntax. The entire result as a whole may also be named.GM = Record(:name => \"GARRY M\", :salary => 260004)\nvoid[GM]\n#=>\n│ name     salary │\n┼─────────────────┼\n│ GARRY M  260004 │\n=#Field access is possible via Get query constructor, which takes a label\'s name. Here Get(:name) is an elementwise query that returns the value of a given label when found.void[GM >> Get(:name)]\n#=>\n│ name    │\n┼─────────┼\n│ GARRY M │\n=#For syntactic convenience, It can be used for dotted access.void[GM >> It.name]\n#=>\n│ name    │\n┼─────────┼\n│ GARRY M │\n=#The Label combinator provides a name to any expression.void[Lift(\"Hello World\") >> Label(:greeting)]\n#=>\n│ greeting    │\n┼─────────────┼\n│ Hello World │\n=#Alternatively, Julia\'s pair constructor (=>) and and a Symbol denoted by a colon (:) can be used to label an expression.Hello =\n  :greeting => Lift(\"Hello World\")\n\nvoid[Hello]\n#=>\n│ greeting    │\n┼─────────────┼\n│ Hello World │\n=#Records can be plural. Here is a table of obvious statistics.Stats = Record(:n¹=>It, :n²=>It.*It, :n³=>It.*It.*It)\nvoid[Lift(1:3) >> Stats]\n#=>\n  │ n¹  n²  n³ │\n──┼────────────┼\n1 │  1   1   1 │\n2 │  2   4   8 │\n3 │  3   9  27 │\n=#By accessing names, calculations can be performed on records.void[Lift(1:3) >> Stats >> (It.n¹ .+ It.n² .+ It.n³)]\n#=>\n  │ It │\n──┼────┼\n1 │  3 │\n2 │ 14 │\n3 │ 39 │\n=#Using records, it is possible to represent complex, hierarchical data. It is then possible to access and compute with this data."
},

{
    "location": "thinking/#Query-Parameters-1",
    "page": "Thinking in Combinators",
    "title": "Query Parameters",
    "category": "section",
    "text": "With DataKnots, parameters can be provided so that static data can be used within query expressions. By convention, we use upper case, singular labels for query parameters.void[\"Hello \" .* Get(:WHO), WHO=\"World\"]\n#=>\n│ It          │\n┼─────────────┼\n│ Hello World │\n=#To make Get convenient, It provides a shorthand syntax.void[\"Hello \" .* It.WHO, WHO=\"World\"]\n#=>\n│ It          │\n┼─────────────┼\n│ Hello World │\n=#Query parameters are available anywhere in the query. They could, for example be used within a filter.query = OneTo(6) >> Filter(It .> It.START)\nvoid[query, START=3]\n#=>\n  │ It │\n──┼────┼\n1 │  4 │\n2 │  5 │\n3 │  6 │\n=#Parameters can also be defined as part of a query using Given. This combinator takes set of pairs (=>) that map symbols (:name) onto query expressions. The subsequent argument is then evaluated in a naming context where the defined parameters are available for reuse.void[Given(:WHO => \"World\", \"Hello \" .* Get(:WHO))]\n#=>\n│ It          │\n┼─────────────┼\n│ Hello World │\n=#Query parameters can be especially useful when managing aggregates, or with expressions that one may wish to repeat more than once.GreaterThanAverage(X) =\n  Given(:AVG => Mean(X),\n        X >> Filter(It .> Get(:AVG)))\n\nvoid[GreaterThanAverage(OneTo(6))]\n#=>\n  │ It │\n──┼────┼\n1 │  4 │\n2 │  5 │\n3 │  6 │\n=#In DataKnots, query parameters permit external data to be used within query expressions. Parameters that are defined with Given can be used to remember values and reuse them."
},

{
    "location": "thinking/#Working-With-Data-1",
    "page": "Thinking in Combinators",
    "title": "Working With Data",
    "category": "section",
    "text": "Arrays of named tuples can be wrapped with Lift in order to provide a series of tuples. Since DataKnots works fluidly with Julia, any sort of Julia object may be used. In this case, NamedTuple has special support so that it prints well.DATA = Lift([(name = \"GARRY M\", salary = 260004),\n              (name = \"ANTHONY R\", salary = 185364),\n              (name = \"DANA A\", salary = 170112)])\n\nvoid[:staff => DATA]\n#=>\n  │ staff             │\n  │ name       salary │\n──┼───────────────────┼\n1 │ GARRY M    260004 │\n2 │ ANTHONY R  185364 │\n3 │ DANA A     170112 │\n=#Access to slots in a NamedTuple is also supported by Get.void[DATA >> Get(:name)]\n#=>\n  │ name      │\n──┼───────────┼\n1 │ GARRY M   │\n2 │ ANTHONY R │\n3 │ DANA A    │\n=#Together with previous combinators, DataKnots could be used to create readable queries, such as \"who has the greatest salary\"?void[:highest_salary =>\n  Given(:MAX => Max(DATA >> It.salary),\n        DATA >> Filter(It.salary .== Get(:MAX)))]\n#=>\n  │ highest_salary  │\n  │ name     salary │\n──┼─────────────────┼\n1 │ GARRY M  260004 │\n=#Records can even contain lists of subordinate records.DB =\n  void[:department =>\n    Record(:name => \"FIRE\", :staff => It.FIRE),\n    FIRE=[(name = \"JOSE S\", salary = 202728),\n          (name = \"CHARLES S\", salary = 197736)]]\n#=>\n│ department                              │\n│ name  staff                             │\n┼─────────────────────────────────────────┼\n│ FIRE  JOSE S, 202728; CHARLES S, 197736 │\n=#These subordinate records can then be summarized.void[:statistics =>\n  DB >> Record(:dept => It.name,\n               :count => Count(It.staff))]\n#=>\n│ statistics  │\n│ dept  count │\n┼─────────────┼\n│ FIRE      2 │\n=#"
},

{
    "location": "thinking/#Quirks-and-Hints-1",
    "page": "Thinking in Combinators",
    "title": "Quirks & Hints",
    "category": "section",
    "text": "By quirks we mean perhaps unexpected consequences of embedding DataKnots in Julia or deviations from how other languages work. They are not necessarily bugs, nor could they be easily fixed.The query Count is not the same as the query Count(It). The former is an aggregate that consumes its entire input, the latter is an elementwise query that considers one input a time. Since it could only receive one input element at a time, Count(It) is always 1. This is clearly less than ideal.void[OneTo(3) >> Count(It)]\n#=>\n  │ It │\n──┼────┼\n1 │  1 │\n2 │  1 │\n3 │  1 │\n=#The Count aggregate only considers the number of elements in the input. It does not check for values that are truthy.void[OneTo(5) >> iseven.(It) >> Count]\n#=>\n│ It │\n┼────┼\n│  5 │\n=#\n\nvoid[OneTo(5) >> Filter(iseven.(It)) >> Count]\n#=>\n│ It │\n┼────┼\n│  2 │\n=#Using the broadcast syntax to lift combinators is clever, but it doesn\'t always work out. If an argument to the broadcast isn\'t a Query then a regular broadcast will happen. For example, rand.(1:3) is an array of arrays containing random numbers. Wrapping an argument in Lift will address this challenge.using Random: seed!, rand\nseed!(0)\nvoid[Lift(1:3) >> rand.(Lift(7:9))]\n#=>\n  │ It │\n──┼────┼\n1 │  7 │\n2 │  9 │\n3 │  8 │\n=#"
},

{
    "location": "reference/#",
    "page": "Reference",
    "title": "Reference",
    "category": "page",
    "text": ""
},

{
    "location": "reference/#Reference-1",
    "page": "Reference",
    "title": "Reference",
    "category": "section",
    "text": "DataKnots are a Julia library for building and evaluating data processing pipelines. Each Pipeline represents a context-aware data transformation; a pipeline\'s input and output is represented by a DataKnot. Besides a few overloaded Base functions, such as run and get, the bulk of this reference focuses on pipeline constructors."
},

{
    "location": "reference/#Concept-Overview-1",
    "page": "Reference",
    "title": "Concept Overview",
    "category": "section",
    "text": "The DataKnots package exports two data types: DataKnot and Pipeline. A DataKnot represents a data set, which may be composite, hierarchical or cyclic; hence the monkier knot. A Pipeline represents a context-aware data transformation from an input knot to an output knot.Consider the following example containing a cross-section of public data from Chicago. This data could be modeled in native Julia as a hierarchy of NamedTuple and Vector objects. Within each department is a set of employee records.Emp = NamedTuple{(:name,:position,:salary,:rate),\n                  Tuple{String,String,Union{Int,Missing},\n                        Union{Float64,Missing}}}\nDep = NamedTuple{(:name, :employee), \n                  Tuple{String,Vector{Emp}}}\n\nchicago_data = \n  (department = Dep[\n   (name = \"POLICE\", employee = Emp[\n     (name = \"JEFFERY A\", position = \"SERGEANT\", \n      salary = 101442, rate = missing), \n     (name = \"NANCY A\", position = \"POLICE OFFICER\", \n      salary = 80016, rate = missing)]), \n   (name = \"FIRE\", employee = Emp[\n     (name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", \n      salary = 103350, rate = missing), \n     (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", \n      salary = 95484, rate = missing)]), \n   (name = \"OEMC\", employee = Emp[\n     (name = \"LAKENYA A\", position = \"CROSSING GUARD\", \n      salary = missing, rate = 17.68), \n     (name = \"DORIS A\", position = \"CROSSING GUARD\", \n      salary = missing, rate = 19.38)])]\n  ,);We can inquire the maximum salary for each department using the DataKnots system. Here we define a MaxSalary pipeline and then incorporate it into the broader DeptStats pipeline. This pipeline can then be run on the ChicagoData knot.using DataKnots\nMaxSalary = :max_salary => Max(It.employee.salary)\nDeptStats = Record(It.name, MaxSalary)\nchicago = DataKnot(chicago_data)\n\nchicago[It.department >> DeptStats]\n#=>\n  │ department         │\n  │ name    max_salary │\n──┼────────────────────┼\n1 │ POLICE      101442 │\n2 │ FIRE        103350 │\n3 │ OEMC               │\n=#The MaxSalary pipeline is context-aware: it assumes a list of employee data found within a given department. It could be used independently by first extracting a particular department. FindDept(X) = It.department >> Filter(It.name .== X)\n police = chicago[FindDept(\"POLICE\")]\n police[DeptStats]\n#=>\n  │ department         │\n  │ name    max_salary │\n──┼────────────────────┼\n1 │ POLICE      101442 │\n=#When the MaxSalary pipeline is invoked, it sees employee data having a source relative to each department. This is what we mean by DataKnots being context-aware. In the DeptStats pipeline, after each MaxSalary is computed, the results are integrated to provide output of the DeptStats pipeline."
},

{
    "location": "reference/#DataKnots.Cardinality-1",
    "page": "Reference",
    "title": "DataKnots.Cardinality",
    "category": "section",
    "text": "In DataKnots, the elementary unit is a collection of values, we call a data knot. Besides the Julia datatype for a knot\'s values, each data knot also has a cardinality. The bookkeeping of cardinality is an essential aspect of pipeline evaluation.Cardinality is a constraint on the number of values in a knot. A knot is called mandatory if it must contain at least one value; optional otherwise. Similarly, a knot is called singular if it must contain at most one value; plural otherwise.    REG::Cardinality = 0      # singular and mandatory\n    OPT::Cardinality = 1      # optional, but singular\n    PLU::Cardinality = 2      # plural, but mandatory\n    OPT_PLU::Cardinality = 3  # optional and pluralTo record the knot cardinality constraint we use the OPT, PLU and REG flags of the type DataKnots.Cardinality. The OPT and PLU flags express relaxations of the mandatory and singular constraint, respectively. A REG knot, which is both mandatory and singular, is called regular and it must contain exactly one value. Conversely, a knot with both OPT|PLU flags has unconstrained cardinality and may contain any number of values.For any knot with values of Julia type T, the knot\'s cardinality has a correspondence to native Julia types: A regular knot corresponds to a single Julia value of type T.  An unconstrained knot corresponds to Vector{T}. An optional knot corresponds to Union{Missing, T}. There is no correspondence for mandatory yet plural knots; however, Vector{T} could be used with the convention that it always has at least one element."
},

{
    "location": "reference/#Creating-and-Extracting-DataKnots-1",
    "page": "Reference",
    "title": "Creating & Extracting DataKnots",
    "category": "section",
    "text": "The constructor DataKnot() takes a native Julia object, typically a vector or scalar value. The get() function can be used to retrieve the DataKnot\'s native Julia value. Like most libraries, show() will produce a suitable display."
},

{
    "location": "reference/#DataKnots.DataKnot-1",
    "page": "Reference",
    "title": "DataKnots.DataKnot",
    "category": "section",
    "text": "    DataKnot(elts::AbstractVector, card::Cardinality=OPT|PLU)In the general case, a DataKnot can be constructed from an AbstractVector to produce a DataKnot with a given cardinality. By default, the card of the collection is unconstrained.    DataKnot(elt, card::Cardinality=REG)As a convenience, a non-vector constructor is also defined, it marks the collection as being both singular and mandatory.    DataKnot(::Missing, card::Cardinality=OPT)There is an edge-case constructor for the creation of a singular but empty collection.    DataKnot()Finally, there is the unit knot, with a single value nothing; this is the default, implicit DataKnot used when run is evaluated without an input data source.DataKnot([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#=>\n  │ It        │\n──┼───────────┼\n1 │ GARRY M   │\n2 │ ANTHONY R │\n3 │ DANA A    │\n\n=#\n\nDataKnot(\"GARRY M\")\n#=>\n│ It      │\n┼─────────┼\n│ GARRY M │\n=#\n\nDataKnot(missing)\n#=>\n│ It │\n┼────┼\n=#\n\nDataKnot()\n#=>\n│ It │\n┼────┼\n│    │\n=#Note that plural DataKnots are shown with an index, while singular knots are shown without. Further note that the missing knot doesn\'t have a value in its data block, unlike the unit knot which has a value of nothing. When showing a DataKnot, we follow Julia\'s command line behavior of rendering nothing as a blank since we wish to display short string values unquoted."
},

{
    "location": "reference/#show-1",
    "page": "Reference",
    "title": "show",
    "category": "section",
    "text": "    show(data::DataKnot)Besides displaying plural and singular knots differently, the show method has special treatment for Tuple and NamedTuple.DataKnot((name = \"GARRY M\", salary = 260004))\n#=>\n│ name     salary │\n┼─────────────────┼\n│ GARRY M  260004 │\n=#This permits a vector-of-tuples to be displayed as tabular data.DataKnot([(name = \"GARRY M\", salary = 260004),\n          (name = \"ANTHONY R\", salary = 185364),\n          (name = \"DANA A\", salary = 170112)])\n#=>\n  │ name       salary │\n──┼───────────────────┼\n1 │ GARRY M    260004 │\n2 │ ANTHONY R  185364 │\n3 │ DANA A     170112 │\n=#"
},

{
    "location": "reference/#get-1",
    "page": "Reference",
    "title": "get",
    "category": "section",
    "text": "    get(data::DataKnot)A DataKnot can be converted into native Julia values using get. Regular values are returned as native Julia. Plural values are returned as a vector.get(DataKnot(\"GARRY M\"))\n#=>\n\"GARRY M\"\n=#\n\nget(DataKnot([\"GARRY M\", \"ANTHONY R\", \"DANA A\"]))\n#=>\n[\"GARRY M\", \"ANTHONY R\", \"DANA A\"]\n=#\n\nget(DataKnot(missing))\n#=>\nmissing\n=#\n\nshow(get(DataKnot()))\n#=>\nnothing\n=#Nested vectors and other data, such as a TupleVector, round-trip though the conversion to a DataKnot and back using get.get(DataKnot([[260004, 185364], [170112]]))\n#=>\nArray{Int,1}[[260004, 185364], [170112]]\n=#\n\nget(DataKnot((name = \"GARRY M\", salary = 260004)))\n#=>\n(name = \"GARRY M\", salary = 260004)\n=#The Implementation Guide provides for lower level details as to the internal representation of a DataKnot. Libraries built with this internal API may provide more convenient ways to construct knots and retrieve values."
},

{
    "location": "reference/#Running-Pipelines-and-Parameters-1",
    "page": "Reference",
    "title": "Running Pipelines & Parameters",
    "category": "section",
    "text": "Pipelines can be evaluated against an input DataKnot using run() to produce an output DataKnot. If an input is not specified, the default unit knot, DataKnot(), is used. There are several sorts of pipelines that could be evaluated."
},

{
    "location": "reference/#DataKnots.AbstractPipeline-1",
    "page": "Reference",
    "title": "DataKnots.AbstractPipeline",
    "category": "section",
    "text": "    struct DataKnot <: AbstractPipeline ... endA DataKnot is viewed as a pipeline that produces its entire data block for each input value it receives.    struct Navigation <: AbstractPipeline ... endFor convenience, path-based navigation is also seen as a pipeline. The identity pipeline, It, simply reproduces its input. Further, when a parameter x is provided via run() it is available for lookup with It.x.    struct Pipeline <: AbstractPipeline ... endBesides the primitives identified above, the remainder of this reference is dedicated to various ways of constructing Pipeline instances from other pipelines."
},

{
    "location": "reference/#run-1",
    "page": "Reference",
    "title": "run",
    "category": "section",
    "text": "    run(F::AbstractPipeline; params...)In its simplest form, run takes a pipeline with a set of named parameters and evaluates the pipeline with the unit knot as input. The parameters are each converted to a DataKnot before being made available within the pipeline\'s evaluation.    run(F::Pair{Symbol,<:AbstractPipeline}; params...)Using Julia\'s Pair syntax, this run method provides a convenient way to label an output DataKnot.    run(db::DataKnot, F; params...)The general case run permits easy use of a specific input data source. It run applies the pipeline F to the input dataset db elementwise with the context params.  Since the 1st argument is a DataKnot and dispatch is unambiguous, the second argument to the method can be automatically converted to a Pipeline using Lift.Therefore, we can write the following examples.DataKnot(\"Hello World\")\n#=>\n│ It          │\n┼─────────────┼\n│ Hello World │\n=#\n\nDataKnot(\"Hello World\")[:greeting => It]\n#=>\n│ greeting    │\n┼─────────────┼\n│ Hello World │\n=#\n\nDataKnot(\"Hello World\")[It]\n#=>\n│ It          │\n┼─────────────┼\n│ Hello World │\n=#\n\nDataKnot()[\"Hello World\"]\n#=>\n│ It          │\n┼─────────────┼\n│ Hello World │\n=#Named arguments to run() become additional values that are accessible via It. Those arguments are converted into a DataKnot if they are not already.DataKnot()[It.hello, hello=DataKnot(\"Hello World\")]\n#=>\n│ hello       │\n┼─────────────┼\n│ Hello World │\n=#\n\nDataKnot()[It.a .* (It.b .+ It.c), a=7, b=7, c=-1]\n#=>\n│ It │\n┼────┼\n│ 42 │\n=#Once a pipeline is run() the resulting DataKnot value can be retrieved via get().get(DataKnot(1)[It .+ 1])\n#=>\n2\n=#Like get and show, the run function comes Julia\'s Base, and hence the methods defined here are only chosen if an argument matches the signature dispatch."
},

{
    "location": "reference/#Pipeline-Construction-1",
    "page": "Reference",
    "title": "Pipeline Construction",
    "category": "section",
    "text": "..."
},

{
    "location": "implementation/#",
    "page": "Implementation Notes",
    "title": "Implementation Notes",
    "category": "page",
    "text": ""
},

{
    "location": "implementation/#Implementation-Notes-1",
    "page": "Implementation Notes",
    "title": "Implementation Notes",
    "category": "section",
    "text": "Pages = [\n    \"vectors.md\",\n    \"pipelines.md\",\n    \"shapes.md\",\n    \"queries.md\",\n]\nDepth = 3"
},

{
    "location": "vectors/#",
    "page": "Column Store",
    "title": "Column Store",
    "category": "page",
    "text": ""
},

{
    "location": "vectors/#Column-Store-1",
    "page": "Column Store",
    "title": "Column Store",
    "category": "section",
    "text": ""
},

{
    "location": "vectors/#Overview-1",
    "page": "Column Store",
    "title": "Overview",
    "category": "section",
    "text": "This section describes how DataKnots implements an in-memory column store. We will need the following definitions:using DataKnots:\n    @VectorTree,\n    BlockVector,\n    Cardinality,\n    TupleVector,\n    cardinality,\n    column,\n    columns,\n    elements,\n    ismandatory,\n    issingular,\n    labels,\n    offsets,\n    width,\n    x0to1,\n    x0toN,\n    x1to1,\n    x1toN"
},

{
    "location": "vectors/#Tabular-data-and-TupleVector-1",
    "page": "Column Store",
    "title": "Tabular data and TupleVector",
    "category": "section",
    "text": "Structured data can often be represented in a tabular form.  For example, information about city employees can be arranged in the following table.name position salary\nJEFFERY A SERGEANT 101442\nJAMES A FIRE ENGINEER-EMT 103350\nTERRY A POLICE OFFICER 93354Internally, a database engine stores tabular data using composite data structures such as tuples and vectors.A tuple is a fixed-size collection of heterogeneous values and can represent a table row.(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442)A vector is a variable-size collection of homogeneous values and can store a table column.[\"JEFFERY A\", \"JAMES A\", \"TERRY A\"]For a table as a whole, we have two options: either store it as a vector of tuples or store it as a tuple of vectors.  The former is called a row-oriented format, commonly used in programming and traditional database engines.[(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442),\n (name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350),\n (name = \"TERRY A\", position = \"POLICE OFFICER\", salary = 93354)]The other option, \"tuple of vectors\" layout, is called a column-oriented format.  It is often used by analytical databases as it is more suited for processing complex analytical queries.The DataKnots package implements data structures to support column-oriented data format.  In particular, tabular data is represented using TupleVector objects.TupleVector(:name => [\"JEFFERY A\", \"JAMES A\", \"TERRY A\"],\n            :position => [\"SERGEANT\", \"FIRE ENGINEER-EMT\", \"POLICE OFFICER\"],\n            :salary => [101442, 103350, 93354])Since creating TupleVector objects by hand is tedious and error prone, DataKnots provides a convenient macro @VectorTree, which lets you create column-oriented data using regular tuple and vector literals.@VectorTree (name = String, position = String, salary = Int) [\n    (name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442),\n    (name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350),\n    (name = \"TERRY A\", position = \"POLICE OFFICER\", salary = 93354),\n]"
},

{
    "location": "vectors/#Hierarchical-data-and-BlockVector-1",
    "page": "Column Store",
    "title": "Hierarchical data and BlockVector",
    "category": "section",
    "text": "Structured data could also be organized in hierarchical fashion.  For example, consider a collection of departments, where each department contains a list of associated employees.name employee\nPOLICE JEFFERY A; NANCY A\nFIRE JAMES A; DANIEL A\nOEMC LAKENYA A; DORIS AIn the row-oriented format, this data is represented using nested vectors.[(name = \"POLICE\", employee = [\"JEFFERY A\", \"NANCY A\"]),\n (name = \"FIRE\", employee = [\"JAMES A\", \"DANIEL A\"]),\n (name = \"OEMC\", employee = [\"LAKENYA A\", \"DORIS A\"])]To represent this data in column-oriented format, we need to serialize name and employee as column vectors.  The name column is straightforward.name_col = [\"POLICE\", \"FIRE\", \"OEMC\"]As for the employee column, naively, we could store it as a vector of vectors.[[\"JEFFERY A\", \"NANCY A\"], [\"JAMES A\", \"DANIEL A\"], [\"LAKENYA A\", \"DORIS A\"]]However, this representation loses the advantages of the column-oriented format since the data is no longer serialized with a fixed number of vectors. Instead, we should keep the column data in a tightly-packed vector of elements.employee_elts = [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"]This vector could be partitioned into separate blocks by the vector of offsets.employee_offs = [1, 3, 5, 7]Each pair of adjacent offsets corresponds a slice of the element vector.employee_elts[employee_offs[1]:employee_offs[2]-1]\n#-> [\"JEFFERY A\", \"NANCY A\"]\nemployee_elts[employee_offs[2]:employee_offs[3]-1]\n#-> [\"JAMES A\", \"DANIEL A\"]\nemployee_elts[employee_offs[3]:employee_offs[4]-1]\n#-> [\"LAKENYA A\", \"DORIS A\"]Together, elements and offsets faithfully reproduce the layout of the column. A pair of the offset and the element vectors is encapsulated with a BlockVector object, which represents a column-oriented encoding of a vector of variable-size blocks.employee_col = BlockVector(employee_offs, employee_elts)Now we can wrap the columns using TupleVector.TupleVector(:name => name_col, :employee => employee_col)@VectorTree provides a convenient way to create BlockVector objects from regular vector literals.@VectorTree (name = String, employee = (0:N)String) [\n    (name = \"POLICE\", employee = [\"JEFFERY A\", \"NANCY A\"]),\n    (name = \"FIRE\", employee = [\"JAMES A\", \"DANIEL A\"]),\n    (name = \"OEMC\", employee = [\"LAKENYA A\", \"DORIS A\"]),\n]"
},

{
    "location": "vectors/#Optional-values-1",
    "page": "Column Store",
    "title": "Optional values",
    "category": "section",
    "text": "As we arrange data in a tabular form, we may need to leave some cells blank.For example, consider that a city employee could be compensated either with salary or with hourly pay.  To display the compensation data in a table, we add two columns: the annual salary and the hourly rate.  However, only one of the columns per each row is filled.name position salary rate\nJEFFERY A SERGEANT 101442 \nJAMES A FIRE ENGINEER-EMT 103350 \nTERRY A POLICE OFFICER 93354 \nLAKENYA A CROSSING GUARD  17.68As in the previous section, the cells in this table may contain a variable number of values.  Therefore, the table columns could be represented using BlockVector objects.  We start with packing the column data as element vectors.salary_elts = [101442, 103350, 93354]\nrate_elts = [17.68]Element vectors are partitioned into table cells by offset vectors.salary_offs = [1, 2, 3, 4, 4]\nrate_offs = [1, 1, 1, 1, 2]The pairs of element and offset vectors are wrapped as BlockVector objects.salary_col = BlockVector(salary_offs, salary_elts, x0to1)\nrate_col = BlockVector(rate_offs, rate_elts, x0to1)Here, the last parameter of the BlockVector constructor is the cardinality constraint on the size of the blocks.  The constraint x0to1 indicates that each block should contain from 0 to 1 elements.  The default constraint x0toN does not restrict the block size.The first two columns of the table do not contain empty cells, and therefore could be represented by regular vectors.  If we choose to wrap these columns with BlockVector, we should use the constraint x1to1 to indicate that each block must contain exactly one element.  Alternatively, BlockVector provides the following shorthand notation.name_col = BlockVector(:, [\"JEFFERY A\", \"JAMES A\", \"TERRY A\", \"LAKENYA A\"])\nposition_col = BlockVector(:, [\"SERGEANT\", \"FIRE ENGINEER-EMT\", \"POLICE OFFICER\", \"CROSSING GUARD\"])To represent the whole table, the columns should be wrapped with a TupleVector.TupleVector(\n    :name => name_col,\n    :position => position_col,\n    :salary => salary_col,\n    :rate => rate_col)As usual, we could create this data from tuple and vector literals.@VectorTree (name = (1:1)String,\n             position = (1:1)String,\n             salary = (0:1)Int,\n             rate = (0:1)Float64) [\n    (name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing),\n    (name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing),\n    (name = \"TERRY A\", position = \"POLICE OFFICER\", salary = 93354, rate = missing),\n    (name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68),\n]"
},

{
    "location": "vectors/#Nested-data-1",
    "page": "Column Store",
    "title": "Nested data",
    "category": "section",
    "text": "When data does not fit a single table, it can often be presented in a top-down fashion.  For example, HR data can be seen as a collection of departments, each of which containing the associated employees.  Such data is serialized using nested data structures, which, in row-oriented format, may look as follows:[(name = \"POLICE\",\n  employee = [(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing),\n              (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016, rate = missing)]),\n (name = \"FIRE\",\n  employee = [(name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing),\n              (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484, rate = missing)]),\n (name = \"OEMC\",\n  employee = [(name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68),\n              (name = \"DORIS A\", position = \"CROSSING GUARD\", salary = missing, rate = 19.38)])]To store this data in a column-oriented format, we should use nested TupleVector and BlockVector instances.  We start with representing employee data.employee_elts =\n    TupleVector(\n        :name => [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"],\n        :position => [\"SERGEANT\", \"POLICE OFFICER\", \"FIRE ENGINEER-EMT\", \"FIRE FIGHTER-EMT\", \"CROSSING GUARD\", \"CROSSING GUARD\"],\n        :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484], x0to1),\n        :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38], x0to1))Then we partition employee data by departments:employee_col = BlockVector([1, 3, 5, 7], employee_elts)Adding a column of department names, we obtain HR data in a column-oriented format.TupleVector(\n    :name => [\"POLICE\", \"FIRE\", \"OEMC\"],\n    :employee => employee_col)Another way to assemble this data in column-oriented format is to use @VectorTree.@VectorTree (name = String,\n             employee = [(name = String,\n                          position = String,\n                          salary = (0:1)Int,\n                          rate = (0:1)Float64)]) [\n    (name = \"POLICE\",\n     employee = [(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing),\n                 (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016, rate = missing)]),\n    (name = \"FIRE\",\n     employee = [(name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing),\n                 (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484, rate = missing)]),\n    (name = \"OEMC\",\n     employee = [(name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68),\n                 (name = \"DORIS A\", position = \"CROSSING GUARD\", salary = missing, rate = 19.38)])\n]"
},

{
    "location": "vectors/#DataKnots.BlockVector",
    "page": "Column Store",
    "title": "DataKnots.BlockVector",
    "category": "type",
    "text": "BlockVector(offs::AbstractVector{Int}, elts::AbstractVector, card::Cardinality=x0toN)\nBlockVector(:, elts::AbstractVector, card::Cardinality=x1to1)\n\nVector of data blocks stored as a vector of elements partitioned by a vector of offsets.\n\nelts is a continuous vector of block elements.\noffs is a vector of indexes that subdivide elts into separate blocks. Should be monotonous with offs[1] == 1 and offs[end] == length(elts)+1. Use : if the offset vector is a unit range.\ncard is the cardinality constraint on the blocks.\n\n\n\n\n\n"
},

{
    "location": "vectors/#DataKnots.Cardinality",
    "page": "Column Store",
    "title": "DataKnots.Cardinality",
    "category": "type",
    "text": "x1to1::Cardinality\nx0to1::Cardinality\nx1toN::Cardinality\nx0toN::Cardinality\n\nCardinality constraints on a block of data.\n\n\n\n\n\n"
},

{
    "location": "vectors/#DataKnots.TupleVector",
    "page": "Column Store",
    "title": "DataKnots.TupleVector",
    "category": "type",
    "text": "TupleVector([lbls::Vector{Symbol},] len::Int, cols::Vector{AbstractVector})\nTupleVector([lbls::Vector{Symbol},] idxs::AbstractVector{Int}, cols::Vector{AbstractVector})\nTupleVector(lcols::Pair{<:Union{Symbol,AbstractString},<:AbstractVector}...)\n\nVector of tuples stored as a collection of column vectors.\n\ncols is a vector of columns; optional lbls is a vector of column labels. Alternatively, labels and columns could be provided as a list of pairs lcols.\nlen is the vector length, which must coincide with the length of all the columns.  Alternatively, the vector could be constructed from a subset of the column data using a vector of indexes idxs.\n\n\n\n\n\n"
},

{
    "location": "vectors/#Base.getindex-Tuple{DataKnots.BlockVector,AbstractArray{T,1} where T}",
    "page": "Column Store",
    "title": "Base.getindex",
    "category": "method",
    "text": "(::BlockVector)[ks::AbstractVector{Int}] :: BlockVector\n\nReturns a new BlockVector with a selection of blocks specified by indexes ks.\n\n\n\n\n\n"
},

{
    "location": "vectors/#Base.getindex-Tuple{DataKnots.TupleVector,AbstractArray{T,1} where T}",
    "page": "Column Store",
    "title": "Base.getindex",
    "category": "method",
    "text": "(::TupleVector)[ks::AbstractVector{Int}] :: TupleVector\n\nReturns a new TupleVector with a subset of rows specified by indexes ks.\n\n\n\n\n\n"
},

{
    "location": "vectors/#DataKnots.@VectorTree-Tuple{Any,Any}",
    "page": "Column Store",
    "title": "DataKnots.@VectorTree",
    "category": "macro",
    "text": "@VectorTree sig vec\n\nConstructs a tree of columnar vectors from a plain vector literal.\n\nThe first parameter, sig, describes the tree structure.  It is defined recursively:\n\nJulia type T indicates a regular vector of type T.\nTuple (col₁, col₂, ...) indicates a TupleVector instance.\nNamed tuple (lbl₁ = col₁, lbl₂ = col₂, ...) indicates a TupleVector instance with the given labels.\nPrefixes (0:N), (1:N), (0:1), (1:1) indicate a BlockVector instance with the respective cardinality constraints (no constraints, mandatory, singular, mandatory+singular).\n\nThe second parameter, vec, is a vector literal in row-oriented format:\n\nTupleVector data is specified either by a matrix or by a vector of (regular or named) tuples.\nBlockVector data is specified by a vector of vectors.  A one-element block could be represented by its element; an empty block by missing literal.\n\n\n\n\n\n"
},

{
    "location": "vectors/#API-Reference-1",
    "page": "Column Store",
    "title": "API Reference",
    "category": "section",
    "text": "Modules = [DataKnots]\nPages = [\"vectors.jl\"]"
},

{
    "location": "vectors/#Test-Suite-1",
    "page": "Column Store",
    "title": "Test Suite",
    "category": "section",
    "text": ""
},

{
    "location": "vectors/#TupleVector-1",
    "page": "Column Store",
    "title": "TupleVector",
    "category": "section",
    "text": "TupleVector is a vector of tuples stored as a collection of parallel vectors.tv = TupleVector(:name => [\"GARRY M\", \"ANTHONY R\", \"DANA A\"],\n                 :salary => [260004, 185364, 170112])\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\ndisplay(tv)\n#=>\n@VectorTree of 3 × (name = String, salary = Int):\n (name = \"GARRY M\", salary = 260004)\n (name = \"ANTHONY R\", salary = 185364)\n (name = \"DANA A\", salary = 170112)\n=#Labels could be specified by strings.TupleVector(:salary => [260004, 185364, 170112], \"#B\" => [true, false, false])\n#-> @VectorTree (salary = Int, \"#B\" = Bool) [(salary = 260004, #B = 1) … ]It is also possible to construct a TupleVector without labels.TupleVector(length(tv), columns(tv))\n#-> @VectorTree (String, Int) [(\"GARRY M\", 260004) … ]An error is reported in case of duplicate labels or columns of different height.TupleVector(:name => [\"GARRY M\", \"ANTHONY R\"],\n            :name => [\"DANA A\", \"JUAN R\"])\n#-> ERROR: duplicate column label :name\n\nTupleVector(:name => [\"GARRY M\", \"ANTHONY R\"],\n            :salary => [260004, 185364, 170112])\n#-> ERROR: unexpected column heightWe can access individual components of the vector.labels(tv)\n#-> Symbol[:name, :salary]\n\nwidth(tv)\n#-> 2\n\ncolumn(tv, 2)\n#-> [260004, 185364, 170112]\n\ncolumn(tv, :salary)\n#-> [260004, 185364, 170112]\n\ncolumns(tv)\n#-> …[[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [260004, 185364, 170112]]When indexed by another vector, we get a new instance of TupleVector.tv′ = tv[[3,1]]\ndisplay(tv′)\n#=>\n@VectorTree of 2 × (name = String, salary = Int):\n (name = \"DANA A\", salary = 170112)\n (name = \"GARRY M\", salary = 260004)\n=#Note that the new instance wraps the index and the original column vectors. Updated column vectors are generated on demand.column(tv′, 2)\n#-> [170112, 260004]"
},

{
    "location": "vectors/#Cardinality-1",
    "page": "Column Store",
    "title": "Cardinality",
    "category": "section",
    "text": "Enumerated type Cardinality is used to constrain the cardinality of a data block.  There are four different cardinality constraints: just one (1:1), zero or one (0:1), one or many (1:N), and zero or many (0:N).display(Cardinality)\n#=>\nEnum Cardinality:\nx1to1 = 0x00\nx0to1 = 0x01\nx1toN = 0x02\nx0toN = 0x03\n=#Cardinality values could be obtained from the matching symbols.convert(Cardinality, :x1toN)\n#-> x1toNCardinality values support bitwise operations.x1to1|x0to1|x1toN           #-> x0toN\nx1toN&~x1toN                #-> x1to1We can use predicates ismandatory() and issingular() to check if a constraint is present.ismandatory(x0to1)          #-> false\nismandatory(x1toN)          #-> true\nissingular(x1toN)           #-> false\nissingular(x0to1)           #-> true"
},

{
    "location": "vectors/#BlockVector-1",
    "page": "Column Store",
    "title": "BlockVector",
    "category": "section",
    "text": "BlockVector is a vector of homogeneous vectors (blocks) stored as a vector of elements partitioned into individual blocks by a vector of offsets.bv = BlockVector([1, 3, 5, 7], [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"])\n#-> @VectorTree (0:N) × String [[\"JEFFERY A\", \"NANCY A\"], [\"JAMES A\", \"DANIEL A\"], [\"LAKENYA A\", \"DORIS A\"]]\n\ndisplay(bv)\n#=>\n@VectorTree of 3 × (0:N) × String:\n [\"JEFFERY A\", \"NANCY A\"]\n [\"JAMES A\", \"DANIEL A\"]\n [\"LAKENYA A\", \"DORIS A\"]\n=#We can indicate that each block should contain at most one element or at least one element.BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38], x0to1)\n#-> @VectorTree (0:1) × Float64 [missing, missing, missing, missing, 17.68, 19.38]\n\nBlockVector([1, 3, 5, 7], [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"], x1toN)\n#-> @VectorTree (1:N) × String [[\"JEFFERY A\", \"NANCY A\"], [\"JAMES A\", \"DANIEL A\"], [\"LAKENYA A\", \"DORIS A\"]]If each block contains exactly one element, we could use : in place of the offset vector.BlockVector(:, [\"POLICE\", \"FIRE\", \"OEMC\"])\n#-> @VectorTree (1:1) × String [\"POLICE\", \"FIRE\", \"OEMC\"]The BlockVector constructor verifies that the offset vector is well-formed.BlockVector(Base.OneTo(0), [])\n#-> ERROR: offsets must be non-empty\n\nBlockVector(Int[], [])\n#-> ERROR: offsets must be non-empty\n\nBlockVector([0], [])\n#-> ERROR: offsets must start with 1\n\nBlockVector([1,2,2,1], [\"HEALTH\"])\n#-> ERROR: offsets must be monotone\n\nBlockVector(Base.OneTo(4), [\"HEALTH\", \"FINANCE\"])\n#-> ERROR: offsets must enclose the elements\n\nBlockVector([1,2,3,6], [\"HEALTH\", \"FINANCE\"])\n#-> ERROR: offsets must enclose the elementsThe constructor also validates the cardinality constraint.BlockVector([1, 3, 5, 7], [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"], x0to1)\n#-> ERROR: singular blocks must have at most one element\n\nBlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38], x1toN)\n#-> ERROR: mandatory blocks must have at least one elementWe can access individual components of the vector.offsets(bv)\n#-> [1, 3, 5, 7]\n\nelements(bv)\n#-> [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"]\n\ncardinality(bv)\n#-> x0toNWhen indexed by a vector of indexes, an instance of BlockVector is returned.elts = [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nreg_bv = BlockVector(:, elts)\n#-> @VectorTree (1:1) × String [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nopt_bv = BlockVector([1, 2, 3, 3, 4, 4, 5, 6, 6, 6, 7], elts, x0to1)\n#-> @VectorTree (0:1) × String [\"POLICE\", \"FIRE\", missing, \"HEALTH\", missing, \"AVIATION\", \"WATER MGMNT\", missing, missing, \"FINANCE\"]\n\nplu_bv = BlockVector([1, 1, 1, 2, 2, 4, 4, 6, 7], elts)\n#-> @VectorTree (0:N) × String [[], [], [\"POLICE\"], [], [\"FIRE\", \"HEALTH\"], [], [\"AVIATION\", \"WATER MGMNT\"], [\"FINANCE\"]]\n\nreg_bv[[1,3,5,3]]\n#-> @VectorTree (1:1) × String [\"POLICE\", \"HEALTH\", \"WATER MGMNT\", \"HEALTH\"]\n\nplu_bv[[1,3,5,3]]\n#-> @VectorTree (0:N) × String [[], [\"POLICE\"], [\"FIRE\", \"HEALTH\"], [\"POLICE\"]]\n\nreg_bv[Base.OneTo(4)]\n#-> @VectorTree (1:1) × String [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\"]\n\nreg_bv[Base.OneTo(6)]\n#-> @VectorTree (1:1) × String [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nplu_bv[Base.OneTo(6)]\n#-> @VectorTree (0:N) × String [[], [], [\"POLICE\"], [], [\"FIRE\", \"HEALTH\"], []]\n\nopt_bv[Base.OneTo(10)]\n#-> @VectorTree (0:1) × String [\"POLICE\", \"FIRE\", missing, \"HEALTH\", missing, \"AVIATION\", \"WATER MGMNT\", missing, missing, \"FINANCE\"]"
},

{
    "location": "vectors/#@VectorTree-1",
    "page": "Column Store",
    "title": "@VectorTree",
    "category": "section",
    "text": "We can use @VectorTree macro to convert vector literals to the columnar form assembled with TupleVector and BlockVector objects.TupleVector is created from a matrix or a vector of (named) tuples.@VectorTree (name = String, salary = Int) [\n    \"GARRY M\"   260004\n    \"ANTHONY R\" 185364\n    \"DANA A\"    170112\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\n@VectorTree (name = String, salary = Int) [\n    (\"GARRY M\", 260004),\n    (\"ANTHONY R\", 185364),\n    (\"DANA A\", 170112),\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\n@VectorTree (name = String, salary = Int) [\n    (name = \"GARRY M\", salary = 260004),\n    (name = \"ANTHONY R\", salary = 185364),\n    (name = \"DANA A\", salary = 170112),\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]Column labels are optional.@VectorTree (String, Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n#-> @VectorTree (String, Int) [(\"GARRY M\", 260004) … ]BlockVector is constructed from a vector of vector literals.  A one-element block could be represented by the element itself; an empty block by missing.@VectorTree [String] [\n    \"HEALTH\",\n    [\"FINANCE\", \"HUMAN RESOURCES\"],\n    missing,\n    [\"POLICE\", \"FIRE\"],\n]\n#-> @VectorTree (0:N) × String [[\"HEALTH\"], [\"FINANCE\", \"HUMAN RESOURCES\"], [], [\"POLICE\", \"FIRE\"]]Ill-formed @VectorTree constructors are rejected.@VectorTree \"String\" [\"POLICE\", \"FIRE\"]\n#=>\nERROR: expected a type; got \"String\"\n=#\n\n@VectorTree (String, Int) (\"GARRY M\", 260004)\n#=>\nERROR: LoadError: expected a vector literal; got :((\"GARRY M\", 260004))\n⋮\n=#\n\n@VectorTree (String, Int) [(position = \"SUPERINTENDENT OF POLICE\", salary = 260004)]\n#=>\nERROR: LoadError: expected no label; got :(position = \"SUPERINTENDENT OF POLICE\")\n⋮\n=#\n\n@VectorTree (name = String, salary = Int) [(position = \"SUPERINTENDENT OF POLICE\", salary = 260004)]\n#=>\nERROR: LoadError: expected label :name; got :(position = \"SUPERINTENDENT OF POLICE\")\n⋮\n=#\n\n@VectorTree (name = String, salary = Int) [(\"GARRY M\", \"SUPERINTENDENT OF POLICE\", 260004)]\n#=>\nERROR: LoadError: expected 2 column(s); got :((\"GARRY M\", \"SUPERINTENDENT OF POLICE\", 260004))\n⋮\n=#\n\n@VectorTree (name = String, salary = Int) [\"GARRY M\"]\n#=>\nERROR: LoadError: expected a tuple or a row literal; got \"GARRY M\"\n⋮\n=#Using @VectorTree, we can easily construct hierarchical data.hier_data = @VectorTree (name = (1:1)String, employee = (0:N)(name = (1:1)String, salary = (0:1)Int)) [\n    \"POLICE\"    [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n    \"FIRE\"      [\"JOSE S\" 202728; \"CHARLES S\" 197736]\n]\ndisplay(hier_data)\n#=>\n@VectorTree of 2 × (name = (1:1) × String,\n                    employee = (0:N) × (name = (1:1) × String,\n                                        salary = (0:1) × Int)):\n (name = \"POLICE\", employee = [(name = \"GARRY M\", salary = 260004) … ])\n (name = \"FIRE\", employee = [(name = \"JOSE S\", salary = 202728) … ])\n=#"
},

{
    "location": "pipelines/#",
    "page": "Pipeline Algebra",
    "title": "Pipeline Algebra",
    "category": "page",
    "text": ""
},

{
    "location": "pipelines/#Pipeline-Algebra-1",
    "page": "Pipeline Algebra",
    "title": "Pipeline Algebra",
    "category": "section",
    "text": ""
},

{
    "location": "pipelines/#Overview-1",
    "page": "Pipeline Algebra",
    "title": "Overview",
    "category": "section",
    "text": "This section describes the Pipeline interface of vectorized data transformations.  We will use the following definitions:using DataKnots:\n    @VectorTree,\n    Pipeline,\n    Runtime,\n    adapt_missing,\n    adapt_tuple,\n    adapt_vector,\n    block_any,\n    block_filler,\n    block_length,\n    block_lift,\n    chain_of,\n    column,\n    distribute,\n    distribute_all,\n    filler,\n    flatten,\n    lift,\n    null_filler,\n    pass,\n    sieve,\n    slice,\n    tuple_lift,\n    tuple_of,\n    with_column,\n    with_elements,\n    wrap,\n    x1toN"
},

{
    "location": "pipelines/#Lifting-and-fillers-1",
    "page": "Pipeline Algebra",
    "title": "Lifting and fillers",
    "category": "section",
    "text": "DataKnots stores structured data in a column-oriented format, serialized using specialized composite vector types.  Consequently, operations on data must also be adapted to the column-oriented format.In DataKnots, operations on column-oriented data are called pipelines.  A pipeline is a vectorized transformation: it takes a vector of input values and produces a vector of the same size containing output values.Any unary scalar function could be vectorized, which gives us a simple method for creating new pipelines.  Consider, for example, function titlecase(), which transforms the input string by capitalizing the first letter of each word and converting every other character to lowercase.titlecase(\"JEFFERY A\")      #-> \"Jeffery A\"This function can be converted to a pipeline or lifted, using the lift pipeline constructor.p = lift(titlecase)\np([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [\"Jeffery A\", \"James A\", \"Terry A\"]A scalar function with N arguments could be lifted by tuple_lift to make a pipeline that transforms a TupleVector with N columns.  For example, a binary predicate > gives rise to a pipeline tuple_lift(>) that transforms a TupleVector with two columns into a Boolean vector.p = tuple_lift(>)\np(@VectorTree (Int, Int) [260004 200000; 185364 200000; 170112 200000])\n#-> Bool[1, 0, 0]In a similar manner, a function with a vector argument can be lifted by block_lift to make a pipeline that expects a BlockVector input.  For example, function length(), which returns the length of a vector, could be converted to a pipeline block_lift(length) that transforms a block vector to an integer vector containing block lengths.p = block_lift(length)\np(@VectorTree [String] [[\"JEFFERY A\", \"NANCY A\"], [\"JAMES A\"]])\n#-> [2, 1]Not just functions, but also regular values could give rise to pipelines.  The filler constructor makes a pipeline from any scalar value.  This pipeline maps any input vector to a vector filled with the given scalar.p = filler(200000)\np([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [200000, 200000, 200000]Similarly, block_filler makes a pipeline from any vector value.  This pipeline produces a BlockVector filled with the given vector.p = block_filler([\"POLICE\", \"FIRE\"])\np([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree (0:N) × String [[\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"]]A variant of block_filler called null_filler makes a pipeline that produces a BlockVector filled with empty blocks.p = null_filler()\np([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree (0:1) × Bottom [missing, missing, missing]"
},

{
    "location": "pipelines/#Chaining-pipelines-1",
    "page": "Pipeline Algebra",
    "title": "Chaining pipelines",
    "category": "section",
    "text": "Given a series of pipelines, the chain_of constructor creates their composition pipeline, which transforms the input vector by sequentially applying the given pipelines.p = chain_of(lift(split), lift(first), lift(titlecase))\np([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [\"Jeffery\", \"James\", \"Terry\"]The degenerate composition of an empty sequence of pipelines has its own name, pass(). It passes its input to the output unchanged.chain_of()\n#-> pass()\n\np = pass()\np([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [\"JEFFERY A\", \"JAMES A\", \"TERRY A\"]In general, pipeline constructors that take one or more pipelines as arguments are called pipeline combinators.  Combinators are used to assemble elementary pipelines into complex pipeline expressions."
},

{
    "location": "pipelines/#Working-with-composite-vectors-1",
    "page": "Pipeline Algebra",
    "title": "Working with composite vectors",
    "category": "section",
    "text": "In DataKnots, composite data is represented as a tree of vectors with regular Vector objects at the leaves and composite vectors such as TupleVector and BlockVector at the intermediate nodes.  We demonstrated how to create and transform regular vectors using filler and lift.  Now let us show how to do the same with composite vectors.TupleVector is a vector of tuples composed of a sequence of column vectors. Any collection of vectors could be used as columns as long as they all have the same length.  One way to obtain N columns for a TupleVector is to apply N pipelines to the same input vector.  This is precisely the action of the tuple_of combinator.p = tuple_of(:first => chain_of(lift(split), lift(first), lift(titlecase)),\n             :last => lift(last))\np([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> @VectorTree (first = String, last = Char) [(first = \"Jeffery\", last = \'A\') … ]In the opposite direction, the column constructor makes a pipeline that extracts the specified column from the input TupleVector.p = column(:salary)\np(@VectorTree (name=String, salary=Int) [(\"JEFFERY A\", 101442), (\"JAMES A\", 103350), (\"TERRY A\", 93354)])\n#-> [101442, 103350, 93354]BlockVector is a vector of vectors serialized as a partitioned vector of elements.  Any input vector could be transformed to a BlockVector by the pipeline wrap(), which wraps the vector elements into one-element blocks.p = wrap()\np([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree (1:1) × String [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]Dual to wrap() is the pipeline flatten(), which transforms a nested BlockVector by flattening its nested blocks.p = flatten()\np(@VectorTree [[String]] [[[\"GARRY M\"], [\"ANTHONY R\", \"DANA A\"]], [[], [\"JOSE S\"], [\"CHARLES S\"]]])\n#-> @VectorTree (0:N) × String [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]]The distribute constructor makes a pipeline that rearranges a TupleVector with a specified BlockVector column.  Specifically, it takes each tuple, where a specific field must contain a block value, and transforms it to a block of tuples by distributing the block value over the tuple.p = distribute(:employee)\np(@VectorTree (department = String, employee = [String]) [\n    \"POLICE\"    [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]\n    \"FIRE\"      [\"JOSE S\", \"CHARLES S\"]]) |> display\n#=>\n@VectorTree of 2 × (0:N) × (department = String, employee = String):\n [(department = \"POLICE\", employee = \"GARRY M\"), (department = \"POLICE\", employee = \"ANTHONY R\"), (department = \"POLICE\", employee = \"DANA A\")]\n [(department = \"FIRE\", employee = \"JOSE S\"), (department = \"FIRE\", employee = \"CHARLES S\")]\n=#Often we need to transform only a part of a composite vector, leaving the rest of the structure intact.  This can be achieved using with_column and with_elements combinators.  Specifically, with_column transforms a specific column of a TupleVector while with_elements transforms the vector of elements of a BlockVector.p = with_column(:employee, with_elements(lift(titlecase)))\np(@VectorTree (department = String, employee = [String]) [\n    \"POLICE\"    [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]\n    \"FIRE\"      [\"JOSE S\", \"CHARLES S\"]]) |> display\n#=>\n@VectorTree of 2 × (department = String, employee = (0:N) × String):\n (department = \"POLICE\", employee = [\"Garry M\", \"Anthony R\", \"Dana A\"])\n (department = \"FIRE\", employee = [\"Jose S\", \"Charles S\"])\n=#"
},

{
    "location": "pipelines/#Specialized-pipelines-1",
    "page": "Pipeline Algebra",
    "title": "Specialized pipelines",
    "category": "section",
    "text": "Not every data transformation can be implemented with lifting.  DataKnots provide pipeline constructors for some common transformation tasks.For example, data filtering is implemented with the pipeline sieve().  As input, it expects a TupleVector of pairs containing a value and a Bool flag.  sieve() transforms the input to a BlockVector containing 0- and 1-element blocks.  When the flag is false, it is mapped to an empty block, otherwise, it is mapped to a one-element block containing the data value.p = sieve()\np(@VectorTree (String, Bool) [(\"JEFFERY A\", true), (\"JAMES A\", true), (\"TERRY A\", false)])\n#-> @VectorTree (0:1) × String [\"JEFFERY A\", \"JAMES A\", missing]If DataKnots does not provide a specific transformation, it is easy to create a new one.  For example, let us create a pipeline constructor double which makes a pipeline that doubles the elements of the input vector.We need to provide two definitions: to create a Pipeline object and to perform the tranformation on the given input vector.double() = Pipeline(double)\ndouble(::Runtime, input::AbstractVector{<:Number}) = input .* 2\n\np = double()\np([260004, 185364, 170112])\n#-> [520008, 370728, 340224]It is also easy to create new pipeline combinators.  Let us create a combinator twice, which applies the given pipeline to the input two times.twice(p) = Pipeline(twice, p)\ntwice(rt::Runtime, input, p) = p(rt, p(rt, input))\n\np = twice(double())\np([260004, 185364, 170112])\n#-> [1040016, 741456, 680448]"
},

{
    "location": "pipelines/#DataKnots.Pipeline",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Pipeline",
    "category": "type",
    "text": "Pipeline(op, args...)\n\nA pipeline object represents a vectorized data transformation.\n\nParameter op is a function that performs the transformation; args are extra arguments to be passed to the function.\n\nThe pipeline transforms any input vector by invoking op with the following arguments:\n\nop(rt::Runtime, input::AbstractVector, args...)\n\nThe result of op must be the output vector, which should be of the same length as the input vector.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Runtime",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Runtime",
    "category": "type",
    "text": "Runtime()\n\nRuntime state for pipeline evaluation.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.adapt_missing-Tuple{}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.adapt_missing",
    "category": "method",
    "text": "adapt_missing() :: Pipeline\n\nThis pipeline transforms a vector that contains missing elements to a block vector with missing elements replaced by empty blocks.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.adapt_tuple-Tuple{}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.adapt_tuple",
    "category": "method",
    "text": "adapt_tuple() :: Pipeline\n\nThis pipeline transforms a vector of tuples to a tuple vector.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.adapt_vector-Tuple{}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.adapt_vector",
    "category": "method",
    "text": "adapt_vector() :: Pipeline\n\nThis pipeline transforms a vector with vector elements to a block vector.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.block_any-Tuple{}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.block_any",
    "category": "method",
    "text": "block_any() :: Pipeline\n\nThis pipeline applies any to a block vector with Bool elements.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.block_filler",
    "page": "Pipeline Algebra",
    "title": "DataKnots.block_filler",
    "category": "function",
    "text": "block_filler(block::AbstractVector, card::Cardinality) :: Pipeline\n\nThis pipeline produces a block vector filled with the given block.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.block_length-Tuple{}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.block_length",
    "category": "method",
    "text": "block_length() :: Pipeline\n\nThis pipeline converts a block vector to a vector of block lengths.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.block_lift",
    "page": "Pipeline Algebra",
    "title": "DataKnots.block_lift",
    "category": "function",
    "text": "block_lift(f) :: Pipeline\nblock_lift(f, default) :: Pipeline\n\nf is a function that expects a vector argument.\n\nThe pipeline applies f to each block of the input block vector.  When a block is empty, default (if specified) is used as the output value.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.chain_of",
    "page": "Pipeline Algebra",
    "title": "DataKnots.chain_of",
    "category": "function",
    "text": "chain_of(p₁::Pipeline, p₂::Pipeline … pₙ::Pipeline) :: Pipeline\n\nThis pipeline sequentially applies p₁, p₂ … pₙ.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.column-Tuple{Union{Int64, Symbol}}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.column",
    "category": "method",
    "text": "column(lbl::Union{Int,Symbol}) :: Pipeline\n\nThis pipeline extracts the specified column of a tuple vector.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.designate",
    "page": "Pipeline Algebra",
    "title": "DataKnots.designate",
    "category": "function",
    "text": "designate(::Pipeline, ::Signature) :: Pipeline\ndesignate(::Pipeline, ::AbstractShape, ::AbstractShape) :: Pipeline\np::Pipeline |> designate(::Signature) :: Pipeline\np::Pipeline |> designate(::AbstractShape, ::AbstractShape) :: Pipeline\n\nSets the pipeline signature.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.distribute-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.distribute",
    "category": "method",
    "text": "distribute(lbl::Union{Int,Symbol}) :: Pipeline\n\nThis pipeline transforms a tuple vector with a column of blocks to a block vector with tuple elements.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.distribute_all-Tuple{}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.distribute_all",
    "category": "method",
    "text": "distribute_all() :: Pipeline\n\nThis pipeline transforms a tuple vector with block columns to a block vector with tuple elements.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.filler-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.filler",
    "category": "method",
    "text": "filler(val) :: Pipeline\n\nThis pipeline produces a vector filled with the given value.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.flatten-Tuple{}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.flatten",
    "category": "method",
    "text": "flatten() :: Pipeline\n\nThis pipeline flattens a nested block vector.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.lift-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.lift",
    "category": "method",
    "text": "lift(f) :: Pipeline\n\nf is any scalar unary function.\n\nThe pipeline applies f to each element of the input vector.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.null_filler-Tuple{}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.null_filler",
    "category": "method",
    "text": "null_filler() :: Pipeline\n\nThis pipeline produces a block vector with empty blocks.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.optimize-Tuple{DataKnots.Pipeline}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.optimize",
    "category": "method",
    "text": "optimize(::Pipeline) :: Pipeline\n\nRewrites the pipeline to make it (hopefully) faster.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.pass-Tuple{}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.pass",
    "category": "method",
    "text": "pass() :: Pipeline\n\nThis pipeline returns its input unchanged.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.sieve-Tuple{}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.sieve",
    "category": "method",
    "text": "sieve() :: Pipeline\n\nThis pipeline filters a vector of pairs by the second column.  It expects a pair vector, whose second column is a Bool vector, and produces a block vector with 0- or 1-element blocks containing the elements of the first column.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.signature-Tuple{DataKnots.Pipeline}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.signature",
    "category": "method",
    "text": "signature(::Pipeline) :: Signature\n\nReturns the pipeline signature.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.slice",
    "page": "Pipeline Algebra",
    "title": "DataKnots.slice",
    "category": "function",
    "text": "slice(N::Int, rev::Bool=false) :: Pipeline\n\nThis pipeline transforms a block vector by keeping the first N elements of each block.  If rev is true, the pipeline drops the first N elements of each block.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.slice",
    "page": "Pipeline Algebra",
    "title": "DataKnots.slice",
    "category": "function",
    "text": "slice(rev::Bool=false) :: Pipeline\n\nThis pipeline takes a pair vector of blocks and integers, and returns the first column with blocks restricted by the second column.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.tuple_lift-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.tuple_lift",
    "category": "method",
    "text": "tuple_lift(f) :: Pipeline\n\nf is an n-ary function.\n\nThe pipeline applies f to each row of an n-tuple vector.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.tuple_of-Tuple",
    "page": "Pipeline Algebra",
    "title": "DataKnots.tuple_of",
    "category": "method",
    "text": "tuple_of(p₁::Pipeline, p₂::Pipeline … pₙ::Pipeline) :: Pipeline\n\nThis pipeline produces an n-tuple vector, whose columns are generated by applying p₁, p₂ … pₙ to the input vector.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.with_column-Tuple{Union{Int64, Symbol},Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.with_column",
    "category": "method",
    "text": "with_column(lbl::Union{Int,Symbol}, p::Pipeline) :: Pipeline\n\nThis pipeline transforms a tuple vector by applying p to the specified column.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.with_elements-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.with_elements",
    "category": "method",
    "text": "with_elements(p::Pipeline) :: Pipeline\n\nThis pipeline transforms a block vector by applying p to its vector of elements.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.wrap-Tuple{}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.wrap",
    "category": "method",
    "text": "wrap() :: Pipeline\n\nThis pipeline produces a block vector with one-element blocks wrapping the values of the input vector.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#API-Reference-1",
    "page": "Pipeline Algebra",
    "title": "API Reference",
    "category": "section",
    "text": "Modules = [DataKnots]\nPages = [\"pipelines.jl\"]"
},

{
    "location": "pipelines/#Test-Suite-1",
    "page": "Pipeline Algebra",
    "title": "Test Suite",
    "category": "section",
    "text": ""
},

{
    "location": "pipelines/#Lifting-1",
    "page": "Pipeline Algebra",
    "title": "Lifting",
    "category": "section",
    "text": "The lift constructor makes a pipeline by vectorizing a unary function.p = lift(titlecase)\n#-> lift(titlecase)\n\np([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [\"Garry M\", \"Anthony R\", \"Dana A\"]The block_lift constructor makes a pipeline on block vectors by vectorizing a unary vector function.p = block_lift(length)\n#-> block_lift(length)\n\np(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]])\n#-> [3, 2]Some vector functions may expect a non-empty vector as an argument.  In this case, we should provide the value to replace empty blocks.p = block_lift(maximum, missing)\n#-> block_lift(maximum, missing)\n\np(@VectorTree [Int] [[260004, 185364, 170112], [], [202728, 197736]])\n#-> Union{Missing, Int}[260004, missing, 202728]The tuple_lift constructor makes a pipeline on tuple vectors by vectorizing a function of several arguments.p = tuple_lift(>)\n#-> tuple_lift(>)\n\np(@VectorTree (Int, Int) [260004 200000; 185364 200000; 170112 200000])\n#-> Bool[1, 0, 0]"
},

{
    "location": "pipelines/#Fillers-1",
    "page": "Pipeline Algebra",
    "title": "Fillers",
    "category": "section",
    "text": "The pipeline filler(val) ignores its input and produces a vector filled with val.p = filler(200000)\n#-> filler(200000)\n\np([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [200000, 200000, 200000]The pipeline block_filler(blk, card) produces a block vector filled with the given block.p = block_filler([\"POLICE\", \"FIRE\"], x1toN)\n#-> block_filler([\"POLICE\", \"FIRE\"], x1toN)\n\np([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree (1:N) × String [[\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"]]The pipeline null_filler() produces a block vector with empty blocks.p = null_filler()\n#-> null_filler()\n\np([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree (0:1) × Bottom [missing, missing, missing]"
},

{
    "location": "pipelines/#Adapting-row-oriented-data-1",
    "page": "Pipeline Algebra",
    "title": "Adapting row-oriented data",
    "category": "section",
    "text": "The pipeline adapt_missing() transforms a vector containing missing values to a block vector with missing replaced by an empty block and other values wrapped in 1-element block.p = adapt_missing()\n#-> adapt_missing()\n\np([260004, 185364, 170112, missing, 202728, 197736])\n#-> @VectorTree (0:1) × Int [260004, 185364, 170112, missing, 202728, 197736]The pipeline adapt_vector() transforms a vector of vectors to a block vector.p = adapt_vector()\n#-> adapt_vector()\n\np([[260004, 185364, 170112], Int[], [202728, 197736]])\n#-> @VectorTree (0:N) × Int [[260004, 185364, 170112], [], [202728, 197736]]The pipeline adapt_tuple() transforms a vector of tuples to a tuple vector.p = adapt_tuple()\n#-> adapt_tuple()\n\np([(\"GARRY M\", 260004), (\"ANTHONY R\", 185364), (\"DANA A\", 170112)]) |> display\n#=>\n@VectorTree of 3 × (String, Int):\n (\"GARRY M\", 260004)\n (\"ANTHONY R\", 185364)\n (\"DANA A\", 170112)\n=#Vectors of named tuples are also supported.p([(name=\"GARRY M\", salary=260004), (name=\"ANTHONY R\", salary=185364), (name=\"DANA A\", salary=170112)]) |> display\n#=>\n@VectorTree of 3 × (name = String, salary = Int):\n (name = \"GARRY M\", salary = 260004)\n (name = \"ANTHONY R\", salary = 185364)\n (name = \"DANA A\", salary = 170112)\n=#"
},

{
    "location": "pipelines/#Composition-1",
    "page": "Pipeline Algebra",
    "title": "Composition",
    "category": "section",
    "text": "The chain_of combinator composes a sequence of pipelines.p = chain_of(lift(split), lift(first), lift(titlecase))\n#-> chain_of(lift(split), lift(first), lift(titlecase))\n\np([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [\"Jeffery\", \"James\", \"Terry\"]The empty chain chain_of() has an alias pass().p = pass()\n#-> pass()\n\np([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]"
},

{
    "location": "pipelines/#Tuple-vectors-1",
    "page": "Pipeline Algebra",
    "title": "Tuple vectors",
    "category": "section",
    "text": "The pipeline tuple_of(p₁, p₂ … pₙ) produces a tuple vector, whose columns are generated by applying p₁, p₂ … pₙ to the input vector.p = tuple_of(:title => lift(titlecase), :last => lift(last))\n#-> tuple_of(:title => lift(titlecase), :last => lift(last))\n\np([\"GARRY M\", \"ANTHONY R\", \"DANA A\"]) |> display\n#=>\n@VectorTree of 3 × (title = String, last = Char):\n (title = \"Garry M\", last = \'M\')\n (title = \"Anthony R\", last = \'R\')\n (title = \"Dana A\", last = \'A\')\n=#The pipeline column(lbl) extracts the specified column from a tuple vector.  The column constructor accepts either the column position or the column label.p = column(1)\n#-> column(1)\n\np(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112])\n#-> [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]\n\np = column(:salary)\n#-> column(:salary)\n\np(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112])\n#-> [260004, 185364, 170112]The with_column combinator lets us apply the given pipeline to a selected column of a tuple vector.p = with_column(:name, lift(titlecase))\n#-> with_column(:name, lift(titlecase))\n\np(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]) |> display\n#=>\n@VectorTree of 3 × (name = String, salary = Int):\n (name = \"Garry M\", salary = 260004)\n (name = \"Anthony R\", salary = 185364)\n (name = \"Dana A\", salary = 170112)\n=#"
},

{
    "location": "pipelines/#Block-vectors-1",
    "page": "Pipeline Algebra",
    "title": "Block vectors",
    "category": "section",
    "text": "The pipeline wrap() wraps the elements of the input vector to one-element blocks.p = wrap()\n#-> wrap()\n\np([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n@VectorTree (1:1) × String [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]The pipeline flatten() flattens a nested block vector.p = flatten()\n#-> flatten()\n\np(@VectorTree [[String]] [[[\"GARRY M\"], [\"ANTHONY R\", \"DANA A\"]], [missing, [\"JOSE S\"], [\"CHARLES S\"]]])\n@VectorTree (0:N) × String [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]]The with_elements combinator lets us apply the given pipeline to transform the elements of a block vector.p = with_elements(lift(titlecase))\n#-> with_elements(lift(titlecase))\n\np(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]])\n@VectorTree (0:N) × String [[\"Garry M\", \"Anthony R\", \"Dana A\"], [\"Jose S\", \"Charles S\"]]The pipeline distribute(lbl) transforms a tuple vector with a certain block column to a block vector of tuples by distributing the block elements over the tuple.p = distribute(1)\n#-> distribute(1)\n\np(@VectorTree ([Int], [Int]) [\n    [260004, 185364, 170112]    200000\n    missing                     200000\n    [202728, 197736]            [200000, 200000]]\n) |> display\n#=>\n@VectorTree of 3 × (0:N) × (Int, (0:N) × Int):\n [(260004, [200000]), (185364, [200000]), (170112, [200000])]\n []\n [(202728, [200000, 200000]), (197736, [200000, 200000])]\n=#The pipeline distribute_all() takes a tuple vector with block columns and distribute all of the block columns.p = distribute_all()\n#-> distribute_all()\n\np(@VectorTree ([Int], [Int]) [\n    [260004, 185364, 170112]    200000\n    missing                     200000\n    [202728, 197736]            [200000, 200000]]\n) |> display\n#=>\n@VectorTree of 3 × (0:N) × (Int, Int):\n [(260004, 200000), (185364, 200000), (170112, 200000)]\n []\n [(202728, 200000), (202728, 200000), (197736, 200000), (197736, 200000)]\n=#This pipeline is equivalent to chain_of(distribute(1), with_elements(distribute(2)), flatten()).The pipeline block_length() calculates the lengths of blocks in a block vector.p = block_length()\n#-> block_length()\n\np(@VectorTree [String] [missing, \"GARRY M\", [\"ANTHONY R\", \"DANA A\"]])\n#-> [0, 1, 2]The pipeline block_any() checks whether the blocks in a Bool block vector have any true values.p = block_any()\n#-> block_any()\n\np(@VectorTree [Bool] [missing, true, false, [true, false], [false, false], [false, true]])\n#-> Bool[0, 1, 0, 1, 0, 1]"
},

{
    "location": "pipelines/#Filtering-1",
    "page": "Pipeline Algebra",
    "title": "Filtering",
    "category": "section",
    "text": "The pipeline sieve() filters a vector of pairs by the second column.p = sieve()\n#-> sieve()\n\np(@VectorTree (Int, Bool) [260004 true; 185364 false; 170112 false])\n#-> @VectorTree (0:1) × Int [260004, missing, missing]"
},

{
    "location": "pipelines/#Slicing-1",
    "page": "Pipeline Algebra",
    "title": "Slicing",
    "category": "section",
    "text": "The pipeline slice(N) transforms a block vector by keeping the first N elements of each block.p = slice(2)\n#-> slice(2, false)\n\np(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"], missing])\n#-> @VectorTree (0:N) × String [[\"GARRY M\", \"ANTHONY R\"], [\"JOSE S\", \"CHARLES S\"], []]When N is negative, slice(N) drops the last -N elements of each block.p = slice(-1)\n\np(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"], missing])\n#-> @VectorTree (0:N) × String [[\"GARRY M\", \"ANTHONY R\"], [\"JOSE S\"], []]The pipeline slice(N, true) drops the first N elements (or keeps the last -N elements if N is negative).p = slice(2, true)\n\np(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"], missing])\n#-> @VectorTree (0:N) × String [[\"DANA A\"], [], []]\n\np = slice(-1, true)\n\np(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"], missing])\n#-> @VectorTree (0:N) × String [[\"DANA A\"], [\"CHARLES S\"], []]A variant of this pipeline slice() expects a tuple vector with two columns: the first column containing the blocks and the second column with the number of elements to keep.p = slice()\n#-> slice(false)\n\np(@VectorTree ([String], Int) [([\"GARRY M\", \"ANTHONY R\", \"DANA A\"], 1), ([\"JOSE S\", \"CHARLES S\"], -1), (missing, 0)])\n#-> @VectorTree (0:N) × String [[\"GARRY M\"], [\"JOSE S\"], []]"
},

{
    "location": "shapes/#",
    "page": "Shapes and Signatures",
    "title": "Shapes and Signatures",
    "category": "page",
    "text": ""
},

{
    "location": "shapes/#Shapes-and-Signatures-1",
    "page": "Shapes and Signatures",
    "title": "Shapes and Signatures",
    "category": "section",
    "text": ""
},

{
    "location": "shapes/#Overview-1",
    "page": "Shapes and Signatures",
    "title": "Overview",
    "category": "section",
    "text": "To describe data shapes and pipeline signatures, we need the following definitions.using DataKnots:\n    @VectorTree,\n    AnyShape,\n    BlockOf,\n    BlockVector,\n    IsFlow,\n    IsLabeled,\n    IsScope,\n    NoShape,\n    Signature,\n    TupleOf,\n    TupleVector,\n    ValueOf,\n    cardinality,\n    chain_of,\n    column,\n    columns,\n    compose,\n    context,\n    designate,\n    domain,\n    elements,\n    fits,\n    label,\n    labels,\n    replace_column,\n    replace_elements,\n    shapeof,\n    signature,\n    source,\n    subject,\n    target,\n    tuple_lift,\n    tuple_of,\n    wrap,\n    x0to1,\n    x0toN,\n    x1to1,\n    x1toN"
},

{
    "location": "shapes/#Data-shapes-1",
    "page": "Shapes and Signatures",
    "title": "Data shapes",
    "category": "section",
    "text": "In DataKnots, the structure of composite data is represented using shape objects.For example, consider a collection of departments with associated employees.depts =\n    @VectorTree (name = (1:1)String,\n                 employee = (1:N)(name = (1:1)String,\n                                  position = (1:1)String,\n                                  salary = (0:1)Int,\n                                  rate = (0:1)Float64)) [\n        (name = \"POLICE\",\n         employee = [(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing),\n                     (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016, rate = missing)]),\n        (name = \"FIRE\",\n         employee = [(name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing),\n                     (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484, rate = missing)]),\n        (name = \"OEMC\",\n         employee = [(name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68),\n                     (name = \"DORIS A\", position = \"CROSSING GUARD\", salary = missing, rate = 19.38)])\n    ]In this collection, each department record has two fields: name and employee.  Each employee record has four fields: name, position, salary, and rate.  The employee field is plural; salary and rate are optional.Physically, this collection is stored as a tree of interleaving TupleVector and BlockVector objects with regular Vector objects as the leaves.  Its structure is described by a congruent tree composed of TupleOf, BlockOf and ValueOf objects.ValueOf corresponds to regular Julia Vector objects and specifies the type of the vector elements.ValueOf(String)\n#-> ValueOf(String)BlockOf specifies the shape of the elements and the cardinality of a BlockVector.  As a shorthand, a regular Julia type is accepted in place of a ValueOf shape, and the cardinality x0toN is assumed by default.BlockOf(ValueOf(String), x1to1)\n#-> BlockOf(String, x1to1)TupleOf describes a TupleVector object with the given labels and the shapes of the columns.emp_shp = TupleOf(:name => BlockOf(String, x1to1),\n                  :position => BlockOf(String, x1to1),\n                  :salary => BlockOf(Int, x0to1),\n                  :rate => BlockOf(Float64, x0to1))Using nested shape objects, we can accurately specify the structure of a nested collection.dept_shp = TupleOf(:name => BlockOf(String, x1to1),\n                   :employee => BlockOf(emp_shp, x1toN))\n#=>\nTupleOf(:name => BlockOf(String, x1to1),\n        :employee => BlockOf(TupleOf(:name => BlockOf(String, x1to1),\n                                     :position => BlockOf(String, x1to1),\n                                     :salary => BlockOf(Int, x0to1),\n                                     :rate => BlockOf(Float64, x0to1)),\n                             x1toN))\n=#"
},

{
    "location": "shapes/#Traversing-nested-data-1",
    "page": "Shapes and Signatures",
    "title": "Traversing nested data",
    "category": "section",
    "text": "A record field gives rise to a pipeline that maps the records to the field values.  For example, the field employee corresponds to a pipeline which maps a collection of departments to associated employees.dept_employee = column(:employee)\n\ndept_employee(depts) |> display\n#=>\n@VectorTree of 3 × (1:N) × (name = (1:1) × String,\n                            position = (1:1) × String,\n                            salary = (0:1) × Int,\n                            rate = (0:1) × Float64):\n [(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing), (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016, rate = missing)]\n [(name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing), (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484, rate = missing)]\n [(name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68), (name = \"DORIS A\", position = \"CROSSING GUARD\", salary = missing, rate = 19.38)]\n=#The expected input and output of a pipeline can be specified by its signature.dept_employee =\n    dept_employee |> designate(dept_shp, BlockOf(emp_shp, x1toN) |> IsFlow)Here, we also annotate the output shape with IsFlow to indicate its special role in pipeline composition.Two adjacent field pipelines may form a path.  For example, consider the rate pipeline.emp_rate =\n    column(:rate) |> designate(emp_shp, BlockOf(Float64, x0to1) |> IsFlow)\n\nsignature(emp_rate)\n#=>\nSignature(TupleOf(:name => BlockOf(String, x1to1),\n                  :position => BlockOf(String, x1to1),\n                  :salary => BlockOf(Int, x0to1),\n                  :rate => BlockOf(Float64, x0to1)),\n          BlockOf(Float64, x0to1) |> IsFlow)\n=#We wish to form a path through the fields employee and rate.  However, the pipelines dept_employee and emp_rate cannot be chained into chain_of(dept_employee, emp_rate) because their intermediate shapes do not match.fits(target(dept_employee), source(emp_rate))   #-> falseOn the other hand, these pipelines could be composed using the elementwise composition combinator.dept_employee_rate = compose(dept_employee, emp_rate)\n#-> chain_of(column(:employee), chain_of(with_elements(column(:rate)), flatten()))\n\ndept_employee_rate(depts)\n#-> @VectorTree (0:N) × Float64 [[], [], [17.68, 19.38]]\n\nsignature(dept_employee_rate)\n#=>\nSignature(TupleOf(:name => BlockOf(String, x1to1),\n                  :employee =>\n                      BlockOf(TupleOf(:name => BlockOf(String, x1to1),\n                                      :position => BlockOf(String, x1to1),\n                                      :salary => BlockOf(Int, x0to1),\n                                      :rate => BlockOf(Float64, x0to1)),\n                              x1toN)),\n          BlockOf(Float64) |> IsFlow)\n=#Elementwise composition connects the pipelines by fusing their output flows. The least upper bound of the flow cardinalities is the cardinality of the fused flow.dept_employee_card = cardinality(target(dept_employee))\n#-> x1toN\n\nemp_rate_card = cardinality(target(emp_rate))\n#-> x0to1\n\ndept_employee_rate_card = cardinality(target(dept_employee_rate))\n#-> x0toN\n\ndept_employee_card|emp_rate_card == dept_employee_rate_card\n#-> true"
},

{
    "location": "shapes/#Flow-and-scope-1",
    "page": "Shapes and Signatures",
    "title": "Flow and scope",
    "category": "section",
    "text": "Elementwise composition is a sequential composition with special handling of two types of containers: flow and scope.The flow is a BlockVector that wraps the output of the pipeline.  When two pipelines are composed, their output flows are fused together.The scope is a TupleVector that augments the input data with extra context parameters.  When pipelines are composed, the context is passed along the composition.For example, consider a pipeline that wraps the function round and expects the precision to be passed as a context parameter :P.round_digits(x, d) = round(x, digits=d)\n\nround_it =\n    chain_of(\n        tuple_of(chain_of(column(1)),\n                 chain_of(column(2), column(:P))),\n        tuple_lift(round_digits),\n        wrap())\n\nround_it(@VectorTree (Float64, (P = (1:1)Int,)) [(17.68, (P = 1,)), (19.38, (P = 1,))])\n#-> @VectorTree (1:1) × Float64 [17.7, 19.4]To be able to use this pipeline in composition, we assign it its signature.round_it =\n    round_it |> designate(TupleOf(Float64, TupleOf(:P => Float64)) |> IsScope,\n                          BlockOf(Float64, x1to1) |> IsFlow)When two pipelines have compatible intermediate domains, they could be composed.domain(target(dept_employee_rate))\n#-> ValueOf(Float64)\n\ndomain(source(round_it))\n#-> ValueOf(Float64)\n\ndept_employee_round_rate = compose(dept_employee_rate, round_it)The composition also has a signature assigned to it.  The input of the composition should contain the department data together with a parameter P.signature(dept_employee_round_rate)\n#=>\nSignature(TupleOf(TupleOf(:name => BlockOf(String, x1to1),\n                          :employee =>\n                              BlockOf(TupleOf(\n                                          :name => BlockOf(String, x1to1),\n                                          :position => BlockOf(String, x1to1),\n                                          :salary => BlockOf(Int, x0to1),\n                                          :rate => BlockOf(Float64, x0to1)),\n                                      x1toN)),\n                  TupleOf(:P => Float64)) |>\n          IsScope,\n          BlockOf(Float64) |> IsFlow)\n=#To run this pipeline, we pack the input data together with parameters.slots = @VectorTree (P = Int,) [(P = 1,), (P = 1,), (P = 1,)]\n\ninput = TupleVector(:depts => depts, :slots => slots)\n\ndept_employee_round_rate(input)\n#-> @VectorTree (0:N) × Float64 [[], [], [17.7, 19.4]]"
},

{
    "location": "shapes/#DataKnots.AbstractShape",
    "page": "Shapes and Signatures",
    "title": "DataKnots.AbstractShape",
    "category": "type",
    "text": "AbstractShape\n\nDescribes the structure of column-oriented data.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.AnyShape",
    "page": "Shapes and Signatures",
    "title": "DataKnots.AnyShape",
    "category": "type",
    "text": "AnyShape()\n\nNothing is known about the data.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.BlockOf",
    "page": "Shapes and Signatures",
    "title": "DataKnots.BlockOf",
    "category": "type",
    "text": "BlockOf(elts::AbstractShape, card::Cardinality=x0toN)\n\nShape of a BlockVector.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.IsLabeled",
    "page": "Shapes and Signatures",
    "title": "DataKnots.IsLabeled",
    "category": "type",
    "text": "sub |> IsLabeled(::Symbol)\n\nThe shape has an attached label.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.NoShape",
    "page": "Shapes and Signatures",
    "title": "DataKnots.NoShape",
    "category": "type",
    "text": "NoShape()\n\nInconsistent constraints on the data.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.Signature",
    "page": "Shapes and Signatures",
    "title": "DataKnots.Signature",
    "category": "type",
    "text": "Signature(::AbstractShape, ::AbstractShape)\n\nShapes of a pipeline source and tagret.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.fits",
    "page": "Shapes and Signatures",
    "title": "DataKnots.fits",
    "category": "function",
    "text": "fits(x::T, y::T) :: Bool\n\nChecks if constraint x implies constraint y.\n\n\n\n\n\n"
},

{
    "location": "shapes/#API-Reference-1",
    "page": "Shapes and Signatures",
    "title": "API Reference",
    "category": "section",
    "text": "Modules = [DataKnots]\nPages = [\"shapes.jl\"]"
},

{
    "location": "shapes/#Test-Suite-1",
    "page": "Shapes and Signatures",
    "title": "Test Suite",
    "category": "section",
    "text": ""
},

{
    "location": "shapes/#Cardinality-1",
    "page": "Shapes and Signatures",
    "title": "Cardinality",
    "category": "section",
    "text": "Cardinality constraints are partially ordered.  For two Cardinality constraints, we can determine whether one is more strict than the other.fits(x0to1, x1toN)          #-> false\nfits(x1to1, x0toN)          #-> true"
},

{
    "location": "shapes/#Data-shapes-2",
    "page": "Shapes and Signatures",
    "title": "Data shapes",
    "category": "section",
    "text": "The structure of composite data is specified with shape objects.A regular vector containing values of a specific type is indicated by the ValueOf shape.str_shp = ValueOf(String)\n#-> ValueOf(String)\n\neltype(str_shp)\n#-> StringThe structure of a BlockVector object is described using BlockOf shape.rate_shp = BlockOf(Float64, x0to1)\n#-> BlockOf(Float64, x0to1)\n\ncardinality(rate_shp)\n#-> x0to1\n\nelements(rate_shp)\n#-> ValueOf(Float64)\n\neltype(rate_shp)\n#-> Union{Missing, Float64}For a TupleVector, the column shapes and their labels are described with TupleOf.emp_shp = TupleOf(:name => BlockOf(String, x1to1),\n                  :position => BlockOf(String, x1to1),\n                  :salary => BlockOf(Int, x0to1),\n                  :rate => BlockOf(Float64, x0to1))\n#=>\nTupleOf(:name => BlockOf(String, x1to1),\n        :position => BlockOf(String, x1to1),\n        :salary => BlockOf(Int, x0to1),\n        :rate => BlockOf(Float64, x0to1))\n=#\n\nlabels(emp_shp)\n#-> Symbol[:name, :position, :salary, :rate]\n\nlabel(emp_shp, 4)\n#-> :rate\n\ncolumns(emp_shp)\n#-> DataKnots.AbstractShape[BlockOf(String, x1to1), BlockOf(String, x1to1), BlockOf(Int, x0to1), BlockOf(Float64, x0to1)]\n\ncolumn(emp_shp, :rate)\n#-> BlockOf(Float64, x0to1)\n\ncolumn(emp_shp, 4)\n#-> BlockOf(Float64, x0to1)It is possible to specify the shape of a TupleVector without labels.cmp_shp = TupleOf(BlockOf(Int, x0to1), BlockOf(Int, x1to1))\n#-> TupleOf(BlockOf(Int, x0to1), BlockOf(Int, x1to1))In this case, the columns will be assigned ordinal labels.label(cmp_shp, 1)   #-> Symbol(\"#A\")\nlabel(cmp_shp, 2)   #-> Symbol(\"#B\")"
},

{
    "location": "shapes/#Annotations-1",
    "page": "Shapes and Signatures",
    "title": "Annotations",
    "category": "section",
    "text": "Any shape can be assigned a label using IsLabeled annotation.lbl_shp = BlockOf(String, x1to1) |> IsLabeled(:name)\n\nsubject(lbl_shp)\n#-> BlockOf(String, x1to1)\n\nlabel(lbl_shp)\n#-> :nameA BlockOf shape is annotated with IsFlow to indicate that the container holds the output flow of a pipeline.flw_shp = BlockOf(String, x1to1) |> IsFlow\n\nsubject(flw_shp)\n#-> BlockOf(String, x1to1)The shape of the flow elements could be easily accessed or replaced.elements(flw_shp)\n#-> ValueOf(String)\n\nreplace_elements(flw_shp, ValueOf(Int))\n#-> BlockOf(Int, x1to1) |> IsFlowA TupleOf shape is annotated with IsScope to indicate that the container holds the scoping context of a pipeline.scp_shp = TupleOf(Float64, TupleOf(:P => Int)) |> IsScope\n\nsubject(scp_shp)\n#-> TupleOf(Float64, TupleOf(:P => Int))We can get the shapes of the input data and the context parameters.context(scp_shp)\n#-> TupleOf(:P => Int)\n\ncolumn(scp_shp)\n#-> ValueOf(Float64)\n\nreplace_column(scp_shp, ValueOf(Int))\n#-> TupleOf(Int, TupleOf(:P => Int)) |> IsScope"
},

{
    "location": "shapes/#Shape-ordering-1",
    "page": "Shapes and Signatures",
    "title": "Shape ordering",
    "category": "section",
    "text": "A single vector instance may satisfy many different shape constraints.bv = BlockVector(:, [\"Chicago\"])\n\nfits(bv, BlockOf(String, x1to1))        #-> true\nfits(bv, BlockOf(AbstractString))       #-> true\nfits(bv, AnyShape())                    #-> trueWe can tell, for any two shape constraints, if one of them is more specific than the other.fits(ValueOf(Int), ValueOf(Number))     #-> true\nfits(ValueOf(Int), ValueOf(String))     #-> false\n\nfits(BlockOf(Int, x1to1),\n     BlockOf(Number, x0to1))            #-> true\nfits(BlockOf(Int, x1toN),\n     BlockOf(Number, x0to1))            #-> false\nfits(BlockOf(Int, x1to1),\n     BlockOf(String, x0to1))            #-> false\n\nfits(TupleOf(BlockOf(Int, x1to1),\n             BlockOf(String, x0to1)),\n     TupleOf(BlockOf(Number, x1to1),\n             BlockOf(String, x0toN)))   #-> true\nfits(TupleOf(BlockOf(Int, x0to1),\n             BlockOf(String, x1to1)),\n     TupleOf(BlockOf(Number, x1to1),\n             BlockOf(String, x0toN)))   #-> false\nfits(TupleOf(BlockOf(Int, x1to1)),\n     TupleOf(BlockOf(Number, x1to1),\n             BlockOf(String, x0toN)))   #-> falseShapes of different kinds are typically not compatible with each other.  The exceptions are AnyShape() and NoShape().fits(ValueOf(Int), BlockOf(Int))        #-> false\nfits(ValueOf(Int), AnyShape())          #-> true\nfits(NoShape(), ValueOf(Int))           #-> trueColumn labels are treated as additional shape constraints.fits(TupleOf(:name => String),\n     TupleOf(:name => String))          #-> true\nfits(TupleOf(String),\n     TupleOf(:position => String))      #-> false\nfits(TupleOf(:name => String),\n     TupleOf(String))                   #-> true\nfits(TupleOf(:name => String),\n     TupleOf(:position => String))      #-> falseSimilarly, annotations are treated as shape constraints.fits(String |> IsLabeled(:name),\n     String |> IsLabeled(:name))        #-> true\nfits(ValueOf(String),\n     String |> IsLabeled(:position))    #-> false\nfits(String |> IsLabeled(:name),\n     ValueOf(String))                   #-> true\nfits(String |> IsLabeled(:name),\n     String |> IsLabeled(:position))    #-> false\n\nfits(BlockOf(String, x1to1) |> IsFlow,\n     BlockOf(String, x0toN) |> IsFlow)  #-> true\nfits(BlockOf(String, x1to1),\n     BlockOf(String, x0toN) |> IsFlow)  #-> false\nfits(BlockOf(String, x1to1) |> IsFlow,\n     BlockOf(String, x0toN))            #-> true\n\nfits(TupleOf(Int, TupleOf(:X => Int))\n     |> IsScope,\n     TupleOf(Int, TupleOf(:X => Int))\n     |> IsScope)                        #-> true\nfits(TupleOf(Int, TupleOf(:X => Int)),\n     TupleOf(Int, TupleOf(:X => Int))\n     |> IsScope)                        #-> false\nfits(TupleOf(Int, TupleOf(:X => Int))\n     |> IsScope,\n     TupleOf(Int, TupleOf(:X => Int)))  #-> true"
},

{
    "location": "shapes/#Shape-of-a-vector-1",
    "page": "Shapes and Signatures",
    "title": "Shape of a vector",
    "category": "section",
    "text": "Function shapeof() determines the shape of a given vector.shapeof([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> ValueOf(String)\n\nshapeof(@VectorTree ((1:1)String, (0:1)Int) [])\n#-> TupleOf(BlockOf(String, x1to1), BlockOf(Int, x0to1))\n\nshapeof(@VectorTree (name = String, employee = [String]) [])\n#-> TupleOf(:name => String, :employee => BlockOf(String))"
},

{
    "location": "shapes/#Pipeline-signature-1",
    "page": "Shapes and Signatures",
    "title": "Pipeline signature",
    "category": "section",
    "text": "A Signature object describes the shapes of a pipeline\'s input and output.sig = Signature(ValueOf(UInt),\n                BlockOf(TupleOf(:name => BlockOf(String, x1to1),\n                                :employee => BlockOf(UInt, x0toN))) |> IsFlow)\n#=>\nSignature(ValueOf(UInt),\n          BlockOf(TupleOf(:name => BlockOf(String, x1to1),\n                          :employee => BlockOf(UInt))) |>\n          IsFlow)\n=#Components of the signature can be easily extracted.target(sig)\n#=>\nBlockOf(TupleOf(:name => BlockOf(String, x1to1),\n                :employee => BlockOf(UInt))) |>\nIsFlow\n=#\n\nsource(sig)\n#-> ValueOf(UInt)"
},

{
    "location": "knots/#",
    "page": "Data Knots",
    "title": "Data Knots",
    "category": "page",
    "text": ""
},

{
    "location": "knots/#Data-Knots-1",
    "page": "Data Knots",
    "title": "Data Knots",
    "category": "section",
    "text": ""
},

{
    "location": "knots/#Overview-1",
    "page": "Data Knots",
    "title": "Overview",
    "category": "section",
    "text": "A DataKnot object contains a single data value serialized in a column-oriented form.using DataKnots:\n    @VectorTree,\n    DataKnot,\n    It,\n    cell,\n    shapeAny Julia value can be converted to a DataKnot.hello = DataKnot(\"Hello World!\")\n#=>\n│ It           │\n┼──────────────┼\n│ Hello World! │\n=#To obtain a Julia value from a DataKnot object, we use the get() function.get(hello)\n#-> \"Hello World!\"To preserve the column-oriented structure of the data, DataKnot keeps the value in a one-element vector.cell(hello)\n#-> [\"Hello World!\"]DataKnot also stores the shape of the data.shape(hello)\n#-> ValueOf(String)We use indexing notation to apply a Query to a DataKnot.  The output of a query is also a DataKnot object.hello[length.(It)]\n#=>\n│ It │\n┼────┼\n│ 12 │\n=#"
},

{
    "location": "knots/#DataKnots.DataKnot",
    "page": "Data Knots",
    "title": "DataKnots.DataKnot",
    "category": "type",
    "text": "DataKnot(cell::AbstractVector, shp::AbstractShape)\n\nEncapsulates a data cell serialized in a column-oriented form.\n\n\n\n\n\n"
},

{
    "location": "knots/#API-Reference-1",
    "page": "Data Knots",
    "title": "API Reference",
    "category": "section",
    "text": "Modules = [DataKnots]\nPages = [\"knots.jl\"]"
},

{
    "location": "knots/#Test-Suite-1",
    "page": "Data Knots",
    "title": "Test Suite",
    "category": "section",
    "text": ""
},

{
    "location": "knots/#Constructors-1",
    "page": "Data Knots",
    "title": "Constructors",
    "category": "section",
    "text": "A DataKnot object is created from a one-element vector and its shape.DataKnot([\"Hello World\"], String)\n#=>\n│ It          │\n┼─────────────┼\n│ Hello World │\n=#It is an error to provide a vector of a length different from 1.DataKnot(String[], String)\n#-> ERROR: AssertionError: length(cell) == 1Any Julia value can be converted to a DataKnot object using the convert() function or a one-argument DataKnot constructor.convert(DataKnot, \"Hello World!\")\n#=>\n│ It           │\n┼──────────────┼\n│ Hello World! │\n=#\n\nhello = DataKnot(\"Hello World!\")\n#=>\n│ It           │\n┼──────────────┼\n│ Hello World! │\n=#Scalar values are stored as is.shape(hello)\n#-> ValueOf(String)The value missing is converted to an empty DataKnot.null = DataKnot(missing)\n#=>\n│ It │\n┼────┼\n=#\n\nshape(null)\n#-> BlockOf(NoShape(), x0to1)The value nothing is converted to the void DataKnot.  The same DataKnot is created by the constructor with no arguments.void = DataKnot()\n#=>\n│ It │\n┼────┼\n│    │\n=#\n\nshape(void)\n#-> ValueOf(Nothing)A vector value is converted to a block.blk = DataKnot(\'a\':\'c\')\n#=>\n  │ It │\n──┼────┼\n1 │ a  │\n2 │ b  │\n3 │ c  │\n=#\n\nshape(blk)\n#-> BlockOf(Char)By default, the block has no cardinality constraint, but we could specify it explicitly.int_null = DataKnot(Int[], :x0to1)\n#=>\n│ It │\n┼────┼\n=#\n\nshape(int_null)\n#-> BlockOf(Int, x0to1)A Ref object is converted into the referenced value.int_ty = DataKnot(Base.broadcastable(Int))\n#=>\n│ It  │\n┼─────┼\n│ Int │\n=#\n\nshape(int_ty)\n#-> ValueOf(Type{Int})"
},

{
    "location": "knots/#Rendering-1",
    "page": "Data Knots",
    "title": "Rendering",
    "category": "section",
    "text": "On output, a DataKnot object is rendered as a table.emp = DataKnot([(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442),\n                (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016),\n                (name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350),\n                (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484)])\n#=>\n  │ name       position           salary │\n──┼──────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT           101442 │\n2 │ NANCY A    POLICE OFFICER      80016 │\n3 │ JAMES A    FIRE ENGINEER-EMT  103350 │\n4 │ DANIEL A   FIRE FIGHTER-EMT    95484 │\n=#The table is truncated if it does not fit the output screen.small = IOContext(stdout, :displaysize => (6, 20))\n\nshow(small, emp)\n#=>\n  │ name       posi…\n──┼────────────────…\n1 │ JEFFERY A  SERG…\n⋮\n4 │ DANIEL A   FIRE…\n=#Top-level tuples are serialized as table columns while nested tuples are rendered as comma-separated lists of tuple elements.DataKnot((\"FIRE\", [(\"JEFFERY A\", (101442, missing)), (\"NANCY A\", (80016, missing))]))\n#=>\n│ #A    #B                                                      │\n┼───────────────────────────────────────────────────────────────┼\n│ FIRE  JEFFERY A, (101442, missing); NANCY A, (80016, missing) │\n=#\n\nDataKnot((name = \"FIRE\", employee = [(name = \"JEFFERY A\", compensation = (salary = 101442, rate = missing)),\n                                     (name = \"NANCY A\", compensation = (salary = 80016, rate = missing))]))\n#=>\n│ name  employee                                                │\n┼───────────────────────────────────────────────────────────────┼\n│ FIRE  JEFFERY A, (101442, missing); NANCY A, (80016, missing) │\n=#\n\nDataKnot(\n    @VectorTree((name = (1:1)String,\n                 employee = [(name = (1:1)String,\n                              compensation = (1:1)(salary = (0:1)Int,\n                                                   rate = (0:1)Float64))]), [\n        (name = \"FIRE\", employee = [(name = \"JEFFERY A\", compensation = (salary = 101442, rate = missing)),\n                                    (name = \"NANCY A\", compensation = (salary = 80016, rate = missing))])]),\n    :x1to1)\n\n#=>\n│ name  employee                                                │\n┼───────────────────────────────────────────────────────────────┼\n│ FIRE  JEFFERY A, (101442, missing); NANCY A, (80016, missing) │\n=#Similarly, top-level vectors are represented as table rows while nested vectors are rendered as semicolon-separated lists.DataKnot([[\"JEFFERY A\", \"NANCY A\"], [\"JAMES A\", \"DANIEL A\"]])\n#=>\n  │ It                 │\n──┼────────────────────┼\n1 │ JEFFERY A; NANCY A │\n2 │ JAMES A; DANIEL A  │\n=#\n\nDataKnot(@VectorTree [String] [[\"JEFFERY A\", \"NANCY A\"], [\"JAMES A\", \"DANIEL A\"]])\n#=>\n  │ It                 │\n──┼────────────────────┼\n1 │ JEFFERY A; NANCY A │\n2 │ JAMES A; DANIEL A  │\n=#Integer numbers are right-aligned while decimal numbers are centered around the decimal point.DataKnot([true, false])\n#=>\n  │ It    │\n──┼───────┼\n1 │  true │\n2 │ false │\n=#\n\nDataKnot([101442, 80016])\n#=>\n  │ It     │\n──┼────────┼\n1 │ 101442 │\n2 │  80016 │\n=#\n\nDataKnot([35.6, 2.65])\n#=>\n  │ It    │\n──┼───────┼\n1 │ 35.6  │\n2 │  2.65 │\n=#"
},

{
    "location": "queries/#",
    "page": "Query Algebra",
    "title": "Query Algebra",
    "category": "page",
    "text": ""
},

{
    "location": "queries/#Query-Algebra-1",
    "page": "Query Algebra",
    "title": "Query Algebra",
    "category": "section",
    "text": ""
},

{
    "location": "queries/#Overview-1",
    "page": "Query Algebra",
    "title": "Overview",
    "category": "section",
    "text": "In this section, we sketch the design and implementation of the query algebra. We will need the following definitions.using DataKnots:\n    @VectorTree,\n    Count,\n    DataKnot,\n    Drop,\n    Each,\n    Environment,\n    Filter,\n    Get,\n    Given,\n    It,\n    Keep,\n    Label,\n    Lift,\n    Max,\n    Min,\n    Record,\n    Sum,\n    Tag,\n    Take,\n    assemble,\n    elements,\n    optimize,\n    trivial_pipe,\n    target_pipe,\n    uncoverAs a running example, we will use the following dataset of city departments with associated employees.  This dataset is serialized as a nested structure with a singleton root record, which holds all department records, each of which holds associated employee records.chicago_data =\n    @VectorTree (department = [(name     = (1:1)String,\n                                employee = [(name     = (1:1)String,\n                                             position = (1:1)String,\n                                             salary   = (0:1)Int,\n                                             rate     = (0:1)Float64)])],) [\n        (department = [\n            (name     = \"POLICE\",\n             employee = [\"JEFFERY A\"  \"SERGEANT\"           101442   missing\n                         \"NANCY A\"    \"POLICE OFFICER\"     80016    missing]),\n            (name     = \"FIRE\",\n             employee = [\"JAMES A\"    \"FIRE ENGINEER-EMT\"  103350   missing\n                         \"DANIEL A\"   \"FIRE FIGHTER-EMT\"   95484    missing]),\n            (name     = \"OEMC\",\n             employee = [\"LAKENYA A\"  \"CROSSING GUARD\"     missing  17.68\n                         \"DORIS A\"    \"CROSSING GUARD\"     missing  19.38])],\n        )\n    ]\n\nchicago = DataKnot(chicago_data, :x1to1)\n#=>\n│ department                                                                   …\n┼──────────────────────────────────────────────────────────────────────────────…\n│ POLICE, [JEFFERY A, SERGEANT, 101442, missing; NANCY A, POLICE OFFICER, 80016…\n=#"
},

{
    "location": "queries/#Constructing-queries-1",
    "page": "Query Algebra",
    "title": "Constructing queries",
    "category": "section",
    "text": "In DataKnots, we query data by assembling and running Query objects.  Queries are constructed algebraically: they either come a set of atomic primitive queries, or are built from other queries using query combinators.For example, consider the query:Employees = Get(:department) >> Get(:employee)\n#-> Get(:department) >> Get(:employee)This query traverses the dataset through fields department and employee. It is constructed from two primitive queries Get(:department) and Get(:employee) connected using the query composition combinator >>.Since attribute traversal is so common, DataKnots provides a shorthand notation.Employees = It.department.employee\n#-> It.department.employeeTo apply a query to a DataKnot, we use indexing notation.  The output of a query is also a DataKnot.chicago[Employees]\n#=>\n  │ employee                                    │\n  │ name       position           salary  rate  │\n──┼─────────────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT           101442        │\n2 │ NANCY A    POLICE OFFICER      80016        │\n3 │ JAMES A    FIRE ENGINEER-EMT  103350        │\n4 │ DANIEL A   FIRE FIGHTER-EMT    95484        │\n5 │ LAKENYA A  CROSSING GUARD             17.68 │\n6 │ DORIS A    CROSSING GUARD             19.38 │\n=#Regular Julia values and functions could be used to create query components. Specifically, any Julia value could be converted to a query primitive, and any Julia function could be converted to a query combinator.For example, let us find find employees whose salary is greater than $100k. For this purpose, we need to construct a predicate query that compares the salary field with a specific number.If we were constructing an ordinary predicate function, we would write:salary_over_100k(emp) = emp.salary > 100000An equivalent query is constructed as follows:SalaryOver100K = Lift(>, (Get(:salary), Lift(100000)))\n#-> Lift(>, (Get(:salary), Lift(100000)))This query expression is constructed from two primitive components: Get(:salary) and Lift(100000), which serve as parameters of the Lift(>) combinator.  Here, Lift is used twice.  Lift applied to a regular Julia value converts it to a constant query primitive while Lift applied to a function lifts it to a query combinator.As a shorthand notation for lifting functions and operators, DataKnots supports broadcasting syntax:SalaryOver100K = It.salary .> 100000\n#-> It.salary .> 100000To test this query, we can append it to the Employees query using the composition combinator.chicago[Employees >> SalaryOver100K]\n#=>\n  │ It    │\n──┼───────┼\n1 │  true │\n2 │ false │\n3 │  true │\n4 │ false │\n=#However, this only gives us a list of bare Boolean values disconnected from the respective employees.  To contextualize this output, we can use the Record combinator.chicago[Employees >> Record(It.name,\n                            It.salary,\n                            :salary_over_100k => SalaryOver100K)]\n#=>\n  │ employee                            │\n  │ name       salary  salary_over_100k │\n──┼─────────────────────────────────────┼\n1 │ JEFFERY A  101442              true │\n2 │ NANCY A     80016             false │\n3 │ JAMES A    103350              true │\n4 │ DANIEL A    95484             false │\n5 │ LAKENYA A                           │\n6 │ DORIS A                             │\n=#To actually filter the data using this predicate query, we need to use the Filter combinator.EmployeesWithSalaryOver100K = Employees >> Filter(SalaryOver100K)\n#-> It.department.employee >> Filter(It.salary .> 100000)\n\nchicago[EmployeesWithSalaryOver100K]\n#=>\n  │ employee                                   │\n  │ name       position           salary  rate │\n──┼────────────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT           101442       │\n2 │ JAMES A    FIRE ENGINEER-EMT  103350       │\n=#DataKnots provides a number of useful query constructors.  For example, to find the number of items produced by a query, we can use the Count combinator.chicago[Count(EmployeesWithSalaryOver100K)]\n#=>\n│ It │\n┼────┼\n│  2 │\n=#In general, query algebra forms an XPath-like domain-specific language.  It is designed to let the user construct queries incrementally, with each step being individually crafted and tested.  It also encourages the user to create reusable query components and remix them in creative ways."
},

{
    "location": "queries/#Compiling-queries-1",
    "page": "Query Algebra",
    "title": "Compiling queries",
    "category": "section",
    "text": "In DataKnots, applying a query to the input data is a two-phase process. First, the query generates a pipeline.  Second, this pipeline transforms the input data to the output data.Let us elaborate on the role of pipelines and queries.  In DataKnots, just like pipelines are used to transform data, a query can transform pipelines.  That is, a query can be applied to a pipeline to produce a new pipeline.To run a query on the given data, we apply the query to a trivial pipeline. The generated pipeline is used to actually transform the data.To demonstrate how to apply a query, let us use EmployeesWithSalaryOver100K from the previous section.  Recall that it could be represented as follows:Get(:department) >> Get(:employee) >> Filter(Get(:salary) .> 100000)\n#-> Get(:department) >> Get(:employee) >> Filter(Get(:salary) .> 100000)This query is constructed using a composition combinator.  A query composition transforms a pipeline by sequentially applying the component queries. Therefore, to find the pipeline of EmployeesWithSalaryOver100K, we need to start with a trivial pipeline and sequentially tranfrorm it with the queries Get(:department), Get(:employee) and Filter(SalaryOver100K).The trivial pipeline can be obtained from the input data.p0 = trivial_pipe(chicago)\n#-> pass()We use the function assemble() to apply a query to a pipeline.  To run assemble() we need to create the environment object.env = Environment()\n\np1 = assemble(Get(:department), env, p0)\n#-> chain_of(with_elements(column(:department)), flatten())The pipeline p1 fetches the attribute department from the input data.  In general, Get(name) maps a pipeline to its monadic composition with column(name).  For example, when we apply Get(:employee) to p1, what we get is the result of compose(p1, column(:employee)).p2 = assemble(Get(:employee), env, p1)\n#=>\nchain_of(chain_of(with_elements(column(:department)), flatten()),\n         chain_of(with_elements(column(:employee)), flatten()))\n=#To finish assembling the pipeline, we apply Filter(SalaryOver100K) to p2. Filter acts on the input pipeline as follows.  First, it assembles the predicate pipeline by applying the predicate query to a trivial pipeline.pc0 = target_pipe(p2)\n#-> wrap()\n\npc1 = assemble(SalaryOver100K, env, pc0)\n#=>\nchain_of(wrap(),\n         chain_of(\n             with_elements(\n                 chain_of(\n                     chain_of(\n                         ⋮\n                         tuple_lift(>)),\n                     adapt_missing())),\n             flatten()))\n=#Filter(SalaryOver100K) then combines the pipelines p2 and pc1 using the pipeline primitive sieve().p3 = assemble(Filter(SalaryOver100K), env, p2)\n#=>\nchain_of(\n    chain_of(chain_of(with_elements(column(:department)), flatten()),\n             chain_of(with_elements(column(:employee)), flatten())),\n    chain_of(\n        with_elements(\n            chain_of(\n                ⋮\n                sieve())),\n        flatten()))\n=#The resulting pipeline could be compacted by simplifying the pipeline expression.p = optimize(uncover(p3))\n#=>\nchain_of(with_elements(chain_of(column(:department),\n                                with_elements(column(:employee)))),\n         flatten(),\n         flatten(),\n         with_elements(chain_of(tuple_of(pass(),\n                                         chain_of(tuple_of(column(:salary),\n                                                           chain_of(\n                                                               filler(100000),\n                                                               wrap())),\n                                                  tuple_lift(>),\n                                                  adapt_missing(),\n                                                  block_any())),\n                                sieve())),\n         flatten())\n=#Applying this pipeline to the input data gives us the output of the query.p(chicago)\n#=>\n  │ employee                                   │\n  │ name       position           salary  rate │\n──┼────────────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT           101442       │\n2 │ JAMES A    FIRE ENGINEER-EMT  103350       │\n=#"
},

{
    "location": "queries/#DataKnots.Count-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.Count",
    "category": "method",
    "text": "Count(X) :: Query\nEach(X >> Count) :: Query\n\nCounts the number of elements produced by the query.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Drop-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.Drop",
    "category": "method",
    "text": "Drop(N) :: Query\n\nDrops the first N elements of the input, keeps the rest.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Each-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.Each",
    "category": "method",
    "text": "Each(X) :: Query\n\nThis query evaluates X elementwise.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Filter-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.Filter",
    "category": "method",
    "text": "Filter(X) :: Query\n\nFilters the input by the given condition.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Get-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.Get",
    "category": "method",
    "text": "Get(name) :: Query\n\nThis query emits the value of a record field.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Given-Tuple{Any,Vararg{Any,N} where N}",
    "page": "Query Algebra",
    "title": "DataKnots.Given",
    "category": "method",
    "text": "Given(X₁, X₂ … Xₙ, Q) :: Query\n\nEvaluates the query with the given context parameters.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Keep-Tuple{Any,Vararg{Any,N} where N}",
    "page": "Query Algebra",
    "title": "DataKnots.Keep",
    "category": "method",
    "text": "Keep(X₁, X₂ … Xₙ) :: Query\n\nDefines context parameters.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Label-Tuple{Symbol}",
    "page": "Query Algebra",
    "title": "DataKnots.Label",
    "category": "method",
    "text": "Label(lbl::Symbol) :: Query\n\nAssigns a label to the output.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Lift-Tuple{Any,Tuple}",
    "page": "Query Algebra",
    "title": "DataKnots.Lift",
    "category": "method",
    "text": "Lift(f, (X₁, X₂ … Xₙ)) :: Query\n\nThis query uses the outputs of X₁, X₂ … Xₙ as arguments of f.  The output of f is emitted.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Lift-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.Lift",
    "category": "method",
    "text": "Lift(val) :: Query\n\nThis query emits the given value.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Max-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.Max",
    "category": "method",
    "text": "Max(X) :: Query\nEach(X >> Max) :: Query\n\nFinds the maximum among the elements produced by the query.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Min-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.Min",
    "category": "method",
    "text": "Min(X) :: Query\nEach(X >> Min) :: Query\n\nFinds the minimum among the elements produced by the query.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Record-Tuple",
    "page": "Query Algebra",
    "title": "DataKnots.Record",
    "category": "method",
    "text": "Record(X₁, X₂ … Xₙ) :: Query\n\nThis query emits records, whose fields are generated by X₁, X₂ … Xₙ.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Sum-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.Sum",
    "category": "method",
    "text": "Sum(X) :: Query\nEach(X >> Sum) :: Query\n\nSums the elements produced by the query.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Tag-Tuple{Symbol,Any}",
    "page": "Query Algebra",
    "title": "DataKnots.Tag",
    "category": "method",
    "text": "Tag(name::Symbol, F) :: Query\nTag(name::Symbol, (X₁, X₂ … Xₙ), F) :: Query\n\nAssigns a name to a query.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Take-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.Take",
    "category": "method",
    "text": "Take(N) :: Query\n\nKeeps the first N elements of the input, drops the rest.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Environment",
    "page": "Query Algebra",
    "title": "DataKnots.Environment",
    "category": "type",
    "text": "Environment()\n\nQuery compilation state.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Navigation",
    "page": "Query Algebra",
    "title": "DataKnots.Navigation",
    "category": "type",
    "text": "It\n\nIdentity query with respect to the query composition.\n\nIt.a.b.c\n\nEquivalent to Get(:a) >> Get(:b) >> Get(:c).\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Query",
    "page": "Query Algebra",
    "title": "DataKnots.Query",
    "category": "type",
    "text": "Query(op, args...)\n\nA query is implemented as a pipeline transformation that preserves pipeline source.  Specifically, a query takes the input pipeline that maps the source to the input target and generates a pipeline that maps the source to the output target.\n\nParameter op is a function that performs the transformation; args are extra arguments passed to the function.\n\nThe query transforms an input pipeline p by invoking op with the following arguments:\n\nop(env::Environment, q::Pipeline, args...)\n\nThe result of op must be the output pipeline.\n\n\n\n\n\n"
},

{
    "location": "queries/#Base.getindex-Tuple{DataKnot,Any}",
    "page": "Query Algebra",
    "title": "Base.getindex",
    "category": "method",
    "text": "db::DataKnot[F::Query; params...] :: DataKnot\n\nQueries db with F.\n\n\n\n\n\n"
},

{
    "location": "queries/#API-Reference-1",
    "page": "Query Algebra",
    "title": "API Reference",
    "category": "section",
    "text": "Modules = [DataKnots]\nPages = [\"queries.jl\"]"
},

{
    "location": "queries/#Test-Suite-1",
    "page": "Query Algebra",
    "title": "Test Suite",
    "category": "section",
    "text": ""
},

{
    "location": "queries/#Querying-1",
    "page": "Query Algebra",
    "title": "Querying",
    "category": "section",
    "text": "A Query is applied to a DataKnot using the array indexing syntax.Q = Count(It.department)\n\nchicago[Q]\n#=>\n│ It │\n┼────┼\n│  3 │\n=#Any parameters to the query should be be passed as keyword arguments.Q = It.department >>\n    Filter(Count(It.employee >> Filter(It.salary .> It.AMT)) .>= It.SZ) >>\n    Count\n\nchicago[Q, AMT=100000, SZ=1]\n#=>\n│ It │\n┼────┼\n│  2 │\n=#We can use the function assemble() to see the query plan.p = assemble(chicago, Count(It.department))\n#=>\nchain_of(with_elements(chain_of(column(:department), block_length(), wrap())),\n         flatten())\n=#\n\np(chicago)\n#=>\n│ It │\n┼────┼\n│  3 │\n=#"
},

{
    "location": "queries/#Composition-1",
    "page": "Query Algebra",
    "title": "Composition",
    "category": "section",
    "text": "Queries can be composed sequentially using the >> combinator.Q = Lift(3) >> (It .+ 4) >> (It .* 6)\n#-> Lift(3) >> (It .+ 4) >> It .* 6\n\nchicago[Q]\n#=>\n│ It │\n┼────┼\n│ 42 │\n=#The It query primitive is the identity with respect to >>.Q = It >> Q >> It\n#-> It >> Lift(3) >> (It .+ 4) >> It .* 6 >> It\n\nchicago[Q]\n#=>\n│ It │\n┼────┼\n│ 42 │\n=#"
},

{
    "location": "queries/#Record-1",
    "page": "Query Algebra",
    "title": "Record",
    "category": "section",
    "text": "The query Record(X₁, X₂ … Xₙ) emits records with the fields generated by X₁, X₂ … Xₙ.Q = It.department >>\n    Record(It.name,\n           :size => Count(It.employee))\n#-> It.department >> Record(It.name, :size => Count(It.employee))\n\nchicago[Q]\n#=>\n  │ department   │\n  │ name    size │\n──┼──────────────┼\n1 │ POLICE     2 │\n2 │ FIRE       2 │\n3 │ OEMC       2 │\n=#If a field has no label, an ordinal label (#A, #B … #AA, #AB …) is assigned.Q = It.department >> Record(It.name, Count(It.employee))\n#-> It.department >> Record(It.name, Count(It.employee))\n\nchicago[Q]\n#=>\n  │ department │\n  │ name    #B │\n──┼────────────┼\n1 │ POLICE   2 │\n2 │ FIRE     2 │\n3 │ OEMC     2 │\n=#Similarly, when there are duplicate labels, only the last one survives.Q = It.department >> Record(It.name, It.employee.name)\n#-> It.department >> Record(It.name, It.employee.name)\n\nchicago[Q]\n#=>\n  │ department                 │\n  │ #A      name               │\n──┼────────────────────────────┼\n1 │ POLICE  JEFFERY A; NANCY A │\n2 │ FIRE    JAMES A; DANIEL A  │\n3 │ OEMC    LAKENYA A; DORIS A │\n=#"
},

{
    "location": "queries/#Lift-1",
    "page": "Query Algebra",
    "title": "Lift",
    "category": "section",
    "text": "The Lift constructor is used to convert Julia values and functions to queries.Lift(val) makes a query primitive from a Julia value.Q = Lift(\"Hello World!\")\n#-> Lift(\"Hello World!\")\n\nchicago[Q]\n#=>\n│ It           │\n┼──────────────┼\n│ Hello World! │\n=#Lifting missing produces no output.Q = Lift(missing)\n#-> Lift(missing)\n\nchicago[Q]\n#=>\n│ It │\n┼────┼\n=#Lifting a vector produces plural output.Q = Lift(\'a\':\'c\')\n#-> Lift(\'a\':1:\'c\')\n\nchicago[Q]\n#=>\n  │ It │\n──┼────┼\n1 │ a  │\n2 │ b  │\n3 │ c  │\n=#Lift can also convert Julia functions to query combinators.Inc(X) = Lift(x -> x+1, (X,))\n\nQ = Lift(0) >> Inc(It)\n#-> Lift(0) >> Lift(x -> x + 1, (It,))\n\nchicago[Q]\n#=>\n│ It │\n┼────┼\n│  1 │\n=#Functions of multiple arguments are also supported.GT(X, Y) = Lift(>, (X, Y))\n\nQ = It.department.employee >>\n    Record(It.name, It.salary, GT(It.salary, 100000))\n#=>\nIt.department.employee >>\nRecord(It.name, It.salary, Lift(>, (It.salary, 100000)))\n=#\n\nchicago[Q]\n#=>\n  │ employee                 │\n  │ name       salary  #C    │\n──┼──────────────────────────┼\n1 │ JEFFERY A  101442   true │\n2 │ NANCY A     80016  false │\n3 │ JAMES A    103350   true │\n4 │ DANIEL A    95484  false │\n5 │ LAKENYA A                │\n6 │ DORIS A                  │\n=#Just as functions with no arguments.using Random: seed!\n\nseed!(0)\n\nQ = Lift(rand, ())\n#-> Lift(rand, ())\n\nchicago[Q]\n#=>\n│ It       │\n┼──────────┼\n│ 0.823648 │\n=#Functions with vector arguments are supported.using Statistics: mean\n\nMean(X) = Lift(mean, (X,))\n\nQ = Mean(It.department.employee.salary)\n#-> Lift(mean, (It.department.employee.salary,))\n\nchicago[Q]\n#=>\n│ It      │\n┼─────────┼\n│ 95073.0 │\n=#Just like with regular values, missing and vector results are interpreted as no and plural output.Q = Inc(missing)\n#-> Lift(x -> x + 1, (missing,))\n\nchicago[Q]\n#=>\n│ It │\n┼────┼\n=#\n\nOneTo(N) = Lift(UnitRange, (1, N))\n\nQ = OneTo(3)\n#-> Lift(UnitRange, (1, 3))\n\nchicago[Q]\n#=>\n  │ It │\n──┼────┼\n1 │  1 │\n2 │  2 │\n3 │  3 │\n=#Julia functions are lifted when they are broadcasted over queries.Q = mean.(It.department.employee.salary)\n#-> mean.(It.department.employee.salary)\n\nchicago[Q]\n#=>\n│ It      │\n┼─────────┼\n│ 95073.0 │\n=#"
},

{
    "location": "queries/#Each-1",
    "page": "Query Algebra",
    "title": "Each",
    "category": "section",
    "text": "Each serves as a barrier for aggregate queries.Q = It.department >> (It.employee >> Count)\n#-> It.department >> It.employee >> Count\n\nchicago[Q]\n#=>\n│ It │\n┼────┼\n│  6 │\n=#\n\nQ = It.department >> Each(It.employee >> Count)\n#-> It.department >> Each(It.employee >> Count)\n\nchicago[Q]\n#=>\n  │ It │\n──┼────┼\n1 │  2 │\n2 │  2 │\n3 │  2 │\n=#Note that Record and Lift also serve as natural barriers for aggregate queries.Q = It.department >>\n    Record(It.name, It.employee >> Count)\n#-> It.department >> Record(It.name, It.employee >> Count)\n\nchicago[Q]\n#=>\n  │ department │\n  │ name    #B │\n──┼────────────┼\n1 │ POLICE   2 │\n2 │ FIRE     2 │\n3 │ OEMC     2 │\n=#\n\nQ = It.department >>\n    (1 .* (It.employee >> Count))\n#-> It.department >> 1 .* (It.employee >> Count)\n\nchicago[Q]\n#=>\n  │ It │\n──┼────┼\n1 │  2 │\n2 │  2 │\n3 │  2 │\n=#"
},

{
    "location": "queries/#Label-1",
    "page": "Query Algebra",
    "title": "Label",
    "category": "section",
    "text": "We use the Label() primitive to assign a label to the output.Q = Count(It.department) >> Label(:num_dept)\n#-> Count(It.department) >> Label(:num_dept)\n\nchicago[Q]\n#=>\n│ num_dept │\n┼──────────┼\n│        3 │\n=#As a shorthand, we can use =>.Q = :num_dept => Count(It.department)\n#-> :num_dept => Count(It.department)\n\nchicago[Q]\n#=>\n│ num_dept │\n┼──────────┼\n│        3 │\n=#"
},

{
    "location": "queries/#Tag-1",
    "page": "Query Algebra",
    "title": "Tag",
    "category": "section",
    "text": "We use Tag() constructor to assign a name to a query.DeptSize = Count(It.employee) >> Label(:dept_size)\n#-> Count(It.employee) >> Label(:dept_size)\n\nDeptSize = Tag(:DeptSize, DeptSize)\n#-> DeptSize\n\nQ = It.department >> Record(It.name, DeptSize)\n#-> It.department >> Record(It.name, DeptSize)\n\nchicago[Q]\n#=>\n  │ department        │\n  │ name    dept_size │\n──┼───────────────────┼\n1 │ POLICE          2 │\n2 │ FIRE            2 │\n3 │ OEMC            2 │\n=#Tag() is also used to assign a name to a query combinator.SalaryOver(X) = It.salary .> X\n\nSalaryOver(100000)\n#-> It.salary .> 100000\n\nSalaryOver(X) = Tag(SalaryOver, (X,), It.salary .> X)\n\nSalaryOver(100000)\n#-> SalaryOver(100000)\n\nQ = It.department.employee >>\n    Filter(SalaryOver(100000))\n#-> It.department.employee >> Filter(SalaryOver(100000))\n\nchicago[Q]\n#=>\n  │ employee                                   │\n  │ name       position           salary  rate │\n──┼────────────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT           101442       │\n2 │ JAMES A    FIRE ENGINEER-EMT  103350       │\n=#"
},

{
    "location": "queries/#Get-1",
    "page": "Query Algebra",
    "title": "Get",
    "category": "section",
    "text": "We use the Get(name) to extract the value of a record field.Q = Get(:department) >> Get(:name)\n#-> Get(:department) >> Get(:name)\n\nchicago[Q]\n#=>\n  │ name   │\n──┼────────┼\n1 │ POLICE │\n2 │ FIRE   │\n3 │ OEMC   │\n=#As a shorthand, extracting an attribute of It generates a Get() query.Q = It.department.name\n#-> It.department.name\n\nchicago[Q]\n#=>\n  │ name   │\n──┼────────┼\n1 │ POLICE │\n2 │ FIRE   │\n3 │ OEMC   │\n=#We can also extract fields that have ordinal labels, but the label name is not preserved.Q = It.department >>\n    Record(It.name, Count(It.employee)) >>\n    It.B\n\nchicago[Q]\n#=>\n  │ It │\n──┼────┼\n1 │  2 │\n2 │  2 │\n3 │  2 │\n=#Same notation is used to extract values of context parameters defined with Keep() or Given().Q = It.department >>\n    Keep(:dept_name => It.name) >>\n    It.employee >>\n    Record(It.dept_name, It.name)\n\nchicago[Q]\n#=>\n  │ employee             │\n  │ dept_name  name      │\n──┼──────────────────────┼\n1 │ POLICE     JEFFERY A │\n2 │ POLICE     NANCY A   │\n3 │ FIRE       JAMES A   │\n4 │ FIRE       DANIEL A  │\n5 │ OEMC       LAKENYA A │\n6 │ OEMC       DORIS A   │\n=#A context parameter is preferred if it has the same name as a record field.Q = It.department >>\n    Keep(It.name) >>\n    It.employee >>\n    Record(It.name, It.position)\n\nchicago[Q]\n#=>\n  │ employee                  │\n  │ name    position          │\n──┼───────────────────────────┼\n1 │ POLICE  SERGEANT          │\n2 │ POLICE  POLICE OFFICER    │\n3 │ FIRE    FIRE ENGINEER-EMT │\n4 │ FIRE    FIRE FIGHTER-EMT  │\n5 │ OEMC    CROSSING GUARD    │\n6 │ OEMC    CROSSING GUARD    │\n=#If there is no attribute with the given name, an error is reported.Q = It.department.employee.ssn\n\nchicago[Q]\n#=>\nERROR: cannot find \"ssn\" at\n(0:N) × (name = (1:1) × String, position = (1:1) × String, salary = (0:1) × Int, rate = (0:1) × Float64)\n=#Regular and named tuples also support attribute lookup.Q = Lift((name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442)) >>\n    It.position\n\nchicago[Q]\n#=>\n│ position │\n┼──────────┼\n│ SERGEANT │\n=#\n\nQ = Lift((name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442)) >>\n    It.ssn\n\nchicago[Q]\n#=>\nERROR: cannot find \"ssn\" at\n(1:1) × NamedTuple{(:name, :position, :salary),Tuple{String,String,Int}}\n=#\n\nQ = Lift((\"JEFFERY A\", \"SERGEANT\", 101442)) >>\n    It.B\n\nchicago[Q]\n#=>\n│ It       │\n┼──────────┼\n│ SERGEANT │\n=#\n\nQ = Lift((\"JEFFERY A\", \"SERGEANT\", 101442)) >>\n    It.Z\n\nchicago[Q]\n#=>\nERROR: cannot find \"Z\" at\n(1:1) × Tuple{String,String,Int}\n=#"
},

{
    "location": "queries/#Keep-and-Given-1",
    "page": "Query Algebra",
    "title": "Keep and Given",
    "category": "section",
    "text": "We use the combinator Keep() to assign a value to a context parameter.Q = It.department >>\n    Keep(:dept_name => It.name) >>\n    It.employee >>\n    Record(It.dept_name, It.name)\n#=>\nIt.department >>\nKeep(:dept_name => It.name) >>\nIt.employee >>\nRecord(It.dept_name, It.name)\n=#\n\nchicago[Q]\n#=>\n  │ employee             │\n  │ dept_name  name      │\n──┼──────────────────────┼\n1 │ POLICE     JEFFERY A │\n2 │ POLICE     NANCY A   │\n3 │ FIRE       JAMES A   │\n4 │ FIRE       DANIEL A  │\n5 │ OEMC       LAKENYA A │\n6 │ OEMC       DORIS A   │\n=#Several context parameters could be defined together.Q = It.department >>\n    Keep(:size => Count(It.employee),\n         :half => It.size .÷ 2) >>\n    Each(It.employee >> Take(It.half))\n\nchicago[Q]\n#=>\n  │ employee                                    │\n  │ name       position           salary  rate  │\n──┼─────────────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT           101442        │\n2 │ JAMES A    FIRE ENGINEER-EMT  103350        │\n3 │ LAKENYA A  CROSSING GUARD             17.68 │\n=#Keep() requires that the parameter is labeled.Q = It.department >>\n    Keep(Count(It.employee))\n\nchicago[Q]\n#-> ERROR: parameter name is not specifiedKeep() will override an existing parameter with the same name.Q = It.department >>\n    Keep(:current_name => It.name) >>\n    It.employee >>\n    Keep(:current_name => It.name) >>\n    It.current_name\n\nchicago[Q]\n#=>\n  │ current_name │\n──┼──────────────┼\n1 │ JEFFERY A    │\n2 │ NANCY A      │\n3 │ JAMES A      │\n4 │ DANIEL A     │\n5 │ LAKENYA A    │\n6 │ DORIS A      │\n=#Combinator Given() is used to evaluate a query with the given context parameters.Q = It.department >>\n    Given(:size => Count(It.employee),\n          :half => It.size .÷ 2,\n          It.employee >> Take(It.half))\n#=>\nIt.department >> Given(:size => Count(It.employee),\n                       :half => div.(It.size, 2),\n                       It.employee >> Take(It.half))\n=#\n\nchicago[Q]\n#=>\n  │ employee                                    │\n  │ name       position           salary  rate  │\n──┼─────────────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT           101442        │\n2 │ JAMES A    FIRE ENGINEER-EMT  103350        │\n3 │ LAKENYA A  CROSSING GUARD             17.68 │\n=#Given() does not let any parameters defined within its scope escape it.Q = It.department >>\n    Given(Keep(It.name)) >>\n    It.employee >>\n    It.name\n\nchicago[Q]\n#=>\n  │ name      │\n──┼───────────┼\n1 │ JEFFERY A │\n2 │ NANCY A   │\n3 │ JAMES A   │\n4 │ DANIEL A  │\n5 │ LAKENYA A │\n6 │ DORIS A   │\n=#"
},

{
    "location": "queries/#Count,-Sum,-Max,-Min-1",
    "page": "Query Algebra",
    "title": "Count, Sum, Max, Min",
    "category": "section",
    "text": "Count(X), Sum(X), Max(X), Min(X) evaluate the X and emit the number of elements, their sum, maximum, and minimum respectively.Salary = It.department.employee.salary\n\nQ = Record(Salary,\n           :count => Count(Salary),\n           :sum => Sum(Salary),\n           :max => Max(Salary),\n           :min => Min(Salary))\n#=>\nRecord(It.department.employee.salary,\n       :count => Count(It.department.employee.salary),\n       :sum => Sum(It.department.employee.salary),\n       :max => Max(It.department.employee.salary),\n       :min => Min(It.department.employee.salary))\n=#\n\nchicago[Q]\n#=>\n│ salary                        count  sum     max     min   │\n┼────────────────────────────────────────────────────────────┼\n│ 101442; 80016; 103350; 95484      4  380292  103350  80016 │\n=#Count, Sum, Max, and Min could also be used as aggregate primitives.Q = Record(Salary,\n           :count => Salary >> Count,\n           :sum => Salary >> Sum,\n           :max => Salary >> Max,\n           :min => Salary >> Min)\n#=>\nRecord(It.department.employee.salary,\n       :count => It.department.employee.salary >> Count,\n       :sum => It.department.employee.salary >> Sum,\n       :max => It.department.employee.salary >> Max,\n       :min => It.department.employee.salary >> Min)\n=#\n\nchicago[Q]\n#=>\n│ salary                        count  sum     max     min   │\n┼────────────────────────────────────────────────────────────┼\n│ 101442; 80016; 103350; 95484      4  380292  103350  80016 │\n=#When applied to an empty input, Sum emits 0, Min and Max emit no output.Salary = It.employee.salary\n\nQ = It.department >>\n    Record(It.name,\n           Salary,\n           :count => Count(Salary),\n           :sum => Sum(Salary),\n           :max => Max(Salary),\n           :min => Min(Salary))\n\nchicago[Q]\n#=>\n  │ department                                          │\n  │ name    salary         count  sum     max     min   │\n──┼─────────────────────────────────────────────────────┼\n1 │ POLICE  101442; 80016      2  181458  101442  80016 │\n2 │ FIRE    103350; 95484      2  198834  103350  95484 │\n3 │ OEMC                       0       0                │\n=#"
},

{
    "location": "queries/#Filter-1",
    "page": "Query Algebra",
    "title": "Filter",
    "category": "section",
    "text": "We use Filter() to filter the input by the given predicate.Q = It.department >>\n    Filter(It.name .== \"POLICE\") >>\n    It.employee >>\n    Filter(It.name .== \"JEFFERY A\")\n#=>\nIt.department >>\nFilter(It.name .== \"POLICE\") >>\nIt.employee >>\nFilter(It.name .== \"JEFFERY A\")\n=#\n\nchicago[Q]\n#=>\n  │ employee                          │\n  │ name       position  salary  rate │\n──┼───────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT  101442       │\n=#The predicate must produce true of false values.Q = It.department >>\n    Filter(Count(It.employee))\n\nchicago[Q]\n#-> ERROR: expected a predicateThe input data is dropped when the output of the predicate contains only false elements.Q = It.department >>\n    Filter(It.employee >> (It.salary .> 100000)) >>\n    Record(It.name, It.employee.salary)\n\nchicago[Q]\n#=>\n  │ department            │\n  │ name    salary        │\n──┼───────────────────────┼\n1 │ POLICE  101442; 80016 │\n2 │ FIRE    103350; 95484 │\n=#"
},

{
    "location": "queries/#Take-and-Drop-1",
    "page": "Query Algebra",
    "title": "Take and Drop",
    "category": "section",
    "text": "We use Take(N) and Drop(N) to pass or drop the first N input elements.Employee = It.department.employee\n\nQ = Employee >> Take(4)\n#-> It.department.employee >> Take(4)\n\nchicago[Q]\n#=>\n  │ employee                                   │\n  │ name       position           salary  rate │\n──┼────────────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT           101442       │\n2 │ NANCY A    POLICE OFFICER      80016       │\n3 │ JAMES A    FIRE ENGINEER-EMT  103350       │\n4 │ DANIEL A   FIRE FIGHTER-EMT    95484       │\n=#\n\nQ = Employee >> Drop(4)\n#-> It.department.employee >> Drop(4)\n\nchicago[Q]\n#=>\n  │ employee                                 │\n  │ name       position        salary  rate  │\n──┼──────────────────────────────────────────┼\n1 │ LAKENYA A  CROSSING GUARD          17.68 │\n2 │ DORIS A    CROSSING GUARD          19.38 │\n=#Take(-N) drops the last N elements, while Drop(-N) keeps the last N elements.Q = Employee >> Take(-4)\n\nchicago[Q]\n#=>\n  │ employee                                │\n  │ name       position        salary  rate │\n──┼─────────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT        101442       │\n2 │ NANCY A    POLICE OFFICER   80016       │\n=#\n\nQ = Employee >> Drop(-4)\n\nchicago[Q]\n#=>\n  │ employee                                    │\n  │ name       position           salary  rate  │\n──┼─────────────────────────────────────────────┼\n1 │ JAMES A    FIRE ENGINEER-EMT  103350        │\n2 │ DANIEL A   FIRE FIGHTER-EMT    95484        │\n3 │ LAKENYA A  CROSSING GUARD             17.68 │\n4 │ DORIS A    CROSSING GUARD             19.38 │\n=#Take and Drop accept a query argument, which is evaluated against the input source and must produce a singular integer.Half = Count(Employee) .÷ 2\n\nQ = Employee >> Take(Half)\n\nchicago[Q]\n#=>\n  │ employee                                   │\n  │ name       position           salary  rate │\n──┼────────────────────────────────────────────┼\n1 │ JEFFERY A  SERGEANT           101442       │\n2 │ NANCY A    POLICE OFFICER      80016       │\n3 │ JAMES A    FIRE ENGINEER-EMT  103350       │\n=#\n\nQ = Take(Employee >> It.name)\n\nchicago[Q]\n#-> ERROR: expected a singular integer"
},

{
    "location": "simulation/#",
    "page": "Tutorial: Simulated Data",
    "title": "Tutorial: Simulated Data",
    "category": "page",
    "text": "EditURL = \"https://github.com/rbt-lang/DataKnots.jl/blob/master/doc/src/simulation.jl\""
},

{
    "location": "simulation/#Tutorial:-Simulated-Data-1",
    "page": "Tutorial: Simulated Data",
    "title": "Tutorial: Simulated Data",
    "category": "section",
    "text": "In this tutorial we simulate a random patient population from a health clinic dealing with hypertension and type 2 diabetes. We assume the reader has read \"Thinking in Combinators\" and wishes to use DataKnots for this simulation.using DataKnots"
},

{
    "location": "simulation/#Lifted-Functions-1",
    "page": "Tutorial: Simulated Data",
    "title": "Lifted Functions",
    "category": "section",
    "text": "Before we start generating data, there are a few combinators that are specific to this application area we should define first. Let\'s start with OneTo that wraps Julia\'s UnitRange.OneTo(N) = Lift(UnitRange, (1, N))\nrun(OneTo(3))Known data is boring in a simulation. Instead we need pseudorandom data. To make that data repeatable, let\'s fix the seed. We can then lift the rand function to a DataKnot combinator and use it to pick a random number from 3 to 5.using Random: seed!, rand\nseed!(1)\nRand(r::AbstractVector) = Lift(rand, (r,))\nrun(Rand(3:5))Combining OneTo and Rand we could make an easy way to build several rows of a given value.Several = OneTo(Rand(2:5))\nrun(Several >> \"Hello World\")Julia\'s Distributions has Categorical and TruncatedNormal to make sure they work with DataKnots, we need another lift.using Distributions\nRand(d::Distribution) = Lift(rand, (d,))\nrun(Rand(Categorical([.492, .508])))Sometimes it\'s helpful to truncate a floating point value, as chosen from an age distribution, to an integer value.  Here we lift Trunc.Trunc(X) = Int.(floor.(X))\nrun(Trunc(Rand(TruncatedNormal(60,20,18,104))))Translating a value, such as an index to a reference height, is also common. Here we define a switch function and then lift it.switch(x) = error();\nswitch(x, p, qs...) = x == p.first ? p.second : switch(x, qs...)\nSwitch(X, QS...) = Lift(switch, (X, QS...))\nrun(Switch(1, 1=>177, 2=>163))"
},

{
    "location": "simulation/#Building-a-Patient-Record-1",
    "page": "Tutorial: Simulated Data",
    "title": "Building a Patient Record",
    "category": "section",
    "text": "Let\'s incrementally construct a set of patient records. Let\'s start with assigning a random 5-digit Medical Record Number (\"MRN\").RandPatient = Record(:mrn => Rand(10000:99999))\nrun(:patient => Several >> RandPatient)To assign an age to patients, we use Julia\'s truncated normal distribution. Since we wish whole-numbered ages, we truncate to the nearest integer value.RandPatient >>= Record(It.mrn,\n  :age => Trunc(Rand(TruncatedNormal(60,20,18,104))))\nrun(:patient => Several >> RandPatient)Let\'s assign each patient a random Sex. Here we use a categorical distribution plus enumerated values for male/female.@enum Sex male=1 female=2\nRandPatient >>= Record(It.mrn, It.age,\n  :sex => Lift(Sex, (Rand(Categorical([.492, .508])),)))\nrun(:patient => Several >> RandPatient)Next, let\'s define the patient\'s height based upon the U.S. average of 177cm for males and 163cm for females with distribution of 7cm.RandPatient >>= Record(It.mrn, It.age, It.sex,\n  :height => Trunc(Switch(It.sex, male => 177, female => 163)\n                   .+ Rand(TruncatedNormal(0,7,-40,40))))\nrun(:patient => Several >> RandPatient)"
},

{
    "location": "simulation/#Implemention-Comparison-1",
    "page": "Tutorial: Simulated Data",
    "title": "Implemention Comparison",
    "category": "section",
    "text": "How could this patient sample be implemented directly in Julia?@enum Sex male=1 female=2\nfunction rand_patient()\n   sex = Sex(rand(Categorical([.492,.508])))\n   return (\n      mrn = rand(10000:99999), sex = sex,\n      age = trunc(Int, rand(TruncatedNormal(60,20,18,104))),\n      height = trunc(Int, (sex == male ? 177 : 163)\n                          + rand(TruncatedNormal(0,7,-40,40))))\nend\n[rand_patient() for i in 1:rand(2:5)]Omitting the boilerplate lifting of Rand, Trunc, and Switch, the combinator variant can also be constructed succinctly.@enum Sex male=1 female=2\nRandPatient = Given(\n  :sex => Lift(Sex, (Rand(Categorical([.492, .508])),)),\n  Record(\n    :mrn => Rand(10000:99999), It.sex,\n    :age => Trunc(Rand(TruncatedNormal(60,20,18,104))),\n    :height => Trunc(Switch(It.sex, male => 177, female => 163)\n                     .+ Rand(TruncatedNormal(0,7,-40,40)))))\nrun(:patient => OneTo(Rand(2:5)) >> RandPatient)That said, as complexity builds, the more incremental approach as shown in the previous section may prove to be more desireable."
},

]}
