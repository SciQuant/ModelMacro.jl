module ModelMacro

using UnPack: @unpack

using Base.Meta: quot, isexpr
using MacroTools: rmlines, striplines, @match, @capture

using OrderedCollections

# como este paquete no puede correr sin UMC, tengo que reexportarlo. Tambien esta bueno
# para boundear con cuales versiones funciona de UMC (por si cambia)
# @reexport using UniversalMonteCarlo # si tengo conflicto con los types, usar `Parser`
# @reexport using UniversalPricing

include("utils.jl")
include("expression.jl")
include("attributes.jl")
include("parameters.jl")
include("dynamics/dynamics.jl")
include("macro_model.jl")

export @model
end
