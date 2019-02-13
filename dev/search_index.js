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
    "location": "start/#",
    "page": "Installation Instructions",
    "title": "Installation Instructions",
    "category": "page",
    "text": ""
},

{
    "location": "start/#Installation-Instructions-1",
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
    "text": "Consider a pipeline Hello that produces a string value, \"Hello World\". It is built using the Lift primitive, which converts a Julia value into a pipeline component. This pipeline can then be run() to produce its output.Hello = Lift(\"Hello World\")\nrun(Hello)\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#The output of the pipeline is encapsulated in a DataKnot, which is a container holding structured, vectorized data. We can get the corresponding Julia value using get().get(run(Hello)) #-> \"Hello World\"Consider another pipeline created by applying Lift to 3:5, a native UnitRange value. When run(), this pipeline emits a sequence of integers from 3 to 5.run(Lift(3:5))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        3 │\n2 │        4 │\n3 │        5 │\n=#The output of this knot can also be converted back to native Julia.get(run(Lift(3:5))) #-> 3:5DataKnots track each pipeline\'s cardinality. Observe that the Hello pipeline produces a singular value, while the Lift(3:5) pipeline is plural. In the output notation for plural knots, indices are in the first column and values are in remaining columns."
},

{
    "location": "thinking/#Composition-and-Identity-1",
    "page": "Thinking in Combinators",
    "title": "Composition & Identity",
    "category": "section",
    "text": "Two pipelines can be connected sequentially using the composition combinator (>>). Consider the composition Lift(1:3) >> Hello. Since Lift(1:3) emits 3 values and Hello emits \"Hello World\" regardless of its input, their composition emits 3 copies of \"Hello World\".run(Lift(1:3) >> Hello)\n#=>\n  │ DataKnot    │\n──┼─────────────┤\n1 │ Hello World │\n2 │ Hello World │\n3 │ Hello World │\n=#When pipelines that produce plural values are combined, the output is flattened into a single sequence. The following expression calculates Lift(7:9) twice and then flattens the outputs.run(Lift(1:2) >> Lift(7:9))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        7 │\n2 │        8 │\n3 │        9 │\n4 │        7 │\n5 │        8 │\n6 │        9 │\n=#The identity with respect to pipeline composition is called It. This primitive can be composed with any pipeline without changing the pipeline\'s output.run(Hello >> It)\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#The identity, It, can be used to construct pipelines which rely upon the output from previous processing.Increment = It .+ 1\nrun(Lift(1:3) >> Increment)\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │        3 │\n3 │        4 │\n=#In DataKnots, pipelines are built algebraically, using pipeline composition, identity and other combinators. This lets us define sophisticated pipeline components and remix them in creative ways."
},

{
    "location": "thinking/#Lifting-Julia-Functions-1",
    "page": "Thinking in Combinators",
    "title": "Lifting Julia Functions",
    "category": "section",
    "text": "With DataKnots, any native Julia expression can be lifted to build a Pipeline. Consider the Julia function double() that, when applied to a Number, produces a Number:double(x) = 2x\ndouble(3) #-> 6What we want is an analogue to double that, instead of operating on numbers, operates on pipelines. Such functions are called pipeline combinators. We can convert any Julia function to a pipeline combinator by passing to Lift the function and its arguments.Double(X) = Lift(double, (X,))When given an argument, the combinator Double can then be used to build a pipeline that produces a doubled value.run(Double(21))\n#=>\n│ DataKnot │\n├──────────┤\n│       42 │\n=#In combinator form, Double can be used within pipeline composition. To build a pipeline component that doubles its input, the Double combinator could have It as its argument.run(Lift(1:3) >> Double(It))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │        4 │\n3 │        6 │\n=#Since this use of native Julia functions as combinators is common enough, Julia\'s broadcast syntax (using a period) is overloaded to make translation convenient. Any native Julia function, such as double, can be used as a combinator as follows:run(Lift(1:3) >> double.(It))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │        4 │\n3 │        6 │\n=#Automatic lifting also applies to built-in Julia operators. For example, the expression It .+ 1 is a pipeline component that increments each one of its input values.run(Lift(1:3) >> (It .+ 1))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │        3 │\n3 │        4 │\n=#One can define combinators in terms of expressions.OneTo(N) = UnitRange.(1, Lift(N))When a lifted function is vector-valued, the resulting combinator builds plural pipelines.run(OneTo(3))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        1 │\n2 │        2 │\n3 │        3 │\n=#In DataKnots, pipeline combinators can be constructed directly from native Julia functions. This lets us take advantage of Julia\'s rich statistical and data processing functions."
},

{
    "location": "thinking/#Aggregates-1",
    "page": "Thinking in Combinators",
    "title": "Aggregates",
    "category": "section",
    "text": "Some pipeline combinators transform a plural pipeline into a singular pipeline; we call them aggregate combinators. Consider the operation of the Count combinator.run(Count(OneTo(3)))\n#=>\n│ DataKnot │\n├──────────┤\n│        3 │\n=#As a convenience, Count can also be used as a pipeline primitive.run(OneTo(3) >> Count)\n#=>\n│ DataKnot │\n├──────────┤\n│        3 │\n=#It\'s possible to use aggregates within a plural pipeline. In this example, as the outer OneTo goes from 1 to 3, the Sum aggregate would calculate its output from OneTo(1), OneTo(2) and OneTo(3).run(OneTo(3) >> Sum(OneTo(It)))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        1 │\n2 │        3 │\n3 │        6 │\n=#However, if we rewrite the pipeline to use Sum as a pipeline primitive, we get a different result.run(OneTo(3) >> OneTo(It) >> Sum)\n#=>\n│ DataKnot │\n├──────────┤\n│       10 │\n=#Since pipeline composition (>>) is associative, adding parenthesis around OneTo(It) >> Sum will not change the result.run(OneTo(3) >> (OneTo(It) >> Sum))\n#=>\n│ DataKnot │\n├──────────┤\n│       10 │\n=#Instead of using parenthesis, we need to wrap OneTo(It) >> Sum with the Each combinator. This combinator builds a pipeline that processes its input elementwise.run(OneTo(3) >> Each(OneTo(It) >> Sum))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        1 │\n2 │        3 │\n3 │        6 │\n=#Native Julia language aggregates, such as sum, can be automatically lifted. DataKnots automatically converts a plural pipeline into an input vector required by the native aggregate.using Statistics\nMean(X) = Lift(mean, (X,))\nrun(Mean(OneTo(3) >> Sum(OneTo(It))))\n#=>\n│ DataKnot │\n├──────────┤\n│  3.33333 │\n=#To use Mean as a pipeline primitive, there are two steps. First, we use Then to build a pipeline that aggregates from its input. Second, we register a Lift to this pipeline when the combinator\'s name is mentioned in a pipeline expression.DataKnots.Lift(::typeof(Mean)) = Then(Mean)Once these are done, one could take an average of sums as follows:run(Lift(1:3) >> Sum(OneTo(It)) >> Mean)\n#=>\n│ DataKnot │\n├──────────┤\n│  3.33333 │\n=#In DataKnots, aggregate operations are naturally expressed as pipeline combinators. Moreover, custom aggregates can be easily constructed as native Julia functions and lifted into the pipeline algebra."
},

{
    "location": "thinking/#Filtering-and-Slicing-Data-1",
    "page": "Thinking in Combinators",
    "title": "Filtering & Slicing Data",
    "category": "section",
    "text": "DataKnots comes with combinators for rearranging data. Consider Filter, which takes one parameter, a predicate pipeline that for each input value decides if that value should be included in the output.run(OneTo(6) >> Filter(It .> 3))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        4 │\n2 │        5 │\n3 │        6 │\n=#Contrast this with the built-in Julia function filter().filter(x -> x > 3, 1:6) #-> [4, 5, 6]Where filter() returns a filtered dataset, the Filter combinator returns a pipeline component, which could then be composed with any data generating pipeline.KeepEven = Filter(iseven.(It))\nrun(OneTo(6) >> KeepEven)\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │        4 │\n3 │        6 │\n=#Similar to Filter, the Take and Drop combinators can be used to slice an input stream: Drop is used to skip over input, Take ignores output past a particular point.run(OneTo(9) >> Drop(3) >> Take(3))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        4 │\n2 │        5 │\n3 │        6 │\n=#Since Take is a combinator, its argument could also be a full blown pipeline. This next example, FirstHalf is a combinator that builds a pipeline returning the first half of an input stream.FirstHalf(X) = Each(X >> Take(Count(X) .÷ 2))\nrun(FirstHalf(OneTo(6)))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        1 │\n2 │        2 │\n3 │        3 │\n=#Using Then, this combinator could be used with pipeline composition:run(OneTo(6) >> Then(FirstHalf))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        1 │\n2 │        2 │\n3 │        3 │\n=#In DataKnots, filtering and slicing are realized as pipeline components. They are attached to data processing pipelines using the composition combinator. This brings common data processing concepts into our pipeline algebra."
},

{
    "location": "thinking/#Query-Parameters-1",
    "page": "Thinking in Combinators",
    "title": "Query Parameters",
    "category": "section",
    "text": "With DataKnots, parameters can be provided so that static data can be used within query expressions. By convention, we use upper case, singular labels for query parameters.run(\"Hello \" .* Lookup(:WHO), WHO=\"World\")\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#To make Lookup convenient, It provides a shorthand syntax.run(\"Hello \" .* It.WHO, WHO=\"World\")\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#Query parameters are available anywhere in the query. They could, for example be used within a filter.query = OneTo(6) >> Filter(It .> It.START)\nrun(query, START=3)\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        4 │\n2 │        5 │\n3 │        6 │\n=#Parameters can also be defined as part of a query using Given. This combinator takes set of pairs (=>) that map symbols (:name) onto query expressions. The subsequent argument is then evaluated in a naming context where the defined parameters are available for reuse.run(Given(:WHO => \"World\",\n    \"Hello \" .* Lookup(:WHO)))\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#Query parameters can be especially useful when managing aggregates, or with expressions that one may wish to repeat more than once.GreaterThanAverage(X) =\n  Given(:AVG => Mean(X),\n        X >> Filter(It .> Lookup(:AVG)))\n\nrun(OneTo(6) >> Then(GreaterThanAverage))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        4 │\n2 │        5 │\n3 │        6 │\n=#In DataKnots, query parameters passed in to the run command permit external data to be used within query expressions. Parameters that are defined with Given can be used to remember values and reuse them."
},

{
    "location": "thinking/#Records-and-Labels-1",
    "page": "Thinking in Combinators",
    "title": "Records & Labels",
    "category": "section",
    "text": "Internally, DataKnots use a column-oriented storage mechanism that handles hierarchies and graphs. Data objects in this model can be created using the Record combinator.GM = Record(:name => \"GARRY M\", :salary => 260004)\nrun(GM)\n#=>\n│ DataKnot        │\n│ name     salary │\n├─────────────────┤\n│ GARRY M  260004 │\n=#Field access is also possible via Lookup or via the It shortcut.run(GM >> It.name)\n#=>\n│ name    │\n├─────────┤\n│ GARRY M │\n=#As seen in the output above, field names also act as display labels. It is possible to provide a name to any expression with the Label combinator. Labeling doesn\'t affect the actual output, only the field name given to the expression and its display.run(Lift(\"Hello World\") >> Label(:greeting))\n#=>\n│ greeting    │\n├─────────────┤\n│ Hello World │\n=#Alternatively, Julia\'s pair constructor (=>) and and a Symbol denoted by a colon (:) can be used to label an expression.Hello = :greeting => Lift(\"Hello World\")\nrun(Hello)\n#=>\n│ greeting    │\n├─────────────┤\n│ Hello World │\n=#When a record is created, it can use the label from which it originates. In this case, the :greeting label from the Hello is used to make the field label used within the Record. The record itself is also expressly labeled.run(:seasons => Record(Hello))\n#=>\n│ seasons     │\n│ greeting    │\n├─────────────┤\n│ Hello World │\n=#Records can be plural. Here is a table of obvious statistics.Stats = Record(:n¹=>It, :n²=>It.*It, :n³=>It.*It.*It)\nrun(Lift(1:3) >> Stats)\n#=>\n  │ DataKnot   │\n  │ n¹  n²  n³ │\n──┼────────────┤\n1 │  1   1   1 │\n2 │  2   4   8 │\n3 │  3   9  27 │\n=#Calculations could be run on record sets as follows:run(Lift(1:3) >> Stats >> (It.n² .+ It.n³))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │       12 │\n3 │       36 │\n=#Any values can be used within a Record, including other records and plural values.run(:work_schedule =>\n Record(:staff => Record(:name => \"Jim Rockford\",\n                         :phone => \"555-2368\"),\n        :workday => Lift([\"Su\", \"M\",\"Tu\", \"F\"])))\n#=>\n│ work_schedule                        │\n│ staff                   workday      │\n├──────────────────────────────────────┤\n│ Jim Rockford, 555-2368  Su; M; Tu; F │\n=#In DataKnots, records are used to generate tabular data. Using nested records, it is possible to represent complex, hierarchical data."
},

