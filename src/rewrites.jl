#
# Optimizing pipelines.
#

struct RewriteMemo
    op_map::Dict{Any,Dict{Vector{Any},Pipeline}}

    RewriteMemo() = new(Dict{Any,Dict{Vector{Any},Pipeline}}())
end

function (memo::RewriteMemo)(p::Pipeline)
    args_map = get!(memo.op_map, p.op) do
        Dict{Vector{Any},Pipeline}()
    end
    get!(args_map, p.args) do
        p
    end
end

function (memo::RewriteMemo)(ps::Vector{Pipeline})
    if isempty(ps)
        memo(pass())
    elseif length(ps) == 1
        memo(ps[1])
    else
        memo(chain_of(ps))
    end
end

function unchain(p)
    if p.op === pass
        return Pipeline[]
    elseif p.op === chain_of
        return collect(Pipeline, p.args[1])
    else
        return Pipeline[p]
    end
end

function rewrite_all(p::Pipeline; memo=RewriteMemo())::Pipeline
    rewrite_common(rewrite_simplify(p, memo=memo), memo=memo)
end

@inline function rewrite_with(f, memo, p)
    @match_pipeline if (p ~ chain_of(qs))
        chain = Pipeline[]
        for q in qs
            append!(chain, unchain(f(memo, q)))
        end
        return memo(chain)
    end
    args = Any[f(memo, arg) for arg in p.args]
    memo(Pipeline(p.op, args=args))
end


#
# Local simplification.
#

function rewrite_simplify(p::Pipeline; memo=RewriteMemo())::Pipeline
    rewrite_simplify(memo, p) |> designate(p.sig)
end

function rewrite_simplify(memo::RewriteMemo, p::Pipeline)
    @match_pipeline if (p ~ chain_of(_))
        chain = Pipeline[]
        simplify_and_push!(memo, chain, p)
        return memo(chain)
    end
    p′ = rewrite_with(rewrite_simplify, memo, p)
    # with_column(N, pass()) => pass()
    @match_pipeline if (p′ ~ with_column(_, pass()))
        p′ =  memo(pass())
    # with_elements(pass()) => pass()
    elseif (p′ ~ with_elements(pass()))
        p′ = memo(pass())
    end
    p′
end

rewrite_simplify(memo::RewriteMemo, ps::Vector{Pipeline}) =
    Pipeline[rewrite_simplify(memo, p) for p in ps]

rewrite_simplify(memo::RewriteMemo, @nospecialize other) = other

