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

function rewrite_compact(p::Pipeline; memo=RewriteMemo())::Pipeline
    delinearize!(linearize(p)) |> designate(signature(p))
end

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
# Data graph.
#

@enum DataNodeKind ROOT_NODE PIPE_NODE HEAD_NODE PART_NODE JOIN_NODE SLOT_NODE FILL_NODE EXIT_NODE DEAD_NODE

mutable struct DataNode
    kind::DataNodeKind
    refs::Vector{DataNode}
    more::Union{Int,Pipeline,Nothing}
    shp::AbstractShape
    root::Union{DataNode,Nothing}
    uses::Vector{Tuple{DataNode,Int}}
    memo::Any
end

function root_node(@nospecialize src::AbstractShape)
    DataNode(ROOT_NODE, DataNode[], nothing, src, nothing, Tuple{DataNode,Int}[], nothing)
end

function pipe_node(p::Pipeline, input::DataNode)
    shp = target(signature(p))
    n = DataNode(PIPE_NODE, DataNode[input], p, shp, get_root(input), Tuple{DataNode,Int}[], nothing)
    push!(input.uses, (n, 1))
    n
end

function head_node(base::DataNode)
    shp = deannotate(base.shp)
    w = width(shp)
    all_slots = true
    for j = 1:w
        if !(branch(shp, j) isa SlotShape)
            shp = replace_branch(shp, j, SlotShape())
            all_slots = false
        end
    end
    if all_slots
        return base
    end
    if w > 0
        shp = HasSlots(shp, w)
    end
    n = DataNode(HEAD_NODE, DataNode[base], nothing, shp, get_root(base), Tuple{DataNode,Int}[], nothing)
    push!(base.uses, (n, 1))
    n
end

function part_node(base::DataNode, idx::Int)
    shp = branch(deannotate(base.shp), idx)
    n = DataNode(PART_NODE, DataNode[base], idx, shp, get_root(base), Tuple{DataNode,Int}[], nothing)
    push!(base.uses, (n, 1))
    n
end

function join_node(head::DataNode, parts::Vector{DataNode})
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
        shp = HasSlots(shp, ary)
    end
    refs = DataNode[head]
    append!(refs, parts)
    n = DataNode(JOIN_NODE, refs, nothing, shp, get_root(head), Tuple{DataNode,Int}[], nothing)
    for (k, ref) in enumerate(refs)
        push!(ref.uses, (n, k))
    end
    n
end

function slot_node(base::DataNode)
    if base.shp isa SlotShape
        return base
    end
    n = DataNode(SLOT_NODE, DataNode[base], nothing, SlotShape(), get_root(base), Tuple{DataNode,Int}[], nothing)
    push!(base.uses, (n, 1))
    n
end

function fill_node(slot::DataNode, fill::DataNode)
    n = DataNode(FILL_NODE, DataNode[slot, fill], nothing, fill.shp, get_root(slot), Tuple{DataNode,Int}[], nothing)
    push!(slot.uses, (n, 1))
    push!(fill.uses, (n, 2))
    n
end

function exit_node(base::DataNode)
    n = DataNode(EXIT_NODE, DataNode[base], nothing, base.shp, get_root(base), Tuple{DataNode,Int}[], nothing)
    push!(base.uses, (n, 1))
    n
end

get_root(n::DataNode) =
    n.root !== nothing ? n.root : n

show(io::IO, n::DataNode) =
    print_expr(io, quoteof(n))

function sequence(root::DataNode)
    @assert isempty(root.refs)
    seq = DataNode[]
    seen = Set{DataNode}()
    stk = [(root, 1)]
    while !isempty(stk)
        node, k = pop!(stk)
        if k > length(node.uses)
            push!(seq, node)
        else
            push!(stk, (node, k+1))
            u = node.uses[k][1]
            if !(u in seen)
                push!(seen, u)
                push!(stk, (u, 1))
            end
        end
    end
    reverse!(seq)
end