{
    "location": "thinking/#Working-With-Data-1",
    "page": "Thinking in Combinators",
    "title": "Working With Data",
    "category": "section",
    "text": "Arrays of named tuples can be wrapped with Lift in order to provide a series of tuples. Since DataKnots works fluidly with Julia, any sort of Julia object may be used. In this case, NamedTuple has special support so that it prints well.DATA = Lift([(name = \"GARRY M\", salary = 260004),\n              (name = \"ANTHONY R\", salary = 185364),\n              (name = \"DANA A\", salary = 170112)])\n\nrun(:staff => DATA)\n#=>\n  │ staff             │\n  │ name       salary │\n──┼───────────────────┤\n1 │ GARRY M    260004 │\n2 │ ANTHONY R  185364 │\n3 │ DANA A     170112 │\n=#Access to slots in a NamedTuple is also supported by Lookup.run(DATA >> Lookup(:name))\n#=>\n  │ name      │\n──┼───────────┤\n1 │ GARRY M   │\n2 │ ANTHONY R │\n3 │ DANA A    │\n=#Together with previous combinators, DataKnots could be used to create readable queries, such as \"who has the greatest salary\"?run(:highest_salary =>\n  Given(:MAX => Max(DATA >> It.salary),\n        DATA >> Filter(It.salary .== Lookup(:MAX))))\n#=>\n  │ highest_salary  │\n  │ name     salary │\n──┼─────────────────┤\n1 │ GARRY M  260004 │\n=#Records can even contain lists of subordinate records.DB =\n  run(:department =>\n    Record(:name => \"FIRE\", :staff => It.FIRE),\n    FIRE=[(name = \"JOSE S\", salary = 202728),\n          (name = \"CHARLES S\", salary = 197736)])\n#=>\n│ department                              │\n│ name  staff                             │\n├─────────────────────────────────────────┤\n│ FIRE  JOSE S, 202728; CHARLES S, 197736 │\n=#These subordinate records can then be summarized.run(:statistics =>\n  DB >> Record(:dept => It.name,\n               :count => Count(It.staff)))\n#=>\n│ statistics  │\n│ dept  count │\n├─────────────┤\n│ FIRE      2 │\n=#"
},

{
    "location": "thinking/#Quirks-1",
    "page": "Thinking in Combinators",
    "title": "Quirks",
    "category": "section",
    "text": "By quirks we mean unexpected consequences of embedding DataKnots in Julia. They are not necessarily bugs, nor could they be easily fixed.Using the broadcast syntax to lift combinators is a clever shortcut, but it doesn\'t always work out. If an argument to the broadcast isn\'t a Pipeline then a regular broadcast will happen. For example, rand.(1:3) is an array of arrays containing random numbers. Wrapping an argument in Lift will address this challenge. The following will generate 3 random numbers from 1 to 3.using Random: seed!, rand\nseed!(0)\nrun(Lift(1:3) >> rand.(Lift(7:9)))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        7 │\n2 │        9 │\n3 │        8 │\n=#"
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
    "text": "DataKnots are a Julia library for building and evaluating data processing pipelines. In this library, each Pipeline represents a data transformation; a pipeline\'s input and output is represented by a DataKnot. With the exception of a few overloaded Base functions, such as run and get, the bulk of this reference focuses on pipeline constructors.To exercise our reference examples, we import the package:using DataKnots"
},

{
    "location": "reference/#DataKnots-and-Running-Pipelines-1",
    "page": "Reference",
    "title": "DataKnots & Running Pipelines",
    "category": "section",
    "text": "A DataKnot is a column-oriented data store supporting hierarchical and self-referential data. A DataKnot is produced when a Pipeline is run."
},

{
    "location": "reference/#DataKnots.Cardinality-1",
    "page": "Reference",
    "title": "DataKnots.Cardinality",
    "category": "section",
    "text": "In DataKnots, the elementary unit is a collection of values, we call a data block. Besides the Julia datatype for a block\'s values, each data block also has a cardinality. The bookkeeping of cardinality is an essential aspect of pipeline evaluation.Cardinality is a constraint on the number of values in a block. A block is called mandatory if it must contain at least one value; optional otherwise. Similarly, a block is called singular if it must contain at most one value; plural otherwise.    REG::Cardinality = 0      # singular and mandatory\n    OPT::Cardinality = 1      # optional, but singular\n    PLU::Cardinality = 2      # plural, but mandatory\n    OPT_PLU::Cardinality = 3  # optional and pluralTo record the block cardinality constraint we use the OPT, PLU and REG flags of the type DataKnots.Cardinality. The OPT and PLU flags express relaxations of the mandatory and singular constraint, respectively. A REG block, which is both mandatory and singular, is called regular and it must contain exactly one value. Conversely, a block with both OPT|PLU flags has unconstrained cardinality and may contain any number of values.For any block with values of Julia type T, the block\'s cardinality has a correspondence to native Julia types: A regular block corresponds to a single Julia value of type T.  An unconstrained block corresponds to Vector{T}. An optional block corresponds to Union{Missing, T}. There is no correspondence for mandatory yet plural blocks; however, Vector{T} could be used with the convention that it always has at least one element."
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
    "text": "    DataKnot(elts::AbstractVector, card::Cardinality=OPT|PLU)In the general case, a DataKnot can be constructed from an AbstractVector to produce a DataKnot with a given cardinality. By default, the card of the collection is unconstrained.    DataKnot(elt, card::Cardinality=REG)As a convenience, a non-vector constructor is also defined, it marks the collection as being both singular and mandatory.    DataKnot(::Missing, card::Cardinality=OPT)There is an edge-case constructor for the creation of a singular but empty collection.    DataKnot()Finally, there is the unit knot, with a single value nothing; this is the default, implicit DataKnot used when run is evaluated without an input data source.DataKnot([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#=>\n  │ DataKnot  │\n──┼───────────┤\n1 │ GARRY M   │\n2 │ ANTHONY R │\n3 │ DANA A    │\n=#\n\nDataKnot(\"GARRY M\")\n#=>\n│ DataKnot │\n├──────────┤\n│ GARRY M  │\n=#\n\nDataKnot(missing)\n#=>\n│ DataKnot │\n=#\n\nDataKnot()\n#=>\n│ DataKnot │\n├──────────┤\n│          │\n=#Note that plural DataKnots are shown with an index, while singular knots are shown without. Further note that the missing knot doesn\'t have a value in its data block, unlike the unit knot which has a value of nothing. When showing a DataKnot, we follow Julia\'s command line behavior of rendering nothing as a blank since we wish to display short string values unquoted."
},

{
    "location": "reference/#show-1",
    "page": "Reference",
    "title": "show",
    "category": "section",
    "text": "    show(data::DataKnot)Besides displaying plural and singular knots differently, the show method has special treatment for Tuple and NamedTuple.DataKnot((name = \"GARRY M\", salary = 260004))\n#=>\n│ DataKnot        │\n│ name     salary │\n├─────────────────┤\n│ GARRY M  260004 │\n=#This permits a vector-of-tuples to be displayed as tabular data.DataKnot([(name = \"GARRY M\", salary = 260004),\n          (name = \"ANTHONY R\", salary = 185364),\n          (name = \"DANA A\", salary = 170112)])\n#=>\n  │ DataKnot          │\n  │ name       salary │\n──┼───────────────────┤\n1 │ GARRY M    260004 │\n2 │ ANTHONY R  185364 │\n3 │ DANA A     170112 │\n=#"
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
    "text": "    run(F::AbstractPipeline; params...)In its simplest form, run takes a pipeline with a set of named parameters and evaluates the pipeline with the unit knot as input. The parameters are each converted to a DataKnot before being made available within the pipeline\'s evaluation.    run(F::Pair{Symbol,<:AbstractPipeline}; params...)Using Julia\'s Pair syntax, this run method provides a convenient way to label an output DataKnot.    run(db::DataKnot, F; params...)The general case run permits easy use of a specific input data source. Since the 1st argument is a DataKnot and dispatch is unambiguous, the second argument to the method can be automatically converted to a Pipeline using Lift.Therefore, we can write the following examples.run(DataKnot(\"Hello World\"))\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#\n\nrun(:greeting => DataKnot(\"Hello World\"))\n#=>\n│ greeting    │\n├─────────────┤\n│ Hello World │\n=#\n\nrun(DataKnot(\"Hello World\"), It)\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#\n\nrun(DataKnot(), \"Hello World\")\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#Named arguments to run() become additional values that are accessible via It. Those arguments are converted into a DataKnot if they are not already.run(It.hello, hello=DataKnot(\"Hello World\"))\n#=>\n│ DataKnot    │\n├─────────────┤\n│ Hello World │\n=#\n\nrun(It.a .* (It.b .+ It.c), a=7, b=7, c=-1)\n#=>\n│ DataKnot │\n├──────────┤\n│       42 │\n=#Once a pipeline is run() the resulting DataKnot value can be retrieved via get().get(run(DataKnot(1), It .+ 1))\n#=>\n2\n=#Like get and show, the run function comes Julia\'s Base, and hence the methods defined here are only chosen if an argument matches the signature dispatch."
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
    "text": "Pages = [\n    \"vectors.md\",\n    \"queries.md\",\n    \"shapes.md\",\n    \"pipelines.md\",\n    \"lifting.md\",\n]\nDepth = 3"
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
    "location": "vectors/#Tabular-data-and-TupleVector-1",
    "page": "Column Store",
    "title": "Tabular data and TupleVector",
    "category": "section",
    "text": "Structured data can often be represented in a tabular form.  For example, information about city employees can be arranged in the following table.name position salary\nJEFFERY A SERGEANT 101442\nJAMES A FIRE ENGINEER-EMT 103350\nTERRY A POLICE OFFICER 93354Internally, a database engine stores tabular data using composite data structures such as tuples and vectors.A tuple is a fixed-size collection of heterogeneous values and can represent a table row.(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442)A vector is a variable-size collection of homogeneous values and can store a table column.[\"JEFFERY A\", \"JAMES A\", \"TERRY A\"]For a table as a whole, we have two options: either store it as a vector of tuples or store it as a tuple of vectors.  The former is called a row-oriented format, commonly used in programming and traditional database engines.[(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442),\n (name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350),\n (name = \"TERRY A\", position = \"POLICE OFFICER\", salary = 93354)]The other option, \"tuple of vectors\" layout, is called a column-oriented format.  It is often used by analytical databases as it is more suited for processing complex analytical queries.The module DataKnot implements data structures to support column-oriented data format.  In particular, tabular data is represented using TupleVector objects.TupleVector(:name => [\"JEFFERY A\", \"JAMES A\", \"TERRY A\"],\n            :position => [\"SERGEANT\", \"FIRE ENGINEER-EMT\", \"POLICE OFFICER\"],\n            :salary => [101442, 103350, 93354])Since creating TupleVector objects by hand is tedious and error prone, DataKnots provides a convenient macro @VectorTree, which lets you create column-oriented data using regular tuple and vector literals.@VectorTree (name = String, position = String, salary = Int) [\n    (name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442),\n    (name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350),\n    (name = \"TERRY A\", position = \"POLICE OFFICER\", salary = 93354),\n]"
},

{
    "location": "vectors/#Hierarchical-data-and-BlockVector-1",
    "page": "Column Store",
    "title": "Hierarchical data and BlockVector",
    "category": "section",
    "text": "Structured data could also be organized in hierarchical fashion.  For example, consider a collection of departments, where each department contains a list of associated employees.name employee\nPOLICE JEFFERY A; NANCY A\nFIRE JAMES A; DANIEL A\nOEMC LAKENYA A; DORIS AIn the row-oriented format, this data is represented using nested vectors.[(name = \"POLICE\", employee = [\"JEFFERY A\", \"NANCY A\"]),\n (name = \"FIRE\", employee = [\"JAMES A\", \"DANIEL A\"]),\n (name = \"OEMC\", employee = [\"LAKENYA A\", \"DORIS A\"])]To represent this data in column-oriented format, we need to serialize name and employee as column vectors.  The name column is straightforward.name_col = [\"POLICE\", \"FIRE\", \"OEMC\"]As for the employee column, naively, we could store it as a vector of vectors.[[\"JEFFERY A\", \"NANCY A\"], [\"JAMES A\", \"DANIEL A\"], [\"LAKENYA A\", \"DORIS A\"]]However, this representation loses the advantages of the column-oriented format since the data is no longer serialized with a fixed number of vectors. Instead, we should keep the column data in a tightly-packed vector of elements.employee_elts = [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"]This vector could be partitioned into separate blocks by the vector of offsets.employee_offs = [1, 3, 5, 7]Each pair of adjacent offsets corresponds a slice of the element vector.employee_elts[employee_offs[1]:employee_offs[2]-1]\n#-> [\"JEFFERY A\", \"NANCY A\"]\nemployee_elts[employee_offs[2]:employee_offs[3]-1]\n#-> [\"JAMES A\", \"DANIEL A\"]\nemployee_elts[employee_offs[3]:employee_offs[4]-1]\n#-> [\"LAKENYA A\", \"DORIS A\"]Together, elements and offsets faithfully reproduce the layout of the column. A pair of the offset and the element vectors is encapsulated with a BlockVector object, which represents a column-oriented encoding of a vector of variable-size blocks.employee_col = BlockVector(employee_offs, employee_elts)Now we can wrap the columns using TupleVector.TupleVector(:name => name_col, :employee => employee_col)@VectorTree provides a convenient way to create BlockVector objects from regular vector literals.@VectorTree (name = String, employee = [String]) [\n    (name = \"POLICE\", employee = [\"JEFFERY A\", \"NANCY A\"]),\n    (name = \"FIRE\", employee = [\"JAMES A\", \"DANIEL A\"]),\n    (name = \"OEMC\", employee = [\"LAKENYA A\", \"DORIS A\"]),\n]"
},

