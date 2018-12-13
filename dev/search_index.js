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
    "text": "DataKnots is a Julia library for representing and querying data, including nested and circular structures.  DataKnots provides integration and analytics across CSV, JSON, XML and SQL data sources with an extensible, practical and coherent algebra of query combinators."
},

{
    "location": "#Contents-1",
    "page": "Home",
    "title": "Contents",
    "category": "section",
    "text": "Pages = [\n    \"install.md\",\n    \"thinking.md\",\n    \"usage.md\",\n    \"implementation.md\",\n]"
},

{
    "location": "#Index-1",
    "page": "Home",
    "title": "Index",
    "category": "section",
    "text": ""
},

{
    "location": "install/#",
    "page": "Installation Instructions",
    "title": "Installation Instructions",
    "category": "page",
    "text": ""
},

{
    "location": "install/#Installation-Instructions-1",
    "page": "Installation Instructions",
    "title": "Installation Instructions",
    "category": "section",
    "text": "DataKnots.jl is a Julia library, but it is not yet registered with the Julia package manager.  To install it, run in the package shell (enter with ] from the Julia shell):pkg> add https://github.com/rbt-lang/DataKnots.jlDataKnots.jl requires Julia 0.7 or higher.If you want to modify the source code of DataKnots.jl, you need to install it in development mode with:pkg> dev https://github.com/rbt-lang/DataKnots.jl"
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
    "text": "DataKnots are a Julia library for building data processing pipelines. In DataKnots, pipelines are assembled algebraically: they either come from a set of atomic primitives or are built from other pipelines using combinators. In this tutorial, we show how to build pipelines starting from smaller components and then combining them algebraically to implement complex processing tasks.To start working with DataKnots, we import the package:using DataKnots"
},

{
    "location": "thinking/#Constructing-Pipelines-1",
    "page": "Thinking in Combinators",
    "title": "Constructing Pipelines",
    "category": "section",
    "text": "Consider a pipeline Hello that produces a string value, \"Hello World\". It is built using the Const primitive, which converts a Julia value into a pipeline component. This pipeline can then be run() to produce its output.Hello = Const(\"Hello World\")\nrun(Hello)\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#The output of the pipeline is encapsulated in a DataKnot, which is a container holding structured, vectorized data. We can get the corresponding Julia value using get().get(run(Hello)) #-> \"Hello World\"Consider another pipeline, Range(3). It is built with the Range combinator. When run(), it emits a sequence of integers from 1 to 3.run(Range(3))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        1 │\n2 │        2 │\n3 │        3 │\n=#The output of this knot can also be converted to native Julia.get(run(Range(3))) #-> [1, 2, 3]Observe that Hello pipeline produces a singular value, while the Range(3) pipeline is plural. In the output notation for plural knots, indices are in the first column with values in remaining columns."
},

{
    "location": "thinking/#Composition-and-Identity-1",
    "page": "Thinking in Combinators",
    "title": "Composition & Identity",
    "category": "section",
    "text": "In DataKnots, two pipelines could be connected sequentially using the composition combinator (>>). Consider the composition Range(3) >> Hello. Since Range(3) emits 3 values and Hello emits \"Hello World\" regardless of its input, their composition emits 3 copies of \"Hello World\".run(Range(3) >> Hello)\n#=>\n  │ DataKnot    │\n──┼─────────────┤\n1 │ Hello World │\n2 │ Hello World │\n3 │ Hello World │\n=#The identity with respect to pipeline composition is called It. This primitive can be composed with any pipeline without changing the pipeline\'s output.run(Hello >> It)\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#The identity, It, can be used to construct pipelines which rely upon the output from previous processing. For example, one can define a pipeline Increment as It .+ 1.Increment = It .+ 1\nrun(Range(3) >> Increment)\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │        3 │\n3 │        4 │\n=#When pipelines that produce plural values are combined, the output is flattened into a single sequence. The following expression calculates Range(1), Range(2) and Range(3) and then merges the outputs.run(Range(3) >> Range(It))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        1 │\n2 │        1 │\n3 │        2 │\n4 │        1 │\n5 │        2 │\n6 │        3 │\n=#In DataKnots, pipelines are built algebraically, using pipeline composition, identity and other combinators. This lets us define sophisticated pipeline components and remix them in creative ways."
},

{
    "location": "thinking/#Lifting-Julia-Functions-1",
    "page": "Thinking in Combinators",
    "title": "Lifting Julia Functions",
    "category": "section",
    "text": "With DataKnots, any native Julia expression can be lifted to build a Pipeline. Consider the Julia function double() that, when applied to a Number, produces a Number:double(x) = 2x\ndouble(3) #-> 6What we want is an analogue to double that, instead of operating on numbers, operates on pipelines. Such functions are called pipeline combinators. We can convert any Julia function to a pipeline Combinator as follows:Double(X) = Combinator(double)(X)When given an argument, the combinator Double can then be used to build a pipeline that produces the doubled value.run(Double(21))\n#=>\n│ DataKnot │\n├──────────┤\n│       42 │\n=#If the argument to the combinator is plural, than the pipeline constructed is also plural. When run() the following pipeline first evaluates the argument, Range(3) to produce three input values. These values are then passed though the underlying function, double. The results are then collected and converted into a plural output knot.run(Double(Range(3)))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │        4 │\n3 │        6 │\n=#Sometimes it\'s handy to use pipeline composition, rather than passing by combinator arguments. To build a pipeline component that doubles its input, the Double combinator could use It as its argument. This pipeline can then later be reused with various inputs.ThenDouble = Double(It)\nrun(Range(3) >> ThenDouble)\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │        4 │\n3 │        6 │\n=#Since this lifting operation is common enough, Julia\'s broadcast syntax (using a period) is overloaded to make simple lifting easy. Any scalar function can be used as a combinator as follows:run(double.(Range(3)))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │        4 │\n3 │        6 │\n=#DataKnots\' automatic lifting also applies to built-in Julia operators. In this example, the expression It .+ 1 is a pipeline component that increments each one of its input values.run(Range(3) >> It .+ 1)\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │        3 │\n3 │        4 │\n=#When a Julia function returns a vector, a lifted combinator creates pipelines having plural output. In fact, the Range combinator used in these examples could be created as follows:Range(X) = Combinator(Range, x -> 1:x)(X)In DataKnots, pipeline combinators can be constructed directly from native Julia functions. This lets us take advantage of Julia\'s rich statistical and data processing functions."
},

{
    "location": "thinking/#Aggregates-1",
    "page": "Thinking in Combinators",
    "title": "Aggregates",
    "category": "section",
    "text": "Some pipeline combinators transform a plural pipeline into a singular pipeline; we call them aggregate combinators. Consider the pipeline, Count(Range(3)). It is built by applying the Count combinator to the Range(3) pipeline. It outputs a singular value 3, the number of entries produced by Range(3).run(Count(Range(3)))\n#=>\n│ DataKnot │\n├──────────┤\n│        3 │\n=#Count can also be used as a pipeline primitive.run(Range(3) >> Count)\n#=>\n│ DataKnot │\n├──────────┤\n│        3 │\n=#It\'s possible to use aggregates within a plural pipeline. In this example, as the outer Range goes from 1 to 3, the Sum aggregate would calculate its output from Range(1), Range(2) and Range(3).run(Range(3) >> Sum(Range(It)))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        1 │\n2 │        3 │\n3 │        6 │\n=#However, if we rewrite the pipeline to use Sum as a pipeline primitive, we get a different result.run(Range(3) >> Range(It) >> Sum)\n#=>\n│ DataKnot │\n├──────────┤\n│       10 │\n=#Since pipeline composition (>>) is associative, just adding parenthesis around Range(It) >> Sum would not change the result.run(Range(3) >> (Range(It) >> Sum))\n#=>\n│ DataKnot │\n├──────────┤\n│       10 │\n=#Instead of using parenthesis, we need to wrap Range(It) >> Sum with the Each combinator. This combinator builds a pipeline that processes its input elementwise.run(Range(3) >> Each(Range(It) >> Sum))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        1 │\n2 │        3 │\n3 │        6 │\n=#Like scalar functions, aggregates can be lifted to Combinator form with the aggregate=true keyword argument. This constructor produces an aggregate combinator that operates on an incoming pipeline. For example, the Mean aggregate combinator could be defined as:using Statistics\nMean(X) = Combinator(Mean, mean, aggregate=true)(X)Then, one could create a mean of sums as follows:run(Mean(Range(3) >> Sum(Range(It))))\n#=>\n│ DataKnot    │\n├─────────────┤\n│ 3.333333335 │\n=#To use Mean as a pipeline primitive, there are two additional steps. First, a zero-argument version is required, Mean(). Second, an automatic conversion of the symbol Mean to a pipeline is required. The former is done by Then, the latter by Julia\'s built-in convert.Mean() = Then(Mean)\nconvert(::Type{Pipeline}, ::typeof(Mean)) = Mean()Once these are done, one could take the sum of means as follows:run(Range(3) >> Sum(Range(It)) >> Mean)\n#=>\n│ DataKnot    │\n├─────────────┤\n│ 3.333333335 │\n=#In DataKnots, aggregate operations are naturally expressed as pipeline combinators. Moreover, custom aggregates can be easily constructed as native Julia functions and lifted into the pipeline algebra."
},

