#
# Cardinality of a collection.
#

"""
    Cardinality
    REG::Cardinality
    OPT::Cardinality
    PLU::Cardinality
    OPT|PLU::Cardinality

Cardinality constraint on a block of values.  `REG` stands for *1…1*, `OPT`
for *0…1*, `PLU` for *1…∞*, `OPT|PLU` for *0…∞*.
"""
primitive type Cardinality <: Enum{UInt8} 8 end

# Standard @enum definitions.

# Not using `@enum` because of custom printing functions.
#@enum Cardinality::UInt8 REG OPT PLU OPT_PLU

function Cardinality(x::Integer)
    (0x00 <= x <= 0x03) || Base.Enums.enum_argument_error(:Cardinality, x)
    return Base.bitcast(Cardinality, convert(UInt8, x))
end

Base.Enums.basetype(::Type{Cardinality}) = UInt8

Base.typemin(::Type{Cardinality}) = Cardinality(0x00)

Base.typemax(::Type{Cardinality}) = Cardinality(0x03)

Base.isless(c1::Cardinality, c2::Cardinality) =
    isless(UInt8(c1), UInt8(c2))

let insts = map(Cardinality, (0x00, 0x01, 0x02, 0x03))
    Base.instances(::Type{Cardinality}) = insts
end

show(io::IO, c::Cardinality) =
    print(
        io,
        c == REG ? "REG" :
        c == OPT ? "OPT" :
        c == PLU ? "PLU" :
        c == OPT|PLU ? "OPT|PLU" : "")

function show(io::IO, ::MIME"text/plain", t::Type{Cardinality})
    print(io, "Enum ")
    Base.show_datatype(io, t)
    print(io, ":")
    for c in instances(t)
        print(io, "\n", c, " = ", UInt8(c))
    end
end

const REG = Cardinality(0x00)
const OPT = Cardinality(0x01)
const PLU = Cardinality(0x02)

syntax(c::Cardinality) =
    c == OPT ? :? :
    c == PLU ? :+ :
    c == OPT|PLU ? :* : :!

# Bitwise operations.

(~)(c::Cardinality) =
    Base.bitcast(Cardinality, (~UInt8(c))&UInt8(OPT|PLU))

(|)(c1::Cardinality, c2::Cardinality) =
    Base.bitcast(Cardinality, UInt8(c1)|UInt8(c2))

(&)(c1::Cardinality, c2::Cardinality) =
    Base.bitcast(Cardinality, UInt8(c1)&UInt8(c2))

# Predicates.

isregular(c::Cardinality) =
    c == REG

isoptional(c::Cardinality) =
    c & OPT == OPT

isplural(c::Cardinality) =
    c & PLU == PLU

# Partial order.

bound(::Type{Cardinality}) = REG

bound(c1::Cardinality, c2::Cardinality) = c1 | c2

ibound(::Type{Cardinality}) = OPT|PLU

ibound(c1::Cardinality, c2::Cardinality) = c1 & c2

fits(c1::Cardinality, c2::Cardinality) = (c1 | c2) == c2

