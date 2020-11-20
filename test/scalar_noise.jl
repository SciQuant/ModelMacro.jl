
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


parser = @model DS begin

    @interest_rate IR begin
        InterestRateModel → ShortRateModel
        ShortRateModel → MultiFactorAffine
        x₀ → x0
        ξ₀ → ξ₀
        ξ₁ → ξ₁
        κ → ϰ
        θ → θ
        Σ → Σ
        α → α
        β → β
    end

    @process x begin
        x₀ → 1.
        m → mx
    end
    @process y begin
        x₀ → 1.
        m → 2 * mx
        ρ → ρy
    end
    @processes z begin
        x₀ → [1., 2.]
        m → [1, 2]
        # ρ → ρ
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
end