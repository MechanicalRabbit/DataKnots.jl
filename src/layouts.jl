#
# Optimal source code formatter for a fixed width screen.
# (see <https://research.google.com/pubs/pub44667.html>)
#

module Layouts

export
    pretty_print,
    print_code

import Base:
    IndexStyle,
    getindex,
    size,
    show,
    *, /, |

const DEFAULT_LINE_WIDTH = 79
const DEFAULT_BREAK_COST = 1
const DEFAULT_SPILL_COST = 2

include("layouts/tile.jl")
include("layouts/fit.jl")
include("layouts/code.jl")

"""
    Layouts.pretty_print([io::IO], data)

Formats the data so that it fits the width of the output screen.
"""
pretty_print(args...; kwds...) =
    pretty_print(STDOUT, args...; kwds...)

pretty_print(io::IO, args...; kwds...) =
    pretty_print(io, tile(args...; kwds...))

function pretty_print(io::IO, lt::Layout)
    render(io, best(fit(io, lt)))
    nothing
end

"""
    Layouts.print_code([io::IO], code)

Formats a Julia expression.
"""
print_code(ex) =
    print_code(STDOUT, ex)

print_code(io::IO, ex) =
    pretty_print(io, tile_code(ex))

end
