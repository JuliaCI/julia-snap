const CURRENT_LTS = v"1.6"  # keep this up to date

#####

if isempty(ARGS)
    error("Expected release type as a command line argument to this script")
end

using HTTP
using JSON3

snaparch(jlarch) = jlarch == "x86_64" ? "amd64" :
                   jlarch == "i686" ? "i386" :
                   jlarch == "aarch64" ? "arm64" :
                   jlarch == "armv7l" ? "armhf" :
                   throw(ArgumentError("unrecognized architecture $jlarch"))

release = ARGS[1]
contents = JSON3.read(HTTP.get("https://julialang-s3.julialang.org/bin/versions.json").body)

versions = VersionNumber.(String.(keys(contents)))
if release == "lts"
    filter!(v -> v.major == CURRENT_LTS.major && v.minor == CURRENT_LTS.minor, versions)
else
    filter!(v -> v >= CURRENT_LTS, versions)
end
latest = maximum(versions)

urls = Dict(snaparch(file.arch) => file.url for file in contents[Symbol(latest)].files
            if file.os == "linux" && !occursin("musl", file.triplet) &&
               file.extension == "tar.gz")

open(joinpath(dirname(@__DIR__), "snap", "snapcraft.yaml"), "w") do io
    print(io, """
          name: julia
          version: '$latest'
          title: The Julia Language
          summary: The Julia programming language
          description: |
            Julia is a high level, high performance, dynamic language for technical computing.
          license: MIT

          base: core18
          confinement: classic
          type: app

          architectures:
          """)
    for arch in keys(urls)
        println(io, "- build-on: ", arch)
    end
    print(io, """

          apps:
            julia:
              command: bin/julia
            julia-docs:
              command: julia-docs.sh \$SNAP/share/doc/julia/html/en/index.html

          parts:
            julia:
              plugin: dump
              source:
          """)
    for (arch, url) in urls
        println(io, "    - on ", arch, ": ", url)
    end
    print(io, """
            julia-docs:
              plugin: dump
              source: snap/local
          """)
end
