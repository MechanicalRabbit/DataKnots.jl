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
    "page": "Thinking in DataKnots",
    "title": "Thinking in DataKnots",
    "category": "page",
    "text": ""
},

{
    "location": "thinking/#Thinking-in-DataKnots-1",
    "page": "Thinking in DataKnots",
    "title": "Thinking in DataKnots",
    "category": "section",
    "text": "DataKnots is a Julia library for constructing computational pipelines. DataKnots permit the encapsulation of data transformation logic so  that they could be independently tested and reused in various contexts.This library is named after the type of data objects it manipulates, DataKnots. Each DataKnot is a container holding structured, often interrelated, vectorized data. DataKnots come with an in-memory column-oriented backend which can handle tabular data from a CSV file, hierarchical data from JSON or XML, or even interlinked YAML graphs. DataKnots could also be federated to handle external data sources such as SQL databases or GraphQL enabled websites.Computations on DataKnots are expressed using Pipeline expressions. Pipelines are constructed algebraically using pipeline primitives and combinators. Primitives represent relationships among data from a given data source. Combinators are components that encapsulate logic. DataKnots provide a rich library of these pipeline components, and new ones could be coded in Julia. Importantly, any Julia function could be lifted to a pipeline component, providing easy and tight integration of Julia functions within DataKnot expressions.To start working with DataKnots, we import the package:using DataKnots"
},

{
    "location": "thinking/#Pipeline-Basics-1",
    "page": "Thinking in DataKnots",
    "title": "Pipeline Basics",
    "category": "section",
    "text": ""
},

{
    "location": "thinking/#Constant-Combinators-1",
    "page": "Thinking in DataKnots",
    "title": "Constant Combinators",
    "category": "section",
    "text": "To explain, let\'s consider an example combinator query that produces a DataKnot containing a singular string value, \"Hello World\". query(\"Hello World\")This example can be rewritten to show how \"Hello World\" is implicitly converted into its Combinator namesake. Hence, the query() argument is not a constant value at all, but rather an combinator expression which convert to a function that produces a constant value,  \"Hello World\" for each of its inputs.query(Combinator(\"Hello World\"))But, if \"Hello World\" expresses a query function, where is the function\'s input? There is also an implicit DataKnot containing a single element, nothing. Hence, this example can be rewritten:query(DataKnot(nothing), Combinator(\"Hello World\"))There are other combinators. The identity combinator, It converts to a query function that simply reproduces its input. This would permit us to write our \"Hello World\" example once again:query(query(\"Hello World\"), It)"
},

{
    "location": "thinking/#Lifting-Functions-to-Combinators-1",
    "page": "Thinking in DataKnots",
    "title": "Lifting Functions to Combinators",
    "category": "section",
    "text": "In fact, any scalar value can be seen as a function, just one that ignores its input. Given such a function, it could be lifted into its combinator form.hello_world(x) = \"Hello World\"\nHelloWorld = Lift(hello_world, It)\nquery(HelloWorld)The Lift() function takes the function being lifted into a combinator as the 1st argument. The 2nd and remaining arguments are the combinator expressions used to convert. In Julia, anonymous functions can be used to make this lifting far more convenient.query(Lift(x -> \"Hello World\", It))"
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
    "text": "Pages = [\n    \"layouts.md\",\n    \"vectors.md\",\n    \"shapes.md\",\n    \"queries.md\",\n    \"combinators.md\",\n    \"lifting.md\",\n]"
},

{
    "location": "layouts/#",
    "page": "Optimal Layouts",
    "title": "Optimal Layouts",
    "category": "page",
    "text": ""
},

{
    "location": "layouts/#Optimal-Layouts-1",
    "page": "Optimal Layouts",
    "title": "Optimal Layouts",
    "category": "section",
    "text": ""
},

{
    "location": "layouts/#Overview-1",
    "page": "Optimal Layouts",
    "title": "Overview",
    "category": "section",
    "text": "In DataKnots.jl, we often need to visualize composite data structures or complex Julia expressions.  For this purpose, module DataKnots.Layouts implements a pretty-printing engine.using DataKnots.LayoutsTo format a data structure, we need to encode its possible layouts in the form of a layout expression.A fixed single-line layout is created with Layouts.literal().Layouts.literal(\"department\")\n#-> literal(\"department\")Layouts could be combined using horizontal and vertical composition operators.lhz = Layouts.literal(\"department\") * Layouts.literal(\".\") * Layouts.literal(\"name\")\n#-> literal(\"department.name\")\n\nlvt = Layouts.literal(\"department\") / Layouts.literal(\"name\")\n#-> literal(\"department\") / literal(\"name\")Function Layouts.pretty_print() serializes the layout.pretty_print(lhz)\n#-> department.name\n\npretty_print(lvt)\n#=>\ndepartment\nname\n=#To indicate that we can choose between several different layouts, use the choice operator.l = lhz | lvt\n#-> literal(\"department.name\") | literal(\"department\") / literal(\"name\")The pretty-printing engine can search through possible layouts to find the best fit, which is expressed as a layout expression without a choice operator.Layouts.best(Layouts.fit(l))\n#-> literal(\"department.name\")The module implements the optimal layout algorithm described in https://research.google.com/pubs/pub44667.html."
},

{
    "location": "layouts/#DataKnots.Layouts.pretty_print",
    "page": "Optimal Layouts",
    "title": "DataKnots.Layouts.pretty_print",
    "category": "function",
    "text": "Layouts.pretty_print([io::IO], data)\n\nFormats the data so that it fits the width of the output screen.\n\n\n\n\n\n"
},

{
    "location": "layouts/#DataKnots.Layouts.print_code",
    "page": "Optimal Layouts",
    "title": "DataKnots.Layouts.print_code",
    "category": "function",
    "text": "Layouts.print_code([io::IO], code)\n\nFormats a Julia expression.\n\n\n\n\n\n"
},

{
    "location": "layouts/#API-Reference-1",
    "page": "Optimal Layouts",
    "title": "API Reference",
    "category": "section",
    "text": "DataKnots.Layouts.pretty_print\nDataKnots.Layouts.print_code"
},

{
    "location": "layouts/#Test-Suite-1",
    "page": "Optimal Layouts",
    "title": "Test Suite",
    "category": "section",
    "text": "We start with creating a simple tree structure.struct Node\n    name::Symbol\n    arms::Vector{Node}\nend\n\nNode(name) = Node(name, [])\n\ntree =\n    Node(:a, [Node(:an, [Node(:anchor, [Node(:anchorage), Node(:anchorite)]),\n                           Node(:anchovy),\n                           Node(:antic, [Node(:anticipation)])]),\n               Node(:arc, [Node(:arch, [Node(:archduke), Node(:archer)])]),\n               Node(:awl)])\n#-> Node(:a, Main.layouts.md.Node[ … ])To specify a layout expression for Node objects, we need to override Layout.tile().  Layout expressions are assembled from Layouts.literal() primitives using operators * (horizontal composition), / (vertical composition), and | (choice).function Layouts.tile(tree::Node)\n    if isempty(tree.arms)\n        return Layouts.literal(\"Node($(repr(tree.name)))\")\n    end\n    arm_lts = [Layouts.tile(arm) for arm in tree.arms]\n    v_lt = h_lt = nothing\n    for (k, arm_lt) in enumerate(arm_lts)\n        if k == 1\n            v_lt = arm_lt\n            h_lt = Layouts.nobreaks(arm_lt)\n        else\n            v_lt = v_lt * Layouts.literal(\",\") / arm_lt\n            h_lt = h_lt * Layouts.literal(\", \") * Layouts.nobreaks(arm_lt)\n        end\n    end\n    return Layouts.literal(\"Node($(repr(tree.name)), [\") *\n           (v_lt | h_lt) *\n           Layouts.literal(\"])\")\nendNow we can use function pretty_print() to render a nicely formatted representation of the tree.pretty_print(stdout, tree)\n#=>\nNode(:a, [Node(:an, [Node(:anchor, [Node(:anchorage), Node(:anchorite)]),\n                     Node(:anchovy),\n                     Node(:antic, [Node(:anticipation)])]),\n          Node(:arc, [Node(:arch, [Node(:archduke), Node(:archer)])]),\n          Node(:awl)])\n=#We can control the width of the output.pretty_print(IOContext(stdout, :displaysize => (24, 60)), tree)\n#=>\nNode(:a, [Node(:an, [Node(:anchor, [Node(:anchorage),\n                                    Node(:anchorite)]),\n                     Node(:anchovy),\n                     Node(:antic, [Node(:anticipation)])]),\n          Node(:arc, [Node(:arch, [Node(:archduke),\n                                   Node(:archer)])]),\n          Node(:awl)])\n=#We can display the layout expression itself, both the original and the optimized variants.Layouts.tile(tree)\n#=>\nliteral(\"Node(:a, [\")\n* (literal(\"Node(:an, [\")\n   * (literal(\"Node(:anchor, [\")\n   ⋮\n=#\n\nLayouts.best(Layouts.fit(stdout, Layouts.tile(tree)))\n#=>\nliteral(\"Node(:a, [\")\n* (literal(\"Node(:an, [\")\n   * (literal(\"Node(:anchor, [Node(:anchorage), Node(:anchorite)]),\")\n   ⋮\n=#For some built-in data structures, automatic layout is already provided.data = [\n    (name = \"RICHARD A\", position = \"FIREFIGHTER\", salary = 90018),\n    (name = \"DEBORAH A\", position = \"POLICE OFFICER\", salary = 86520),\n    (name = \"KATHERINE A\", position = \"PERSONAL COMPUTER OPERATOR II\", salary = 60780)\n]\n\npretty_print(data)\n#=>\n[(name = \"RICHARD A\", position = \"FIREFIGHTER\", salary = 90018),\n (name = \"DEBORAH A\", position = \"POLICE OFFICER\", salary = 86520),\n (name = \"KATHERINE A\",\n  position = \"PERSONAL COMPUTER OPERATOR II\",\n  salary = 60780)]\n=#This includes Julia syntax trees.Q = :(\n    Employee\n    >> ThenFilter(Department >> Name .== \"POLICE\")\n    >> ThenSort(Salary >> Desc)\n    >> ThenSelect(Name, Position, Salary)\n    >> ThenTake(10)\n)\n\nprint_code(Q)\n#=>\nEmployee\n>> ThenFilter(Department >> Name .== \"POLICE\")\n>> ThenSort(Salary >> Desc)\n>> ThenSelect(Name, Position, Salary)\n>> ThenTake(10)\n=#"
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
    "text": "Module DataKnots.Vectors implements an in-memory column store.using DataKnots.Vectors"
},

{
    "location": "vectors/#Tabular-data-1",
    "page": "Column Store",
    "title": "Tabular data",
    "category": "section",
    "text": "Structured data can often be represented in a tabular form.  For example, information about city employees can be arranged in the following table.name position salary\nJEFFERY A SERGEANT 101442\nJAMES A FIRE ENGINEER-EMT 103350\nTERRY A POLICE OFFICER 93354Internally, a database engine can store tabular data using composite data structures such as tuples and vectors.A tuple is a fixed-size collection of heterogeneous values and can represent a table row.(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442)A vector is a variable-size collection of homogeneous values and can store a table column.[\"JEFFERY A\", \"JAMES A\", \"TERRY A\"]For a table as a whole, we have two options: either store it as a vector of tuples or store it as a tuple of vectors.  The former is called a row-oriented format, commonly used in programming and traditional database engines.[(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442),\n (name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350),\n (name = \"TERRY A\", position = \"POLICE OFFICER\", salary = 93354)]The \"tuple of vectors\" layout is called a column-oriented format.  It is often used by analytical databases as it is more suited for processing complex analytical queries.The module DataKnots.Vectors implements necessary data structures to support column-oriented data format.  In particular, tabular data is represented using TupleVector objects.TupleVector(:name => [\"JEFFERY A\", \"JAMES A\", \"TERRY A\"],\n            :position => [\"SERGEANT\", \"FIRE ENGINEER-EMT\", \"POLICE OFFICER\"],\n            :salary => [101442, 103350, 93354])"
},

