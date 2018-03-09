var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "DataKnots.jl",
    "title": "DataKnots.jl",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#DataKnots.jl-1",
    "page": "DataKnots.jl",
    "title": "DataKnots.jl",
    "category": "section",
    "text": "DataKnots is a Julia library that implements a combinator-based embedded query language."
},

{
    "location": "index.html#Contents-1",
    "page": "DataKnots.jl",
    "title": "Contents",
    "category": "section",
    "text": "Pages = [\n    \"reference.md\",\n    \"test/index.md\",\n]"
},

{
    "location": "index.html#Index-1",
    "page": "DataKnots.jl",
    "title": "Index",
    "category": "section",
    "text": ""
},

{
    "location": "reference.html#",
    "page": "API Reference",
    "title": "API Reference",
    "category": "page",
    "text": ""
},

{
    "location": "reference.html#API-Reference-1",
    "page": "API Reference",
    "title": "API Reference",
    "category": "section",
    "text": ""
},

{
    "location": "test/index.html#",
    "page": "Test Suite",
    "title": "Test Suite",
    "category": "page",
    "text": ""
},

{
    "location": "test/index.html#Test-Suite-1",
    "page": "Test Suite",
    "title": "Test Suite",
    "category": "section",
    "text": "Pages = [\n    \"layouts.md\",\n    \"vectors.md\",\n    \"shapes.md\",\n    \"queries.md\",\n]"
},

{
    "location": "test/layouts.html#",
    "page": "Optimal Layouts",
    "title": "Optimal Layouts",
    "category": "page",
    "text": ""
},

{
    "location": "test/layouts.html#Optimal-Layouts-1",
    "page": "Optimal Layouts",
    "title": "Optimal Layouts",
    "category": "section",
    "text": "To represent complex structures on a fixed width screen, we can use a source code layout engine.using DataKnots.LayoutsFor example, let us represent a simple tree structure.struct Node\n    name::Symbol\n    arms::Vector{Node}\nend\n\nNode(name) = Node(name, [])\n\ntree =\n    Node(:a, [Node(:an, [Node(:anchor, [Node(:anchorage), Node(:anchorite)]),\n                           Node(:anchovy),\n                           Node(:antic, [Node(:anticipation)])]),\n               Node(:arc, [Node(:arch, [Node(:archduke), Node(:archer)])]),\n               Node(:awl)])\n#-> Node(:a, Main.layouts.md.Node[ … ])We override the function Layouts.tile() and use Layouts.literal() with combinators * (horizontal composition), / (vertical composition), and | (choice) to generate the layout expression.function Layouts.tile(tree::Node)\n    if isempty(tree.arms)\n        return Layouts.literal(\"Node($(repr(tree.name)))\")\n    end\n    arm_lts = [Layouts.tile(arm) for arm in tree.arms]\n    v_lt = h_lt = nothing\n    for (k, arm_lt) in enumerate(arm_lts)\n        if k == 1\n            v_lt = arm_lt\n            h_lt = Layouts.nobreaks(arm_lt)\n        else\n            v_lt = v_lt * Layouts.literal(\",\") / arm_lt\n            h_lt = h_lt * Layouts.literal(\", \") * Layouts.nobreaks(arm_lt)\n        end\n    end\n    return Layouts.literal(\"Node($(repr(tree.name)), [\") *\n           (v_lt | h_lt) *\n           Layouts.literal(\"])\")\nendNow we can use function pretty_print() to render a nicely formatted representation of the tree.pretty_print(stdout, tree)\n#=>\nNode(:a, [Node(:an, [Node(:anchor, [Node(:anchorage), Node(:anchorite)]),\n                     Node(:anchovy),\n                     Node(:antic, [Node(:anticipation)])]),\n          Node(:arc, [Node(:arch, [Node(:archduke), Node(:archer)])]),\n          Node(:awl)])\n=#We can control the width of the output.pretty_print(IOContext(stdout, :displaysize => (24, 60)), tree)\n#=>\nNode(:a, [Node(:an, [Node(:anchor, [Node(:anchorage),\n                                    Node(:anchorite)]),\n                     Node(:anchovy),\n                     Node(:antic, [Node(:anticipation)])]),\n          Node(:arc, [Node(:arch, [Node(:archduke),\n                                   Node(:archer)])]),\n          Node(:awl)])\n=#We can easily display the original and the optimized layouts.Layouts.tile(tree)\n#=>\nliteral(\"Node(:a, [\")\n* (literal(\"Node(:an, [\")\n   * (literal(\"Node(:anchor, [\")\n   ⋮\n=#\n\nLayouts.best(Layouts.fit(stdout, Layouts.tile(tree)))\n#=>\nliteral(\"Node(:a, [\")\n* (literal(\"Node(:an, [\")\n   * (literal(\"Node(:anchor, [Node(:anchorage), Node(:anchorite)]),\")\n   ⋮\n=#For some built-in data structures, automatic layout is already provided.data = [\n    (name = \"RICHARD A\", position = \"FIREFIGHTER\", salary = 90018),\n    (name = \"DEBORAH A\", position = \"POLICE OFFICER\", salary = 86520),\n    (name = \"KATHERINE A\", position = \"PERSONAL COMPUTER OPERATOR II\", salary = 60780)\n]\n\npretty_print(data)\n#=>\n[(name = \"RICHARD A\", position = \"FIREFIGHTER\", salary = 90018),\n (name = \"DEBORAH A\", position = \"POLICE OFFICER\", salary = 86520),\n (name = \"KATHERINE A\",\n  position = \"PERSONAL COMPUTER OPERATOR II\",\n  salary = 60780)]\n=#Finally, we can format and print Julia expressions.Q = :(\n    Employee\n    >> ThenFilter(Department >> Name .== \"POLICE\")\n    >> ThenSort(Salary >> Desc)\n    >> ThenSelect(Name, Position, Salary)\n    >> ThenTake(10)\n)\n\nprint_code(Q)\n#=>\nEmployee\n>> ThenFilter(Department >> Name .== \"POLICE\")\n>> ThenSort(Salary >> Desc)\n>> ThenSelect(Name, Position, Salary)\n>> ThenTake(10)\n=#"
},

{
    "location": "test/vectors.html#",
    "page": "Composite Vectors",
    "title": "Composite Vectors",
    "category": "page",
    "text": ""
},