function quoteof(n::DataNode)
    seq = sequence(get_root(n))
    vars = Dict{DataNode,Symbol}()
    exs = Expr[]
    for (k, node) in enumerate(seq)
        vars[node] = Symbol("n", k)
        ex =
            if node.kind == ROOT_NODE
                Expr(:call, nameof(root_node), quoteof(node.shp))
            elseif node.kind == PIPE_NODE
                Expr(:call, nameof(pipe_node), quoteof(node.more), vars[node.refs[1]])
            elseif node.kind == HEAD_NODE
                Expr(:call, nameof(head_node), vars[node.refs[1]])
            elseif node.kind == PART_NODE
                Expr(:call, nameof(part_node), vars[node.refs[1]], node.more)
            elseif node.kind == JOIN_NODE
                Expr(:call, nameof(join_node), vars[node.refs[1]], Expr(:vect, [vars[node.refs[j]] for j = 2:length(node.refs)]...))
            elseif node.kind == SLOT_NODE
                Expr(:call, nameof(slot_node), vars[node.refs[1]])
            elseif node.kind == FILL_NODE
                Expr(:call, nameof(fill_node), vars[node.refs[1]], vars[node.refs[2]])
            elseif node.kind == EXIT_NODE
                Expr(:call, nameof(exit_node), vars[node.refs[1]])
            end
        push!(exs, ex)
    end
    if length(seq) == 1
        exs[1]
    else
        lets = [Expr(:(=), vars[node], exs[k]) for (k, node) in enumerate(seq)]
        Expr(:let, Expr(:block, lets...), vars[n])
    end
end

macro match_node(ex)
    return esc(_match_node(ex))
end

function _match_node(@nospecialize ex)
    if Meta.isexpr(ex, :call, 3) && ex.args[1] == :~
        val = gensym()
        p = ex.args[2]
        pat = ex.args[3]
        cs = Expr[]
        as = Expr[]
        _match_node!(val, pat, cs, as)
        c = foldl((l, r) -> :($l && $r), cs)
        quote
            local $val = $p
            if $c
                $(as...)
                true
            else
                false
            end
        end
    elseif ex isa Expr
        Expr(ex.head, Any[_match_node(arg) for arg in ex.args]...)
    else
        ex
    end
end

function _match_node!(val, pat, cs, as)
    if pat === :_
        return
    elseif pat isa Symbol
        push!(as, :(local $pat = $val))
        return
    elseif Meta.isexpr(pat, :(::), 2)
        ty = pat.args[2]
        pat = pat.args[1]
        push!(cs, :($val isa $ty))
        _match_node!(val, pat, cs, as)
        return
    elseif Meta.isexpr(pat, :call, 3) && pat.args[1] === :~
        _match_node!(val, pat.args[2], cs, as)
        _match_node!(val, pat.args[3], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 2) && pat.args[1] === :root_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.kind == $DataKnots.ROOT_NODE))
        _match_node!(:($val.shp), pat.args[2], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 3) && pat.args[1] === :pipe_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.kind == $DataKnots.PIPE_NODE))
        _match_pipeline!(:($val.more::$DataKnots.Pipeline), pat.args[2], cs, as)
        _match_node!(:($val.refs[1]), pat.args[3], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 2) && pat.args[1] === :head_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.kind == $DataKnots.HEAD_NODE))
        _match_node!(:($val.refs[1]), pat.args[2], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 3) && pat.args[1] === :part_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.kind == $DataKnots.PART_NODE))
        _match_node!(:($val.refs[1]), pat.args[2], cs, as)
        _match_node!(:($val.more::Int), pat.args[3], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 3) && pat.args[1] === :join_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.kind == $DataKnots.JOIN_NODE))
        _match_node!(:($val.refs[1]), pat.args[2], cs, as)
        _match_node!(:($val.refs[2:end]), pat.args[3], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 2) && pat.args[1] === :slot_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.kind == $DataKnots.SLOT_NODE))
        _match_node!(:($val.refs[1]), pat.args[2], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 3) && pat.args[1] === :fill_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.kind == $DataKnots.FILL_NODE))
        _match_node!(:($val.refs[1]), pat.args[2], cs, as)
        _match_node!(:($val.refs[2]), pat.args[3], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 2) && pat.args[1] === :exit_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.kind == $DataKnots.EXIT_NODE))
        _match_node!(:($val.refs[1]), pat.args[2], cs, as)
        return
    elseif Meta.isexpr(pat, :vect)
        push!(cs, :($val isa Vector{$DataKnots.DataNode}))
        _match_node!(val, pat.args, cs, as)
        return
    end
    error("expected a node pattern; got $(repr(pat))")
