
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
        μ → begin # fx(x.dx, ...) # entonces esta termina siendo una buena opcion tambien, mandar fx(dx, ...)
            x.dx[] = x(t) + 2
            # para dimensiones mayores a 1 estoy pensando, igual no sirve porque la operacion del lhs del copy puede allocar y lo mismo para el otro caso! jajaj
            x.dx[:] .= x(t) + 2 # para dimensiones mayores a 1 podemos poner en el codigo. claramente aca yo no conozco la dimension
            copyto!(x.dx, x(t) + 2) # tambien podemos hacer esto en el fuente, el copyto! lo pongo yo. el tema es que cuando la dimension es uno, conviene el primero.
        end
    end

    @system y begin
        x₀ → [1., 2.]
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


#= /Users/ramirovignolo/.julia/dev/ModelMacro/src/macro_model.jl:104 =#
var"##f#555"((var"##du#552", var"##u#553", var"##p#554", t)) = begin
    #= /Users/ramirovignolo/.julia/dev/ModelMacro/src/function.jl:24 =#
    begin
        $(Expr(:inbounds, true))
        local var"#74#val" = begin
                    #= /Users/ramirovignolo/.julia/dev/ModelMacro/src/function.jl:25 =#
                    begin
                        begin
                            #= /Users/ramirovignolo/.julia/packages/UnPack/EkESO/src/UnPack.jl:100 =#
                            local var"##557" = var"##p#554"
                            #= /Users/ramirovignolo/.julia/packages/UnPack/EkESO/src/UnPack.jl:101 =#
                            begin
                                x0 = (UnPack).unpack(var"##557", Val{:x0}())
                                ξ₀ = (UnPack).unpack(var"##557", Val{:ξ₀}())
                                ξ₁ = (UnPack).unpack(var"##557", Val{:ξ₁}())
                                ϰ = (UnPack).unpack(var"##557", Val{:ϰ}())
                                θ = (UnPack).unpack(var"##557", Val{:θ}())
                                Σ = (UnPack).unpack(var"##557", Val{:Σ}())
                                α = (UnPack).unpack(var"##557", Val{:α}())
                                β = (UnPack).unpack(var"##557", Val{:β}())
                                a = (UnPack).unpack(var"##557", Val{:a}())
                                var"##dynamicsIR1#539" = (UnPack).unpack(var"##557", Val{Symbol("##dynamicsIR1#539")}())
                                var"##dynamics##B_IR1#541#542" = (UnPack).unpack(var"##557", Val{Symbol("##dynamics##B_IR1#541#542")}())
                                var"##dynamicsIR2#543" = (UnPack).unpack(var"##557", Val{Symbol("##dynamicsIR2#543")}())
                                var"##dynamics##B_IR2#545#546" = (UnPack).unpack(var"##557", Val{Symbol("##dynamics##B_IR2#545#546")}())
                                var"##x#547" = (UnPack).unpack(var"##557", Val{Symbol("##x#547")}())
                                var"##y#548" = (UnPack).unpack(var"##557", Val{Symbol("##y#548")}())
                                var"##z#549" = (UnPack).unpack(var"##557", Val{Symbol("##z#549")}())
                                var"##D#550" = (UnPack).unpack(var"##557", Val{Symbol("##D#550")}())
                                var"##M#551" = (UnPack).unpack(var"##557", Val{Symbol("##M#551")}())
                            end
                            #= /Users/ramirovignolo/.julia/packages/UnPack/EkESO/src/UnPack.jl:102 =#
                            var"##557"
                        end
                        var"##x_IR1#540" = Security{dimension(var"##dynamicsIR1#539"), noise_dimension(var"##dynamicsIR1#539"), true}(var"##du#552", var"##u#553", t, 1:dimension(var"##D#550"[1]))
                        var"##B_IR1#541" = Security{dimension(var"##dynamics##B_IR1#541#542"), noise_dimension(var"##dynamics##B_IR1#541#542"), true}(var"##du#552", var"##u#553", t, dimension(var"##D#550"[1]) + 1:dimension(var"##D#550"[2]))
                        IR1 = FixedIncomeSecurities(var"##dynamicsIR1#539", var"##x_IR1#540", var"##B_IR1#541")
                        var"##x_IR2#544" = Security{dimension(var"##dynamicsIR2#543"), noise_dimension(var"##dynamicsIR2#543"), true}(var"##du#552", var"##u#553", t, dimension(var"##D#550"[2]) + 1:dimension(var"##D#550"[3]))
                        var"##B_IR2#545" = Security{dimension(var"##dynamics##B_IR2#545#546"), noise_dimension(var"##dynamics##B_IR2#545#546"), true}(var"##du#552", var"##u#553", t, dimension(var"##D#550"[3]) + 1:dimension(var"##D#550"[4]))
                        IR2 = FixedIncomeSecurities(var"##dynamicsIR2#543", var"##x_IR2#544", var"##B_IR2#545")
                        x = Security{dimension(var"##x#547"), noise_dimension(var"##x#547"), true}(var"##du#552", var"##u#553", t, dimension(var"##D#550"[4]) + 1:dimension(var"##D#550"[5]))
                        y = Security{dimension(var"##y#548"), noise_dimension(var"##y#548"), true}(var"##du#552", var"##u#553", t, dimension(var"##D#550"[5]) + 1:dimension(var"##D#550"[6]))
                        z = Security{dimension(var"##z#549"), noise_dimension(var"##z#549"), true}(var"##du#552", var"##u#553", t, dimension(var"##D#550"[6]) + 1:dimension(var"##D#550"[7]))
                    end
                    #= /Users/ramirovignolo/.julia/dev/ModelMacro/src/function.jl:26 =#
                    begin
                        drift!((var"##x_IR1#540").dx, var"##x_IR1#540"(t), parameters(var"##dynamicsIR1#539"), t)
                        (var"##B_IR1#541").dx[] = IR1.r(t) * var"##B_IR1#541"(t)
                        drift!((var"##x_IR2#544").dx, var"##x_IR2#544"(t), parameters(var"##dynamicsIR2#543"), t)
                        (var"##B_IR2#545").dx[] = IR2.r(t) * var"##B_IR2#545"(t)
                        nothing
                        nothing
                        nothing
                    end
                    #= /Users/ramirovignolo/.julia/dev/ModelMacro/src/function.jl:27 =#
                    return nothing
                end
        $(Expr(:inbounds, :pop))
        var"#74#val"
    end