{
    "location": "test/vectors.html#Composite-Vectors-1",
    "page": "Composite Vectors",
    "title": "Composite Vectors",
    "category": "section",
    "text": "For efficient data processing, an array of composite data can be stored in a column-oriented form: as a collection of arrays with primitive data.using DataKnots.Vectors"
},

{
    "location": "test/vectors.html#TupleVector-1",
    "page": "Composite Vectors",
    "title": "TupleVector",
    "category": "section",
    "text": "TupleVector is a vector of tuples stored as a collection of parallel vectors.tv = TupleVector(:name => [\"GARRY M\", \"ANTHONY R\", \"DANA A\"],\n                 :salary => [260004, 185364, 170112])\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\ndisplay(tv)\n#=>\nTupleVector of 3 × (name = String, salary = Int):\n (name = \"GARRY M\", salary = 260004)\n (name = \"ANTHONY R\", salary = 185364)\n (name = \"DANA A\", salary = 170112)\n=#It is possible to construct a TupleVector without labels.TupleVector(length(tv), columns(tv))\n#-> @VectorTree (String, Int) [(\"GARRY M\", 260004) … ]An error is reported in case of duplicate labels or columns of different height.TupleVector(:name => [\"GARRY M\", \"ANTHONY R\"],\n            :name => [\"DANA A\", \"JUAN R\"])\n#-> ERROR: duplicate column label :name\n\nTupleVector(:name => [\"GARRY M\", \"ANTHONY R\"],\n            :salary => [260004, 185364, 170112])\n#-> ERROR: unexpected column heightWe can access individual components of the vector.labels(tv)\n#-> Symbol[:name, :salary]\n\nwidth(tv)\n#-> 2\n\ncolumn(tv, 2)\n#-> [260004, 185364, 170112]\n\ncolumn(tv, :salary)\n#-> [260004, 185364, 170112]\n\ncolumns(tv)\n#-> …[[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [260004, 185364, 170112]]When indexed by another vector, we get a new instance of TupleVector.tv′ = tv[[3,1]]\ndisplay(tv′)\n#=>\nTupleVector of 2 × (name = String, salary = Int):\n (name = \"DANA A\", salary = 170112)\n (name = \"GARRY M\", salary = 260004)\n=#Note that the new instance keeps a reference to the index and the original column vectors.  Updated column vectors are generated on demand.column(tv′, 2)\n#-> [170112, 260004]"
},

{
    "location": "test/vectors.html#BlockVector-1",
    "page": "Composite Vectors",
    "title": "BlockVector",
    "category": "section",
    "text": "BlockVector is a vector of homogeneous vectors (blocks) stored as a vector of elements partitioned into individual blocks by a vector of offsets.bv = BlockVector([[\"HEALTH\"], [\"FINANCE\", \"HUMAN RESOURCES\"], [], [\"POLICE\", \"FIRE\"]])\n#-> @VectorTree [String] [\"HEALTH\", [\"FINANCE\", \"HUMAN RESOURCES\"], missing, [\"POLICE\", \"FIRE\"]]\n\ndisplay(bv)\n#=>\nBlockVector of 4 × [String]:\n \"HEALTH\"\n [\"FINANCE\", \"HUMAN RESOURCES\"]\n missing\n [\"POLICE\", \"FIRE\"]\n=#We can omit brackets for singular blocks and use missing in place of empty blocks.BlockVector([\"HEALTH\", [\"FINANCE\", \"HUMAN RESOURCES\"], missing, [\"POLICE\", \"FIRE\"]])\n#-> @VectorTree [String] [\"HEALTH\", [\"FINANCE\", \"HUMAN RESOURCES\"], missing, [\"POLICE\", \"FIRE\"]]It is possible to specify the offset and the element vectors separately.BlockVector([1, 2, 4, 4, 6], [\"HEALTH\", \"FINANCE\", \"HUMAN RESOURCES\", \"POLICE\", \"FIRE\"])\n#-> @VectorTree [String] [\"HEALTH\", [\"FINANCE\", \"HUMAN RESOURCES\"], missing, [\"POLICE\", \"FIRE\"]]If each block contains exactly one element, we could use : in place of the offset vector.BlockVector(:, [\"HEALTH\", \"FINANCE\", \"HUMAN RESOURCES\", \"POLICE\", \"FIRE\"])\n#-> @VectorTree [String] [\"HEALTH\", \"FINANCE\", \"HUMAN RESOURCES\", \"POLICE\", \"FIRE\"]The BlockVector constructor verifies that the offset vector is well-formed.BlockVector(Base.OneTo(0), [])\n#-> ERROR: partition must be non-empty\n\nBlockVector(Int[], [])\n#-> ERROR: partition must be non-empty\n\nBlockVector([0], [])\n#-> ERROR: partition must start with 1\n\nBlockVector([1,2,2,1], [\"HEALTH\"])\n#-> ERROR: partition must be monotone\n\nBlockVector(Base.OneTo(4), [\"HEALTH\", \"FINANCE\"])\n#-> ERROR: partition must enclose the elements\n\nBlockVector([1,2,3,6], [\"HEALTH\", \"FINANCE\"])\n#-> ERROR: partition must enclose the elementsWe can access individual components of the vector.offsets(bv)\n#-> [1, 2, 4, 4, 6]\n\nelements(bv)\n#-> [\"HEALTH\", \"FINANCE\", \"HUMAN RESOURCES\", \"POLICE\", \"FIRE\"]\n\npartition(bv)\n#-> ([1, 2, 4, 4, 6], [\"HEALTH\", \"FINANCE\", \"HUMAN RESOURCES\", \"POLICE\", \"FIRE\"])When indexed by a vector of indexes, an instance of BlockVector is returned.elts = [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nreg_bv = BlockVector(:, elts)\nshowcompact(reg_bv)\n#-> [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nopt_bv = BlockVector([1, 2, 3, 3, 4, 4, 5, 6, 6, 6, 7], elts)\nshowcompact(opt_bv)\n#-> [\"POLICE\", \"FIRE\", missing, \"HEALTH\", missing, \"AVIATION\", \"WATER MGMNT\", missing, missing, \"FINANCE\"]\n\nplu_bv = BlockVector([1, 1, 1, 2, 2, 4, 4, 6, 7], elts)\nshowcompact(plu_bv)\n#-> [missing, missing, \"POLICE\", missing, [\"FIRE\", \"HEALTH\"], missing, [\"AVIATION\", \"WATER MGMNT\"], \"FINANCE\"]\n\nshowcompact(reg_bv[[1,3,5,3]])\n#-> [\"POLICE\", \"HEALTH\", \"WATER MGMNT\", \"HEALTH\"]\n\nshowcompact(plu_bv[[1,3,5,3]])\n#-> [missing, \"POLICE\", [\"FIRE\", \"HEALTH\"], \"POLICE\"]\n\nshowcompact(reg_bv[Base.OneTo(4)])\n#-> [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\"]\n\nshowcompact(reg_bv[Base.OneTo(6)])\n#-> [\"POLICE\", \"FIRE\", \"HEALTH\", \"AVIATION\", \"WATER MGMNT\", \"FINANCE\"]\n\nshowcompact(plu_bv[Base.OneTo(6)])\n#-> [missing, missing, \"POLICE\", missing, [\"FIRE\", \"HEALTH\"], missing]\n\nshowcompact(opt_bv[Base.OneTo(10)])\n#-> [\"POLICE\", \"FIRE\", missing, \"HEALTH\", missing, \"AVIATION\", \"WATER MGMNT\", missing, missing, \"FINANCE\"]"
},

