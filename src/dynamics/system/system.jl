
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
    m::GeneralExprOrNothing
    μ::Union{GeneralExprOrNothing,Dict{Symbol,GeneralExpr}}
    σ::Union{GeneralExprOrNothing,Dict{Symbol,GeneralExpr}}
    ρ::GeneralExprOrNothing
    idx::Int64
end

SystemDynamics(dname, sname, x0, idx; μ=nothing, σ=nothing, m=nothing, ρ=nothing) =
    SystemDynamics(dname, sname, x0, m, μ, σ, ρ, idx)

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

    push!(parser.dynamics.systems, name => SystemDynamics(gensym(name), name, x0, system_counter(); μ=μ, σ=σ, m=m, ρ=ρ))

    return UMC_PARSER_OK
end