function simplify_and_push!(memo::RewriteMemo, chain::Vector{Pipeline}, p::Pipeline)
    top = !isempty(chain) ? chain[end] : memo(pass())
    @match_pipeline if (p ~ pass())
    elseif (p ~ chain_of(qs))
        for q in qs
            if (q ~ chain_of(_))
                simplify_and_push!(memo, chain, q)
            else
                simplify_and_push!(memo, chain, rewrite_simplify(memo, q))
            end
        end
    elseif (p ~ tuple_of(lbls, cols))
        head = nothing
        for col in cols
            if (col ~ chain_of([q, _...]))
                col = q
            end
            if (col ~ filler(_)) || (col ~ block_filler(_, _)) || (col ~ null_filler())
            elseif (col ~ column(k)) && (head === nothing || head === col)
                head = col
            else
                head = missing
                break
            end
        end
        if head === missing
            push!(chain, p)
        elseif head === nothing
            empty!(chain)
            push!(chain, p)
        else
            cols′ = Pipeline[]
            for col in cols
                if col === head
                    col = memo(pass())
                elseif (col ~ chain_of([q, qs...]))
                    if q === head
                        col = memo(qs)
                    end
                end
                push!(cols′, col)
            end
            simplify_and_push!(memo, chain, head)
            simplify_and_push!(memo, chain, memo(tuple_of(lbls, cols′)))
        end
    # chain_of(p, filler(val)) => filler(val)
    elseif (p ~ filler(_)) || (p ~ block_filler(_, _)) || (p ~ null_filler())
        empty!(chain)
        push!(chain, p)
    # chain_of(tuple_of(p1, ..., pn), column(k)) => pk
    elseif (top ~ tuple_of(lbls, cols)) && (p ~ column(lbl))
        k = lbl isa Symbol ? findfirst(isequal(lbl), lbls) : lbl
        qs = unchain(cols[k])
        pop!(chain)
        for q in qs
            simplify_and_push!(memo, chain, q)
        end
    # chain_of(tuple_of(..., pk, ...), with_column(k, q)) => tuple_of(..., chain_of(pk, q), ...)
    elseif (top ~ tuple_of(lbls, cols)) && (p ~ with_column(lbl, q))
        k = lbl isa Symbol ? findfirst(isequal(lbl), lbls) : lbl
        pop!(chain)
        qs = unchain(cols[k])
        simplify_and_push!(memo, qs, q)
        cols′ = copy(cols)
        cols′[k] = memo(qs)
        simplify_and_push!(memo, chain, memo(tuple_of(lbls, cols′)))
    # chain_of(tuple_of(chain_of(p, wrap()), ...), tuple_lift(f)) => chain_of(tuple_of(p, ...), tuple_lift(f))
    elseif (top ~ tuple_of(lbls, cols)) && (p ~ tuple_lift(_))
        cols′ = Pipeline[]
        for col in cols
            qs = unchain(col)
            while (qs ~ [_..., wrap()])
                pop!(qs)
            end
            push!(cols′, memo(qs))
        end
        pop!(chain)
        push!(chain, memo(tuple_of(lbls, cols′)))
        push!(chain, p)
    # chain_of(with_column(k, wrap()), distribute(k)) => wrap()
    elseif (top ~ with_column(j, wrap())) && (p ~ distribute(k)) && j == k
        pop!(chain)
        simplify_and_push!(memo, chain, memo(wrap()))
    # chain_of(with_column(k, chain_of(p, wrap())), distribute(k)) => chain_of(with_column(k, p), wrap())
    elseif (top ~ with_column(j, chain_of([qs..., wrap()]))) && (p ~ distribute(k)) && j == k
        pop!(chain)
        push!(chain, memo(with_column(k, memo(qs))))
        push!(chain, memo(wrap()))
    # chain_of(wrap(), flatten()) => pass()
    elseif (top ~ wrap()) && (p ~ flatten())
        pop!(chain)
    # chain_of(wrap(), with_elements(p)) => chain_of(p, wrap())
    elseif (top ~ wrap()) && (p ~ with_elements(q))
        pop!(chain)
        qs = unchain(q)
        for q in qs
            simplify_and_push!(memo, chain, q)
        end
        simplify_and_push!(memo, chain, top)
    # chain_of(wrap(), lift(f)) => lift(f)
    elseif (top ~ wrap()) && (p ~ lift(_))
        pop!(chain)
        simplify_and_push!(memo, chain, p)
    # chain_of(with_elements(p), with_elements(q)) => with_elements(chain_of(p, q))
    elseif (top ~ with_elements(q1)) && (p ~ with_elements(q2))
        pop!(chain)
        qs = unchain(q1)
        for q in unchain(q2)
            simplify_and_push!(memo, qs, q)
        end
        simplify_and_push!(memo, chain, memo(with_elements(memo(qs))))
    # chain_of(with_elements(wrap()), flatten()) => pass()
    elseif (top ~ with_elements(wrap())) && (p ~ flatten())
        pop!(chain)
    # chain_of(with_elements(chain_of(p, wrap())), flatten()) => with_elements(p)
    elseif (top ~ with_elements(chain_of([qs..., wrap()]))) && (p ~ flatten())
        pop!(chain)
        simplify_and_push!(memo, chain, memo(with_elements(memo(qs))))
    # chain_of(flatten(), with_elements(column(k))) => chain_of(with_elements(with_elements(column(k))), flatten())
    elseif (top ~ flatten()) && (p ~ with_elements(column(k)))
        pop!(chain)
        simplify_and_push!(memo, chain, memo(with_elements(p)))
        simplify_and_push!(memo, chain, top)
   # chain_of(flatten(), with_elements(chain_of(column(k), p))) => chain_of(with_elements(with_elements(column(k))), flatten(), with_elements(p))
    elseif (top ~ flatten()) && (p ~ with_elements(chain_of([column(k), qs...])))
        pop!(chain)
        simplify_and_push!(memo, chain, memo(with_elements(memo(with_elements(memo(column(k)))))))
        simplify_and_push!(memo, chain, top)
        simplify_and_push!(memo, chain, memo(with_elements(memo(qs))))
    # chain_of(distribute(k), with_elements(column(k))) => column(k)
    elseif (top ~ distribute(j)) && (p ~ with_elements(column(k))) && j == k
        pop!(chain)
        simplify_and_push!(memo, chain, memo(column(k)))
    # chain_of(distribute(k), with_elements(chain_of(column(k), p))) => chain_of(column(k), with_elements(p))
    elseif (top ~ distribute(j)) && (p ~ with_elements(chain_of([column(k), qs...]))) && j == k
        pop!(chain)
        simplify_and_push!(memo, chain, memo(column(k)))
        simplify_and_push!(memo, chain, memo(with_elements(memo(qs))))
    # chain_of(sieve_by(), with_elements(column(k))) => chain_of(with_column(1, column(k)), sieve_by())
    elseif (top ~ sieve_by()) && (p ~ with_elements(column(k)))
        pop!(chain)
        simplify_and_push!(memo, chain, memo(with_column(1, memo(column(k)))))
        simplify_and_push!(memo, chain, top)
    else
        push!(chain, p)
    end
    nothing