{
    "location": "test/vectors.html#IndexVector-1",
    "page": "Composite Vectors",
    "title": "IndexVector",
    "category": "section",
    "text": "IndexVector is a vector of indexes in some named vector.iv = IndexVector(:REF, [1, 1, 1, 2])\n#-> @VectorTree &REF [1, 1, 1, 2]\n\ndisplay(iv)\n#=>\nIndexVector of 4 × &REF:\n 1\n 1\n 1\n 2\n=#We can obtain the components of the vector.identifier(iv)\n#-> :REF\n\nindexes(iv)\n#-> [1, 1, 1, 2]Indexing an IndexVector by a vector produces another IndexVector instance.iv[[4,2]]\n#-> @VectorTree &REF [2, 1]IndexVector can be deferenced against a list of named vectors.refv = [\"COMISSIONER\", \"DEPUTY COMISSIONER\", \"ZONING ADMINISTRATOR\", \"PROJECT MANAGER\"]\n\ndereference(iv, [:REF => refv])\n#-> [\"COMISSIONER\", \"COMISSIONER\", \"COMISSIONER\", \"DEPUTY COMISSIONER\"]Function dereference() has no effect on other types of vectors, or when the desired reference vector is not in the list.dereference(iv, [:REF′ => refv])\n#-> @VectorTree &REF [1, 1, 1, 2]\n\ndereference([1, 1, 1, 2], [:REF => refv])\n#-> [1, 1, 1, 2]"
},

{
    "location": "test/vectors.html#CapsuleVector-1",
    "page": "Composite Vectors",
    "title": "CapsuleVector",
    "category": "section",
    "text": "CapsuleVector provides references for a composite vector with nested indexes. We use CapsuleVector to represent self-referential and mutually referential data.cv = CapsuleVector(TupleVector(:ref => iv), :REF => refv)\n#-> @VectorTree (ref = &REF,) [(ref = 1,), (ref = 1,), (ref = 1,), (ref = 2,)] where {REF = [ … ]}\n\ndisplay(cv)\n#=>\nCapsuleVector of 4 × (ref = &REF,):\n (ref = 1,)\n (ref = 1,)\n (ref = 1,)\n (ref = 2,)\nwhere\n REF = [\"COMISSIONER\", \"DEPUTY COMISSIONER\" … ]\n=#Function decapsulate() decomposes a capsule into the underlying vector and a list of references.decapsulate(cv)\n#-> (@VectorTree (ref = &REF,) [ … ], Pair{Symbol,AbstractArray{T,1} where T}[ … ])Function recapsulate() applies the given function to the underlying vector and encapsulates the output of the function.cv′ = recapsulate(v -> v[:, :ref], cv)\n#-> @VectorTree &REF [1, 1, 1, 2] where {REF = [ … ]}We could dereference CapsuleVector if it wraps an IndexVector instance. Function dereference() has no effect otherwise.dereference(cv′)\n#-> [\"COMISSIONER\", \"COMISSIONER\", \"COMISSIONER\", \"DEPUTY COMISSIONER\"]\n\ndereference(cv)\n#-> @VectorTree (ref = &REF,) [(ref = 1,), (ref = 1,), (ref = 1,), (ref = 2,)] where {REF = [ … ]}Indexing CapsuleVector by a vector produces another instance of CapsuleVector.cv[[4,2]]\n#-> @VectorTree (ref = &REF,) [(ref = 2,), (ref = 1,)] where {REF = [ … ]}"
},

