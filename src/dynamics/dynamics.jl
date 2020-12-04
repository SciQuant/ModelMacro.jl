
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

function generate_dynamics_parameters(dynamics::Dynamics)
    dynamics_assignments = generate_dynamics(dynamics)
    D_assignment = generate_dimensions(dynamics_assignments)
    M_assignment = generate_noise_dimensions(dynamics_assignments)
    return dynamics_assignments, D_assignment, M_assignment
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

# f IIP
function generate_inplace_drift(dynamics::Dynamics, args, paramsnames, D)
    @unpack du, u, p, t = args
    f = Function{true}(gensym(:f), args=Expr(:tuple, du, u, p, t))
    unpack = generate_unpack_macro(paramsnames, p)
    securities = generate_securities(dynamics, du, u, D)
    drifts = generate_drifts(dynamics, Val(:IIP))
    push!(f.header.args, unpack)
    push!(f.header.args, convert.(Expr, securities)...)
    push!(f.body.args, convert.(Expr, drifts)...)
    return convert(Expr, f)
end

# f OOP
function generate_outofplace_drift(dynamics::Dynamics, args, paramsnames, D)
    @unpack u, p, t = args
    f = Function{false}(gensym(:f), args=Expr(:tuple, u, p, t))
    unpack = generate_unpack_macro(paramsnames, p)
    securities = generate_securities(dynamics, u, D)
    drifts = generate_drifts(dynamics, Val(:OOP))
    output = generate_output(drifts)
    push!(f.header.args, unpack)
    push!(f.header.args, convert.(Expr, securities)...)
    push!(f.body.args, convert.(Expr, drifts)...)
    push!(f.output.args, output)
    return convert(Expr, f)
end

# g IIP + DN
function generate_inplace_diagonalnoise_diffusion(dynamics::Dynamics, args, paramsnames, D)
    @unpack du, u, p, t = args
    g = Function{true}(gensym(:g), args=Expr(:tuple, du, u, p, t))
    unpack = generate_unpack_macro(paramsnames, p)
    securities = generate_securities(dynamics, du, u, D)
    diffusions = generate_diffusions(dynamics, Val(:IIP)) # Val(:DN)
    push!(g.header.args, unpack)
    push!(g.header.args, convert.(Expr, securities)...)
    push!(g.body.args, convert.(Expr, diffusions)...)
    return convert(Expr, g)
end

# g OOP + DN
function generate_outofplace_diagonalnoise_diffusion(dynamics::Dynamics, args, paramsnames, D)
    @unpack u, p, t = args
    g = Function{false}(gensym(:g), args=Expr(:tuple, u, p, t))
    unpack = generate_unpack_macro(paramsnames, p)
    securities = generate_securities(dynamics, u, D)
    diffusions = generate_diffusions(dynamics, Val(:OOP)) # Val(:DN)
    output = generate_output(diffusions, Val(:DN))
    push!(g.header.args, unpack)
    push!(g.header.args, convert.(Expr, securities)...)
    push!(g.body.args, convert.(Expr, diffusions)...)
    push!(g.output.args, output)
    return convert(Expr, g)
end

# g IIP + NonDN
function generate_inplace_nondiagonalnoise_diffusion(dynamics::Dynamics, args, paramsnames, D, M)
    @unpack du, u, p, t = args
    g = Function{true}(gensym(:g), args=Expr(:tuple, du, u, p, t))
    unpack = generate_unpack_macro(paramsnames, p)
    securities = generate_securities(dynamics, du, u, D, M)
    diffusions = generate_diffusions(dynamics, Val(:IIP)) # Val(:NonDN)
    push!(g.header.args, unpack)
    push!(g.header.args, convert.(Expr, securities)...)
    push!(g.body.args, convert.(Expr, diffusions)...)
    return convert(Expr, g)
end

# g OOP + NonDN
# en esta funcion tenemos problemas ya que aun no podemos construir una block matrix usando
# static arrays de forma simple. Un mecanismo seria completar la matrix usando matrices con
# zeros e implementando hcat y vcat (no es lo mejor por performance ya que tendriamos varias
# posiciones con zeros, pero bueno). Por otro lado esta lo de usar SDiagonal, pero eso tiene
# otras dificultades asociadas.
function generate_outofplace_nondiagonalnoise_diffusion(dynamics::Dynamics, args, paramsnames, D)
    @unpack u, p, t = args
    g = Function{false}(gensym(:g), args=Expr(:tuple, u, p, t))
    unpack = generate_unpack_macro(paramsnames, p)
    securities = generate_securities(dynamics, u, D) # no necesita M yet
    diffusions = generate_diffusions(dynamics, Val(:OOP)) # Val(:NonDN)
    output = generate_output(diffusions, Val(:NonDN))
    push!(g.header.args, unpack)
    push!(g.header.args, convert.(Expr, securities)...)
    push!(g.body.args, convert.(Expr, diffusions)...)
    push!(g.output.args, output)
    return convert(Expr, g)
end