
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

function Base.convert(::Type{Expr}, f::Function{true})
    @unpack name, args, header, body = f
    ex = :(
        function $(name)($(args.args...))
            @inbounds begin
                $header
                $body
                return nothing
            end
        end
    )
    return esc(ex)
end

function Base.convert(::Type{Expr}, f::Function{false})
    @unpack name, args, header, body, output = f
    ex = :(
        function $(name)($(args.args...))
            @inbounds begin
                $header
                $body
                return $output
            end
        end
    )
    return esc(ex)
end