{
    "location": "vectors/#Blank-cells-1",
    "page": "Column Store",
    "title": "Blank cells",
    "category": "section",
    "text": "As we arrange data in a tabular form, we may need to leave some cells blank.For example, consider that a city employee could be compensated either with salary or with hourly pay.  To display the compensation data in a table, we add two columns: the annual salary and the hourly rate.  However, only one of the columns per each row is filled.name position salary rate\nJEFFERY A SERGEANT 101442 \nJAMES A FIRE ENGINEER-EMT 103350 \nTERRY A POLICE OFFICER 93354 \nLAKENYA A CROSSING GUARD  17.68How can this data be serialized in a column-oriented format?  To retain the advantages of the format, we\'d like to keep the column data in tightly packed vectors of elements.[\"JEFFERY A\", \"JAMES A\", \"TERRY A\", \"LAKENYA A\"]\n[\"SERGEANT\", \"FIRE ENGINEER-EMT\", \"POLICE OFFICER\", \"CROSSING GUARD\"]\n[101442, 103350, 93354]\n[17.68]Vectors of elements are partitioned into individual cells by the vectors of offsets.[1, 2, 3, 4, 5]\n[1, 2, 3, 4, 5]\n[1, 2, 3, 4, 4]\n[1, 1, 1, 1, 2]Together, elements and offsets faithfully reproduce the layout of the table columns.  A pair of the offset and the element vectors is encapsulated with a BlockVector instance.BlockVector(:, [\"JEFFERY A\", \"JAMES A\", \"TERRY A\", \"LAKENYA A\"])\nBlockVector(:, [\"SERGEANT\", \"FIRE ENGINEER-EMT\", \"POLICE OFFICER\", \"CROSSING GUARD\"])\nBlockVector([1, 2, 3, 4, 4], [101442, 103350, 93354])\nBlockVector([1, 1, 1, 1, 2], [17.68])Here, the symbol : is used as a shortcut for a unit range vector.A BlockVector instance is a column-oriented encoding of a vector of variable-size blocks.  In this specific case, each block corresponds to a table cell: an empty block for a blank cell and a one-element block for a filled cell.[[\"JEFFERY A\"], [\"JAMES A\"], [\"TERRY A\"], [\"LAKENYA A\"]]\n[[\"SERGEANT\"], [\"FIRE ENGINEER-EMT\"], [\"POLICE OFFICER\"], [\"CROSSING GUARD\"]]\n[[101442], [103350], [93354], []]\n[[], [], [], [17.68]]To represent the whole table, the columns should be wrapped with a TupleVector.TupleVector(\n    :name => BlockVector(:, [\"JEFFERY A\", \"JAMES A\", \"TERRY A\", \"LAKENYA A\"]),\n    :position => BlockVector(:, [\"SERGEANT\", \"FIRE ENGINEER-EMT\", \"POLICE OFFICER\", \"CROSSING GUARD\"]),\n    :salary => BlockVector([1, 2, 3, 4, 4], [101442, 103350, 93354]),\n    :rate => BlockVector([1, 1, 1, 1, 2], [17.68]))"
},