{
    "location": "test/vectors.html#@VectorTree-1",
    "page": "Composite Vectors",
    "title": "@VectorTree",
    "category": "section",
    "text": "We can use @VectorTree macro to convert vector literals to the columnar form assembled with TupleVector, BlockVector, IndexVector, and CapsuleVector.TupleVector is created from a matrix or a vector of (named) tuples.@VectorTree (name = String, salary = Int) [\n    \"GARRY M\"   260004\n    \"ANTHONY R\" 185364\n    \"DANA A\"    170112\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\n@VectorTree (name = String, salary = Int) [\n    (\"GARRY M\", 260004),\n    (\"ANTHONY R\", 185364),\n    (\"DANA A\", 170112),\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]\n\n@VectorTree (name = String, salary = Int) [\n    (name = \"GARRY M\", salary = 260004),\n    (name = \"ANTHONY R\", salary = 185364),\n    (name = \"DANA A\", salary = 170112),\n]\n#-> @VectorTree (name = String, salary = Int) [(name = \"GARRY M\", salary = 260004) … ]Column labels are optional.@VectorTree (String, Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n#-> @VectorTree (String, Int) [(\"GARRY M\", 260004) … ]BlockVector and IndexVector can also be constructed.@VectorTree [String] [\n    \"HEALTH\",\n    [\"FINANCE\", \"HUMAN RESOURCES\"],\n    missing,\n    [\"POLICE\", \"FIRE\"],\n]\n#-> @VectorTree [String] [\"HEALTH\", [\"FINANCE\", \"HUMAN RESOURCES\"], missing, [\"POLICE\", \"FIRE\"]]\n\n@VectorTree &REF [1, 1, 1, 2]\n#-> @VectorTree &REF [1, 1, 1, 2]A CapsuleVector could be constructed using where syntax.@VectorTree &REF [1, 1, 1, 2] where {REF = refv}\n#-> @VectorTree &REF [1, 1, 1, 2] where {REF = [\"COMISSIONER\", \"DEPUTY COMISSIONER\"  … ]}Ill-formed @VectorTree contructors are rejected.@VectorTree (String, Int) (\"GARRY M\", 260004)\n#=>\nERROR: LoadError: expected a vector literal; got :((\"GARRY M\", 260004))\nin expression starting at none:2\n=#\n\n@VectorTree (String, Int) [(position = \"SUPERINTENDENT OF POLICE\", salary = 260004)]\n#=>\nERROR: LoadError: expected no label; got :(position = \"SUPERINTENDENT OF POLICE\")\nin expression starting at none:2\n=#\n\n@VectorTree (name = String, salary = Int) [(position = \"SUPERINTENDENT OF POLICE\", salary = 260004)]\n#=>\nERROR: LoadError: expected label :name; got :(position = \"SUPERINTENDENT OF POLICE\")\nin expression starting at none:2\n=#\n\n@VectorTree (name = String, salary = Int) [(\"GARRY M\", \"SUPERINTENDENT OF POLICE\", 260004)]\n#=>\nERROR: LoadError: expected 2 column(s); got :((\"GARRY M\", \"SUPERINTENDENT OF POLICE\", 260004))\nin expression starting at none:2\n=#\n\n@VectorTree (name = String, salary = Int) [\"GARRY M\"]\n#=>\nERROR: LoadError: expected a tuple or a row literal; got \"GARRY M\"\nin expression starting at none:2\n=#\n\n@VectorTree &REF [[]] where (:REF => [])\n#=>\nERROR: LoadError: expected an assignment; got :(:REF => [])\nin expression starting at none:2\n=#Using @VectorTree, we can easily construct hierarchical and mutually referential data.hier_data = @VectorTree (name = [String], employee = [(name = [String], salary = [Int])]) [\n    \"POLICE\"    [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]\n    \"FIRE\"      [\"JOSE S\" 202728; \"CHARLES S\" 197736]\n]\ndisplay(hier_data)\n#=>\nTupleVector of 2 × (name = [String], employee = [(name = [String], salary = [Int])]):\n (name = \"POLICE\", employee = [(name = \"GARRY M\", salary = 260004) … ])\n (name = \"FIRE\", employee = [(name = \"JOSE S\", salary = 202728) … ])\n=#\n\nmref_data = @VectorTree (department = [&DEPT], employee = [&EMP]) [\n    [1, 2]  [1, 2, 3, 4, 5]\n] where {\n    DEPT = @VectorTree (name = [String], employee = [&EMP]) [\n        \"POLICE\"    [1, 2, 3]\n        \"FIRE\"      [4, 5]\n    ]\n    ,\n    EMP = @VectorTree (name = [String], department = [&DEPT], salary = [Int]) [\n        \"GARRY M\"   1   260004\n        \"ANTHONY R\" 1   185364\n        \"DANA A\"    1   170112\n        \"JOSE S\"    2   202728\n        \"CHARLES S\" 2   197736\n    ]\n}\ndisplay(mref_data)\n#=>\nCapsuleVector of 1 × (department = [&DEPT], employee = [&EMP]):\n (department = [1, 2], employee = [1, 2, 3, 4, 5])\nwhere\n DEPT = @VectorTree (name = [String], employee = [&EMP]) [(name = \"POLICE\", employee = [1, 2, 3]) … ]\n EMP = @VectorTree (name = [String], department = [&DEPT], salary = [Int]) [(name = \"GARRY M\", department = 1, salary = 260004) … ]\n=#"
},

{
    "location": "test/shapes.html#",
    "page": "Type System",
    "title": "Type System",
    "category": "page",
    "text": ""
},

{
    "location": "test/shapes.html#Type-System-1",
    "page": "Type System",
    "title": "Type System",
    "category": "section",
    "text": "This module lets us describe the shape of the data.using DataKnots.Shapes"
},

{
    "location": "test/shapes.html#Cardinality-1",
    "page": "Type System",
    "title": "Cardinality",
    "category": "section",
    "text": "Enumerated type Cardinality is used to constrain the cardinality of a data block.  A block of data is called regular if it must contain exactly one element; optional if it may have no elements; and plural if it may have more than one element.  This gives us four different cardinality constraints.display(Cardinality)\n#=>\nEnum Cardinality:\nREG = 0\nOPT = 1\nPLU = 2\nOPT|PLU = 3\n=#Cardinality values support bitwise operations.REG|OPT|PLU             #-> OPT|PLU\nPLU&~PLU                #-> REGWe can use predicates isregular(), isoptional(), isplural() to check cardinality values.isregular(REG)          #-> true\nisregular(OPT)          #-> false\nisregular(PLU)          #-> false\nisoptional(OPT)         #-> true\nisoptional(PLU)         #-> false\nisplural(PLU)           #-> true\nisplural(OPT)           #-> falseCardinality supports standard operations on enumerated types.typemin(Cardinality)    #-> REG\ntypemax(Cardinality)    #-> OPT|PLU\nREG < OPT|PLU           #-> true\n\nCardinality(3)\n#-> OPT|PLU\nread(IOBuffer(\"\\x03\"), Cardinality)\n#-> OPT|PLUThere is a partial ordering defined on Cardinality values.  We can determine the greatest and the least cardinality; the least upper bound and the greatest lower bound of a collection of Cardinality values; and, for two Cardinality values, determine whether one of the values is smaller than the other.bound(Cardinality)      #-> REG\nibound(Cardinality)     #-> OPT|PLU\n\nbound(OPT, PLU)         #-> OPT|PLU\nibound(PLU, OPT)        #-> REG\n\nfits(OPT, PLU)          #-> false\nfits(REG, OPT|PLU)      #-> true"
},

