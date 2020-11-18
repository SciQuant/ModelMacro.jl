struct ProcessesParser
    x::Symbol # Tuple as well? or as another parameter?
    dx::Symbol
    x0::GeneralExpr
    m::GeneralExprOrNothing
    μ::Union{GeneralExprOrNothing,Dict{Symbol,GeneralExpr}}
    σ::Union{GeneralExprOrNothing,Dict{Symbol,GeneralExpr}}
    ρ::GeneralExprOrNothing
end

ProcessesParser(x, x0; μ=nothing, σ=nothing, m=nothing, ρ=nothing, dx=gensym(x)) =
    ProcessesParser(x, dx, x0, m, μ, σ, ρ)


function parse_processes!(parser, block)

    # could be a tuple?
    name = block.args[3]

    if !isa(name, Symbol)
        error("expected `@processes` name as a `Symbol`, got '$(string(name))' instead.")
    end

    required_attrs_keys = (:x₀,)
    optional_attrs_keys = (:m, :μ, :σ, :ρ)

    # create a dictionary to store attributes and its values
    attrs = Dict{GeneralExpr,GeneralExpr}()

    # parse attributes block
    parse_attributes!(attrs, block.args[4], required_attrs_keys, optional_attrs_keys)

    # useful handlers
    x0 = attrs[:x₀]
    m = get(attrs, :m, nothing)
    μ = get(attrs, :μ, nothing)
    σ = get(attrs, :σ, nothing)
    ρ = get(attrs, :ρ, nothing)

    push!(parser.dynamics.Ps, name => ProcessesParser(name, x0, μ=μ, σ=σ, m=m, ρ=ρ))

    return UMC_PARSER_OK
end






function define_processes_dynamics(parser, name, x0, m=nothing, ρ=nothing)

    pds = parser.PDs
    iparameters = parser.parameters.internal

    kwargs = Expr(:tuple)
    isnothing(m) ? nothing : push!(kwargs.args, :(m = $m))
    isnothing(ρ) ? nothing : push!(kwargs.args, :(ρ = $ρ))

    iname = add_assignment!(iparameters, name, :(ProcessesDynamics($x0; $kwargs...)), true)

    if name in keys(pds)
        error("processes dynamics '$(string(name))' already exists.")
    end

    return UMC_PARSER_OK
end

# creates a processes named `x`
function define_processes(parser, x, dx, expr_μiip, expr_σiip, expr_μoop=expr_μiip, expr_σoop=expr_σiip)

    name = x

    # inspect if the ProcessesDynamics exists
    pds = get(parser.PDs, name, nothing)

    # if it doesn't exists (e.g. it can be a LiborMarketModel, OneFactorAffine, etc), use
    # the provided name.
    iname = isnothing(pds) ? name : pds.name

    # IDEA: En lugar de usar algo que sea Dimension{D} podriamos usar Range{R} o algo asi?
    push!(parser.D_expr.args, :(Dimension{dimension($iname)}()))

    # OJO: `range` puede ser que sea para calcular una matrix y no solo vectores! esto pasa
    # en la difusion en casos non diagonal. Ahi  tenemos que usar Ms. Es decir, todo lo que
    # viene a continuacion es para diagonal noise, pero falta tener en cuenta las σiip y
    # σoop con non-diagonal noise
    idx = length(parser.D_expr.args)
    range = isone(idx) ? :(1:dimension(Ns[1])) : :(dimension(Ns[$idx - 1]) + 1:dimension(Ns[$idx]))

    μiip = getfunction(parser, :μiip)
    σiip = getfunction(parser, :σiip)
    μoop = getfunction(parser, :μoop)
    σoop = getfunction(parser, :σoop)

    du = getvarname(parser, :du)
    u  = getvarname(parser, :u)

    for header in map(fparser -> getproperty(fparser, :header), (μiip, σiip, μoop, σoop))
        add_assignment!(header, name, :(Processes($u, t, $range)), false)
    end

    for header in map(fparser -> getproperty(fparser, :header), (μiip, σiip))
        add_assignment!(header, dx, :(@view $du[$range]), false)
    end

    !isnothing(expr_μiip) ? push!(μiip.body, expr_μiip) : nothing
    !isnothing(expr_σiip) ? push!(σiip.body, expr_σiip) : nothing
    !isnothing(expr_μoop) ? add_assignment!(μoop.body, dx, expr_μoop, false) : nothing
    !isnothing(expr_σoop) ? add_assignment!(σoop.body, dx, expr_σoop, false) : nothing

    return UMC_PARSER_OK
end