{
    "location": "thinking/#Filtering-and-Slicing-Data-1",
    "page": "Thinking in Combinators",
    "title": "Filtering & Slicing Data",
    "category": "section",
    "text": "DataKnots comes with combinators for rearranging data. Consider Filter, which takes one parameter, a predicate pipeline that for each input value decides if that value should be included in the output.run(Range(6) >> Filter(It .> 3))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        4 │\n2 │        5 │\n3 │        6 │\n=#Contrast this with the built-in Julia function filter().filter(x -> x > 3, 1:6) #-> [4, 5, 6]Where filter() returns a filtered dataset, the Filter combinator returns a pipeline component, which could then be composed with any data generating pipeline.KeepEven = Filter(iseven.(It))\nrun(Range(6) >> KeepEven)\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │        4 │\n3 │        6 │\n=#Similar to Filter, the Take and Drop combinators can be used to slice an input stream: Drop is used to skip over input, Take ignores output past a particular point.run(Range(9) >> Drop(3) >> Take(3))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        4 │\n2 │        5 │\n3 │        6 │\n=#Since Take is a combinator, its argument could also be a full blown pipeline. This next example, FirstHalf is a combinator that builds a pipeline returning the first half of an input stream.FirstHalf(X) = Each(X >> Take(Count(X) .÷ 2))\nrun(FirstHalf(Range(6)))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        1 │\n2 │        2 │\n3 │        3 │\n=#Using Then, this combinator could be used with pipeline composition:run(Range(6) >> Then(FirstHalf))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        1 │\n2 │        2 │\n3 │        3 │\n=#The TakeFirst combinator is similar to Take(1), only that it returns a singular, rather than plural knot.run(Range(3) >> TakeFirst())\n#=>\n│ DataKnot │\n├──────────┤\n│        1 │\n=#In DataKnots, filtering and slicing are realized as pipeline components. They are attached to data processing pipelines using the composition combinator. This brings common data processing concepts into our pipeline algebra."
},

{
    "location": "thinking/#Query-Parameters-1",
    "page": "Thinking in Combinators",
    "title": "Query Parameters",
    "category": "section",
    "text": "With DataKnots, parameters can be provided so that static data can be used within query expressions. By convention, we use upper case, singular labels for query parameters.run(\"Hello \" .* Lookup(:WHO), WHO=\"World\")\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#To make Lookup convenient, It provides a shorthand syntax.run(\"Hello \" .* It.WHO, WHO=\"World\")\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#Query parameters are available anywhere in the query. They could, for example be used within a filter.query = Range(6) >> Filter(It .> It.START)\nrun(query, START=3)\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        4 │\n2 │        5 │\n3 │        6 │\n=#Parameters can also be defined as part of a query using Given. This combinator takes set of pairs (=>) that map symbols (:name) onto query expressions. The subsequent argument is then evaluated in a naming context where the defined parameters are available for reuse.run(Given(:WHO => \"World\",\n    \"Hello \" .* Lookup(:WHO)))\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#Query parameters can be especially useful when managing aggregates, or with expressions that one may wish to repeat more than once.GreaterThanAverage(X) =\n  Given(:AVG => Mean(X),\n        X >> Filter(It .> Lookup(:AVG)))\n\nrun(Range(6) >> Then(GreaterThanAverage))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        4 │\n2 │        5 │\n3 │        6 │\n=#In DataKnots, query parameters passed in to the run command permit external data to be used within query expressions. Parameters that are defined with Given can be used to remember values and reuse them."
},

{
    "location": "thinking/#Records-and-Labels-1",
    "page": "Thinking in Combinators",
    "title": "Records & Labels",
    "category": "section",
    "text": "Internally, DataKnots use a column-oriented storage mechanism that handles hierarchies and graphs. Data objects in this model can be created using the Record combinator.GM = Record(:name => \"GARRY M\", :salary => 260004)\nrun(GM)\n#=>\n│ DataKnot        │\n│ name     salary │\n├─────────────────┤\n│ GARRY M  260004 │\n=#Field access is also possible via Lookup or via the It shortcut.run(GM >> It.name)\n#=>\n│ name    │\n├─────────┤\n│ GARRY M │\n=#As seen in the output above, field names also act as display labels. It is possible to provide a name to any expression with the Label combinator. Labeling doesn\'t affect the actual output, only the field name given to the expression and its display.run(Const(\"Hello World\") >> Label(:greeting))\n#=>\n│ greeting    │\n├─────────────┤\n│ Hello World │\n=#Alternatively, Julia\'s pair constructor (=>) and and a Symbol denoted by a colon (:) can be used to label an expression.Hello = :greeting => Const(\"Hello World\")\nrun(Hello)\n#=>\n│ greeting    │\n├─────────────┤\n│ Hello World │\n=#When a record is created, it can use the label from which it originates. In this case, the :greeting label from the Hello is used to make the field label used within the Record. The record itself is also expressly labeled.run(:seasons => Record(Hello))\n#=>\n│ seasons     │\n│ greeting    │\n├─────────────┤\n│ Hello World │\n=#Records can be plural. Here is a table of obvious statistics.Stats = Record(:n¹=>It, :n²=>It.*It, :n³=>It.*It.*It)\nrun(Range(3) >> Stats)\n#=>\n  │ DataKnot   │\n  │ n¹  n²  n³ │\n──┼────────────┤\n1 │  1   1   1 │\n2 │  2   4   8 │\n3 │  3   9  27 │\n=#Calculations could be run on record sets as follows:run(Range(3) >> Stats >> (It.n² .+ It.n³))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │       12 │\n3 │       36 │\n=#Any values can be used within a Record, including other records and plural values.run(:work_schedule =>\n Record(:staff => Record(:name => \"Jim Rockford\",\n                         :phone => \"555-2368\"),\n        :workday => Const([\"Su\", \"M\",\"Tu\", \"F\"])))\n#=>\n│ work_schedule                            │\n│ staff                       workday      │\n├──────────────────────────────────────────┤\n│ │ name          phone    │  Su; M; Tu; F │\n│ ├────────────────────────┤               │\n│ │ Jim Rockford  555-2386 │               │\n=#In DataKnots, records are used to generate tabular data. Using nested records, it is possible to represent complex, hierarchical data."
},

{
    "location": "thinking/#Working-With-Data-1",
    "page": "Thinking in Combinators",
    "title": "Working With Data",
    "category": "section",
    "text": "Arrays of named tuples can be wrapped with Const in order to provide a series of tuples. Since DataKnots works fluidly with Julia, any sort of Julia object may be used. In this case, NamedTuple has special support so that it prints well.DATA = Const([(name = \"GARRY M\", salary = 260004),\n              (name = \"ANTHONY R\", salary = 185364),\n              (name = \"DANA A\", salary = 170112)])\n\nrun(:staff => DATA)\n#=>\n  │ staff             │\n  │ name       salary │\n──┼───────────────────┤\n1 │ GARRY M    260004 │\n2 │ ANTHONY R  185364 │\n3 │ DANA A     170112 │\n=#Access to slots in a NamedTuple is also supported by Lookup.run(DATA >> Lookup(:name))\n#=>\n  │ name      │\n──┼───────────┤\n1 │ GARRY M   │\n2 │ ANTHONY R │\n3 │ DANA A    │\n=#Together with previous combinators, DataKnots could be used to create readable queries, such as \"who has the greatest salary\"?run(:highest_salary =>\n  Given(:MAX => Max(DATA >> It.salary),\n        DATA >> Filter(It.salary .== Lookup(:MAX))))\n#=>\n  │ highest_salary  │\n  │ name     salary │\n──┼─────────────────┤\n1 │ GARRY M  260004 │\n=#Records can even contain lists of subordinate records.DB =\n  run(:department =>\n    Record(:name => \"FIRE\", :staff => It.FIRE),\n    FIRE=[(name = \"JOSE S\", salary = 202728),\n          (name = \"CHARLES S\", salary = 197736)])\n#=>\n│ department                    │\n│ name  staff                   │\n├───────────────────────────────┤\n│ FIRE    │ name       salary │ │\n│       ──┼───────────────────┤ │\n│       1 │ JOSE S     202728 │ │\n│       2 │ CHARLES S  197736 │ │\n=#These subordinate records can then be summarized.run(:statistics =>\n  DB >> Record(:dept => It.name,\n               :count => Count(It.staff)))\n#=>\n│ statistics  │\n│ dept  count │\n├─────────────┤\n│ FIRE      2 │\n=#"
},

{
    "location": "usage/#",
    "page": "Usage Guide",
    "title": "Usage Guide",
    "category": "page",
    "text": ""
},

{
    "location": "usage/#Usage-Guide-1",
    "page": "Usage Guide",
    "title": "Usage Guide",
    "category": "section",
    "text": ""
},

{
    "location": "usage/#What-is-a-DataKnot?-1",
    "page": "Usage Guide",
    "title": "What is a DataKnot?",
    "category": "section",
    "text": "A DataKnot is an in-memory column store.  It may contain tabular data, a collection of interrelated tables, or hierarchical data such as JSON or XML. It can also serve as an interface to external data sources such as SQL databases.To start working with DataKnots, we import the package:using DataKnots"
},

{
    "location": "usage/#Querying-tabular-data-1",
    "page": "Usage Guide",
    "title": "Querying tabular data",
    "category": "section",
    "text": "In this section, we demonstrate how to use DataKnots.jl to query tabular data.First, we load some sample data from a CSV file.  We use the (???) data set, which is packaged as a part of DataKnots.jl.# Path to ???.csv.\nDATA = joinpath(Base.find_package(\"DataKnots\"),\n                \"test/data/???.csv\")\n\nusedb!(data = LoadCSV(DATA))This command loads tabular data from ???.csv and adds it to the current database under the name data.  We can now query it.Show the whole dataset.@query data\n#=>\n...\n=#Show all the salaries.@query data.salary\n#=>\n...\n=#Show the number of rows in the dataset.@query count(data)\n#=>\n...\n=#Show the mean salary.@query mean(data.salary)\n#=>\n...\n=#Show all employees with annual salary higher than 100000.@query data.filter(salary>100000)\n#=>\n...\n=#Show the number of employees with annual salary higher than 100000.@query count(data.filter(salary>100000))\n#=>\n...\n=#Show the top ten employees ordered by salary.@query data.sort(salary.desc()).select(name, salary).take(10)\n#=>\n...\n=#A long query could be split into several lines.@query begin\n    data\n    sort(salary.desc())\n    select(name, salary)\n    take(10)\nend\n#=>\n...\n=#DataKnots.jl implements an algebra of query combinators.  In this algebra, its elements are queries, which represents relationships among classes and data types.  This algebra\'s operations are combinators, which are applied to construct query expressions."
},

{
    "location": "implementation/#",
    "page": "Implementation Guide",
    "title": "Implementation Guide",
    "category": "page",
    "text": ""
},

