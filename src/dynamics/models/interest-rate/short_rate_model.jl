
abstract type ShortRateParameters end

struct AffineParameters <: ShortRateParameters
    κ::GeneralExpr
    θ::GeneralExpr
    Σ::GeneralExpr
    α::GeneralExpr
    β::GeneralExpr
    ξ₀::GeneralExprOrNothing
    ξ₁::GeneralExprOrNothing
end

struct QuadraticParameters <: ShortRateParameters
    κ::GeneralExpr
    θ::GeneralExpr
    σ::GeneralExpr
    ξ₀::GeneralExpr
    ξ₁::GeneralExpr
    ξ₂::GeneralExpr
end

struct ShortRateModelDynamics{T} <: InterestRateModelDynamics
    sname::Symbol # security name
    dname::Symbol # dynamics name
    params::ShortRateParameters
    x::SystemDynamics
    B::SystemDynamics
end

macro_params(::Val{:OneFactorAffine}) = (:InterestRateModel, :ShortRateModel, :r₀, :κ, :θ, :Σ, :α, :β), (:ξ₀, :ξ₁)
macro_params(::Val{:MultiFactorAffine}) = (:InterestRateModel, :ShortRateModel, :x₀, :κ, :θ, :Σ, :α, :β, :ξ₀, :ξ₁), ()
macro_params(::Val{:OneFactorQuadratic}) = (:InterestRateModel, :ShortRateModel, :x₀, :κ, :θ, :σ, :ξ₀, :ξ₁, :ξ₂), ()
macro_params(::Val{:MultiFactorQuadratic}) = (:InterestRateModel, :ShortRateModel, :x₀, :κ, :θ, :σ :ξ₀, :ξ₁, :ξ₂), ()