{
    "location": "test/shapes.html#Data-shapes-1",
    "page": "Type System",
    "title": "Data shapes",
    "category": "section",
    "text": "The structure of composite data is specified with shape objects.NativeShape specifies the type of a regular Julia value.str_shp = NativeShape(String)\n#-> NativeShape(String)\n\neltype(str_shp)\n#-> StringIndexShape indicates that the value is an index in a vector.  Its class name is used to find the shape of the target vector.idx_shp = IndexShape(:Emp)\n#-> IndexShape(:Emp)\n\nclass(idx_shp)\n#-> :EmpA shape which does not contain any indexes is called closed.isclosed(idx_shp)\n#-> false\n\nisclosed(str_shp)\n#-> trueFor a data block, BlockShape specifies shape of its elements.blk_shp = BlockShape(IndexShape(:Emp))\n#-> BlockShape(IndexShape(:Emp))\n\nblk_shp[]\n#-> IndexShape(:Emp)TupleShape lets us specify the field types of a tuple value.tpl_shp = TupleShape(NativeShape(String),\n                     BlockShape(IndexShape(:Emp)))\n#-> TupleShape(NativeShape(String), BlockShape(IndexShape(:Emp)))\n\nforeach(println, tpl_shp[:])\n#=>\nNativeShape(String)\nBlockShape(IndexShape(:Emp))\n=#Two special shape types are used to indicate that the value may have any shape, or cannot exist.any_shp = AnyShape()\n#-> AnyShape()\n\nnone_shp = NoneShape()\n#-> NoneShape()By default, AnyShape is assumed open-ended, but we can also indicate that it is closed.isclosed(AnyShape())\n#-> false\n\nisclosed(AnyShape(true))\n#-> trueTo any shape, we can attach an arbitrary set of attributes, which are called decorations.  In particular, we can label the values.decor_shp = str_shp |> decorate(:tag => :position)\n#-> NativeShape(String) |> decorate(:tag => :position)The value of a decoration could be extracted.decoration(decor_shp, :tag)We can enforce the type and the default value of the decoration.decoration(decor_shp, :tag, Symbol, Symbol(\"\"))\n#-> :position\ndecoration(decor_shp, :tag, String, \"\")\n#-> \"\"\ndecoration(str_shp, :tag, String, \"\")\n#-> \"\"InputShape and OutputShape are derived shapes that describe the structure of the query input and the query output.To describe the query input, we specify the shape of the input elements, the shapes of the parameters, and whether or not the input is framed.i_shp = InputShape(IndexShape(:Emp),\n                   [:D => OutputShape(NativeShape(String))],\n                   true)\n#-> InputShape(IndexShape(:Emp), [:D => OutputShape(NativeShape(String))], true)\n\ni_shp[]\n#-> IndexShape(:Emp)\n\ndomain(i_shp)\n#-> IndexShape(:Emp)\n\nmode(i_shp)\n#-> InputMode([:D => OutputShape(NativeShape(String))], true)To describe the query output, we specify the shape and the cardinality of the output elements.o_shp = OutputShape(NativeShape(Int), OPT|PLU)\n#-> OutputShape(NativeShape(Int), OPT|PLU)\n\no_shp[]\n#-> NativeShape(Int)\n\ncardinality(o_shp)\n#-> OPT|PLU\n\ndomain(o_shp)\n#-> NativeShape(Int)\n\nmode(o_shp)\n#-> OutputMode(OPT|PLU)RecordShape` specifies the shape of a record value where each field has a certain shape and cardinality.dept_shp = RecordShape(OutputShape(String) |> decorate(:tag => :name),\n                       OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :employee))\n#=>\nRecordShape(OutputShape(NativeShape(String) |> decorate(:tag => :name)),\n            OutputShape(IndexShape(:Emp) |> decorate(:tag => :employee),\n                        OPT|PLU))\n=#\n\nemp_shp = RecordShape(OutputShape(String) |> decorate(:tag => :name),\n                      OutputShape(:Dept) |> decorate(:tag => :department),\n                      OutputShape(String) |> decorate(:tag => :position),\n                      OutputShape(Int) |> decorate(:tag => :salary),\n                      OutputShape(:Emp, OPT) |> decorate(:tag => :manager),\n                      OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :subordinate))\n#=>\nRecordShape(OutputShape(NativeShape(String) |> decorate(:tag => :name)),\n            OutputShape(IndexShape(:Dept) |> decorate(:tag => :department)),\n            OutputShape(NativeShape(String) |> decorate(:tag => :position)),\n            OutputShape(NativeShape(Int) |> decorate(:tag => :salary)),\n            OutputShape(IndexShape(:Emp) |> decorate(:tag => :manager), OPT),\n            OutputShape(IndexShape(:Emp) |> decorate(:tag => :subordinate),\n                        OPT|PLU))\n=#CapsuleShape provides the shapes for any nested indexes.  Using it, we can fully specify self-referential and mutually referential data.db_shp = RecordShape(OutputShape(:Dept, OPT|PLU) |> decorate(:tag => :department),\n                     OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :employee))\n\nCapsuleShape(db_shp, :Dept => dept_shp, :Emp => emp_shp)\n#=>\nCapsuleShape(\n    RecordShape(OutputShape(IndexShape(:Dept) |> decorate(:tag => :department),\n                            OPT|PLU),\n                OutputShape(IndexShape(:Emp) |> decorate(:tag => :employee),\n                            OPT|PLU)),\n    :Dept => RecordShape(\n                 OutputShape(NativeShape(String) |> decorate(:tag => :name)),\n                 OutputShape(IndexShape(:Emp) |> decorate(:tag => :employee),\n                             OPT|PLU)),\n    :Emp =>\n        RecordShape(\n            OutputShape(NativeShape(String) |> decorate(:tag => :name)),\n            OutputShape(IndexShape(:Dept) |> decorate(:tag => :department)),\n            OutputShape(NativeShape(String) |> decorate(:tag => :position)),\n            OutputShape(NativeShape(Int) |> decorate(:tag => :salary)),\n            OutputShape(IndexShape(:Emp) |> decorate(:tag => :manager), OPT),\n            OutputShape(IndexShape(:Emp) |> decorate(:tag => :subordinate),\n                        OPT|PLU)))\n=#"
},

