
abstract type InterestRateModelDynamics <: ModelDynamics end

include("short_rate_model.jl")
include("libor_market_model.jl")





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