{
    "location": "vectors/#Nested-data-1",
    "page": "Column Store",
    "title": "Nested data",
    "category": "section",
    "text": "When data does not fit a single table, it can often be presented in a top-down fashion.  For example, HR data can be seen as a collection of departments, each of which containing the associated employees.Such data is serialized using nested data structures.[(name = \"POLICE\",\n  employee = [(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing),\n              (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016, rate = missing)]),\n (name = \"FIRE\",\n  employee = [(name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing),\n              (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484, rate = missing)]),\n (name = \"OEMC\",\n  employee = [(name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68),\n              (name = \"DORIS A\", position = \"CROSSING GUARD\", salary = missing, rate = 19.38)])]To store this data in a column-oriented format, we should use nested TupleVector and BlockVector instances.  We start with representing employee data.TupleVector(\n    :name => BlockVector(:, [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"]),\n    :position => BlockVector(:, [\"SERGEANT\", \"POLICE OFFICER\", \"FIRE ENGINEER-EMT\", \"FIRE FIGHTER-EMT\", \"CROSSING GUARD\", \"CROSSING GUARD\"]),\n    :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484]),\n    :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38]))The aggregated employee data could be partitioned to individual departments using a vector of offsets.BlockVector(\n    [1, 3, 5, 7],\n    TupleVector(\n        :name => BlockVector(:, [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"]),\n        :position => BlockVector(:, [\"SERGEANT\", \"POLICE OFFICER\", \"FIRE ENGINEER-EMT\", \"FIRE FIGHTER-EMT\", \"CROSSING GUARD\", \"CROSSING GUARD\"]),\n        :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484]),\n        :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38])))Adding a column of department names, we obtain HR data in a column-oriented format.TupleVector(\n    :name => BlockVector(:, [\"POLICE\", \"FIRE\", \"OEMC\"]),\n    :employee =>\n        BlockVector(\n            [1, 3, 5, 7],\n            TupleVector(\n                :name => BlockVector(:, [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"]),\n                :position => BlockVector(:, [\"SERGEANT\", \"POLICE OFFICER\", \"FIRE ENGINEER-EMT\", \"FIRE FIGHTER-EMT\", \"CROSSING GUARD\", \"CROSSING GUARD\"]),\n                :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484]),\n                :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38]))))Since writing offset vectors manually is tedious, DataKnots provides a convenient macro @VectorTree, which lets you specify column-oriented data using regular tuple and vector literals.@VectorTree (name = [String],\n             employee = [(name = [String], position = [String], salary = [Int], rate = [Float64])]) [\n    (name = \"POLICE\",\n     employee = [(name = \"JEFFERY A\", position = \"SERGEANT\", salary = 101442, rate = missing),\n                 (name = \"NANCY A\", position = \"POLICE OFFICER\", salary = 80016, rate = missing)]),\n    (name = \"FIRE\",\n     employee = [(name = \"JAMES A\", position = \"FIRE ENGINEER-EMT\", salary = 103350, rate = missing),\n                 (name = \"DANIEL A\", position = \"FIRE FIGHTER-EMT\", salary = 95484, rate = missing)]),\n    (name = \"OEMC\",\n     employee = [(name = \"LAKENYA A\", position = \"CROSSING GUARD\", salary = missing, rate = 17.68),\n                 (name = \"DORIS A\", position = \"CROSSING GUARD\", salary = missing, rate = 19.38)])\n]"
},

{
    "location": "vectors/#Circular-data-1",
    "page": "Column Store",
    "title": "Circular data",
    "category": "section",
    "text": "Some relationships cannot be represented using tabular or nested data structures.  Consider, for example, the relationship between an employee and their manager.  To serialize this relationship, we need to use references.emp_1 = (name = \"RHAM E\", position = \"MAYOR\", manager = missing)\nemp_2 = (name = \"EDDIE J\", position = \"SUPERINTENDENT OF POLICE\", manager = emp_1)\nemp_3 = (name = \"KEVIN N\", position = \"FIRST DEPUTY SUPERINTENDENT\", manager = emp_2)\nemp_4 = (name = \"FRED W\", position = \"CHIEF\", manager = emp_2)In the column-oriented format, we replace references with array indexes.[1, 2, 2]To specify the name of the target array, we wrap the indexes with an IndexVector instance.IndexVector(:EMP, [1, 2, 2])After adding the regular columns, we obtain the following structure.TupleVector(\n    :name => BlockVector(:, [\"RHAM E\", \"EDDIE J\", \"KEVIN N\", \"FRED W\"]),\n    :position => BlockVector(:, [\"MAYOR\", \"SUPERINTENDENT OF POLICE\", \"FIRST DEPUTY SUPERINTENDENT\", \"CHIEF\"]),\n    :manager => BlockVector([1, 1, 2, 3, 4], IndexVector(:EMP, [1, 2, 2])))We still need to associate the array name EMP with the actual array.  This array is provided by a CapsuleVector instance.CapsuleVector(\n    IndexVector(:EMP, 1:4),\n    :EMP =>\n        TupleVector(\n            :name => BlockVector(:, [\"RHAM E\", \"EDDIE J\", \"KEVIN N\", \"FRED W\"]),\n            :position => BlockVector(:, [\"MAYOR\", \"SUPERINTENDENT OF POLICE\", \"FIRST DEPUTY SUPERINTENDENT\", \"CHIEF\"]),\n            :manager => BlockVector([1, 1, 2, 3, 4], IndexVector(:EMP, [1, 2, 2]))))"
},

{
    "location": "vectors/#Databases-1",
    "page": "Column Store",
    "title": "Databases",
    "category": "section",
    "text": "Using a combination of TupleVector, BlockVector, and IndexVector wrapped in a CapsuleVector instance, we can serialize an entire database in a column-oriented format.For example, consider a database with two types of entities: departments and employees, where each employee belongs to a department.  Two collections of entities can be represented as follows.TupleVector(\n    :name => BlockVector(:, [\"POLICE\", \"FIRE\", \"OEMC\"]),\n    :employee => BlockVector([1, 3, 5, 7], IndexVector(:EMP, [1, 2, 3, 4, 5, 6])))\n\nTupleVector(\n    :name => BlockVector(:, [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"]),\n    :department => BlockVector(:, IndexVector(:DEPT, [1, 1, 2, 2, 3, 3])),\n    :position => BlockVector(:, [\"SERGEANT\", \"POLICE OFFICER\", \"FIRE ENGINEER-EMT\", \"FIRE FIGHTER-EMT\", \"CROSSING GUARD\", \"CROSSING GUARD\"]),\n    :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484]),\n    :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38]))The collections are linked to each other with a pair of IndexVector instances.In addition, we create the database root, which contains indexes to each entity array.TupleVector(\n    :department => BlockVector([1, 4], IndexVector(:DEPT, 1:3)),\n    :employee => BlockVector([1, 7], IndexVector(:EMP, 1:6)))The database root is wrapped in a CapsuleVector to provide the arrays DEPT and EMP.CapsuleVector(\n    TupleVector(\n        :department => BlockVector([1, 4], IndexVector(:DEPT, 1:3)),\n        :employee => BlockVector([1, 7], IndexVector(:EMP, 1:6))),\n    :DEPT =>\n        TupleVector(\n            :name => BlockVector(:, [\"POLICE\", \"FIRE\", \"OEMC\"]),\n            :employee => BlockVector([1, 3, 5, 7], IndexVector(:EMP, [1, 2, 3, 4, 5, 6]))),\n    :EMP =>\n        TupleVector(\n            :name => BlockVector(:, [\"JEFFERY A\", \"NANCY A\", \"JAMES A\", \"DANIEL A\", \"LAKENYA A\", \"DORIS A\"]),\n            :department => BlockVector(:, IndexVector(:DEPT, [1, 1, 2, 2, 3, 3])),\n            :position => BlockVector(:, [\"SERGEANT\", \"POLICE OFFICER\", \"FIRE ENGINEER-EMT\", \"FIRE FIGHTER-EMT\", \"CROSSING GUARD\", \"CROSSING GUARD\"]),\n            :salary => BlockVector([1, 2, 3, 4, 5, 5, 5], [101442, 80016, 103350, 95484]),\n            :rate => BlockVector([1, 1, 1, 1, 1, 2, 3], [17.68, 19.38])))"
},

{
    "location": "vectors/#DataKnots.Vectors.TupleVector",
    "page": "Column Store",
    "title": "DataKnots.Vectors.TupleVector",
    "category": "type",
    "text": "TupleVector([lbls::Vector{Symbol}], len::Int, cols::Vector{AbstractVector})\nTupleVector(cols::Pair{Symbol,<:AbstractVector}...)\n\nVector of tuples stored as a collection of column vectors.\n\n\n\n\n\n"
},

{
    "location": "vectors/#DataKnots.Vectors.BlockVector",
    "page": "Column Store",
    "title": "DataKnots.Vectors.BlockVector",
    "category": "type",
    "text": "BlockVector(offs::AbstractVector{Int}, elts::AbstractVector)\nBlockVector(blks::AbstractVector)\n\nVector of vectors (blocks) stored as a vector of elements partitioned by a vector of offsets.\n\n\n\n\n\n"
},

{
    "location": "vectors/#DataKnots.Vectors.IndexVector",
    "page": "Column Store",
    "title": "DataKnots.Vectors.IndexVector",
    "category": "type",
    "text": "IndexVector(ident::Symbol, idxs::AbstractVector{Int})\n\nVector of indexes in some named vector.\n\n\n\n\n\n"
},

{
    "location": "vectors/#DataKnots.Vectors.CapsuleVector",
    "page": "Column Store",
    "title": "DataKnots.Vectors.CapsuleVector",
    "category": "type",
    "text": "CapsuleVector(vals::AbstractVector, refs::Pair{Symbol,<:AbstractVector}...)\n\nEncapsulates reference vectors to dereference any nested indexes.\n\n\n\n\n\n"
},

{
    "location": "vectors/#API-Reference-1",
    "page": "Column Store",
    "title": "API Reference",
    "category": "section",
    "text": "DataKnots.Vectors.TupleVector\nDataKnots.Vectors.BlockVector\nDataKnots.Vectors.IndexVector\nDataKnots.Vectors.CapsuleVector"
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
    "text": "TupleVector is a vector of tuples stored as a collection of parallel vectors.tv = TupleVector(:name => [\"GARRY M\", \"ANTHONY R\", \"DANA A\"],\n                 :salary => [260004, 185364, 170112])\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\ndisplay(tv)\n#=>\nTupleVector of 3 × (name = String, salary = Int):\n (name = \"GARRY M\", salary = 260004)\n (name = \"ANTHONY R\", salary = 185364)\n (name = \"DANA A\", salary = 170112)\n=#It is possible to construct a TupleVector without labels.TupleVector(length(tv), columns(tv))\n#-> @VectorTree (String, Int) [(\"GARRY M\", 260004) … ]An error is reported in case of duplicate labels or columns of different height.TupleVector(:name => [\"GARRY M\", \"ANTHONY R\"],\n            :name => [\"DANA A\", \"JUAN R\"])\n#-> ERROR: duplicate column label :name\n\nTupleVector(:name => [\"GARRY M\", \"ANTHONY R\"],\n            :salary => [260004, 185364, 170112])\n#-> ERROR: unexpected column heightWe can access individual components of the vector.labels(tv)\n#-> Symbol[:name, :salary]\n\nwidth(tv)\n#-> 2\n\ncolumn(tv, 2)\n#-> [260004, 185364, 170112]\n\ncolumn(tv, :salary)\n#-> [260004, 185364, 170112]\n\ncolumns(tv)\n#-> …[[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [260004, 185364, 170112]]When indexed by another vector, we get a new instance of TupleVector.tv′ = tv[[3,1]]\ndisplay(tv′)\n#=>\nTupleVector of 2 × (name = String, salary = Int):\n (name = \"DANA A\", salary = 170112)\n (name = \"GARRY M\", salary = 260004)\n=#Note that the new instance keeps a reference to the index and the original column vectors.  Updated column vectors are generated on demand.column(tv′, 2)\n#-> [170112, 260004]"
},

{
    "location": "vectors/#BlockVector-1",
    "page": "Column Store",
    "title": "BlockVector",
    "category": "section",
    "text": "BlockVector is a vector of homogeneous vectors (blocks) stored as a vector of elements partitioned into individual blocks by a vector of offsets.bv = BlockVector([[\"HEALTH\"], [\"FINANCE\", \"HUMAN RESOURCES\"], [], [\"POLICE\", \"FIRE\"]])\n#-> @VectorTree [String] [\"HEALTH\", [\"FINANCE\", \"HUMAN RESOURCES\"], missing, [\"POLICE\", \"FIRE\"]]\n\ndisplay(bv)\n#=>\nBlockVector of 4 × [String]:\n \"HEALTH\"\n [\"FINANCE\", \"HUMAN RESOURCES\"]\n missing\n [\"POLICE\", \"FIRE\"]\n=#We can omit brackets for singular blocks and use missing in place of empty blocks.BlockVector([\"HEALTH\", [\"FINANCE\", \"HUMAN RESOURCES\"], missing, [\"POLICE\", \"FIRE\"]])\n#-> @VectorTree [String] [\"HEALTH\", [\"FINANCE\", \"HUMAN RESOURCES\"], missing, [\"POLICE\", \"FIRE\"]]It is possible to specify the offset and the element vectors separately.BlockVector([1, 2, 4, 4, 6], [\"HEALTH\", \"FINANCE\", \"HUMAN RESOURCES\", \"POLICE\", \"FIRE\"])\n#-> @VectorTree [String] [\"HEALTH\", [\"FINANCE\", \"HUMAN RESOURCES\"], missing, [\"POLICE\", \"FIRE\"]]If each block contains exactly one element, we could use : in place of the offset vector.BlockVector(:, [\"HEALTH\", \"FINANCE\", \"HUMAN RESOURCES\", \"POLICE\", \"FIRE\"])\n#-> @VectorTree [String] [\"HEALTH\", \"FINANCE\", \"HUMAN RESOURCES\", \"POLICE\", \"FIRE\"]The BlockVector constructor verifies that the offset vector is well-formed.BlockVector(Base.OneTo(0), [])\n#-> ERROR: partition must be non-empty\n\nBlockVector(Int[], [])\n#-> ERROR: partition must be non-empty\n\nBlockVector([0], [])\n#-> ERROR: partition must start with 1\n\nBlockVector([1,2,2,1], [\"HEALTH\"])\n#-> ERROR: partition must be monotone\n\nBlockVector(Base.OneTo(4), [\"HEALTH\", \"FINANCE\"])\n#-> ERROR: partition must enclose the elements\n\nBlockVector([1,2,3,6], [\"HEALTH\", \"FINANCE\"])\n#-> ERROR: partition must enclose the elementsWe can access individual components of the vector.offsets(bv)\n#-> [1, 2, 4, 4, 6]\n\nelements(bv)\n#-> [\"HEALTH\", \"FINANCE\", \"HUMAN RESOURCES\", \"POLICE\", \"FIRE\"]\n\npartition(bv)\n#-> ([1, 2, 4, 4, 6], [\"HEALTH\", \"FINANCE\", \"HUMAN RESOURCES\", \"POLICE\", \"FIRE\"])When indexed by a vector of indexes, an instance of BlockVector is returned.elts = [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nreg_bv = BlockVector(:, elts)\n#-> @VectorTree [String] [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nopt_bv = BlockVector([1, 2, 3, 3, 4, 4, 5, 6, 6, 6, 7], elts)\n#-> @VectorTree [String] [\"POLICE\", \"FIRE\", missing, \"HEALTH\", missing, \"AVIATION\", \"WATER MGMNT\", missing, missing, \"FINANCE\"]\n\nplu_bv = BlockVector([1, 1, 1, 2, 2, 4, 4, 6, 7], elts)\n#-> @VectorTree [String] [missing, missing, \"POLICE\", missing, [\"FIRE\", \"HEALTH\"], missing, [\"AVIATION\", \"WATER MGMNT\"], \"FINANCE\"]\n\nreg_bv[[1,3,5,3]]\n#-> @VectorTree [String] [\"POLICE\", \"HEALTH\", \"WATER MGMNT\", \"HEALTH\"]\n\nplu_bv[[1,3,5,3]]\n#-> @VectorTree [String] [missing, \"POLICE\", [\"FIRE\", \"HEALTH\"], \"POLICE\"]\n\nreg_bv[Base.OneTo(4)]\n#-> @VectorTree [String] [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\"]\n\nreg_bv[Base.OneTo(6)]\n#-> @VectorTree [String] [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nplu_bv[Base.OneTo(6)]\n#-> @VectorTree [String] [missing, missing, \"POLICE\", missing, [\"FIRE\", \"HEALTH\"], missing]\n\nopt_bv[Base.OneTo(10)]\n#-> @VectorTree [String] [\"POLICE\", \"FIRE\", missing, \"HEALTH\", missing, \"AVIATION\", \"WATER MGMNT\", missing, missing, \"FINANCE\"]"
},

{
    "location": "vectors/#IndexVector-1",
    "page": "Column Store",
    "title": "IndexVector",
    "category": "section",
    "text": "IndexVector is a vector of indexes in some named vector.iv = IndexVector(:REF, [1, 1, 1, 2])\n#-> @VectorTree &REF [1, 1, 1, 2]\n\ndisplay(iv)\n#=>\nIndexVector of 4 × &REF:\n 1\n 1\n 1\n 2\n=#We can obtain the components of the vector.identifier(iv)\n#-> :REF\n\nindexes(iv)\n#-> [1, 1, 1, 2]Indexing an IndexVector by a vector produces another IndexVector instance.iv[[4,2]]\n#-> @VectorTree &REF [2, 1]IndexVector can be deferenced against a list of named vectors.refv = [\"COMISSIONER\", \"DEPUTY COMISSIONER\", \"ZONING ADMINISTRATOR\", \"PROJECT MANAGER\"]\n\ndereference(iv, [:REF => refv])\n#-> [\"COMISSIONER\", \"COMISSIONER\", \"COMISSIONER\", \"DEPUTY COMISSIONER\"]Function dereference() has no effect on other types of vectors, or when the desired reference vector is not in the list.dereference(iv, [:REF′ => refv])\n#-> @VectorTree &REF [1, 1, 1, 2]\n\ndereference([1, 1, 1, 2], [:REF => refv])\n#-> [1, 1, 1, 2]"
},

{
    "location": "vectors/#CapsuleVector-1",
    "page": "Column Store",
    "title": "CapsuleVector",
    "category": "section",
    "text": "CapsuleVector provides references for a composite vector with nested indexes. We use CapsuleVector to represent self-referential and mutually referential data.cv = CapsuleVector(TupleVector(:ref => iv), :REF => refv)\n#-> @VectorTree (ref = &REF,) [(ref = 1,), (ref = 1,), (ref = 1,), (ref = 2,)] where {REF = [ … ]}\n\ndisplay(cv)\n#=>\nCapsuleVector of 4 × (ref = &REF,):\n (ref = 1,)\n (ref = 1,)\n (ref = 1,)\n (ref = 2,)\nwhere\n REF = [\"COMISSIONER\", \"DEPUTY COMISSIONER\" … ]\n=#Function decapsulate() decomposes a capsule into the underlying vector and a list of references.decapsulate(cv)\n#-> (@VectorTree (ref = &REF,) [ … ], Pair{Symbol,AbstractArray{T,1} where T}[ … ])Function recapsulate() applies the given function to the underlying vector and encapsulates the output of the function.cv′ = recapsulate(v -> v[:, :ref], cv)\n#-> @VectorTree &REF [1, 1, 1, 2] where {REF = [ … ]}We could dereference CapsuleVector if it wraps an IndexVector instance. Function dereference() has no effect otherwise.dereference(cv′)\n#-> [\"COMISSIONER\", \"COMISSIONER\", \"COMISSIONER\", \"DEPUTY COMISSIONER\"]\n\ndereference(cv)\n#-> @VectorTree (ref = &REF,) [(ref = 1,), (ref = 1,), (ref = 1,), (ref = 2,)] where {REF = [ … ]}Indexing CapsuleVector by a vector produces another instance of CapsuleVector.cv[[4,2]]\n#-> @VectorTree (ref = &REF,) [(ref = 2,), (ref = 1,)] where {REF = [ … ]}"
},

{
    "location": "vectors/#@VectorTree-1",
    "page": "Column Store",
    "title": "@VectorTree",
    "category": "section",
    "text": "We can use @VectorTree macro to convert vector literals to the columnar form assembled with TupleVector, BlockVector, IndexVector, and CapsuleVector.TupleVector is created from a matrix or a vector of (named) tuples.@VectorTree (name = String, salary = Int) [\n    \"GARRY M\"   260004\n    \"ANTHONY R\" 185364\n    \"DANA A\"    170112\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\n@VectorTree (name = String, salary = Int) [\n    (\"GARRY M\", 260004),\n    (\"ANTHONY R\", 185364),\n    (\"DANA A\", 170112),\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\n@VectorTree (name = String, salary = Int) [\n    (name = \"GARRY M\", salary = 260004),\n    (name = \"ANTHONY R\", salary = 185364),\n    (name = \"DANA A\", salary = 170112),\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]Column labels are optional.@VectorTree (String, Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n#-> @VectorTree (String, Int) [(\"GARRY M\", 260004) … ]BlockVector and IndexVector can also be constructed.@VectorTree [String] [\n    \"HEALTH\",\n    [\"FINANCE\", \"HUMAN RESOURCES\"],\n    missing,\n    [\"POLICE\", \"FIRE\"],\n]\n#-> @VectorTree [String] [\"HEALTH\", [\"FINANCE\", \"HUMAN RESOURCES\"], missing, [\"POLICE\", \"FIRE\"]]\n\n@VectorTree &REF [1, 1, 1, 2]\n#-> @VectorTree &REF [1, 1, 1, 2]A CapsuleVector could be constructed using where syntax.@VectorTree &REF [1, 1, 1, 2] where {REF = refv}\n#-> @VectorTree &REF [1, 1, 1, 2] where {REF = [\"COMISSIONER\", \"DEPUTY COMISSIONER\"  … ]}Ill-formed @VectorTree contructors are rejected.@VectorTree (String, Int) (\"GARRY M\", 260004)\n#=>\nERROR: LoadError: expected a vector literal; got :((\"GARRY M\", 260004))\n⋮\n=#\n\n@VectorTree (String, Int) [(position = \"SUPERINTENDENT OF POLICE\", salary = 260004)]\n#=>\nERROR: LoadError: expected no label; got :(position = \"SUPERINTENDENT OF POLICE\")\n⋮\n=#\n\n@VectorTree (name = String, salary = Int) [(position = \"SUPERINTENDENT OF POLICE\", salary = 260004)]\n#=>\nERROR: LoadError: expected label :name; got :(position = \"SUPERINTENDENT OF POLICE\")\n⋮\n=#\n\n@VectorTree (name = String, salary = Int) [(\"GARRY M\", \"SUPERINTENDENT OF POLICE\", 260004)]\n#=>\nERROR: LoadError: expected 2 column(s); got :((\"GARRY M\", \"SUPERINTENDENT OF POLICE\", 260004))\n⋮\n=#\n\n@VectorTree (name = String, salary = Int) [\"GARRY M\"]\n#=>\nERROR: LoadError: expected a tuple or a row literal; got \"GARRY M\"\n⋮\n=#\n\n@VectorTree &REF [[]] where (:REF => [])\n#=>\nERROR: LoadError: expected an assignment; got :(:REF => [])\n⋮\n=#Using @VectorTree, we can easily construct hierarchical and mutually referential data.hier_data = @VectorTree (name = [String], employee = [(name = [String], salary = [Int])]) [\n    \"POLICE\"    [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n    \"FIRE\"      [\"JOSE S\" 202728; \"CHARLES S\" 197736]\n]\ndisplay(hier_data)\n#=>\nTupleVector of 2 × (name = [String], employee = [(name = [String], salary = [Int])]):\n (name = \"POLICE\", employee = [(name = \"GARRY M\", salary = 260004) … ])\n (name = \"FIRE\", employee = [(name = \"JOSE S\", salary = 202728) … ])\n=#\n\nmref_data = @VectorTree (department = [&DEPT], employee = [&EMP]) [\n    [1, 2]  [1, 2, 3, 4, 5]\n] where {\n    DEPT = @VectorTree (name = [String], employee = [&EMP]) [\n        \"POLICE\"    [1, 2, 3]\n        \"FIRE\"      [4, 5]\n    ]\n    ,\n    EMP = @VectorTree (name = [String], department = [&DEPT], salary = [Int]) [\n        \"GARRY M\"   1   260004\n        \"ANTHONY R\" 1   185364\n        \"DANA A\"    1   170112\n        \"JOSE S\"    2   202728\n        \"CHARLES S\" 2   197736\n    ]\n}\ndisplay(mref_data)\n#=>\nCapsuleVector of 1 × (department = [&DEPT], employee = [&EMP]):\n (department = [1, 2], employee = [1, 2, 3, 4, 5])\nwhere\n DEPT = @VectorTree (name = [String], employee = [&EMP]) [(name = \"POLICE\", employee = [1, 2, 3]) … ]\n EMP = @VectorTree (name = [String], department = [&DEPT], salary = [Int]) [(name = \"GARRY M\", department = 1, salary = 260004) … ]\n=#"
},

{
    "location": "shapes/#",
    "page": "Type System",
    "title": "Type System",
    "category": "page",
    "text": ""
},

{
    "location": "shapes/#Type-System-1",
    "page": "Type System",
    "title": "Type System",
    "category": "section",
    "text": "This module lets us describe the shape of the data.using DataKnots.Shapes"
},

{
    "location": "shapes/#Cardinality-1",
    "page": "Type System",
    "title": "Cardinality",
    "category": "section",
    "text": "Enumerated type Cardinality is used to constrain the cardinality of a data block.  A block of data is called regular if it must contain exactly one element; optional if it may have no elements; and plural if it may have more than one element.  This gives us four different cardinality constraints.display(Cardinality)\n#=>\nEnum Cardinality:\nREG = 0\nOPT = 1\nPLU = 2\nOPT|PLU = 3\n=#Cardinality values support bitwise operations.REG|OPT|PLU             #-> OPT|PLU\nPLU&~PLU                #-> REGWe can use predicates isregular(), isoptional(), isplural() to check cardinality values.isregular(REG)          #-> true\nisregular(OPT)          #-> false\nisregular(PLU)          #-> false\nisoptional(OPT)         #-> true\nisoptional(PLU)         #-> false\nisplural(PLU)           #-> true\nisplural(OPT)           #-> falseCardinality supports standard operations on enumerated types.typemin(Cardinality)    #-> REG\ntypemax(Cardinality)    #-> OPT|PLU\nREG < OPT|PLU           #-> true\n\nCardinality(3)\n#-> OPT|PLU\nread(IOBuffer(\"\\x03\"), Cardinality)\n#-> OPT|PLUThere is a partial ordering defined on Cardinality values.  We can determine the greatest and the least cardinality; the least upper bound and the greatest lower bound of a collection of Cardinality values; and, for two Cardinality values, determine whether one of the values is smaller than the other.bound(Cardinality)      #-> REG\nibound(Cardinality)     #-> OPT|PLU\n\nbound(OPT, PLU)         #-> OPT|PLU\nibound(PLU, OPT)        #-> REG\n\nfits(OPT, PLU)          #-> false\nfits(REG, OPT|PLU)      #-> true"
},

{
    "location": "shapes/#Data-shapes-1",
    "page": "Type System",
    "title": "Data shapes",
    "category": "section",
    "text": "The structure of composite data is specified with shape objects.NativeShape specifies the type of a regular Julia value.str_shp = NativeShape(String)\n#-> NativeShape(String)\n\neltype(str_shp)\n#-> StringClassShape refers to a shape with a name.cls_shp = ClassShape(:Emp)\n#-> ClassShape(:Emp)\n\nclass(cls_shp)\n#-> :EmpWe can provide a definition for a class name using rebind() method.clos_shp = cls_shp |> rebind(:Emp => str_shp)\n#-> ClassShape(:Emp) |> rebind(:Emp => NativeShape(String))Now we can obtain the actual shape of the class.clos_shp[]\n#-> NativeShape(String)A shape which does not contain any nested undefined classes is called closed.isclosed(str_shp)\n#-> true\n\nisclosed(cls_shp)\n#-> false\n\nisclosed(clos_shp)\n#-> trueTupleShape lets us specify the field types of a tuple value.tpl_shp = TupleShape(NativeShape(String),\n                     BlockShape(ClassShape(:Emp)))\n#-> TupleShape(NativeShape(String), BlockShape(ClassShape(:Emp)))\n\nforeach(println, tpl_shp[:])\n#=>\nNativeShape(String)\nBlockShape(ClassShape(:Emp))\n=#Two special shape types are used to indicate that the value may have any shape, or cannot exist.any_shp = AnyShape()\n#-> AnyShape()\n\nnone_shp = NoneShape()\n#-> NoneShape()To any shape, we can attach an arbitrary set of attributes, which are called decorations.  In particular, we can label the values.decor_shp = str_shp |> decorate(:tag => :position)\n#-> NativeShape(String) |> decorate(:tag => :position)The value of a decoration could be extracted.decoration(decor_shp, :tag)We can enforce the type and the default value of the decoration.decoration(decor_shp, :tag, Symbol, Symbol(\"\"))\n#-> :position\ndecoration(decor_shp, :tag, String, \"\")\n#-> \"\"\ndecoration(str_shp, :tag, String, \"\")\n#-> \"\"InputShape and OutputShape are derived shapes that describe the structure of the query input and the query output.To describe the query input, we specify the shape of the input elements, the shapes of the parameters, and whether or not the input is framed.i_shp = InputShape(ClassShape(:Emp),\n                   [:D => OutputShape(NativeShape(String))],\n                   true)\n#-> InputShape(ClassShape(:Emp), [:D => OutputShape(NativeShape(String))], true)\n\ni_shp[]\n#-> ClassShape(:Emp)\n\ndomain(i_shp)\n#-> ClassShape(:Emp)\n\nmode(i_shp)\n#-> InputMode([:D => OutputShape(NativeShape(String))], true)To describe the query output, we specify the shape and the cardinality of the output elements.o_shp = OutputShape(NativeShape(Int), OPT|PLU)\n#-> OutputShape(NativeShape(Int), OPT|PLU)\n\no_shp[]\n#-> NativeShape(Int)\n\ncardinality(o_shp)\n#-> OPT|PLU\n\ndomain(o_shp)\n#-> NativeShape(Int)\n\nmode(o_shp)\n#-> OutputMode(OPT|PLU)RecordShape` specifies the shape of a record value where each field has a certain shape and cardinality.dept_shp = RecordShape(OutputShape(String) |> decorate(:tag => :name),\n                       OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :employee))\n#=>\nRecordShape(OutputShape(NativeShape(String) |> decorate(:tag => :name)),\n            OutputShape(ClassShape(:Emp) |> decorate(:tag => :employee),\n                        OPT|PLU))\n=#\n\nemp_shp = RecordShape(OutputShape(String) |> decorate(:tag => :name),\n                      OutputShape(:Dept) |> decorate(:tag => :department),\n                      OutputShape(String) |> decorate(:tag => :position),\n                      OutputShape(Int) |> decorate(:tag => :salary),\n                      OutputShape(:Emp, OPT) |> decorate(:tag => :manager),\n                      OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :subordinate))\n#=>\nRecordShape(OutputShape(NativeShape(String) |> decorate(:tag => :name)),\n            OutputShape(ClassShape(:Dept) |> decorate(:tag => :department)),\n            OutputShape(NativeShape(String) |> decorate(:tag => :position)),\n            OutputShape(NativeShape(Int) |> decorate(:tag => :salary)),\n            OutputShape(ClassShape(:Emp) |> decorate(:tag => :manager), OPT),\n            OutputShape(ClassShape(:Emp) |> decorate(:tag => :subordinate),\n                        OPT|PLU))\n=#Using the combination of different shapes we can describe the structure of any data source.db_shp = RecordShape(OutputShape(:Dept, OPT|PLU) |> decorate(:tag => :department),\n                     OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :employee))\n\ndb_shp |> rebind(:Dept => dept_shp, :Emp => emp_shp)\n#=>\nRecordShape(\n    OutputShape(\n        ClassShape(:Dept)\n        |> rebind(:Dept => RecordShape(\n                               OutputShape(NativeShape(String)\n                                           |> decorate(:tag => :name)),\n                               OutputShape(ClassShape(:Emp)\n                                           |> decorate(:tag => :employee),\n                                           OPT|PLU))\n                           |> decorate(:tag => :department),\n                  :Emp => RecordShape(\n                              OutputShape(NativeShape(String)\n                                          |> decorate(:tag => :name)),\n                              ⋮\n                              OutputShape(ClassShape(:Emp)\n                                          |> decorate(:tag => :subordinate),\n                                          OPT|PLU))),\n        OPT|PLU),\n    OutputShape(\n        ClassShape(:Emp)\n        |> rebind(:Dept => RecordShape(\n                               OutputShape(NativeShape(String)\n                                           |> decorate(:tag => :name)),\n                               OutputShape(ClassShape(:Emp)\n                                           |> decorate(:tag => :employee),\n                                           OPT|PLU)),\n                  :Emp => RecordShape(\n                              OutputShape(NativeShape(String)\n                                          |> decorate(:tag => :name)),\n                              ⋮\n                              OutputShape(ClassShape(:Emp)\n                                          |> decorate(:tag => :subordinate),\n                                          OPT|PLU))\n                          |> decorate(:tag => :employee)),\n        OPT|PLU))\n=#"
},

{
    "location": "shapes/#Shape-ordering-1",
    "page": "Type System",
    "title": "Shape ordering",
    "category": "section",
    "text": "The same data can satisfy many different shape constraints.  For example, a vector BlockVector([Chicago]) can be said to have, among others, the shape BlockShape(String), the shape OutputShape(String, OPT|PLU) or the shape AnyShape().  We can tell, for any two shapes, if one of them is more specific than the other.fits(NativeShape(Int), NativeShape(Number))     #-> true\nfits(NativeShape(Int), NativeShape(String))     #-> false\n\nfits(ClassShape(:Emp), ClassShape(:Emp))        #-> true\nfits(ClassShape(:Emp), ClassShape(:Dept))       #-> false\n\nfits(ClassShape(:Emp),\n     ClassShape(:Emp)\n     |> rebind(:Emp => NativeShape(String)))    #-> false\n\nfits(ClassShape(:Emp),\n     ClassShape(:Dept)\n     |> rebind(:Emp => NativeShape(String)))    #-> false\n\nfits(ClassShape(:Emp)\n     |> rebind(:Emp => NativeShape(String)),\n     ClassShape(:Emp))                          #-> true\n\nfits(ClassShape(:Emp)\n     |> rebind(:Emp => NativeShape(String)),\n     ClassShape(:Emp)\n     |> rebind(:Emp => NativeShape(String)))    #-> true\n\nfits(ClassShape(:Emp)\n     |> rebind(:Emp => NativeShape(String)),\n     ClassShape(:Dept)\n     |> rebind(:Dept => NativeShape(String)))   #-> false\n\nfits(ClassShape(:Emp)\n     |> rebind(:Emp => NativeShape(String)),\n     ClassShape(:Emp)\n     |> rebind(:Emp => NativeShape(Number)))    #-> false\n\nfits(BlockShape(Int), BlockShape(Number))       #-> true\nfits(BlockShape(Int), BlockShape(String))       #-> false\n\nfits(TupleShape(Int, BlockShape(String)),\n     TupleShape(Number, BlockShape(String)))    #-> true\nfits(TupleShape(Int, BlockShape(String)),\n     TupleShape(String, BlockShape(String)))    #-> false\nfits(TupleShape(Int),\n     TupleShape(Number, BlockShape(String)))    #-> false\n\nfits(InputShape(Int,\n                [:X => OutputShape(Int),\n                 :Y => OutputShape(String)],\n                true),\n     InputShape(Number,\n                [:X => OutputShape(Int, OPT)])) #-> true\nfits(InputShape(Int),\n     InputShape(Number, true))                  #-> false\nfits(InputShape(Int,\n                [:X => OutputShape(Int, OPT)]),\n     InputShape(Number,\n                [:X => OutputShape(Int)]))      #-> false\n\nfits(OutputShape(Int),\n     OutputShape(Number, OPT))                  #-> true\nfits(OutputShape(Int, PLU),\n     OutputShape(Number, OPT))                  #-> false\nfits(OutputShape(Int),\n     OutputShape(String, OPT))                  #-> false\n\nfits(RecordShape(OutputShape(Int),\n                 OutputShape(String, OPT)),\n     RecordShape(OutputShape(Number),\n                 OutputShape(String, OPT|PLU)))     #-> true\nfits(RecordShape(OutputShape(Int, OPT),\n                 OutputShape(String)),\n     RecordShape(OutputShape(Number),\n                 OutputShape(String, OPT|PLU)))     #-> false\nfits(RecordShape(OutputShape(Int)),\n     RecordShape(OutputShape(Number),\n                 OutputShape(String, OPT|PLU)))     #-> falseShapes of different kinds are typically not compatible with each other.  The exceptions are AnyShape and NullShape.fits(NativeShape(Int), ClassShape(:Emp))    #-> false\nfits(NativeShape(Int), AnyShape())          #-> true\nfits(NoneShape(), ClassShape(:Emp))         #-> trueShape decorations are treated as additional shape constraints.fits(NativeShape(String) |> decorate(:tag => :name),\n     NativeShape(String) |> decorate(:tag => :name))        #-> true\nfits(NativeShape(String),\n     NativeShape(String) |> decorate(:tag => :name))        #-> false\nfits(NativeShape(String) |> decorate(:tag => :position),\n     NativeShape(String))                                   #-> true\nfits(NativeShape(String) |> decorate(:tag => :position),\n     NativeShape(String) |> decorate(:tag => :name))        #-> falseFor any given number of shapes, we can find their upper bound, the shape that is more general than each of them.  We can also find their lower bound.bound(NativeShape(Int), NativeShape(Number))\n#-> NativeShape(Number)\nibound(NativeShape(Int), NativeShape(Number))\n#-> NativeShape(Int)\n\nbound(ClassShape(:Emp), ClassShape(:Emp))\n#-> ClassShape(:Emp)\nibound(ClassShape(:Emp), ClassShape(:Emp))\n#-> ClassShape(:Emp)\nbound(ClassShape(:Emp), ClassShape(:Dept))\n#-> AnyShape()\nibound(ClassShape(:Emp), ClassShape(:Dept))\n#-> NoneShape()\nbound(ClassShape(:Emp),\n      ClassShape(:Emp) |> rebind(:Emp => NativeShape(String)))\n#-> ClassShape(:Emp)\nibound(ClassShape(:Emp),\n       ClassShape(:Emp) |> rebind(:Emp => NativeShape(String)))\n#-> ClassShape(:Emp) |> rebind(:Emp => NativeShape(String))\nbound(ClassShape(:Emp) |> rebind(:Emp => NativeShape(Number)),\n      ClassShape(:Emp) |> rebind(:Emp => NativeShape(String)))\n#-> ClassShape(:Emp) |> rebind(:Emp => AnyShape())\nibound(ClassShape(:Emp) |> rebind(:Emp => NativeShape(Number)),\n       ClassShape(:Emp) |> rebind(:Emp => NativeShape(String)))\n#-> ClassShape(:Emp) |> rebind(:Emp => NoneShape())\n\nbound(BlockShape(Int), BlockShape(Number))\n#-> BlockShape(NativeShape(Number))\nibound(BlockShape(Int), BlockShape(Number))\n#-> BlockShape(NativeShape(Int))\n\nbound(TupleShape(:Emp, BlockShape(String)),\n      TupleShape(:Dept, BlockShape(String)))\n#-> TupleShape(AnyShape(), BlockShape(NativeShape(String)))\nibound(TupleShape(:Emp, BlockShape(String)),\n       TupleShape(:Dept, BlockShape(String)))\n#-> TupleShape(NoneShape(), BlockShape(NativeShape(String)))\n\nbound(InputShape(Int, [:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true),\n      InputShape(Number, [:X => OutputShape(Int)]))\n#=>\nInputShape(NativeShape(Number), [:X => OutputShape(NativeShape(Int), OPT)])\n=#\nibound(InputShape(Int, [:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true),\n       InputShape(Number, [:X => OutputShape(Int)]))\n#=>\nInputShape(NativeShape(Int),\n           [:X => OutputShape(NativeShape(Int)),\n            :Y => OutputShape(NativeShape(String))],\n           true)\n=#\n\nbound(OutputShape(String, OPT), OutputShape(String, PLU))\n#-> OutputShape(NativeShape(String), OPT|PLU)\nibound(OutputShape(String, OPT), OutputShape(String, PLU))\n#-> OutputShape(NativeShape(String))\n\nbound(RecordShape(OutputShape(Int, PLU),\n                  OutputShape(String, OPT)),\n      RecordShape(OutputShape(Number),\n                  OutputShape(:Emp, OPT|PLU)))\n#=>\nRecordShape(OutputShape(NativeShape(Number), PLU),\n            OutputShape(AnyShape(), OPT|PLU))\n=#\nibound(RecordShape(OutputShape(Int, PLU),\n                   OutputShape(String, OPT)),\n       RecordShape(OutputShape(Number),\n                   OutputShape(:Emp, OPT|PLU)))\n#=>\nRecordShape(OutputShape(NativeShape(Int)), OutputShape(NoneShape(), OPT))\n=#For decorated shapes, incompatible decoration constraints are replaced with nothing.bound(NativeShape(String) |> decorate(:show => false, :tag => :name),\n      NativeShape(String) |> decorate(:hide => true, :tag => :name))\n#-> NativeShape(String) |> decorate(:tag => :name)\n\nibound(NativeShape(String) |> decorate(:show => false, :tag => :name),\n       NativeShape(String) |> decorate(:hide => true, :tag => :name))\n#-> NativeShape(String) |> decorate(:hide => true, :show => false, :tag => :name)\n\nbound(NativeShape(String) |> decorate(:tag => :position),\n      NativeShape(Number) |> decorate(:tag => :salary))\n#-> AnyShape()\n\nibound(NativeShape(String) |> decorate(:tag => :position),\n       NativeShape(Number) |> decorate(:tag => :salary))\n#-> NoneShape() |> decorate(:tag => nothing)\n\nbound(NativeShape(Int),\n      NativeShape(Number) |> decorate(:tag => :salary))\n#-> NativeShape(Number)\n\nibound(NativeShape(Int),\n       NativeShape(Number) |> decorate(:tag => :salary))\n#-> NativeShape(Int) |> decorate(:tag => :salary)"
},

{
    "location": "shapes/#Query-signature-1",
    "page": "Type System",
    "title": "Query signature",
    "category": "section",
    "text": "The signature of a query is a pair of an InputShape object and an OutputShape object.sig = Signature(InputShape(:Dept),\n                OutputShape(RecordShape(OutputShape(String) |> decorate(:tag => :name),\n                                        OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :employee))))\n#-> Dept -> (name => String[1 .. 1], employee => Emp[0 .. ∞])[1 .. 1]Different components of the signature can be easily extracted.shape(sig)\n#=>\nOutputShape(RecordShape(\n                OutputShape(NativeShape(String) |> decorate(:tag => :name)),\n                OutputShape(ClassShape(:Emp) |> decorate(:tag => :employee),\n                            OPT|PLU)))\n=#\n\nishape(sig)\n#-> InputShape(ClassShape(:Dept))\n\ndomain(sig)\n#=>\nRecordShape(OutputShape(NativeShape(String) |> decorate(:tag => :name)),\n            OutputShape(ClassShape(:Emp) |> decorate(:tag => :employee),\n                        OPT|PLU))\n=#\n\nmode(sig)\n#-> OutputMode()\n\nidomain(sig)\n#-> ClassShape(:Dept)\n\nimode(sig)\n#-> InputMode()"
},

{
    "location": "queries/#",
    "page": "Query Execution Engine",
    "title": "Query Execution Engine",
    "category": "page",
    "text": ""
},

{
    "location": "queries/#Query-Execution-Engine-1",
    "page": "Query Execution Engine",
    "title": "Query Execution Engine",
    "category": "section",
    "text": ""
},

{
    "location": "queries/#Overview-1",
    "page": "Query Execution Engine",
    "title": "Overview",
    "category": "section",
    "text": "In DataKnots, structured data is stored in a column-oriented format, serialized using specialized composite vector types.  Consequently, operations on data take the form of vectorized functions.Module DataKnots.Queries exports an interface of vectorized transformations called Query and provives a rich library of query primitives and combinators.using DataKnots.Vectors\nusing DataKnots.Queries"
},

{
    "location": "queries/#Lifting-1",
    "page": "Query Execution Engine",
    "title": "Lifting",
    "category": "section",
    "text": "Lifting lets us convert a scalar function to a query.Any unary scalar function could be lifted to a vectorized form.  Consider, for example, function titlecase(), which transforms the input string by capitalizing the first letter of each word and converting every other character to lowercase.titlecase(\"JEFFERY A\")      #-> \"Jeffery A\"This function can be converted to a query using the lift operator.q = lift(titlecase)\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [\"Jeffery A\", \"James A\", \"Terry A\"]If a scalar function takes several arguments, it could be lifted to a query on TupleVector instances.  For example, the comparison operator >, which maps a pair of integer values to a Boolean value, could be lifted to a query lift_to_tuple(>) that transforms a TupleVector instance with two integer columns to a Boolean vector.q = lift_to_tuple(>)\nq(@VectorTree (Int, Int) [260004 200000; 185364 200000; 170112 200000])\n#-> Bool[true, false, false]In a similar manner, a function with a vector argument can be converted to a query on BlockVector instances.  For example, function length(), which returns the length of a vector, could be lifted to a query lift_to_block(length) that transforms a block vector to an integer vector containing block lengths.q = lift_to_block(length)\nq(@VectorTree [String] [[\"JEFFERY A\", \"NANCY A\"], [\"JAMES A\"]])\n#-> [2, 1]A constant value could be lifted to a query as well.  The lifted constant maps any input vector to a vector of constant values.q = lift_const(200000)\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [200000, 200000, 200000]"
},

{
    "location": "queries/#Query-interface-1",
    "page": "Query Execution Engine",
    "title": "Query interface",
    "category": "section",
    "text": "Functions such as lift(), lift_to_tuple(), and many others return a Query object.  The Query interface represents a vectorized data transformation that maps an input vector to an output vector of the same length.Functions that take one or more Query instances as arguments and return a new Query object as the result are called combinators.  Combinators are used to assemble elementary queries into complex query expressions.For example, composition combinator chain_of() assembles a series of queries into a sequential composition, which transforms the input vector by sequentially applying the given queries.q = chain_of(lift(split), lift(first), lift(titlecase))\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> [\"Jeffery\", \"James\", \"Terry\"]Another combinator, tuple constructor tuple_of() assembles a series of queries into a parallel composition.  It outputs a TupleVector instance, which columns are generated by applying the given queries to the input vector.q = tuple_of(lift(titlecase), lift(last))\nq([\"JEFFERY A\", \"JAMES A\", \"TERRY A\"])\n#-> @VectorTree (String, Char) [(\"Jeffery A\", \'A\'), (\"James A\", \'A\'), (\"Terry A\", \'A\')]An individual column of a TupleVector instance could be extracted using a column() query.q = column(:salary)\nq(@VectorTree (name=String, salary=Int) [(\"JEFFERY A\", 101442), (\"JAMES A\", 103350), (\"TERRY A\", 93354)])\n#-> [101442, 103350, 93354]"
},

{
    "location": "queries/#DataKnots.Queries.Query",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.Query",
    "category": "type",
    "text": "Query(op, args...)\n\nA query represents a vectorized data transformation.\n\nParameter op is a function that performs the transformation. It is invoked with the following arguments:\n\nop(rt::Runtime, input::AbstractVector, args...)\n\nIt must return the output vector of the same length as the input vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.QueryError",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.QueryError",
    "category": "type",
    "text": "QueryError(msg, ::Query, ::AbstractVector)\n\nException thrown when a query gets unexpected input.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.any_block-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.any_block",
    "category": "method",
    "text": "any_block()\n\nChecks if there is one true value in a block of Bool values.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.as_block-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.as_block",
    "category": "method",
    "text": "as_block()\n\nWraps input values to one-element blocks.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.chain_of-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.chain_of",
    "category": "method",
    "text": "chain_of(q₁, q₂ … qₙ)\n\nSequentially applies q₁, q₂ … qₙ.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.correlate-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.correlate",
    "category": "method",
    "text": "correlate()\n\nCorrelates two vectors of key-value pairs.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.count_block-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.count_block",
    "category": "method",
    "text": "count_block()\n\nMaps a block vector to a vector of block lengths.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.csv_parse-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.csv_parse",
    "category": "method",
    "text": "csv_parse(separator=\',\', quoting=\'\"\', labels=Symbol[], header=true)\n\nParses CSV-formatted text into a table.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.decode_missing-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.decode_missing",
    "category": "method",
    "text": "decode_missing()\n\nDecodes a vector with missing elements as a block vector, where missing elements are converted to empty blocks.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.decode_tuple-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.decode_tuple",
    "category": "method",
    "text": "decode_tuple()\n\nDecodes a vector with tuple elements as a tuple vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.decode_vector-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.decode_vector",
    "category": "method",
    "text": "decode_vector()\n\nDecodes a vector with vector elements as a block vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.designate-Tuple{DataKnots.Queries.Query,DataKnots.Shapes.Signature}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.designate",
    "category": "method",
    "text": "designate(::Query, ::Signature) -> Query\ndesignate(::Query, ::InputShape, ::OutputShape) -> Query\nq::Query |> designate(::Signature) -> Query\nq::Query |> designate(::InputShape, ::OutputShape) -> Query\n\nSets the query signature.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.flat_block-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.flat_block",
    "category": "method",
    "text": "flat_block()\n\nFlattens a nested block vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.flat_tuple-Tuple{Union{Int64, Symbol}}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.flat_tuple",
    "category": "method",
    "text": "flat_tuple(lbl)\n\nFlattens a nested tuple vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.group_by",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.group_by",
    "category": "function",
    "text": "group_by()\n\nDiscriminates a sequence of key-value pairs.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.in_block-Tuple{Any}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.in_block",
    "category": "method",
    "text": "in_block(q)\n\nUsing q, transfors the elements of the input blocks.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.in_tuple-Tuple{Union{Int64, Symbol},Any}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.in_tuple",
    "category": "method",
    "text": "in_tuple(lbl, q)\n\nUsing q, transforms the specified column of a tuple vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.json_parse-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.json_parse",
    "category": "method",
    "text": "json_parse()\n\nParses JSON-formatted text.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.lift-Tuple{Any}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.lift",
    "category": "method",
    "text": "lift(f) -> Query\n\nf is any scalar unary function.\n\nThe query applies f to each element of the input vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.lift_block-Tuple{Any}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.lift_block",
    "category": "method",
    "text": "lift_block(block)\n\nProduces a block vector filled with the given block.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.lift_const-Tuple{Any}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.lift_const",
    "category": "method",
    "text": "lift_const(val)\n\nProduces a vector filled with the given value.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.lift_null-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.lift_null",
    "category": "method",
    "text": "lift_null()\n\nProduces a block vector of empty blocks.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.lift_to_block-Tuple{Any}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.lift_to_block",
    "category": "method",
    "text": "lift_to_block(f)\nlift_to_block(f, default)\n\nf is a function that takes a vector argument.\n\nApplies a function f that takes a vector argument to each block of a block vector.  When specified, default is used instead of applying f to an empty block.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.lift_to_block_tuple-Tuple{Any}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.lift_to_block_tuple",
    "category": "method",
    "text": "lift_to_block_tuple(f)\n\nLifts an n-ary function to a tuple vector with block columns.  Applies the function to every combinations of values from adjacent blocks.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.lift_to_tuple-Tuple{Any}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.lift_to_tuple",
    "category": "method",
    "text": "lift_to_tuple(f) -> Query\n\nf is an n-ary function.\n\nThe query applies f to each row of an n-tuple vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.optimize-Tuple{DataKnots.Queries.Query}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.optimize",
    "category": "method",
    "text": "optimize(::Query)::Query\n\nRewrites the query to make it more effective.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.pass-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.pass",
    "category": "method",
    "text": "pass()\n\nIdentity map.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.pull_block-Tuple{Any}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.pull_block",
    "category": "method",
    "text": "pull_block(lbl)\n\nConverts a tuple with a block column to a block of tuples.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.pull_every_block-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.pull_every_block",
    "category": "method",
    "text": "pull_every_block()\n\nConverts a tuple vector with block columns to a block vector over a tuple vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.sieve-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.sieve",
    "category": "method",
    "text": "sieve()\n\nFilters the vector of pairs by the second column.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.sort_by",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.sort_by",
    "category": "function",
    "text": "sort_by()\n\nSorts the vector of key-value pairs.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.sort_it",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.sort_it",
    "category": "function",
    "text": "sort_it()\n\nSorts the input vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.store-Tuple{Symbol}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.store",
    "category": "method",
    "text": "store(name)\n\nConverts the input vector to an index.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.take_by",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.take_by",
    "category": "function",
    "text": "take_by(N)\n\nKeeps the first N elements in a block.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.tuple_of-Tuple",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.tuple_of",
    "category": "method",
    "text": "tuple_of(q₁, q₂ … qₙ)\n\nCombines the output of q₁, q₂ … qₙ into an n-tuple vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Queries.xml_parse-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Queries.xml_parse",
    "category": "method",
    "text": "xml_parse()\n\nParses XML-formatted text.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Vectors.column-Tuple{Union{Int64, Symbol}}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Vectors.column",
    "category": "method",
    "text": "column(lbl)\n\nExtracts the specified column of a tuple vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#DataKnots.Vectors.dereference-Tuple{}",
    "page": "Query Execution Engine",
    "title": "DataKnots.Vectors.dereference",
    "category": "method",
    "text": "dereference()\n\nDereferences an index vector.\n\n\n\n\n\n"
},

{
    "location": "queries/#API-Reference-1",
    "page": "Query Execution Engine",
    "title": "API Reference",
    "category": "section",
    "text": "Modules = [DataKnots.Queries]\nPrivate = false"
},

{
    "location": "queries/#Test-Suite-1",
    "page": "Query Execution Engine",
    "title": "Test Suite",
    "category": "section",
    "text": ""
},

{
    "location": "queries/#Lifting-2",
    "page": "Query Execution Engine",
    "title": "Lifting",
    "category": "section",
    "text": "Many vector operations can be generated by lifting.  For example, lift_const() generates a primitive operation that maps any input vector to the output vector of the same length filled with the given value.q = lift_const(200000)\n#-> lift_const(200000)\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [200000, 200000, 200000]Similarly, the output of lift_block() is a block vector filled with the given block.q = lift_block([\"POLICE\", \"FIRE\"])\n#-> lift_block([\"POLICE\", \"FIRE\"])\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [String] [[\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"]]A variant of lift_block() called lift_null() outputs a block vector with empty blocks.q = lift_null()\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [Union{}] [missing, missing, missing]Any scalar function could be lifted to a vector operation by applying it to each element of the input vector.q = lift(titlecase)\n#-> lift(titlecase)\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [\"Garry M\", \"Anthony R\", \"Dana A\"]Similarly, any scalar function of several arguments could be lifted to an operation on tuple vectors.q = lift_to_tuple(>)\n#-> lift_to_tuple(>)\n\nq(@VectorTree (Int, Int) [260004 200000; 185364 200000; 170112 200000])\n#-> Bool[true, false, false]It is also possible to apply a scalar function of several arguments to a tuple vector that has block vectors for its columns.  In this case, the function is applied to every combination of values from all the blocks on the same row.q = lift_to_block_tuple(>)\n\nq(@VectorTree ([Int], [Int]) [[260004, 185364, 170112] 200000; missing 200000; [202728, 197736] [200000, 200000]])\n#-> @VectorTree [Bool] [Bool[true, false, false], missing, Bool[true, true, false, false]]Any function that takes a vector argument can be lifted to an operation on block vectors.q = lift_to_block(length)\n#-> lift_to_block(length)\n\nq(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]])\n#-> [3, 2]Some vector functions may expect a non-empty vector as an argument.  In this case, we should provide the value to replace empty blocks.q = lift_to_block(maximum, missing)\n#-> lift_to_block(maximum, missing)\n\nq(@VectorTree [Int] [[260004, 185364, 170112], [], [202728, 197736]])\n#-> Union{Missing, Int}[260004, missing, 202728]"
},