{
    "location": "implementation/#Implementation-Guide-1",
    "page": "Implementation Guide",
    "title": "Implementation Guide",
    "category": "section",
    "text": "Pages = [\n    \"vectors.md\",\n    \"shapes.md\",\n    \"queries.md\",\n    \"pipelines.md\",\n    \"lifting.md\",\n]"
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
    "text": "This section describes how DataKnots implements an in-memory column store. We will need the following definitions:using DataKnots:\n    @VectorTree,\n    OPT,\n    PLU,\n    REG,\n    BlockVector,\n    Cardinality,\n    TupleVector,\n    cardinality,\n    column,\n    columns,\n    elements,\n    isoptional,\n    isplural,\n    isregular,\n    labels,\n    offsets,\n    width"
},

{
    "location": "vectors/#Tabular-data-1",
    "page": "Column Store",
    "title": "Tabular data",
    "category": "section",
    "text": "Structured data can often be represented in a tabular form.  For example, information about city employees can be arranged in the following table.name position salary\nJEFFERY A SERGEANT 101442\nJAMES A FIRE ENGINEER-EMT 103350\nTERRY A POLICE OFFICER 93354Internally, a database engine stores tabular data using composite data structures such as tuples and vectors.A tuple is a fixed-size collection of heterogeneous values and can represent a table row.(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442)A vector is a variable-size collection of homogeneous values and can store a table column.[\"JEFFERY A\", \"JAMES A\", \"TERRY A\"]For a table as a whole, we have two options: either store it as a vector of tuples or store it as a tuple of vectors.  The former is called a row-oriented format, commonly used in programming and traditional database engines.[(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442),\n (name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350),\n (name = \"TERRY A\", position = \"POLICE OFFICER\", salary = 93354)]The other option, \"tuple of vectors\" layout, is called a column-oriented format.  It is often used by analytical databases as it is more suited for processing complex analytical queries.The module DataKnot implements data structures to support column-oriented data format.  In particular, tabular data is represented using TupleVector objects.TupleVector(:name => [\"JEFFERY A\", \"JAMES A\", \"TERRY A\"],\n            :position => [\"SERGEANT\", \"FIRE ENGINEER-EMT\", \"POLICE OFFICER\"],\n            :salary => [101442, 103350, 93354])"
},

{
    "location": "vectors/#Blank-cells-1",
    "page": "Column Store",
    "title": "Blank cells",
    "category": "section",
    "text": "As we arrange data in a tabular form, we may need to leave some cells blank.For example, consider that a city employee could be compensated either with salary or with hourly pay.  To display the compensation data in a table, we add two columns: the annual salary and the hourly rate.  However, only one of the columns per each row is filled.name position salary rate\nJEFFERY A SERGEANT 101442 \nJAMES A FIRE ENGINEER-EMT 103350 \nTERRY A POLICE OFFICER 93354 \nLAKENYA A CROSSING GUARD  17.68How can this data be serialized in a column-oriented format?  To retain the advantages of the format, we\'d like to keep the column data in tightly packed vectors of elements.name_elts = [\"JEFFERY A\", \"JAMES A\", \"TERRY A\", \"LAKENYA A\"]\nposition_elts = [\"SERGEANT\", \"FIRE ENGINEER-EMT\", \"POLICE OFFICER\", \"CROSSING GUARD\"]\nsalary_elts = [101442, 103350, 93354]\nrate_elts = [17.68]These vectors are partitioned into table cells by the vectors of offsets.name_offs = [1, 2, 3, 4, 5]\nposition_offs = [1, 2, 3, 4, 5]\nsalary_offs = [1, 2, 3, 4, 4]\nrate_offs = [1, 1, 1, 1, 2]Each pair of adjacent offsets maps a slice of the element vector to the corresponding column cell.  For example, here is how we fetch the 4-th row of the table:(name_elts[name_offs[4]:name_offs[5]-1],\n position_elts[position_offs[4]:position_offs[5]-1],\n salary_elts[salary_offs[4]:salary_offs[5]-1],\n rate_elts[rate_offs[4]:rate_offs[5]-1])\n#-> ([\"LAKENYA A\"], [\"CROSSING GUARD\"], Int[], [17.68])Together, elements and offsets faithfully reproduce the layout of the column. A pair of the offset and the element vectors is encapsulated with a BlockVector instance.name_col = BlockVector(name_offs, name_elts, REG)\nposition_col = BlockVector(position_offs, position_elts, REG)\nsalary_col = BlockVector(salary_offs, salary_elts, OPT)\nrate_col = BlockVector(rate_offs, rate_elts, OPT)BlockVector is a column-oriented encoding of a vector of variable-size blocks.  The last parameter of the BlockVector constructor is the cardinality constraint on the size of the blocks.  REG indicates that each block has exactly one element; OPT allows a block to be empty.  The constraint PLU is used to indicate that a block may contain more than one element.In this specific case, each block corresponds to a table cell: an empty block to a blank cell and a one-element block to a filled cell.  To represent the whole table, the columns should be wrapped with a TupleVector.TupleVector(\n    :name => name_col,\n    :position => position_col,\n    :salary => salary_col,\n    :rate => rate_col)"
},

