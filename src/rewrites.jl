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

abstract type AbstractForm end

mutable struct DataNode
    form::AbstractForm
    shp::AbstractShape
    root::AbstractForm
end

show(io::IO, n::DataNode) =
    print_expr(io, quoteof(n))

function quoteof(n::DataNode)
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

function quoteof!(n::DataNode, exs, nidxs)
    if haskey(nidxs, n)
        return Symbol("n", nidxs[n])
    end
    ex = quoteof!(n.form, exs, nidxs)
    push!(exs, ex)
    nidxs[n] = length(exs)
    Symbol("n", length(exs))
end

struct RootForm <: AbstractForm
    src::AbstractShape
    cache::Dict{Any,Any}

    RootForm(@nospecialize src) = new(src, Dict{Any,Any}())
end

function root_node(@nospecialize src::AbstractShape)
    root = RootForm(src)
    node = DataNode(root, src, root)
    root.cache[()] = node
    node
end

quoteof!(form::RootForm, exs, nidxs) =
    Expr(:call, nameof(root_node), quoteof(form.src))

struct EvalForm <: AbstractForm
    p::Pipeline
    input::DataNode
end

function eval_node(p::Pipeline, input::DataNode)
    root = input.root::RootForm
    get!(root.cache, (input, p.op, p.args)) do
        form = EvalForm(p, input)
        sig = signature(p)
        shp = target(sig)
        DataNode(form, shp, root)
    end
end

quoteof!(form::EvalForm, exs, nidxs) =
    Expr(:call, nameof(eval_node), quoteof(form.p), quoteof!(form.input, exs, nidxs))

struct HeadForm <: AbstractForm
    node::DataNode
end

function head_node(node::DataNode)
    root = node.root::RootForm
    get!(root.cache, (node, 0)) do
        shp = deannotate(node.shp)
        w = width(shp)
        all_slots = true
        for j = 1:w
            if !(branch(shp, j) isa SlotShape)
                shp = replace_branch(shp, j, SlotShape())
                all_slots = false
            end
        end
        if all_slots
            return node
        end
        if w > 0
            shp = HasSlots(shp, w)
        end
        DataNode(HeadForm(node), shp, root)
    end
end

quoteof!(form::HeadForm, exs, nidxs) =
    Expr(:call, nameof(head_node), quoteof!(form.node, exs, nidxs))

struct PartForm <: AbstractForm
    node::DataNode
    idx::Int
end

function part_node(node::DataNode, idx::Int)
    root = node.root::RootForm
    get!(root.cache, (node, idx)) do
        node_shp = deannotate(node.shp)
        shp = branch(node_shp, idx)
        DataNode(PartForm(node, idx), shp, root)
    end
end

quoteof!(form::PartForm, exs, nidxs) =
    Expr(:call, nameof(part_node), quoteof!(form.node, exs, nidxs), form.idx)

struct JoinForm <: AbstractForm
    head::DataNode
    parts::Vector{DataNode}
end

function join_node(head::DataNode, parts::Vector{DataNode})
    root = head.root::RootForm
    get!(root.cache, (head, parts)) do
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
        DataNode(JoinForm(head, parts), shp, root)
    end
end

function quoteof!(form::JoinForm, exs, nidxs)
    partsex = Expr(:vect, Any[quoteof!(part, exs, nidxs) for part in form.parts]...)
    Expr(:call, nameof(join_node), quoteof!(form.head, exs, nidxs), partsex)
end

struct SlotForm <: AbstractForm
    node::DataNode
end

function slot_node(node::DataNode)
    root = node.root::RootForm
    get!(root.cache, (node, nothing)) do
        if node.shp isa SlotShape
            return node
        end
        DataNode(SlotForm(node), SlotShape(), root)
    end
end

quoteof!(form::SlotForm, exs, nidxs) =
    Expr(:call, nameof(slot_node), quoteof!(form.node, exs, nidxs))

struct FillForm <: AbstractForm
    slot::DataNode
    fill::DataNode
end

function fill_node(slot::DataNode, fill::DataNode)
    root = slot.root::RootForm
    get!(root.cache, (slot, fill)) do
        DataNode(FillForm(slot, fill), fill.shp, root)
    end
end

