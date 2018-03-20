#
# Parsing queries from Julia syntax
#

translate(ex) =
    error("invalid query expression: $(repr(ex))")

translate(val::Union{Number,String}) =
    convert(SomeCombinator, val)

translate(s::Symbol) =
    translate(Val{s})

translate(qn::QuoteNode) =
    translate(qn.value)

function translate(ex::Expr)
    if ex.head == :.
        return compose(translate.(ex.args)...)
    end
    if ex.head == :call && length(ex.args) >= 1
        call = ex.args[1]
        if call == :(=>) && length(ex.args) == 3 && ex.args[2] isa Symbol
            return compose(translate(ex.args[3]), tag(ex.args[2]))
        elseif call isa Symbol
            return translate(Val{call}, (ex.args[2:end]...,))
        elseif call isa QuoteNode
            return translate(Expr(:call, call.value, ex.args[2:end]...))
        elseif call isa Expr && call.head == :. && !isempty(call.args)
            return compose(translate.(call.args[1:end-1])..., translate(Expr(:call, call.args[end], ex.args[2:end]...)))
        end
    end
    if ex.head == :block
        args = (translate(arg) for arg in ex.args if !(arg isa LineNumberNode))
        return compose(args...)
    end
    error("invalid query expression: $(repr(ex))")
end

macro translate(ex)
    return quote
        translate($(QuoteNode(ex)))
    end
end

macro query(ex)
    if ex isa Expr && ex.head == :where && length(ex.args) >= 1
        params = [param isa Expr && param.head == :(=) ? Expr(:kw, param.args...) : param
                  for param in ex.args[2:end]]
        ex = ex.args[1]
        return quote
            query(translate($(QuoteNode(ex))); $(params...))
        end
    end
    return quote
        query(translate($(QuoteNode(ex))))
    end
end

