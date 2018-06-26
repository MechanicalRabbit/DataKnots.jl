#!/usr/bin/env julia

try
    using Documenter
catch
    using Pkg
    Pkg.add("Documenter")
end

using Documenter
using DataKnots

# Highlight indented code blocks as Julia code.
using Markdown
Markdown.Code(code) = Markdown.Code("julia", code)

makedocs(
    format = :html,
    sitename = "DataKnots.jl",
    pages = [
        "index.md",
        "guide.md",
        "reference.md",
        "test/index.md",
        hide("test/layouts.md"),
        hide("test/vectors.md"),
        hide("test/shapes.md"),
        hide("test/queries.md"),
        hide("test/combinators.md"),
    ],
    modules = [DataKnots])

deploydocs(
    repo = "github.com/rbt-lang/DataKnots.jl.git",
    julia = "nightly",
    osname = "linux",
    target = "build",
    deps = nothing,
    make = nothing)
