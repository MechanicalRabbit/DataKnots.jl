#
# JSON type.
#

struct JSONShape <: DerivedShape
end

syntax(::JSONShape) =
    Expr(:call, nameof(JSONShape))

sigsyntax(::JSONShape) =
    :JSON

bound(shp1::JSONShape, ::JSONShape) = shp1

ibound(shp1::JSONShape, ::JSONShape) = shp1

