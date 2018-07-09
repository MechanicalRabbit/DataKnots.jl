# Type System

This module lets us describe the shape of the data.

    using DataKnots.Shapes


## Cardinality

Enumerated type `Cardinality` is used to constrain the cardinality of a data
block.  A block of data is called *regular* if it must contain exactly one
element; *optional* if it may have no elements; and *plural* if it may have
more than one element.  This gives us four different cardinality constraints.

    display(Cardinality)
    #=>
    Enum Cardinality:
    REG = 0
    OPT = 1
    PLU = 2
    OPT|PLU = 3
    =#

Cardinality values support bitwise operations.

    REG|OPT|PLU             #-> OPT|PLU
    PLU&~PLU                #-> REG

We can use predicates `isregular()`, `isoptional()`, `isplural()` to check
cardinality values.

    isregular(REG)          #-> true
    isregular(OPT)          #-> false
    isregular(PLU)          #-> false
    isoptional(OPT)         #-> true
    isoptional(PLU)         #-> false
    isplural(PLU)           #-> true
    isplural(OPT)           #-> false

`Cardinality` supports standard operations on enumerated types.

    typemin(Cardinality)    #-> REG
    typemax(Cardinality)    #-> OPT|PLU
    REG < OPT|PLU           #-> true

    Cardinality(3)
    #-> OPT|PLU
    read(IOBuffer("\x03"), Cardinality)
    #-> OPT|PLU

There is a partial ordering defined on `Cardinality` values.  We can determine
the greatest and the least cardinality; the least upper bound and the greatest
lower bound of a collection of `Cardinality` values; and, for two `Cardinality`
values, determine whether one of the values is smaller than the other.

    bound(Cardinality)      #-> REG
    ibound(Cardinality)     #-> OPT|PLU

    bound(OPT, PLU)         #-> OPT|PLU
    ibound(PLU, OPT)        #-> REG

    fits(OPT, PLU)          #-> false
    fits(REG, OPT|PLU)      #-> true


## Data shapes

The structure of composite data is specified with *shape* objects.

`NativeShape` specifies the type of a regular Julia value.

    str_shp = NativeShape(String)
    #-> NativeShape(String)

    eltype(str_shp)
    #-> String

`ClassShape` refers to a shape with a name.

    cls_shp = ClassShape(:Emp)
    #-> ClassShape(:Emp)

    class(cls_shp)
    #-> :Emp

We can provide a definition for a class name using `rebind()` method.

    clos_shp = cls_shp |> rebind(:Emp => str_shp)
    #-> ClassShape(:Emp) |> rebind(:Emp => NativeShape(String))

Now we can obtain the actual shape of the class.

    clos_shp[]
    #-> NativeShape(String)

A shape which does not contain any nested undefined classes is called closed.

    isclosed(str_shp)
    #-> true

    isclosed(cls_shp)
    #-> false

    isclosed(clos_shp)
    #-> true

`TupleShape` lets us specify the field types of a tuple value.

    tpl_shp = TupleShape(NativeShape(String),
                         BlockShape(ClassShape(:Emp)))
    #-> TupleShape(NativeShape(String), BlockShape(ClassShape(:Emp)))

    foreach(println, tpl_shp[:])
    #=>
    NativeShape(String)
    BlockShape(ClassShape(:Emp))
    =#

Two special shape types are used to indicate that the value may have any shape,
or cannot exist.

    any_shp = AnyShape()
    #-> AnyShape()

    none_shp = NoneShape()
    #-> NoneShape()

To any shape, we can attach an arbitrary set of attributes, which are called
*decorations*.  In particular, we can label the values.

    decor_shp = str_shp |> decorate(:tag => :position)
    #-> NativeShape(String) |> decorate(:tag => :position)

The value of a decoration could be extracted.

    decoration(decor_shp, :tag)

We can enforce the type and the default value of the decoration.

    decoration(decor_shp, :tag, Symbol, Symbol(""))
    #-> :position
    decoration(decor_shp, :tag, String, "")
    #-> ""
    decoration(str_shp, :tag, String, "")
    #-> ""

`InputShape` and `OutputShape` are derived shapes that describe the structure
of the query input and the query output.

To describe the query input, we specify the shape of the input elements, the
shapes of the parameters, and whether or not the input is framed.

    i_shp = InputShape(ClassShape(:Emp),
                       [:D => OutputShape(NativeShape(String))],
                       true)
    #-> InputShape(ClassShape(:Emp), [:D => OutputShape(NativeShape(String))], true)

    i_shp[]
    #-> ClassShape(:Emp)

    domain(i_shp)
    #-> ClassShape(:Emp)

    mode(i_shp)
    #-> InputMode([:D => OutputShape(NativeShape(String))], true)

