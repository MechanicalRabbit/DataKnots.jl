# encode path as nested column offsets, in the case of `with_columns`;
# or, in the case of `with_elements`, `nothing`.
PipelinePath = Vector{Union{Some{Union{Int, Symbol}}, Nothing}}

# wrap a pipeline in combinations of `with_elements` and `with_columns`
function contextualize(path::PipelinePath, p::Pipeline)
     for segment in reverse(path)
        if segment == nothing
            p = with_elements(p)
            continue
        end
        p = with_column(something(segment), p)
     end
     return p
end

function linearize(p::Pipeline)::Vector{Pipeline}
     retval = Pipeline[]
     this_pipeline::Pipeline = p
     this_path::PipelinePath = PipelinePath()
     stack = Tuple{PipelinePath, Pipeline}[(this_path, this_pipeline)]
     while !isempty(stack)
         (path, p) = pop!(stack)
         if p.op == pass
             continue
         end
         if p.op == chain_of
             for s in reverse(p.args[1])
               push!(stack, (path, s))
             end
             continue
         end
         if p.op == with_elements
            this_pipeline = p.args[1]
            this_path = push!(copy(path), nothing)
            push!(stack, (this_path, this_pipeline))
            continue
         end
         if p.op == tuple_of
             push!(retval, contextualize(path,
                    tuple_of(p.args[1], length(p.args[2]))))
             for idx in reverse(1:length(p.args[2]))
                  this_pipeline = p.args[2][idx]
                  this_path = push!(copy(path), Some(idx))
                  push!(stack, (this_path, this_pipeline))
             end
             continue
         end
         push!(retval, contextualize(path, p))
     end
     return retval
end

function rewrite_all(p::Pipeline)::Pipeline
    return chain_of(linearize(p)...) |> designate(signature(p))
end
