#
# Guessing the shape of a vector.
#

guessshape(shp::AbstractShape, v) =
    shp

guessshape(::AnyShape, v) =
    guessshape(v)

guessshape(shp::DecoratedShape, v) =
    let base′ = guessshape(shp.base, v)
        base′ == shp.base ? shp : DecoratedShape(base′, shp.decors)
    end

function guessshape(shp::RecordShape, v::AbstractVector)
    flds′ = OutputShape[]
    for (k, fld) in enumerate(shp[:])
        fld′ = guessshape(fld, column(v, k))
        push!(flds′, fld′)
    end
    flds′ == shp.flds ? shp : RecordShape(flds′)
end

guessshape(shp::OutputShape, v) =
    let dom′ = guessshape(shp.dom, elements(v))
        dom′ == shp.dom ? shp : OutputShape(dom′, shp.md)
    end

guessshape(v::AbstractVector) =
    let T = eltype(v)
        T == Any ? AnyShape() : NativeShape(T)
    end

function guessshape(tv::TupleVector)
    cols = columns(tv)
    lbls = labels(tv)
    if !isempty(cols) && all(col -> col isa BlockVector, cols)
        colshapes = OutputShape[]
        for col in cols
            offs = offsets(col)
            card = REG
            if !(offs isa Base.OneTo)
                l = 0
                for r in offs
                    d = r - l
                    l = r
                    if d < 1
                        card |= OPT
                    end
                    if d > 1
                        card |= PLU
                    end
                    if card == OPT|PLU
                        break
                    end
                end
            end
            push!(colshapes, OutputShape(guessshape(elements(col)), card))
        end
        if !isempty(lbls)
            colshapes = [shp |> decorate(:tag => lbl) for (shp, lbl) in zip(colshapes, lbls)]
        end
        return RecordShape(colshapes)
    else
        colshapes = guessshape.(cols)
        if !isempty(lbls)
            colshapes = [shp |> decorate(:tag => lbl) for (shp, lbl) in zip(colshapes, lbls)]
        end
        TupleShape(colshapes)
    end
end

guessshape(bv::BlockVector) =
    BlockShape(guessshape(bv.elts))

guessshape(iv::IndexVector) =
    ClassShape(iv.ident)

guessshape(cv::CapsuleVector) =
    guessshape(cv.vals) |> rebind((ref.first => guessshape(ref.second) for ref in cv.refs)...)

