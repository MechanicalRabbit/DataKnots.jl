#
# Optimizing pipelines.
#

struct RewriteMemo
    op_map::Dict{Any,Dict{Vector{Any},Pipeline}}

    RewriteMemo() = new(Dict{Any,Dict{Vector{Any},Pipeline}}())
end

function (memo::RewriteMemo)(p::Pipeline)
    args_map = get!(memo.op_map, p.op) do
        Dict{Any,Dict{Vector{Any},Pipeline}}()
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
    if p.op == pass
        return Pipeline[]
    elseif p.op == chain_of
        return collect(Pipeline, p.args[1])
    else
        return Pipeline[p]
    end
end

function rewrite_all(p::Pipeline; memo=RewriteMemo())::Pipeline
    rewrite_unused(rewrite_simplify(p, memo=memo), memo=memo)
end


#
# Local simplification.
#

function rewrite_simplify(p::Pipeline; memo=RewriteMemo())::Pipeline
    rewrite_simplify(memo, p) |> designate(p.sig)
end

function rewrite_simplify(memo::RewriteMemo, p::Pipeline)
    if p.op == chain_of
        chain = Pipeline[]
        simplify_and_push!(memo, chain, p)
        return memo(chain)
    end
    args = collect(Any, rewrite_simplify.(Ref(memo), p.args))
    # with_column(N, pass()) => pass()
    if @match_pipeline p ~ with_column(_, pass())
        return memo(pass())
    end
    # with_elements(pass()) => pass()
    if @match_pipeline p ~ with_elements(pass())
        return memo(pass())
    end
    memo(Pipeline(p.op, args=args))
end

rewrite_simplify(memo::RewriteMemo, p::Vector{Pipeline}) =
    rewrite_simplify.(Ref(memo), p)

rewrite_simplify(memo::RewriteMemo, other) = other

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
    # chain_of(wrap(), with_elements(p)) => chain_of(p, wrap())
    elseif (p ~ with_elements(q)) && (top ~ wrap())
        pop!(chain)
        simplify_and_push!(memo, chain, q)
        simplify_and_push!(memo, chain, memo(wrap()))
    # chain_of(with_elements(p), with_elements(q)) => with_elements(chain_of(p, q))
    elseif (p ~ with_elements(q2)) && (top ~ with_elements(q1))
        qs = unchain(q1)
        pop!(chain)
        for q in unchain(q2)
            simplify_and_push!(memo, qs, q)
        end
        push!(chain, memo(with_elements(memo(qs))))
    # chain_of(wrap(), flatten()) => pass()
    elseif (p ~ flatten()) && (top ~ wrap())
        pop!(chain)
    # chain_of(with_elements(chain_of(p, wrap())), flatten()) => with_elements(p)
    elseif (p ~ flatten()) && (top ~ with_elements(q))
        qs = unchain(q)
        if (qs ~ [_..., wrap()])
            pop!(chain)
            pop!(qs)
            if !isempty(qs)
                push!(chain, memo(with_elements(memo(qs))))
            end
        else
            push!(chain, p)
        end
    # chain_of(wrap(), lift(f)) => lift(f)
    elseif (p ~ lift(_))
        while (chain ~ [_..., wrap()])
            pop!(chain)
        end
        push!(chain, p)
    # chain_of(tuple_of(chain_of(p, wrap()), ...), tuple_lift(f)) => chain_of(tuple_of(p, ...), tuple_lift(f))
    elseif (p ~ tuple_lift(_)) && (top ~ tuple_of(lbls, cols))
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
    # chain_of(with_column(k, chain_of(p, wrap())), distribute(k)) => chain_of(with_column(k, p), wrap())
    elseif (p ~ distribute(k)) && (top ~ with_column(j, q)) && k == j
        qs = unchain(q)
        if (qs ~ [_..., wrap()])
            pop!(chain)
            pop!(qs)
            if !isempty(qs)
                push!(chain, memo(with_column(k, memo(qs))))
            end
            push!(chain, memo(wrap()))
        else
            push!(chain, p)
        end
    # chain_of(tuple_of(p1, ..., pn), column(k)) => pk
    elseif (p ~ column(k::Number)) && (top ~ tuple_of(_, qs))
        qs = unchain(qs[k])
        pop!(chain)
        for q in qs
            simplify_and_push!(memo, chain, q)
        end
    # chain_of(tuple_of(..., pk, ...), with_column(k, q)) => tuple_of(..., chain_of(pk, q), ...)
    elseif (p ~ with_column(k::Number, q)) && (top ~ tuple_of(lbls, cols))
        pop!(chain)
        qs = unchain(cols[k])
        simplify_and_push!(memo, qs, q)
        cols′ = copy(cols)
        cols′[k] = memo(qs)
        push!(chain, memo(tuple_of(lbls, cols′)))
    else
        push!(chain, p)
    end
    nothing
end


#
# Dead code elimination.
#

abstract type AbstractSeen end

quoteof(seen::AbstractSeen) =
    quoteof_auto(seen)

show(io::IO, seen::AbstractSeen) =
    print_expr(io, quoteof(seen))

struct SeenEverything <: AbstractSeen end

struct SeenNothing <: AbstractSeen end

struct SeenTuple <: AbstractSeen
    cols::Dict{Int,AbstractSeen}
end

struct SeenNamedTuple <: AbstractSeen
    cols::Dict{Symbol,AbstractSeen}
end

struct SeenBlock <: AbstractSeen
    elt::AbstractSeen
end

function seen_union(seen1::AbstractSeen, seen2::AbstractSeen)
    @assert seen1 isa Union{SeenEverything, SeenNothing} || seen2 isa Union{SeenEverything, SeenNothing}
    if seen1 isa SeenEverything || seen2 isa SeenNothing
        return seen1
    end
    if seen1 isa SeenNothing || seen2 isa SeenEverything
        return seen2
    end