end

function _match_node!(val, pats::Vector{Any}, cs, as)
    minlen = 0
    varlen = false
    for pat in pats
        if Meta.isexpr(pat, :..., 1)
            !varlen || error("duplicate vararg pattern in $(repr(:([$pat])))")
            varlen = true
        else
            minlen += 1
        end
    end
    push!(cs, !varlen ? :(length($val) == $minlen) : :(length($val) >= $minlen))
    nearend = false
    for (k, pat) in enumerate(pats)
        if Meta.isexpr(pat, :..., 1)
            pat = pat.args[1]
            k = Expr(:call, :(:), k, Expr(:call, :-, :end, minlen-k+1))
            nearend = true
        elseif nearend
            k = Expr(:call, :-, :end, minlen-k+1)
        end
        _match_node!(:($val[$k]), pat, cs, as)
    end
end

function garbage!(n::DataNode)
    n.kind != DEAD_NODE && isempty(n.uses) || return
    garbage = [n]
    while !isempty(garbage)
        garbage_node = pop!(garbage)
        for (idx, ref) in enumerate(garbage_node.refs)
            k = 1
            while k <= length(ref.uses) && (ref.uses[k][1] !== garbage_node || ref.uses[k][2] != idx)
                k += 1
            end
            @assert k <= length(ref.uses)
            ref.uses[k] = ref.uses[end]
            pop!(ref.uses)
            if isempty(ref.uses)
                push!(garbage, ref)
            end
        end
        empty!(garbage_node.refs)
        garbage_node.kind = DEAD_NODE
    end
end

function garbage!(ns::Vector{DataNode})
    foreach(garbage!, ns)
end

function rewrite!(p::Pair{DataNode,DataNode})
    node_from, node_to = p
    node_from !== node_to || return
    for (n, idx) in node_from.uses
        @assert n.refs[idx] === node_from
        n.refs[idx] = node_to
        push!(node_to.uses, (n, idx))
    end
    empty!(node_from.uses)
    garbage!(node_from)
end

function rewrite!(ps::Vector{Pair{DataNode,DataNode}})
    for p in ps
        rewrite!(p)
    end
end

function substitute(n::DataNode, repl)
    if n.shp isa SlotShape
        @assert length(repl) == 1
        fill_node(n, repl[1])
    else
        substitute(n, repl, 1:length(repl))
    end
end

function substitute(n::DataNode, repl, rng)
    shp = n.shp
    if shp isa SlotShape
        @assert length(rng) == 1
        n = repl[first(rng)]
    elseif shp isa HasSlots
        head = head_node(n)
        ary = arity(shp)
        l = 0
        parts′ = DataNode[]
        sub = subject(shp)
        w = width(sub)
        for j = 1:w
            if branch(sub, j) isa SlotShape
                part′ = repl[l+1]
                l += 1
            else
                part = part_node(n, j)
                part_ary = arity(part.shp)
                if part_ary > 0
                    part′ = substitute(part, repl, rng[l+1:l+part_ary])
                    l += part_ary
                else
                    part′ = part
                end
            end
            push!(parts′, part′)
        end
        n = join_node(head, parts′)
    else
        @assert isempty(rng)
    end
    n
end

function decompose(n::DataNode, @nospecialize(shp::AbstractShape))
    if shp isa SlotShape
        n′ = slot_node(n)
        repl = DataNode[n]
    elseif shp isa HasSlots
        ary = arity(shp)
        repl = Vector{DataNode}(undef, ary)
        n′ = decompose!(n, shp, repl, 1)
    else
        repl = DataNode[]
        n′ = n
    end
    (n′, repl)
end

function decompose!(n::DataNode, @nospecialize(shp::AbstractShape), repl, shift)
    if shp isa SlotShape
        repl[shift] = n
        n′ = slot_node(n)
    elseif shp isa HasSlots
        sub = subject(shp)
        w = width(sub)
        @assert w == width(deannotate(n.shp))
        if all(branch(sub, j) isa SlotShape for j = 1:w)
            n′ = head_node(n)
            for j = 1:w
                repl[shift] = part_node(n, j)
                shift += 1
            end
        else
            parts′ = DataNode[part_node(n, j) for j = 1:w]
            for j = 1:w
                b = branch(sub, j)
                part′ = decompose!(parts′[j], b, repl, shift)
                parts′[j] = part′
                shift += arity(b)
            end
            n′ = join_node(head_node(n), parts′)
        end
    else
        n′ = n
    end
    n′
