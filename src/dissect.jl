#
# Pattern dissecting.
#

macro dissect(ex)
    esc(dissect(__module__, ex))
end

function dissect(mod, @nospecialize ex)
    if Meta.isexpr(ex, :call, 3) && ex.args[1] === :~
        val = ex.args[2]
        pat = ex.args[3]
        dissect(mod, val, pat)
    elseif ex isa Expr
        Expr(ex.head, Any[dissect(mod, arg) for arg in ex.args]...)
    else
        ex
    end
end

function dissect(mod::Module, @nospecialize(val), @nospecialize pat)
    pat !== :_ || return :(true)
    scr = gensym(:scr)
    ex = dissect(mod, scr, pat)
    :(local $scr = $val; $ex)
end

function dissect(mod::Module, scr::Symbol, @nospecialize pat)
    if pat isa Expr
        if Meta.isexpr(pat, :call, 3) && pat.args[1] === :~ && pat.args[2] isa Symbol
            ref = pat.args[2]
            ex = dissect(mod, scr, pat.args[3])
            :($ex && (local $ref = $scr; true))
        elseif Meta.isexpr(pat, :call) && length(pat.args) >= 1 &&
               (local f = pat.args[1]; f isa Symbol) && isconst(mod, f)
            dissect(mod, scr, getfield(mod, f), tuple(pat.args[2:end]...))
        elseif Meta.isexpr(pat, :(::), 2)
            ty = pat.args[2]
            ex = dissect(mod, scr, pat.args[1])
            :($scr isa $ty && $ex)
        elseif Meta.isexpr(pat, (:&&, :||))
            Expr(pat.head, Any[dissect(mod, scr, arg) for arg in pat.args]...)
        elseif Meta.isexpr(pat, :ref) && length(pat.args) >= 1
            ty = pat.args[1]
            ex = dissect(mod, scr, Expr(:vect, pat.args[2:end]...))
            :($scr isa Vector{$ty} && ex)
        elseif Meta.isexpr(pat, :vect)
            minlen = 0
            varlen = false
            for argpat in pat.args
                if Meta.isexpr(argpat, :..., 1)
                    !varlen || error("duplicate vararg pattern in $(repr(pat))")
                    varlen = true
                else
                    minlen += 1
                end
            end
            exs = Any[!varlen ? :(length($scr) == $minlen) : :(length($scr) >= $minlen)]
            seen_vararg = false
            for (k, argpat) in enumerate(pat.args)
                if Meta.isexpr(argpat, :..., 1)
                    argpat = argpat.args[1]
                    ex = dissect(mod, :($view($scr, $k : $lastindex($scr) - $(minlen-k+1))), argpat)
                    seen_vararg = true
                elseif seen_vararg
                    ex = dissect(mod, :($scr[$lastindex($scr) - $(minlen-k+1)]), argpat)
                else
                    ex = dissect(mod, :($scr[$k]), argpat)
                end
                push!(exs, ex)
            end
            Expr(:&&, exs...)
        else
            error("expected a pattern expression; got $(repr(pat))")
        end
    elseif pat isa Symbol
        if pat === :_
            :(true)
        elseif isconst(mod, pat)
            val = getfield(mod, pat)
            Base.issingletontype(typeof(val)) ?
                :($scr === $pat) : :($scr == $pat)
        else
            :(local $pat = $scr; true)
        end
    elseif pat isa QuoteNode && pat.val isa Symbol
        :($scr === $pat)
    else
        Base.issingletontype(typeof(pat)) ?
            :($scr === $pat) : :($scr == $pat)
    end
end

