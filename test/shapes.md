# Type System

This module lets us describe the shape of the data.

    using QueryCombinators.Shapes


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

`IndexShape` indicates that the value is an index in a vector.  Its *class
name* is used to find the shape of the target vector.

    idx_shp = IndexShape(:Emp)
    #-> IndexShape(:Emp)

    class(idx_shp)
    #-> :Emp

A shape which does not contain any indexes is called closed.

    isclosed(idx_shp)
    #-> false

    isclosed(str_shp)
    #-> true

For a data block, `BlockShape` specifies its cardinality and the type of the
elements.

    blk_shp = BlockShape(OPT|PLU, IndexShape(:Emp))
    #-> BlockShape(OPT|PLU, IndexShape(:Emp))

    cardinality(blk_shp)
    #-> OPT|PLU

    blk_shp[]
    #-> IndexShape(:Emp)

`TupleShape` lets us specify the field types of a tuple value.

    tpl_shp = TupleShape(BlockShape(REG, NativeShape(String)),
                         BlockShape(OPT|PLU, IndexShape(:Emp)))
    #=>
    TupleShape(BlockShape(REG, NativeShape(String)),
               BlockShape(OPT|PLU, IndexShape(:Emp)))
    =#

    foreach(println, tpl_shp[:])
    #=>
    BlockShape(REG, NativeShape(String))
    BlockShape(OPT|PLU, IndexShape(:Emp))
    =#

Two special shape types are used to indicate that the value may have any shape,
or cannot exist.

    any_shp = AnyShape()
    #-> AnyShape()

    none_shp = NoneShape()
    #-> NoneShape()

By default, `AnyShape` is assumed open-ended, but we can also indicate that
it is closed.

    isclosed(AnyShape())
    #-> false

    isclosed(AnyShape(true))
    #-> true

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

`InputShape` and `OutputShape` are nominal shapes that describe the structure
of the query input and the query output.

To describe the query input, we specify the shape of the input elements, the
shapes of the parameters, and whether or not the input is framed.

    i_shp = InputShape(IndexShape(:Emp),
                       [:D => OutputShape(NativeShape(String))],
                       true)
    #-> InputShape(IndexShape(:Emp), [:D => OutputShape(NativeShape(String))], true)

    i_shp[]
    #-> IndexShape(:Emp)

To describe the query output, we specify the shape and the cardinality of the
output elements.

    o_shp = OutputShape(NativeShape(Int), OPT|PLU)
    #-> OutputShape(NativeShape(Int), OPT|PLU)

    o_shp[]
    #-> NativeShape(Int)

    cardinality(o_shp)
    #-> OPT|PLU

Function `denominalize()` converts a nominal shape to the underlying structural
shape.

    denominalize(i_shp)
    #-> BlockShape(PLU, TupleShape(IndexShape(:Emp), OutputShape(NativeShape(String))))

    denominalize(o_shp)
    #-> BlockShape(OPT|PLU, NativeShape(Int))

`CapsuleShape` encapsulates the value shape with the shapes of the indexes.
Using `CapsuleShape` we can fully specify self-referential data.

    dept_shp = TupleShape(OutputShape(String) |> decorate(:tag => :name),
                          OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :employee))

    emp_shp = TupleShape(OutputShape(String) |> decorate(:tag => :name),
                         OutputShape(:Dept) |> decorate(:tag => :department),
                         OutputShape(String) |> decorate(:tag => :position),
                         OutputShape(Int) |> decorate(:tag => :salary),
                         OutputShape(:Emp, OPT) |> decorate(:tag => :manager),
                         OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :subordinate))

    db_shp = TupleShape(OutputShape(:Dept, OPT|PLU) |> decorate(:tag => :department),
                        OutputShape(:Emp, OPT|PLU) |> decorate(:tag => :employee))

    CapsuleShape(db_shp, :Dept => dept_shp, :Emp => emp_shp)
    #=>
    CapsuleShape(
        TupleShape(OutputShape(IndexShape(:Dept) |> decorate(:tag => :department),
                               OPT|PLU),
                   OutputShape(IndexShape(:Emp) |> decorate(:tag => :employee),
                               OPT|PLU)),
        :Dept => TupleShape(
                     OutputShape(NativeShape(String) |> decorate(:tag => :name)),
                     OutputShape(IndexShape(:Emp) |> decorate(:tag => :employee),
                                 OPT|PLU)),
        :Emp =>
            TupleShape(
                OutputShape(NativeShape(String) |> decorate(:tag => :name)),
                OutputShape(IndexShape(:Dept) |> decorate(:tag => :department)),
                OutputShape(NativeShape(String) |> decorate(:tag => :position)),
                OutputShape(NativeShape(Int) |> decorate(:tag => :salary)),
                OutputShape(IndexShape(:Emp) |> decorate(:tag => :manager), OPT),
                OutputShape(IndexShape(:Emp) |> decorate(:tag => :subordinate),
                            OPT|PLU)))
    =#