end

function trace(p::Pipeline)
    src = deannotate(source(p))
    n0 = root_node(src)
    n = trace(p, n0)
    exit_node(n)
end

function trace(p::Pipeline, i::DataNode)
    @match_pipeline if (p ~ chain_of(qs))
        o = i
        for q in qs
            o = trace(q, o)
        end
    elseif (p ~ pass())
        o = i
    elseif (p ~ tuple_of(lbls, cols::Vector{Pipeline}))
        parts = DataNode[trace(col, i) for col in cols]
        p′ = tuple_of(lbls, length(cols))
        sig′ = p′(i.shp)
        o = join_node(pipe_node(p′ |> designate(sig′), slot_node(i)), parts)
    elseif (p ~ with_column(lbl, q))
        @assert i.shp isa TupleOf
        j = locate(i.shp, lbl)
        q_n = trace(q, part_node(i, j))
        parts′ = DataNode[part_node(i, j) for j = 1:width(i.shp)]
        parts′[j] = q_n
        o = join_node(head_node(i), parts′)
    elseif (p ~ with_elements(q))
        @assert i.shp isa BlockOf
        part = part_node(i, 1)
        q_n = trace(q, part)
        o = join_node(head_node(i), DataNode[q_n])
    #=
    elseif (p ~ column(lbl))
        j = locate(deannotate(i.shp), lbl)
        o = part_node(i, j)
    =#
    #=
    elseif (p ~ distribute(lbl))
        @assert i.shp isa TupleOf
        parts = get_parts(i)
        j = locate(i.shp, lbl)
        @assert parts[j].shp isa BlockOf
        j_parts = get_parts(parts[j])
        @assert length(j_parts) == 1
        parts′ = copy(parts)
        parts′[j] = j_parts[1]
        o = join_node(get_head(parts[j]), DataNode[join_node(get_head(i), parts′)])
    =#
    else
        sig = p(i.shp)
        i, i_repl = decompose(i, source(sig))
        n = pipe_node(p |> designate(sig), i)
        bds = bindings(sig)
        if bds !== nothing
            o_repl = DataNode[i_repl[bds.tgt2src[tgt_slot]] for tgt_slot = 1:bds.tgt_ary]
            o = substitute(n, o_repl)
        else
            o = n
        end
    end
    o
end

const TailMemo = Vector{Tuple{DataNode,Bool}}

function untrace(n::DataNode)
    chain = Pipeline[]
    tails!(n)
    untrace!(chain, n, (get_root(n), true))
    delinearize!(chain)
end

function tails!(n)
    forward_pass(n) do n
        @match_node if (n ~ root_node(_))
            n.memo = TailMemo()
        elseif (n ~ pipe_node(p, input))
            input_tail = input.memo::TailMemo
            bds = bindings(signature(p))
            n.memo =
                bds !== nothing ?
                    Tuple{DataNode,Bool}[input_tail[bds.tgt2src[j]] for j in 1:bds.tgt_ary] :
                    Tuple{DataNode,Bool}[]
        elseif (n ~ head_node(base))
            shp = deannotate(base.shp)
            w = width(shp)
            n.memo = Tuple{DataNode,Bool}[(base, false) for j = 1:w]
        elseif (n ~ part_node(base, idx))
            base_tail = base.memo::TailMemo
            shp = deannotate(base.shp)
            w = width(shp)
            shift = 0
            for j = 1:idx-1
                shift += arity(branch(shp, j))
            end
            ary = arity(branch(shp, idx))
            n.memo = base_tail[1+shift:ary+shift]
        elseif (n ~ join_node(head, parts))
            tail′ = TailMemo()
            for part in parts
                part_tail = part.memo::TailMemo
                append!(tail′, part_tail)
            end
            n.memo = tail′
        elseif (n ~ slot_node(base))
            n.memo = Tuple{DataNode,Bool}[(base, true)]
        elseif (n ~ fill_node(slot, fill))
            n.memo = fill.memo
        elseif (n ~ exit_node(base))
            n.memo = nothing
        else
            error()
        end
    end
