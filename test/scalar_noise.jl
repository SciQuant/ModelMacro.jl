
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