{
    "location": "test/shapes.html#Shape-ordering-1",
    "page": "Type System",
    "title": "Shape ordering",
    "category": "section",
    "text": "The same data can satisfy many different shape constraints.  For example, a vector BlockVector([Chicago]) can be said to have, among others, the shape BlockShape(String), the shape OutputShape(String, OPT|PLU) or the shape AnyShape().  We can tell, for any two shapes, if one of them is more specific than the other.fits(NativeShape(Int), NativeShape(Number))     #-> true\nfits(NativeShape(Int), NativeShape(String))     #-> false\n\nfits(IndexShape(:Emp), IndexShape(:Emp))        #-> true\nfits(IndexShape(:Emp), IndexShape(:Dept))       #-> false\n\nfits(BlockShape(Int), BlockShape(Number))       #-> true\nfits(BlockShape(Int), BlockShape(String))       #-> false\n\nfits(TupleShape(Int, BlockShape(String)),\n     TupleShape(Number, BlockShape(String)))    #-> true\nfits(TupleShape(Int, BlockShape(String)),\n     TupleShape(String, BlockShape(String)))    #-> false\nfits(TupleShape(Int),\n     TupleShape(Number, BlockShape(String)))    #-> false\n\nfits(CapsuleShape(BlockShape(:Emp),\n                  :Emp => TupleShape(String, Int),\n                  :Dept => TupleShape(String)),\n     CapsuleShape(BlockShape(:Emp),\n                  :Emp => TupleShape(String, Number)))  #-> true\nfits(CapsuleShape(BlockShape(:Emp),\n                  :Emp => TupleShape(String, Int)),\n     CapsuleShape(BlockShape(:Emp),\n                  :Emp => TupleShape(String, Int),\n                  :Dept => TupleShape(String)))         #-> false\nfits(CapsuleShape(BlockShape(:Emp),\n                  :Emp => TupleShape(String, Int)),\n     BlockShape(AnyShape()))                            #-> true\nfits(BlockShape(AnyShape()),\n     CapsuleShape(BlockShape(:Emp),\n                  :Emp => TupleShape(String, Number)))  #-> false\n\nfits(InputShape(Int,\n                [:X => OutputShape(Int),\n                 :Y => OutputShape(String)],\n                true),\n     InputShape(Number,\n                [:X => OutputShape(Int, OPT)])) #-> true\nfits(InputShape(Int),\n     InputShape(Number, true))                  #-> false\nfits(InputShape(Int,\n                [:X => OutputShape(Int, OPT)]),\n     InputShape(Number,\n                [:X => OutputShape(Int)]))      #-> false\n\nfits(OutputShape(Int),\n     OutputShape(Number, OPT))                  #-> true\nfits(OutputShape(Int, PLU),\n     OutputShape(Number, OPT))                  #-> false\nfits(OutputShape(Int),\n     OutputShape(String, OPT))                  #-> false\n\nfits(RecordShape(OutputShape(Int),\n                 OutputShape(String, OPT)),\n     RecordShape(OutputShape(Number),\n                 OutputShape(String, OPT|PLU)))     #-> true\nfits(RecordShape(OutputShape(Int, OPT),\n                 OutputShape(String)),\n     RecordShape(OutputShape(Number),\n                 OutputShape(String, OPT|PLU)))     #-> false\nfits(RecordShape(OutputShape(Int)),\n     RecordShape(OutputShape(Number),\n                 OutputShape(String, OPT|PLU)))     #-> falseShapes of different kinds are typically not compatible with each other.  The exceptions are AnyShape and NullShape.fits(NativeShape(Int), IndexShape(:Emp))    #-> false\nfits(NativeShape(Int), AnyShape())          #-> true\nfits(NoneShape(), IndexShape(:Emp))         #-> trueShape decorations are treated as additional shape constraints.fits(NativeShape(String) |> decorate(:tag => :name),\n     NativeShape(String) |> decorate(:tag => :name))        #-> true\nfits(NativeShape(String),\n     NativeShape(String) |> decorate(:tag => :name))        #-> false\nfits(NativeShape(String) |> decorate(:tag => :position),\n     NativeShape(String))                                   #-> true\nfits(NativeShape(String) |> decorate(:tag => :position),\n     NativeShape(String) |> decorate(:tag => :name))        #-> falseFor any given number of shapes, we can find their upper bound, the shape that is more general than each of them.  We can also find their lower bound.bound(NativeShape(Int), NativeShape(Number))\n#-> NativeShape(Number)\nibound(NativeShape(Int), NativeShape(Number))\n#-> NativeShape(Int)\n\nbound(IndexShape(:Emp), IndexShape(:Emp))\n#-> IndexShape(:Emp)\nibound(IndexShape(:Emp), IndexShape(:Emp))\n#-> IndexShape(:Emp)\nbound(IndexShape(:Emp), IndexShape(:Dept))\n#-> AnyShape()\nibound(IndexShape(:Emp), IndexShape(:Dept))\n#-> NoneShape()\n\nbound(BlockShape(Int), BlockShape(Number))\n#-> BlockShape(NativeShape(Number))\nibound(BlockShape(Int), BlockShape(Number))\n#-> BlockShape(NativeShape(Int))\n\nbound(TupleShape(:Emp, BlockShape(String)),\n      TupleShape(:Dept, BlockShape(String)))\n#-> TupleShape(AnyShape(), BlockShape(NativeShape(String)))\nibound(TupleShape(:Emp, BlockShape(String)),\n       TupleShape(:Dept, BlockShape(String)))\n#-> TupleShape(NoneShape(), BlockShape(NativeShape(String)))\n\nbound(CapsuleShape(BlockShape(:Emp),\n                   :Emp => TupleShape(:Dept, Number),\n                   :Dept => TupleShape(String)),\n      CapsuleShape(BlockShape(:Emp),\n                   :Emp => TupleShape(String, Int)))\n#=>\nCapsuleShape(BlockShape(IndexShape(:Emp)),\n             :Emp => TupleShape(AnyShape(), NativeShape(Number)))\n=#\nibound(CapsuleShape(BlockShape(:Emp),\n                    :Emp => TupleShape(:Dept, Number),\n                    :Dept => TupleShape(String)),\n       CapsuleShape(BlockShape(:Emp),\n                    :Emp => TupleShape(String, Int)))\n#=>\nCapsuleShape(BlockShape(IndexShape(:Emp)),\n             :Dept => TupleShape(NativeShape(String)),\n             :Emp => TupleShape(NoneShape(), NativeShape(Int)))\n=#\n\nbound(InputShape(Int, [:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true),\n      InputShape(Number, [:X => OutputShape(Int)]))\n#=>\nInputShape(NativeShape(Number), [:X => OutputShape(NativeShape(Int), OPT)])\n=#\nibound(InputShape(Int, [:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true),\n       InputShape(Number, [:X => OutputShape(Int)]))\n#=>\nInputShape(NativeShape(Int),\n           [:X => OutputShape(NativeShape(Int)),\n            :Y => OutputShape(NativeShape(String))],\n           true)\n=#\n\nbound(OutputShape(String, OPT), OutputShape(String, PLU))\n#-> OutputShape(NativeShape(String), OPT|PLU)\nibound(OutputShape(String, OPT), OutputShape(String, PLU))\n#-> OutputShape(NativeShape(String))\n\nbound(RecordShape(OutputShape(Int, PLU),\n                  OutputShape(String, OPT)),\n      RecordShape(OutputShape(Number),\n                  OutputShape(:Emp, OPT|PLU)))\n#=>\nRecordShape(OutputShape(NativeShape(Number), PLU),\n            OutputShape(AnyShape(), OPT|PLU))\n=#\nibound(RecordShape(OutputShape(Int, PLU),\n                   OutputShape(String, OPT)),\n       RecordShape(OutputShape(Number),\n                   OutputShape(:Emp, OPT|PLU)))\n#=>\nRecordShape(OutputShape(NativeShape(Int)), OutputShape(NoneShape(), OPT))\n=#For decorated shapes, incompatible decoration constraints are replaced with nothing.bound(NativeShape(String) |> decorate(:show => false, :tag => :name),\n      NativeShape(String) |> decorate(:hide => true, :tag => :name))\n#-> NativeShape(String) |> decorate(:tag => :name)\n\nibound(NativeShape(String) |> decorate(:show => false, :tag => :name),\n       NativeShape(String) |> decorate(:hide => true, :tag => :name))\n#-> NativeShape(String) |> decorate(:hide => true, :show => false, :tag => :name)\n\nbound(NativeShape(String) |> decorate(:tag => :position),\n      NativeShape(Number) |> decorate(:tag => :salary))\n#-> AnyShape(true)\n\nibound(NativeShape(String) |> decorate(:tag => :position),\n       NativeShape(Number) |> decorate(:tag => :salary))\n#-> NoneShape() |> decorate(:tag => nothing)\n\nbound(NativeShape(Int),\n      NativeShape(Number) |> decorate(:tag => :salary))\n#-> NativeShape(Number)\n\nibound(NativeShape(Int),\n       NativeShape(Number) |> decorate(:tag => :salary))\n#-> NativeShape(Int) |> decorate(:tag => :salary)"
},

