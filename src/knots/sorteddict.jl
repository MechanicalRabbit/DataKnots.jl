#
# Poor man's immutable sorted dictionary.
#

const PropertyMap{T} = Vector{Pair{Symbol,T}} where {T}

function Base.merge!(target::PropertyMap{T}, sources::PropertyMap{T}...) where {T}
    for source in sources
        i = 1
        for pair in source
            while i <= length(target) && target[i].first < pair.first
                i += 1
            end
            if i <= length(target) && target[i].first == pair.first
                target[i] = pair
            else
                insert!(target, i, pair)
            end
        end
    end
    return target
end

Base.merge(sources::PropertyMap{T}...) where {T} =
    merge!(PropertyMap{T}(), sources...)

function Base.merge!(combine::Function, target::PropertyMap{T}, sources::PropertyMap{T}...) where {T}
    for source in sources
        i = 1
        for pair in source
            while i <= length(target) && target[i].first < pair.first
                i += 1
            end
            if i <= length(target) && target[i].first == pair.first
                target[i] = Pair{Symbol,T}(pair.first, combine(target[i].second, pair.second))
            else
                insert!(target, i, pair)
            end
        end
    end
    return target
end

Base.merge(combine::Function, sources::PropertyMap{T}...) where {T} =
    merge!(combine, PropertyMap{T}(), sources...)