{
    "location": "queries/#Decoding-vectors-1",
    "page": "Query Execution Engine",
    "title": "Decoding vectors",
    "category": "section",
    "text": "Any vector of tuples can be converted to a tuple vector.q = decode_tuple()\n#-> decode_tuple()\n\nq([(\"GARRY M\", 260004), (\"ANTHONY R\", 185364), (\"DANA A\", 170112)]) |> display\n#=>\nTupleVector of 3 × (String, Int):\n (\"GARRY M\", 260004)\n (\"ANTHONY R\", 185364)\n (\"DANA A\", 170112)\n=#Vectors of named tuples are also supported.q([(name=\"GARRY M\", salary=260004), (name=\"ANTHONY R\", salary=185364), (name=\"DANA A\", salary=170112)]) |> display\n#=>\nTupleVector of 3 × (name = String, salary = Int):\n (name = \"GARRY M\", salary = 260004)\n (name = \"ANTHONY R\", salary = 185364)\n (name = \"DANA A\", salary = 170112)\n=#A vector of vector objects can be converted to a block vector.q = decode_vector()\n#-> decode_vector()\n\nq([[260004, 185364, 170112], Int[], [202728, 197736]])\n#-> @VectorTree [Int] [[260004, 185364, 170112], missing, [202728, 197736]]Similarly, a vector containing missing values can be converted to a block vector with zero- and one-element blocks.q = decode_missing()\n#-> decode_missing()\n\nq([260004, 185364, 170112, missing, 202728, 197736])\n#-> @VectorTree [Int] [260004, 185364, 170112, missing, 202728, 197736]"
},

