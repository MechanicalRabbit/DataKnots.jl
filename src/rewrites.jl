#
# Optimizing pipelines.
#

import Base:
    append!,
    convert,
    delete!,
    getindex,
    isempty,
    merge,
    prepend!,
    size


#
# Mutable representation of the pipeline tree.
#

mutable struct Chain{T}
    up::Union{T,Nothing}
    up_idx::Int
    down_head::Union{T,Nothing}
    down_tail::Union{T,Nothing}

    Chain{T}() where {T} =
        new(nothing, 0, nothing, nothing)
end

isempty(c::Chain{T}) where {T} =
    c.down_head === c.down_tail === nothing

mutable struct PipelineNode
    op
    args::Vector{Any}
    left::Union{PipelineNode,Nothing}
    right::Union{PipelineNode,Nothing}
    up::Union{Chain{PipelineNode},Nothing}
    down::Union{Chain{PipelineNode},Nothing}
    down_many::Union{Vector{Chain{PipelineNode}},Nothing}

    PipelineNode(op, args::Vector{Any}=Any[]) =
        new(op, args, nothing, nothing, nothing, nothing, nothing)
end

const PipelineChain = Chain{PipelineNode}

@inline size(p::PipelineNode) = size(p.down_many)

@inline getindex(p::PipelineNode) = p.down

@inline getindex(p::PipelineNode, k::Number) = p.down_many[k]

function delete!(p::PipelineNode)
    l = p.left
    r = p.right
    u = p.up
    if l !== nothing
        @assert l.right === p
        if r === nothing
            @assert l.left !== nothing || l.up === u
            l.up = u
        end
        l.right = r
    end
    if r !== nothing
        @assert r.left === p
        if l === nothing
            @assert r.right !== nothing || r.up === u
            r.up = u
        end
        r.left = l
    end
    if u !== nothing
        @assert l === nothing || r === nothing
        if l === nothing
            @assert u.down_head === p
            u.down_head = r
        end
        if r === nothing
            @assert u.down_tail === p
            u.down_tail = l
        end
    end
    p.left = p.right = p.up = nothing
end

function append!(c::PipelineChain, p::PipelineNode)
    t = c.down_tail
    if t !== nothing
        @assert t.right === nothing && t.up === c
        t.right = p
        if t.left !== nothing
            t.up = nothing
        end
    end
    @assert p.left === p.right === p.up === nothing
    p.left = t
    p.up = c
    if c.down_head === nothing
        c.down_head = p
    end
    c.down_tail = p
end

function append!(l::PipelineNode, p::PipelineNode)
    r = l.right
    u = l.up
    l.right = p
    if l.left !== nothing
        l.up = nothing
    end
    if r !== nothing
        @assert r.left === l
        r.left = p
    else
        @assert u === nothing || u.down_tail === l
        if u !== nothing
            u.down_tail = p
        end
    end
    @assert p.left === p.right === p.up === nothing
    p.left = l
    p.right = r
    if r === nothing
        p.up = u
    end
end

function prepend!(r::PipelineNode, p::PipelineNode)
    l = r.left
    u = r.up
    r.left = p
    if r.right !== nothing
        r.up = nothing
    end
    if l !== nothing
        @assert l.right === r
        l.right = p
    else
        @assert u === nothing || u.down_head === r
        if u !== nothing
            u.down_head = p
        end
    end
    @assert p.left === p.right === p.up === nothing
    p.left = l
    p.right = r
    if l === nothing
        p.up = u
    end
end


#
# Conversion between mutable and immutable representations.
#

function convert(::Type{Pipeline}, p::PipelineNode)::Pipeline
    args = copy(p.args)
    if p.down !== nothing
        push!(args, convert(Pipeline, p.down))
    end
    if p.down_many !== nothing
        push!(args, Pipeline[convert(Pipeline, c) for c in p.down_many])
    end
    Pipeline(p.op, args=args)
end