end


#
# Common subexpression elimination.
#

function rewrite_common(p::Pipeline; memo=RewriteMemo())::Pipeline
    rewrite_common(memo, p) |> designate(p.sig)
end

function rewrite_common(memo::RewriteMemo, p::Pipeline)
    @match_pipeline if (p ~ tuple_of(_, _))
        chain = Pipeline[]
        l, r = pull_common(memo, p)
        append!(chain, unchain(rewrite_common(memo, l)))
        push!(chain, rewrite_with(rewrite_common, memo, r))
        memo(chain)
    else
        rewrite_with(rewrite_common, memo, p)
    end
end

rewrite_common(memo::RewriteMemo, ps::Vector{Pipeline}) =
    Pipeline[rewrite_common(memo, p) for p in ps]

rewrite_common(memo::RewriteMemo, @nospecialize other) = other

function pull_common(memo::RewriteMemo, p::Pipeline)
    l = memo(pass())
    r = p
    @match_pipeline if (p ~ tuple_of(lbls, cols)) && length(cols) > 1
        i = l
        deps = Dict{Pipeline,Vector{Pipeline}}(i => Pipeline[], p => cols)
        seen = Set{Pipeline}()
        dups = Set{Pipeline}()
        for col in cols
            parts = Pipeline[i]
            collect_parts!(memo, parts, deps, i, col)
            for q in parts
                if q in seen
                    push!(dups, q)
                end
            end
            for q in parts
                push!(seen, q)
            end
        end
        if length(dups) > 1
            seen = Set{Pipeline}()
            basis = Pipeline[]
            stack = Pipeline[p]
            while !isempty(stack)
                q = pop!(stack)
                for dep in deps[q]
                    if !(dep in seen)
                        if dep in dups
                            push!(basis, dep)
                        else
                            push!(stack, dep)
                        end
                        push!(seen, dep)
                    end
                end
            end
            w = length(basis)
            if w > 1
                basis = Pipeline[q for q in basis if !(q ~ column(_))]
                if length(basis) < w && !(i in basis)
                    push!(basis, i)
                end
            end
            if !(basis ~ [pass()])
                repl = Dict{Pipeline,Pipeline}()
                if length(basis) == 1
                    l = basis[1]
                    repl[basis[1]] = i
                else
                    l_cols = Pipeline[]
                    for (k, b) in enumerate(basis)
                        push!(l_cols, b)
                        repl[b] = memo(column(k))
                    end
                    l = tuple_of(Symbol[], l_cols)
                end
                r = replace_parts(memo, repl, i, p)
                @assert r !== nothing p
            end
        end
    end
    (l, r)
end

function collect_parts!(memo, parts, deps, i, p)
    @match_pipeline if (p ~ pass())
        o = i
    elseif (p ~ chain_of(qs))
        o = i
        for q in qs
            o = collect_parts!(memo, parts, deps, o, q)
        end
    elseif (p ~ tuple_of(lbls, cols))
        os = Pipeline[]
        for col in cols
            push!(os, collect_parts!(memo, parts, deps, i, col))
        end
        chain = unchain(i)
        push!(chain, p)
        o = memo(chain)
        push!(parts, o)
        get!(deps, o, os)
    elseif (p ~ with_elements(chain_of(qs)))
        chain = unchain(i)
        qs′ = Pipeline[]
        for q in qs
            push!(qs′, q)
            chain′ = copy(chain)
            push!(chain′, memo(with_elements(memo(copy(qs′)))))
            o = memo(chain′)
            get!(deps, o, Pipeline[i])
            i = o
        end
    else
        chain = unchain(i)
        push!(chain, p)
        o = memo(chain)
        push!(parts, o)
        if (p ~ filler(_)) || (p ~ block_filler(_, _)) || (p ~ null_filler())
            get!(deps, o, Pipeline[])
        else
            get!(deps, o, Pipeline[i])
        end
    end
    o