{
    "location": "vectors/#Optional-values-1",
    "page": "Column Store",
    "title": "Optional values",
    "category": "section",
    "text": "As we arrange data in a tabular form, we may need to leave some cells blank.For example, consider that a city employee could be compensated either with salary or with hourly pay.  To display the compensation data in a table, we add two columns: the annual salary and the hourly rate.  However, only one of the columns per each row is filled.name position salary rate\nJEFFERY A SERGEANT 101442 \nJAMES A FIRE ENGINEER-EMT 103350 \nTERRY A POLICE OFFICER 93354 \nLAKENYA A CROSSING GUARD  17.68As in the previous section, the cells in this table may contain a variable number of values.  Therefore, the table columns could be represented using BlockVector objects.  We start with packing the column data as element vectors.name_elts = [\"JEFFERY A\", \"JAMES A\", \"TERRY A\", \"LAKENYA A\"]\nposition_elts = [\"SERGEANT\", \"FIRE ENGINEER-EMT\", \"POLICE OFFICER\", \"CROSSING GUARD\"]\nsalary_elts = [101442, 103350, 93354]\nrate_elts = [17.68]Element vectors are partitioned into table cells by offset vectors.name_offs = [1, 2, 3, 4, 5]\nposition_offs = [1, 2, 3, 4, 5]\nsalary_offs = [1, 2, 3, 4, 4]\nrate_offs = [1, 1, 1, 1, 2]The pairs of element of offset vectors are wrapped as BlockVector objects.name_col = BlockVector(name_offs, name_elts, REG)\nposition_col = BlockVector(position_offs, position_elts, REG)\nsalary_col = BlockVector(salary_offs, salary_elts, OPT)\nrate_col = BlockVector(rate_offs, rate_elts, OPT)The last parameter of the BlockVector constructor is the cardinality constraint on the size of the blocks.  REG indicates that each block has exactly one element; OPT allows a block to be empty.  The constraint PLU is used to indicate that a block may contain more than one element.  No constraint means no restrictions on the block size.To represent the whole table, the columns should be wrapped with a TupleVector.TupleVector(\n    :name => name_col,\n    :position => position_col,\n    :salary => salary_col,\n    :rate => rate_col)As usual, we could create this data from tuple and vector literals.@VectorTree (name = [String, REG],\n             position = [String, REG],\n             salary = [Int, OPT],\n             rate = [Float64, OPT]) [\n    (name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing),\n    (name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing),\n    (name = \"TERRY A\", position = \"POLICE OFFICER\", salary = 93354, rate = missing),\n    (name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68),\n]"
},

{
    "location": "vectors/#Nested-data-1",
    "page": "Column Store",
    "title": "Nested data",
    "category": "section",
    "text": "When data does not fit a single table, it can often be presented in a top-down fashion.  For example, HR data can be seen as a collection of departments, each of which containing the associated employees.  Such data is serialized using nested data structures, which, in row-oriented format, may look as follows:[(name = \"POLICE\",\n  employee = [(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing),\n              (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016, rate = missing)]),\n (name = \"FIRE\",\n  employee = [(name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing),\n              (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484, rate = missing)]),\n (name = \"OEMC\",\n  employee = [(name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68),\n              (name = \"DORIS A\", position = \"CROSSING GUARD\", salary = missing, rate = 19.38)])]To store this data in a column-oriented format, we should use nested TupleVector and BlockVector instances.  We start with representing employee data.employee_elts =\n    TupleVector(\n        :name => BlockVector(:, [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"]),\n        :position => BlockVector(:, [\"SERGEANT\", \"POLICE OFFICER\", \"FIRE ENGINEER-EMT\", \"FIRE FIGHTER-EMT\", \"CROSSING GUARD\", \"CROSSING GUARD\"]),\n        :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484], OPT),\n        :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38], OPT))Then we partition employee data by departments:employee_col = BlockVector([1, 3, 5, 7], employee_elts, PLU)Adding a column of department names, we obtain HR data in a column-oriented format.TupleVector(\n    :name => BlockVector(:, [\"POLICE\", \"FIRE\", \"OEMC\"]),\n    :employee => employee_col)Another way to assemble this data in column-oriented format is to use @VectorTree.@VectorTree (name = [String, REG],\n             employee = [(name = [String, REG],\n                          position = [String, REG],\n                          salary = [Int, OPT],\n                          rate = [Float64, OPT]), PLU]) [\n    (name = \"POLICE\",\n     employee = [(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing),\n                 (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016, rate = missing)]),\n    (name = \"FIRE\",\n     employee = [(name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing),\n                 (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484, rate = missing)]),\n    (name = \"OEMC\",\n     employee = [(name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68),\n                 (name = \"DORIS A\", position = \"CROSSING GUARD\", salary = missing, rate = 19.38)])\n]"
},

{
    "location": "vectors/#DataKnots.Cardinality",
    "page": "Column Store",
    "title": "DataKnots.Cardinality",
    "category": "type",
    "text": "REG::Cardinality\nOPT::Cardinality\nPLU::Cardinality\nOPT|PLU::Cardinality\n\nCardinality constraints on a block of values.  REG stands for 1…1, OPT for 0…1, PLU for 1…∞, OPT|PLU for 0…∞.\n\n\n\n\n\n"
},

{
    "location": "vectors/#DataKnots.BlockVector",
    "page": "Column Store",
    "title": "DataKnots.BlockVector",
    "category": "type",
    "text": "BlockVector(offs::AbstractVector{Int}, elts::AbstractVector, card::Cardinality=OPT|PLU)\nBlockVector(:, elts::AbstractVector, card::Cardinality=REG)\n\nVector of vectors (blocks) stored as a vector of elements partitioned by a vector of offsets.\n\nelts is a continuous vector of block elements.\noffs is a vector of indexes that subdivide elts into separate blocks. Should be monotonous with offs[1] == 1 and offs[end] == length(elts)+1.\ncard is the expected cardinality of the blocks.\n\nThe second constructor creates a BlockVector of one-element blocks.\n\n\n\n\n\n"
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
    "text": "Enumerated type Cardinality is used to constrain the cardinality of a data block.  A block of data is called regular if it must contain exactly one element; optional if it may have no elements; and plural if it may have more than one element.  This gives us four different cardinality constraints.display(Cardinality)\n#=>\nEnum Cardinality:\nREG = 0x00\nOPT = 0x01\nPLU = 0x02\nOPT_PLU = 0x03\n=#Cardinality values support bitwise operations.print(REG|OPT|PLU)      #-> OPT_PLU\nprint(PLU&~PLU)         #-> REGWe can use predicates isregular(), isoptional(), isplural() to check cardinality values.isregular(REG)          #-> true\nisregular(OPT)          #-> false\nisregular(PLU)          #-> false\nisoptional(OPT)         #-> true\nisoptional(PLU)         #-> false\nisplural(PLU)           #-> true\nisplural(OPT)           #-> false"
},

{
    "location": "vectors/#BlockVector-1",
    "page": "Column Store",
    "title": "BlockVector",
    "category": "section",
    "text": "BlockVector is a vector of homogeneous vectors (blocks) stored as a vector of elements partitioned into individual blocks by a vector of offsets.bv = BlockVector([1, 3, 5, 7], [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"], PLU)\n#-> @VectorTree [String, PLU] [[\"JEFFERY A\", \"NANCY A\"], [\"JAMES A\", \"DANIEL A\"], [\"LAKENYA A\", \"DORIS A\"]]\n\ndisplay(bv)\n#=>\nBlockVector of 3 × [String, PLU]:\n [\"JEFFERY A\", \"NANCY A\"]\n [\"JAMES A\", \"DANIEL A\"]\n [\"LAKENYA A\", \"DORIS A\"]\n=#If each block contains exactly one element, we could use : in place of the offset vector.BlockVector(:, [\"POLICE\", \"FIRE\", \"OEMC\"])\n#-> @VectorTree [String, REG] [\"POLICE\", \"FIRE\", \"OEMC\"]The BlockVector constructor verifies that the offset vector is well-formed.BlockVector(Base.OneTo(0), [])\n#-> ERROR: partition must be non-empty\n\nBlockVector(Int[], [])\n#-> ERROR: partition must be non-empty\n\nBlockVector([0], [])\n#-> ERROR: partition must start with 1\n\nBlockVector([1,2,2,1], [\"HEALTH\"])\n#-> ERROR: partition must be monotone\n\nBlockVector(Base.OneTo(4), [\"HEALTH\", \"FINANCE\"])\n#-> ERROR: partition must enclose the elements\n\nBlockVector([1,2,3,6], [\"HEALTH\", \"FINANCE\"])\n#-> ERROR: partition must enclose the elementsThe constructor also validates the cardinality constraint.BlockVector([1, 3, 5, 7], [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"], OPT)\n#-> ERROR: singular blocks must have at most one element\n\nBlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38], REG)\n#-> ERROR: mandatory blocks must have at least one elementWe can access individual components of the vector.offsets(bv)\n#-> [1, 3, 5, 7]\n\nelements(bv)\n#-> [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"]\n\nprint(cardinality(bv))\n#-> PLUWhen indexed by a vector of indexes, an instance of BlockVector is returned.elts = [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nreg_bv = BlockVector(:, elts, REG)\n#-> @VectorTree [String, REG] [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nopt_bv = BlockVector([1, 2, 3, 3, 4, 4, 5, 6, 6, 6, 7], elts, OPT)\n#-> @VectorTree [String, OPT] [\"POLICE\", \"FIRE\", missing, \"HEALTH\", missing, \"AVIATION\", \"WATER MGMNT\", missing, missing, \"FINANCE\"]\n\nplu_bv = BlockVector([1, 1, 1, 2, 2, 4, 4, 6, 7], elts, OPT|PLU)\n#-> @VectorTree [String] [[], [], [\"POLICE\"], [], [\"FIRE\", \"HEALTH\"], [], [\"AVIATION\", \"WATER MGMNT\"], [\"FINANCE\"]]\n\nreg_bv[[1,3,5,3]]\n#-> @VectorTree [String, REG] [\"POLICE\", \"HEALTH\", \"WATER MGMNT\", \"HEALTH\"]\n\nplu_bv[[1,3,5,3]]\n#-> @VectorTree [String] [[], [\"POLICE\"], [\"FIRE\", \"HEALTH\"], [\"POLICE\"]]\n\nreg_bv[Base.OneTo(4)]\n#-> @VectorTree [String, REG] [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\"]\n\nreg_bv[Base.OneTo(6)]\n#-> @VectorTree [String, REG] [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nplu_bv[Base.OneTo(6)]\n#-> @VectorTree [String] [[], [], [\"POLICE\"], [], [\"FIRE\", \"HEALTH\"], []]\n\nopt_bv[Base.OneTo(10)]\n#-> @VectorTree [String, OPT] [\"POLICE\", \"FIRE\", missing, \"HEALTH\", missing, \"AVIATION\", \"WATER MGMNT\", missing, missing, \"FINANCE\"]"
},