{
    "location": "vectors/#Nested-data-1",
    "page": "Column Store",
    "title": "Nested data",
    "category": "section",
    "text": "When data does not fit a single table, it can often be presented in a top-down fashion.  For example, HR data can be seen as a collection of departments, each of which containing the associated employees.  Such data is serialized using nested data structures, which, in row-oriented format, may look as follows:[(name = \"POLICE\",\n  employee = [(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing),\n              (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016, rate = missing)]),\n (name = \"FIRE\",\n  employee = [(name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing),\n              (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484, rate = missing)]),\n (name = \"OEMC\",\n  employee = [(name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68),\n              (name = \"DORIS A\", position = \"CROSSING GUARD\", salary = missing, rate = 19.38)])]To store this data in a column-oriented format, we should use nested TupleVector and BlockVector instances.  We start with representing employee data.employee_elts =\n    TupleVector(\n        :name => BlockVector(:, [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"]),\n        :position => BlockVector(:, [\"SERGEANT\", \"POLICE OFFICER\", \"FIRE ENGINEER-EMT\", \"FIRE FIGHTER-EMT\", \"CROSSING GUARD\", \"CROSSING GUARD\"]),\n        :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484], OPT),\n        :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38], OPT))Then we partition employee data by departments:employee_col = BlockVector([1, 3, 5, 7], employee_elts, PLU)Adding a column of department names, we obtain HR data in a column-oriented format.TupleVector(\n    :name => BlockVector(:, [\"POLICE\", \"FIRE\", \"OEMC\"]),\n    :employee => employee_col)Since writing offset vectors manually is tedious, DataKnots provides a convenient macro @VectorTree, which lets you specify column-oriented data using regular tuple and vector literals.@VectorTree (name = [String, REG],\n             employee = [(name = [String, REG],\n                          position = [String, REG],\n                          salary = [Int, OPT],\n                          rate = [Float64, OPT]), PLU]) [\n    (name = \"POLICE\",\n     employee = [(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing),\n                 (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016, rate = missing)]),\n    (name = \"FIRE\",\n     employee = [(name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing),\n                 (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484, rate = missing)]),\n    (name = \"OEMC\",\n     employee = [(name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68),\n                 (name = \"DORIS A\", position = \"CROSSING GUARD\", salary = missing, rate = 19.38)])\n]"
},

{
    "location": "vectors/#DataKnots.BlockVector",
    "page": "Column Store",
    "title": "DataKnots.BlockVector",
    "category": "type",
    "text": "BlockVector(offs::AbstractVector{Int}, elts::AbstractVector, card::Cardinality=OPT|PLU)\nBlockVector(:, elts::AbstractVector, card::Cardinality=REG)\n\nVector of vectors (blocks) stored as a vector of elements partitioned by a vector of offsets.\n\nelts is a continuous vector of block elements.\noffs is a vector of indexes that subdivide elts into separate blocks. Should be monotonous with offs[1] == 1 and offs[end] == length(elts)+1.\ncard is the expected cardinality of the blocks.\n\nThe second constructor creates a BlockVector of one-element blocks.\n\n\n\n\n\n"
},

{
    "location": "vectors/#DataKnots.Cardinality",
    "page": "Column Store",
    "title": "DataKnots.Cardinality",
    "category": "type",
    "text": "REG::Cardinality\nOPT::Cardinality\nPLU::Cardinality\nOPT|PLU::Cardinality\n\nCardinality constraints on a block of values.  REG stands for 1…1, OPT for 0…1, PLU for 1…∞, OPT|PLU for 0…∞.\n\n\n\n\n\n"
},

{
    "location": "vectors/#DataKnots.TupleVector",
    "page": "Column Store",
    "title": "DataKnots.TupleVector",
    "category": "type",
    "text": "TupleVector([lbls::Vector{Symbol},] len::Int, cols::Vector{AbstractVector})\nTupleVector([lbls::Vector{Symbol},] idxs::AbstractVector{Int}, cols::Vector{AbstractVector})\nTupleVector(lcols::Pair{Symbol,<:AbstractVector}...)\n\nVector of tuples stored as a collection of column vectors.\n\ncols is a vector of columns; optional lbls is a vector of column labels. Alternatively, labels and columns could be provided as a list of pairs lcols.\nlen is the vector length, which must coincide with the length of all the columns.  Alternatively, the vector could be constructed from a subset of the column data using a vector of indexes idxs.\n\n\n\n\n\n"
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
    "text": "@VectorTree sig vec\n\nConstructs a tree of columnar vectors from a plain vector literal.\n\nThe first parameter, sig, describes the tree structure.  It is defined recursively:\n\nJulia type T indicates a regular vector of type T.\nTuple (col₁, col₂, ...) indicates a TupleVector instance.\nNamed tuple (lbl₁ = col₁, lbl₂ = col₂, ...) indicates a TupleVector instance with the given labels.\nOne-element vector [elt] indicates a BlockVector instance.\nTwo-element vector [elt, card] indicates a BlockVector with the given cardinality.\n\nThe second parameter, vec, is a vector literal in row-oriented format:\n\nTupleVector data is specified either by a matrix or by a vector of (regular or named) tuples.\nBlockVector data is specified by a vector of vectors.  A one-element block could be represented by its element; an empty block by missing literal.\n\n\n\n\n\n"
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
    "text": "TupleVector is a vector of tuples stored as a collection of parallel vectors.tv = TupleVector(:name => [\"GARRY M\", \"ANTHONY R\", \"DANA A\"],\n                 :salary => [260004, 185364, 170112])\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\ndisplay(tv)\n#=>\nTupleVector of 3 × (name = String, salary = Int):\n (name = \"GARRY M\", salary = 260004)\n (name = \"ANTHONY R\", salary = 185364)\n (name = \"DANA A\", salary = 170112)\n=#It is possible to construct a TupleVector without labels.TupleVector(length(tv), columns(tv))\n#-> @VectorTree (String, Int) [(\"GARRY M\", 260004) … ]An error is reported in case of duplicate labels or columns of different height.TupleVector(:name => [\"GARRY M\", \"ANTHONY R\"],\n            :name => [\"DANA A\", \"JUAN R\"])\n#-> ERROR: duplicate column label :name\n\nTupleVector(:name => [\"GARRY M\", \"ANTHONY R\"],\n            :salary => [260004, 185364, 170112])\n#-> ERROR: unexpected column heightWe can access individual components of the vector.labels(tv)\n#-> Symbol[:name, :salary]\n\nwidth(tv)\n#-> 2\n\ncolumn(tv, 2)\n#-> [260004, 185364, 170112]\n\ncolumn(tv, :salary)\n#-> [260004, 185364, 170112]\n\ncolumns(tv)\n#-> …[[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [260004, 185364, 170112]]When indexed by another vector, we get a new instance of TupleVector.tv′ = tv[[3,1]]\ndisplay(tv′)\n#=>\nTupleVector of 2 × (name = String, salary = Int):\n (name = \"DANA A\", salary = 170112)\n (name = \"GARRY M\", salary = 260004)\n=#Note that the new instance wraps the index and the original column vectors. Updated column vectors are generated on demand.column(tv′, 2)\n#-> [170112, 260004]"
},

{
    "location": "vectors/#Cardinality-1",
    "page": "Column Store",
    "title": "Cardinality",
    "category": "section",
    "text": "Enumerated type Cardinality is used to constrain the cardinality of a data block.  A block of data is called regular if it must contain exactly one element; optional if it may have no elements; and plural if it may have more than one element.  This gives us four different cardinality constraints.display(Cardinality)\n#=>\nEnum Cardinality:\nREG = 0x00\nOPT = 0x01\nPLU = 0x02\nOPT_PLU = 0x03\n=#Cardinality values support bitwise operations.REG|OPT|PLU             #-> OPT_PLU::Cardinality = 3\nPLU&~PLU                #-> REG::Cardinality = 0We can use predicates isregular(), isoptional(), isplural() to check cardinality values.isregular(REG)          #-> true\nisregular(OPT)          #-> false\nisregular(PLU)          #-> false\nisoptional(OPT)         #-> true\nisoptional(PLU)         #-> false\nisplural(PLU)           #-> true\nisplural(OPT)           #-> false"
},

{
    "location": "vectors/#BlockVector-1",
    "page": "Column Store",
    "title": "BlockVector",
    "category": "section",
    "text": "BlockVector is a vector of homogeneous vectors (blocks) stored as a vector of elements partitioned into individual blocks by a vector of offsets.bv = BlockVector([1, 3, 5, 7], [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"], PLU)\n#-> @VectorTree [String, PLU] [[\"JEFFERY A\", \"NANCY A\"], [\"JAMES A\", \"DANIEL A\"], [\"LAKENYA A\", \"DORIS A\"]]\n\ndisplay(bv)\n#=>\nBlockVector of 3 × [String, PLU]:\n [\"JEFFERY A\", \"NANCY A\"]\n [\"JAMES A\", \"DANIEL A\"]\n [\"LAKENYA A\", \"DORIS A\"]\n=#If each block contains exactly one element, we could use : in place of the offset vector.BlockVector(:, [\"POLICE\", \"FIRE\", \"OEMC\"])\n#-> @VectorTree [String, REG] [\"POLICE\", \"FIRE\", \"OEMC\"]The BlockVector constructor verifies that the offset vector is well-formed.BlockVector(Base.OneTo(0), [])\n#-> ERROR: partition must be non-empty\n\nBlockVector(Int[], [])\n#-> ERROR: partition must be non-empty\n\nBlockVector([0], [])\n#-> ERROR: partition must start with 1\n\nBlockVector([1,2,2,1], [\"HEALTH\"])\n#-> ERROR: partition must be monotone\n\nBlockVector(Base.OneTo(4), [\"HEALTH\", \"FINANCE\"])\n#-> ERROR: partition must enclose the elements\n\nBlockVector([1,2,3,6], [\"HEALTH\", \"FINANCE\"])\n#-> ERROR: partition must enclose the elementsThe constructor also validates the cardinality constraint.BlockVector([1, 3, 5, 7], [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"], OPT)\n#-> ERROR: singular blocks must have at most one element\n\nBlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38], REG)\n#-> ERROR: mandatory blocks must have at least one elementWe can access individual components of the vector.offsets(bv)\n#-> [1, 3, 5, 7]\n\nelements(bv)\n#-> [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"]\n\ncardinality(bv)\n#-> PLU::Cardinality = 2When indexed by a vector of indexes, an instance of BlockVector is returned.elts = [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nreg_bv = BlockVector(:, elts, REG)\n#-> @VectorTree [String, REG] [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nopt_bv = BlockVector([1, 2, 3, 3, 4, 4, 5, 6, 6, 6, 7], elts, OPT)\n#-> @VectorTree [String, OPT] [\"POLICE\", \"FIRE\", missing, \"HEALTH\", missing, \"AVIATION\", \"WATER MGMNT\", missing, missing, \"FINANCE\"]\n\nplu_bv = BlockVector([1, 1, 1, 2, 2, 4, 4, 6, 7], elts, OPT|PLU)\n#-> @VectorTree [String] [[], [], [\"POLICE\"], [], [\"FIRE\", \"HEALTH\"], [], [\"AVIATION\", \"WATER MGMNT\"], [\"FINANCE\"]]\n\nreg_bv[[1,3,5,3]]\n#-> @VectorTree [String, REG] [\"POLICE\", \"HEALTH\", \"WATER MGMNT\", \"HEALTH\"]\n\nplu_bv[[1,3,5,3]]\n#-> @VectorTree [String] [[], [\"POLICE\"], [\"FIRE\", \"HEALTH\"], [\"POLICE\"]]\n\nreg_bv[Base.OneTo(4)]\n#-> @VectorTree [String, REG] [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\"]\n\nreg_bv[Base.OneTo(6)]\n#-> @VectorTree [String, REG] [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nplu_bv[Base.OneTo(6)]\n#-> @VectorTree [String] [[], [], [\"POLICE\"], [], [\"FIRE\", \"HEALTH\"], []]\n\nopt_bv[Base.OneTo(10)]\n#-> @VectorTree [String, OPT] [\"POLICE\", \"FIRE\", missing, \"HEALTH\", missing, \"AVIATION\", \"WATER MGMNT\", missing, missing, \"FINANCE\"]"
},

{
    "location": "vectors/#@VectorTree-1",
    "page": "Column Store",
    "title": "@VectorTree",
    "category": "section",
    "text": "We can use @VectorTree macro to convert vector literals to the columnar form assembled with TupleVector and BlockVector objects.TupleVector is created from a matrix or a vector of (named) tuples.@VectorTree (name = String, salary = Int) [\n    \"GARRY M\"   260004\n    \"ANTHONY R\" 185364\n    \"DANA A\"    170112\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\n@VectorTree (name = String, salary = Int) [\n    (\"GARRY M\", 260004),\n    (\"ANTHONY R\", 185364),\n    (\"DANA A\", 170112),\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\n@VectorTree (name = String, salary = Int) [\n    (name = \"GARRY M\", salary = 260004),\n    (name = \"ANTHONY R\", salary = 185364),\n    (name = \"DANA A\", salary = 170112),\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]Column labels are optional.@VectorTree (String, Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n#-> @VectorTree (String, Int) [(\"GARRY M\", 260004) … ]BlockVector is constructed from a vector of vector literals.  A one-element block could be represented by the element itself; an empty block by missing.@VectorTree [String] [\n    \"HEALTH\",\n    [\"FINANCE\", \"HUMAN RESOURCES\"],\n    missing,\n    [\"POLICE\", \"FIRE\"],\n]\n#-> @VectorTree [String] [[\"HEALTH\"], [\"FINANCE\", \"HUMAN RESOURCES\"], [], [\"POLICE\", \"FIRE\"]]Ill-formed @VectorTree contructors are rejected.@VectorTree (String, Int) (\"GARRY M\", 260004)\n#=>\nERROR: LoadError: expected a vector literal; got :((\"GARRY M\", 260004))\n⋮\n=#\n\n@VectorTree (String, Int) [(position = \"SUPERINTENDENT OF POLICE\", salary = 260004)]\n#=>\nERROR: LoadError: expected no label; got :(position = \"SUPERINTENDENT OF POLICE\")\n⋮\n=#\n\n@VectorTree (name = String, salary = Int) [(position = \"SUPERINTENDENT OF POLICE\", salary = 260004)]\n#=>\nERROR: LoadError: expected label :name; got :(position = \"SUPERINTENDENT OF POLICE\")\n⋮\n=#\n\n@VectorTree (name = String, salary = Int) [(\"GARRY M\", \"SUPERINTENDENT OF POLICE\", 260004)]\n#=>\nERROR: LoadError: expected 2 column(s); got :((\"GARRY M\", \"SUPERINTENDENT OF POLICE\", 260004))\n⋮\n=#\n\n@VectorTree (name = String, salary = Int) [\"GARRY M\"]\n#=>\nERROR: LoadError: expected a tuple or a row literal; got \"GARRY M\"\n⋮\n=#Using @VectorTree, we can easily construct hierarchical data.hier_data = @VectorTree (name = [String, REG], employee = [(name = [String, REG], salary = [Int, OPT])]) [\n    \"POLICE\"    [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n    \"FIRE\"      [\"JOSE S\" 202728; \"CHARLES S\" 197736]\n]\ndisplay(hier_data)\n#=>\nTupleVector of 2 × (name = [String, REG], employee = [(name = [String, REG], salary = [Int, OPT])]):\n (name = \"POLICE\", employee = [(name = \"GARRY M\", salary = 260004) … ])\n (name = \"FIRE\", employee = [(name = \"JOSE S\", salary = 202728) … ])\n=#"
},