end



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
# o sea, agregar dμ y dσ, porque pueden ser diferentes views
struct Security{D,M,DN,T,S}
    dx::T
    x::S
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

# al drift siempre le mando DN = true
function Security{D,M,true}(du, u, t, idxs) where {D,M}
    dxₜ = view(du, idxs)
    xₜ = view(u, idxs)
    # x = s -> isequal(s, t) ? xₜ : throw(DomainError("error."))
    return Security{D,M,true,typeof(dxₜ),typeof(xₜ)}(dxₜ, xₜ)
end

# esta se usa en el caso del non diagonal noise para σ
function Security{D,M,false}(du, u, t, d, m) where {D,M}
    dxₜ = view(du, d, m)
    xₜ = view(u, d)
    # x = s -> isequal(s, t) ? xₜ : throw(DomainError("error."))
    return Security{D,M,false,typeof(dxₜ),typeof(xₜ)}(dxₜ, xₜ)
end

du = rand(3)
u = rand(3)
p = nothing
t = 0.1

function test1(du, u, p, t)
    X = Security{2,1,true}(du, u, t, 1:2)
    x = Security{1,1,true}(du, u, t, 3:3)
    Xt = X()
    xt = x()
    return Xt, xt
end
@btime test1($du, $u, $p, $t)
# 3.666 ns (0 allocations: 0 bytes)

du = rand(3, 5)
function test(du, u, p, t)
    X = Security{2,3,false}(du, u, t, 1:2, 1:3)
    x = Security{1,2,false}(du, u, t, 3:3, 4:5)
    Xt = X()
    xt = x()
    return Xt, xt
end
@btime test($du, $u, $p, $t)

function test0(du, u, p, t)
    X = view(u, 1:2)
    x = view(u, 3:3)
    dX = view(du, 1:2, 1:3)
    dx = view(du, 3:3, 4:5)
    Xt = X
    xt = x[]
    return Xt, xt
end
@btime test0($du, $u, $p, $t)

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

p = [1, 2, 3]
function test6(u, p, t)
    X = view(u, p[1]:p[2])
    x = view(u, p[3]:p[3])
    Xt = X
    xt = x
    return Xt, xt
end
@btime test6($u, $p, $t)
# 7.312 ns (0 allocations: 0 bytes)