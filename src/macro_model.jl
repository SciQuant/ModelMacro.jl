
struct Model
    parameters::Parameters
    dynamics::Dynamics
end

Model() = Model(Parameters(), Dynamics())

"""
    @model

Describing a problem in **UniversalMonteCarlo.jl** requieres many instantiations of
different objects in a correct order. This level of detail might become a barrier to new
users. The macro `@model` defines a Domain Specific Language for the library, which allows
scripting a problem in a way that resembles writing in a piece of paper.

Mas intro...

* SDEs that have correlated noises and/or share noises must be defined using `@system`.
  These SDEs can have [`SacalarNoise`](@ref), [`DiagonalNoise`](@ref) or
  [`NonDiagonalNoise`](@ref).

        dX⃗ = μ⃗ ⋅ dt + σ⃗ ⋅ dW

        @system (S, I, R) begin
            x₀ → @SVector ones(3)
            m → ScalarNoise
            μ → ... # returns a vector of size = (3, )
            σ → ... # returns a vector of size = (3, )
        end

        dX⃗ = μ⃗ ⋅ dt + σ⃗ ⋅ dW⃗

        @system (S, I, R) begin
            x₀ → @SVector ones(3)
            m → DiagonalNoise(3)
            μ → ... # returns a vector of size = (3, )
            σ → ... # returns a vector of size = (3, )
            ρ → ... # constant matrix of size = (3, 3)
        end

        dX⃗ = μ⃗ ⋅ dt + σ ⋅ dW⃗(t)

        @system (S, I, R) begin
            x₀ → @SVector ones(3)
            m → NonDiagonalNoise(4)
            μ → ... # returns a vector of size = (3, )
            σ → ... # returns a matrix of size = (3, 4)
            ρ → ... # constant matrix of size = (4, 4)
        end
"""
macro model(name, body)

    # check
    if !isa(name, Symbol)
        error("expected `@model` name as a `Symbol`, got '$(string(name))' instead.")
    end

    # init an empty parser
    parser = Model()

    # pre-parser initializations
    init_before_parser!(parser)

    # parse
    parse_macro_model!(parser, body)

    # post-parser initializations
    init_after_parser!(parser)

    ex = quote

        $(esc(withkw_assignment))

        # la realidad es que las funciones argumento van a un constructor de DynamicalSystem
        # y ahi dentro, una vez calculado IIP y DN, se instancia a DynamicalSystemDrift y a
        # DynamicalSystemDiffusion.
        f = DynamicalSystemDrift{IIP}($f_iip, $f_oop)
        g = DynamicalSystemDiffusion{IIP,DN}($g_iip_dn, $g_oop_dn, $g_iip_ndn, $g_oop_ndn)

    #     # en realidad me va a dar en el nombre del model un dynamicalsystem
    #     $(esc(name)) = begin
    #         $(convert(Expr, getfunction(parser, :μiip)))
    #         $(convert(Expr, getfunction(parser, :μoop)))
    #         $(convert(Expr, getfunction(parser, :σiip)))
    #         $(convert(Expr, getfunction(parser, :σoop)))
    #         p = $(esc(parser.parameters.external[].call_expr))
    #         ds = DynamicalSystem($(esc(getfuncname(parser, :μiip))), $(esc(getfuncname(parser, :σiip))), p)
    #         ds
    #         # luego mas adelante tendria que construir el model, que incluye las funciones
    #         # de fairvalues y expectations
    #     end
    end

    return ex
end

function parse_macro_model!(parser, model)

    # assume it is not cleaned
    model_blocks = rmlines(model)

    for mblock in model_blocks.args

        check_macrocall(mblock)

        # macro name
        mname = mblock.args[1]

        # parse macro block
        if mname == Symbol("@parameters")

            parse_params!(parser, mblock)

        elseif mname == Symbol("@time_mesh")

            parse_timemesh!(parser, mblock)

        elseif mname == Symbol("@system")

            parse_system!(parser, mblock)

        elseif mname == Symbol("@interest_rate")

            name = mblock.args[3]
            if !isa(name, Symbol)
                error("expected `@interest_rate` name as a `Symbol`, got '$(string(name))' instead.")
            end

            attrs = rmlines(mblock.args[4])

            if (model = parse_attribute(:InterestRateModel, attrs)) === UMC_PARSER_ERROR
                throw(ArgumentError("missing `InterestRateModel` field in `@interest_rate` '$(string(name))'."))
            end

            if model == :ShortRateModel

                parse_srm!(parser, mblock)

            elseif model == :LiborMarketModel

                parse_lmm!(parser, mblock)

            elseif model == :HeathJarrowMorton

                parse_hjm!(parser, mblock)

            else
                throw(ArgumentError("the provided InterestRateModel *must* be <: `InterestRateModel`."))
            end

        elseif mname == Symbol("@expectation")

            parse_expectation!(parser, mblock)

        elseif mname == Symbol("@fair_value")

            parse_fv!(parser, mblock)

        else
            throw(ArgumentError("invalid macro '$(string(mname))'."))
        end
    end

    # to be done
    # check_macro_model(parser)

    return UMC_PARSER_OK
end