quoteof!(form::FillForm, exs, nidxs) =
    Expr(:call, nameof(fill_node), quoteof!(form.slot, exs, nidxs), quoteof!(form.fill, exs, nidxs))

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
        push!(cs, :($val.form isa $DataKnots.RootForm))
        _match_node!(:($val.form.src), pat.args[2], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 3) && pat.args[1] === :eval_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.form isa $DataKnots.EvalForm))
        _match_pipeline!(:($val.form.p), pat.args[2], cs, as)
        _match_node!(:($val.form.input), pat.args[3], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 2) && pat.args[1] === :head_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.form isa $DataKnots.HeadForm))
        _match_node!(:($val.form.node), pat.args[2], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 3) && pat.args[1] === :part_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.form isa $DataKnots.PartForm))
        _match_node!(:($val.form.node), pat.args[2], cs, as)
        _match_node!(:($val.form.idx), pat.args[3], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 3) && pat.args[1] === :join_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.form isa $DataKnots.JoinForm))
        _match_node!(:($val.form.head), pat.args[2], cs, as)
        _match_node!(:($val.form.parts), pat.args[3], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 2) && pat.args[1] === :slot_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.form isa $DataKnots.SlotForm))
        _match_node!(:($val.form.node), pat.args[2], cs, as)
        return
    elseif Meta.isexpr(pat, :call, 3) && pat.args[1] === :fill_node
        push!(cs, :($val isa $DataKnots.DataNode))
        push!(cs, :($val.form isa $DataKnots.FillForm))
        _match_node!(:($val.form.slot), pat.args[2], cs, as)
        _match_node!(:($val.form.fill), pat.args[3], cs, as)
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
            part = part_node(n, j)
            part_ary = arity(part.shp)
            if part_ary > 0
                part′ = substitute(part, repl, rng[l+1:l+part_ary])
                l += part_ary
            else
                part′ = part
            end
            push!(parts′, part′)
        end
        n = join_node(head, parts′)
    else
        @assert isempty(rng)
    end
    n
end

function decompose(n::DataNode, @nospecialize(shp::AbstractShape), error=true)
    if shp isa SlotShape
        n′ = slot_node(n)
        repl = DataNode[n]
    elseif shp isa HasSlots
        ary = arity(shp)
        repl = Vector{DataNode}(undef, ary)
        n′ = decompose!(n, shp, repl, 1, error)
    else
        repl = DataNode[]
        n′ = n
    end
    (n′, repl)
end

function decompose!(n::DataNode, @nospecialize(shp::AbstractShape), repl, shift, error)
    if shp isa SlotShape
        repl[shift] = n
        n′ = slot_node(n)
    elseif shp isa HasSlots
        sub = subject(shp)
        w = width(sub)
        if error
            @assert w == width(deannotate(n.shp))
        end
        if w != width(deannotate(n.shp))
            return nothing
        end
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
                part′ = decompose!(parts′[j], b, repl, shift, error)
                part′ !== nothing || return nothing
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
    trace(p, n0)
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
        o = join_node(eval_node(p′ |> designate(sig′), slot_node(i)), parts)
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
        n = eval_node(p |> designate(sig), i)
        bds = bindings(sig)
        if bds !== nothing
            slot = slot_node(i)
            o_repl = fill(slot, bds.tgt_ary)
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

function rewrite_nodes_with(f, n::DataNode)
    seen = Dict{DataNode,DataNode}()
    rewrite_nodes_with(f, n, seen)
end

function rewrite_nodes_with(f, n, seen)
    get!(seen, n) do
        form = n.form
        if form isa EvalForm
            input′ = rewrite_nodes_with(f, form.input, seen)
            if input′ !== form.input
                n = eval_node(form.p, input′)
            end
        elseif form isa HeadForm
            node′ = rewrite_nodes_with(f, form.node, seen)
            if node′ !== form.node
                n = head_node(node′)
            end
        elseif form isa PartForm
            node′ = rewrite_nodes_with(f, form.node, seen)
            if node′ !== form.node
                n = part_node(node′, form.idx)
            end
        elseif form isa JoinForm
            head′ = rewrite_nodes_with(f, form.head, seen)
            changed = head′ !== form.head
            parts = form.parts
            for j = eachindex(parts)
                part = parts[j]
                part′ = rewrite_nodes_with(f, part, seen)
                if part′ !== part
                    parts[j] = part′
                    changed = true
                end
            end
            if changed
                n = join_node(head′, parts)
            end
        elseif form isa SlotForm
            node′ = rewrite_nodes_with(f, form.node, seen)
            if node′ !== form.node
                n = slot_node(node′)
            end
        elseif form isa FillForm
            slot′ = rewrite_nodes_with(f, form.slot, seen)
            fill′ = rewrite_nodes_with(f, form.fill, seen)
            if slot′ !== form.slot || fill′ !== form.fill
                n = fill_node(slot′, fill′)
            end
        end
        f(n)
    end
end

function rewrite_retrace(n::DataNode)
    rewrite_nodes_with(retrace_node, n)
end

