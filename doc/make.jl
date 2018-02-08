#!/usr/bin/env julia

using Pkg
if Pkg.installed("Documenter") == nothing
    Pkg.add("Documenter")
end

using Documenter
using QueryCombinators

# Highlight indented code blocks as Julia code.
using Markdown
Markdown.Code(code) = Markdown.Code("julia", code)

makedocs(
    format = :html,
    sitename = "QueryCombinators.jl",
    pages = [
        "index.md",
        "reference.md",
        "test/index.md",
        hide("test/layouts.md"),
    ],
    modules = [QueryCombinators])

deploydocs(
    repo = "github.com/rbt-lang/QueryCombinators.jl.git",
    julia = "nightly",
    osname = "linux",
    target = "build",
    deps = nothing,
    make = nothing)