end

function seen_union(seen1::SeenTuple, seen2::SeenTuple)
    cols′ = Dict{Int, AbstractSeen}()
    for (lbl, col_seen1) in seen1.cols
        if lbl in keys(seen2.cols)
            col_seen2 = seen2.cols[lbl]
            cols′[lbl] = seen_union(col_seen1, col_seen2)
        else
            cols′[lbl] = col_seen1
        end
    end
    for (lbl, col_seen2) in seen2.cols
        if !(lbl in keys(seen1.cols))
            cols′[lbl] = col_seen2
        end
    end
    SeenTuple(cols′)
end

function seen_union(seen1::SeenNamedTuple, seen2::SeenNamedTuple)
    cols′ = Dict{Symbol, AbstractSeen}()
    for (lbl, col_seen1) in seen1.cols
        if lbl in keys(seen2.cols)
            col_seen2 = seen2.cols[lbl]
            cols′[lbl] = seen_union(col_seen1, col_seen2)
        else
            cols′[lbl] = col_seen1
        end
    end
    for (lbl, col_seen2) in seen2.cols
        if !(lbl in keys(seen1.cols))
            cols′[lbl] = col_seen2
        end
    end
    SeenNamedTuple(cols′)
end

function seen_union(seen1::SeenBlock, seen2::SeenBlock)
    elt′ = seen_union(seen1.elt, seen2.elt)
    elt′ isa SeenEverything ? elt′ : SeenBlock(elt′)
end

function rewrite_unused(p::Pipeline; memo=RewriteMemo())::Pipeline
    seen = SeenEverything()
    seen′ = rewrite_unused(memo, p, seen)
    p
end

function rewrite_unused(memo::RewriteMemo, p::Pipeline, seen::AbstractSeen)
    if seen isa SeenNothing
        seen′ = seen
    elseif p.op == filler
        seen′ = SeenNothing()
    elseif p.op == null_filler || p.op == block_filler
        @assert seen isa Union{SeenBlock, SeenEverything}
        seen′ = SeenNothing()
    elseif p.op == pass
        seen′ = seen
    elseif p.op == chain_of
        seen′ = seen
        for q in reverse(p.args[1])
            seen′ = rewrite_unused(memo, q, seen′)
        end
    elseif p.op == tuple_of
        lbls, qs = p.args
        @assert seen isa Union{SeenTuple, SeenNamedTuple, SeenEverything}
        @assert (seen isa SeenTuple) <= isempty(lbls) && (seen isa SeenNamedTuple) <= !isempty(lbls)
        seen′ = SeenNothing()
        for k = 1:length(qs)
            lbl = seen isa SeenNamedTuple ? lbls[k] : k
            if seen isa Union{SeenTuple, SeenNamedTuple}
                if !(lbl in keys(seen.cols))
                    continue
                end
                col_seen = seen.cols[lbl]
            else
                col_seen = seen
            end
            col_seen′ = rewrite_unused(memo, qs[k], col_seen)
            seen′ = seen_union(seen′, col_seen′)
        end
    elseif p.op == with_elements
        @assert seen isa Union{SeenBlock, SeenEverything}
        elt_seen = seen isa SeenBlock ? seen.elt : seen
        elt_seen′ = rewrite_unused(memo, p.args[1], elt_seen)
        seen′ = elt_seen′ isa SeenEverything ? elt_seen′ : SeenBlock(elt_seen′)
    elseif p.op == with_column
        k = p.args[1]
        @assert seen isa Union{SeenTuple, SeenEverything}
        if seen isa SeenTuple
            col_seen = get(seen.cols, k, SeenNothing())
            col_seen′ = rewrite_unused(memo, p.args[2], col_seen)
            cols′ = copy(seen.cols)
            cols′[k] = col_seen′
            seen′ = SeenTuple(cols′)
        else
            seen′ = seen
        end
    elseif p.op == wrap
        @assert seen isa Union{SeenBlock, SeenEverything}
        seen′ = seen isa SeenBlock ? seen.elt : seen
    elseif p.op == flatten
        @assert seen isa Union{SeenBlock, SeenEverything}
        seen′ = seen isa SeenBlock ? SeenBlock(seen) : seen
    elseif p.op == distribute
        k = p.args[1]
        @assert seen isa Union{SeenBlock, SeenEverything}
        if seen isa SeenBlock
            @assert seen.elt isa Union{SeenTuple, SeenEverything, SeenNothing}
            if seen.elt isa SeenTuple
                if get(seen.elt.cols, k, nothing) isa SeenEverything
                    seen′ = seen.elt
                else
                    cols′ = copy(seen.elt.cols)
                    cols′[k] = SeenBlock(get(seen.elt.cols, k, SeenNothing()))
                    seen′ = SeenTuple(cols′)
                end
            elseif seen.elt isa SeenNothing
                seen′ = SeenTuple(Dict(k => SeenBlock(seen.elt)))
            else
                seen′ = seen.elt
            end
        else
            seen′ = seen
        end
    elseif p.op == column
        lbl = p.args[1]
        seen′ = lbl isa Symbol ? SeenNamedTuple(Dict(lbl => seen)) : SeenTuple(Dict(lbl => seen))
    elseif p.op == sieve_by
        @assert seen isa Union{SeenBlock, SeenEverything}
        seen′ = seen isa SeenBlock ? SeenTuple(Dict(1 => seen.elt, 2 => SeenEverything())) : seen
    elseif p.op == block_length
        seen′ = SeenBlock(SeenNothing())
    else
        seen′ = SeenEverything()
    end
    #println("~" ^ 60)
    #println(p)
    #println(seen′)
    #println(seen)
    seen′
end

