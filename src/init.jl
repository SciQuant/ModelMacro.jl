
function init_before_parser!(parser) end

function init_after_parser!(parser)

    # dynamics assignments
    dynamics = generate_dynamics(parser.dynamics)

    # D and M parameters
    D = generate_dimensions(dynamics)
    M = generate_noise_dimensions(dynamics)

    # cat all parameters
    params = vcat(parser.parameters.assignments, dynamics, D, M)

    # @with_kw macro
    withkw = generate_withkw_macro(params)
    withkw_assignment = Expr(:(=), parser.parameters.name[], withkw)

    # arguments
    du, u, p, t = gensym(:du), gensym(:u), gensym(:p), :t

    # parameters unpaking
    unpack = generate_unpack_macro(lefthandside.(params), p)

    # f IIP
    f = Function{true}(gensym(:f), args=Expr(:tuple, du, u, p, t))
    securities = generate_securities(parser.dynamics, du, u, lefthandside(D))
    drifts = generate_drifts(parser.dynamics, Val(:IIP))
    push!(f.header.args, unpack)
    push!(f.header.args, convert.(Expr, securities)...)
    push!(f.body.args, convert.(Expr, drifts)...)
    f_iip = convert(Expr, f)

    # f OOP
    f = Function{false}(f.name, args=Expr(:tuple, u, p, t))
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
    securities = generate_securities(parser.dynamics, du, u, lefthandside(D))
    diffusions = generate_diffusions(parser.dynamics, Val(:IIP)) # Val(:DN)
    push!(g.header.args, unpack)
    push!(g.header.args, convert.(Expr, securities)...)
    push!(g.body.args, convert.(Expr, diffusions)...)
    g_iip_dn = convert(Expr, g)

    # g OOP + DN
    g = Function{false}(g.name, args=Expr(:tuple, u, p, t))
    unpack = unpack
    securities = generate_securities(parser.dynamics, u, lefthandside(D))
    diffusions = generate_diffusions(parser.dynamics, Val(:OOP)) # Val(:DN)
    output = generate_output(diffusions, Val(:DN))
    push!(g.header.args, unpack)
    push!(g.header.args, convert.(Expr, securities)...)
    push!(g.body.args, convert.(Expr, diffusions)...)
    push!(g.output.args, output)
    g_oop_dn = convert(Expr, g)

    # g IIP + NonDN
    g = Function{true}(g.name, args=Expr(:tuple, du, u, p, t))
    unpack = unpack
    securities = generate_securities(parser.dynamics, du, u, lefthandside(D), lefthandside(M))
    diffusions = generate_diffusions(parser.dynamics, Val(:IIP)) # Val(:NonDN)
    push!(g.header.args, unpack)
    push!(g.header.args, convert.(Expr, securities)...)
    push!(g.body.args, convert.(Expr, diffusions)...)
    g_iip_ndn = convert(Expr, g)

    # g OOP + NonDN
    g = Function{false}(g.name, args=Expr(:tuple, u, p, t))
    securities = generate_securities(parser.dynamics, u, lefthandside(D)) # no necesita M
    diffusions = generate_diffusions(parser.dynamics, Val(:OOP)) # Val(:NonDN)
    output = generate_output(diffusions, Val(:NonDN))
    push!(g.header.args, unpack)
    push!(g.header.args, convert.(Expr, securities)...)
    push!(g.body.args, convert.(Expr, diffusions)...)
    push!(g.output.args, output)
    g_oop_ndn = convert(Expr, g)


end