{
    "location": "test/shapes.html#Query-signature-1",
    "page": "Type System",
    "title": "Query signature",
    "category": "section",
    "text": "The signature of a query is a pair of an InputShape object and an OutputShape object.sig = Signature(InputShape(:Dept),\n                OutputShape(RecordShape(OutputShape(String) |> decorate(:tag => :name),\n                                        OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :employee))))\n#-> Dept -> (name => String[1 .. 1], employee => Emp[0 .. ∞])[1 .. 1]Different components of the signature can be easily extracted.shape(sig)\n#=>\nOutputShape(RecordShape(\n                OutputShape(NativeShape(String) |> decorate(:tag => :name)),\n                OutputShape(IndexShape(:Emp) |> decorate(:tag => :employee),\n                            OPT|PLU)))\n=#\n\nishape(sig)\n#-> InputShape(IndexShape(:Dept))\n\ndomain(sig)\n#=>\nRecordShape(OutputShape(NativeShape(String) |> decorate(:tag => :name)),\n            OutputShape(IndexShape(:Emp) |> decorate(:tag => :employee),\n                        OPT|PLU))\n=#\n\nmode(sig)\n#-> OutputMode()\n\nidomain(sig)\n#-> IndexShape(:Dept)\n\nimode(sig)\n#-> InputMode()"
},

{
    "location": "test/queries.html#",
    "page": "Query Backend",
    "title": "Query Backend",
    "category": "page",
    "text": ""
},

{
    "location": "test/queries.html#Query-Backend-1",
    "page": "Query Backend",
    "title": "Query Backend",
    "category": "section",
    "text": "The Queries module contains primitive operations and combinators for transforming atomic and composite vectors.using DataKnots.Vectors\nusing DataKnots.Queries"
},

{
    "location": "test/queries.html#Lifting-1",
    "page": "Query Backend",
    "title": "Lifting",
    "category": "section",
    "text": "Many vector operations can be generated by lifting.  For example, lift_const() generates a primitive operation that maps any input vector to the output vector of the same length filled with the given value.q = lift_const(200000)\n#-> lift_const(200000)\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [200000, 200000, 200000]Similarly, the output of lift_block() is a block vector filled with the given block.q = lift_block([\"POLICE\", \"FIRE\"])\n#-> lift_block([\"POLICE\", \"FIRE\"])\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [String] [[\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"], [\"POLICE\", \"FIRE\"]]A variant of lift_block() called lift_null() outputs a block vector with empty blocks.q = lift_null()\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [Union{}] [missing, missing, missing]Any scalar function could be lifted to a vector operation by applying it to each element of the input vector.q = lift(titlecase)\n#-> lift(titlecase)\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [\"Garry M\", \"Anthony R\", \"Dana A\"]Similarly, any scalar function of several arguments could be lifted to an operation on tuple vectors.q = lift_to_tuple(>)\n#-> lift_to_tuple(>)\n\nq(@VectorTree (Int, Int) [260004 200000; 185364 200000; 170112 200000])\n#-> Bool[true, false, false]It is also possible to apply a scalar function of several arguments to a tuple vector that has block vectors for its columns.  In this case, the function is applied to every combination of values from all the blocks on the same row.q = lift_to_block_tuple(>)\n\nq(@VectorTree ([Int], [Int]) [[260004, 185364, 170112] 200000; missing 200000; [202728, 197736] [200000, 200000]])\n#-> @VectorTree [Bool] [Bool[true, false, false], missing, Bool[true, true, false, false]]Any function that takes a vector argument can be lifted to an operation on block vectors.q = lift_to_block(length)\n#-> lift_to_block(length)\n\nq(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]])\n#-> [3, 2]Some vector functions may expect a non-empty vector as an argument.  In this case, we should provide the value to replace empty blocks.q = lift_to_block(maximum, missing)\n#-> lift_to_block(maximum, missing)\n\nq(@VectorTree [Int] [[260004, 185364, 170112], [], [202728, 197736]])\n#-> Union{Missing, Int}[260004, missing, 202728]"
},

