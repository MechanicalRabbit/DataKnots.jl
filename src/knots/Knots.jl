#
# DataKnot definition and operations.
#

module Knots

export
    DataKnot,
    cardinality,
    domain,
    elements,
    mode,
    signature,
    shape,
    thedb,
    unusedb!,
    usedb,
    usedb!

import ..Layouts: syntax

using ..Vectors
import ..Vectors: elements

using ..Shapes
import ..Shapes: cardinality, domain, mode, signature, shape

import Base:
    convert,
    get,
    show

include("dataknot.jl")
include("db.jl")
include("guess.jl")
include("display.jl")

end
