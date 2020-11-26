
@processes (S, I, R) begin # var_gensymed = Processes(...); S(t) = var_gensymed(1, t)
    x₀ → x0
    m → ScalarNoise()
    μ → μ(S(t), I(t), R(t))
    σ → σ(S(t), I(t))

    # lo de arriba esta joya porque no alloca, pero si tenemos IIP... estamos jodidos.
    # por eso estaba esa idea de pedir un ptr a function que sea f(du, p, t, args...) o f(p, t, args...)
    μ → μ(du, t, S(t), I(t), R(t))
    σ → σ(du, t, S(t), I(t))
end

@parameters Params begin
    x0 = @SVector [S0, I0, R0]

    μ(S, I, R) = @SVector [
        -β * S * I / (1 + α1 * S + α2 * I + α3 * S * I) - b * S + (1 - m) * p * d * I + b * (1 - m) * (S + R),
        β * S * I / (1 + α1 * S + α2 * I + α3 * S * I) - (p * d + r) * I,
        r * I - b * R + d * m * p * I + m * b * (S + R)
    ]

    σ(S, I) = @SVector [
        -σ * S * I / (1 + α1 * S + α2 * I + α3 * S * I),
        σ * S * I / (1 + α1 * S + α2 * I + α3 * S * I),
        0
    ]
end

using MacroTools
prettify(@expand @model DS begin

    @interest_rate IR1 begin
        InterestRateModel → ShortRateModel
        ShortRateModel → MultiFactorAffine
        x₀ → 2*x0
        ξ₀ → ξ₀
        ξ₁ → ξ₁
        κ → ϰ
        θ → θ
        Σ → Σ
        α → α
        β → β
    end

    @interest_rate IR2 begin
        InterestRateModel → ShortRateModel
        ShortRateModel → OneFactorAffine
        r₀ → r0
        ξ₀ → 2ξ₀
        # ξ₁ → ξ₁
        κ → ϰ
        θ → θ
        Σ → Σ
        α → α
        β → β
    end


    @system x begin
        x₀ → 1.
        m → NonDiagonalNoise(2)
    end

    @system y begin
        x₀ → 1.
        m → NonDiagonalNoise(4)
        ρ → ρy
    end

    @system z begin
        x₀ → [1., 2.]
        m → ScalarNoise()
    end

    @parameters ParamsSet begin

        # x0 = @SVector [υ₀, θ₀, r₀]
        x0 = @SVector ones(3)

        ξ₀(t) = zero(t) # ξ₀ = zero
        ξ₁(t) = @SVector [0, 0, 1]

        ϰ(t) = @SMatrix([
            μ     0 0
            0     ν 0
            κ_rυ -κ κ
        ])
        θ(t) = @SVector [ῡ, θ̄, θ̄ ]
        Σ(t) = @SMatrix [
            η           0    0
            η * σ_θυ    1 σ_θr
            η * σ_rυ σ_rθ    1
        ]

        α(t) = @SVector [0, ζ^2, α_r]
        β(t) = @SMatrix [
            1 0 0
            β_θ 0 0
            1 0 0
        ]

        a = function (x,y)
            c = 1
            b = 2
            return x+y
        end
    end
end)



# struct Security{T}
#     x::T
# end
# (S::Security{<:SubArray{T,1}})() where T = S.x[]
# (S::Security)() = S.x

# function Security(u, t, idxs)
#     xₜ = view(u, idxs)
#     # x = s -> isequal(s, t) ? xₜ : throw(DomainError("error."))
#     # x = () -> xₜ
#     return Security(xₜ)
# end

# function test(u, p, t)
#     X = Security(u, t, 1:2)
#     x = Security(u, t, 3:3)
#     Xt = X()
#     xt = x()
#     return Xt, xt
# end

# function test2(u, p, t)
#     X = view(u, 1:2)
#     x = view(u, 3:3)
#     Xt = X
#     xt = x
#     return Xt, xt
# end

# struct Dimension{D} end
# dimension(::Dimension{D}) where D = D
# p = (Dimension{1}(), Dimension{2}(), Dimension{3}())

# function test3(u, p, t)
#     X = Security(u, t, dimension(p[1]):dimension(p[2]))
#     x = Security(u, t, dimension(p[3]):dimension(p[3]))
#     Xt = X()
#     xt = x()
#     return Xt, xt
# end

# function test4(u, p, t)
#     X = view(u, dimension(p[1]):dimension(p[2]))
#     x = view(u, dimension(p[3]):dimension(p[3]))
#     Xt = X
#     xt = x
#     return Xt, xt
# end

# p2 = (1, 2, 3)
# function test4(u, p, t)
#     X = view(u, p[1]:p[2])
#     x = view(u, p[3]:p[3])
#     Xt = X
#     xt = x
#     return Xt, xt
# end


# tengo que agregar el dx al Security{D,M}(du, u, ) y testear que todo siga igual de bien
struct Security{D,M,T}
    x::T
end
# dimension(::Security{D}) where {D} = D
# noise_dimension(::Security{D,M}) where {D,M} = M
# puedo usar el closure en funcion de (t) y los siguientes metodos funcionarian con (t::Real)
(S::Security{1})() = S.x[]
(S::Security{D})() where {D} = S.x
# (S::Security{D})(i) where {D} = S.x[i] # este no es necesario, se llama con [] y ya
# (S::Security{D})(i, t) where {D} = S.x[i]

function Security{D,M}(u, t, idxs) where {D,M}
    xₜ = view(u, idxs)
    # x = s -> isequal(s, t) ? xₜ : throw(DomainError("error."))
    return Security{D,M,typeof(xₜ)}(xₜ)
end

u = rand(3)
p = nothing
t = 0.1

function test1(u, p, t)
    X = Security(u, t, 2, 1, 1:2)
    x = Security(u, t, 2, 1, 3:3)
    Xt = X()
    xt = x()
    return Xt, xt
end
@btime test1($u, $p, $t)
# 3.666 ns (0 allocations: 0 bytes)

function test2(u, p, t)
    X = view(u, 1:2)
    x = view(u, 3:3)
    Xt = X
    xt = x[]
    return Xt, xt
end
@btime test2($u, $p, $t)
# 3.666 ns (0 allocations: 0 bytes)

struct Dimension{D} end
dimension(::Dimension{D}) where D = D
p = (Dimension{1}(), Dimension{2}(), Dimension{3}())

function test3(u, p, t)
    X = Security{dimension(p[2]),dimension(p[1])}(u, t, dimension(p[1]):dimension(p[2]))
    x = Security{dimension(p[1]),dimension(p[1])}(u, t, dimension(p[3]):dimension(p[3]))
    Xt = X()
    xt = x()
    return Xt, xt
end
@btime test3($u, $p, $t)
# 3.667 ns (0 allocations: 0 bytes)

function test4(u, p, t)
    X = view(u, dimension(p[1]):dimension(p[2]))
    x = view(u, dimension(p[3]):dimension(p[3]))
    Xt = X
    xt = x[]
    return Xt, xt
end
@btime test4($u, $p, $t)
# 3.666 ns (0 allocations: 0 bytes)

p = (1, 2, 3)
function test5(u, p, t)
    X = view(u, p[1]:p[2])
    x = view(u, p[3]:p[3])
    Xt = X
    xt = x
    return Xt, xt
end
@btime test5($u, $p, $t)
# 6.417 ns (0 allocations: 0 bytes)