function rewrite_all(p::Pipeline)::Pipeline
    vnp = linearize(p)
    vnp = simplify!(vnp)
    return delinearize!(with_nested.(vnp)) |> designate(signature(p))
end

struct NestedPipe
    path::Vector{Int}
    pipe::Pipeline

    NestedPipe(path, pipe) = new(path, pipe)
end

with_nested(np::NestedPipe) = with_nested(np.path, np.pipe)

function simplify!(vnp::Vector{NestedPipe})
  idx = 1

  while length(vnp) >= idx + 1
    this = vnp[idx]
    next = vnp[idx+1]
    this_len = length(this.path)
    next_len = length(next.path)
#    println("Eval #", idx, "=>", this.path, "/", this.pipe, " .. ",
#                                 next.path, "/", next.pipe, "")
    if this_len == next_len && this.path == next.path
      if this.pipe.op == wrap
        # chain_of(wrap(), flatten()) => pass()
        if next.pipe.op == flatten
            popat!(vnp, idx)
            popat!(vnp, idx)
            idx = 1
            continue
        end
        # chain_of(wrap(), lift(f)) => lift(f)
        if next.pipe.op == lift
            popat!(vnp, idx)
            if idx > 1
                idx = idx - 1
            end
            continue
        end
      end
      # chain_of(tuple_of(n), column(k)) => pass()
      if this.pipe.op == tuple_of && next.pipe.op == column
          @assert isa(this.pipe.args[2], Int)
          popat!(vnp, idx)
          popat!(vnp, idx)
          continue
      end
      # chain_of(p, filler(val)) => filler(val)
      if next.pipe.op in (filler, block_filler, null_filler)
          popat!(vnp, idx)
          if idx > 1
              idx = idx - 1
          end
          continue
      end
    elseif next_len > this_len && this.path == next.path[1:this_len]
      # chain_of(wrap(), with_elements(p)) => chain_of(p, wrap())
      if this.pipe.op == wrap && next.path[this_len+1] == 0
          popat!(next.path, this_len+1)
          (vnp[idx], vnp[idx+1]) = (vnp[idx+1], vnp[idx])
          idx += 1
          continue
      end
      # chain_of(distribute(k), with_elements(column(k))) => column(k)
      if this.pipe.op == distribute && next.path[this_len+1] == 0 &&
            next.pipe.op == column && next.pipe.args[1] == this.pipe.args[1]
         popat!(next.path, this_len+1)
         popat!(vnp, idx)
         continue
      end
      # chain_of(sieve_by(), with_elements(column(n))) =>
      #     chain_of(with_column(1, column(n)), sieve_by())
      if this.pipe.op == sieve_by && next.pipe.op == column &&
            next_len == this_len + 1 && next.path[this_len+1] == 0
          next.path[this_len+1] = 1
          (vnp[idx], vnp[idx+1]) = (vnp[idx+1], vnp[idx])
          continue
      end
    elseif this_len > next_len && next.path == this.path[1:next_len]
      if this.pipe.op == wrap
        if this.path[end] == 0
          # chain_of(with_elements(wrap()), flatten()) => pass()
          if next.pipe.op == flatten && next_len + 1 == this_len
              popat!(vnp, idx)
              popat!(vnp, idx)
              idx = 1
              continue
          end
          # chain_of(with_column(n, with_elements(wrap()))), distribute(n)) =>
          #   chain_of(distribute(n), with_elements(with_column(n, wrap())))
          if next.pipe.op == distribute && next_len + 2 == this_len &&
                this.path[end-1] == next.pipe.args[1]
              (this.path[end-1], this.path[end]) = (0, next.pipe.args[1])
              (vnp[idx], vnp[idx+1]) = (vnp[idx+1], vnp[idx])
              idx += 1
              continue
          end
        else
          # chain_of(with_column(n, wrap()), distribute(n)) => wrap()
          if next.pipe.op == distribute && next_len + 1 == this_len &&
                this.path[end] == next.pipe.args[1]
              popat!(vnp, idx + 1)
              pop!(this.path)
              continue
          end
        end
      # chain_of(with_column(k, p()), column(n)) =>
      #     chain_of(column(n), p()) when n == k, else column(n)
      elseif next.pipe.op == column
        offset = this.path[next_len+1]
        if offset == next.pipe.args[1]
            popat!(this.path, next_len+1)
            (vnp[idx], vnp[idx+1]) = (vnp[idx+1], vnp[idx])
            idx = idx - 1
            continue
        elseif offset > 0
            popat!(vnp, idx)
            idx = idx - 1
            continue
        end
      end
    end
    if simplify_tuple_lift!(vnp, idx)
       continue
    end
    idx += 1
  end
  return vnp