{
    "location": "vectors/#@VectorTree-1",
    "page": "Column Store",
    "title": "@VectorTree",
    "category": "section",
    "text": "We can use @VectorTree macro to convert vector literals to the columnar form assembled with TupleVector and BlockVector objects.TupleVector is created from a matrix or a vector of (named) tuples.@VectorTree (name = String, salary = Int) [\n    \"GARRY M\"   260004\n    \"ANTHONY R\" 185364\n    \"DANA A\"    170112\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\n@VectorTree (name = String, salary = Int) [\n    (\"GARRY M\", 260004),\n    (\"ANTHONY R\", 185364),\n    (\"DANA A\", 170112),\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\n@VectorTree (name = String, salary = Int) [\n    (name = \"GARRY M\", salary = 260004),\n    (name = \"ANTHONY R\", salary = 185364),\n    (name = \"DANA A\", salary = 170112),\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]Column labels are optional.@VectorTree (String, Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n#-> @VectorTree (String, Int) [(\"GARRY M\", 260004) … ]BlockVector is constructed from a vector of vector literals.  A one-element block could be represented by the element itself; an empty block by missing.@VectorTree [String] [\n    \"HEALTH\",\n    [\"FINANCE\", \"HUMAN RESOURCES\"],\n    missing,\n    [\"POLICE\", \"FIRE\"],\n]\n#-> @VectorTree [String] [[\"HEALTH\"], [\"FINANCE\", \"HUMAN RESOURCES\"], [], [\"POLICE\", \"FIRE\"]]Ill-formed @VectorTree contructors are rejected.@VectorTree (String, Int) (\"GARRY M\", 260004)\n#=>\nERROR: LoadError: expected a vector literal; got :((\"GARRY M\", 260004))\n⋮\n=#\n\n@VectorTree (String, Int) [(position = \"SUPERINTENDENT OF POLICE\", salary = 260004)]\n#=>\nERROR: LoadError: expected no label; got :(position = \"SUPERINTENDENT OF POLICE\")\n⋮\n=#\n\n@VectorTree (name = String, salary = Int) [(position = \"SUPERINTENDENT OF POLICE\", salary = 260004)]\n#=>\nERROR: LoadError: expected label :name; got :(position = \"SUPERINTENDENT OF POLICE\")\n⋮\n=#\n\n@VectorTree (name = String, salary = Int) [(\"GARRY M\", \"SUPERINTENDENT OF POLICE\", 260004)]\n#=>\nERROR: LoadError: expected 2 column(s); got :((\"GARRY M\", \"SUPERINTENDENT OF POLICE\", 260004))\n⋮\n=#\n\n@VectorTree (name = String, salary = Int) [\"GARRY M\"]\n#=>\nERROR: LoadError: expected a tuple or a row literal; got \"GARRY M\"\n⋮\n=#Using @VectorTree, we can easily construct hierarchical data.hier_data = @VectorTree (name = [String, REG], employee = [(name = [String, REG], salary = [Int, OPT])]) [\n    \"POLICE\"    [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n    \"FIRE\"      [\"JOSE S\" 202728; \"CHARLES S\" 197736]\n]\ndisplay(hier_data)\n#=>\nTupleVector of 2 × (name = [String, REG], employee = [(name = [String, REG], salary = [Int, OPT])]):\n (name = \"POLICE\", employee = [(name = \"GARRY M\", salary = 260004) … ])\n (name = \"FIRE\", employee = [(name = \"JOSE S\", salary = 202728) … ])\n=#"
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
    "text": "This section describes the Query interface of vectorized data transformations.  We will use the following definitions:using DataKnots:\n    @VectorTree,\n    OPT,\n    PLU,\n    REG,\n    Query,\n    Runtime,\n    adapt_missing,\n    adapt_tuple,\n    adapt_vector,\n    block_any,\n    block_filler,\n    block_length,\n    block_lift,\n    chain_of,\n    column,\n    distribute,\n    distribute_all,\n    filler,\n    flatten,\n    lift,\n    null_filler,\n    pass,\n    record_lift,\n    sieve,\n    slice,\n    tuple_lift,\n    tuple_of,\n    with_column,\n    with_elements,\n    wrap"
},

{
    "location": "queries/#Lifting-and-fillers-1",
    "page": "Query Algebra",
    "title": "Lifting and fillers",
    "category": "section",
    "text": "DataKnots stores structured data in a column-oriented format, serialized using specialized composite vector types.  Consequently, operations on data must also be adapted to the column-oriented format.In DataKnots, operations on column-oriented data are called queries.  A query is a vectorized transformation: it takes a vector of input values and produces a vector of the same size containing output values.Any unary scalar function could be vectorized, which gives us a simple method for creating new queries.  Consider, for example, function titlecase(), which transforms the input string by capitalizing the first letter of each word and converting every other character to lowercase.titlecase(\"JEFFERY A\")      #-> \"Jeffery A\"This function can be converted to a query, or lifted, using the lift query constructor.q = lift(titlecase)\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [\"Jeffery A\", \"James A\", \"Terry A\"]A scalar function with N arguments could be lifted by tuple_lift to make a query that transforms a TupleVector with N columns.  For example, a binary predicate > gives rise to a query tuple_lift(>) that transforms a TupleVector with two columns into a Boolean vector.q = tuple_lift(>)\nq(@VectorTree (Int, Int) [260004 200000; 185364 200000; 170112 200000])\n#-> Bool[1, 0, 0]In a similar manner, a function with a vector argument can be lifted by block_lift to make a query that expects a BlockVector input.  For example, function length(), which returns the length of a vector, could be converted to a query block_lift(length) that transforms a block vector to an integer vector containing block lengths.q = block_lift(length)\nq(@VectorTree [String] [[\"JEFFERY A\", \"NANCY A\"], [\"JAMES A\"]])\n#-> [2, 1]Not just functions, but also regular values could give rise to queries.  The filler constructor makes a query from any scalar value.  This query maps any input vector to a vector filled with the given scalar.q = filler(200000)\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [200000, 200000, 200000]Similarly, block_filler makes a query from any vector value.  This query produces a BlockVector filled with the given vector.q = block_filler([\"POLICE\", \"FIRE\"])\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [String] [[\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"]]A variant of block_filler called null_filler makes a query that produces a BlockVector filled with empty blocks.q = null_filler()\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [Union{}, OPT] [missing, missing, missing]"
},

{
    "location": "queries/#Chaining-queries-1",
    "page": "Query Algebra",
    "title": "Chaining queries",
    "category": "section",
    "text": "Given a series of queries, the chain_of constructor creates their composition query, which transforms the input vector by sequentially applying the given queries.q = chain_of(lift(split), lift(first), lift(titlecase))\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [\"Jeffery\", \"James\", \"Terry\"]The degenerate composition of an empty sequence of queries has its own name, pass(). It passes its input to the output unchanged.chain_of()\n#-> pass()\n\nq = pass()\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [\"JEFFERY A\", \"JAMES A\", \"TERRY A\"]In general, query constructors that take one or more queries as arguments are called query combinators.  Combinators are used to assemble elementary queries into complex query expressions."
},

{
    "location": "queries/#Working-with-composite-vectors-1",
    "page": "Query Algebra",
    "title": "Working with composite vectors",
    "category": "section",
    "text": "In DataKnots, composite data is represented as a tree of vectors with regular Vector objects at the leaves and composite vectors such as TupleVector and BlockVector at the intermediate nodes.  We demonstrated how to create and transform regular vectors using filler and lift.  Now let us show how to do the same with composite vectors.TupleVector is a vector of tuples composed of a sequence of column vectors. Any collection of vectors could be used as columns as long as they all have the same length.  One way to obtain N columns for a TupleVector is to apply N queries to the same input vector.  This is precisely the query action of the tuple_of combinator.q = tuple_of(:first => chain_of(lift(split), lift(first), lift(titlecase)),\n             :last => lift(last))\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> @VectorTree (first = String, last = Char) [(first = \"Jeffery\", last = \'A\') … ]In the opposite direction, the column constructor makes a query that extracts the specified column from the input TupleVector.q = column(:salary)\nq(@VectorTree (name=String, salary=Int) [(\"JEFFERY A\", 101442), (\"JAMES A\", 103350), (\"TERRY A\", 93354)])\n#-> [101442, 103350, 93354]BlockVector is a vector of vectors serialized as a partitioned vector of elements.  Any input vector could be transformed to a BlockVector by the query wrap(), which wraps the vector elements into one-element blocks.q = wrap()\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [String, REG] [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]Dual to wrap() is the query flatten(), which transforms a nested BlockVector by flattening its nested blocks.q = flatten()\nq(@VectorTree [[String]] [[[\"GARRY M\"], [\"ANTHONY R\", \"DANA A\"]], [[], [\"JOSE S\"], [\"CHARLES S\"]]])\n#-> @VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]]The distribute constructor makes a query that rearranges a TupleVector with a BlockVector column.  Specifically, it takes each tuple, which should contain a block value, and transforms it to a block of tuples by distributing the block value over the tuple.q = distribute(:employee)\nq(@VectorTree (department = String, employee = [String]) [\n    \"POLICE\"    [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]\n    \"FIRE\"      [\"JOSE S\", \"CHARLES S\"]]) |> display\n#=>\nBlockVector of 2 × [(department = String, employee = String)]:\n [(department = \"POLICE\", employee = \"GARRY M\"), (department = \"POLICE\", employee = \"ANTHONY R\"), (department = \"POLICE\", employee = \"DANA A\")]\n [(department = \"FIRE\", employee = \"JOSE S\"), (department = \"FIRE\", employee = \"CHARLES S\")]\n=#Often we need to transform only a part of a composite vector, leaving the rest of the structure intact.  This can be achieved using with_column and with_elements combinators.  Specifically, with_column transforms a specific column of a TupleVector while with_elements transforms the vector of elements of a BlockVector.q = with_column(:employee, with_elements(lift(titlecase)))\nq(@VectorTree (department = String, employee = [String]) [\n    \"POLICE\"    [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]\n    \"FIRE\"      [\"JOSE S\", \"CHARLES S\"]]) |> display\n#=>\nTupleVector of 2 × (department = String, employee = [String]):\n (department = \"POLICE\", employee = [\"Garry M\", \"Anthony R\", \"Dana A\"])\n (department = \"FIRE\", employee = [\"Jose S\", \"Charles S\"])\n=#"
},

{
    "location": "queries/#Specialized-queries-1",
    "page": "Query Algebra",
    "title": "Specialized queries",
    "category": "section",
    "text": "Not every data transformation can be implemented with lifting.  DataKnots provide query constructors for some common transformation tasks.For example, data filtering is implemented with the query sieve().  As input, it expects a TupleVector of pairs containing a value and a Bool flag. sieve() transforms the input to a BlockVector containing 0- and 1-element blocks.  When the flag is false, it is mapped to an empty block, otherwise, it is mapped to a one-element block containing the data value.q = sieve()\nq(@VectorTree (String, Bool) [(\"JEFFERY A\", true), (\"JAMES A\", true), (\"TERRY A\", false)])\n#->  @VectorTree [String, OPT] [\"JEFFERY A\", \"JAMES A\", missing]If DataKnots does not provide a specific transformation, it is easy to create a new one.  For example, let us create a query constructor double which makes a query that doubles the elements of the input vector.We need to provide two definitions: to create a Query object and to perform the query action on the given input vector.double() = Query(double)\ndouble(::Runtime, input::AbstractVector{<:Number}) = input .* 2\n\nq = double()\nq([260004, 185364, 170112])\n#-> [520008, 370728, 340224]It is also easy to create new query combinators.  Let us create a combinator twice, which applies the given query to the input two times.twice(q) = Query(twice, q)\ntwice(rt::Runtime, input, q) = q(rt, q(rt, input))\n\nq = twice(double())\nq([260004, 185364, 170112])\n#-> [1040016, 741456, 680448]"
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
    "location": "queries/#DataKnots.adapt_missing-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.adapt_missing",
    "category": "method",
    "text": "adapt_missing() :: Query\n\nThis query transforms a vector that contains missing elements to a block vector with missing elements replaced by empty blocks.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.adapt_tuple-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.adapt_tuple",
    "category": "method",
    "text": "adapt_tuple() :: Query\n\nThis query transforms a vector of tuples to a tuple vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.adapt_vector-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.adapt_vector",
    "category": "method",
    "text": "adapt_vector() :: Query\n\nThis query transforms a vector with vector elements to a block vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.block_any-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.block_any",
    "category": "method",
    "text": "block_any() :: Query\n\nThis query applies any to a block vector with Bool elements.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.block_filler",
    "page": "Query Algebra",
    "title": "DataKnots.block_filler",
    "category": "function",
    "text": "block_filler(block::AbstractVector, card::Cardinality) :: Query\n\nThis query produces a block vector filled with the given block.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.block_length-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.block_length",
    "category": "method",
    "text": "block_length() :: Query\n\nThis query converts a block vector to a vector of block lengths.\n\n\n\n\n\n"
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
    "location": "queries/#DataKnots.designate",
    "page": "Query Algebra",
    "title": "DataKnots.designate",
    "category": "function",
    "text": "designate(::Query, ::Signature) :: Query\ndesignate(::Query, ::InputShape, ::OutputShape) :: Query\nq::Query |> designate(::Signature) :: Query\nq::Query |> designate(::InputShape, ::OutputShape) :: Query\n\nSets the query signature.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.distribute-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.distribute",
    "category": "method",
    "text": "distribute(lbl::Union{Int,Symbol}) :: Query\n\nThis query transforms a tuple vector with a column of blocks to a block vector with tuple elements.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.distribute_all-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.distribute_all",
    "category": "method",
    "text": "distribute_all() :: Query\n\nThis query transforms a tuple vector with block columns to a block vector with tuple elements.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.filler-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.filler",
    "category": "method",
    "text": "filler(val) :: Query\n\nThis query produces a vector filled with the given value.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.flatten-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.flatten",
    "category": "method",
    "text": "flatten() :: Query\n\nThis query flattens a nested block vector.\n\n\n\n\n\n"
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
    "location": "queries/#DataKnots.slice",
    "page": "Query Algebra",
    "title": "DataKnots.slice",
    "category": "function",
    "text": "slice(N::Int, rev::Bool=false) :: Query\n\nThis query transforms a block vector by keeping the first N elements of each block.  If rev is true, the query drops the first N elements of each block.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.slice",
    "page": "Query Algebra",
    "title": "DataKnots.slice",
    "category": "function",
    "text": "slice(rev::Bool=false) :: Query\n\nThis query takes a pair vector of blocks and integers, and returns the first column with blocks restricted by the second column.\n\n\n\n\n\n"
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
    "location": "queries/#DataKnots.with_column-Tuple{Union{Int64, Symbol},Any}",
    "page": "Query Algebra",
    "title": "DataKnots.with_column",
    "category": "method",
    "text": "with_column(lbl::Union{Int,Symbol}, q::Query) :: Query\n\nThis query transforms a tuple vector by applying q to the specified column.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.with_elements-Tuple{Any}",
    "page": "Query Algebra",
    "title": "DataKnots.with_elements",
    "category": "method",
    "text": "with_elements(q::Query) :: Query\n\nThis query transforms a block vector by applying q to its vector of elements.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.wrap-Tuple{}",
    "page": "Query Algebra",
    "title": "DataKnots.wrap",
    "category": "method",
    "text": "wrap() :: Query\n\nThis query produces a block vector with one-element blocks wrapping the values of the input vector.\n\n\n\n\n\n"
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
    "location": "queries/#Lifting-1",
    "page": "Query Algebra",
    "title": "Lifting",
    "category": "section",
    "text": "The lift constructor makes a query by vectorizing a unary function.q = lift(titlecase)\n#-> lift(titlecase)\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [\"Garry M\", \"Anthony R\", \"Dana A\"]The block_lift constructor makes a query on block vectors by vectorizing a unary vector function.q = block_lift(length)\n#-> block_lift(length)\n\nq(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]])\n#-> [3, 2]Some vector functions may expect a non-empty vector as an argument.  In this case, we should provide the value to replace empty blocks.q = block_lift(maximum, missing)\n#-> block_lift(maximum, missing)\n\nq(@VectorTree [Int] [[260004, 185364, 170112], [], [202728, 197736]])\n#-> Union{Missing, Int}[260004, missing, 202728]The tuple_lift constructor makes a query on tuple vectors by vectorizing a function of several arguments.q = tuple_lift(>)\n#-> tuple_lift(>)\n\nq(@VectorTree (Int, Int) [260004 200000; 185364 200000; 170112 200000])\n#-> Bool[1, 0, 0]The record_lift constructor is used when the input is in the record layout (a tuple vector with block vector columns); record_lift(f) is a shortcut for chain_of(distribute_all(),with_elements(tuple_lift(f))).q = record_lift(>)\n#-> record_lift(>)\n\nq(@VectorTree ([Int], [Int]) [[260004, 185364, 170112] 200000; missing 200000; [202728, 197736] [200000, 200000]])\n#-> @VectorTree [Bool] [[1, 0, 0], [], [1, 1, 0, 0]]With record_lift, the cardinality of the output is the upper bound of the column block cardinalities.q(@VectorTree ([Int, PLU], [Int, REG]) [([260004, 185364, 170112], 200000)])\n#-> @VectorTree [Bool, PLU] [[1, 0, 0]]"
},

