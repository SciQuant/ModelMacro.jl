
include("system/system.jl")

include("models/models.jl")

struct Dynamics
    systems::OrderedDict{Symbol,SystemDynamics}
    models::OrderedDict{Symbol,ModelDynamics}
end

function Dynamics()
    reset_system_counter()
    return Dynamics(OrderedDict{Symbol,SystemDynamics}(), OrderedDict{Symbol,ModelDynamics}())
end

function generate_dynamics(dynamics::Dynamics)
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    ds = vcat(dynamics_assignment.(models)..., dynamics_assignment.(systems)...)
    return ds
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

# f IIP - g IIP + DN
function generate_securities(dynamics::Dynamics, du, u, D)
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    ss = vcat(security_assignment.(models, du, u, D)..., security_assignment.(systems, du, u, D)...)
    return ss
end

# f OOP - g OOP + DN - g OOP + NonDN
function generate_securities(dynamics::Dynamics, u, D)
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    ss = vcat(security_assignment.(models, u, D)..., security_assignment.(systems, u, D)...)
    return ss
end

# g IIP + NonDN
function generate_securities(dynamics::Dynamics, du, u, D, M)
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    ss = vcat(security_assignment.(models, du, u, D, M)..., security_assignment.(systems, du, u, D, M)...)
    return ss
end

function generate_drifts(dynamics::Dynamics, case::Union{Val{:IIP},Val{:OOP}})
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    ds = vcat(drift_assignment.(models, case)..., drift_assignment.(systems, case)...)
    return ds
end

function generate_diffusions(dynamics::Dynamics, case::Union{Val{:IIP},Val{:OOP}})
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    ds = vcat(diffusion_assignment.(models, case)..., diffusion_assignment.(systems, case)...)
    return ds
end

# f OOP - g OOP + DN
generate_output(a::Vector{AssignmentExpr}) = Expr(:call, :vcat, lefthandside.(a)...)
generate_output(a::Vector{AssignmentExpr}, ::Val{:DN}) = generate_output(a)

# g OOP + NonDN
# Aun no sabemos como concatenar varias SMatrix y formar una SMatrix Block Diagonal. See
# issue #856 in StaticArrays.jl
generate_output(a::Vector{AssignmentExpr}, ::Val{:NonDN}) = generate_output(a, Val(:DN)) # fix
