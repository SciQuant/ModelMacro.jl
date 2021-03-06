
struct Parameters
    name::Vector{Symbol}
    names::Vector{Symbol}
    assignments::Vector{AssignmentExpr}
end

Parameters() = Parameters(Symbol[], Symbol[], AssignmentExpr[])

function parse_params!(parser, block)

    parameters = parser.parameters
    @unpack name, names, assignments = parameters

    pname = block.args[3] # get name in macro block
    if !isa(pname, Symbol)
        throw(ArgumentError(
            "expected `@parameters` name as a `Symbol`, got '$(string(pname))' instead.")
        )
    end
    push!(name, pname)

    # this block contains all the parameters
    paramsblock = rmlines(block.args[4])
    check_block(paramsblock)

    for line in paramsblock.args

        # check if it is an assignment
        if @capture(line, lhs_ = rhs_)

            # translate to closures when needed
            if @capture(line, f_(xs__) = body_)
                closure = striplines(:(($(xs...),) -> $body))
                add_assignment!(assignments, f, closure, false)
                push!(names, f)
            else
                add_assignment!(assignments, lhs, striplines(rhs), false)
                push!(names, lhs)
            end
        else
            throw(ArgumentError("expected a parameter assignment, got '$(string(line))' instead."))
        end
    end

    return UMC_PARSER_OK
end

generate_withkw_macro(p::Parameters) = generate_withkw_macro(p.assignments)

function generate_withkw_macro(a::Vector{AssignmentExpr})
    t = Expr(:tuple)
    push!(t.args, convert.(Expr, a)...)
    macro_expr = Expr(:macrocall, Symbol("@with_kw"), :nothing, t)
    return macro_expr
end

function generate_unpack_macro(paramsnames, p)
    params = Expr(:tuple)
    push!(params.args, paramsnames...)
    macro_expr = Expr(:macrocall, Symbol("@unpack"), :nothing, Expr(:(=), params, p))
    return macro_expr
end