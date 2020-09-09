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

function simplify!(vpn::Vector{NestedPipe})
  idx = 1

  while length(vpn) >= idx + 1
    this = vpn[idx]
    next = vpn[idx+1]
    len_this = length(this.path)
    len_next = length(next.path)
#    println("Eval #", idx, "=>", this.path, "/", this.pipe, " .. ",
#                                 next.path, "/", next.pipe, "")
    if len_this == len_next && this.path == next.path
      if this.pipe.op == wrap
        # chain_of(wrap(), flatten()) => pass()
        if next.pipe.op == flatten
            popat!(vpn, idx)
            popat!(vpn, idx)
            idx = 1
            continue
        end
        # chain_of(wrap(), lift(f)) => lift(f)
        if next.pipe.op == lift
            popat!(vpn, idx)
            if idx > 1
                idx = idx - 1
            end
            continue
        end
      end
      # chain_of(tuple_of(n), column(k)) => pass()
      if this.pipe.op == tuple_of && next.pipe.op == column
          @assert isa(this.pipe.args[2], Int)
          popat!(vpn, idx)
          popat!(vpn, idx)
          continue
      end
      # chain_of(p, filler(val)) => filler(val)
      if next.pipe.op in (filler, block_filler, null_filler)
          popat!(vpn, idx)
          if idx > 1
              idx = idx - 1
          end
          continue
      end
    elseif len_next > len_this && this.path == next.path[1:len_this]
      # chain_of(wrap(), with_elements(p)) => chain_of(p, wrap())
      if this.pipe.op == wrap && next.path[len_this+1] == 0
          popat!(next.path, len_this+1)
          (vpn[idx], vpn[idx+1]) = (vpn[idx+1], vpn[idx])
          idx += 1
          continue
      end
      # chain_of(distribute(k), with_elements(column(k))) => column(k)
      if this.pipe.op == distribute && next.path[len_this+1] == 0 &&
            next.pipe.op == column && next.pipe.args[1] == this.pipe.args[1]
         popat!(next.path, len_this+1)
         popat!(vpn, idx)
         continue
      end
      # chain_of(sieve_by(), with_elements(column(n))) =>
      #     chain_of(with_column(1, column(n)), sieve_by())
      if this.pipe.op == sieve_by && next.pipe.op == column &&
            len_next == len_this + 1 && next.path[len_this+1] == 0
          next.path[len_this+1] = 1
          (vpn[idx], vpn[idx+1]) = (vpn[idx+1], vpn[idx])
          continue
      end
    elseif len_this > len_next && next.path == this.path[1:len_next]
      if this.pipe.op == wrap
        if this.path[end] == 0
          # chain_of(with_elements(wrap()), flatten()) => pass()
          if next.pipe.op == flatten && len_next + 1 == len_this
              popat!(vpn, idx)
              popat!(vpn, idx)
              idx = 1
              continue
          end
          # chain_of(with_column(n, with_elements(wrap()))), distribute(n)) =>
          #   chain_of(distribute(n), with_elements(with_column(n, wrap())))
          if next.pipe.op == distribute && len_next + 2 == len_this &&
                this.path[end-1] == next.pipe.args[1]
              (this.path[end-1], this.path[end]) = (0, next.pipe.args[1])
              (vpn[idx], vpn[idx+1]) = (vpn[idx+1], vpn[idx])
              idx += 1
              continue
          end
        else
          # chain_of(with_column(n, wrap()), distribute(n)) => wrap()
          if next.pipe.op == distribute && len_next + 1 == len_this &&
                this.path[end] == next.pipe.args[1]
              popat!(vpn, idx + 1)
              pop!(this.path)
              continue
          end
        end
      # chain_of(with_column(k, p()), column(n)) =>
      #     chain_of(column(n), p()) when n == k, else column(n)
      elseif next.pipe.op == column
        offset = this.path[len_next+1]
        if offset == next.pipe.args[1]
            popat!(this.path, len_next+1)
            (vpn[idx], vpn[idx+1]) = (vpn[idx+1], vpn[idx])
            idx = idx - 1
            continue
        elseif offset > 0
            popat!(vpn, idx)
            idx = idx - 1
            continue
        end
      end
    end
    # chain_of(tuple_of(chain_of(A(), wrap()), B()), tuple_lift(fn)) =>
    #   chain_of(tuple_of(A(), B()), tuple_lift(fn)
    if next.pipe.op == tuple_lift
        # so, the approach here is to lock on `tuple_lift` and then
        # scan backwards, removing qualifying wraps
        wraps_found = 0
        cols_encountered = Int[]
        scan_idx = idx
        while scan_idx > 0
            scan = vpn[scan_idx]
            if length(scan.path) < len_next + 1
                scan_idx = 0
                break
            end
            colno = scan.path[len_next+1]
            if colno == 0
                scan_idx = 0
                break
            end
            if colno in cols_encountered
                scan_idx = scan_idx - 1
                continue
            end
            if scan.pipe.op == wrap
                popat!(vpn, scan_idx)
                wraps_found += 1
                continue
            end
            push!(cols_encountered, colno)
            scan_idx = scan_idx - 1
        end
        if wraps_found > 0
           idx -= wraps_found
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
