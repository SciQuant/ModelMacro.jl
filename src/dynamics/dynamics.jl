
include("system/system.jl")

include("models/models.jl")

struct Dynamics
    systems::OrderedDict{Symbol,SystemDynamics}
    models::OrderedDict{Symbol,ModelDynamics}
end

function Dynamics()
    return Dynamics(
        OrderedDict{Symbol,SystemDynamics}(),
        OrderedDict{Symbol,ModelDynamics}()
    )
end


function generate_functions(d::Dynamics) end # generates dynamics functions


# genero un array de AssignmentExpr de dynamicas, el resultado de esta funcion se pasa a una
# expresion tupla o block
function generate_dynamics(dynamics::Dynamics)
    ds = AssignmentExpr[]
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    ds = vcat(dynamics_assignment.(models)..., dynamics_assignment.(systems)...)
    return ds
end

function dynamics_assignment(model::ShortRateModelDynamics{:OneFactorAffine})
    @unpack srm, params, x = model
    @unpack κ, θ, Σ, α, β, ξ₀, ξ₁ = params
    kwargs = Expr(:tuple)
    isnothing(ξ₀) ? nothing : push!(kwargs.args, :(ξ₀ = $ξ₀))
    isnothing(ξ₁) ? nothing : push!(kwargs.args, :(ξ₁ = $ξ₁))
    lhs = srm # ya esta gensymeado
    rhs = :(OneFactorAffineModelDynamics($(x.x0), $κ, $θ, $Σ, $α, $β; $kwargs...))
    ax = AssignmentExpr(lhs, rhs)
    aB = dynamics_assignment(model.B)
    return [ax, aB]
end

function dynamics_assignment(model::ShortRateModelDynamics{:MultiFactorAffine})
    @unpack srm, params, x = model
    @unpack κ, θ, Σ, α, β, ξ₀, ξ₁ = params
    lhs = srm # ya esta gensymeado
    rhs = :(MultiFactorAffineModelDynamics($(x.x0), $κ, $θ, $Σ, $α, $β, $ξ₀, $ξ₁))
    return AssignmentExpr(lhs, rhs)
end

function dynamics_assignment(system::SystemDynamics)
    @unpack name, x0, m, ρ = system
    kwargs = Expr(:tuple)
    isnothing(m) ? nothing : push!(kwargs.args, :(m = $m))
    isnothing(ρ) ? nothing : push!(kwargs.args, :(ρ = $ρ))
    lhs = gensym(name)
    rhs = :(SystemDynamics($x0; $kwargs...))
    return AssignmentExpr(lhs, rhs)
end

function generate_dimensions(dynamics::Vector{AssignmentExpr})
    names = lefthandside.(dynamics)
    t = Expr(:tuple)
    for name in names
        push!(t.args, Expr(:call, Expr(:curly, :Dimension, Expr(:call, :dimension, name))))
    end
    lhs = gensym(:D)
    rhs = Expr(:call, :cumsum, t)
    return AssignmentExpr(lhs, rhs)
end

function generate_noise_dimensions(dynamics::Vector{AssignmentExpr})
    names = lefthandside.(dynamics)
    t = Expr(:tuple)
    for name in names
        push!(t.args, Expr(:call, Expr(:curly, :Dimension, Expr(:call, :noise_dimension, name))))
    end
    lhs = gensym(:M)
    rhs = Expr(:call, :cumsum, t)
    return AssignmentExpr(lhs, rhs)
end