{
    "location": "queries/#Fillers-1",
    "page": "Query Algebra",
    "title": "Fillers",
    "category": "section",
    "text": "The query filler(val) ignores its input and produces a vector filled with val.q = filler(200000)\n#-> filler(200000)\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [200000, 200000, 200000]The query block_filler(blk, card) produces a block vector filled with the given block.q = block_filler([\"POLICE\", \"FIRE\"], PLU)\n#-> block_filler([\"POLICE\", \"FIRE\"], PLU)\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [String, PLU] [[\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"]]The query null_filler() produces a block vector with empty blocks.q = null_filler()\n#-> null_filler()\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [Union{}, OPT] [missing, missing, missing]"
},

{
    "location": "queries/#Adapting-row-oriented-data-1",
    "page": "Query Algebra",
    "title": "Adapting row-oriented data",
    "category": "section",
    "text": "The query adapt_missing() transforms a vector containing missing values to a block vector with missing replaced by an empty block and other values wrapped in 1-element block.q = adapt_missing()\n#-> adapt_missing()\n\nq([260004, 185364, 170112, missing, 202728, 197736])\n#-> @VectorTree [Int, OPT] [260004, 185364, 170112, missing, 202728, 197736]The query adapt_vector() transforms a vector of vectors to a block vector.q = adapt_vector()\n#-> adapt_vector()\n\nq([[260004, 185364, 170112], Int[], [202728, 197736]])\n#-> @VectorTree [Int] [[260004, 185364, 170112], [], [202728, 197736]]The query adapt_tuple() transforms a vector of tuples to a tuple vector.q = adapt_tuple()\n#-> adapt_tuple()\n\nq([(\"GARRY M\", 260004), (\"ANTHONY R\", 185364), (\"DANA A\", 170112)]) |> display\n#=>\nTupleVector of 3 × (String, Int):\n (\"GARRY M\", 260004)\n (\"ANTHONY R\", 185364)\n (\"DANA A\", 170112)\n=#Vectors of named tuples are also supported.q([(name=\"GARRY M\", salary=260004), (name=\"ANTHONY R\", salary=185364), (name=\"DANA A\", salary=170112)]) |> display\n#=>\nTupleVector of 3 × (name = String, salary = Int):\n (name = \"GARRY M\", salary = 260004)\n (name = \"ANTHONY R\", salary = 185364)\n (name = \"DANA A\", salary = 170112)\n=#"
},

{
    "location": "queries/#Composition-1",
    "page": "Query Algebra",
    "title": "Composition",
    "category": "section",
    "text": "The chain_of combinator composes a sequence of queries.q = chain_of(lift(split), lift(first), lift(titlecase))\n#-> chain_of(lift(split), lift(first), lift(titlecase))\n\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [\"Jeffery\", \"James\", \"Terry\"]The empty chain chain_of() has an alias pass().q = pass()\n#-> pass()\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]"
},

{
    "location": "queries/#Tuple-vectors-1",
    "page": "Query Algebra",
    "title": "Tuple vectors",
    "category": "section",
    "text": "The query tuple_of(q₁, q₂ … qₙ) produces a tuple vector, whose columns are generated by applying q₁, q₂ … qₙ to the input vector.q = tuple_of(:title => lift(titlecase), :last => lift(last))\n#-> tuple_of(:title => lift(titlecase), :last => lift(last))\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"]) |> display\n#=>\nTupleVector of 3 × (title = String, last = Char):\n (title = \"Garry M\", last = \'M\')\n (title = \"Anthony R\", last = \'R\')\n (title = \"Dana A\", last = \'A\')\n=#The query column(lbl) extracts the specified column from a tuple vector.  The column constructor accepts either the column position or the column label.q = column(1)\n#-> column(1)\n\nq(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112])\n#-> [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]\n\nq = column(:salary)\n#-> column(:salary)\n\nq(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112])\n#-> [260004, 185364, 170112]The with_column combinator lets us apply the given query to a selected column of a tuple vector.q = with_column(:name, lift(titlecase))\n#-> with_column(:name, lift(titlecase))\n\nq(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]) |> display\n#=>\nTupleVector of 3 × (name = String, salary = Int):\n (name = \"Garry M\", salary = 260004)\n (name = \"Anthony R\", salary = 185364)\n (name = \"Dana A\", salary = 170112)\n=#"
},

{
    "location": "queries/#Block-vectors-1",
    "page": "Query Algebra",
    "title": "Block vectors",
    "category": "section",
    "text": "The query wrap() wraps the elements of the input vector to one-element blocks.q = wrap()\n#-> wrap()\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [String, REG] [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]The query flatten() flattens a nested block vector.q = flatten()\n#-> flatten()\n\nq(@VectorTree [[String]] [[[\"GARRY M\"], [\"ANTHONY R\", \"DANA A\"]], [missing, [\"JOSE S\"], [\"CHARLES S\"]]])\n#-> @VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]]The with_elements combinator lets us apply the given query to transform the elements of a block vector.q = with_elements(lift(titlecase))\n#-> with_elements(lift(titlecase))\n\nq(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]])\n#-> @VectorTree [String] [[\"Garry M\", \"Anthony R\", \"Dana A\"], [\"Jose S\", \"Charles S\"]]The query distribute(lbl) transforms a tuple vector with a block column to a block vector of tuples by distributing the block elements over the tuple.q = distribute(1)\n#-> distribute(1)\n\nq(@VectorTree ([Int], [Int]) [\n    [260004, 185364, 170112]    200000\n    missing                     200000\n    [202728, 197736]            [200000, 200000]]\n) |> display\n#=>\nBlockVector of 3 × [(Int, [Int])]:\n [(260004, [200000]), (185364, [200000]), (170112, [200000])]\n []\n [(202728, [200000, 200000]), (197736, [200000, 200000])]\n=#The query distribute_all() takes a tuple vector with block columns and distribute all of the block columns.q = distribute_all()\n#-> distribute_all()\n\nq(@VectorTree ([Int], [Int]) [\n    [260004, 185364, 170112]    200000\n    missing                     200000\n    [202728, 197736]            [200000, 200000]]\n) |> display\n#=>\nBlockVector of 3 × [(Int, Int)]:\n [(260004, 200000), (185364, 200000), (170112, 200000)]\n []\n [(202728, 200000), (202728, 200000), (197736, 200000), (197736, 200000)]\n=#This query is equivalent to chain_of(distribute(1),with_elements(distribute(2),flatten()).The query block_length() calculates the lengths of blocks in a block vector.q = block_length()\n#-> block_length()\n\nq(@VectorTree [String] [missing, \"GARRY M\", [\"ANTHONY R\", \"DANA A\"]])\n#-> [0, 1, 2]The query block_any() checks whether the blocks in a Bool block vector have any true values.q = block_any()\n#-> block_any()\n\nq(@VectorTree [Bool] [missing, true, false, [true, false], [false, false], [false, true]])\n#-> Bool[0, 1, 0, 1, 0, 1]"
},

{
    "location": "queries/#Filtering-1",
    "page": "Query Algebra",
    "title": "Filtering",
    "category": "section",
    "text": "The query sieve() filters a vector of pairs by the second column.q = sieve()\n#-> sieve()\n\nq(@VectorTree (Int, Bool) [260004 true; 185364 false; 170112 false])\n#-> @VectorTree [Int, OPT] [260004, missing, missing]"
},

{
    "location": "queries/#Slicing-1",
    "page": "Query Algebra",
    "title": "Slicing",
    "category": "section",
    "text": "The query slice(N) transforms a block vector by keeping the first N elements of each block.q = slice(2)\n#-> slice(2, false)\n\nq(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"], missing])\n#-> @VectorTree [String] [[\"GARRY M\", \"ANTHONY R\"], [\"JOSE S\", \"CHARLES S\"], []]When N is negative, slice(N) drops the last N elements of each block.q = slice(-1)\n\nq(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"], missing])\n#-> @VectorTree [String] [[\"GARRY M\", \"ANTHONY R\"], [\"JOSE S\"], []]The query slice(N, true) drops the first N elements (or keeps the last N elements if N is negative).q = slice(2, true)\n\nq(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"], missing])\n#-> @VectorTree [String] [[\"DANA A\"], [], []]\n\nq = slice(-1, true)\n\nq(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"], missing])\n#-> @VectorTree [String] [[\"DANA A\"], [\"CHARLES S\"], []]A variant of this query slice() expects a tuple vector with two columns: the first column containing the blocks and the second column with the number of elements to keep.q = slice()\n#-> slice(false)\n\nq(@VectorTree ([String], Int) [([\"GARRY M\", \"ANTHONY R\", \"DANA A\"], 1), ([\"JOSE S\", \"CHARLES S\"], -1), (missing, 0)])\n#-> @VectorTree [String] [[\"GARRY M\"], [\"JOSE S\"], []]"
},

{
    "location": "shapes/#",
    "page": "Monadic Signature",
    "title": "Monadic Signature",
    "category": "page",
    "text": ""
},

{
    "location": "shapes/#Monadic-Signature-1",
    "page": "Monadic Signature",
    "title": "Monadic Signature",
    "category": "section",
    "text": ""
},

{
    "location": "shapes/#Overview-1",
    "page": "Monadic Signature",
    "title": "Overview",
    "category": "section",
    "text": "To describe data shapes and monadic signatures, we need the following definitions.using DataKnots:\n    @VectorTree,\n    OPT,\n    PLU,\n    REG,\n    AnyShape,\n    Cardinality,\n    InputMode,\n    InputShape,\n    NativeShape,\n    NoneShape,\n    OutputMode,\n    OutputShape,\n    RecordShape,\n    Signature,\n    TupleVector,\n    adapt_vector,\n    bound,\n    cardinality,\n    chain_of,\n    column,\n    compose,\n    decorate,\n    designate,\n    domain,\n    fits,\n    ibound,\n    idomain,\n    imode,\n    ishape,\n    isoptional,\n    isplural,\n    isregular,\n    lift,\n    mode,\n    shape,\n    shapeof,\n    signature,\n    slots,\n    tuple_lift,\n    tuple_of,\n    wrap"
},