function retrace_node(n::DataNode)
    @match_node begin
        if (n ~ join_node(head, parts))
            if (head ~ head_node(parent))
                matched = true
                for j in eachindex(parts)
                    part = parts[j]
                    if !((part ~ part_node(node, idx)) && node === parent && idx == j)
                        matched = false
                    end
                end
                if matched
                    return parent
                end
            end
        end
        if (n ~ head_node(join_node(head, _)))
            return head
        end
        if (n ~ part_node(join_node(_, parts), idx))
            return parts[idx]
        end
        if (n ~ slot_node(node))
            node′ = node
            while true
                if (node′ ~ eval_node(_, input))
                    node′ = input
                elseif (node′ ~ head_node(parent))
                    node′ = parent
                elseif (node′ ~ join_node(head, _))
                    node′ = head
                elseif (node′ ~ slot_node(parent))
                    node′ = parent
                elseif (node′ ~ fill_node(slot, _))
                    node′ = slot
                else
                    break
                end
            end
            if node′ !== node
                n = slot_node(node′)
            end
            return n
        end
        if (n ~ fill_node(slot_node(_), fill))
            return fill
        end
        if (n ~ eval_node(flatten(), join_node(eval_node(wrap(), slot_node(_)), [part])))
            return part
        end
        if (n ~ eval_node(flatten(), join_node(head, [eval_node(wrap(), slot_node(_))])))
            return head
        end
        if (n ~ eval_node(p ~ lift(_...), join_node(eval_node(wrap(), slot_node(_)), [part])))
            p = p |> designate(part.shp, target(p))
            return eval_node(p, part)
        end
        if (n ~ eval_node(p ~ tuple_lift(_...), join_node(head, parts)))
            parts′ = copy(parts)
            changed = false
            for j in eachindex(parts)
                part = parts[j]
                if (part ~ join_node(eval_node(wrap(), slot_node(_)), [part′]))
                    parts′[j] = part′
                    changed = true
                end
            end
            if changed
                input = join_node(head, parts′)
                p = p |> designate(input.shp, target(p))
                return eval_node(p, input)
            end
        end
        if (n ~ eval_node(distribute(j::Int), join_node(head, parts)))
            part = parts[j]
            if (part ~ eval_node(p ~ wrap(), slot_node(_)))
                return join_node(eval_node(p, retrace_node(slot_node(head))), DataNode[head])
            end
        end
        if (n ~ fill_node(eval_node(column(_), eval_node(tuple_of(_, _), slot_node(_))), fill))
            return fill
        end
    end
    n
end

function untrace(n::DataNode)
    chain = Pipeline[]
    tails = Dict{DataNode,Vector{DataNode}}()
    tails!(tails, n)
    untrace!(chain, n, n.root.cache[()], tails)
    delinearize!(chain)
end

function tails!(tails, n)
    get!(tails, n) do
        @match_node if (n ~ root_node(_))
            DataNode[]
        elseif (n ~ eval_node(p, input))
            input_tail = tails!(tails, input)
            bds = bindings(signature(p))
            bds !== nothing ?
                DataNode[input_tail[bds.tgt2src[j]] for j in 1:bds.tgt_ary] :
                DataNode[]
        elseif (n ~ head_node(node))
            node_tail = tails!(tails, node)
            shp = deannotate(node.shp)
            w = width(shp)
            shift = 0
            for j = 1:w
                ary = arity(branch(shp, j))
                tails[part_node(node, j)] = node_tail[1+shift:ary+shift]
            end
            DataNode[node for j = 1:w]
        elseif (n ~ part_node(node, idx))
            error()
        elseif (n ~ join_node(head, parts))
            tails!(tails, head)
            tail′ = DataNode[]
            for part in parts
                part_tail = tails!(tails, part)
                append!(tail′, part_tail)
            end
            tail′
        elseif (n ~ slot_node(node))
            tails!(tails, node)
            DataNode[node]
        elseif (n ~ fill_node(slot, fill))
            tails!(tails, slot)
            tails′ = tails!(tails, fill)
            tails′
        else
            error()
        end
    end
end

function untrace!(chain::Vector{Pipeline}, n::DataNode, guard, tails)
    n !== guard || return
    @match_node if (n ~ eval_node(p, input))
        tails = untrace!(chain, input, guard, tails)
        push!(chain, p)
    elseif (n ~ join_node(head, parts))
        untrace!(chain, head, guard, tails)
        head_tail = tails[head]
        shp = deannotate(n.shp)
        top = length(chain)
        for j in eachindex(parts)
            untrace!(chain, parts[j], head_tail[j], tails)
            @assert shp isa BlockOf || shp isa TupleOf
            for k = top+1:length(chain)
                if shp isa BlockOf
                    chain[k] = with_elements(chain[k])
                elseif shp isa TupleOf
                    chain[k] = with_column(j, chain[k])
                end
            end
            top = length(chain)
        end
    elseif (n ~ head_node(node))
        untrace!(chain, node, guard, tails)
    elseif (n ~ part_node(node, _))
        @assert node === guard
        untrace!(chain, node, guard, tails)
    elseif (n ~ fill_node(slot, fill))
        untrace!(chain, slot, guard, tails)
        slot_tail = tails[slot]
        @assert length(slot_tail) == 1
        untrace!(chain, fill, slot_tail[1], tails)
    elseif (n ~ slot_node(node))
        untrace!(chain, node, guard, tails)
    else
        error("failed to untrace from:\n$n\nto:\n$guard")
    end
end

function rewrite_retrace(p::Pipeline)
    n = trace(p)
    n′ = rewrite_retrace(n)
    p′ = untrace(n′)
    p′ |> designate(signature(p))
end