end

function untrace!(chain::Vector{Pipeline}, n::DataNode, guard)
    guard_node, guard_is_slot = guard
    if guard_is_slot
        n !== guard_node || return
    else
        n.kind != PART_NODE || n.refs[1] !== guard_node || return
    end
    @match_node if (n ~ pipe_node(p, input))
        untrace!(chain, input, guard)
        push!(chain, p)
    elseif (n ~ join_node(head, parts))
        untrace!(chain, head, guard)
        head_tail = head.memo::TailMemo
        shp = deannotate(n.shp)
        top = length(chain)
        for j in eachindex(parts)
            untrace!(chain, parts[j], head_tail[j])
            for k = top+1:length(chain)
                chain[k] = with_branch(shp, j, chain[k])
            end
            top = length(chain)
        end
    elseif (n ~ head_node(node))
        untrace!(chain, node, guard)
    elseif (n ~ part_node(node, j))
        untrace!(chain, node, guard)
        shp = deannotate(node.shp)
        push!(chain, extract_branch(shp, j))
    elseif (n ~ fill_node(slot, fill))
        untrace!(chain, slot, guard)
        slot_tail = slot.memo::TailMemo
        @assert length(slot_tail) == 1
        untrace!(chain, fill, slot_tail[1])
    elseif (n ~ slot_node(node))
        untrace!(chain, node, guard)
    elseif (n ~ exit_node(base))
        untrace!(chain, base, guard)
    else
        error("failed to untrace from:\n$n\nto:\n$guard")
    end
end

function rewrite_retrace(p::Pipeline)
    n = trace(p)
    rewrite_retrace!(n)
    p′ = untrace(n)
    p′ |> designate(signature(p))
end

function rewrite_retrace!(n::DataNode)
    for pass! in rewrite_passes(n)
        pass!(n)
    end
end

function forward_pass(f, node::DataNode, args...)
    seen = Set{DataNode}()
    stk = [(node, 1)]
    while !isempty(stk)
        node, k = pop!(stk)
        if k > length(node.refs)
            f(node, args...)
        else
            push!(stk, (node, k+1))
            u = node.refs[k]
            if !(u in seen)
                push!(seen, u)
                push!(stk, (u, 1))
            end
        end
    end
end

function backward_pass(f, node::DataNode, args...)
    seen = Set{DataNode}()
    stk = [(get_root(node), 1)]
    while !isempty(stk)
        node, k = pop!(stk)
        if k > length(node.uses)
            f(node, args...)
        else
            push!(stk, (node, k+1))
            u = node.uses[k][1]
            if !(u in seen)
                push!(seen, u)
                push!(stk, (u, 1))
            end
        end
    end
end

rewrite_passes(@nospecialize ::Any) =
    Pair{Int,Function}[]

rewrite_passes(::Val{(:DataKnots,)}) =
    Pair{Int,Function}[
        10 => rewrite_garbage!,
        20 => rewrite_dedup!,
        30 => rewrite_simplify!,
        40 => rewrite_dedup!,
    ]

function rewrite_passes(node::DataNode)
    mods = Set{Module}()
    forward_pass(node, mods) do node, mods
        @match_node if (node ~ pipe_node(p, _))
            push!(mods, parentmodule(p.op))
        end
    end
    passes = Pair{Int,Function}[]
    for mod in mods
        append!(passes, rewrite_passes(Val(fullname(mod))))
    end
    sort!(passes, by=(p -> (first(p), nameof(last(p)))))
    Function[last(pass) for pass in passes]
end

function rewrite_garbage!(node::DataNode)
    gs = DataNode[]
    backward_pass(node, gs) do n, gs
        if isempty(n.uses) && n.kind != EXIT_NODE
            push!(gs, n)
        end
    end
    garbage!(gs)
end

