
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

    # f IIP
    f = Function{true}(gensym(:f), args=Expr(:tuple, du, u, p, t))
    unpack = generate_unpack_macro(lefthandside.(params), p)
    securities = generate_securities(parser.dynamics, du, u, lefthandside(D))
    drifts = generate_drifts(parser.dynamics, Val(:IIP))
    push!(f.header.args, unpack)
    push!(f.header.args, convert.(Expr, securities)...)
    push!(f.body.args, convert.(Expr, drifts)...)
    f_iip = convert(Expr, f)

    # f OOP
    f = Function{false}(f.name, args=Expr(:tuple, u, p, t))
    unpack = unpack
    securities = generate_securities(parser.dynamics, u, lefthandside(D))
    drifts = generate_drifts(parser.dynamics, Val(:OOP))
    output = generate_output(drifts)
    push!(f.header.args, unpack)
    push!(f.header.args, convert.(Expr, securities)...)
    push!(f.body.args, convert.(Expr, drifts)...)
    push!(f.output.args, output)
    f_oop = convert(Expr, f)

    # g IIP + DN
    g = Function{true}(gensym(:g), args=Expr(:tuple, du, u, p, t))
    unpack = unpack
    securities = generate_securities(parser.dynamics, du, u, lefthandside(D))
    diffusions = generate_diffusions(parser.dynamics, Val(:IIP)) # Val(:DN)
    push!(g.header.args, unpack)
    push!(g.header.args, convert.(Expr, securities)...)
    push!(g.body.args, convert.(Expr, diffusions)...)
    g_iip_dn = convert(Expr, g)

    # g OOP + DN
    g = Function{false}(gensym(:g), args=Expr(:tuple, u, p, t))
    unpack = unpack
    securities = generate_securities(parser.dynamics, u, lefthandside(D))
    diffusions = generate_diffusions(parser.dynamics, Val(:OOP)) # Val(:DN)
    output = generate_output(diffusions)
    push!(g.header.args, unpack)
    push!(g.header.args, convert.(Expr, securities)...)
    push!(g.body.args, convert.(Expr, diffusions)...)
    push!(g.output.args, output)
    g_oop_dn = convert(Expr, g)

    # g IIP + NDN
    g = Function{true}(gensym(:g), args=Expr(:tuple, du, u, p, t))
    unpack = unpack
    securities = generate_securities(parser.dynamics, du, u, lefthandside(D), lefthandside(M))
    diffusions = generate_diffusions(parser.dynamics, Val(:IIP)) # Val(:NDN)
    push!(g.header.args, unpack)
    push!(g.header.args, convert.(Expr, securities)...)
    push!(g.body.args, convert.(Expr, diffusions)...)
    g_iip_ndn = convert(Expr, g)

    # g OOP + NDN
    g = Function{false}(gensym(:g), args=Expr(:tuple, u, p, t))
    unpack = unpack
    securities = generate_securities(parser.dynamics, u, lefthandside(D)) # no necesita M
    diffusions = generate_diffusions(parser.dynamics, Val(:OOP)) # Val(:NDN)
    output = generate_output(diffusions) # esto no es correcto, necesitamos construir una block static matrix, see issue #856 in StaticArrays
    push!(g.header.args, unpack)
    push!(g.header.args, convert.(Expr, securities)...)
    push!(g.body.args, convert.(Expr, diffusions)...)
    push!(g.output.args, output) # see above
    g_oop_ndn = convert(Expr, g)

    # dsd = Expr(:curly, :DynamicalSystemDrift, :IIP, :DN)
    # fexpr = quote
    #     $(esc(dsd))($f_iip, $f_oop)
    # end
    # fexpr = Expr(:call, Expr(:curly, :DynamicalSystemDrift, :IIP, :DN), f_iip, f_oop)

    ex = quote

        $(esc(call))

        # la realidad es que las funciones argumento van a un constructor de DynamicalSystem
        # y ahi dentro, una vez calculado IIP y DN, se instancia a DynamicalSystemDrift y a
        # DynamicalSystemDiffusion.
        f = DynamicalSystemDrift{IIP}($f_iip, $f_oop)\
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

    # return parser, dynamics, withkw
end

function generate_unpack_macro(paramsnames, p)
    params = Expr(:tuple)
    push!(params.args, paramsnames...)
    macro_expr = Expr(:macrocall, Symbol("@unpack"), :nothing, Expr(:(=), params, p))
    return macro_expr
end

