struct SystemDynamics
    name::Symbol
    dx::Symbol
    x0::GeneralExpr
    m::GeneralExprOrNothing
    μ::Union{GeneralExprOrNothing,Dict{Symbol,GeneralExpr}}
    σ::Union{GeneralExprOrNothing,Dict{Symbol,GeneralExpr}}
    ρ::GeneralExprOrNothing
end

SystemDynamics(x, x0; μ=nothing, σ=nothing, m=nothing, ρ=nothing, dx=gensym(x)) =
    SystemDynamics(x, dx, x0, m, μ, σ, ρ)

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

    push!(parser.dynamics.P, name => SystemDynamics(name, x0, μ=μ, σ=σ, m=m, ρ=ρ))

    return UMC_PARSER_OK
end







function define_process_dynamics(parser, name, x0, m=nothing, ρ=nothing)

    iparameters = parser.parameters.internal

    kwargs = Expr(:tuple)
    isnothing(m) ? nothing : push!(kwargs.args, :(m = $m))
    isnothing(ρ) ? nothing : push!(kwargs.args, :(ρ = $ρ))

    ps = add_assignment!(iparameters, name, :(ProcessDynamics($x0; $kwargs...)), true)

    return UMC_PARSER_OK
end

function define_process(parser, x, dx, expr_μiip, expr_σiip, expr_μoop=expr_μiip, expr_σoop=expr_σiip)

    μiip = getfunction(parser, :μiip)
    σiip = getfunction(parser, :σiip)
    μoop = getfunction(parser, :μoop)
    σoop = getfunction(parser, :σoop)

    u = getvarname(parser, :u)

    push!(parser.D_expr.args, :(Dimension{1}()))

    idx = length(parser.D_expr.args)
    idxexpr = :(dimension(Ns[$idx]))

    for header in map(fparser -> getproperty(fparser, :header), (μiip, σiip, μoop, σoop))
        add_assignment!(header, name, :(Process($u, t, $idxexpr)), false)
    end

    !isnothing(expr_μiip) ? push!(μiip.body, expr_μiip) : nothing
    !isnothing(expr_σiip) ? push!(σiip.body, expr_σiip) : nothing
    !isnothing(expr_μoop) ? add_assignment!(μoop.body, dx, expr_μoop, false) : nothing
    !isnothing(expr_σoop) ? add_assignment!(σoop.body, dx, expr_σoop, false) : nothing

    return UMC_PARSER_OK
end