end

function replace_parts(memo, repl, i, p)
    o = memo(vcat(unchain(i), unchain(p)))
    if o in keys(repl)
        return repl[o]
    end
    @match_pipeline if (p ~ chain_of(qs))
        chain′ = unchain(i)
        append!(chain′, qs)
        for k in reverse(eachindex(qs))
            pop!(chain′)
            i′ = memo(copy(chain′))
            o′ = replace_parts(memo, repl, i′, qs[k])
            if o′ !== nothing
                chain = unchain(o′)
                append!(chain, qs[k+1:end])
                return memo(chain)
            end
        end
    elseif (p ~ tuple_of(lbls, cols))
        cols′ = Pipeline[]
        for col in cols
            o = replace_parts(memo, repl, i, col)
            if o !== nothing
                push!(cols′, o)
            end
        end
        if length(cols′) == length(cols)
            return tuple_of(lbls, cols′)
        end
    elseif (p ~ with_elements(chain_of(qs)))
        for k in lastindex(qs)-1:-1:firstindex(qs)+1
            chain′ = unchain(i)
            push!(chain′, memo(with_elements(memo(qs[1:k-1]))))
            i′ = memo(chain′)
            if i′ in keys(repl)
                o′ = repl[i′]
                chain = unchain(o′)
                push!(chain, memo(with_elements(memo(qs[k+1:end]))))
                return memo(chain)
            end
        end
    elseif (p ~ filler(_)) || (p ~ block_filler(_, _)) || (p ~ null_filler())
        return p
    end
    if i in keys(repl)
        return memo(vcat(unchain(repl[i]), unchain(p)))
    end
    nothing
end


#
# Pipeline linearization.
#

function rewrite_linearize(p::Pipeline; memo=RewriteMemo())::Pipeline
    chain_of(linearize(p)) |> designate(signature(p))
end

function linearize(p::Pipeline)::Vector{Pipeline}
    retval = Pipeline[]
    @match_pipeline if (p ~ pass())
        nothing
    elseif (p ~ chain_of(qs))
        for q in qs
            append!(retval, linearize(q))
        end
    elseif (p ~ with_elements(q))
        for r in linearize(q)
            push!(retval, with_elements(r))
        end
    elseif (p ~ with_column(lbl, q))
        for r in linearize(q)
            push!(retval, with_column(lbl, r))
        end
    elseif (p ~ tuple_of(lbls, cols::Vector{Pipeline}))
        push!(retval, tuple_of(lbls, length(cols)))
        for (idx, q) in enumerate(cols)
            for r in linearize(q)
                push!(retval, with_column(idx, r))
            end
        end
    else
        push!(retval, p)
    end
    return retval
end

function delinearize!(vp::Vector{Pipeline})::Pipeline
    chain = Vector{Pipeline}()
    while length(vp) > 0
        @match_pipeline if (vp[1] ~ with_elements(arg))
            push!(chain, delinearize_block!(vp))
        elseif (vp[1] ~ tuple_of(lbls, width::Int))
            push!(chain, delinearize_tuple!(vp, lbls, width))
        else
            push!(chain, popfirst!(vp))
        end
    end
    return chain_of(chain...)
end

function delinearize_block!(vp::Vector{Pipeline})::Pipeline
    chain = Vector{Pipeline}()
    @match_pipeline while (vp ~ [with_elements(p), _...])
        popfirst!(vp)
        push!(chain, p)
    end
    return with_elements(delinearize!(chain))
end

function delinearize_tuple!(vp::Vector{Pipeline}, lbls, width)::Pipeline
    popfirst!(vp) # drop the `tuple_of`
    slots = [Pipeline[] for x in 1:width]
    @match_pipeline while (vp ~ [with_column(idx, p), _...])
        popfirst!(vp)
        if !isa(idx, Int)
            idx = findfirst(==(idx), lbls)
            @assert !isnothing(idx)
        end
        push!(slots[idx], p)
    end
    return tuple_of(lbls, [delinearize!(cv) for cv in slots])
end


#
# Wire diagram.
#

