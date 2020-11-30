"""
    GeneralExpr

Macro arguments may include expressions, literal values, and symbols. Literal values can be,
`Number`, `Char`, `String`, and probably others. `GeneralExpr` limits literals to `Numbers`
since we do not expect to work with others.
"""
const GeneralExpr = Union{Expr,Number,Symbol} # julia usa Any para expresar block.args...
const GeneralExprOrNothing = Union{GeneralExpr,Nothing}

struct AssignmentExpr
    lhs::Symbol
    rhs::Any
end

lefthandside(a::AssignmentExpr) = a.lhs
righthandside(a::AssignmentExpr) = a.rhs

function add_assignment!(assignments, lhs, rhs, gensymed)
    lhs = gensymed ? gensym(lhs) : lhs
    push!(assignments, AssignmentExpr(lhs, rhs))
    return lhs
end

import Base: convert
convert(::Type{Expr}, a::AssignmentExpr) = Expr(:(=), a.lhs, a.rhs)
