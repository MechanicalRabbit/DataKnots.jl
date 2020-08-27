make() = 
#  withenv("LINES"=>11, "COLUMNS"=>72) do
    runtests(joinpath("doc/src", ENV["DOCFILE"]), mod=Main)
#    Base.active_repl.options.iocontext[:displaysize] = 
#      (convert(Integer, trunc(displaysize(Base.stdout)[1] * 2/3)), 72)
#    nothing
#  end

atreplinit() do repl
    try
        @eval using BenchmarkTools: @btime
        @eval using NarrativeTest
        @eval using Revise
        @eval using DataKnots
        @eval make()
        @async Revise.wait_steal_repl_backend()
    catch
        @warn "startup error?"
    end
end