{
    "location": "shapes/#",
    "page": "Data Shape",
    "title": "Data Shape",
    "category": "page",
    "text": ""
},

{
    "location": "shapes/#Data-Shape-1",
    "page": "Data Shape",
    "title": "Data Shape",
    "category": "section",
    "text": "In DataKnots, the structure of vectorized data is described using shape objects.using DataKnots:\n    OPT,\n    PLU,\n    REG,\n    AnyShape,\n    Cardinality,\n    InputMode,\n    InputShape,\n    NativeShape,\n    NoneShape,\n    OutputMode,\n    OutputShape,\n    RecordShape,\n    Signature,\n    bound,\n    cardinality,\n    decorate,\n    domain,\n    fits,\n    ibound,\n    idomain,\n    imode,\n    ishape,\n    isoptional,\n    isplural,\n    isregular,\n    mode,\n    shape"
},

{
    "location": "shapes/#Input-and-output-shapes-1",
    "page": "Data Shape",
    "title": "Input and output shapes",
    "category": "section",
    "text": ""
},

{
    "location": "shapes/#Atomic-shapes-1",
    "page": "Data Shape",
    "title": "Atomic shapes",
    "category": "section",
    "text": ""
},

{
    "location": "shapes/#Record-shape-1",
    "page": "Data Shape",
    "title": "Record shape",
    "category": "section",
    "text": ""
},

{
    "location": "shapes/#Cardinality-1",
    "page": "Data Shape",
    "title": "Cardinality",
    "category": "section",
    "text": "Enumerated type Cardinality is used to constrain the cardinality of a data block.  A block of data is called regular if it must contain exactly one element; optional if it may have no elements; and plural if it may have more than one element.  This gives us four different cardinality constraints.display(Cardinality)\n#=>\nEnum Cardinality:\nREG = 0x00\nOPT = 0x01\nPLU = 0x02\nOPT_PLU = 0x03\n=#Cardinality values support bitwise operations.REG|OPT|PLU             #-> OPT_PLU::Cardinality = 3\nPLU&~PLU                #-> REG::Cardinality = 0We can use predicates isregular(), isoptional(), isplural() to check cardinality values.isregular(REG)          #-> true\nisregular(OPT)          #-> false\nisregular(PLU)          #-> false\nisoptional(OPT)         #-> true\nisoptional(PLU)         #-> false\nisplural(PLU)           #-> true\nisplural(OPT)           #-> falseThere is a partial ordering defined on Cardinality values.  We can determine the greatest and the least cardinality; the least upper bound and the greatest lower bound of a collection of Cardinality values; and, for two Cardinality values, determine whether one of the values is smaller than the other.bound(Cardinality)      #-> REG::Cardinality = 0\nibound(Cardinality)     #-> OPT_PLU::Cardinality = 3\n\nbound(OPT, PLU)         #-> OPT_PLU::Cardinality = 3\nibound(PLU, OPT)        #-> REG::Cardinality = 0\n\nfits(OPT, PLU)          #-> false\nfits(REG, OPT|PLU)      #-> true"
},

{
    "location": "shapes/#Data-shapes-1",
    "page": "Data Shape",
    "title": "Data shapes",
    "category": "section",
    "text": "The structure of composite data is specified with shape objects.NativeShape indicates a regular Julia value of a specific type.str_shp = NativeShape(String)\n#-> NativeShape(String)\n\neltype(str_shp)\n#-> StringTwo special shape types are used to indicate the value of any shape, and a value that cannot exist.any_shp = AnyShape()\n#-> AnyShape()\n\nnone_shp = NoneShape()\n#-> NoneShape()InputShape and OutputShape describe the structure of the query input and the query output.To describe the query input, we specify the shape of the input elements, the shapes of the parameters, and whether or not the input is framed.i_shp = InputShape(UInt, InputMode([:D => OutputShape(String)], true))\n#-> InputShape(UInt, InputMode([:D => OutputShape(String)], true))\n\ndomain(i_shp)\n#-> NativeShape(UInt)\n\nmode(i_shp)\n#-> InputMode([:D => OutputShape(String)], true)To describe the query output, we specify the shape and the cardinality of the output elements.o_shp = OutputShape(Int, OPT|PLU)\n#-> OutputShape(Int, OPT | PLU)\n\ncardinality(o_shp)\n#-> OPT_PLU::Cardinality = 3\n\ndomain(o_shp)\n#-> NativeShape(Int)\n\nmode(o_shp)\n#-> OutputMode(OPT | PLU)It is possible to decorate InputShape and OutputShape objects to specify additional attributes.  Currently, we can specify the label.o_shp |> decorate(label=:output)\n#-> OutputShape(:output, Int, OPT | PLU)RecordShape` specifies the shape of a record value where each field has a certain shape and cardinality.dept_shp = RecordShape(OutputShape(:name, String),\n                       OutputShape(:employee, UInt, OPT|PLU))\n#=>\nRecordShape(OutputShape(:name, String),\n            OutputShape(:employee, UInt, OPT | PLU))\n=#\n\nemp_shp = RecordShape(OutputShape(:name, String),\n                      OutputShape(:department, UInt),\n                      OutputShape(:position, String),\n                      OutputShape(:salary, Int),\n                      OutputShape(:manager, UInt, OPT),\n                      OutputShape(:subordinate, UInt, OPT|PLU))\n#=>\nRecordShape(OutputShape(:name, String),\n            OutputShape(:department, UInt),\n            OutputShape(:position, String),\n            OutputShape(:salary, Int),\n            OutputShape(:manager, UInt, OPT),\n            OutputShape(:subordinate, UInt, OPT | PLU))\n=#Using the combination of different shapes we can describe the structure of any data source.db_shp = RecordShape(OutputShape(:department, dept_shp, OPT|PLU),\n                     OutputShape(:employee, emp_shp, OPT|PLU))\n#=>\nRecordShape(OutputShape(:department,\n                        RecordShape(OutputShape(:name, String),\n                                    OutputShape(:employee, UInt, OPT | PLU)),\n                        OPT | PLU),\n            OutputShape(:employee,\n                        RecordShape(\n                            OutputShape(:name, String),\n                            OutputShape(:department, UInt),\n                            OutputShape(:position, String),\n                            OutputShape(:salary, Int),\n                            OutputShape(:manager, UInt, OPT),\n                            OutputShape(:subordinate, UInt, OPT | PLU)),\n                        OPT | PLU))\n=#"
},

{
    "location": "shapes/#Shape-ordering-1",
    "page": "Data Shape",
    "title": "Shape ordering",
    "category": "section",
    "text": "The same data can satisfy many different shape constraints.  For example, a vector BlockVector([Chicago]) can be said to have, among others, the shape OutputShape(String), the shape OutputShape(String, OPT|PLU) or the shape AnyShape().  We can tell, for any two shapes, if one of them is more specific than the other.fits(NativeShape(Int), NativeShape(Number))     #-> true\nfits(NativeShape(Int), NativeShape(String))     #-> false\n\nfits(InputShape(Int,\n                InputMode([:X => OutputShape(Int),\n                           :Y => OutputShape(String)],\n                          true)),\n     InputShape(Number,\n                InputMode([:X => OutputShape(Int, OPT)])))\n#-> true\nfits(InputShape(Int),\n     InputShape(Number, InputMode(true)))\n#-> false\nfits(InputShape(Int,\n                InputMode([:X => OutputShape(Int, OPT)])),\n     InputShape(Number,\n                InputMode([:X => OutputShape(Int)])))\n#-> false\n\nfits(OutputShape(Int),\n     OutputShape(Number, OPT))                  #-> true\nfits(OutputShape(Int, PLU),\n     OutputShape(Number, OPT))                  #-> false\nfits(OutputShape(Int),\n     OutputShape(String, OPT))                  #-> false\n\nfits(RecordShape(OutputShape(Int),\n                 OutputShape(String, OPT)),\n     RecordShape(OutputShape(Number),\n                 OutputShape(String, OPT|PLU)))     #-> true\nfits(RecordShape(OutputShape(Int, OPT),\n                 OutputShape(String)),\n     RecordShape(OutputShape(Number),\n                 OutputShape(String, OPT|PLU)))     #-> false\nfits(RecordShape(OutputShape(Int)),\n     RecordShape(OutputShape(Number),\n                 OutputShape(String, OPT|PLU)))     #-> falseShapes of different kinds are typically not compatible with each other.  The exceptions are AnyShape and NullShape.fits(NativeShape(Int), OutputShape(Int))    #-> false\nfits(NativeShape(Int), AnyShape())          #-> true\nfits(NoneShape(), NativeShape(Int))         #-> trueShape decorations are treated as additional shape constraints.fits(OutputShape(:name, String),\n     OutputShape(:name, String))                            #-> true\nfits(OutputShape(String),\n     OutputShape(:position, String))                        #-> false\nfits(OutputShape(:position, String),\n     OutputShape(String))                                   #-> true\nfits(OutputShape(:position, String),\n     OutputShape(:name, String))                            #-> falseFor any given number of shapes, we can find their upper bound, the shape that is more general than each of them.  We can also find their lower bound.bound(NativeShape(Int), NativeShape(Number))\n#-> NativeShape(Number)\nibound(NativeShape(Int), NativeShape(Number))\n#-> NativeShape(Int)\n\nbound(InputShape(Int, InputMode([:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true)),\n      InputShape(Number, InputMode([:X => OutputShape(Int)])))\n#=>\nInputShape(Number, InputMode([:X => OutputShape(Int, OPT)]))\n=#\nibound(InputShape(Int, InputMode([:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true)),\n       InputShape(Number, InputMode([:X => OutputShape(Int)])))\n#=>\nInputShape(Int,\n           InputMode([:X => OutputShape(Int), :Y => OutputShape(String)],\n                     true))\n=#\n\nbound(OutputShape(String, OPT), OutputShape(String, PLU))\n#-> OutputShape(String, OPT | PLU)\nibound(OutputShape(String, OPT), OutputShape(String, PLU))\n#-> OutputShape(String)\n\nbound(RecordShape(OutputShape(Int, PLU),\n                  OutputShape(String, OPT)),\n      RecordShape(OutputShape(Number),\n                  OutputShape(UInt, OPT|PLU)))\n#=>\nRecordShape(OutputShape(Number, PLU), OutputShape(AnyShape(), OPT | PLU))\n=#\nibound(RecordShape(OutputShape(Int, PLU),\n                   OutputShape(String, OPT)),\n       RecordShape(OutputShape(Number),\n                   OutputShape(UInt, OPT|PLU)))\n#=>\nRecordShape(OutputShape(Int), OutputShape(NoneShape(), OPT))\n=#For decorated shapes, incompatible labels are replaed with an empty label.bound(OutputShape(:name, String), OutputShape(:name, String))\n#-> OutputShape(:name, String)\n\nibound(OutputShape(:name, String), OutputShape(:name, String))\n#-> OutputShape(:name, String)\n\nbound(OutputShape(:position, String), OutputShape(:salary, Number))\n#-> OutputShape(AnyShape())\n\nibound(OutputShape(:position, String), OutputShape(:salary, Number))\n#-> OutputShape(Symbol(\"\"), NoneShape())\n\nbound(OutputShape(Int), OutputShape(:salary, Number))\n#-> OutputShape(Number)\n\nibound(OutputShape(Int), OutputShape(:salary, Number))\n#-> OutputShape(:salary, Int)"
},

