#
# Correlate two vectors.
#

correlate() = Query(correlate)

function correlate(rt::Runtime, input::AbstractVector)
    input isa SomeTupleVector && width(input) == 2 || error("expected a pair vector; got $input\nat $(correlate())")
    len = length(input)
    main, dict = columns(input)
    main isa SomeBlockVector || error("expected a block vector; got $main\nat $(correlate())")
    mainoffs = offsets(main)
    mainelts = elements(main)
    mainelts isa SomeTupleVector && width(mainelts) == 2 || error("expected a pair vector; got $mainelts\nat $(correlate())")
    dict isa SomeBlockVector || error("expected a block vector; got $dict\nat $(correlate())")
    dictoffs = offsets(dict)
    dictelts = elements(dict)
    dictelts isa SomeTupleVector && width(dictelts) == 2 || error("expected a pair vector; got $dictelts\nat $(correlate())")
    o = ordering_pair(column(dictelts, 1), column(mainelts, 1))
    slices = _correlate(len, dictoffs, mainoffs, o)
    sz = 0
    for slice in slices
        sz += length(slice)
    end
    offs = Vector{Int}(undef, length(slices)+1)
    perm = Vector{Int}(undef, sz)
    offs[1] = top = 1
    for k = 1:lastindex(slices)
        slice = slices[k]
        copyto!(perm, top, slice)
        top += length(slice)
        offs[k+1] = top
    end
    vals = column(dictelts, 2)[perm]
    output = BlockVector(mainoffs, TupleVector(length(mainelts), AbstractVector[column(mainelts, 2), BlockVector(offs, vals)]))
    output
end

function _correlate(len, dictoffs, mainoffs, o)
    slices = Vector{UnitRange{Int}}(undef, mainoffs[end]-1)
    p = 1
    for k = 1:len
        @inbounds v = dictoffs[k]:dictoffs[k+1]-1
        for x = mainoffs[k]:mainoffs[k+1]-1
            slice = searchsorted(v, -x, 1, length(v), o)
            slices[p] = slice
            p += 1
        end
    end
    slices
end

