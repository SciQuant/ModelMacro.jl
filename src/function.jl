
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
    f = Expr(:call, name, args)
    ex = :(
        $f = begin
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
    f = Expr(:call, name, args)
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