struct RootNode
    cache::Dict{Any,Any}

    RootNode() = new(Dict{Any,Any}())
end

struct EvalNode{N}
    p::Pipeline
    input::N
end

struct HeadNode{N}
    node::N
end

struct PartNode{N}
    node::N
    idx::Int
end

struct JoinNode{N}
    head::N
    parts::Vector{N}
end

mutable struct NodeRef
    ref::Union{RootNode,EvalNode{NodeRef},HeadNode{NodeRef},PartNode{NodeRef},JoinNode{NodeRef},Nothing}
    shp::AbstractShape
    root::RootNode
end

function root_node(src::AbstractShape)
    root = RootNode()
    node = NodeRef(root, src, root)
    root.cache[()] = node
    node
end

function hole_node(n::NodeRef)
    get!(n.root.cache, nothing) do
        NodeRef(nothing, SlotShape(), n.root)
    end
end

function eval_node(p::Pipeline, input::NodeRef)
    get!(input.root.cache, (input, p.op, p.args)) do
        ref = EvalNode{NodeRef}(p, input)
        shp = target(signature(p))
        NodeRef(ref, shp, input.root)
    end
end

function head_node(node::NodeRef)
    get!(node.root.cache, (node, 0)) do
        shp = deannotate(node.shp)
        w = width(shp)
        for j = 1:w
            shp = replace_branch(shp, j, SlotShape())
        end
        if w > 0
            shp = HasSlots(shp, w)
        end
        NodeRef(HeadNode{NodeRef}(node), shp, node.root)
    end
end

function part_node(node::NodeRef, idx::Int)
    get!(node.root.cache, (node, idx)) do
        shp = deannotate(node.shp)
        if !(shp isa SlotShape)
            shp = branch(shp, idx)
        end
        NodeRef(PartNode{NodeRef}(node, idx), shp, node.root)
    end
end

function join_node(head::NodeRef, parts::Vector{NodeRef})
    get!(head.root.cache, (head, parts)) do
        shp = deannotate(head.shp)
        w = width(shp)
        ary = 0
        @assert w == length(parts)
        for j = 1:w
            @assert branch(shp, j) isa SlotShape
            shp = replace_branch(shp, j, parts[j].shp)
            ary += arity(parts[j].shp)
        end
        if ary > 0
            shp = HasSlots(shp, w)
        end
        NodeRef(JoinNode{NodeRef}(head, parts), shp, head.root)
    end
end

show(io::IO, n::NodeRef) =
    print_expr(io, quoteof(n))

function quoteof(n::NodeRef)
    exs = Expr[]
    nidxs = IdDict{Any,Int}()
    ex = quoteof!(n, exs, nidxs)
    if isempty(exs)
        return ex
    elseif length(exs) == 1
        return exs[1]
    end
    letargs = [Expr(:(=), Symbol("n", k), exs[k]) for k in eachindex(exs)]
    Expr(:let, Expr(:block, letargs...), ex)
end

function quoteof!(n::NodeRef, exs, nidxs)
    if haskey(nidxs, n)
        return Symbol("n", nidxs[n])
    end
    ref = n.ref
    if ref === nothing
        ex = Expr(:call, nameof(hole_node), quoteof!(n.root.cache[()], exs, nidxs))
    elseif ref isa RootNode
        ex = Expr(:call, nameof(root_node), quoteof(n.shp))
    elseif ref isa EvalNode{NodeRef}
        ex = Expr(:call, nameof(eval_node), quoteof(ref.p), quoteof!(ref.input, exs, nidxs))
    elseif ref isa HeadNode{NodeRef}
        ex = Expr(:call, nameof(head_node), quoteof!(ref.node, exs, nidxs))
    elseif ref isa PartNode{NodeRef}
        ex = Expr(:call, nameof(part_node), quoteof!(ref.node, exs, nidxs), ref.idx)
    elseif ref isa JoinNode{NodeRef}
        partsex = Expr(:vect, Any[quoteof!(part, exs, nidxs) for part in ref.parts]...)
        ex = Expr(:call, nameof(join_node), quoteof!(ref.head, exs, nidxs), partsex)
    end
    push!(exs, ex)
    nidxs[n] = length(exs)
    Symbol("n", length(exs))
end

function get_head(n::NodeRef)
    ref = n.ref
    if ref isa JoinNode{NodeRef}
        return ref.head
    end
    shp = n.shp
    if shp isa HasSlots
        shp = subject(shp)
    end
    if all(branch(shp, j) isa SlotShape for j = 1:width(shp))
        return n
    end
    return head_node(n)
