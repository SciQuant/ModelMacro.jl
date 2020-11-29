
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
            m → ScalarNoise
            x₀ → @SVector ones(3)
            μ → ... # returns a vector of size = (3, )
            σ → ... # returns a vector of size = (3, )
        end

        dX⃗ = μ⃗ ⋅ dt + σ⃗ ⋅ dW⃗

        @system (S, I, R) begin
            m → DiagonalNoise
            x₀ → @SVector ones(3)
            μ → ... # returns a vector of size = (3, )
            σ → ... # returns a vector of size = (3, )
            ρ → ... # constant matrix of size = (3, 3)
        end

        dX⃗ = μ⃗ ⋅ dt + σ ⋅ dW⃗(t)

        @system (S, I, R) begin
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
    parser = Model()

    # initialize pre-parser objects
    # init_before_parser!(parser)

    # parse
    parse_macro_model!(parser, body)

    # initialize post-parser objects
    # init_after_parser!(parser)

    # this function might be moved outside as generate_model(model_parser)
    # model = build_model(parser)

    # estas funciones van dentro de init_after_parser y en particular, son
    # generate_withkw_macro (algo asi, aunque ese nombre ya existe)
    dynamics = generate_dynamics(parser.dynamics)
    D = generate_dimensions(dynamics) # de aca hay que guardar el lhs de `D`, el name
    M = generate_noise_dimensions(dynamics) # idem above
    params = vcat(parser.parameters.assignments, dynamics, D, M)
    withkw = generate_withkw_macro(params)
    call = Expr(:(=), parser.parameters.name[], withkw)

    du = gensym(:du)
    u = gensym(:u)
    p = gensym(:p)
    t = :t

    # ahora creo las funciones y las pueblo
    # empecemos por la mas facil, μiip
    f = Function{true}(gensym(:f), args=Expr(:tuple, du, u, p, t))
    unpack = generate_unpack_macro(lefthandside.(params), p)
    securities = generate_securities(parser.dynamics, du, u, lefthandside(D))
    drifts = generate_drifts(parser.dynamics)
    push!(f.header.args, unpack)
    push!(f.header.args, convert.(Expr, securities)...)
    push!(f.body.args, drifts...)
    fexpr = convert(Expr, f)


    ex = quote

        $(esc(call))

        $fexpr

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

    # return parser, dynamics, withkw
end

function generate_unpack_macro(paramsnames, p)
    params = Expr(:tuple)
    push!(params.args, paramsnames...)
    macro_expr = Expr(:macrocall, Symbol("@unpack"), :nothing, Expr(:(=), params, p))
    return macro_expr
end

function generate_securities(dynamics::Dynamics, du, u, D)
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    ss = vcat(security_assignment.(models, Ref(du), Ref(u), Ref(D))..., security_assignment.(systems, Ref(du), Ref(u), Ref(D))...)
    return ss
end

# estamos pensando en algo que es para f y ademas IIP, luego implemetar dispatch
function security_assignment(model::ShortRateModelDynamics, du, u, D)
    @unpack securities, dynamics, x, B = model
    ax = security_assignment(x, du, u, D)
    aB = security_assignment(B, du, u, D)

    lhs = securities
    rhs = :(FixedIncomeSecurities($dynamics, $(ax.lhs), $(aB.lhs)))
    aFI = AssignmentExpr(lhs, rhs)

    return [ax, aB, aFI]
end

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

function generate_drifts(dynamics::Dynamics)
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    ds = vcat(drift_assignment.(models)..., drift_assignment.(systems)...)
    return ds
end

function drift_assignment(model::ShortRateModelDynamics)
    @unpack x, B = model
    ax = drift_assignment(x)
    aB = drift_assignment(B)
    return [ax, aB]
end

function drift_assignment(system::SystemDynamics)
    μ = system.μ

    if isnothing(μ)
        return nothing
    end

    return μ isa Dict ? μ[:IIP] : μ
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
