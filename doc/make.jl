#!/usr/bin/env julia

using Pkg
haskey(Pkg.installed(), "Documenter") || Pkg.add("Documenter")

using Documenter
using DataKnots

# Highlight indented code blocks as Julia code.
using Markdown
Markdown.Code(code) = Markdown.Code("julia", code)

makedocs(
    sitename = "DataKnots.jl",
    pages = [
        "Home" => "index.md",
        "install.md",
        "thinking.md",
        "usage.md",
        hide("implementation.md",
             ["vectors.md", "queries.md", "shapes.md", "lifting.md",
              "pipelines.md"]),
    ],
    modules = [DataKnots])

deploydocs(
    repo = "github.com/rbt-lang/DataKnots.jl.git",
)
