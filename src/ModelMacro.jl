module ModelMacro

using UnPack: @unpack

using Base.Meta: quot, isexpr
using MacroTools: rmlines, striplines, @match, @capture

using OrderedCollections

# como este paquete no puede correr sin UMC, tengo que reexportarlo. Tambien esta bueno
# para boundear con cuales versiones funciona de UMC (por si cambia)
# @reexport using UniversalMonteCarlo

include("utils.jl")
include("expression.jl")
include("attributes.jl")
include("parameters.jl")
include("process.jl")
include("processes.jl")
include("interest_rate.jl")
include("dynamics.jl")
include("macro_model.jl")

export @model
end
