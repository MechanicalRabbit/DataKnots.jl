#
# Navigation syntax.
#


struct Navigation
    _path::Tuple{Vararg{Symbol}}
end

Base.getproperty(nav::Navigation, s::Symbol) =
    let path = getfield(nav, :_path)
        Navigation((path..., s))
    end

show(io::IO, nav::Navigation) =
    let path = getfield(nav, :_path)
        print(io, join((:It, path...), "."))
    end

const It = Navigation(())

