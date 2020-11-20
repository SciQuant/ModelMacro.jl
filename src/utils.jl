@enum ParserReturn UMC_PARSER_OK UMC_PARSER_ERROR

for head in (:block, :tuple, :macrocall)
    fname = Symbol(:is, head)
    qhead = quot(head)
    @eval begin
        function $fname(expr::Expr)
            return isexpr(expr, $qhead) ?
                UMC_PARSER_OK :
                throw(ArgumentError("expected `$($qhead)`, got '$(string(expr))' instead."))
        end
    end
end

const mapIndex = Dict{Char,Char}(
    '0' => '₀',
    '1' => '₁',
    '2' => '₂',
    '3' => '₃',
    '4' => '₄',
    '5' => '₅',
    '6' => '₆',
    '7' => '₇',
    '8' => '₈',
    '9' => '₉',
)

subscript(i) = join(mapIndex[c] for c in string(i))
index(s::Symbol, i) = Symbol(s, subscript(i))

getnames(x::DataType) = fieldnames(x)
getnames(x::NTuple) = x
getnames(x::NamedTuple) = keys(x)
getnames(x::Dict) = keys(x)
getnames(x) = propertynames(x) # for structs