{
    "location": "shapes/#Data-shapes-1",
    "page": "Monadic Signature",
    "title": "Data shapes",
    "category": "section",
    "text": "In DataKnots, the structure of composite data is represented using shape objects.For example, consider a collection of departments with associated employees.depts =\n    @VectorTree (name = [String, REG],\n                 employee = [(name = [String, REG],\n                              position = [String, REG],\n                              salary = [Int, OPT],\n                              rate = [Float64, OPT]), PLU]) [\n        (name = \"POLICE\",\n         employee = [(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing),\n                     (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016, rate = missing)]),\n        (name = \"FIRE\",\n         employee = [(name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing),\n                     (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484, rate = missing)]),\n        (name = \"OEMC\",\n         employee = [(name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68),\n                     (name = \"DORIS A\", position = \"CROSSING GUARD\", salary = missing, rate = 19.38)])\n    ]In this collection, each department record has two fields: name and employee.  Each employee record has four fields: name, position, salary, and rate.  The employee field is plural; salary and rate are optional.Physically, this collection is stored as a tree of interleaving TupleVector and BlockVector objects with regular Vector objects as the tree leaves. The structure of this collection can be described by a congruent tree composed of RecordShape, OutputShape, and NativeShape objects.NativeShape corresponds to regular Julia Vector objects and specifies the type of the vector elements.NativeShape(String)\n#-> NativeShape(String)OutputShape specifies the label, the domain and the cardinality of a record field.  The data of a record field is stored in a BlockVector object. Accordingly, the field domain is the shape of the BlockVector elements and the field cardinality is the cardinality of the BlockVector.  When the domain is represented by NativeShape, we could instead specify the respective Julia type.  The REG cardinality is assumed by default.OutputShape(:position, NativeShape(String), REG)\n#-> OutputShape(:position, String)RecordShape describes the structure of a record.  It contains a list of field shapes and corresponds to a TupleVector with BlockVector columns.emp_shp =\n    RecordShape(OutputShape(:name, String),\n                OutputShape(:position, String),\n                OutputShape(:salary, Int, OPT),\n                OutputShape(:rate, Float64, OPT))Using nested shape objects, we can describe the structure of a nested collection.dept_shp =\n    RecordShape(OutputShape(:name, String),\n                OutputShape(:employee, emp_shp, PLU))"
},

{
    "location": "shapes/#Traversing-nested-data-1",
    "page": "Monadic Signature",
    "title": "Traversing nested data",
    "category": "section",
    "text": "A record field can be seen as a specialized query.  For example, the field employee corresponds to a query which maps a collection of departments to associated employees.dept_employee = column(:employee)\n\ndept_employee(depts) |> display\n#=>\nBlockVector of 3 × [(name = [String, REG], position = [String, REG], salary = [Int, OPT], rate = [Float64, OPT]), PLU]:\n [(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing), (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016, rate = missing)]\n [(name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing), (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484, rate = missing)]\n [(name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68), (name = \"DORIS A\", position = \"CROSSING GUARD\", salary = missing, rate = 19.38)]\n=#To indicate the role of this query, we assign it a monadic signature, which describes the shapes of the query input and output.dept_employee =\n    dept_employee |> designate(InputShape(dept_shp), OutputShape(emp_shp, PLU))\n\nsignature(dept_employee)\n#=>\n(name = [String, REG],\n employee = [(name = [String, REG],\n              position = [String, REG],\n              salary = [Int, OPT],\n              rate = [Float64, OPT]),\n             PLU]) ->\n    [(name = [String, REG],\n      position = [String, REG],\n      salary = [Int, OPT],\n      rate = [Float64, OPT]),\n     PLU]\n=#A path could be assembled by composing two adjacent field queries.  For example, consider a query that corresponds to the rate field.emp_rate =\n    column(:rate) |> designate(InputShape(emp_shp), OutputShape(Float64, OPT))The output domain of the dept_employee coincides with the input domain of emp_rate.domain(dept_employee)\n#=>\nRecordShape(OutputShape(:name, String),\n            OutputShape(:position, String),\n            OutputShape(:salary, Int, OPT),\n            OutputShape(:rate, Float64, OPT))\n=#\n\nidomain(emp_rate)\n#=>\nRecordShape(OutputShape(:name, String),\n            OutputShape(:position, String),\n            OutputShape(:salary, Int, OPT),\n            OutputShape(:rate, Float64, OPT))\n=#This means the queries are composable.  Note that we cannot simply chain the queries using chain_of(dept_employee, emp_rate) because the output of dept_employee is not compatible with emp_rate.  Indeed, dept_employee produces a BlockVector while emp_rate expects a TupleVector.  So instead we use the monadic composition combinator.dept_employee_rate = compose(dept_employee, emp_rate)\n#-> chain_of(column(:employee), with_elements(column(:rate)), flatten())\n\ndept_employee_rate(depts)\n#-> @VectorTree [Float64] [[], [], [17.68, 19.38]]This composition represents a path through the fields employee and rate and has a signature assigned to it.signature(dept_employee_rate)\n#=>\n(name = [String, REG],\n employee = [(name = [String, REG],\n              position = [String, REG],\n              salary = [Int, OPT],\n              rate = [Float64, OPT]),\n             PLU]) ->\n    [Float64]\n=#"
},

{
    "location": "shapes/#Monadic-queries-1",
    "page": "Monadic Signature",
    "title": "Monadic queries",
    "category": "section",
    "text": "Among all queries, DataKnots distinguishes a special class of path-like queries, which are called monadic.  We indicate that a query is monadic by assigning it its monadic signature.The query signature describes the shapes of its input and output using InputShape and OutputShape objects.OutputShape specifies the label, the domain and the cardinality of the query output.  A monadic query always produces a BlockVector object.  Accordingly, the output domain and cardinality specify the BlockVector elements and its cardinality.InputShape specifies the label, the domain and the named slots of the query input.  The input of a monadic query is a TupleVector with two columns: the first column is the regular input data described by the input domain, while the second column is a record containing slot data.  When the query has no slots, the outer TupleVector is omitted.For example, consider a monadic query that wraps the round function with precision specified in a named slot.round_digits(x, d) = round(x, digits=d)\n\nround_it =\n    chain_of(\n        tuple_of(chain_of(column(1), wrap()),\n                 chain_of(column(2), column(:P))),\n        tuple_lift(round_digits),\n        wrap())\n\nround_it(@VectorTree (Float64, (P = [Int, REG],)) [(17.68, (P = 1,)), (19.38, (P = 1,))])\n#-> @VectorTree [Float64, REG] [17.7, 19.4]To indicate that the query is monadic, we assign it its monadic signature.round_it =\n    round_it |> designate(InputShape(Float64, [:P => OutputShape(Float64)]),\n                          OutputShape(Float64))When two monadic queries have compatible intermediate domains, they could be composed.domain(dept_employee_rate)\n#-> NativeShape(Float64)\n\nidomain(round_it)\n#-> NativeShape(Float64)\n\ndept_employee_round_rate = compose(dept_employee_rate, round_it)The composition is again a monadic query.  Its signature is constructed from the signatures of the components.  In particular, the cardinality of the composition is the upper bound of the component cardinalities while its input slots are formed from the slots of the components.print(cardinality(dept_employee_round_rate))\n#-> OPT_PLU\n\nslots(dept_employee_round_rate)\n#-> Pair{Symbol,DataKnots.OutputShape}[:P=>OutputShape(Float64)]\n\nslot_data = @VectorTree (P = [Int, REG],) [(P = 1,), (P = 1,), (P = 1,)]\n\ninput = TupleVector(:depts => depts, :slot_data => slot_data)\n\ndept_employee_round_rate(input)\n#-> @VectorTree [Float64] [[], [], [17.7, 19.4]]"
},

{
    "location": "shapes/#DataKnots.AbstractShape",
    "page": "Monadic Signature",
    "title": "DataKnots.AbstractShape",
    "category": "type",
    "text": "AbstractShape\n\nRepresents the shape of column-oriented data.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.AnyShape",
    "page": "Monadic Signature",
    "title": "DataKnots.AnyShape",
    "category": "type",
    "text": "AnyShape()\n\nNo constraints on the data.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.Decoration",
    "page": "Monadic Signature",
    "title": "DataKnots.Decoration",
    "category": "type",
    "text": "Decoration(label::Union{Nothing,Symbol}=nothing)\n\nAnnotations on the query input and output.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.InputMode",
    "page": "Monadic Signature",
    "title": "DataKnots.InputMode",
    "category": "type",
    "text": "InputMode(slots::Union{Nothing,Vector{Pair{Symbol,OutputShape}}},\n          framed::Bool)\n\nComonadic constraints on the query input.\n\nParameter slots is a list of named query parameters and their shapes.\n\nParameter framed indicates if the query input is partitioned into frames.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.InputShape",
    "page": "Monadic Signature",
    "title": "DataKnots.InputShape",
    "category": "type",
    "text": "InputShape(::Decoration, ::AbstractShape, ::InputMode)\n\nThe shape of the input of a monadic query.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.NoneShape",
    "page": "Monadic Signature",
    "title": "DataKnots.NoneShape",
    "category": "type",
    "text": "NoneShape()\n\nInconsistent constraints on the data.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.OutputMode",
    "page": "Monadic Signature",
    "title": "DataKnots.OutputMode",
    "category": "type",
    "text": "OutputMode(card::Cardinality=REG)\n\nMonadic constraints on the query output.\n\nParameter card is the cardinality of the query output.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.OutputShape",
    "page": "Monadic Signature",
    "title": "DataKnots.OutputShape",
    "category": "type",
    "text": "OutputShape(::Decoration, ::AbstractShape, ::OutputMode)\n\nThe shape of the output of a monadic query.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.RecordShape",
    "page": "Monadic Signature",
    "title": "DataKnots.RecordShape",
    "category": "type",
    "text": "RecordShape(flds::OutputShape...)\n\nShape of a record with the given fields.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.Signature",
    "page": "Monadic Signature",
    "title": "DataKnots.Signature",
    "category": "type",
    "text": "Signature(::InputShape, ::OutputShape)\n\nSignature of a monadic query.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.bound",
    "page": "Monadic Signature",
    "title": "DataKnots.bound",
    "category": "function",
    "text": "bound(::Type{T}) :: T\n\nThe most specific constraint of the type T.\n\nbound(xs::T...) :: T\nbound(xs::Vector{T}) :: T\n\nThe tight upper bound of the given sequence of constraints.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.fits",
    "page": "Monadic Signature",
    "title": "DataKnots.fits",
    "category": "function",
    "text": "fits(x::T, y::T) :: Bool\n\nChecks if constraint x implies constraint y.\n\n\n\n\n\n"
},

{
    "location": "shapes/#DataKnots.ibound",
    "page": "Monadic Signature",
    "title": "DataKnots.ibound",
    "category": "function",
    "text": "ibound(::Type{T}) :: T\n\nThe least specific constraint of the type T.\n\nibound(xs::T...) :: T\nibound(xs::Vector{T}) :: T\n\nThe tight lower bound of the given sequence of constraints.\n\n\n\n\n\n"
},

{
    "location": "shapes/#API-Reference-1",
    "page": "Monadic Signature",
    "title": "API Reference",
    "category": "section",
    "text": "Modules = [DataKnots]\nPages = [\"shapes.jl\"]"
},

{
    "location": "shapes/#Test-Suite-1",
    "page": "Monadic Signature",
    "title": "Test Suite",
    "category": "section",
    "text": ""
},

{
    "location": "shapes/#Cardinality-1",
    "page": "Monadic Signature",
    "title": "Cardinality",
    "category": "section",
    "text": "Cardinality constraints are partially ordered.  In particular, there are the greatest and the least cardinalities.print(bound(Cardinality))   #-> REG\nprint(ibound(Cardinality))  #-> OPT_PLUFor a collection of cardinality constraints, we can determine their least upper bound and their greatest lower bound.print(bound(OPT, PLU))      #-> OPT_PLU\nprint(ibound(PLU, OPT))     #-> REGFor two Cardinality constraints, we can determine whether one is more strict than the other.fits(OPT, PLU)              #-> false\nfits(REG, OPT|PLU)          #-> true"
},

