struct ModelParser
    parameters::ParametersParser
    dynamics::DynamicsParser
end

ModelParser() = ModelParser(ParametersParser(), DynamicsParser())

"""
    @model

Describing a problem requieres many instantiations of different objects in a correct order.
This level of detail might become a barrier to new users. The macro `@model` defines a
Domain Specific Language for the library, which allows scripting a problem in a way that
resembles writing in a piece of paper.

Mas intro...

* `@process`

* SDEs that have correlated noises and/or share noises must be defined using `@processes`.
  These SDEs can have [`SacalarNoise`](@ref), [`DiagonalNoise`](@ref) or
  [`NonDiagonalNoise`](@ref).

        dX⃗ = μ⃗ ⋅ dt + σ⃗ ⋅ dW

        @processes (S, I, R) begin
            m → ScalarNoise
            x₀ → @SVector ones(3)
            μ → ... # returns a vector of size = (3, )
            σ → ... # returns a vector of size = (3, )
        end

        dX⃗ = μ⃗ ⋅ dt + σ⃗ ⋅ dW⃗

        @processes (S, I, R) begin
            m → DiagonalNoise
            x₀ → @SVector ones(3)
            μ → ... # returns a vector of size = (3, )
            σ → ... # returns a vector of size = (3, )
            ρ → ... # constant matrix of size = (3, 3)
        end

        dX⃗ = μ⃗ ⋅ dt + σ ⋅ dW⃗(t)

        @processes (S, I, R) begin
            m → NonDiagonalNoise(4)
            x₀ → @SVector ones(3)
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

    # init an empty parser object
    parser = ModelParser()

    # initialize pre-parser objects
    # init_before_parser!(parser)

    # parse
    parse_macro_model!(parser, body)

    # initialize post-parser objects
    # init_after_parser!(parser)

    # this function might be moved outside as generate_model(model_parser)
    # model = build_model(parser)

    # ex = quote
    #     # TODO: ahora esto es una llamada a una funcion que construye esta expresion
    #     # Parameters.jl @with_kw macro
    #     $(esc(parser.parameters.external[].macro_call))

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
    # end

    # return ex

    return parser
end

function parse_macro_model!(parser, model)

    # assume it is not cleaned
    model_blocks = rmlines(model) # Base.rmlines! does the same trick, right?

    for mblock in model_blocks.args

        # check
        ismacrocall(mblock)

        # macro name
        mname = mblock.args[1]

        # parse macro block
        if mname == Symbol("@parameters")

            parse_params!(parser, mblock)

        elseif mname == Symbol("@time_mesh")

            parse_timemesh!(parser, mblock)

        elseif mname == Symbol("@process")

            parse_process!(parser, mblock)

        elseif mname == Symbol("@processes")

            parse_processes!(parser, mblock)

        elseif mname == Symbol("@interest_rate")

            name = mblock.args[3]
            if !isa(name, Symbol)
                error("expected `@interest_rate` name as a `Symbol`, got '$(string(name))' instead.")
            end

            attrs = MacroTools.rmlines(mblock.args[4])

            if (model = parse_attribute(:InterestRateModel, attrs)) === UMC_PARSER_ERROR
                throw(ArgumentError("missing InterestRateModel field in `@interest_rate` '$(string(name))'."))
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

        elseif mname == Symbol("@correlations")

            parse_correlations!(parser, mblock)

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