function convert(::Type{Pipeline}, c::PipelineChain)::Pipeline
    if c.down_head === c.down_tail === nothing
        pass()
    elseif c.down_head === c.down_tail
        convert(Pipeline, c.down_head)
    else
        chain = Pipeline[convert(Pipeline, c.down_head)]
        p = c.down_head
        while p !== c.down_tail
            p = p.right
            @assert p !== nothing
            push!(chain, convert(Pipeline, p))
        end
        chain_of(chain)
    end
end

function convert(::Type{PipelineChain}, p::Pipeline)::PipelineChain
    if p.op === pass && isempty(p.args)
        PipelineChain()
    elseif p.op === chain_of && length(p.args) == 1 && p.args[1] isa Vector{Pipeline}
        c = PipelineChain()
        for q in p.args[1]
            c′ = convert(PipelineChain, q)
            if c.down_head === c.down_tail === nothing
                c = c′
            elseif !(c′.down_head === c′.down_tail === nothing)
                c.down_tail.up = nothing
                c.down_tail.right = c′.down_head
                c′.down_head.up = nothing
                c′.down_head.left = c.down_tail
                c.down_head.up = c
                c′.down_tail.up = c
                c.down_tail = c′.down_tail
            end
        end
        c
    else
        args = copy(p.args)
        down_many = nothing
        if !isempty(args) && args[end] isa Vector{Pipeline}
            qs = pop!(args)
            down_many = PipelineChain[convert(PipelineChain, q) for q in qs]
        end
        down = nothing
        if !isempty(args) && args[end] isa Pipeline
            q = pop!(args)
            down = convert(PipelineChain, q)
        end
        p = PipelineNode(p.op, args)
        if down !== nothing
            down.up = p
            p.down = down
        end
        if down_many !== nothing
            for (n, c) in enumerate(down_many)
                c.up = p
                c.up_idx = n
            end
            p.down_many = down_many
        end
        c = PipelineChain()
        p.up = c
        c.down_head = c.down_tail = p
        c
    end
end


#
# Representation.
#

quoteof(p::Union{PipelineNode, PipelineChain}) =
    quoteof(convert(Pipeline, p))

show(io::IO, p::Union{PipelineNode, PipelineChain}) =
    print_expr(io, quoteof(p))


#
# Multi-pass pipeline optimizer.
#

function rewrite_all(p::Pipeline)::Pipeline
    sig = signature(p)
    c = convert(PipelineChain, p)
    rewrite_all!(c, sig)
    p′ = convert(Pipeline, c) |> designate(sig)
    p′
end

function rewrite_all!(c::PipelineChain, sig::Signature)
    rewrite_simplify!(c)
    rewrite_dead!(c)
end

function rewrite_with!(f!, p::PipelineNode)
    if p.down !== nothing
        f!(p.down)
    end
    if p.down_many !== nothing
        for c in p.down_many
            f!(c)
        end
    end
end

function rewrite_with!(f!, c::PipelineChain)
    p = c.down_head
    while p !== nothing
        p′ = p.right
        f!(p)
        p = p′
    end
end


#
# Local simplification.
#

function rewrite_simplify(p::Pipeline)::Pipeline
    sig = signature(p)
    c = convert(PipelineChain, p)
    rewrite_simplify!(c)
    p′ = convert(Pipeline, c) |> designate(sig)
    p′
end

function rewrite_simplify!(c::PipelineChain)
    rewrite_with!(rewrite_simplify!, c)
end

function rewrite_simplify!(p::PipelineNode)
    rewrite_with!(rewrite_simplify!, p)
    simplify!(p)
end

