using ChainRulesTestUtils
using Documenter

makedocs(;
    modules=[ChainRulesTestUtils],
    format=Documenter.HTML(; prettyurls=false, assets=["assets/chainrules.css"]),
    sitename="ChainRulesTestUtils",
    authors="JuliaDiff contributors",
    strict=true,
    checkdocs=:exports,
)

const repo = "github.com/JuliaDiff/ChainRulesTestUtils.jl.git"
deploydocs(; repo=repo, push_preview=true)
