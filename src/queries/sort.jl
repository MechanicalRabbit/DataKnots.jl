#
# Sort a block vector.
#

sort_it(spec=nothing) = Query(sort_it, spec)

function sort_it(rt::Runtime, input::AbstractVector, spec)
    input isa SomeBlockVector || error("expected a block vector; got $input at\n$(sort_it(spec))")
    offs = offsets(input)
    elts = elements(input)
    perm = collect(1:length(elts))
    cr = cursor(BlockVector(offs, perm))
    o = ordering(elts, spec)
    _sort!(cr, o)
    return BlockVector(offs, elts[perm])
end

sort_by(spec=nothing) = Query(sort_by, spec)

function sort_by(rt::Runtime, input::AbstractVector, spec)
   input isa SomeBlockVector || error("expected a block vector of pairs; got $input at\n$(sort_by(spec))")
    offs = offsets(input)
    elts = elements(input)
    elts isa SomeTupleVector || error("expected a block vector of pairs; got $input at\n$(sort_by(spec))")
    cols = columns(elts)
    length(cols) == 2 || error("expected a block vector of pairs; got $input at\n$(sort_by(spec))")
    vals, keys = cols
    perm = collect(1:length(elts))
    cr = cursor(BlockVector(offs, perm))
    o = ordering(keys, spec)
    _sort!(cr, o)
    return BlockVector(offs, vals[perm])
end

function _sort!(cr, o)
    while !done(cr)
        next!(cr)
        if length(cr) > 1
            sort!(cr, Base.DEFAULT_UNSTABLE, o)
        end
    end
end