{
    "location": "shapes/#Data-shapes-2",
    "page": "Monadic Signature",
    "title": "Data shapes",
    "category": "section",
    "text": "The structure of composite data is specified with shape objects.NativeShape indicates a regular Julia value of a specific type.str_shp = NativeShape(String)\n#-> NativeShape(String)\n\neltype(str_shp)\n#-> StringTwo special shape types indicate values with no constraints and with inconsistent constraints.any_shp = AnyShape()\n#-> AnyShape()\n\nnone_shp = NoneShape()\n#-> NoneShape()InputShape and OutputShape describe the structure of the input and the output of a monadic query.To describe the query input, we specify the shape of the input elements, the shapes of the parameters, and whether or not the input is framed.i_shp = InputShape(UInt, InputMode([:D => OutputShape(String)], true))\n#-> InputShape(UInt, InputMode([:D => OutputShape(String)], true))\n\ndomain(i_shp)\n#-> NativeShape(UInt)\n\nmode(i_shp)\n#-> InputMode([:D => OutputShape(String)], true)To describe the query output, we specify the shape and the cardinality of the output elements.o_shp = OutputShape(Int, OPT|PLU)\n#-> OutputShape(Int, OPT | PLU)\n\nprint(cardinality(o_shp))\n#-> OPT_PLU\n\ndomain(o_shp)\n#-> NativeShape(Int)\n\nmode(o_shp)\n#-> OutputMode(OPT | PLU)It is possible to decorate InputShape and OutputShape objects to specify additional attributes.  Currently, we can only specify the label.o_shp |> decorate(label=:output)\n#-> OutputShape(:output, Int, OPT | PLU)RecordShape` specifies the shape of a record value where each record field has a certain shape and cardinality.dept_shp = RecordShape(OutputShape(:name, String),\n                       OutputShape(:employee, UInt, OPT|PLU))\n#=>\nRecordShape(OutputShape(:name, String),\n            OutputShape(:employee, UInt, OPT | PLU))\n=#\n\nemp_shp = RecordShape(OutputShape(:name, String),\n                      OutputShape(:department, UInt),\n                      OutputShape(:position, String),\n                      OutputShape(:salary, Int),\n                      OutputShape(:manager, UInt, OPT),\n                      OutputShape(:subordinate, UInt, OPT|PLU))\n#=>\nRecordShape(OutputShape(:name, String),\n            OutputShape(:department, UInt),\n            OutputShape(:position, String),\n            OutputShape(:salary, Int),\n            OutputShape(:manager, UInt, OPT),\n            OutputShape(:subordinate, UInt, OPT | PLU))\n=#Using the combination of different shapes we can describe the structure of any data source.db_shp = RecordShape(OutputShape(:department, dept_shp, OPT|PLU),\n                     OutputShape(:employee, emp_shp, OPT|PLU))\n#=>\nRecordShape(OutputShape(:department,\n                        RecordShape(OutputShape(:name, String),\n                                    OutputShape(:employee, UInt, OPT | PLU)),\n                        OPT | PLU),\n            OutputShape(:employee,\n                        RecordShape(\n                            OutputShape(:name, String),\n                            OutputShape(:department, UInt),\n                            OutputShape(:position, String),\n                            OutputShape(:salary, Int),\n                            OutputShape(:manager, UInt, OPT),\n                            OutputShape(:subordinate, UInt, OPT | PLU)),\n                        OPT | PLU))\n=#"
},

{
    "location": "shapes/#Shape-ordering-1",
    "page": "Monadic Signature",
    "title": "Shape ordering",
    "category": "section",
    "text": "The same data can satisfy many different shape constraints.  For example, a vector BlockVector(:, [Chicago]) can be said to have, among others, the shape OutputShape(String), the shape OutputShape(AbstractString, OPT|PLU) or the shape AnyShape().  We can tell, for any two shapes, if one of them is more specific than the other.fits(NativeShape(Int), NativeShape(Number))     #-> true\nfits(NativeShape(Int), NativeShape(String))     #-> false\n\nfits(InputShape(Int,\n                InputMode([:X => OutputShape(Int),\n                           :Y => OutputShape(String)],\n                          true)),\n     InputShape(Number,\n                InputMode([:X => OutputShape(Int, OPT)])))\n#-> true\nfits(InputShape(Int),\n     InputShape(Number, InputMode(true)))\n#-> false\nfits(InputShape(Int,\n                InputMode([:X => OutputShape(Int, OPT)])),\n     InputShape(Number,\n                InputMode([:X => OutputShape(Int)])))\n#-> false\n\nfits(OutputShape(Int),\n     OutputShape(Number, OPT))                  #-> true\nfits(OutputShape(Int, PLU),\n     OutputShape(Number, OPT))                  #-> false\nfits(OutputShape(Int),\n     OutputShape(String, OPT))                  #-> false\n\nfits(RecordShape(OutputShape(Int),\n                 OutputShape(String, OPT)),\n     RecordShape(OutputShape(Number),\n                 OutputShape(String, OPT|PLU)))     #-> true\nfits(RecordShape(OutputShape(Int, OPT),\n                 OutputShape(String)),\n     RecordShape(OutputShape(Number),\n                 OutputShape(String, OPT|PLU)))     #-> false\nfits(RecordShape(OutputShape(Int)),\n     RecordShape(OutputShape(Number),\n                 OutputShape(String, OPT|PLU)))     #-> falseShapes of different kinds are typically not compatible with each other.  The exceptions are AnyShape and NullShape.fits(NativeShape(Int), OutputShape(Int))    #-> false\nfits(NativeShape(Int), AnyShape())          #-> true\nfits(NoneShape(), NativeShape(Int))         #-> trueShape decorations are treated as additional shape constraints.fits(OutputShape(:name, String),\n     OutputShape(:name, String))                            #-> true\nfits(OutputShape(String),\n     OutputShape(:position, String))                        #-> false\nfits(OutputShape(:position, String),\n     OutputShape(String))                                   #-> true\nfits(OutputShape(:position, String),\n     OutputShape(:name, String))                            #-> falseFor any given number of shapes, we can find their upper bound, the shape that is more general than each of them.  We can also find their lower bound.bound(NativeShape(Int), NativeShape(Number))\n#-> NativeShape(Number)\nibound(NativeShape(Int), NativeShape(Number))\n#-> NativeShape(Int)\n\nbound(InputShape(Int, InputMode([:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true)),\n      InputShape(Number, InputMode([:X => OutputShape(Int)])))\n#=>\nInputShape(Number, InputMode([:X => OutputShape(Int, OPT)]))\n=#\nibound(InputShape(Int, InputMode([:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true)),\n       InputShape(Number, InputMode([:X => OutputShape(Int)])))\n#=>\nInputShape(Int,\n           InputMode([:X => OutputShape(Int), :Y => OutputShape(String)],\n                     true))\n=#\n\nbound(OutputShape(String, OPT), OutputShape(String, PLU))\n#-> OutputShape(String, OPT | PLU)\nibound(OutputShape(String, OPT), OutputShape(String, PLU))\n#-> OutputShape(String)\n\nbound(RecordShape(OutputShape(Int, PLU),\n                  OutputShape(String, OPT)),\n      RecordShape(OutputShape(Number),\n                  OutputShape(UInt, OPT|PLU)))\n#=>\nRecordShape(OutputShape(Number, PLU), OutputShape(AnyShape(), OPT | PLU))\n=#\nibound(RecordShape(OutputShape(Int, PLU),\n                   OutputShape(String, OPT)),\n       RecordShape(OutputShape(Number),\n                   OutputShape(UInt, OPT|PLU)))\n#=>\nRecordShape(OutputShape(Int), OutputShape(NoneShape(), OPT))\n=#For decorated shapes, incompatible labels are replaced with an empty label.bound(OutputShape(:name, String), OutputShape(:name, String))\n#-> OutputShape(:name, String)\n\nibound(OutputShape(:name, String), OutputShape(:name, String))\n#-> OutputShape(:name, String)\n\nbound(OutputShape(:position, String), OutputShape(:salary, Number))\n#-> OutputShape(AnyShape())\n\nibound(OutputShape(:position, String), OutputShape(:salary, Number))\n#-> OutputShape(Symbol(\"\"), NoneShape())\n\nbound(OutputShape(Int), OutputShape(:salary, Number))\n#-> OutputShape(Number)\n\nibound(OutputShape(Int), OutputShape(:salary, Number))\n#-> OutputShape(:salary, Int)"
},

{
    "location": "shapes/#Monadic-signature-1",
    "page": "Monadic Signature",
    "title": "Monadic signature",
    "category": "section",
    "text": "The signature of a monadic query is a pair of an InputShape object and an OutputShape object.sig = Signature(InputShape(UInt),\n                OutputShape(RecordShape(OutputShape(:name, String),\n                                        OutputShape(:employee, UInt, OPT|PLU))))\n#-> UInt -> [(name = [String, REG], employee = [UInt]), REG]Different components of the signature can be easily extracted.shape(sig)\n#=>\nOutputShape(RecordShape(OutputShape(:name, String),\n                        OutputShape(:employee, UInt, OPT | PLU)))\n=#\n\nishape(sig)\n#-> InputShape(UInt)\n\ndomain(sig)\n#=>\nRecordShape(OutputShape(:name, String),\n            OutputShape(:employee, UInt, OPT | PLU))\n=#\n\nmode(sig)\n#-> OutputMode()\n\nidomain(sig)\n#-> NativeShape(UInt)\n\nimode(sig)\n#-> InputMode()"
},

{
    "location": "shapes/#Determining-the-vector-shape-1",
    "page": "Monadic Signature",
    "title": "Determining the vector shape",
    "category": "section",
    "text": "Function shapeof() determines the shape of a given vector.shapeof([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> NativeShape(String)In particular, it detects the record layout.shapeof(\n    @VectorTree ([String, REG],\n                 [(name = [String, REG],\n                   position = [String, REG],\n                   salary = [Int, OPT],\n                   rate = [Float64, OPT]), PLU]) [])\n#=>\nRecordShape(OutputShape(String),\n            OutputShape(RecordShape(OutputShape(:name, String),\n                                    OutputShape(:position, String),\n                                    OutputShape(:salary, Int, OPT),\n                                    OutputShape(:rate, Float64, OPT)),\n                        PLU))\n=#TupleVector and BlockVector objects that are not in the record layout are treated as regular vectors.shapeof(@VectorTree (String, [String]) [])\n#-> NativeShape(Tuple{String,Array{String,1}})\n\nshapeof(@VectorTree (name = String, employee = [String]) [])\n#-> NativeShape(NamedTuple{(:name, :employee),Tuple{String,Array{String,1}}})"
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
    "text": "using DataKnots\n\nusing DataKnots:\n    @VectorTree\n\ndb = DataKnot(\n    @VectorTree (name = [String], employee = [(name = [String], salary = [Int])]) [\n        \"POLICE\"    [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n        \"FIRE\"      [\"JOSE S\" 202728; \"CHARLES S\" 197736]\n    ])\n#=>\n  │ DataKnot                                                   │\n  │ name    employee                                           │\n──┼────────────────────────────────────────────────────────────┤\n1 │ POLICE  GARRY M, 260004; ANTHONY R, 185364; DANA A, 170112 │\n2 │ FIRE    JOSE S, 202728; CHARLES S, 197736                  │\n=#\n\nrun(db >> It.employee.name)\n#=>\n  │ name      │\n──┼───────────┤\n1 │ GARRY M   │\n2 │ ANTHONY R │\n3 │ DANA A    │\n4 │ JOSE S    │\n5 │ CHARLES S │\n=#\n\nTitleCase = Lift(titlecase, (It,))\n\nrun(db >> It.employee.name >> TitleCase)\n#=>\n  │ DataKnot  │\n──┼───────────┤\n1 │ Garry M   │\n2 │ Anthony R │\n3 │ Dana A    │\n4 │ Jose S    │\n5 │ Charles S │\n=#\n\nSplit = Lift(split, (It,))\n\nrun(db >> It.employee.name >> Split)\n#=>\n   │ DataKnot │\n───┼──────────┤\n 1 │ GARRY    │\n 2 │ M        │\n 3 │ ANTHONY  │\n 4 │ R        │\n 5 │ DANA     │\n 6 │ A        │\n 7 │ JOSE     │\n 8 │ S        │\n 9 │ CHARLES  │\n10 │ S        │\n=#\n\nrun(db >> (\n    :employee =>\n      It.employee >>\n        Record(:name =>\n          It.name >> Split)))\n#=>\n  │ employee   │\n  │ name       │\n──┼────────────┤\n1 │ GARRY; M   │\n2 │ ANTHONY; R │\n3 │ DANA; A    │\n4 │ JOSE; S    │\n5 │ CHARLES; S │\n=#\n\nRepeat(V,N) = Lift(fill, (V, N))\nrun(db >> Record(It.name, Repeat(\"Go!\", 3)))\n#=>\n  │ DataKnot              │\n  │ name    #2            │\n──┼───────────────────────┤\n1 │ POLICE  Go!; Go!; Go! │\n2 │ FIRE    Go!; Go!; Go! │\n=#"
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
    "text": "In this section, we describe the design and implementation of the pipeline algebra.  We will need the following definitions.using DataKnots:\n    @VectorTree,\n    OPT,\n    REG,\n    Count,\n    DataKnot,\n    Drop,\n    Environment,\n    Filter,\n    Given,\n    It,\n    Lift,\n    Lookup,\n    Max,\n    Min,\n    Record,\n    Take,\n    apply,\n    elements,\n    optimize,\n    stubAs a running example, we will use the following dataset of city departments with associated employees.  This dataset is serialized as a nested structure with a singleton root record, which holds all department records, each of which holds associated employee records.elts =\n    @VectorTree (department = [(name     = [String, REG],\n                                employee = [(name     = [String, REG],\n                                             position = [String, REG],\n                                             salary   = [Int, OPT],\n                                             rate     = [Float64, OPT])])],) [\n        (department = [\n            (name     = \"POLICE\",\n             employee = [\"JEFFERY A\"  \"SERGEANT\"           101442   missing\n                         \"NANCY A\"    \"POLICE OFFICER\"     80016    missing]),\n            (name     = \"FIRE\",\n             employee = [\"JAMES A\"    \"FIRE ENGINEER-EMT\"  103350   missing\n                         \"DANIEL A\"   \"FIRE FIGHTER-EMT\"   95484    missing]),\n            (name     = \"OEMC\",\n             employee = [\"LAKENYA A\"  \"CROSSING GUARD\"     missing  17.68\n                         \"DORIS A\"    \"CROSSING GUARD\"     missing  19.38])],\n        )\n    ]\n\ndb = DataKnot(elts, REG)\n#=>\n│ DataKnot                                                                     …\n│ department                                                                   …\n├──────────────────────────────────────────────────────────────────────────────…\n│ POLICE, JEFFERY A, SERGEANT, 101442, ; NANCY A, POLICE OFFICER, 80016, ; FIRE…\n=#"
},