function parse_srm!(parser, block)

    # interest rate model name
    irm = block.args[3]

    block = rmlines(block.args[4])
    check_block(block)

    if (SRM = parse_attribute(:ShortRateModel, block)) === UMC_PARSER_ERROR
        throw(ArgumentError("missing `ShortRateModel` field in `@interest_rate` '$(string(irm))'."))
    end

    if !(SRM in (:OneFactorAffine, :MultiFactorAffine, :OneFactorQuadratic, :MultiFactorQuadratic))
        throw(ArgumentError("the provided ShortRateModel *must* be <: `ShortRateModel`."))
    end

    # once it is safe, eval
    # SRM = @eval(@__MODULE__, $SRM)

    # parse attributes
    required_keys, optional_keys = macro_params(Val(SRM))
    attrs = parse_attributes!(block, required_keys, optional_keys)

    if SRM == :OneFactorAffine

        x0 = attrs[:r₀] # idealmente deberiamos usar r0
        κ  = attrs[:κ]
        θ  = attrs[:θ]
        Σ  = attrs[:Σ]
        α  = attrs[:α]
        β  = attrs[:β]
        ξ₀ = get(attrs, :ξ₀, nothing)
        ξ₁ = get(attrs, :ξ₁, nothing)

        # IDEA: crear funcion optional_kwargs using optional_keys?
        kwargs = Expr(:tuple)
        isnothing(ξ₀) ? nothing : push!(kwargs.args, :(ξ₀ = $ξ₀))
        isnothing(ξ₁) ? nothing : push!(kwargs.args, :(ξ₁ = $ξ₁))
        dname = gensym(Symbol(:dynamics, irm))

        x = gensym(Symbol(:x_, irm))
        μx = Dict{Symbol,GeneralExpr}(
            :IIP => :(drift!($(x).dx, $x(t), parameters($dname), t)),
            :OOP => :(drift($x(t), parameters($dname), t))
        )
        σx = Dict{Symbol,GeneralExpr}(
            :IIP => :(diffusion!($(x).dx, $x(t), parameters($dname), t)),
            :OOP => :(diffusion($x(t), parameters($dname), t))
        )
        parser.dynamics.N[] = parser.dynamics.N[] + 1
        xₚ = SystemDynamics(dname, x, x0, parser.dynamics.N[]; μ=μx, σ=σx)
        # push!(parser.dynamics.systems, x => xₚ)

        B = gensym(Symbol(:B_, irm))
        B0 = :(one(eltype(state($dname))))
        μB = :($(B).dx[] = $(irm).r(t) * $B(t))
        parser.dynamics.N[] = parser.dynamics.N[] + 1
        Bₚ = SystemDynamics(gensym(Symbol(:dynamics, B)), B, B0, parser.dynamics.N[]; μ=μB)
        # push!(parser.dynamics.systems, B => Bₚ)

        paramsₚ = AffineParameters(κ, θ, Σ, α, β, ξ₀, ξ₁)
        srmₚ = ShortRateModelDynamics{SRM}(irm, dname, paramsₚ, xₚ, Bₚ)
        push!(parser.dynamics.models, irm => srmₚ)
        # el ShortRateModelDynamics <: IntererestRateModelDynamics hace estas 2 cosas:
        # for body in map(fparser -> getproperty(fparser, :body), (μiip, σiip, μoop, σoop))
        #     add_assignment!(body, irm, :(InterestRate($srm, $x, $B)), false)
        # end

    elseif SRM == :MultiFactorAffine

        x0 = attrs[:x₀]
        κ  = attrs[:κ]
        θ  = attrs[:θ]
        Σ  = attrs[:Σ]
        α  = attrs[:α]
        β  = attrs[:β]
        ξ₀ = attrs[:ξ₀]
        ξ₁ = attrs[:ξ₁]

        dname = gensym(Symbol(:dynamics, irm))

        x = gensym(Symbol(:x_, irm))
        μx = Dict{Symbol,GeneralExpr}(
            :IIP => :(drift!($(x).dx, $x(t), parameters($dname), t)),
            :OOP => :(drift($x(t), parameters($dname), t))
        )
        σx = Dict{Symbol,GeneralExpr}(
            :IIP => :(diffusion!($(x).dx, $x(t), parameters($dname), t)),
            :OOP => :(diffusion($x(t), parameters($dname), t))
        )
        parser.dynamics.N[] = parser.dynamics.N[] + 1
        xₚ = SystemDynamics(dname, x, x0, parser.dynamics.N[]; μ=μx, σ=σx)
        # push!(parser.dynamics.systems, x => xₚ)

        B = gensym(Symbol(:B_, irm))
        B0 = :(one(eltype(state($dname))))
        μB = :($(B).dx[] = $(irm).r(t) * $B(t))
        parser.dynamics.N[] = parser.dynamics.N[] + 1
        Bₚ = SystemDynamics(gensym(Symbol(:dynamics, B)), B, B0, parser.dynamics.N[]; μ=μB)
        # push!(parser.dynamics.systems, B => Bₚ)

        paramsₚ = AffineParameters(κ, θ, Σ, α, β, ξ₀, ξ₁)
        srmₚ = ShortRateModelDynamics{SRM}(irm, dname, paramsₚ, xₚ, Bₚ)
        push!(parser.dynamics.models, irm => srmₚ)
        # el ShortRateModelDynamics <: IntererestRateModelDynamics hace estas 2 cosas:
        # srm = add_assignment!(iparameters, srm, :(MultiFactorAffine($x0, $κ, $θ, $Σ, $α, $β, $ξ₀, $ξ₁)), true)
        # for body in map(fparser -> getproperty(fparser, :body), (μiip, σiip, μoop, σoop))
        #     add_assignment!(body, irm, :(InterestRate($srm, $x, $B)), false)
        # end

    elseif SRM == :OneFactorQuadratic

        x0 = attrs[:x₀]
        κ  = attrs[:κ]
        θ  = attrs[:θ]
        σ  = attrs[:σ]
        ξ₀ = attrs[:ξ₀]
        ξ₁ = attrs[:ξ₁]
        ξ₂ = attrs[:ξ₂]

        srm = add_assignment!(
            iparameters, irm, :(OneFactorQuadratic($x0, $ϰ, $θ, $σ, $ξ₀, $ξ₁, $ξ₂)), true
        )

    elseif SRM == :MultiFactorQuadratic

        x0 = attrs[:x₀]
        κ  = attrs[:κ]
        θ  = attrs[:θ]
        σ  = attrs[:σ]
        ξ₀ = attrs[:ξ₀]
        ξ₁ = attrs[:ξ₁]
        ξ₂ = attrs[:ξ₂]

        srm = add_assignment!(
            iparameters, irm, :(MultiFactorQuadratic($x0, $ϰ, $θ, $σ, $ξ₀, $ξ₁, $ξ₂)), true
        )
    end

    return UMC_PARSER_OK
end