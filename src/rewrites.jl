function rewrite_all(p::Pipeline)::Pipeline
    vpn = linearize(p)
    vpn = simplify!(vpn)
    return delinearize!(with_nested.(vpn)) |> designate(signature(p))
end

struct NestedPipe
    path::Vector{Int}
    pipe::Pipeline

    NestedPipe(path, pipe) = new(path, pipe)
end

with_nested(np::NestedPipe) = with_nested(np.path, np.pipe)

isprefixed(path::Vector{Int}, prefix::Vector{Int})::Bool =
    length(path) >= length(prefix) && path[1:length(prefix)] == path

function simplify!(vpn::Vector{NestedPipe})
  idx = 1
  while length(vpn) >= idx + 1
    this = vpn[idx]
    next = vpn[idx+1]
    len_this = length(this.path)
    len_next = length(next.path)
    if len_this == len_next
      # chain_of(wrap(), flatten()) => pass()
      if this.pipe.op == wrap && next.pipe.op == flatten
          popat!(vpn, idx)
          popat!(vpn, idx)
          idx = 1
          continue
      end
    elseif len_next > len_this
      # chain_of(wrap(), with_elements(p)) => chain_of(p, wrap())
      if this.pipe.op == wrap && next.path[len_this+1] == 0 &&
                                 next.path[1:len_this] == this.path
          popat!(next.path, len_this+1)
          (vpn[idx], vpn[idx+1]) = (vpn[idx+1], vpn[idx])
          idx += 1
          continue
      end
    elseif len_next < len_this
      # chain_of(with_column(n, with_elements(wrap()))), distribute(n)) =>
      #   chain_of(distribute(n), with_elements(with_column(n, wrap())))
      if this.pipe.op == wrap && next.pipe.op == distribute &&
         len_next + 2 == len_this && this.path[end] == 0 &&
                                     this.path[end-1] == next.pipe.args[1]
          (this.path[end-1], this.path[end]) = (0, next.pipe.args[1])
          (vpn[idx], vpn[idx+1]) = (vpn[idx+1], vpn[idx])
          idx += 1
          continue
      end
    end
    idx += 1
  end
  return vpn
end

function linearize(p::Pipeline, path::Vector{Int}=Int[])::Vector{NestedPipe}
    retval = NestedPipe[]
    @match_pipeline if (p ~ pass())
        nothing
    elseif (p ~ chain_of(qs))
        for q in qs
            append!(retval, linearize(q, copy(path)))
        end
    elseif (p ~ with_elements(q))
        append!(retval, linearize(q, [path..., 0]))
    elseif (p ~ with_column(lbl::Int, q))
        append!(retval, linearize(q, [path..., lbl]))
    elseif (p ~ tuple_of(lbls, cols::Vector{Pipeline}))
        push!(retval, NestedPipe(path, tuple_of(lbls, length(cols))))
        for (idx, q) in enumerate(cols)
            append!(retval, linearize(q, [path..., idx]))
        end
    else
        push!(retval, NestedPipe(path, p))
    end
    return retval
end

function delinearize!(vp::Vector{Pipeline}, base::Vector{Int}=Int[])::Pipeline
    depth = length(base)
    chain = Pipeline[]
    while length(vp) > 0
        @match_pipeline if (vp ~ [with_nested(path, p), _...])
            if path == base
                @match_pipeline if (p ~ tuple_of(lbls, width::Int))
                    push!(chain, delinearize_tuple!(vp, base, lbls, width))
                    continue
                end
                popfirst!(vp)
                push!(chain, p)
                continue
            end
            if base == path[1:length(base)]
                idx = path[depth+1]
                if idx == 0
                    push!(chain, delinearize_elements!(vp, base))
                else
                    push!(chain, delinearize_column!(vp, base, idx))
                end
                continue
            end
            break
        end
        push!(chain, popfirst!(vp))
    end
    return chain_of(chain...)
end

function delinearize_elements!(vp::Vector{Pipeline}, base)::Pipeline
    base = [base..., 0]
    depth = length(base)
    chain = Pipeline[]
    @match_pipeline while (vp ~ [with_nested(path, p), _...])
        if length(path) >= depth && base == path[1:depth]
            push!(chain, popfirst!(vp))
            continue
        end
        break
    end
    return with_elements(delinearize!(chain, base))
end

function delinearize_column!(vp::Vector{Pipeline}, base, idx)::Pipeline
    base = [base..., idx]
    depth = length(base)
    chain = Pipeline[]
    @match_pipeline while (vp ~ [with_nested(path, p), _...])
        if length(path) >= depth && base == path[1:depth]
            push!(chain, popfirst!(vp))
            continue
        end
        break
    end
    return with_column(idx, delinearize!(chain, base))
end

function delinearize_tuple!(vp::Vector{Pipeline}, base, lbls, width)::Pipeline
    popfirst!(vp) # drop the `tuple_of`
    depth = length(base)
    slots = [Pipeline[] for x in 1:width]
    @match_pipeline while (vp ~ [with_nested(path, p), _...])
        if base == path[1:depth]
            if length(path) > depth
                idx = path[depth+1]
                if idx > 0
                    push!(slots[idx], popfirst!(vp))
                    continue
                end
            elseif length(path) == depth
                @match_pipeline if (p ~ with_column(idx::Int, q))
                    popfirst!(vp)
                    push!(slots[idx], q)
                    continue
                end
            end
        end
        break
    end
    return tuple_of(lbls, [delinearize!(cv, [base..., idx])
                              for (cv, idx) in zip(slots, 1:width)])
end
