
abstract type ShortRateParameters end

struct AffineParameters <: ShortRateParameters κ; θ; Σ; α; β; ξ₀; ξ₁ end
struct QuadraticParameters <: ShortRateParameters κ; θ; σ; ξ₀; ξ₁; ξ₂ end

struct ShortRateModelDynamics{T} <: InterestRateModelDynamics
    securities::Symbol
    dynamics::Symbol
    params::ShortRateParameters
    x::SystemDynamics
    B::SystemDynamics
end

const ASRMs = (:OneFactorAffine, :MultiFactorAffine)
const QSRMs = (:OneFactorQuadratic, :MultiFactorQuadratic)
const SRMs = (ASRMs..., QSRMs...)

macro_keys(::Val{:OneFactorAffine}) = (:InterestRateModel, :ShortRateModel, :r₀, :κ, :θ, :Σ, :α, :β), (:ξ₀, :ξ₁)
macro_keys(::Val{:MultiFactorAffine}) = (:InterestRateModel, :ShortRateModel, :x₀, :κ, :θ, :Σ, :α, :β, :ξ₀, :ξ₁), ()
macro_keys(::Val{:OneFactorQuadratic}) = (:InterestRateModel, :ShortRateModel, :x₀, :κ, :θ, :σ, :ξ₀, :ξ₁, :ξ₂), ()
macro_keys(::Val{:MultiFactorQuadratic}) = (:InterestRateModel, :ShortRateModel, :x₀, :κ, :θ, :σ :ξ₀, :ξ₁, :ξ₂), ()

function parse_srm!(parser, block)

    # fixed income securities name
    securities = block.args[3]

    block = rmlines(block.args[4])
    check_block(block)

    if (srm = parse_attribute(:ShortRateModel, block)) === UMC_PARSER_ERROR
        throw(ArgumentError("missing `ShortRateModel` field in `@interest_rate` '$(string(securities))'."))
    end

    if !(srm in SRMs)
        throw(ArgumentError("the provided ShortRateModel *must* be <: `ShortRateModel`."))
    end

    # once it is safe, eval
    # srm = @eval(@__MODULE__, $srm)

    # parse attributes
    required_keys, optional_keys = macro_keys(Val(srm))
    attrs = parse_attributes!(block, required_keys, optional_keys)

    if srm in ASRMs

        x0 = isequal(srm, :OneFactorAffine) ? attrs[:r₀] : attrs[:x₀]
        κ  = attrs[:κ]
        θ  = attrs[:θ]
        Σ  = attrs[:Σ]
        α  = attrs[:α]
        β  = attrs[:β]
        ξ₀ = get(attrs, :ξ₀, nothing)
        ξ₁ = get(attrs, :ξ₁, nothing)

        paramsₚ = AffineParameters(κ, θ, Σ, α, β, ξ₀, ξ₁)

    elseif srm in QSRMs

        x0 = attrs[:x₀]
        κ  = attrs[:κ]
        θ  = attrs[:θ]
        σ  = attrs[:σ]
        ξ₀ = attrs[:ξ₀]
        ξ₁ = attrs[:ξ₁]
        ξ₂ = attrs[:ξ₂]

        paramsₚ = QuadraticParameters(κ, θ, σ, ξ₀, ξ₁, ξ₂)
    end

    dynamics = gensym(Symbol(:dynamics, securities))

    x = gensym(Symbol(:x_, securities))
    μx = Dict{Val,GeneralExpr}(
        Val(:IIP) => :(drift!($(x).dx, $x(t), parameters($dynamics), t)),
        Val(:OOP) => :(drift($x(t), parameters($dynamics), t))
    )
    σx = Dict{Val,GeneralExpr}(
        Val(:IIP) => :(diffusion!($(x).dx, $x(t), parameters($dynamics), t)),
        Val(:OOP) => :(diffusion($x(t), parameters($dynamics), t))
    )
    xₚ = SystemDynamics(dynamics, x, system_counter(), x0; μ=μx, σ=σx)

    B = gensym(Symbol(:B_, securities))
    B0 = :(one(eltype(state($dynamics))))
    μB = Dict{Val,GeneralExpr}(
        Val(:IIP) => :($(B).dx[] = $(securities).r(t) * $B(t)),
        Val(:OOP) => :($(securities).r(t) * $B(t))
    )
    Bₚ = SystemDynamics(gensym(Symbol(:dynamics, B)), B, system_counter(), B0; μ=μB)

    srmₚ = ShortRateModelDynamics{srm}(securities, dynamics, paramsₚ, xₚ, Bₚ)
    push!(parser.dynamics.models, securities => srmₚ)

    return UMC_PARSER_OK
end