To describe the query output, we specify the shape and the cardinality of the
output elements.

    o_shp = OutputShape(NativeShape(Int), OPT|PLU)
    #-> OutputShape(NativeShape(Int), OPT|PLU)

    o_shp[]
    #-> NativeShape(Int)

    cardinality(o_shp)
    #-> OPT|PLU

    domain(o_shp)
    #-> NativeShape(Int)

    mode(o_shp)
    #-> OutputMode(OPT|PLU)

RecordShape` specifies the shape of a record value where each field has a
certain shape and cardinality.

    dept_shp = RecordShape(OutputShape(String) |> decorate(:tag => :name),
                           OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :employee))
    #=>
    RecordShape(OutputShape(NativeShape(String) |> decorate(:tag => :name)),
                OutputShape(ClassShape(:Emp) |> decorate(:tag => :employee),
                            OPT|PLU))
    =#

    emp_shp = RecordShape(OutputShape(String) |> decorate(:tag => :name),
                          OutputShape(:Dept) |> decorate(:tag => :department),
                          OutputShape(String) |> decorate(:tag => :position),
                          OutputShape(Int) |> decorate(:tag => :salary),
                          OutputShape(:Emp, OPT) |> decorate(:tag => :manager),
                          OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :subordinate))
    #=>
    RecordShape(OutputShape(NativeShape(String) |> decorate(:tag => :name)),
                OutputShape(ClassShape(:Dept) |> decorate(:tag => :department)),
                OutputShape(NativeShape(String) |> decorate(:tag => :position)),
                OutputShape(NativeShape(Int) |> decorate(:tag => :salary)),
                OutputShape(ClassShape(:Emp) |> decorate(:tag => :manager), OPT),
                OutputShape(ClassShape(:Emp) |> decorate(:tag => :subordinate),
                            OPT|PLU))
    =#

Using the combination of different shapes we can describe the structure of any
data source.

    db_shp = RecordShape(OutputShape(:Dept, OPT|PLU) |> decorate(:tag => :department),
                         OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :employee))

    db_shp |> rebind(:Dept => dept_shp, :Emp => emp_shp)
    #=>
    RecordShape(
        OutputShape(
            ClassShape(:Dept)
            |> rebind(:Dept => RecordShape(
                                   OutputShape(NativeShape(String)
                                               |> decorate(:tag => :name)),
                                   OutputShape(ClassShape(:Emp)
                                               |> decorate(:tag => :employee),
                                               OPT|PLU))
                               |> decorate(:tag => :department),
                      :Emp => RecordShape(
                                  OutputShape(NativeShape(String)
                                              |> decorate(:tag => :name)),
                                  ⋮
                                  OutputShape(ClassShape(:Emp)
                                              |> decorate(:tag => :subordinate),
                                              OPT|PLU))),
            OPT|PLU),
        OutputShape(
            ClassShape(:Emp)
            |> rebind(:Dept => RecordShape(
                                   OutputShape(NativeShape(String)
                                               |> decorate(:tag => :name)),
                                   OutputShape(ClassShape(:Emp)
                                               |> decorate(:tag => :employee),
                                               OPT|PLU)),
                      :Emp => RecordShape(
                                  OutputShape(NativeShape(String)
                                              |> decorate(:tag => :name)),
                                  ⋮
                                  OutputShape(ClassShape(:Emp)
                                              |> decorate(:tag => :subordinate),
                                              OPT|PLU))
                              |> decorate(:tag => :employee)),
            OPT|PLU))
    =#


## Shape ordering

The same data can satisfy many different shape constraints.  For example, a
vector `BlockVector([Chicago])` can be said to have, among others, the shape
`BlockShape(String)`, the shape `OutputShape(String, OPT|PLU)` or the shape
`AnyShape()`.  We can tell, for any two shapes, if one of them is more specific
than the other.

    fits(NativeShape(Int), NativeShape(Number))     #-> true
    fits(NativeShape(Int), NativeShape(String))     #-> false

    fits(ClassShape(:Emp), ClassShape(:Emp))        #-> true
    fits(ClassShape(:Emp), ClassShape(:Dept))       #-> false

    fits(ClassShape(:Emp),
         ClassShape(:Emp)
         |> rebind(:Emp => NativeShape(String)))    #-> false

    fits(ClassShape(:Emp),
         ClassShape(:Dept)
         |> rebind(:Emp => NativeShape(String)))    #-> false

    fits(ClassShape(:Emp)
         |> rebind(:Emp => NativeShape(String)),
         ClassShape(:Emp))                          #-> true

    fits(ClassShape(:Emp)
         |> rebind(:Emp => NativeShape(String)),
         ClassShape(:Emp)
         |> rebind(:Emp => NativeShape(String)))    #-> true

    fits(ClassShape(:Emp)
         |> rebind(:Emp => NativeShape(String)),
         ClassShape(:Dept)
         |> rebind(:Dept => NativeShape(String)))   #-> false

    fits(ClassShape(:Emp)
         |> rebind(:Emp => NativeShape(String)),
         ClassShape(:Emp)
         |> rebind(:Emp => NativeShape(Number)))    #-> false

    fits(BlockShape(Int), BlockShape(Number))       #-> true
    fits(BlockShape(Int), BlockShape(String))       #-> false

    fits(TupleShape(Int, BlockShape(String)),
         TupleShape(Number, BlockShape(String)))    #-> true
    fits(TupleShape(Int, BlockShape(String)),
         TupleShape(String, BlockShape(String)))    #-> false
    fits(TupleShape(Int),
         TupleShape(Number, BlockShape(String)))    #-> false

    fits(InputShape(Int,
                    [:X => OutputShape(Int),
                     :Y => OutputShape(String)],
                    true),
         InputShape(Number,
                    [:X => OutputShape(Int, OPT)])) #-> true
    fits(InputShape(Int),
         InputShape(Number, true))                  #-> false
    fits(InputShape(Int,
                    [:X => OutputShape(Int, OPT)]),
         InputShape(Number,
                    [:X => OutputShape(Int)]))      #-> false

    fits(OutputShape(Int),
         OutputShape(Number, OPT))                  #-> true
    fits(OutputShape(Int, PLU),
         OutputShape(Number, OPT))                  #-> false
    fits(OutputShape(Int),
         OutputShape(String, OPT))                  #-> false

    fits(RecordShape(OutputShape(Int),
                     OutputShape(String, OPT)),
         RecordShape(OutputShape(Number),
                     OutputShape(String, OPT|PLU)))     #-> true
    fits(RecordShape(OutputShape(Int, OPT),
                     OutputShape(String)),
         RecordShape(OutputShape(Number),
                     OutputShape(String, OPT|PLU)))     #-> false
    fits(RecordShape(OutputShape(Int)),
         RecordShape(OutputShape(Number),
                     OutputShape(String, OPT|PLU)))     #-> false

Shapes of different kinds are typically not compatible with each other.  The
exceptions are `AnyShape` and `NullShape`.

    fits(NativeShape(Int), ClassShape(:Emp))    #-> false
    fits(NativeShape(Int), AnyShape())          #-> true
    fits(NoneShape(), ClassShape(:Emp))         #-> true

Shape decorations are treated as additional shape constraints.

    fits(NativeShape(String) |> decorate(:tag => :name),
         NativeShape(String) |> decorate(:tag => :name))        #-> true
    fits(NativeShape(String),
         NativeShape(String) |> decorate(:tag => :name))        #-> false
    fits(NativeShape(String) |> decorate(:tag => :position),
         NativeShape(String))                                   #-> true
    fits(NativeShape(String) |> decorate(:tag => :position),
         NativeShape(String) |> decorate(:tag => :name))        #-> false

For any given number of shapes, we can find their upper bound, the shape that
is more general than each of them.  We can also find their lower bound.

    bound(NativeShape(Int), NativeShape(Number))
    #-> NativeShape(Number)
    ibound(NativeShape(Int), NativeShape(Number))
    #-> NativeShape(Int)

    bound(ClassShape(:Emp), ClassShape(:Emp))
    #-> ClassShape(:Emp)
    ibound(ClassShape(:Emp), ClassShape(:Emp))
    #-> ClassShape(:Emp)
    bound(ClassShape(:Emp), ClassShape(:Dept))
    #-> AnyShape()
    ibound(ClassShape(:Emp), ClassShape(:Dept))
    #-> NoneShape()
    bound(ClassShape(:Emp),
          ClassShape(:Emp) |> rebind(:Emp => NativeShape(String)))
    #-> ClassShape(:Emp)
    ibound(ClassShape(:Emp),
           ClassShape(:Emp) |> rebind(:Emp => NativeShape(String)))
    #-> ClassShape(:Emp) |> rebind(:Emp => NativeShape(String))
    bound(ClassShape(:Emp) |> rebind(:Emp => NativeShape(Number)),
          ClassShape(:Emp) |> rebind(:Emp => NativeShape(String)))
    #-> ClassShape(:Emp) |> rebind(:Emp => AnyShape())
    ibound(ClassShape(:Emp) |> rebind(:Emp => NativeShape(Number)),
           ClassShape(:Emp) |> rebind(:Emp => NativeShape(String)))
    #-> ClassShape(:Emp) |> rebind(:Emp => NoneShape())

    bound(BlockShape(Int), BlockShape(Number))
    #-> BlockShape(NativeShape(Number))
    ibound(BlockShape(Int), BlockShape(Number))
    #-> BlockShape(NativeShape(Int))

    bound(TupleShape(:Emp, BlockShape(String)),
          TupleShape(:Dept, BlockShape(String)))
    #-> TupleShape(AnyShape(), BlockShape(NativeShape(String)))
    ibound(TupleShape(:Emp, BlockShape(String)),
           TupleShape(:Dept, BlockShape(String)))
    #-> TupleShape(NoneShape(), BlockShape(NativeShape(String)))

    bound(InputShape(Int, [:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true),
          InputShape(Number, [:X => OutputShape(Int)]))
    #=>
    InputShape(NativeShape(Number), [:X => OutputShape(NativeShape(Int), OPT)])
    =#
    ibound(InputShape(Int, [:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true),
           InputShape(Number, [:X => OutputShape(Int)]))
    #=>
    InputShape(NativeShape(Int),
               [:X => OutputShape(NativeShape(Int)),
                :Y => OutputShape(NativeShape(String))],
               true)
    =#

    bound(OutputShape(String, OPT), OutputShape(String, PLU))
    #-> OutputShape(NativeShape(String), OPT|PLU)
    ibound(OutputShape(String, OPT), OutputShape(String, PLU))
    #-> OutputShape(NativeShape(String))

    bound(RecordShape(OutputShape(Int, PLU),
                      OutputShape(String, OPT)),
          RecordShape(OutputShape(Number),
                      OutputShape(:Emp, OPT|PLU)))
    #=>
    RecordShape(OutputShape(NativeShape(Number), PLU),
                OutputShape(AnyShape(), OPT|PLU))
    =#
    ibound(RecordShape(OutputShape(Int, PLU),
                       OutputShape(String, OPT)),
           RecordShape(OutputShape(Number),
                       OutputShape(:Emp, OPT|PLU)))
    #=>
    RecordShape(OutputShape(NativeShape(Int)), OutputShape(NoneShape(), OPT))
    =#

For decorated shapes, incompatible decoration constraints are replaced with
`nothing`.

    bound(NativeShape(String) |> decorate(:show => false, :tag => :name),
          NativeShape(String) |> decorate(:hide => true, :tag => :name))
    #-> NativeShape(String) |> decorate(:tag => :name)

    ibound(NativeShape(String) |> decorate(:show => false, :tag => :name),
           NativeShape(String) |> decorate(:hide => true, :tag => :name))
    #-> NativeShape(String) |> decorate(:hide => true, :show => false, :tag => :name)

    bound(NativeShape(String) |> decorate(:tag => :position),
          NativeShape(Number) |> decorate(:tag => :salary))
    #-> AnyShape()

    ibound(NativeShape(String) |> decorate(:tag => :position),
           NativeShape(Number) |> decorate(:tag => :salary))
    #-> NoneShape() |> decorate(:tag => nothing)

    bound(NativeShape(Int),
          NativeShape(Number) |> decorate(:tag => :salary))
    #-> NativeShape(Number)

    ibound(NativeShape(Int),
           NativeShape(Number) |> decorate(:tag => :salary))
    #-> NativeShape(Int) |> decorate(:tag => :salary)


## Query signature

The signature of a query is a pair of an `InputShape` object and an
`OutputShape` object.

    sig = Signature(InputShape(:Dept),
                    OutputShape(RecordShape(OutputShape(String) |> decorate(:tag => :name),
                                            OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :employee))))
    #-> Dept -> (name => String[1 .. 1], employee => Emp[0 .. ∞])[1 .. 1]

Different components of the signature can be easily extracted.

    shape(sig)
    #=>
    OutputShape(RecordShape(
                    OutputShape(NativeShape(String) |> decorate(:tag => :name)),
                    OutputShape(ClassShape(:Emp) |> decorate(:tag => :employee),
                                OPT|PLU)))
    =#

    ishape(sig)
    #-> InputShape(ClassShape(:Dept))

    domain(sig)
    #=>
    RecordShape(OutputShape(NativeShape(String) |> decorate(:tag => :name)),
                OutputShape(ClassShape(:Emp) |> decorate(:tag => :employee),
                            OPT|PLU))
    =#

    mode(sig)
    #-> OutputMode()

    idomain(sig)
    #-> ClassShape(:Dept)

    imode(sig)
    #-> InputMode()