end

function simplify_tuple_lift!(vnp::Vector{NestedPipe}, idx::Int)::Bool
    this = vnp[idx]
    this_len = length(this.path)
    # chain_of(tuple_of(chain_of(A(), wrap()), B()), tuple_lift(fn)) =>
    #   chain_of(tuple_of(A(), B()), tuple_lift(fn)
    if this.pipe.op == wrap && this_len > 0 && this.path[end] > 0
      scan_idx = idx + 1
      scan_count = 1
      while scan_idx <= length(vnp)
          scan = vnp[scan_idx]
          if length(scan.path) >= this_len &&
                scan.path[this_len] > 1 &&
                scan.path[1:this_len-1] == this.path[1:this_len-1] &&
                scan.path[this_len] != this.path[this_len]
             scan_idx += 1
             continue
          end
          if scan.path == this.path && scan.pipe.op == wrap
              scan_idx += 1
              scan_count += 1
              continue
          end
          if length(scan.path) == this_len - 1 && scan.pipe.op == tuple_lift
              while scan_count > 0
                  popat!(vnp, idx)
                  scan_count -= 1
              end
              return true
          end
          break
      end
    end
    return false
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

function simplify_wrap!(vnp::Vector{NestedPipe}, start::Int)::Bool
    @assert vnp[start].pipe.op == wrap
    idx = start
    this = vnp[start]
    while idx < length(vnp)
      next = vnp[idx + 1]
      this_len = length(this.path)
      next_len = length(next.path)
      if next_len == this_len
        if this.path == next.path
          # chain_of(wrap(), flatten()) => pass()
          if next.pipe.op == flatten
              popat!(vnp, idx)
              popat!(vnp, idx)
              return true
          end
          # chain_of(wrap(), lift(f)) => lift(f)
          if next.pipe.op == lift
              popat!(vnp, idx)
              return true
          end
        end
      elseif next_len > this_len && this.path == next.path[1:this_len]
        # chain_of(wrap(), with_elements(p)) => chain_of(p, wrap())
        if next.path[this_len+1] == 0
            popat!(next.path, this_len+1)
            (vnp[idx], vnp[idx+1]) = (vnp[idx+1], vnp[idx])
            idx += 1
            continue
        end
      elseif this_len > next_len && next.path == this.path[1:next_len]
        # with_elements(wrap())
        if 0 == this.path[end]
          # chain_of(with_elements(wrap()), flatten()) => pass()
          if next.pipe.op == flatten && next_len + 1 == this_len
              popat!(vnp, idx)
              popat!(vnp, idx)
              return true
          end
          # chain_of(with_column(n, with_elements(wrap()))), distribute(n)) =>
          #   chain_of(distribute(n), with_elements(with_column(n, wrap())))
          if next.pipe.op == distribute && next_len + 2 == this_len &&
                this.path[end-1] == next.pipe.args[1]
              (this.path[end-1], this.path[end]) = (0, next.pipe.args[1])
              (vnp[idx], vnp[idx+1]) = (vnp[idx+1], vnp[idx])
              idx += 1
              continue
          end
        # with_column(n, wrap())
        else
          # chain_of(with_column(n, wrap()), distribute(n)) => wrap()
          if next.pipe.op == distribute && next_len + 1 == this_len &&
                this.path[end] == next.pipe.args[1]
              popat!(vnp, idx + 1)
              pop!(this.path)
              continue
          end
        end
      end
      if next.pipe.op == wrap
         if simplify_wrap!(vnp, idx + 1)
            continue
         end
      end
      break
    end
    return idx > start ? true : false
end