function simplify!(p::PipelineNode)
    l = p.left
    # with_elements(pass()) => pass()
    if p.op === with_elements && p.down !== nothing && isempty(p.down)
        delete!(p)
    # with_column(k, pass()) => pass()
    elseif p.op === with_column && p.down !== nothing && isempty(p.down)
        delete!(p)
    # chain_of(p, filler(val)) => filler(val)
    elseif p.op === filler || p.op === block_filler || p.op === null_filler
        while p.left !== nothing
            delete!(p.left)
        end
    elseif l !== nothing
        # chain_of(tuple_of(p1, ..., pn), column(k)) => pk
        if l.op === tuple_of && p.op === column
            @assert length(l.args) == 1 && l.args[1] isa Vector{Symbol} && l.down_many !== nothing
            @assert length(p.args) == 1 && p.args[1] isa Union{Int,Symbol}
            lbls = l.args[1]::Vector{Symbol}
            lbl = p.args[1]::Union{Int,Symbol}
            k = lbl isa Symbol ? findfirst(isequal(lbl), lbls) : lbl
            @assert 1 <= k <= length(l.down_many)
            c = l.down_many[k]
            while !isempty(c)
                q = c.down_head
                delete!(q)
                prepend!(l, q)
                simplify!(q)
            end
            delete!(l)
            delete!(p)
        # chain_of(tuple_of(..., pk, ...), with_column(k, q)) => tuple_of(..., chain_of(pk, q), ...)
        elseif l.op === tuple_of && p.op === with_column
            @assert length(l.args) == 1 && l.args[1] isa Vector{Symbol} && l.down_many !== nothing
            @assert length(p.args) == 1 && p.args[1] isa Union{Int,Symbol} && p.down !== nothing
            lbls = l.args[1]::Vector{Symbol}
            lbl = p.args[1]::Union{Int,Symbol}
            k = lbl isa Symbol ? findfirst(isequal(lbl), lbls) : lbl
            @assert 1 <= k <= length(l.down_many)
            c = l.down_many[k]
            c′ = p.down
            while !isempty(c′)
                q = c′.down_head
                delete!(q)
                append!(c, q)
                simplify!(q)
            end
            delete!(p)
        # chain_of(tuple_of(chain_of(p, wrap()), ...), tuple_lift(f)) => chain_of(tuple_of(p, ...), tuple_lift(f))
        elseif l.op === tuple_of && p.op === tuple_lift
            @assert length(l.args) == 1 && l.down_many !== nothing
            for c in l.down_many
                if c.down_tail !== nothing && c.down_tail.op === wrap
                    delete!(c.down_tail)
                end
            end
        # chain_of(with_column(k, chain_of(p, wrap())), distribute(k)) => chain_of(with_column(k, p), wrap())
        elseif l.op === with_column && l.down !== nothing && !isempty(l.down) && l.down.down_tail.op === wrap &&
               p.op === distribute && length(l.args) == 1 && length(p.args) == 1 && l.args[1] == p.args[1]
            q = l.down.down_tail
            delete!(q)
            if isempty(l.down)
                delete!(l)
            end
            append!(p, q)
            delete!(p)
        # chain_of(wrap(), flatten()) => pass()
        elseif l.op === wrap && p.op === flatten
            delete!(l)
            delete!(p)
        # chain_of(wrap(), with_elements(p)) => chain_of(p, wrap())
        elseif l.op === wrap && p.op === with_elements
            c = p.down
            @assert c !== nothing
            while !isempty(c)
                q = c.down_head
                delete!(q)
                prepend!(l, q)
                simplify!(q)
            end
            delete!(p)
            simplify!(l)
        # chain_of(wrap(), lift(f)) => lift(f)
        elseif l.op === wrap && p.op === lift
            delete!(l)
        # chain_of(with_elements(p), with_elements(q)) => with_elements(chain_of(p, q))
        elseif l.op === with_elements && p.op === with_elements
            @assert l.down !== nothing && p.down !== nothing
            while !isempty(p.down)
                q = p.down.down_head
                delete!(q)
                append!(l.down, q)
                simplify!(q)
            end
            delete!(p)
        # chain_of(with_elements(chain_of(p, wrap())), flatten()) => with_elements(p)
        elseif l.op === with_elements && l.down !== nothing && !isempty(l.down) && l.down.down_tail.op === wrap && p.op === flatten
            delete!(l.down.down_tail)
            if isempty(l.down)
                delete!(l)
            end
            delete!(p)
        end
    end