{
    "location": "queries/#Tuple-vectors-1",
    "page": "Query Execution Engine",
    "title": "Tuple vectors",
    "category": "section",
    "text": "To create a tuple vector, we use the combinator tuple_of(). Its arguments are the functions that generate the columns of the tuple.q = tuple_of(:title => lift(titlecase), :last => lift(last))\n#-> tuple_of([:title, :last], [lift(titlecase), lift(last)])\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"]) |> display\n#=>\nTupleVector of 3 × (title = String, last = Char):\n (title = \"Garry M\", last = \'M\')\n (title = \"Anthony R\", last = \'R\')\n (title = \"Dana A\", last = \'A\')\n=#To extract a column of a tuple vector, we use the primitive column().  It accepts either the column position or the column name.q = column(1)\n#-> column(1)\n\nq(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112])\n#-> [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]\n\nq = column(:salary)\n#-> column(:salary)\n\nq(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112])\n#-> [260004, 185364, 170112]Finally, we can apply an arbitrary transformation to a selected column of a tuple vector.q = in_tuple(:name, lift(titlecase))\n#-> in_tuple(:name, lift(titlecase))\n\nq(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]) |> display\n#=>\nTupleVector of 3 × (name = String, salary = Int):\n (name = \"Garry M\", salary = 260004)\n (name = \"Anthony R\", salary = 185364)\n (name = \"Dana A\", salary = 170112)\n=#"
},