end

function get_parts(n::NodeRef)
    shp = deannotate(n.shp)
    w = width(shp)
    ref = n.ref
    if ref isa JoinNode{NodeRef}
        @assert length(ref.parts) == w
        return ref.parts
    end
    return NodeRef[part_node(n, j) for j = 1:w]
end

substitute(n::NodeRef, repl) =
    substitute(n, repl, 1:length(repl))

function substitute(n::NodeRef, repl, rng)
    shp = n.shp
    if shp isa SlotShape
        @assert length(rng) == 1
        n = repl[first(rng)]
    elseif shp isa HasSlots
        head = get_head(n)
        parts = get_parts(n)
        ary = arity(shp)
        l = 0
        parts′ = copy(parts)
        for j = 1:width(subject(shp))
            part = parts[j]
            part_ary = arity(part.shp)
            if part_ary > 0
                part′ = substitute(part, repl, rng[l+1:l+part_ary])
                parts′[j] = part′
                l += part_ary
            end
        end
        n = join_node(head, parts′)
    else
        @assert isempty(rng)
    end
    n
end

function decompose(n::NodeRef, @nospecialize(shp::AbstractShape))
    hole = hole_node(n)
    ary = arity(shp)
    repl = fill(hole, ary)
    n′ = decompose!(n, shp, repl, 1)
    (n′, repl)
end

function decompose!(n::NodeRef, @nospecialize(shp::AbstractShape), repl, shift)
    if shp isa SlotShape
        repl[shift] = n
        n′ = hole_node(n)
    elseif shp isa HasSlots
        sub = subject(shp)
        w = width(sub)
        parts = get_parts(n)
        @assert w == length(parts)
        parts′ = copy(parts)
        only_holes = true
        for j = 1:w
            b = branch(sub, j)
            parts′[j] = part′ = decompose!(parts[j], b, repl, shift)
            shift += arity(b)
            if part′.ref !== nothing
                only_holes = false
            end
        end
        n′ = get_head(n)
        if !only_holes
            n′ = join_node(n′, parts′)
        end
    else
        n′ = n
    end
    n′
end

function trace(p::Pipeline)
    src = deannotate(source(p))
    n0 = root_node(src)
    trace(p, n0)
end

function trace(p::Pipeline, i::NodeRef)
    @match_pipeline if (p ~ chain_of(qs))
        o = i
        for q in qs
            o = trace(q, o)
        end
    elseif (p ~ pass())
        o = i
    elseif (p ~ tuple_of(lbls, cols::Vector{Pipeline}))
        parts = NodeRef[trace(col, i) for col in cols]
        p′ = tuple_of(lbls, length(cols))
        sig′ = p′(i.shp)
        o = join_node(eval_node(p′ |> designate(sig′), hole_node(i)), parts)
    elseif (p ~ with_column(lbl, q))
        @assert i.shp isa TupleOf
        parts = get_parts(i)
        @assert length(parts) == width(i.shp)
        j = locate(i.shp, lbl)
        q_n = trace(q, parts[j])
        parts′ = copy(parts)
        parts′[j] = q_n
        o = join_node(get_head(i), parts′)
    elseif (p ~ with_elements(q))
        @assert i.shp isa BlockOf
        parts = get_parts(i)
        @assert length(parts) == 1
        q_n = trace(q, parts[1])
        o = join_node(get_head(i), NodeRef[q_n])
    elseif (p ~ distribute(lbl))
        @assert i.shp isa TupleOf
        parts = get_parts(i)
        j = locate(i.shp, lbl)
        @assert parts[j].shp isa BlockOf
        j_parts = get_parts(parts[j])
        @assert length(j_parts) == 1
        parts′ = copy(parts)
        parts′[j] = j_parts[1]
        o = join_node(get_head(parts[j]), NodeRef[join_node(get_head(i), parts′)])
    else
        sig = p(i.shp)
        i, i_repl = decompose(i, source(sig))
        n = eval_node(p |> designate(sig), i)
        bds = bindings(sig)
        if bds !== nothing
            hole = hole_node(i)
            o_repl = fill(hole, bds.tgt_ary)
            for (src_slot, tgt_slot) in bds.src2tgt
                o_repl[tgt_slot] = i_repl[src_slot]
            end
            o = substitute(n, o_repl)
        else
            o = n
        end
    end
    o
end