{
    "location": "shapes/#Query-signature-1",
    "page": "Data Shape",
    "title": "Query signature",
    "category": "section",
    "text": "The signature of a query is a pair of an InputShape object and an OutputShape object.sig = Signature(InputShape(UInt),\n                OutputShape(RecordShape(OutputShape(:name, String),\n                                        OutputShape(:employee, UInt, OPT|PLU))))\n#-> UInt64 -> (name => String[1 .. 1], employee => UInt64[0 .. ∞])[1 .. 1]Different components of the signature can be easily extracted.shape(sig)\n#=>\nOutputShape(RecordShape(OutputShape(:name, String),\n                        OutputShape(:employee, UInt, OPT | PLU)))\n=#\n\nishape(sig)\n#-> InputShape(UInt)\n\ndomain(sig)\n#=>\nRecordShape(OutputShape(:name, String),\n            OutputShape(:employee, UInt, OPT | PLU))\n=#\n\nmode(sig)\n#-> OutputMode()\n\nidomain(sig)\n#-> NativeShape(UInt)\n\nimode(sig)\n#-> InputMode()"
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
    "text": "In DataKnots, structured data is stored in a column-oriented format, serialized using specialized composite vector types.  Consequently, operations on data must also be adapted to the column-oriented format.Module DataKnots implements the Query interface of vectorized data transformations and provives a rich library of query primitives and combinators.using DataKnots:\n    @VectorTree,\n    as_block,\n    block_filler,\n    block_lift,\n    chain_of,\n    column,\n    decode_missing,\n    decode_tuple,\n    decode_vector,\n    filler,\n    flat_block,\n    in_block,\n    in_tuple,\n    lift,\n    null_filler,\n    pass,\n    pull_block,\n    pull_every_block,\n    record_lift,\n    tuple_lift,\n    tuple_of"
},

{
    "location": "queries/#Lifting-1",
    "page": "Query Algebra",
    "title": "Lifting",
    "category": "section",
    "text": "Lifting lets us convert a scalar function to a query.Any unary scalar function could be lifted to a vectorized form.  Consider, for example, function titlecase(), which transforms the input string by capitalizing the first letter of each word and converting every other character to lowercase.titlecase(\"JEFFERY A\")      #-> \"Jeffery A\"This function can be converted to a query using the lift operator.q = lift(titlecase)\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [\"Jeffery A\", \"James A\", \"Terry A\"]If a scalar function takes several arguments, it could be lifted to a query on TupleVector instances.  For example, the comparison operator >, which maps a pair of integer values to a Boolean value, could be lifted to a query tuple_lift(>) that transforms a TupleVector instance with two integer columns to a Boolean vector.q = tuple_lift(>)\nq(@VectorTree (Int, Int) [260004 200000; 185364 200000; 170112 200000])\n#-> Bool[true, false, false]In a similar manner, a function with a vector argument can be converted to a query on BlockVector instances.  For example, function length(), which returns the length of a vector, could be lifted to a query block_lift(length) that transforms a block vector to an integer vector containing block lengths.q = block_lift(length)\nq(@VectorTree [String] [[\"JEFFERY A\", \"NANCY A\"], [\"JAMES A\"]])\n#-> [2, 1]A constant value could be lifted to a query as well.  The lifted constant maps any input vector to a vector of constant values.q = filler(200000)\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [200000, 200000, 200000]"
},

{
    "location": "queries/#Query-interface-1",
    "page": "Query Algebra",
    "title": "Query interface",
    "category": "section",
    "text": "Functions such as lift(), tuple_lift(), and many others return a Query object.  The Query interface represents a vectorized data transformation that maps an input vector to an output vector of the same length.Functions that take one or more Query instances as arguments and return a new Query object as the result are called combinators.  Combinators are used to assemble elementary queries into complex query expressions.For example, composition combinator chain_of() assembles a series of queries into a sequential composition, which transforms the input vector by sequentially applying the given queries.q = chain_of(lift(split), lift(first), lift(titlecase))\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [\"Jeffery\", \"James\", \"Terry\"]Another combinator, tuple constructor tuple_of() assembles a series of queries into a parallel composition.  It outputs a TupleVector instance, which columns are generated by applying the given queries to the input vector.q = tuple_of(lift(titlecase), lift(last))\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> @VectorTree (String, Char) [(\"Jeffery A\", \'A\'), (\"James A\", \'A\'), (\"Terry A\", \'A\')]An individual column of a TupleVector instance could be extracted using a column() query.q = column(:salary)\nq(@VectorTree (name=String, salary=Int) [(\"JEFFERY A\", 101442), (\"JAMES A\", 103350), (\"TERRY A\", 93354)])\n#-> [101442, 103350, 93354]"
},