{
    "location": "queries/#Block-vectors-1",
    "page": "Query Execution Engine",
    "title": "Block vectors",
    "category": "section",
    "text": "Primitive as_block() wraps the elements of the input vector to one-element blocks.q = as_block()\n#-> as_block()\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [String] [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]In the opposite direction, primitive flat_block() flattens a block vector with block elements.q = flat_block()\n#-> flat_block()\n\nq(@VectorTree [[String]] [[[\"GARRY M\"], [\"ANTHONY R\", \"DANA A\"]], [missing, [\"JOSE S\"], [\"CHARLES S\"]]])\n#-> @VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]]Finally, we can apply an arbitrary transformation to every element of a block vector.q = in_block(lift(titlecase))\n#-> in_block(lift(titlecase))\n\nq(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]])\n#-> @VectorTree [String] [[\"Garry M\", \"Anthony R\", \"Dana A\"], [\"Jose S\", \"Charles S\"]]The pull_block() primitive converts a tuple vector with a block column to a block vector of tuples.q = pull_block(1)\n#-> pull_block(1)\n\nq(@VectorTree ([Int], [Int]) [\n    [260004, 185364, 170112]    200000\n    missing                     200000\n    [202728, 197736]            [200000, 200000]]\n) |> display\n#=>\nBlockVector of 3 × [(Int, [Int])]:\n [(260004, 200000), (185364, 200000), (170112, 200000)]\n missing\n [(202728, [200000, 200000]), (197736, [200000, 200000])]\n=#It is also possible to pull all block columns from a tuple vector.q = pull_every_block()\n#-> pull_every_block()\n\nq(@VectorTree ([Int], [Int]) [\n    [260004, 185364, 170112]    200000\n    missing                     200000\n    [202728, 197736]            [200000, 200000]]\n) |> display\n#=>\nBlockVector of 3 × [(Int, Int)]:\n [(260004, 200000), (185364, 200000), (170112, 200000)]\n missing\n [(202728, 200000), (202728, 200000), (197736, 200000), (197736, 200000)]\n=#"
},