{
    "location": "test/queries.html#Decoding-vectors-1",
    "page": "Query Backend",
    "title": "Decoding vectors",
    "category": "section",
    "text": "Any vector of tuples can be converted to a tuple vector.q = decode_tuple()\n#-> decode_tuple()\n\nq([(\"GARRY M\", 260004), (\"ANTHONY R\", 185364), (\"DANA A\", 170112)]) |> display\n#=>\nTupleVector of 3 × (String, Int):\n (\"GARRY M\", 260004)\n (\"ANTHONY R\", 185364)\n (\"DANA A\", 170112)\n=#Vectors of named tuples are also supported.q([(name=\"GARRY M\", salary=260004), (name=\"ANTHONY R\", salary=185364), (name=\"DANA A\", salary=170112)]) |> display\n#=>\nTupleVector of 3 × (name = String, salary = Int):\n (name = \"GARRY M\", salary = 260004)\n (name = \"ANTHONY R\", salary = 185364)\n (name = \"DANA A\", salary = 170112)\n=#A vector of vector objects can be converted to a block vector.q = decode_vector()\n#-> decode_vector()\n\nq([[260004, 185364, 170112], Int[], [202728, 197736]])\n#-> @VectorTree [Int] [[260004, 185364, 170112], missing, [202728, 197736]]Similarly, a vector containing missing values can be converted to a block vector with zero- and one-element blocks.q = decode_missing()\n#-> decode_missing()\n\nq([260004, 185364, 170112, missing, 202728, 197736])\n#-> @VectorTree [Int] [260004, 185364, 170112, missing, 202728, 197736]"
},

{
    "location": "test/queries.html#Tuple-vectors-1",
    "page": "Query Backend",
    "title": "Tuple vectors",
    "category": "section",
    "text": "To create a tuple vector, we use the combinator tuple_of(). Its arguments are the functions that generate the columns of the tuple.q = tuple_of(:title => lift(titlecase), :last => lift(last))\n#-> tuple_of([:title, :last], [lift(titlecase), lift(last)])\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"]) |> display\n#=>\nTupleVector of 3 × (title = String, last = Char):\n (title = \"Garry M\", last = \'M\')\n (title = \"Anthony R\", last = \'R\')\n (title = \"Dana A\", last = \'A\')\n=#To extract a column of a tuple vector, we use the primitive column().  It accepts either the column position or the column name.q = column(1)\n#-> column(1)\n\nq(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112])\n#-> [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]\n\nq = column(:salary)\n#-> column(:salary)\n\nq(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112])\n#-> [260004, 185364, 170112]Finally, we can apply an arbitrary transformation to a selected column of a tuple vector.q = in_tuple(:name, lift(titlecase))\n#-> in_tuple(:name, lift(titlecase))\n\nq(@VectorTree (name = String, salary = Int) [\"GARRY M\" 260004; \"ANTHONY R\" 185364; \"DANA A\" 170112]) |> display\n#=>\nTupleVector of 3 × (name = String, salary = Int):\n (name = \"Garry M\", salary = 260004)\n (name = \"Anthony R\", salary = 185364)\n (name = \"Dana A\", salary = 170112)\n=#"
},

{
    "location": "test/queries.html#Block-vectors-1",
    "page": "Query Backend",
    "title": "Block vectors",
    "category": "section",
    "text": "Primitive as_block() wraps the elements of the input vector to one-element blocks.q = as_block()\n#-> as_block()\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> @VectorTree [String] [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]In the opposite direction, primitive flat_block() flattens a block vector with block elements.q = flat_block()\n#-> flat_block()\n\nq(@VectorTree [[String]] [[[\"GARRY M\"], [\"ANTHONY R\", \"DANA A\"]], [missing, [\"JOSE S\"], [\"CHARLES S\"]]])\n#-> @VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]]Finally, we can apply an arbitrary transformation to every element of a block vector.q = in_block(lift(titlecase))\n#-> in_block(lift(titlecase))\n\nq(@VectorTree [String] [[\"GARRY M\", \"ANTHONY R\", \"DANA A\"], [\"JOSE S\", \"CHARLES S\"]])\n#-> @VectorTree [String] [[\"Garry M\", \"Anthony R\", \"Dana A\"], [\"Jose S\", \"Charles S\"]]The pull_block() primitive converts a tuple vector with a block column to a block vector of tuples.q = pull_block(1)\n#-> pull_block(1)\n\nq(@VectorTree ([Int], [Int]) [\n    [260004, 185364, 170112]    200000\n    missing                     200000\n    [202728, 197736]            [200000, 200000]]\n) |> display\n#=>\nBlockVector of 3 × [(Int, [Int])]:\n [(260004, 200000), (185364, 200000), (170112, 200000)]\n missing\n [(202728, [200000, 200000]), (197736, [200000, 200000])]\n=#It is also possible to pull all block columns from a tuple vector.q = pull_every_block()\n#-> pull_every_block()\n\nq(@VectorTree ([Int], [Int]) [\n    [260004, 185364, 170112]    200000\n    missing                     200000\n    [202728, 197736]            [200000, 200000]]\n) |> display\n#=>\nBlockVector of 3 × [(Int, Int)]:\n [(260004, 200000), (185364, 200000), (170112, 200000)]\n missing\n [(202728, 200000), (202728, 200000), (197736, 200000), (197736, 200000)]\n=#"
},

{
    "location": "test/queries.html#Index-vectors-1",
    "page": "Query Backend",
    "title": "Index vectors",
    "category": "section",
    "text": "An index vector could be dereferenced using the dereference() primitive.q = dereference()\n#-> dereference()\n\nq(@VectorTree &DEPT [1, 1, 1, 2] where {DEPT = [\"POLICE\", \"FIRE\"]})\n#-> [\"POLICE\", \"POLICE\", \"POLICE\", \"FIRE\"]"
},

{
    "location": "test/queries.html#Composition-1",
    "page": "Query Backend",
    "title": "Composition",
    "category": "section",
    "text": "We can compose a sequence of transformations using the chain_of() combinator.q = chain_of(\n        column(:employee),\n        in_block(lift(titlecase)))\n#-> chain_of(column(:employee), in_block(lift(titlecase)))\n\nq(@VectorTree (department = String, employee = [String]) [\n    \"POLICE\"    [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]\n    \"FIRE\"      [\"JOSE S\", \"CHARLES S\"]])\n#-> @VectorTree [String] [[\"Garry M\", \"Anthony R\", \"Dana A\"], [\"Jose S\", \"Charles S\"]]The empty chain chain_of() has an alias pass().q = pass()\n#-> pass()\n\nq([\"GARRY M\", \"ANTHONY R\", \"DANA A\"])\n#-> [\"GARRY M\", \"ANTHONY R\", \"DANA A\"]"
},

]}
