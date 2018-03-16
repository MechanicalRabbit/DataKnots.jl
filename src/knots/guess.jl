#
# Guessing the shape of a vector.
#

guessshape(v::AbstractVector) =
    NativeShape(eltype(v))

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
    IndexShape(iv.ident)

guessshape(cv::CapsuleVector) =
    CapsuleShape(guessshape(cv.vals), [ref.first => guessshape(ref.second) for ref in cv.refs])

