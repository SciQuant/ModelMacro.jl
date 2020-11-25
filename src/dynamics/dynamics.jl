
include("system/system.jl")

include("models/models.jl")

struct Dynamics
    systems::OrderedDict{Symbol,SystemDynamics}
    models::OrderedDict{Symbol,ModelDynamics}
    # IRs::OrderedDict{Symbol,InterestRate}
end

function Dynamics()
    return Dynamics(
        OrderedDict{Symbol,SystemDynamics}(),
        OrderedDict{Symbol,ModelDynamics}()
    )
end

# se construyen con una funcion
# D_expr::Expr # inside parameters?
# M_expr::Expr # inside parameters?
function generate_dimensions(d::Dynamics) end # generates tuples withs Dimensions
function concatenate_parameters(p::Parameters, d::Dynamics) end
function generate_functions(d::Dynamics) end # generates dynamics functions


function convert(::Type{Expr}, dynamics::Dynamics)

    ds = AssignmentExpr[]
    ds_names = Symbol[]

    for interest_rate in values(dynamics.IRs)

        model = interest_rate.model

        if isa(model, ShortRateModel)

            @unpack name, params, x = model
            @unpack κ, θ, Σ, α, β, ξ₀, ξ₁ = params

            push!(ds_names,
                add_assignment!(
                    ds,
                    name,
                    :(MultiFactorAffine($(x.x0), $κ, $θ, $Σ, $α, $β, $ξ₀, $ξ₁)),
                    false # ya esta gensymeado
                )
            )

            # y agrego el process money market


        # elseif isa(model, LiborMarketModel)

        end


    end

    for process in values(dynamics.P)
        @unpack name, x0, m, ρ = process

        kwargs = Expr(:tuple)
        isnothing(m) ? nothing : push!(kwargs.args, :(m = $m))
        isnothing(ρ) ? nothing : push!(kwargs.args, :(ρ = $ρ))

        add_assignment!(ds, name, :(AbstractProcess($x0; $kwargs...)), true)

    end

    for processes in values(dynamics.Ps)
        @unpack name, x0, m, ρ = processes

        kwargs = Expr(:tuple)
        isnothing(m) ? nothing : push!(kwargs.args, :(m = $m))
        isnothing(ρ) ? nothing : push!(kwargs.args, :(ρ = $ρ))

        add_assignment!(ds, name, :(AbstractProcesses($x0; $kwargs...)), true)

    end


    t = Expr(:tuple)
    push!(t.args, ds)
    return t
end


# esta funcion la llamo dentro de parameters y recibo parameters. fuck no puedo
function process_dimension(p)

end





