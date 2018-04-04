#
# Filesystem operations.
#

struct FilesystemEntry
    path::String
    stat::Base.StatStruct
end

FilesystemEntry(path::String) =
    FilesystemEntry(path, stat(path))

FilesystemEntry() =
    FilesystemEntry(pwd())

show(io::IO, f::FilesystemEntry) =
    print(io, f.path)

filesystem() =
    Combinator(filesystem)

translate(::Type{Val{:filesystem}}, ::Tuple{}) =
    filesystem()

function filesystem(env::Environment, q::Query)
    r = chain_of(
            tuple_of(Symbol[], []),
            lift_to_tuple(FilesystemEntry),
            as_block(),
    ) |> designate(InputShape(AnyShape()), OutputShape(FilesystemEntry))
    compose(q, r)
end

lookup(ty::Type{FilesystemEntry}, name::Symbol) =
    lookup(ty, Val{name})

lookup(::Type{FilesystemEntry}, ::Type{<:Val}) =
    missing

lookup(::Type{FilesystemEntry}, ::Type{Val{:path}}) =
    chain_of(
        lift(e -> e.path),
        as_block(),
    ) |> designate(InputShape(FilesystemEntry), OutputShape(String) |> decorate(:tag => :path))

lookup(::Type{FilesystemEntry}, ::Type{Val{:name}}) =
    chain_of(
        lift(e -> basename(e.path)),
        as_block(),
    ) |> designate(InputShape(FilesystemEntry), OutputShape(String) |> decorate(:tag => :name))

lookup(::Type{FilesystemEntry}, ::Type{Val{:directory}}) =
    chain_of(
        lift(e -> dirname(e.path)),
        as_block(),
    ) |> designate(InputShape(FilesystemEntry), OutputShape(String) |> decorate(:tag => :directory))


lookup(::Type{FilesystemEntry}, ::Type{Val{:size}}) =
    chain_of(
        lift(e -> e.stat.size),
        as_block(),
    ) |> designate(InputShape(FilesystemEntry), OutputShape(Int64) |> decorate(:tag => :size))

lookup(::Type{FilesystemEntry}, ::Type{Val{:entry}}) =
    chain_of(
        lift(e -> [FilesystemEntry(joinpath(e.path, name))
                   for name in (isdir(e.path) ? readdir(e.path) : String[])]),
        decode_vector(),
    ) |> designate(InputShape(FilesystemEntry), OutputShape(FilesystemEntry, OPT|PLU) |> decorate(:tag => :entry))

lookup(::Type{FilesystemEntry}, ::Type{Val{:content}}) =
    chain_of(
        lift(e -> isfile(e.path) ? read(e.path, String) : missing),
        decode_missing(),
    ) |> designate(InputShape(FilesystemEntry), OutputShape(String, OPT) |> decorate(:tag => :content))

function fspattern2regex(key::String)
    key = replace(key, r"[^0-9A-Za-z*?]" => s"\\\0")
    key = replace(key, r"\*" => s".*")
    key = replace(key, r"\?" => s".")
    key = "^" * key * "\$"
    Regex(key)
end

lookup(::Type{FilesystemEntry}, key::String) =
    let key = fspattern2regex(key)
        chain_of(
            lift(e -> [FilesystemEntry(joinpath(e.path, name))
                       for name in (isdir(e.path) ? readdir(e.path) : String[])
                       if occursin(key, name)]),
            decode_vector(),
        ) |> designate(InputShape(FilesystemEntry), OutputShape(FilesystemEntry, OPT|PLU))
    end

