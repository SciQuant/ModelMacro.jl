
struct Function{IIP}
    name::Symbol
    args::Expr
    header::Expr
    body::Expr
    output::Expr

    function Function{IIP}(
        name;
        args=Expr(:tuple), header=Expr(:block), body=Expr(:block), output=Expr(:block)
    ) where {IIP}
        return new{IIP}(name, args, header, body, output)
    end
end

isinplace(::Function{IIP}) where {IIP} = IIP
name(f::Function) = f.name

# function define_function(parser, name, args, header, body, output, iip::Bool, iname = name)
#     functions = parser.functions

#     if name in keys(functions)
#         error("function '$(string(name))' already exists.")
#     end

#     push!(functions, name => Function(iname, args, header, body, output, iip))

#     return UMC_PARSER_OK
# end

# getfunction(parser, name) = parser.functions[name]
# name(f::Function) = f.name
# getfuncname(parser, name) = getname(getfunction(parser, name))

function Base.convert(::Type{Expr}, f::Function{true})
    @unpack name, args, header, body, output = f
    f = Expr(:call, name, args)
    ex = :(
        $f = begin
            @inbounds begin
                $header
                $body
                $output
                return nothing
            end
        end
    )

    return esc(ex)
end

function Base.convert(::Type{Expr}, f::Function{false})
    @unpack name, args = f
    header = Expr(:block)
    push!(header.args, f.header)
    body = Expr(:block)
    push!(body.args, f.body)
    output = Expr(:block)
    push!(output.args, f.output)
    # header, body, output = build_function_blocks(f)

    f = Expr(:call, name, args...)
    ex = :(
        $f = begin
            @inbounds begin
                $header
                $body
                return $output
            end
        end
    )

    return esc(ex)
end
