OS_NAME = get(ENV, "TRAVIS_OS_NAME", "")
JULIA_VERSION = get(ENV, "TRAVIS_JULIA_VERSION", "")

if OS_NAME == "linux" && JULIA_VERSION == "nightly"
    using Pkg
    if Pkg.installed("Coverage") == nothing
        Pkg.add("Coverage")
    end

    using Coverage

    Codecov.submit(Codecov.process_folder())
end