## Shape ordering

The same data can satisfy many different shape constraints.  For example, a
vector `BlockVector([Chicago])` can be said to have, among others, the shape
`BlockShape(REG, String)`, the shape `BlockShape(OPT|PLU, Any)` or the shape
`AnyShape()`.  We can tell, for any two shapes, if one of them is more specific
than the other.

    fits(NativeShape(Int), NativeShape(Number))     #-> true
    fits(NativeShape(Int), NativeShape(String))     #-> false

    fits(IndexShape(:Emp), IndexShape(:Emp))        #-> true
    fits(IndexShape(:Emp), IndexShape(:Dept))       #-> false

    fits(BlockShape(REG, Int), BlockShape(OPT, Number))     #-> true
    fits(BlockShape(PLU, Int), BlockShape(OPT, Number))     #-> false
    fits(BlockShape(REG, Int), BlockShape(OPT, String))     #-> false

    fits(TupleShape(BlockShape(REG, Int),
                    BlockShape(OPT, String)),
         TupleShape(BlockShape(REG, Number),
                    BlockShape(OPT|PLU, String)))       #-> true
    fits(TupleShape(BlockShape(OPT, Int),
                    BlockShape(REG, String)),
         TupleShape(BlockShape(REG, Number),
                    BlockShape(OPT|PLU, String)))       #-> false
    fits(TupleShape(BlockShape(REG, Int)),
         TupleShape(BlockShape(REG, Number),
                    BlockShape(OPT|PLU, String)))       #-> false

Shapes of different kinds are typically not compatible with each other.  The
exceptions are `AnyShape` and `NullShape`.

    fits(NativeShape(Int), IndexShape(:Emp))    #-> false
    fits(NativeShape(Int), AnyShape())          #-> true
    fits(NoneShape(), IndexShape(:Emp))         #-> true

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

    bound(IndexShape(:Emp), IndexShape(:Emp))
    #-> IndexShape(:Emp)
    ibound(IndexShape(:Emp), IndexShape(:Emp))
    #-> IndexShape(:Emp)
    bound(IndexShape(:Emp), IndexShape(:Dept))
    #-> AnyShape()
    ibound(IndexShape(:Emp), IndexShape(:Dept))
    #-> NoneShape()

    bound(BlockShape(OPT, String), BlockShape(PLU, String))
    #-> BlockShape(OPT|PLU, NativeShape(String))
    ibound(BlockShape(OPT, String), BlockShape(PLU, String))
    #-> BlockShape(REG, NativeShape(String))

    bound(TupleShape(BlockShape(OPT, :Emp), BlockShape(REG, String)),
          TupleShape(BlockShape(OPT, :Dept), BlockShape(PLU, String)))
    #-> TupleShape(BlockShape(OPT, AnyShape()), BlockShape(PLU, NativeShape(String)))
    ibound(TupleShape(BlockShape(OPT, :Emp), BlockShape(REG, String)),
           TupleShape(BlockShape(OPT, :Dept), BlockShape(PLU, String)))
    #-> TupleShape(BlockShape(OPT, NoneShape()), BlockShape(REG, NativeShape(String)))

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
    #-> AnyShape(true)

    ibound(NativeShape(String) |> decorate(:tag => :position),
           NativeShape(Number) |> decorate(:tag => :salary))
    #-> NoneShape() |> decorate(:tag => nothing)

    bound(NativeShape(Int),
          NativeShape(Number) |> decorate(:tag => :salary))
    #-> NativeShape(Number)

    ibound(NativeShape(Int),
           NativeShape(Number) |> decorate(:tag => :salary))
    #-> NativeShape(Int) |> decorate(:tag => :salary)

