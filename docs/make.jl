using ModelMacro
using Documenter

makedocs(;
    modules=[ModelMacro],
    authors="Ramiro Vignolo <ramirovignolo@gmail.com> and contributors",
    repo="https://github.com/rvignolo/ModelMacro.jl/blob/{commit}{path}#L{line}",
    sitename="ModelMacro.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)
