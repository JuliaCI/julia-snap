const CURRENT_LTS = v"1.6"  # keep this up to date

#####

if isempty(ARGS)
    error("Expected release type as a command line argument to this script")
end

using HTTP
using JSON3

release = ARGS[1]
contents = JSON3.read(HTTP.get("https://julialang-s3.julialang.org/bin/versions.json").body)

versions = VersionNumber.(String.(keys(contents)))
if release == "lts"
    filter!(v -> v.major == CURRENT_LTS.major && v.minor == CURRENT_LTS.minor, versions)
else
    filter!(v -> v >= CURRENT_LTS, versions)
end
latest = maximum(versions)

substitutions = Dict(
    raw"${JULIA_VERSION}" => string(latest),
    raw"${JULIA_SERIES}" => string(latest.major, '.', latest.minor)
)

open(joinpath(dirname(@__DIR__), "snap", "snapcraft.yaml"), "w") do io
    yaml = read("snapcraft.yaml.in", String)
    for pair in substitutions
        yaml = replace(yaml, pair)
    end
    print(io, yaml)
end