{
    "location": "queries/#Index-vectors-1",
    "page": "Query Execution Engine",
    "title": "Index vectors",
    "category": "section",
    "text": "An index vector could be dereferenced using the dereference() primitive.q = dereference()\n#-> dereference()\n\nq(@VectorTree &DEPT [1, 1, 1, 2] where {DEPT = [\"POLICE\", \"FIRE\"]})\n#-> [\"POLICE\", \"POLICE\", \"POLICE\", \"FIRE\"]"
},

{
    "location": "queries/#Composition-1",
    "page": "Query Execution Engine",
    "title": "Composition",
    "category": "section",
    "text": "We can compose a sequence of transformations using the chain_of() combinator.q = chain_of(\n        column(:employee),\n        in_block(lift(titlecase)))\n#-> chain_of(column(:employee), in_block(lift(titlecase)))\n\nq(@VectorTree (department = String, employee = [String]) [\n    \"POLICE\"    [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]\n    \"FIRE\"      [\"JOSE S\", \"CHARLES S\"]])\n#-> @VectorTree [String] [[\"Garry M\", \"Anthony R\", \"Dana A\"], [\"Jose S\", \"Charles S\"]]The empty chain chain_of() has an alias pass().q = pass()\n#-> pass()\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]"
},

{
    "location": "combinators/#",
    "page": "Query Algebra",
    "title": "Query Algebra",
    "category": "page",
    "text": ""
},

