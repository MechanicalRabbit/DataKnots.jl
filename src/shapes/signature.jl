#
# Signature of a query.
#

struct Signature
    ishp::InputShape
    shp::OutputShape
end

let NO_ISHP = InputShape(NoneShape()),
    VOID_ISHP = InputShape(NativeShape(Nothing)),
    NO_SHP = OutputShape(AnyShape(), OPT|PLU)

    global Signature

    Signature() = Signature(NO_ISHP, NO_SHP)

    Signature(shp::OutputShape) = Signature(VOID_ISHP, shp)
end

function sigsyntax(sig::Signature)
    iex = sigsyntax(sig.ishp)
    ex = sigsyntax(sig.shp)
    if iex !== :Nothing
        ex = Expr(:(->), iex, ex)
    end
    ex
end

show(io::IO, sig::Signature) =
    Layouts.print_code(io, sigsyntax(sig))

signature(sig::Signature) = sig

ishape(sig::Signature) = sig.ishp

shape(sig::Signature) = sig.shp

idomain(sig::Signature) = domain(sig.ishp)

imode(sig::Signature) = mode(sig.ishp)

domain(sig::Signature) = domain(sig.shp)

mode(sig::Signature) = mode(sig.shp)

