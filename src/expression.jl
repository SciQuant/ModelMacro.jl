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

function code_block(exprs)
    block = Expr(:block)
    push_code!(block, exprs...)
    return block
end

function code_tuple(exprs)
    tup = Expr(:tuple)
    push_code!(tuple, exprs...)
    return tup
end

push_code!(block, a::AssignmentExpr) = push!(block.args, Expr(:(=), a.lhs, a.rhs))
push_code!(block, g::GeneralExpr) = push!(block.args, g)
push_code!(block, iter...) = push_code!(block, iter)
push_code!(block, iter) = _push_code!(block, iter)

function _push_code!(block, iter)
    for item in iter
        push_code!(block, item)
    end
    block
end