end


#
# Dead wire elimination.
#

function rewrite_dead!(c::PipelineChain)
    v = Dict{PipelineNode,Signature}()
    visibility!(v, c, AnyShape())
    for (p, sig) in v
        if target(sig) isa NoShape
            c = p.up
            delete!(p)
            while c !== nothing && isempty(c) && c.up !== nothing && (c.up.op === with_elements || c.up.op == with_column)
                p = c.up
                c = p.up
                delete!(p)
            end
        end
    end
end

function visibility!(v::Dict{PipelineNode,Signature}, c::PipelineChain, tgt::AbstractShape)
    p = c.down_tail
    while p !== nothing
        src = visibility!(v, p, tgt)
        v[p] = Signature(src, tgt)
        tgt = src
        p = p.left
    end
    tgt
end

function visibility!(v::Dict{PipelineNode,Signature}, p::PipelineNode, tgt::AbstractShape)
    if tgt isa NoShape
        src = tgt
    elseif p.op === filler
        src = NoShape()
    elseif p.op === null_filler || p.op === block_filler
        @assert tgt isa Union{BlockOf, AnyShape}
        src = NoShape()
    elseif p.op === tuple_of
        @assert length(p.args) == 1 && p.args[1] isa Vector{Symbol}
        @assert p.down_many !== nothing
        @assert tgt isa Union{TupleOf, AnyShape}
        lbls = p.args[1]
        src = NoShape()
        for (k, c) in enumerate(p.down_many)
            if tgt isa TupleOf
                tgt_lbls = labels(tgt)
                tgt_cols = columns(tgt)
                if !isempty(lbls)
                    lbl = lbls[k]
                    k = findfirst(isequal(lbl), tgt_lbls)
                end
                col_tgt = k !== nothing && 1 <= k <= length(tgt_cols) ? tgt_cols[k] : NoShape()
            else
                col_tgt = tgt
            end
            col_src = visibility!(v, c, col_tgt)
            src = visibility_union(src, col_src)
        end
    elseif p.op === with_elements
        @assert tgt isa Union{BlockOf, AnyShape}
        @assert p.down !== nothing
        elt_tgt = tgt isa BlockOf ? elements(tgt) : tgt
        elt_src = visibility!(v, p.down, elt_tgt)
        src = elt_src isa AnyShape ? elt_src : BlockOf(elt_src)
    elseif p.op === with_column
        @assert length(p.args) == 1 && p.args[1] isa Union{Symbol, Number}
        @assert tgt isa Union{TupleOf, AnyShape}
        @assert p.down !== nothing
        lbl = p.args[1]
        if tgt isa TupleOf
            lbls = labels(tgt)
            cols = columns(tgt)
            k = lbl isa Symbol ? findfirst(isequal(lbl), lbls) :
                1 <= lbl <= length(cols) ? lbl : nothing
            col_tgt = k !== nothing ? cols[k] : NoShape()
            col_src = visibility!(v, p.down, col_tgt)
            if k !== nothing
                cols = copy(cols)
                cols[k] = col_src
            end
            src = TupleOf(lbls, cols)
        else
            src = tgt
        end
    elseif p.op === wrap
        @assert tgt isa Union{BlockOf, AnyShape}
        src = tgt isa BlockOf ? elements(tgt) : tgt
    elseif p.op === flatten
        @assert tgt isa Union{BlockOf, AnyShape}
        src = tgt isa BlockOf ? BlockOf(tgt) : tgt
    elseif p.op === distribute
        @assert length(p.args) == 1 && p.args[1] isa Union{Symbol, Number}
        @assert tgt isa Union{BlockOf, AnyShape}
        if tgt isa BlockOf
            lbl = p.args[1]
            elt_tgt = elements(tgt)
            @assert elt_tgt isa Union{TupleOf, NoShape, AnyShape}
            if elt_tgt isa TupleOf
                lbls = labels(elt_tgt)
                cols = columns(elt_tgt)
                k = lbl isa Symbol ? findfirst(isequal(lbl), lbls) :
                    1 <= lbl <= length(cols) ? lbl : nothing
                col_tgt = k !== nothing ? cols[k] : NoShape()
                col_src = BlockOf(col_tgt)
                if k !== nothing
                    cols = copy(cols)
                    cols[k] = col_src
                elseif lbl isa Symbol
                    k = searchsortedfirst(lbls, lbl)
                    lbls = copy(lbls)
                    insert!(lbls, k, lbl)
                    cols = copy(cols)
                    insert!(cols, k, col_src)
                else
                    cols = copy(cols)
                    while length(cols) < lbl - 1
                        push!(cols, NoShape())
                    end
                    push!(cols, col_src)
                end
                src = TupleOf(lbls, cols)
            elseif elt_tgt isa NoShape
                if lbl isa Symbol
                    src = TupleOf(lbl => BlockOf(elt_tgt))
                else
                    cols = AbstractShape[]
                    for k = 1:lbl-1
                        push!(cols, NoShape())
                    end
                    push!(cols, tgt)
                    src = TupleOf(cols)
                end
            else
                src = elt_tgt
            end
        else
            src = tgt
        end
    elseif p.op === column
        @assert length(p.args) == 1 && p.args[1] isa Union{Symbol, Number}
        lbl = p.args[1]
        if lbl isa Symbol
            src = TupleOf(lbl => tgt)
        else
            cols = AbstractShape[]
            for k = 1:lbl-1
                push!(cols, NoShape())
            end
            push!(cols, tgt)
            src = TupleOf(cols)
        end
    elseif p.op === sieve_by
        @assert tgt isa Union{BlockOf, AnyShape}
        src = tgt isa BlockOf ? TupleOf(elements(tgt), AnyShape()) : tgt
    elseif p.op === block_length
        src = BlockOf(NoShape())
    else
        src = AnyShape()
    end
    src
