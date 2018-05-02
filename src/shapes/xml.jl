#
# XML type.
#

struct XMLShape <: DerivedShape
end

syntax(::XMLShape) =
    Expr(:call, nameof(XMLShape))

sigsyntax(::XMLShape) =
    :XML

bound(shp1::XMLShape, ::XMLShape) = shp1

ibound(shp1::XMLShape, ::XMLShape) = shp1

