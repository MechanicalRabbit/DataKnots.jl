# Monadic Signature

In `DataKnots`, the structure of vectorized data is described using *shape*
objects.

    using DataKnots:
        OPT,
        PLU,
        REG,
        AnyShape,
        Cardinality,
        InputMode,
        InputShape,
        NativeShape,
        NoneShape,
        OutputMode,
        OutputShape,
        RecordShape,
        Signature,
        bound,
        cardinality,
        decorate,
        domain,
        fits,
        ibound,
        idomain,
        imode,
        ishape,
        isoptional,
        isplural,
        isregular,
        mode,
        shape


## Overview


## API Reference

```@autodocs
Modules = [DataKnots]
Pages = ["shapes.jl"]
```


## Test Suite


### Cardinality

Enumerated type `Cardinality` is used to constrain the cardinality of a data
block.  A block of data is called *regular* if it must contain exactly one
element; *optional* if it may have no elements; and *plural* if it may have
more than one element.  This gives us four different cardinality constraints.

    display(Cardinality)
    #=>
    Enum Cardinality:
    REG = 0x00
    OPT = 0x01
    PLU = 0x02
    OPT_PLU = 0x03
    =#

Cardinality values support bitwise operations.

    print(REG|OPT|PLU)          #-> OPT_PLU
    print(PLU&~PLU)             #-> REG

We can use predicates `isregular()`, `isoptional()`, `isplural()` to check
cardinality values.

    isregular(REG)              #-> true
    isregular(OPT)              #-> false
    isregular(PLU)              #-> false
    isoptional(OPT)             #-> true
    isoptional(PLU)             #-> false
    isplural(PLU)               #-> true
    isplural(OPT)               #-> false

There is a partial ordering defined on `Cardinality` values.  We can determine
the greatest and the least cardinality; the least upper bound and the greatest
lower bound of a collection of `Cardinality` values; and, for two `Cardinality`
values, determine whether one of the values is smaller than the other.

    print(bound(Cardinality))   #-> REG
    print(ibound(Cardinality))  #-> OPT_PLU

    print(bound(OPT, PLU))      #-> OPT_PLU
    print(ibound(PLU, OPT))     #-> REG

    fits(OPT, PLU)              #-> false
    fits(REG, OPT|PLU)          #-> true


### Data shapes

The structure of composite data is specified with *shape* objects.

`NativeShape` indicates a regular Julia value of a specific type.

    str_shp = NativeShape(String)
    #-> NativeShape(String)

    eltype(str_shp)
    #-> String

Two special shape types are used to indicate the value of any shape, and a value
that cannot exist.

    any_shp = AnyShape()
    #-> AnyShape()

    none_shp = NoneShape()
    #-> NoneShape()

`InputShape` and `OutputShape` describe the structure of the query input and
the query output.

To describe the query input, we specify the shape of the input elements, the
shapes of the parameters, and whether or not the input is framed.

    i_shp = InputShape(UInt, InputMode([:D => OutputShape(String)], true))
    #-> InputShape(UInt, InputMode([:D => OutputShape(String)], true))

    domain(i_shp)
    #-> NativeShape(UInt)

    mode(i_shp)
    #-> InputMode([:D => OutputShape(String)], true)

To describe the query output, we specify the shape and the cardinality of the
output elements.

    o_shp = OutputShape(Int, OPT|PLU)
    #-> OutputShape(Int, OPT | PLU)

    print(cardinality(o_shp))
    #-> OPT_PLU

    domain(o_shp)
    #-> NativeShape(Int)

    mode(o_shp)
    #-> OutputMode(OPT | PLU)

It is possible to decorate `InputShape` and `OutputShape` objects to specify
additional attributes.  Currently, we can specify the *label*.

    o_shp |> decorate(label=:output)
    #-> OutputShape(:output, Int, OPT | PLU)

