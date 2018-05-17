#
# Grouping.
#

group_by(spec=nothing) = Query(group_by, spec)

function group_by(rt::Runtime, input::AbstractVector, spec)
    input isa SomeBlockVector || error("expected a block vector of pairs; got $input at\n$(sort_by(spec))")
    offs = offsets(input)
    elts = elements(input)
    elts isa SomeTupleVector || error("expected a block vector of pairs; got $input at\n$(sort_by(spec))")
    cols = columns(elts)
    length(cols) == 2 || error("expected a block vector of pairs; got $input at\n$(sort_by(spec))")
    vals, keys = cols
    perm = collect(1:length(elts))
    o = ordering(keys, spec)
    _sort!(offs, perm, o)
    offs1, offs2 = _group(offs, perm, o)
    keyperm = perm[view(offs2, 1:length(offs2)-1)]
    return BlockVector(offs1,
                       TupleVector(length(offs2)-1,
                                   AbstractVector[BlockVector(offs2, vals[perm]),
                                                  keys[keyperm]]))
end

function _group(offs, perm, o)
    sz = 0
    cr = cursor(BlockVector(offs, perm))
    while !done(cr)
        next!(cr)
        sz += length(cr)
        for k = 2:length(cr)
            if !Base.lt(o, cr[k-1], cr[k])
                sz -= 1
            end
        end
    end
    offs1 = Vector{Int}(undef, length(offs))
    offs1[1] = top1 = 1
    offs2 = Vector{Int}(undef, sz+1)
    offs2[1] = top2 = 1
    cr = cursor(BlockVector(offs, perm))
    while !done(cr)
        next!(cr)
        for k = 1:length(cr)
            if k > 1 && Base.lt(o, cr[k-1], cr[k])
                top1 += 1
                offs2[top1] = top2
            end
            top2 += 1
        end
        if !isempty(cr)
            top1 += 1
            offs2[top1] = top2
        end
        offs1[cr.pos+1] = top1
    end
    return offs1, offs2
end