{
    "location": "queries/#DataKnots.Query",
    "page": "Query Algebra",
    "title": "DataKnots.Query",
    "category": "type",
    "text": "Query(op, args...)\n\nA query object represents a vectorized data transformation.\n\nParameter op is a function that performs the transformation; args are extra arguments to be passed to the function.\n\nThe query transforms any input vector by invoking op with the following arguments:\n\nop(rt::Runtime, input::AbstractVector, args...)\n\nThe result of op must be the output vector, which should be of the same length as the input vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Runtime",
    "page": "Query Algebra",
    "title": "DataKnots.Runtime",
    "category": "type",
    "text": "Runtime()\n\nRuntime state for query evaluation.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.any_block-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.any_block",
    "category": "method",
    "text": "any_block() :: Query\n\nThis query applies any to a block vector with Bool elements.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.as_block-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.as_block",
    "category": "method",
    "text": "as_block() :: Query\n\nThis query produces a block vector with one-element blocks wrapping the values of the input vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.block_filler",
    "page": "Query Algebra",
    "title": "DataKnots.block_filler",
    "category": "function",
    "text": "block_filler(block::AbstractVector, card::Cardinality) :: Query\n\nThis query produces a block vector filled with the given block.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.block_lift",
    "page": "Query Algebra",
    "title": "DataKnots.block_lift",
    "category": "function",
    "text": "block_lift(f) :: Query\nblock_lift(f, default) :: Query\n\nf is a function that expects a vector argument.\n\nThe query applies f to each block of the input block vector.  When a block is empty, default (if specified) is used as the output value.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.chain_of",
    "page": "Query Algebra",
    "title": "DataKnots.chain_of",
    "category": "function",
    "text": "chain_of(q₁::Query, q₂::Query … qₙ::Query) :: Query\n\nThis query sequentially applies q₁, q₂ … qₙ.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.column-Tuple{Union{Int64, Symbol}}",
    "page": "Query Algebra",
    "title": "DataKnots.column",
    "category": "method",
    "text": "column(lbl::Union{Int,Symbol}) :: Query\n\nThis query extracts the specified column of a tuple vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.count_block-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.count_block",
    "category": "method",
    "text": "count_block() :: Query\n\nThis query converts a block vector to a vector of block lengths.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.decode_missing-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.decode_missing",
    "category": "method",
    "text": "decode_missing() :: Query\n\nThis query transforms a vector that contains missing elements to a block vector with missing elements replaced by empty blocks.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.decode_tuple-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.decode_tuple",
    "category": "method",
    "text": "decode_tuple() :: Query\n\nThis query transforms a vector of tuples to a tuple vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.decode_vector-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.decode_vector",
    "category": "method",
    "text": "decode_vector() :: Query\n\nThis query transforms a vector with vector elements to a block vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.designate",
    "page": "Query Algebra",
    "title": "DataKnots.designate",
    "category": "function",
    "text": "designate(::Query, ::Signature) :: Query\ndesignate(::Query, ::InputShape, ::OutputShape) :: Query\nq::Query |> designate(::Signature) :: Query\nq::Query |> designate(::InputShape, ::OutputShape) :: Query\n\nSets the query signature.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.filler-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.filler",
    "category": "method",
    "text": "filler(val) :: Query\n\nThis query produces a vector filled with the given value.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.flat_block-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.flat_block",
    "category": "method",
    "text": "flat_block() :: Query\n\nThis query flattens a nested block vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.flat_tuple-Tuple{Union{Int64, Symbol}}",
    "page": "Query Algebra",
    "title": "DataKnots.flat_tuple",
    "category": "method",
    "text": "flat_tuple(lbl::Union{Int,Symbol}) :: Query\n\nThis query flattens a nested tuple vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.in_block-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.in_block",
    "category": "method",
    "text": "in_block(q::Query) :: Query\n\nThis query transforms a block vector by applying q to its vector of elements.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.in_tuple-Tuple{Union{Int64, Symbol},Any}",
    "page": "Query Algebra",
    "title": "DataKnots.in_tuple",
    "category": "method",
    "text": "in_tuple(lbl::Union{Int,Symbol}, q::Query) :: Query\n\nThis query transforms a tuple vector by applying q to the specified column.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.lift-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.lift",
    "category": "method",
    "text": "lift(f) :: Query\n\nf is any scalar unary function.\n\nThe query applies f to each element of the input vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.null_filler-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.null_filler",
    "category": "method",
    "text": "null_filler() :: Query\n\nThis query produces a block vector with empty blocks.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.optimize-Tuple{DataKnots.Query}",
    "page": "Query Algebra",
    "title": "DataKnots.optimize",
    "category": "method",
    "text": "optimize(::Query) :: Query\n\nRewrites the query to make it (hopefully) faster.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.pass-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.pass",
    "category": "method",
    "text": "pass() :: Query\n\nThis query returns its input unchanged.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.pull_block-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.pull_block",
    "category": "method",
    "text": "pull_block(lbl::Union{Int,Symbol}) :: Query\n\nThis query transforms a tuple vector with a column of blocks to a block vector with tuple elements.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.pull_every_block-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.pull_every_block",
    "category": "method",
    "text": "pull_every_block() :: Query\n\nThis query transforms a tuple vector with block columns to a block vector with tuple elements.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.record_lift-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.record_lift",
    "category": "method",
    "text": "record_lift(f) :: Query\n\nf is an n-ary function.\n\nThis query expects the input to be an n-tuple vector with each column being a block vector.  The query produces a block vector, where each block is generated by applying f to every combination of values from the input blocks.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.sieve-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.sieve",
    "category": "method",
    "text": "sieve() :: Query\n\nThis query filters a vector of pairs by the second column.  The query expects a pair vector, whose second column is a Bool vector.  It produces a block vector with 0-element or 1-element blocks containing the elements of the first column.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.signature-Tuple{DataKnots.Query}",
    "page": "Query Algebra",
    "title": "DataKnots.signature",
    "category": "method",
    "text": "signature(::Query) :: Signature\n\nReturns the query signature.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.take_by",
    "page": "Query Algebra",
    "title": "DataKnots.take_by",
    "category": "function",
    "text": "take_by(rev::Bool=false) :: Query\n\nThis query takes a pair vector of blocks and integers, and returns the first column with blocks restricted by the second column.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.take_by",
    "page": "Query Algebra",
    "title": "DataKnots.take_by",
    "category": "function",
    "text": "take_by(N::Int, rev::Bool=false) :: Query\n\nThis query transforms a block vector by keeping the first N elements of each block.  If rev is true, the query drops the first N elements of each block.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.tuple_lift-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.tuple_lift",
    "category": "method",
    "text": "tuple_lift(f) :: Query\n\nf is an n-ary function.\n\nThe query applies f to each row of an n-tuple vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.tuple_of-Tuple",
    "page": "Query Algebra",
    "title": "DataKnots.tuple_of",
    "category": "method",
    "text": "tuple_of(q₁::Query, q₂::Query … qₙ::Query) :: Query\n\nThis query produces an n-tuple vector, whose columns are generated by applying q₁, q₂ … qₙ to the input vector.\n\n\n\n\n\n"
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
    "location": "queries/#Lifting-2",
    "page": "Query Algebra",
    "title": "Lifting",
    "category": "section",
    "text": "Many vector operations can be generated by lifting.  For example, filler() generates a primitive operation that maps any input vector to the output vector of the same length filled with the given value.q = filler(200000)\n#-> filler(200000)\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [200000, 200000, 200000]Similarly, the output of block_filler() is a block vector filled with the given block.q = block_filler([\"POLICE\", \"FIRE\"])\n#-> block_filler([\"POLICE\", \"FIRE\"], OPT | PLU)\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [String] [[\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"]]A variant of block_filler() called null_filler() outputs a block vector with empty blocks.q = null_filler()\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [Union{}, OPT] [missing, missing, missing]Any scalar function could be lifted to a vector operation by applying it to each element of the input vector.q = lift(titlecase)\n#-> lift(titlecase)\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [\"Garry M\", \"Anthony R\", \"Dana A\"]Similarly, any scalar function of several arguments could be lifted to an operation on tuple vectors.q = tuple_lift(>)\n#-> tuple_lift(>)\n\nq(@VectorTree (Int, Int) [260004 200000; 185364 200000; 170112 200000])\n#-> Bool[true, false, false]It is also possible to apply a scalar function of several arguments to a tuple vector that has block vectors for its columns.  In this case, the function is applied to every combination of values from all the blocks on the same row.q = record_lift(>)\n\nq(@VectorTree ([Int], [Int]) [[260004, 185364, 170112] 200000; missing 200000; [202728, 197736] [200000, 200000]])\n#-> @VectorTree [Bool] [[true, false, false], [], [true, true, false, false]]Any function that takes a vector argument can be lifted to an operation on block vectors.q = block_lift(length)\n#-> block_lift(length)\n\nq(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]])\n#-> [3, 2]Some vector functions may expect a non-empty vector as an argument.  In this case, we should provide the value to replace empty blocks.q = block_lift(maximum, missing)\n#-> block_lift(maximum, missing)\n\nq(@VectorTree [Int] [[260004, 185364, 170112], [], [202728, 197736]])\n#-> Union{Missing, Int}[260004, missing, 202728]"
},

{
    "location": "queries/#Decoding-vectors-1",
    "page": "Query Algebra",
    "title": "Decoding vectors",
    "category": "section",
    "text": "Any vector of tuples can be converted to a tuple vector.q = decode_tuple()\n#-> decode_tuple()\n\nq([(\"GARRY M\", 260004), (\"ANTHONY R\", 185364), (\"DANA A\", 170112)]) |> display\n#=>\nTupleVector of 3 × (String, Int):\n (\"GARRY M\", 260004)\n (\"ANTHONY R\", 185364)\n (\"DANA A\", 170112)\n=#Vectors of named tuples are also supported.q([(name=\"GARRY M\", salary=260004), (name=\"ANTHONY R\", salary=185364), (name=\"DANA A\", salary=170112)]) |> display\n#=>\nTupleVector of 3 × (name = String, salary = Int):\n (name = \"GARRY M\", salary = 260004)\n (name = \"ANTHONY R\", salary = 185364)\n (name = \"DANA A\", salary = 170112)\n=#A vector of vector objects can be converted to a block vector.q = decode_vector()\n#-> decode_vector()\n\nq([[260004, 185364, 170112], Int[], [202728, 197736]])\n#-> @VectorTree [Int] [[260004, 185364, 170112], [], [202728, 197736]]Similarly, a vector containing missing values can be converted to a block vector with zero- and one-element blocks.q = decode_missing()\n#-> decode_missing()\n\nq([260004, 185364, 170112, missing, 202728, 197736])\n#-> @VectorTree [Int, OPT] [260004, 185364, 170112, missing, 202728, 197736]"
},

{
    "location": "queries/#Tuple-vectors-1",
    "page": "Query Algebra",
    "title": "Tuple vectors",
    "category": "section",
    "text": "To create a tuple vector, we use the combinator tuple_of(). Its arguments are the functions that generate the columns of the tuple.q = tuple_of(:title => lift(titlecase), :last => lift(last))\n#-> tuple_of([:title, :last], [lift(titlecase), lift(last)])\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"]) |> display\n#=>\nTupleVector of 3 × (title = String, last = Char):\n (title = \"Garry M\", last = \'M\')\n (title = \"Anthony R\", last = \'R\')\n (title = \"Dana A\", last = \'A\')\n=#To extract a column of a tuple vector, we use the primitive column().  It accepts either the column position or the column name.q = column(1)\n#-> column(1)\n\nq(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112])\n#-> [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]\n\nq = column(:salary)\n#-> column(:salary)\n\nq(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112])\n#-> [260004, 185364, 170112]Finally, we can apply an arbitrary transformation to a selected column of a tuple vector.q = in_tuple(:name, lift(titlecase))\n#-> in_tuple(:name, lift(titlecase))\n\nq(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]) |> display\n#=>\nTupleVector of 3 × (name = String, salary = Int):\n (name = \"Garry M\", salary = 260004)\n (name = \"Anthony R\", salary = 185364)\n (name = \"Dana A\", salary = 170112)\n=#"
},

{
    "location": "queries/#Block-vectors-1",
    "page": "Query Algebra",
    "title": "Block vectors",
    "category": "section",
    "text": "Primitive as_block() wraps the elements of the input vector to one-element blocks.q = as_block()\n#-> as_block()\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [String, REG] [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]In the opposite direction, primitive flat_block() flattens a block vector with block elements.q = flat_block()\n#-> flat_block()\n\nq(@VectorTree [[String]] [[[\"GARRY M\"], [\"ANTHONY R\", \"DANA A\"]], [missing, [\"JOSE S\"], [\"CHARLES S\"]]])\n#-> @VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]]Finally, we can apply an arbitrary transformation to every element of a block vector.q = in_block(lift(titlecase))\n#-> in_block(lift(titlecase))\n\nq(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]])\n#-> @VectorTree [String] [[\"Garry M\", \"Anthony R\", \"Dana A\"], [\"Jose S\", \"Charles S\"]]The pull_block() primitive converts a tuple vector with a block column to a block vector of tuples.q = pull_block(1)\n#-> pull_block(1)\n\nq(@VectorTree ([Int], [Int]) [\n    [260004, 185364, 170112]    200000\n    missing                     200000\n    [202728, 197736]            [200000, 200000]]\n) |> display\n#=>\nBlockVector of 3 × [(Int, [Int])]:\n [(260004, [200000]), (185364, [200000]), (170112, [200000])]\n []\n [(202728, [200000, 200000]), (197736, [200000, 200000])]\n=#It is also possible to pull all block columns from a tuple vector.q = pull_every_block()\n#-> pull_every_block()\n\nq(@VectorTree ([Int], [Int]) [\n    [260004, 185364, 170112]    200000\n    missing                     200000\n    [202728, 197736]            [200000, 200000]]\n) |> display\n#=>\nBlockVector of 3 × [(Int, Int)]:\n [(260004, 200000), (185364, 200000), (170112, 200000)]\n []\n [(202728, 200000), (202728, 200000), (197736, 200000), (197736, 200000)]\n=#"
},

