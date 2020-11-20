"""
    GeneralExpr

Macro arguments may include expressions, literal values, and symbols. Literal values can be,
`Number`, `Char`, `String`, and probably others. `GeneralExpr` limits literals to `Numbers`
since we do not expect to work with others.
"""
const GeneralExpr = Union{Expr,Number,Symbol}
const GeneralExprOrNothing = Union{GeneralExpr,Nothing}

struct AssignmentExpr
    lhs::Symbol
    rhs::GeneralExpr
end

const AssignmentOrGeneralExpr = Union{AssignmentExpr,GeneralExpr}

function add_assignment!(assignments, lhs, rhs, gensymed)
    lhs = gensymed == true ? gensym(lhs) : lhs
    push!(assignments, AssignmentExpr(lhs, rhs))
    return lhs
end

# seguramente me falte definir para a::Vector{AssignmentOrGeneralExpr} = push!.(Ref(args), a)
Base.push!(args::Array{Any,1}, a::Vector{AssignmentExpr}) = push!.(Ref(args), a)
Base.push!(args::Array{Any,1}, a::AssignmentExpr) = push!(args, Expr(:(=), a.lhs, a.rhs))