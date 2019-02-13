#!/usr/bin/env julia

using Pkg
haskey(Pkg.installed(), "Plots") || Pkg.add("Plots")
haskey(Pkg.installed(), "Literate") || Pkg.add("Literate")
haskey(Pkg.installed(), "Documenter") || Pkg.add("Documenter")
haskey(Pkg.installed(), "Random") || Pkg.add("Random")
haskey(Pkg.installed(), "Distributions") || Pkg.add("Distributions")

using Documenter
using DataKnots
using Literate
using Plots

# Convert Literate example code to markdown.
INPUTS = joinpath(@__DIR__, "src", "simulation.jl")
OUTPUT = joinpath(@__DIR__, "src")
Literate.markdown(INPUTS, OUTPUT, documenter=true, credit=false)

# Highlight indented code blocks as Julia code.
using Markdown
Markdown.Code(code) = Markdown.Code("julia", code)

makedocs(
    sitename = "DataKnots.jl",
    pages = [
        "Home" => "index.md",
        "start.md",
        "thinking.md",
        "reference.md",
        hide("implementation.md",
             ["vectors.md", "queries.md", "shapes.md", "lifting.md",
              "pipelines.md"]),
        "simulation.md",
    ],
    modules = [DataKnots])

deploydocs(
    repo = "github.com/rbt-lang/DataKnots.jl.git",
)
