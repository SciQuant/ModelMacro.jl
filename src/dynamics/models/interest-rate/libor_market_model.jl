
struct LiborMarketModelParameters τ; σ; ρ; measure; imethod end

struct LiborMarketModelDynamics <: InterestRateModelDynamics
    securities::Symbol
    dynamics::Symbol
    params::LiborMarketModelParameters
    L::SystemDynamics
end

function parse_lmm!(parser, block)

    # fixed income securities name
    securities = block.args[3]

    block = rmlines(block.args[4])
    check_block(block)

    required_keys, optional_keys = (:L₀, :τ, :σ, :ρ, :measure), (:interpolation, )
    attrs = parse_attributes!(block, required_keys, optional_keys)

    L₀ = attrs[:L₀]
    τ = attrs[:τ]
    σ = attrs[:σ]
    ρ = attrs[:ρ]
    measure = attrs[:measure]
    imethod = get(attrs, :interpolation, :(DoNotInterpolate()))

    params = LiborMarketModelParameters(τ, σ, ρ, measure, imethod)

    dynamics = gensym(Symbol(:dynamics, securities))

    L = gensym(Symbol(:L_, securities))
    μL = Dict{Symbol,GeneralExpr}(
        :IIP => :(drift!($(L).dx, $x(t), parameters($dynamics), t)),
        :OOP => :(drift($L(t), parameters($dynamics), t))
    )
    σL = Dict{Symbol,GeneralExpr}(
        :IIP => :(diffusion!($(L).dx, $x(t), parameters($dynamics), t)),
        :OOP => :(diffusion($L(t), parameters($dynamics), t))
    )
    Lₚ = SystemDynamics(dynamics, L, system_counter(), L0; μ=μL, σ=σL)

    lmmₚ = LiborMarketModelDynamics(securities, dynamics, paramsₚ, Lₚ)
    push!(parser.dynamics.models, securities => lmmₚ)

    return UMC_PARSER_OK
end