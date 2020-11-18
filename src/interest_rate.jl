
# primero incluimos todos y luego definimos InterestRate (lo mismo podriamos hacer en dynamics.jl)
# include("short_rate.jl")

abstract type ShortRateParametersParser end

struct ShortRateModelParser{T}
    srm::Symbol
    params::ShortRateParametersParser
    x::Union{ProcessParser,ProcessesParser}
    B::ProcessParser
end

struct AffineParametersParser <: ShortRateParametersParser
    κ::GeneralExpr
    θ::GeneralExpr
    Σ::GeneralExpr
    α::GeneralExpr
    β::GeneralExpr
    ξ₀::GeneralExprOrNothing
    ξ₁::GeneralExprOrNothing
end

struct QuadraticParametersParser <: ShortRateParametersParser
    κ::GeneralExpr
    θ::GeneralExpr
    σ::GeneralExpr
    ξ₀::GeneralExpr
    ξ₁::GeneralExpr
    ξ₂::GeneralExpr
end

macro_params(::Val{:OneFactorAffine}) = (:InterestRateModel, :ShortRateModel, :r₀, :κ, :θ, :Σ, :α, :β), (:ξ₀, :ξ₁)
macro_params(::Val{:MultiFactorAffine}) = (:InterestRateModel, :ShortRateModel, :x₀, :κ, :θ, :Σ, :α, :β, :ξ₀, :ξ₁), ()
macro_params(::Val{:OneFactorQuadratic}) = (:InterestRateModel, :ShortRateModel, :x₀, :κ, :θ, :σ, :ξ₀, :ξ₁, :ξ₂), ()
macro_params(::Val{:MultiFactorQuadratic}) = (:InterestRateModel, :ShortRateModel, :x₀, :κ, :θ, :σ :ξ₀, :ξ₁, :ξ₂), ()

function parse_srm!(parser, block)

    # interest rate model name, e.g. EURIBOR
    irname = block.args[3]

    block = MacroTools.rmlines(block.args[4])

    # TODO: funciones en parser.jl que sean del tipo: isblock(block) y todas las que correspondan: macrocall, etc
    block.head == :block || error("expected a `:block`, got '$(string(block))' instead.")

    if (SRM = parse_attribute(:ShortRateModel, block)) === UMC_PARSER_ERROR
        throw(ArgumentError("missing ShortRateModel field in `@interest_rate` '$(string(name))'."))
    end

    if !(SRM in (:OneFactorAffine, :MultiFactorAffine, :OneFactorQuadratic, :MultiFactorQuadratic))
        throw(ArgumentError("the provided ShortRateModel *must* be <: `ShortRateModel`."))
    end

    # once it is safe, eval
    # SRM = @eval(@__MODULE__, $SRM)

    # parse attributes
    attrs = Dict{GeneralExpr,GeneralExpr}()
    required_keys, optional_keys = macro_params(Val(SRM))
    parse_attributes!(attrs, block, required_keys, optional_keys)

    iparameters = parser.parameters.internal

    if SRM == OneFactorAffine

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

        srm = add_assignment!(
            iparameters, irname, :(OneFactorAffine($x0, $κ, $θ, $Σ, $α, $β, $kwargs...)), true
        )

    elseif SRM == :MultiFactorAffine

        x0 = attrs[:x₀]
        N  = attrs[:N]
        κ  = attrs[:κ]
        θ  = attrs[:θ]
        Σ  = attrs[:Σ]
        α  = attrs[:α]
        β  = attrs[:β]
        ξ₀ = attrs[:ξ₀]
        ξ₁ = attrs[:ξ₁]

        # definimos un name para el short rate model en base al nombre del interest rate
        srm = gensym(Symbol(:srm, irname))

        x = gensym(Symbol(:x_, irname))
        dx = gensym(Symbol(:d, x))
        μx = Dict{Symbol,GeneralExpr}(
            :IIP => :(drift!($dx, $x(t), parameters($srm), t)),
            :OOP => :(drift($x(t), parameters($srm), t))
        )
        σx = Dict{Symbol,GeneralExpr}(
            :IIP => :(diffusion!($dx, $x(t), parameters($srm), t)),
            :OOP => :(diffusion($x(t), parameters($srm), t))
        )
        xₚ = ProcessesParser(x, x0, μ=μx, σ=σx, dx=dx)
        push!(parser.dynamics.Ps, x => xₚ)

        B = gensym(Symbol(:B_, irname))
        B0 = :(one(eltype(state($srm))))
        μB = :($(irname).r(t) * $B(t))
        Bₚ = ProcessParser(B, B0, μ=μB)
        push!(parser.dynamics.P, B => Bₚ)

        paramsₚ = AffineParametersParser(κ, θ, Σ, α, β, ξ₀, ξ₁)
        srmₚ = ShortRateModelParser{SRM}(srm, paramsₚ, xₚ, Bₚ) # hace srm = add_assignment!(iparameters, :mfa, :(MultiFactorAffine($x0, $κ, $θ, $Σ, $α, $β, $ξ₀, $ξ₁)), true)
        irₚ = InterestRateParser(irname, srmₚ)
        push!(parser.dynamics.IRs, irname => irₚ)

        # el interest rate hace
        # for body in map(fparser -> getproperty(fparser, :body), (μiip, σiip, μoop, σoop))
        #     add_assignment!(body, irname, :(InterestRate($srm, $x, $B)), false)
        # end

    elseif SRM == OneFactorQuadratic

        x0 = attrs[:x₀]
        κ  = attrs[:κ]
        θ  = attrs[:θ]
        σ  = attrs[:σ]
        ξ₀ = attrs[:ξ₀]
        ξ₁ = attrs[:ξ₁]
        ξ₂ = attrs[:ξ₂]

        srm = add_assignment!(
            iparameters, irname, :(OneFactorQuadratic($x0, $ϰ, $θ, $σ, $ξ₀, $ξ₁, $ξ₂)), true
        )

    elseif SRM == MultiFactorQuadratic

        x0 = attrs[:x₀]
        κ  = attrs[:κ]
        θ  = attrs[:θ]
        σ  = attrs[:σ]
        ξ₀ = attrs[:ξ₀]
        ξ₁ = attrs[:ξ₁]
        ξ₂ = attrs[:ξ₂]

        srm = add_assignment!(
            iparameters, irname, :(MultiFactorQuadratic($x0, $ϰ, $θ, $σ, $ξ₀, $ξ₁, $ξ₂)), true
        )
    end

    return UMC_PARSER_OK
end









function unpack_expectation_function_shortratemodel_objects!(fskel, parser)
    @unpack shortrates = parser
    @unpack header = fskel
    u = fskel.args[1]

    for shortrate in values(shortrates)
      @unpack name, srm = shortrate
      x = Symbol(u, name)
      B = Symbol(:B, name) # mmm el nombre va a ser gensym
      ir = add_assignment!(header, name, :(InterestRate($srm, $x, $B)), false)
    end

    return UMC_PARSER_OK
  end



  struct InterestRateParser
    ir::Symbol
    model::Union{ShortRateModelParser} # LiborMarketModelParser
end