{
    "location": "pipelines/#Assembling-pipelines-1",
    "page": "Pipeline Algebra",
    "title": "Assembling pipelines",
    "category": "section",
    "text": "In DataKnots, we query data by assembling and running query pipelines. Pipeline are assembled algebraically: they either come a set of atomic primitive pipelines, or are built from other pipelines using pipeline combinators.For example, consider the pipeline:Employees = Lookup(:department) >> Lookup(:employee)\n#-> Lookup(:department) >> Lookup(:employee)This pipeline traverses the dataset through fields department and employee. It is assembled from two primitive pipelines Lookup(:department) and Lookup(:employee) connected using the pipeline composition combinator >>.Since attribute traversal is very common, DataKnots provides a shorthand notation.Employees = It.department.employee\n#-> It.department.employeeTo get the data from a pipeline, we use function run().  This function takes the input dataset and a pipeline object, and produces the output dataset.run(db, Employees)\n#=>\n  │ employee                                    │\n  │ name       position           salary  rate  │\n──┼─────────────────────────────────────────────┤\n1 │ JEFFERY A  SERGEANT           101442        │\n2 │ NANCY A    POLICE OFFICER      80016        │\n3 │ JAMES A    FIRE ENGINEER-EMT  103350        │\n4 │ DANIEL A   FIRE FIGHTER-EMT    95484        │\n5 │ LAKENYA A  CROSSING GUARD             17.68 │\n6 │ DORIS A    CROSSING GUARD             19.38 │\n=#Regular Julia values and functions could be used to create pipeline components. Specifically, any Julia value could be converted to a pipeline primitive, and any Julia function could be converted to a pipeline combinator.For example, let us find find employees whose salary is greater than $100k. For this purpose, we need to construct a predicate pipeline that compares the salary field with a specific number.If we were constructing an ordinary predicate function, we would write:emp -> emp.salary > 100000An equivalent pipeline is constructed as follows:SalaryOver100K = Lift(>, (Lookup(:salary), Lift(100000)))\n#-> Lift(>, (Lookup(:salary), Lift(100000)))This pipeline expression is assembled from two primitive components: Lookup(:salary) and Lift(100000), which serve as parameters of the Lift(>) combinator.  Here, Lift is used twice.  Lift applied to a regular Julia value converts it to a constant pipeline primitive while Lift applied to a function lifts it to a pipeline combinator.As a shorthand notation for lifting functions and operators, DataKnots supports broadcasting syntax:SalaryOver100K = It.salary .> 100000\n#-> It.salary .> 100000To test this pipeline, we can append it to the Employees pipeline using the composition combinator.run(db, Employees >> SalaryOver100K)\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │     true │\n2 │    false │\n3 │     true │\n4 │    false │\n=#However, this only gives us a list of bare Boolean values disconnected from the respective employees.  To improve this output, we can use the Record combinator.run(db, Employees >> Record(It.name,\n                            It.salary,\n                            :salary_over_100k => SalaryOver100K))\n#=>\n  │ employee                            │\n  │ name       salary  salary_over_100k │\n──┼─────────────────────────────────────┤\n1 │ JEFFERY A  101442              true │\n2 │ NANCY A     80016             false │\n3 │ JAMES A    103350              true │\n4 │ DANIEL A    95484             false │\n5 │ LAKENYA A                           │\n6 │ DORIS A                             │\n=#To actually filter the data using this predicate pipeline, we need to use the Filter combinator.EmployeesWithSalaryOver100K = Employees >> Filter(SalaryOver100K)\n#-> It.department.employee >> Filter(It.salary .> 100000)\n\nrun(db, EmployeesWithSalaryOver100K)\n#=>\n  │ employee                                   │\n  │ name       position           salary  rate │\n──┼────────────────────────────────────────────┤\n1 │ JEFFERY A  SERGEANT           101442       │\n2 │ JAMES A    FIRE ENGINEER-EMT  103350       │\n=#DataKnots provides a number of useful pipeline constructors.  For example, to find the number of items produced by a pipeline, we can use the Count combinator.run(db, Count(EmployeesWithSalaryOver100K))\n#=>\n│ DataKnot │\n├──────────┤\n│        2 │\n=#In general, pipeline algebra forms an XPath-like domain-specific language.  It is designed to let the user construct pipelines incrementally, with each step being individually crafted and tested.  It also encourages the user to create reusable pipeline components and remix them in creative ways."
},

{
    "location": "pipelines/#Principal-queries-1",
    "page": "Pipeline Algebra",
    "title": "Principal queries",
    "category": "section",
    "text": "In DataKnots, running a pipeline is a two-phase process.  First, the pipeline generates its principal query.  Second, the principal query transforms the input data to the output data.Let us elaborate on the role of queries and pipelines.  In DataKnots, queries are used to transform data, and pipelines are used to transform monadic queries.  That is, just as a query can be applied to some dataset to produce a new dataset, a pipeline can be applied to a monadic query to produce a new monadic query.Among all queries produced by a pipeline, we distinguish its principal query, which is obtained when the pipeline is applied to a trivial monadic query.To demonstrate how the principal query is constructed, let us use the pipeline EmployeesWithSalaryOver100K from the previous section.  Recall that it could be represented as follows:Lookup(:department) >> Lookup(:employee) >> Filter(Lookup(:salary) .> 100000)\n#-> Lookup(:department) >> Lookup(:employee) >> Filter(Lookup(:salary) .> 100000)The pipeline P is constructed using a composition combinator.  A composition transforms a query by sequentially applying its components.  Therefore, to find the principal query of P, we need to start with a trivial query and sequentially tranfrorm it with the pipelines Lookup(:department), Lookup(:employee) and Filter(SalaryOver100K).The trivial query is a monadic identity on the input dataset.q0 = stub(db)\n#-> wrap()To apply a pipeline to a query, we need to create application environment. Then we use the function apply().env = Environment()\n\nq1 = apply(Lookup(:department), env, q0)\n#-> chain_of(wrap(), with_elements(column(:department)), flatten())Here, the query q1 is a monadic composition of q0 with column(:department).  Since q0 is a monadic identity, this query is actually equivalent to column(:department).In general, Lookup(name) maps a query to its monadic composition with column(name).  For example, when we apply Lookup(:employee) to q1, we get compose(q1, column(:employee)).q2 = apply(Lookup(:employee), env, q1)\n#=>\nchain_of(chain_of(wrap(), with_elements(column(:department)), flatten()),\n         with_elements(column(:employee)),\n         flatten())\n=#We conclude assembling the principal query by applying Filter(SalaryOver100K) to q2.  Filter acts on the input query as follows. First, it finds the principal query of the condition pipeline.  For that, we need a trivial monadic query on the output of q2.qc0 = stub(q2)\n#-> wrap()Passing qc0 through SalaryOver100K gives us a query that generates the result of the condition.qc1 = apply(SalaryOver100K, env, qc0)\n#=>\nchain_of(wrap(),\n         with_elements(chain_of(tuple_of(\n                                    chain_of(wrap(),\n                                             with_elements(column(:salary)),\n                                             flatten()),\n                                    chain_of(wrap(),\n                                             with_elements(\n                                                 block_filler([100000], REG)),\n                                             flatten())),\n                                tuple_lift(>),\n                                adapt_missing())),\n         flatten())\n=#Filter(SalaryOver100K) then combines the outputs of q2 and qc1 using sieve().q3 = apply(Filter(SalaryOver100K), env, q2)\n#=>\nchain_of(\n    chain_of(chain_of(wrap(), with_elements(column(:department)), flatten()),\n             with_elements(column(:employee)),\n             flatten()),\n    with_elements(\n        chain_of(\n            tuple_of(\n                pass(),\n                chain_of(\n                    chain_of(\n                        wrap(),\n                        with_elements(\n                            chain_of(\n                                tuple_of(\n                                    chain_of(wrap(),\n                                             with_elements(column(:salary)),\n                                             flatten()),\n                                    chain_of(wrap(),\n                                             with_elements(\n                                                 block_filler([100000], REG)),\n                                             flatten())),\n                                tuple_lift(>),\n                                adapt_missing())),\n                        flatten()),\n                    block_any())),\n            sieve())),\n    flatten())\n=#The resulting query could be compacted by simplifying the query expression.q = optimize(q3)\n#=>\nchain_of(column(:department),\n         with_elements(column(:employee)),\n         flatten(),\n         with_elements(\n             chain_of(tuple_of(pass(),\n                               chain_of(tuple_of(column(:salary),\n                                                 block_filler([100000], REG)),\n                                        tuple_lift(>),\n                                        adapt_missing(),\n                                        block_any())),\n                      sieve())),\n         flatten())\n=#Applying the principal query to the input data gives us the output of the pipeline.input = elements(db)\noutput = q(input)\n\ndisplay(elements(output))\n#=>\nTupleVector of 2 × (name = [String, REG], position = [String, REG], salary = [Int, OPT], rate = [Float64, OPT]):\n (name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing)\n (name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing)\n=#"
},

{
    "location": "pipelines/#DataKnots.Count-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Count",
    "category": "method",
    "text": "Count(X)\nX >> Count\n\nCounts the number of elements produced by X.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Drop-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Drop",
    "category": "method",
    "text": "Drop(N)\n\nDrops the first N elements.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Each-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Each",
    "category": "method",
    "text": "Each(X)\n\nMakes X process its input elementwise.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Filter-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Filter",
    "category": "method",
    "text": "Filter(X)\n\nFilters the input by condition.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Given-Tuple{Any,Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Given",
    "category": "method",
    "text": "Given(P, X)\n\nSpecifies the parameter.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Label-Tuple{Symbol}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Label",
    "category": "method",
    "text": "Label(lbl::Symbol)\n\nAssigns a label.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Lift-Tuple{Any,Tuple}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Lift",
    "category": "method",
    "text": "Lift(f, Xs)\n\nConverts a Julia function to a pipeline combinator.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Lift-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Lift",
    "category": "method",
    "text": "Lift(val)\n\nConverts a Julia value to a pipeline primitive.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Lookup-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Lookup",
    "category": "method",
    "text": "Lookup(name)\n\nFinds an attribute or a parameter.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Max-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Max",
    "category": "method",
    "text": "Max(X)\nX >> Max\n\nFinds the maximum.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Min-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Min",
    "category": "method",
    "text": "Min(X)\nX >> Min\n\nFinds the minimum.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Record-Tuple",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Record",
    "category": "method",
    "text": "Record(Xs...)\n\nCreates a pipeline component for building a record.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Sum-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Sum",
    "category": "method",
    "text": "Sum(X)\nX >> Sum\n\nSums the elements produced by X.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Tag-Tuple{Symbol,Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Tag",
    "category": "method",
    "text": "Tag(name::Symbol, X)\n\nAssigns a name to a pipeline.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Take-Tuple{Any}",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Take",
    "category": "method",
    "text": "Take(N)\n\nTakes the first N elements.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Environment",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Environment",
    "category": "type",
    "text": "Environment()\n\nPipeline execution state.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Navigation",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Navigation",
    "category": "type",
    "text": "It\n\nIdentity pipeline with respect to pipeline composition.\n\nIt.a.b.c\n\nEquivalent to Lookup(:a) >> Lookup(:b) >> Lookup(:c).\n\n\n\n\n\n"
},

{
    "location": "pipelines/#DataKnots.Pipeline",
    "page": "Pipeline Algebra",
    "title": "DataKnots.Pipeline",
    "category": "type",
    "text": "Pipeline(op, args...)\n\nA pipeline is a transformation of monadic queries.\n\nParameter op is a function that performs the transformation; args are extra arguments passed to the function.\n\nThe pipeline transforms an input monadic query q by invoking op with the following arguments:\n\nop(env::Environment, q::Query, args...)\n\nThe result of op must again be a monadic query.\n\n\n\n\n\n"
},

{
    "location": "pipelines/#Base.run-Tuple{DataKnots.AbstractPipeline}",
    "page": "Pipeline Algebra",
    "title": "Base.run",
    "category": "method",
    "text": "run(F::AbstractPipeline; params...)\n\nRuns the pipeline with the given parameters.\n\n\n\n\n\n"
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
