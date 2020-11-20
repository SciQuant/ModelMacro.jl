
struct Dynamics
    P::OrderedDict{Symbol,AbstractProcess}
    Ps::OrderedDict{Symbol,AbstractProcesses}
    IRs::OrderedDict{Symbol,InterestRate}
end

function Dynamics()
    return Dynamics(
        OrderedDict{Symbol,AbstractProcess}(),
        OrderedDict{Symbol,AbstractProcesses}(),
        OrderedDict{Symbol,InterestRate}()
    )
end

# se construyen con una funcion
# D_expr::Expr # inside parameters?
# M_expr::Expr # inside parameters?
function generate_dimensions(d::Dynamics) end # generates tuples withs Dimensions
function concatenate_parameters(p::Parameters, d::Dynamics) end
function generate_functions(d::Dynamics) end # generates dynamics functions


function dynamics(dynamics::Dynamics)

    ds = AssignmentExpr[]

    for interest_rate in values(dynamics.IRs)

        model = interest_rate.model

        if isa(model, ShortRateModel)

            @unpack name, params, x = model
            @unpack κ, θ, Σ, α, β, ξ₀, ξ₁ = params

            add_assignment!(ds, name, :(MultiFactorAffine($(x.x0), $κ, $θ, $Σ, $α, $β, $ξ₀, $ξ₁)), false)

        # elseif isa(model, LiborMarketModel)

        end


    end

    for process in values(dynamics.P)
        @unpack name, x0, m, ρ = process

        kwargs = Expr(:tuple)
        isnothing(m) ? nothing : push!(kwargs.args, :(m = $m))
        isnothing(ρ) ? nothing : push!(kwargs.args, :(ρ = $ρ))

        add_assignment!(ds, name, :(AbstractProcess($x0; $kwargs...)), false)

    end

    for processes in values(dynamics.Ps)
        @unpack name, x0, m, ρ = processes

        kwargs = Expr(:tuple)
        isnothing(m) ? nothing : push!(kwargs.args, :(m = $m))
        isnothing(ρ) ? nothing : push!(kwargs.args, :(ρ = $ρ))

        add_assignment!(ds, name, :(AbstractProcesses($x0; $kwargs...)), false)

    end


    t = Expr(:tuple)
    push!(t.args, ds)
    return t
end