end

function visibility_union(shp1::AbstractShape, shp2::AbstractShape)
    @assert shp1 isa Union{NoShape, AnyShape} || shp2 isa Union{NoShape, AnyShape}
    if shp1 isa AnyShape || shp2 isa NoShape
        return shp1
    elseif shp1 isa NoShape || shp2 isa AnyShape
        return shp2
    end
end

function visibility_union(shp1::BlockOf, shp2::BlockOf)
    elt_shp = visibility_union(elements(shp1), elements(shp2))
    elt_shp isa AnyShape ? elt_shp : BlockOf(elt_shp)
end

function visibility_union(shp1::TupleOf, shp2::TupleOf)
    lbls1 = labels(shp1)
    cols1 = columns(shp1)
    lbls2 = labels(shp2)
    cols2 = columns(shp2)
    lbls = Symbol[]
    cols = AbstractShape[]
    k1 = k2 = 1
    while k1 <= length(cols1) || k2 <= length(cols2)
        if k1 <= length(lbls1) && k2 <= length(lbls2) && lbls1[k1] < lbls2[k2] || k2 > length(cols2)
            if k1 <= length(lbls1)
                push!(lbls, lbls1[k1])
            end
            push!(cols, cols1[k1])
            k1 += 1
        elseif k1 <= length(lbls1) && k2 <= length(lbls2) && lbls1[k1] > lbls2[k2] || k1 > length(cols1)
            if k2 <= length(lbls2)
                push!(lbls, lbls2[k2])
            end
            push!(cols, cols2[k2])
            k2 += 1
        else
            col_shp = visibility_union(cols1[k1], cols2[k2])
            if k1 <= length(lbls1) && k2 <= length(lbls2)
                push!(lbls, lbls1[k1])
            end
            push!(cols, col_shp)
            k1 += 1
            k2 += 1
        end
    end
    TupleOf(lbls, cols)
end