function rewrite_simplify!(node::DataNode)
    forward_pass(node) do n
        @match_node begin
            # Tighten a join loop.
            if (n ~ join_node(head, parts))
                if (head ~ head_node(base))
                    matched = true
                    for j in eachindex(parts)
                        part = parts[j]
                        if !((part ~ part_node(part_base, idx)) && part_base === base && idx == j)
                            matched = false
                        end
                    end
                    if matched
                        return rewrite!(n => base)
                    end
                end
            end
            # Tighten a fill loop.
            if (n ~ fill_node(slot_node(_), fill))
                return rewrite!(n => fill)
            end
            # Eliminate a join.
            if (n ~ head_node(join_node(head, _)))
                return rewrite!(n => head)
            end
            if (n ~ part_node(join_node(_, parts), idx))
                return rewrite!(n => parts[idx])
            end
            if (n ~ head_node(fill_node(slot, join_node(head, _))))
                return rewrite!(n => fill_node(slot, head))
            end
            if (n ~ part_node(fill_node(slot, join_node(_, parts)), idx))
                return rewrite!(n => parts[idx])
            end
            # Slide a slot backward.
            if (n ~ slot_node(base))
                base′ = base
                while true
                    if (base′ ~ pipe_node(_, input))
                        base′ = input
                    elseif (base′ ~ head_node(head_base))
                        base′ = head_base
                    elseif (base′ ~ join_node(head, _))
                        base′ = head
                    elseif (base′ ~ slot_node(slot_base))
                        base′ = slot_base
                    elseif (base′ ~ fill_node(slot, _))
                        base′ = slot
                    else
                        break
                    end
                end
                if base′ !== base
                    return rewrite!(n => slot_node(base′))
                end
            end
            # Eliminate a column.
            #=
            if (n ~ fill_node(pipe_node(column(_), head_node(base)), part ~ part_node(base′, _))) && base === base′
                return rewrite!(n => part)
            end
            =#
            # Eliminate a tuple.
            if (n ~ pipe_node(column(_), pipe_node(tuple_of(_, _), base)))
                return rewrite!(n => base)
            end
            if (n ~ pipe_node(column(_), fill_node(slot, pipe_node(tuple_of(_, _), base))))
                return rewrite!(n => fill_node(slot, base))
            end
            # Eliminate a fill.
            #=
            if (n ~ fill_node(pipe_node(_, head_node(parent)), part ~ part_node(parent′, _))) && parent === parent′
                return rewrite!(n => part)
            end
            =#
            # Eliminate a wrap.
            if (n ~ pipe_node(flatten(), join_node(pipe_node(wrap(), slot_node(_)), [part])))
                return rewrite!(n => part)
            end
            if (n ~ pipe_node(flatten(), join_node(head, [pipe_node(wrap(), slot_node(_))])))
                return rewrite!(n => head)
            end
            if (n ~ pipe_node(block_any(), join_node(pipe_node(wrap(), slot_node(_)), [part])))
                return rewrite!(n => part)
            end
            if (n ~ pipe_node(p ~ lift(_...), join_node(pipe_node(wrap(), slot_node(_)), [part])))
                p = p |> designate(part.shp, target(p))
                return rewrite!(n => pipe_node(p, part))
            end
            if (n ~ pipe_node(p ~ tuple_lift(_...), join_node(head, parts)))
                parts′ = copy(parts)
                changed = false
                for j in eachindex(parts)
                    part = parts[j]
                    if (part ~ join_node(pipe_node(wrap(), slot_node(_)), [part′]))
                        parts′[j] = part′
                        changed = true
                    end
                end
                if changed
                    input = join_node(head, parts′)
                    p = p |> designate(input.shp, target(p))
                    return rewrite!(n => pipe_node(p, input))
                end
            end
            if (n ~ pipe_node(distribute(j::Int), join_node(head, parts)))
                part = parts[j]
                if (part ~ pipe_node(p ~ wrap(), slot_node(_)))
                    return rewrite!(n => join_node(pipe_node(p, slot_node(head)), DataNode[head]))
                end
            end
            # Eliminate distribute.
            #=
            if (n ~ head_node(pipe_node(distribute(j::Int), join_node(_, parts))))
                return rewrite!(n => head_node(parts[j]))
            end
            =#
        end
    end
end

function rewrite_dedup!(node::DataNode)
    node_cache = Dict{Any,Any}()
    forward_pass(node) do node
        more = node.more
        if more isa Int
            key = (node.kind, node.refs, more)
        elseif more isa Pipeline
            key = (node.kind, node.refs, more.op, more.args)
        else
            key = (node.kind, node.refs)
        end
        node′ = get!(node_cache, key, node)
        if node′ !== node
            rewrite!(node => node′)
        end
    end
end

