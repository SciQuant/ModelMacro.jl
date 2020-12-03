
let N = 0
    global function system_counter()
        N += 1
    end
    global function reset_system_counter()
        N = 0
    end
end

struct SystemDynamics
    dname::Symbol # dynamics name
    sname::Symbol # security name
    x0::GeneralExpr
    μ::Union{GeneralExprOrNothing,Dict{Val,GeneralExpr}}
    σ::Union{GeneralExprOrNothing,Dict{Val,GeneralExpr}}
    m::GeneralExprOrNothing
    ρ::GeneralExprOrNothing
    idx::Int64
end

SystemDynamics(dname, sname, idx, x0; μ=nothing, σ=nothing, m=nothing, ρ=nothing) =
    SystemDynamics(dname, sname, x0, μ, σ, m, ρ, idx)

function parse_system!(parser, block)

    name = block.args[3]

    if !isa(name, Symbol)
        error("expected `@system` name as a `Symbol`, got '$(string(name))' instead.")
    end

    required_attrs_keys = (:x₀,)
    optional_attrs_keys = (:m, :μ, :σ, :ρ)

    # parse attributes
    attrs = parse_attributes!(block.args[4], required_attrs_keys, optional_attrs_keys)

    x0 = attrs[:x₀]
    m = get(attrs, :m, nothing)
    μ = get(attrs, :μ, nothing)
    σ = get(attrs, :σ, nothing)
    ρ = get(attrs, :ρ, nothing)

    push!(
        parser.dynamics.systems, name =>
            SystemDynamics(gensym(name), name, system_counter(), x0; μ=μ, σ=σ, m=m, ρ=ρ)
    )

    return UMC_PARSER_OK
end

function dynamics_assignment(system::SystemDynamics)
    @unpack dname, x0, m, ρ = system
    kwargs = Expr(:tuple)
    isnothing(m) ? nothing : push!(kwargs.args, :(m = $m))
    isnothing(ρ) ? nothing : push!(kwargs.args, :(ρ = $ρ))
    lhs = dname
    rhs = :(SystemDynamics($x0; $kwargs...))
    return AssignmentExpr(lhs, rhs)
end

# f IIP - g IIP + DN
function security_assignment(system::SystemDynamics, du, u, D)
    @unpack dname, sname, idx = system
    lhs = sname
    idx_D_from = idx - 1
    idx_D_to = idx
    D_from = iszero(idx_D_from) ? 1 : :(dimension($D[$idx_D_from]) + 1)
    D_to = :(dimension($D[$idx_D_to]))
    rhs = :(Security{dimension($dname),noise_dimension($dname),true}($du, $u, t, $D_from:$D_to))
    return AssignmentExpr(lhs, rhs)
end

# f OOP - g OOP + DN - g OOP + NonDN
function security_assignment(system::SystemDynamics, u, D)
    @unpack dname, sname, idx = system
    lhs = sname
    idx_D_from = idx - 1
    idx_D_to = idx
    D_from = iszero(idx_D_from) ? 1 : :(dimension($D[$idx_D_from]) + 1)
    D_to = :(dimension($D[$idx_D_to]))
    rhs = :(Security{dimension($dname),noise_dimension($dname),true}($u, t, $D_from:$D_to))
    return AssignmentExpr(lhs, rhs)
end

# g IIP + NonDN
function security_assignment(system::SystemDynamics, du, u, D, M)
    @unpack dname, sname, idx = system
    lhs = sname
    idx_D_from = idx - 1
    idx_D_to = idx
    D_from = iszero(idx_D_from) ? 1 : :(dimension($D[$idx_D_from]) + 1)
    D_to = :(dimension($D[$idx_D_to]))
    idx_M_from = idx - 1
    idx_M_to = idx
    M_from = iszero(idx_M_from) ? 1 : :(noise_dimension($M[$idx_M_from]) + 1)
    M_to = :(noise_dimension($M[$idx_M_to]))
    rhs = :(Security{dimension($dname),noise_dimension($dname),false}($du, $u, t, $D_from:$D_to, $M_from:$M_to))
    return AssignmentExpr(lhs, rhs)
end

function drift_assignment(system::SystemDynamics, case::Union{Val{:IIP},Val{:OOP}})
    @unpack μ = system
    return μ isa Dict ? AssignmentExpr(gensym(), μ[case]) : AssignmentExpr(gensym(), μ)
end

function diffusion_assignment(system::SystemDynamics, case::Union{Val{:IIP},Val{:OOP}})
    @unpack σ = system
    return σ isa Dict ? AssignmentExpr(gensym(), σ[case]) : AssignmentExpr(gensym(), σ)
end