{
    "location": "queries/#Composition-1",
    "page": "Query Algebra",
    "title": "Composition",
    "category": "section",
    "text": "We can compose a sequence of transformations using the chain_of() combinator.q = chain_of(\n        column(:employee),\n        in_block(lift(titlecase)))\n#-> chain_of(column(:employee), in_block(lift(titlecase)))\n\nq(@VectorTree (department = String, employee = [String]) [\n    \"POLICE\"    [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]\n    \"FIRE\"      [\"JOSE S\", \"CHARLES S\"]])\n#-> @VectorTree [String] [[\"Garry M\", \"Anthony R\", \"Dana A\"], [\"Jose S\", \"Charles S\"]]The empty chain chain_of() has an alias pass().q = pass()\n#-> pass()\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]"
},

{
    "location": "lifting/#",
    "page": "Lifting Scalar Functions to Combinators",
    "title": "Lifting Scalar Functions to Combinators",
    "category": "page",
    "text": ""
},

{
    "location": "lifting/#Lifting-Scalar-Functions-to-Combinators-1",
    "page": "Lifting Scalar Functions to Combinators",
    "title": "Lifting Scalar Functions to Combinators",
    "category": "section",
    "text": "using DataKnots\n\nusing DataKnots:\n    @VectorTree\n\ndb = DataKnot(\n    @VectorTree (name = [String], employee = [(name = [String], salary = [Int])]) [\n        \"POLICE\"    [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n        \"FIRE\"      [\"JOSE S\" 202728; \"CHARLES S\" 197736]\n    ])\n#=>\n  │ DataKnot                                                   │\n  │ name    employee                                           │\n──┼────────────────────────────────────────────────────────────┤\n1 │ POLICE  GARRY M, 260004; ANTHONY R, 185364; DANA A, 170112 │\n2 │ FIRE    JOSE S, 202728; CHARLES S, 197736                  │\n=#\n\nrun(db >> It.employee.name)\n#=>\n  │ name      │\n──┼───────────┤\n1 │ GARRY M   │\n2 │ ANTHONY R │\n3 │ DANA A    │\n4 │ JOSE S    │\n5 │ CHARLES S │\n=#\n\nTitleCase = Lift(s -> titlecase(s), It)\n\nrun(db >> It.employee.name >> TitleCase)\n#=>\n  │ DataKnot  │\n──┼───────────┤\n1 │ Garry M   │\n2 │ Anthony R │\n3 │ Dana A    │\n4 │ Jose S    │\n5 │ Charles S │\n=#\n\nSplit = Lift(s -> split(s), It)\n\nrun(db >> It.employee.name >> Split)\n#=>\n   │ DataKnot │\n───┼──────────┤\n 1 │ GARRY    │\n 2 │ M        │\n 3 │ ANTHONY  │\n 4 │ R        │\n 5 │ DANA     │\n 6 │ A        │\n 7 │ JOSE     │\n 8 │ S        │\n 9 │ CHARLES  │\n10 │ S        │\n=#\n\nrun(db >> (\n    :employee =>\n      It.employee >>\n        Record(:name =>\n          It.name >> Split)))\n#=>\n  │ employee   │\n  │ name       │\n──┼────────────┤\n1 │ GARRY; M   │\n2 │ ANTHONY; R │\n3 │ DANA; A    │\n4 │ JOSE; S    │\n5 │ CHARLES; S │\n=#\n\nRepeat(V,N) = Lift((v,n) -> [v for i in 1:n], V, N)\nrun(db >> Record(It.name, Repeat(\"Go!\", 3)))\n#=>\n  │ DataKnot              │\n  │ name    #2            │\n──┼───────────────────────┤\n1 │ POLICE  Go!; Go!; Go! │\n2 │ FIRE    Go!; Go!; Go! │\n=#"
},

{
    "location": "pipelines/#",
    "page": "Query Algebra",
    "title": "Query Algebra",
    "category": "page",
    "text": ""
},

{
    "location": "pipelines/#Query-Algebra-1",
    "page": "Query Algebra",
    "title": "Query Algebra",
    "category": "section",
    "text": "using DataKnots\n\ndb = DataKnot(3)\n\nF = (It .+ 4) >> (It .* 6)\n#-> (It .+ 4) >> It .* 6\n\nrun(db >> F)\n#=>\n│ DataKnot │\n├──────────┤\n│       42 │\n=#\n\nusing DataKnots: prepare\n\nprepare(DataKnot(3) >> F)\n#=>\nchain_of(block_filler([3], REG),\n         in_block(chain_of(tuple_of([], [as_block(), block_filler([4], REG)]),\n                           record_lift(+))),\n         flat_block(),\n         in_block(chain_of(tuple_of([], [as_block(), block_filler([6], REG)]),\n                           record_lift(*))),\n         flat_block())\n=#\n\nusing DataKnots: @VectorTree\n\ndb = DataKnot(\n    @VectorTree (name = [String], employee = [(name = [String], salary = [Int])]) [\n        \"POLICE\"    [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n        \"FIRE\"      [\"JOSE S\" 202728; \"CHARLES S\" 197736]\n    ])\n#=>\n  │ DataKnot                                                   │\n  │ name    employee                                           │\n──┼────────────────────────────────────────────────────────────┤\n1 │ POLICE  GARRY M, 260004; ANTHONY R, 185364; DANA A, 170112 │\n2 │ FIRE    JOSE S, 202728; CHARLES S, 197736                  │\n=#\n\nrun(db >> Field(:name))\n#=>\n  │ name   │\n──┼────────┤\n1 │ POLICE │\n2 │ FIRE   │\n=#\n\nrun(db >> It.name)\n#=>\n  │ name   │\n──┼────────┤\n1 │ POLICE │\n2 │ FIRE   │\n=#\n\nrun(db >> Field(:employee) >> Field(:salary))\n#=>\n  │ salary │\n──┼────────┤\n1 │ 260004 │\n2 │ 185364 │\n3 │ 170112 │\n4 │ 202728 │\n5 │ 197736 │\n=#\n\nrun(db >> It.employee.salary)\n#=>\n  │ salary │\n──┼────────┤\n1 │ 260004 │\n2 │ 185364 │\n3 │ 170112 │\n4 │ 202728 │\n5 │ 197736 │\n=#\n\nrun(db >> Count(It.employee))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        3 │\n2 │        2 │\n=#\n\nrun(db >> Count)\n#=>\n│ DataKnot │\n├──────────┤\n│        2 │\n=#\n\nrun(db >> Count(It.employee) >> Max)\n#=>\n│ DataKnot │\n├──────────┤\n│        3 │\n=#\n\nrun(db >> It.employee >> Filter(It.salary .> 200000))\n#=>\n  │ employee        │\n  │ name     salary │\n──┼─────────────────┤\n1 │ GARRY M  260004 │\n2 │ JOSE S   202728 │\n=#\n\nrun(db >> Count(It.employee) .> 2)\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │     true │\n2 │    false │\n=#\n\nrun(db >> Filter(Count(It.employee) .> 2))\n#=>\n  │ DataKnot                                                   │\n  │ name    employee                                           │\n──┼────────────────────────────────────────────────────────────┤\n1 │ POLICE  GARRY M, 260004; ANTHONY R, 185364; DANA A, 170112 │\n=#\n\nrun(db >> Filter(Count(It.employee) .> 2) >> Count)\n#=>\n│ DataKnot │\n├──────────┤\n│        1 │\n=#\n\nrun(db >> Record(It.name, :size => Count(It.employee)))\n#=>\n  │ DataKnot     │\n  │ name    size │\n──┼──────────────┤\n1 │ POLICE     3 │\n2 │ FIRE       2 │\n=#\n\nrun(db >> It.employee >> Filter(It.salary .> It.S),\n      S=200000)\n#=>\n  │ employee        │\n  │ name     salary │\n──┼─────────────────┤\n1 │ GARRY M  260004 │\n2 │ JOSE S   202728 │\n=#\n\nrun(\n    db >> Given(:S => Max(It.employee.salary),\n                It.employee >> Filter(It.salary .== It.S)))\n#=>\n  │ employee        │\n  │ name     salary │\n──┼─────────────────┤\n1 │ GARRY M  260004 │\n2 │ JOSE S   202728 │\n=#\n\nrun(db >> It.employee.salary >> Take(3))\n#=>\n  │ salary │\n──┼────────┤\n1 │ 260004 │\n2 │ 185364 │\n3 │ 170112 │\n=#\n\nrun(db >> It.employee.salary >> Drop(3))\n#=>\n  │ salary │\n──┼────────┤\n1 │ 202728 │\n2 │ 197736 │\n=#\n\nrun(db >> It.employee.salary >> Take(-3))\n#=>\n  │ salary │\n──┼────────┤\n1 │ 260004 │\n2 │ 185364 │\n=#\n\nrun(db >> It.employee.salary >> Drop(-3))\n#=>\n  │ salary │\n──┼────────┤\n1 │ 170112 │\n2 │ 202728 │\n3 │ 197736 │\n=#\n\nrun(db >> It.employee.salary >> Take(Count(db >> It.employee) .÷ 2))\n#=>\n  │ salary │\n──┼────────┤\n1 │ 260004 │\n2 │ 185364 │\n=#"
},

]}
