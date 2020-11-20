
function parse_attributes!(
    attrs::Expr,
    required_keys::Tuple{Vararg{GeneralExpr}},
    optional_keys::Tuple{Vararg{GeneralExpr}}
)
    output = Dict{GeneralExpr,GeneralExpr}()

    # assume it is not cleaned
    attrs = striplines(attrs)

    # importan checks
    isblock(attrs)
    check_attributes_format(attrs) # checks `key → value` format
    check_attributes_keys(attrs, required_keys, optional_keys)

    for key in required_keys

        if (value = parse_attribute(key, attrs)) == UMC_PARSER_ERROR
            throw(ArgumentError("missing attribute '$(string(key))'."))
        end

        output[key] = value
    end

    for key in optional_keys
        if (value = parse_attribute(key, attrs)) != UMC_PARSER_ERROR
            output[key] = value
        end
    end

    return output
end

function check_attributes_format(attrs::Expr)
    for arg in attrs.args

        key = @match arg begin
            key_ → value_ => key
        end

        if isnothing(key)
            throw(ArgumentError("expected 'key : value' format, got '$(string(arg))' instead."))
        end
    end

    return UMC_PARSER_OK
end

function check_attributes_keys(
    attrs::Expr,
    required_keys::Tuple{Vararg{GeneralExpr}},
    optional_keys::Tuple{Vararg{GeneralExpr}}
)
    parsed_keys = Set{GeneralExpr}()
    for arg in attrs.args

        key = @match arg begin
            key_ → value_ => key   # value as value_ is needed...
        end

        if !(key in (required_keys..., optional_keys...))
            throw(ArgumentError("unexpected key '$(string(key))'."))
        end

        if in(key, parsed_keys)
            throw(ArgumentError("repeated key '$(string(key))' in block."))
        end

        push!(parsed_keys, key)
    end

    return UMC_PARSER_OK
end

function check_attributes_keys_bracketed_format(
    potential_keys::Tuple{Vararg{GeneralExpr}},
    name::Symbol,
    N::Union{Int64,Vector{Int64}}
)
    for key in potential_keys

        value = @match key begin
            $(name)[s__] => Tuple(s)
        end

        if isnothing(value) || !any(n -> isa(value, NTuple{n,Symbol}), N)
            throw(ArgumentError("unexpected key '$(string(key))' format."))
        end
    end

    return UMC_PARSER_OK
end

function parse_attribute(attr, attrs)

    # assume that the attribute was not given
    val = nothing

    # could not use postwalk ...
    # postwalk(x -> @capture(x, $attr : value_) ? value : x, ex_attrs)
    # IDEA: use all()?
    for arg in attrs.args
        val = @match arg begin
            $attr → value_ => value
        end
        !isnothing(val) && break
    end

    return isnothing(val) ? UMC_PARSER_ERROR : val
end

function get_attributes_keys(attrs::Expr)
    # first, assume it is not cleaned
    attrs = rmlines(attrs)

    # important checks
    attrs.head == :block || error("expected attributes as a block, got '$(string(attrs))' instead.")

    check_attributes_format(attrs) # checks key : value format

    # get attributes keys
    keys = Vector{GeneralExpr}(undef, length(attrs.args))
    for (i, arg) in enumerate(attrs.args)
        keys[i] = @match arg begin
            key_ → value_ => key   # value as value_ is needed...
        end
    end

    return Tuple(keys)
end