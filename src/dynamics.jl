
struct DynamicsParser
    P::OrderedDict{Symbol,ProcessParser}
    Ps::OrderedDict{Symbol,ProcessesParser}
    IRs::OrderedDict{Symbol,InterestRateParser}
end

function DynamicsParser()
    return DynamicsParser(
        OrderedDict{Symbol,ProcessParser}(),
        OrderedDict{Symbol,ProcessesParser}(),
        OrderedDict{Symbol,InterestRateParser}()
    )
end

# se construyen con una funcion
# D_expr::Expr # inside parameters?
# M_expr::Expr # inside parameters?
function generate_dimensions(d::DynamicsParser) end # generates tuples withs Dimensions
function concatenate_parameters(p::ParametersParser, d::DynamicsParser) end
function generate_functions(d::DynamicsParser) end # generates dynamics functions