RecordShape` specifies the shape of a record value where each field has a
certain shape and cardinality.

    dept_shp = RecordShape(OutputShape(:name, String),
                           OutputShape(:employee, UInt, OPT|PLU))
    #=>
    RecordShape(OutputShape(:name, String),
                OutputShape(:employee, UInt, OPT | PLU))
    =#

    emp_shp = RecordShape(OutputShape(:name, String),
                          OutputShape(:department, UInt),
                          OutputShape(:position, String),
                          OutputShape(:salary, Int),
                          OutputShape(:manager, UInt, OPT),
                          OutputShape(:subordinate, UInt, OPT|PLU))
    #=>
    RecordShape(OutputShape(:name, String),
                OutputShape(:department, UInt),
                OutputShape(:position, String),
                OutputShape(:salary, Int),
                OutputShape(:manager, UInt, OPT),
                OutputShape(:subordinate, UInt, OPT | PLU))
    =#

Using the combination of different shapes we can describe the structure of any
data source.

    db_shp = RecordShape(OutputShape(:department, dept_shp, OPT|PLU),
                         OutputShape(:employee, emp_shp, OPT|PLU))
    #=>
    RecordShape(OutputShape(:department,
                            RecordShape(OutputShape(:name, String),
                                        OutputShape(:employee, UInt, OPT | PLU)),
                            OPT | PLU),
                OutputShape(:employee,
                            RecordShape(
                                OutputShape(:name, String),
                                OutputShape(:department, UInt),
                                OutputShape(:position, String),
                                OutputShape(:salary, Int),
                                OutputShape(:manager, UInt, OPT),
                                OutputShape(:subordinate, UInt, OPT | PLU)),
                            OPT | PLU))
    =#


### Shape ordering

The same data can satisfy many different shape constraints.  For example, a
vector `BlockVector([Chicago])` can be said to have, among others, the shape
`OutputShape(String)`, the shape `OutputShape(String, OPT|PLU)` or the shape
`AnyShape()`.  We can tell, for any two shapes, if one of them is more specific
than the other.

    fits(NativeShape(Int), NativeShape(Number))     #-> true
    fits(NativeShape(Int), NativeShape(String))     #-> false

    fits(InputShape(Int,
                    InputMode([:X => OutputShape(Int),
                               :Y => OutputShape(String)],
                              true)),
         InputShape(Number,
                    InputMode([:X => OutputShape(Int, OPT)])))
    #-> true
    fits(InputShape(Int),
         InputShape(Number, InputMode(true)))
    #-> false
    fits(InputShape(Int,
                    InputMode([:X => OutputShape(Int, OPT)])),
         InputShape(Number,
                    InputMode([:X => OutputShape(Int)])))
    #-> false

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

    fits(NativeShape(Int), OutputShape(Int))    #-> false
    fits(NativeShape(Int), AnyShape())          #-> true
    fits(NoneShape(), NativeShape(Int))         #-> true

Shape decorations are treated as additional shape constraints.

    fits(OutputShape(:name, String),
         OutputShape(:name, String))                            #-> true
    fits(OutputShape(String),
         OutputShape(:position, String))                        #-> false
    fits(OutputShape(:position, String),
         OutputShape(String))                                   #-> true
    fits(OutputShape(:position, String),
         OutputShape(:name, String))                            #-> false

For any given number of shapes, we can find their upper bound, the shape that
is more general than each of them.  We can also find their lower bound.

    bound(NativeShape(Int), NativeShape(Number))
    #-> NativeShape(Number)
    ibound(NativeShape(Int), NativeShape(Number))
    #-> NativeShape(Int)

    bound(InputShape(Int, InputMode([:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true)),
          InputShape(Number, InputMode([:X => OutputShape(Int)])))
    #=>
    InputShape(Number, InputMode([:X => OutputShape(Int, OPT)]))
    =#
    ibound(InputShape(Int, InputMode([:X => OutputShape(Int, OPT), :Y => OutputShape(String)], true)),
           InputShape(Number, InputMode([:X => OutputShape(Int)])))
    #=>
    InputShape(Int,
               InputMode([:X => OutputShape(Int), :Y => OutputShape(String)],
                         true))
    =#

    bound(OutputShape(String, OPT), OutputShape(String, PLU))
    #-> OutputShape(String, OPT | PLU)
    ibound(OutputShape(String, OPT), OutputShape(String, PLU))
    #-> OutputShape(String)

    bound(RecordShape(OutputShape(Int, PLU),
                      OutputShape(String, OPT)),
          RecordShape(OutputShape(Number),
                      OutputShape(UInt, OPT|PLU)))
    #=>
    RecordShape(OutputShape(Number, PLU), OutputShape(AnyShape(), OPT | PLU))
    =#
    ibound(RecordShape(OutputShape(Int, PLU),
                       OutputShape(String, OPT)),
           RecordShape(OutputShape(Number),
                       OutputShape(UInt, OPT|PLU)))
    #=>
    RecordShape(OutputShape(Int), OutputShape(NoneShape(), OPT))
    =#

For decorated shapes, incompatible labels are replaed with an empty label.

    bound(OutputShape(:name, String), OutputShape(:name, String))
    #-> OutputShape(:name, String)

    ibound(OutputShape(:name, String), OutputShape(:name, String))
    #-> OutputShape(:name, String)

    bound(OutputShape(:position, String), OutputShape(:salary, Number))
    #-> OutputShape(AnyShape())

    ibound(OutputShape(:position, String), OutputShape(:salary, Number))
    #-> OutputShape(Symbol(""), NoneShape())

    bound(OutputShape(Int), OutputShape(:salary, Number))
    #-> OutputShape(Number)

    ibound(OutputShape(Int), OutputShape(:salary, Number))
    #-> OutputShape(:salary, Int)


### Query signature

The signature of a query is a pair of an `InputShape` object and an
`OutputShape` object.

    sig = Signature(InputShape(UInt),
                    OutputShape(RecordShape(OutputShape(:name, String),
                                            OutputShape(:employee, UInt, OPT|PLU))))
    #-> UInt -> (name => String[1 .. 1], employee => UInt[0 .. ∞])[1 .. 1]

Different components of the signature can be easily extracted.

    shape(sig)
    #=>
    OutputShape(RecordShape(OutputShape(:name, String),
                            OutputShape(:employee, UInt, OPT | PLU)))
    =#

    ishape(sig)
    #-> InputShape(UInt)

    domain(sig)
    #=>
    RecordShape(OutputShape(:name, String),
                OutputShape(:employee, UInt, OPT | PLU))
    =#

    mode(sig)
    #-> OutputMode()

    idomain(sig)
    #-> NativeShape(UInt)

    imode(sig)
    #-> InputMode()

