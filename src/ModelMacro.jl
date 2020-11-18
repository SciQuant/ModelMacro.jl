module ModelMacro

using UnPack: @unpack
using Base.Meta: quot, isexpr
using MacroTools: rmlines, @match, @capture
using OrderedCollections

# como este paquete no puede correr sin UMC, tengo que reexportarlo. Tambien esta bueno
# para boundear con cuales versiones funciona de UMC (por si cambia)
# @reexport using UniversalMonteCarlo

@enum ParserReturn UMC_PARSER_OK UMC_PARSER_ERROR UMC_RUNTIME_OK UMC_RUNTIME_ERROR

include("expression.jl")
include("utils.jl")
include("attributes.jl")
include("parameters.jl")
include("process.jl")
include("processes.jl")
include("interest_rate.jl")
include("dynamics.jl")
include("macro_model.jl")

end
