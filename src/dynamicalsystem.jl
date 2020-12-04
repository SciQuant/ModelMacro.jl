
# la verdad que con la function `f` podria usar el dispatch comun, ya que escribo dos
# functions con el mismo name y cada una tiene diferente numero de argumentos.
struct DynamicalSystemDrift{IIP,F1,F2}
    iip::F1
    oop::F2
end

@inline (f::DynamicalSystemDrift{true})(du, u, p, t) = f.iip(du, u, p, t)
@inline (f::DynamicalSystemDrift{false})(u, p, t) = f.oop(u, p, t)

DynamicalSystemDrift{IIP}(iip::F1, oop::F2) where {IIP} = DynamicalSystemDrift{IIP,F1,F2}(iip, oop)

# aca no puedo usar el dispatch comun, tengo que elegir entre 2 con el mismo numero de args.
# por lo tanto, dependo de IIP y DN
struct DynamicalSystemDiffusion{IIP,DN,G1,G2,G3,G4}
    iip_dn::G1
    oop_dn::G2
    iip_ndn::G3
    oop_ndn::G4
end

@inline (g::DynamicalSystemDiffusion{true,true})(du, u, p, t)  = g.iip_dn(du, u, p, t)
@inline (g::DynamicalSystemDiffusion{false,true})(u, p, t) = g.oop_dn(u, p, t)
@inline (g::DynamicalSystemDiffusion{true,false})(du, u, p, t) = g.iip_ndn(du, u, p, t)
@inline (g::DynamicalSystemDiffusion{false,false})(u, p, t) = g.oop_ndn(u, p, t)

DynamicalSystemDiffusion{IIP,DN}(iip_dn::G1, oop_dn::G2, iip_ndn::G3, oop_ndn::G4) where {IIP,DN,G1,G2,G3,G4} =
    DynamicalSystemDiffusion{IIP,DN,G1,G2,G3,G4}(iip_dn, oop_dn, iip_ndn, oop_ndn)


# tenemos que tener algunos constructores adicionales en esta libreria
# import UniversalMonteCarlo: DynamicalSystem

function DynamicalSystem(
    p;
    f_iip=nothing, f_oop=nothing, g_iip_dn=nothing, g_oop_dn=nothing, g_iip_ndn=nothing, g_oop_ndn=nothing)

    # el temita del filtrado de p
    dynamics = filter(d -> d isa AbstractDynamics, p)

    # calcular IIP

    # llamar a las funciones que tenemos en la otra libreria y que calculen IIP,D,M,DN
    # es decir, armar esas funciones y llamarlas aca

    f = DynamicalSystemDrift{IIP}(f_iip, f_oop)
    g = DynamicalSystemDiffusion{IIP,DN}(g_iip_dn, g_oop_dn, g_iip_ndn, g_oop_ndn)


    return UniversalMonteCarlo.DynamicalSystem(f, g, p) # esta basicamente va a recalcular varias cosas que ya hicimos aca, va, aca seguro calculemos menos cosas, solo IIP, D, M y DN
    # NO, me parece que directamente llamamos aca al constructor nosotros y antes calculamos todo
    return DynamicalSystem{IIP,D,M,DN}(
        f, g, x0, p; t0=t0, ρ=ρ, noise=noise, noise_rate_prototype=noise_rate_prototype
    )
end