# f IIP - g IIP + DN
function generate_securities(dynamics::Dynamics, du, u, D)
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    ss = vcat(security_assignment.(models, du, u, D)..., security_assignment.(systems, du, u, D)...)
    return ss
end

# f OOP - g OOP + DN - (creo que tambien para g OOP + NDN)
function generate_securities(dynamics::Dynamics, u, D)
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    ss = vcat(security_assignment.(models, u, D)..., security_assignment.(systems, u, D)...)
    return ss
end

# g IIP + NDN
function generate_securities(dynamics::Dynamics, du, u, D, M)
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    ss = vcat(security_assignment.(models, du, u, D, M)..., security_assignment.(systems, du, u, D, M)...)
    return ss
end

# f IIP - g IIP + DN
function security_assignment(model::ShortRateModelDynamics, du, u, D)
    @unpack securities, dynamics, x, B = model
    ax = security_assignment(x, du, u, D)
    aB = security_assignment(B, du, u, D)

    lhs = securities
    rhs = :(FixedIncomeSecurities($dynamics, $(ax.lhs), $(aB.lhs)))
    aFI = AssignmentExpr(lhs, rhs)

    return [ax, aB, aFI]
end

# f OOP - g OOP + DN
function security_assignment(model::ShortRateModelDynamics, u, D)
    @unpack securities, dynamics, x, B = model
    ax = security_assignment(x, u, D)
    aB = security_assignment(B, u, D)

    lhs = securities
    rhs = :(FixedIncomeSecurities($dynamics, $(ax.lhs), $(aB.lhs)))
    aFI = AssignmentExpr(lhs, rhs)

    return [ax, aB, aFI]
end

# g IIP + NDN
function security_assignment(model::ShortRateModelDynamics, du, u, D, M)
    @unpack securities, dynamics, x, B = model
    ax = security_assignment(x, du, u, D, M)
    aB = security_assignment(B, du, u, D, M)

    lhs = securities
    rhs = :(FixedIncomeSecurities($dynamics, $(ax.lhs), $(aB.lhs)))
    aFI = AssignmentExpr(lhs, rhs)

    return [ax, aB, aFI]
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

# f OOP - g OOP + DN
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

# g IIP + NDN
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

function generate_drifts(dynamics::Dynamics, case::Union{Val{:IIP},Val{:OOP}})
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    ds = vcat(drift_assignment.(models, case)..., drift_assignment.(systems, case)...)
    return ds
end

function drift_assignment(model::ShortRateModelDynamics, case::Union{Val{:IIP},Val{:OOP}})
    @unpack x, B = model
    ax = drift_assignment(x, case)
    aB = drift_assignment(B, case)
    return [ax, aB]
end

function drift_assignment(system::SystemDynamics, case::Union{Val{:IIP},Val{:OOP}})
    @unpack μ = system
    return μ isa Dict ? AssignmentExpr(gensym(), μ[case]) : AssignmentExpr(gensym(), μ)
end

# function generate_diffusions(dynamics::Dynamics, case::Union{Val{:IIP},Val{:OOP}}, noise::Union{Val{:DN},Val{:NDN}})
function generate_diffusions(dynamics::Dynamics, case::Union{Val{:IIP},Val{:OOP}})
    models = values(dynamics.models)
    systems = values(dynamics.systems)
    # ds = vcat(diffusion_assignment.(models, case, noise)..., diffusion_assignment.(systems, case, noise)...)
    ds = vcat(diffusion_assignment.(models, case)..., diffusion_assignment.(systems, case)...)
    return ds
end

function diffusion_assignment(model::ShortRateModelDynamics, case::Union{Val{:IIP},Val{:OOP}})
    return diffusion_assignment(model.x, case)
end

function diffusion_assignment(system::SystemDynamics, case::Union{Val{:IIP},Val{:OOP}})
    @unpack σ = system
    return σ isa Dict ? AssignmentExpr(gensym(), σ[case]) : AssignmentExpr(gensym(), σ)
end

# OOP + DN
function generate_output(drifts::Vector{AssignmentExpr})
    return Expr(:call, :vcat, Expr.(:call, :SVector, lefthandside.(drifts))...) # no need to call SVector() in StaticArrays.jl v1.0
end

# OOP + NDD: Aun no sabemos como concatenar varias SMatrix y formar una SMatrix Block Diagonal
# function generate_output(drifts::Vector{AssignmentExpr})
#     return Expr(:call, :vcat, Expr.(:call, :SVector, lefthandside.(drifts))...)
# end

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