{
    "location": "combinators/#Query-Algebra-1",
    "page": "Query Algebra",
    "title": "Query Algebra",
    "category": "section",
    "text": "using DataKnots\nusing DataKnots.Combinators\n\nF = (It .+ 4) >> (It .* 6)\n#-> (It .+ 4) >> It .* 6\n\nquery(3, F)\n#=>\n│ DataKnot │\n├──────────┤\n│       42 │\n=#\n\nprepare(DataKnot(3) >> F)\n#=>\nchain_of(lift_block([3]),\n         in_block(chain_of(tuple_of([], [as_block(), lift_block([4])]),\n                           lift_to_block_tuple(+))),\n         flat_block(),\n         in_block(chain_of(tuple_of([], [as_block(), lift_block([6])]),\n                           lift_to_block_tuple(*))),\n         flat_block())\n=#\n\nusedb!(\n    @VectorTree (name = [String], employee = [(name = [String], salary = [Int])]) [\n        \"POLICE\"    [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n        \"FIRE\"      [\"JOSE S\" 202728; \"CHARLES S\" 197736]\n    ])\n#=>\n  │ DataKnot                                                   │\n  │ name    employee                                           │\n──┼────────────────────────────────────────────────────────────┤\n1 │ POLICE  GARRY M, 260004; ANTHONY R, 185364; DANA A, 170112 │\n2 │ FIRE    JOSE S, 202728; CHARLES S, 197736                  │\n=#\n\nquery(Field(:name))\n#=>\n  │ name   │\n──┼────────┤\n1 │ POLICE │\n2 │ FIRE   │\n=#\n\nquery(It.name)\n#=>\n  │ name   │\n──┼────────┤\n1 │ POLICE │\n2 │ FIRE   │\n=#\n\n@query name\n#=>\n  │ name   │\n──┼────────┤\n1 │ POLICE │\n2 │ FIRE   │\n=#\n\nquery(Field(:employee) >> Field(:salary))\n#=>\n  │ salary │\n──┼────────┤\n1 │ 260004 │\n2 │ 185364 │\n3 │ 170112 │\n4 │ 202728 │\n5 │ 197736 │\n=#\n\nquery(It.employee.salary)\n#=>\n  │ salary │\n──┼────────┤\n1 │ 260004 │\n2 │ 185364 │\n3 │ 170112 │\n4 │ 202728 │\n5 │ 197736 │\n=#\n\n@query employee.salary\n#=>\n  │ salary │\n──┼────────┤\n1 │ 260004 │\n2 │ 185364 │\n3 │ 170112 │\n4 │ 202728 │\n5 │ 197736 │\n=#\n\nquery(Count(It.employee))\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        3 │\n2 │        2 │\n=#\n\n@query count(employee)\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        3 │\n2 │        2 │\n=#\n\nquery(Count)\n#=>\n│ DataKnot │\n├──────────┤\n│        2 │\n=#\n\n@query count()\n#=>\n│ DataKnot │\n├──────────┤\n│        2 │\n=#\n\nquery(Count(It.employee) >> Max)\n#=>\n│ DataKnot │\n├──────────┤\n│        3 │\n=#\n\n@query count(employee).max()\n#=>\n│ DataKnot │\n├──────────┤\n│        3 │\n=#\n\nquery(It.employee >> Filter(It.salary .> 200000))\n#=>\n  │ employee        │\n  │ name     salary │\n──┼─────────────────┤\n1 │ GARRY M  260004 │\n2 │ JOSE S   202728 │\n=#\n\n@query employee.filter(salary>200000)\n#=>\n  │ employee        │\n  │ name     salary │\n──┼─────────────────┤\n1 │ GARRY M  260004 │\n2 │ JOSE S   202728 │\n=#\n\n@query begin\n    employee\n    filter(salary>200000)\nend\n#=>\n  │ employee        │\n  │ name     salary │\n──┼─────────────────┤\n1 │ GARRY M  260004 │\n2 │ JOSE S   202728 │\n=#\n\nquery(Count(It.employee) .> 2)\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │     true │\n2 │    false │\n=#\n\n@query count(employee)>2\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │     true │\n2 │    false │\n=#\n\nquery(Filter(Count(It.employee) .> 2))\n#=>\n  │ DataKnot                                                   │\n  │ name    employee                                           │\n──┼────────────────────────────────────────────────────────────┤\n1 │ POLICE  GARRY M, 260004; ANTHONY R, 185364; DANA A, 170112 │\n=#\n\n@query filter(count(employee)>2)\n#=>\n  │ DataKnot                                                   │\n  │ name    employee                                           │\n──┼────────────────────────────────────────────────────────────┤\n1 │ POLICE  GARRY M, 260004; ANTHONY R, 185364; DANA A, 170112 │\n=#\n\nquery(Filter(Count(It.employee) .> 2) >> Count)\n#=>\n│ DataKnot │\n├──────────┤\n│        1 │\n=#\n\n@query begin\n    filter(count(employee)>2)\n    count()\nend\n#=>\n│ DataKnot │\n├──────────┤\n│        1 │\n=#\n\nquery(Record(It.name, :size => Count(It.employee)))\n#=>\n  │ DataKnot     │\n  │ name    size │\n──┼──────────────┤\n1 │ POLICE     3 │\n2 │ FIRE       2 │\n=#\n\n@query record(name, size => count(employee))\n#=>\n  │ DataKnot     │\n  │ name    size │\n──┼──────────────┤\n1 │ POLICE     3 │\n2 │ FIRE       2 │\n=#\n\nquery(It.employee >> Filter(It.salary .> It.S),\n      S=200000)\n#=>\n  │ employee        │\n  │ name     salary │\n──┼─────────────────┤\n1 │ GARRY M  260004 │\n2 │ JOSE S   202728 │\n=#\n\nquery(\n    Given(:S => Max(It.employee.salary),\n        It.employee >> Filter(It.salary .== It.S)))\n#=>\n  │ employee        │\n  │ name     salary │\n──┼─────────────────┤\n1 │ GARRY M  260004 │\n2 │ JOSE S   202728 │\n=#\n\n@query begin\n    employee\n    filter(salary>S)\nend where { S = 200000 }\n#=>\n  │ employee        │\n  │ name     salary │\n──┼─────────────────┤\n1 │ GARRY M  260004 │\n2 │ JOSE S   202728 │\n=#\n\n@query given(\n        S => max(employee.salary),\n        employee.filter(salary==S))\n#=>\n  │ employee        │\n  │ name     salary │\n──┼─────────────────┤\n1 │ GARRY M  260004 │\n2 │ JOSE S   202728 │\n=#\n\nquery(It.employee.salary >> Sort)\n#=>\n  │ salary │\n──┼────────┤\n1 │ 170112 │\n2 │ 185364 │\n3 │ 197736 │\n4 │ 202728 │\n5 │ 260004 │\n=#\n\n@query employee.salary.sort()\n#=>\n  │ salary │\n──┼────────┤\n1 │ 170112 │\n2 │ 185364 │\n3 │ 197736 │\n4 │ 202728 │\n5 │ 260004 │\n=#\n\nquery(It.employee.salary >> Desc >> Sort)\n#=>\n  │ salary │\n──┼────────┤\n1 │ 260004 │\n2 │ 202728 │\n3 │ 197736 │\n4 │ 185364 │\n5 │ 170112 │\n=#\n\n@query employee.salary.desc().sort()\n#=>\n  │ salary │\n──┼────────┤\n1 │ 260004 │\n2 │ 202728 │\n3 │ 197736 │\n4 │ 185364 │\n5 │ 170112 │\n=#\n\nquery(It.employee >> Sort(It.salary))\n#=>\n  │ employee          │\n  │ name       salary │\n──┼───────────────────┤\n1 │ DANA A     170112 │\n2 │ ANTHONY R  185364 │\n3 │ CHARLES S  197736 │\n4 │ JOSE S     202728 │\n5 │ GARRY M    260004 │\n=#\n\n@query employee.sort(salary)\n#=>\n  │ employee          │\n  │ name       salary │\n──┼───────────────────┤\n1 │ DANA A     170112 │\n2 │ ANTHONY R  185364 │\n3 │ CHARLES S  197736 │\n4 │ JOSE S     202728 │\n5 │ GARRY M    260004 │\n=#\n\nquery(It.employee >> Sort(It.salary >> Desc))\n#=>\n  │ employee          │\n  │ name       salary │\n──┼───────────────────┤\n1 │ GARRY M    260004 │\n2 │ JOSE S     202728 │\n3 │ CHARLES S  197736 │\n4 │ ANTHONY R  185364 │\n5 │ DANA A     170112 │\n=#\n\n@query employee.sort(salary.desc())\n#=>\n  │ employee          │\n  │ name       salary │\n──┼───────────────────┤\n1 │ GARRY M    260004 │\n2 │ JOSE S     202728 │\n3 │ CHARLES S  197736 │\n4 │ ANTHONY R  185364 │\n5 │ DANA A     170112 │\n=#\n\nquery(It.employee.salary >> Take(3))\n#=>\n  │ salary │\n──┼────────┤\n1 │ 260004 │\n2 │ 185364 │\n3 │ 170112 │\n=#\n\nquery(It.employee.salary >> Drop(3))\n#=>\n  │ salary │\n──┼────────┤\n1 │ 202728 │\n2 │ 197736 │\n=#\n\nquery(It.employee.salary >> Take(-3))\n#=>\n  │ salary │\n──┼────────┤\n1 │ 260004 │\n2 │ 185364 │\n=#\n\nquery(It.employee.salary >> Drop(-3))\n#=>\n  │ salary │\n──┼────────┤\n1 │ 170112 │\n2 │ 202728 │\n3 │ 197736 │\n=#\n\nquery(It.employee.salary >> Take(Count(thedb() >> It.employee) .÷ 2))\n#=>\n  │ salary │\n──┼────────┤\n1 │ 260004 │\n2 │ 185364 │\n=#\n\nquery(It.employee >> Group(:grade => It.salary .÷ 100000))\n#=>\n  │ DataKnot                                                    │\n  │ grade  employee                                             │\n──┼─────────────────────────────────────────────────────────────┤\n1 │     1  ANTHONY R, 185364; DANA A, 170112; CHARLES S, 197736 │\n2 │     2  GARRY M, 260004; JOSE S, 202728                      │\n=#\n\n@query employee.group(grade => salary ÷ 100000)\n#=>\n  │ DataKnot                                                    │\n  │ grade  employee                                             │\n──┼─────────────────────────────────────────────────────────────┤\n1 │     1  ANTHONY R, 185364; DANA A, 170112; CHARLES S, 197736 │\n2 │     2  GARRY M, 260004; JOSE S, 202728                      │\n=#\n\n@query begin\n    employee\n    group(grade => salary ÷ 100000)\n    record(\n        grade,\n        size => count(employee),\n        low => min(employee.salary),\n        high => max(employee.salary),\n        avg => mean(employee.salary),\n        employee.salary.sort())\nend\n#=>\n  │ DataKnot                                                      │\n  │ grade  size  low     high    avg       salary                 │\n──┼───────────────────────────────────────────────────────────────┤\n1 │     1     3  170112  197736  184404.0  170112; 185364; 197736 │\n2 │     2     2  202728  260004  231366.0  202728; 260004         │\n=#\n\nusedb!(\n    @VectorTree (department = [(name = [String],)],\n                 employee = [(name = [String], department = [String], position = [String], salary = [Int])]) [\n        (department = [\n            \"POLICE\"\n            \"FIRE\"\n         ],\n         employee = [\n            \"JAMES A\"   \"POLICE\"    \"SERGEANT\"      110370\n            \"MICHAEL W\" \"POLICE\"    \"INVESTIGATOR\"  63276\n            \"STEVEN S\"  \"FIRE\"      \"CAPTAIN\"       123948\n            \"APRIL W\"   \"FIRE\"      \"PARAMEDIC\"     54114\n        ])\n    ]\n)\n#=>\n│ DataKnot                                                                     …\n│ department    employee                                                       …\n├──────────────────────────────────────────────────────────────────────────────…\n│ POLICE; FIRE  JAMES A, POLICE, SERGEANT, 110370; MICHAEL W, POLICE, INVESTIGA…\n=#\n\n@query begin\n    record(\n        department.graft(name, employee.index(department)),\n        employee.graft(department, department.unique_index(name)))\nend\n#=>\n│ DataKnot                                                                     …\n│ department                                                                   …\n├──────────────────────────────────────────────────────────────────────────────…\n│ POLICE, JAMES A, POLICE, SERGEANT, 110370; MICHAEL W, POLICE, INVESTIGATOR, 6…\n=#\n\n@query begin\n    record(\n        department.graft(name, employee.index(department)),\n        employee.graft(department, department.unique_index(name)))\n    employee.record(name, department_name => department.name)\nend\n#=>\n  │ DataKnot                   │\n  │ name       department_name │\n──┼────────────────────────────┤\n1 │ JAMES A    POLICE          │\n2 │ MICHAEL W  POLICE          │\n3 │ STEVEN S   FIRE            │\n4 │ APRIL W    FIRE            │\n=#\n\n@query begin\n    record(\n        department.graft(name, employee.index(department)),\n        employee.graft(department, department.unique_index(name)))\n    department.record(name, size => count(employee), max_salary => max(employee.salary))\nend\n#=>\n  │ DataKnot                 │\n  │ name    size  max_salary │\n──┼──────────────────────────┤\n1 │ POLICE     2      110370 │\n2 │ FIRE       2      123948 │\n=#\n\n@query begin\n    weave(\n        department.graft(name, employee.index(department)),\n        employee.graft(department, department.unique_index(name)))\nend\n#=>\n│ DataKnot                       │\n│ department  employee           │\n├────────────────────────────────┤\n│ [1]; [2]    [1]; [2]; [3]; [4] │\n=#\n\n@query begin\n    weave(\n        department.graft(name, employee.index(department)),\n        employee.graft(department, department.unique_index(name)))\n    employee.record(name, department_name => department.name)\nend\n#=>\n  │ DataKnot                   │\n  │ name       department_name │\n──┼────────────────────────────┤\n1 │ JAMES A    POLICE          │\n2 │ MICHAEL W  POLICE          │\n3 │ STEVEN S   FIRE            │\n4 │ APRIL W    FIRE            │\n=#\n\n@query begin\n    weave(\n        department.graft(name, employee.index(department)),\n        employee.graft(department, department.unique_index(name)))\n    department.record(name, size => count(employee), max_salary => max(employee.salary))\nend\n#=>\n  │ DataKnot                 │\n  │ name    size  max_salary │\n──┼──────────────────────────┤\n1 │ POLICE     2      110370 │\n2 │ FIRE       2      123948 │\n=#\n\n@query begin\n    weave(\n        department.graft(name, employee.index(department)),\n        employee.graft(department, department.unique_index(name)))\n    department\n    employee\n    department\n    employee\n    name\nend\n#=>\n  │ name      │\n──┼───────────┤\n1 │ JAMES A   │\n2 │ MICHAEL W │\n3 │ JAMES A   │\n4 │ MICHAEL W │\n5 │ STEVEN S  │\n6 │ APRIL W   │\n7 │ STEVEN S  │\n8 │ APRIL W   │\n=#\n\nusedb!(\n    @VectorTree (department = [&DEPT], employee = [&EMP]) [\n        [1, 2]  [1, 2, 3, 4]\n    ] where {\n        DEPT = @VectorTree (name = [String], employee = [&EMP]) [\n            \"POLICE\"    [1, 2]\n            \"FIRE\"      [3, 4]\n        ]\n        ,\n        EMP = @VectorTree (name = [String], department = [&DEPT], position = [String], salary = [Int]) [\n            \"JAMES A\"   1   \"SERGEANT\"      110370\n            \"MICHAEL W\" 1   \"INVESTIGATOR\"  63276\n            \"STEVEN S\"  2   \"CAPTAIN\"       123948\n            \"APRIL W\"   2   \"PARAMEDIC\"     54114\n        ]\n    }\n)\n#=>\n│ DataKnot                       │\n│ department  employee           │\n├────────────────────────────────┤\n│ [1]; [2]    [1]; [2]; [3]; [4] │\n=#\n\n@query department.name\n#=>\n  │ name   │\n──┼────────┤\n1 │ POLICE │\n2 │ FIRE   │\n=#\n\n@query department.employee.name\n#=>\n  │ name      │\n──┼───────────┤\n1 │ JAMES A   │\n2 │ MICHAEL W │\n3 │ STEVEN S  │\n4 │ APRIL W   │\n=#\n\n@query employee.department.name\n#=>\n  │ name   │\n──┼────────┤\n1 │ POLICE │\n2 │ POLICE │\n3 │ FIRE   │\n4 │ FIRE   │\n=#\n\n@query employee.position\n#=>\n  │ position     │\n──┼──────────────┤\n1 │ SERGEANT     │\n2 │ INVESTIGATOR │\n3 │ CAPTAIN      │\n4 │ PARAMEDIC    │\n=#\n\n@query count(department)\n#=>\n│ DataKnot │\n├──────────┤\n│        2 │\n=#\n\n@query max(employee.salary)\n#=>\n│ salary │\n├────────┤\n│ 123948 │\n=#\n\n@query department.count(employee)\n#=>\n  │ DataKnot │\n──┼──────────┤\n1 │        2 │\n2 │        2 │\n=#\n\n@query max(department.count(employee))\n#=>\n│ DataKnot │\n├──────────┤\n│        2 │\n=#\n\n@query employee.filter(salary>100000).name\n#=>\n  │ name     │\n──┼──────────┤\n1 │ JAMES A  │\n2 │ STEVEN S │\n=#\n\n@query begin\n    department\n    filter(count(employee)>=2)\n    count()\nend\n#=>\n│ DataKnot │\n├──────────┤\n│        2 │\n=#\n\n@query department.record(name, size => count(employee))\n#=>\n  │ DataKnot     │\n  │ name    size │\n──┼──────────────┤\n1 │ POLICE     2 │\n2 │ FIRE       2 │\n=#"
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
    "text": "using DataKnots\n\nusedb!(\n    @VectorTree (name = [String], employee = [(name = [String], salary = [Int])]) [\n        \"POLICE\"    [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n        \"FIRE\"      [\"JOSE S\" 202728; \"CHARLES S\" 197736]\n    ])\n#=>\n  │ DataKnot                                                   │\n  │ name    employee                                           │\n──┼────────────────────────────────────────────────────────────┤\n1 │ POLICE  GARRY M, 260004; ANTHONY R, 185364; DANA A, 170112 │\n2 │ FIRE    JOSE S, 202728; CHARLES S, 197736                  │\n=#\n\nquery(It.employee.name)\n#=>\n  │ name      │\n──┼───────────┤\n1 │ GARRY M   │\n2 │ ANTHONY R │\n3 │ DANA A    │\n4 │ JOSE S    │\n5 │ CHARLES S │\n=#\n\nTitleCase = Lift(s -> titlecase(s), It)\n\nquery(It.employee.name >> TitleCase)\n#=>\n  │ DataKnot  │\n──┼───────────┤\n1 │ Garry M   │\n2 │ Anthony R │\n3 │ Dana A    │\n4 │ Jose S    │\n5 │ Charles S │\n=#\n\n@query(titlecase(employee.name))\n#=>\n  │ DataKnot  │\n──┼───────────┤\n1 │ Garry M   │\n2 │ Anthony R │\n3 │ Dana A    │\n4 │ Jose S    │\n5 │ Charles S │\n=#\n\nSplit = Lift(s -> split(s), It)\n\nquery(It.employee.name >> Split)\n#=>\n   │ DataKnot │\n───┼──────────┤\n 1 │ GARRY    │\n 2 │ M        │\n 3 │ ANTHONY  │\n 4 │ R        │\n 5 │ DANA     │\n 6 │ A        │\n 7 │ JOSE     │\n 8 │ S        │\n 9 │ CHARLES  │\n10 │ S        │\n=#\n\nquery(:employee =>\n  It.employee >>\n    Record(:name =>\n      It.name >> Split))\n#=>\n  │ employee   │\n  │ name       │\n──┼────────────┤\n1 │ GARRY; M   │\n2 │ ANTHONY; R │\n3 │ DANA; A    │\n4 │ JOSE; S    │\n5 │ CHARLES; S │\n=#\n\nRepeat(V,N) = Lift((v,n) -> [v for i in 1:n], V, N)\nquery(Record(It.name, Repeat(\"Go!\", 3)))\n#=>\n  │ DataKnot              │\n  │ name    #2            │\n──┼───────────────────────┤\n1 │ POLICE  Go!; Go!; Go! │\n2 │ FIRE    Go!; Go!; Go! │\n=#"
},

]}
