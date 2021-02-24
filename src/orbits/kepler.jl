using AstroLib: kepler_solver, trueanom
using KeywordDispatch
using PhysicalConstants
using Unitful
using UnitfulAstro

const G = PhysicalConstants.CODATA2018.G
const G_val = 6.67430e-8 # CGS

"""
    KeplerianOrbit(; kwargs...)
Keplerian orbit parameterized by the basic observables of a transiting 2-body system.
# Parameters
* `a` - The semi-major axis, nominally in AU
* `aRₛ` - The ratio of the semi-major axis to the star radius. Aliased to `aRs`
* `b` - The impact parameter, bounded between 0 ≤ b ≤ 1
* `ecc` - The eccentricity of the closed orbit, bounded between 0 ≤ ecc < 1
* `P` - The orbital period of the planet, nominally in days
* `ρₛ` - The spherical star density, nominally in g/cc. Aliased to `rho_s`
* `r_star` - The star mass, nominally in solar radii. Aliased to `R_s`
* `t₀` - The midpoint time of the reference transit, same units as `P`. Aliased to `t0`
* `incl` - The inclination of the orbital plane relative to the axis perpendicular to the
           reference plane, nominally in degrees
* `Ω` - The longitude of the ascending node, nominally in radians. Aliased to `Omega`
* `ω` - The argument of periapsis, same units as `Ω`. Aliased to `omega`
"""
struct KeplerianOrbit <: AbstractOrbit
    a
    aRₛ
    b
    ecc
    P
    ρₛ
    r_star
    n
    t₀
    incl
    Ω
    ω
end

# Enable keyword dispatch and argument name aliasing
@kwdispatch KeplerianOrbit(;
    Omega => Ω,
    omega => ω,
    aRs => aRₛ,
    rho_s => ρₛ,
    aRs => aRₛ,
    Rs => r_star,
    t0 => t₀,
)

@kwmethod function KeplerianOrbit(;ρₛ, r_star, ecc, P, t₀, incl)
    Ω = π / 2
    ω = 0.0
    a = get_a(ρₛ, P, r_star)
    b = get_b(ρₛ, P, sincos(incl))

    return KeplerianOrbit(
        a,
        get_aRₛ(ρₛ=ρₛ, P=P) |> upreferred,
        upreferred(b) |> upreferred,
        ecc,
        P,
        ρₛ,
        r_star,
        2 * π / P,
        t₀,
        incl,
        Ω,
        ω,
    )
end

@kwmethod function KeplerianOrbit(;aRₛ, b, ecc, P, t₀)
    Ω = π / 2
    ω = 0.0
    incl = get_incl(aRₛ, b, ecc, sincos(ω))

    return KeplerianOrbit(
        nothing,
        aRₛ |> upreferred,
        b |> upreferred,
        ecc,
        P,
        nothing,
        nothing,
        2 * π / P,
        t₀,
        incl,
        Ω,
        ω,
    )
end

#############
# Orbit logic
#############
# Star density
get_ρₛ(aRₛ, P) = (3 * π / (G_val * P^2)) * aRₛ^3
get_ρₛ(a, P, r_star) = get_ρₛ(aRₛ(a, r_star), P)

# Semi-major axis / star radius ratio
@kwdispatch get_aRₛ()
@kwmethod get_aRₛ(;ρₛ, P) = cbrt(G_val * P^2 * ρₛ / (3 * π))
@kwmethod get_aRₛ(;a, P, r_star) = aRₛ(get_ρₛ(a, P, r_star), P)
@kwmethod get_aRₛ(;a, r_star) = a / r_star

# Semi-major axis
get_a(ρₛ, P, r_star) = get_a(get_aRₛ(ρₛ=ρₛ, P=P), r_star)
get_a(aRₛ, r_star) = aRₛ * r_star

# Impact parameter
get_b(ρₛ, P, sincosi) = get_b(get_aRₛ(ρₛ=ρₛ, P=P), sincosi)
get_b(aRₛ, sincosi) = aRₛ * sincosi[2]

# Inclination
function get_incl(aRₛ, b, ecc, sincosω)
    return acos((b/aRₛ) * (1 + ecc*sincosω[1])/(1 - ecc^2))
end

# Finds the position `r` of the planet along its orbit after rotating
# through the true anomaly `ν`, then transforms this from the
# orbital plan to the equatorial plane
function relative_position(orbit::KeplerianOrbit, t)
    sinν, cosν = get_true_anomaly(orbit, t)
    if orbit.ecc === nothing
        r = orbit.a
    else
        r = orbit.a * (1 - orbit.ecc^2) / (1 + orbit.ecc * cosν)
    end
    return rotate_vector(orbit, r * cosν, r * sinν)
end

# Returns sin(ν), cos(ν)
function get_true_anomaly(orbit::KeplerianOrbit, t)
    M = orbit.n * ((t - orbit.t₀))
    E = kepler_solver(M, orbit.ecc)
    return sincos(trueanom(E, orbit.ecc))
end
#(M, ::Nothing) = sincos(M)

# Transform from orbital plane to equatorial plane
function rotate_vector(orbit::KeplerianOrbit, x, y)
    sini, cosi = sincos(orbit.incl)
    sinΩ, cosΩ = sincos(orbit.Ω)
    sinω, cosω = sincos(orbit.ω)
    # rotate about z0 axis by ω
    if orbit.ecc === nothing
        x1, y1 = x, y
    else
        x1 = cosω * x - sinω * y
        y1 = sinω * x + cosω * y
    end

    # rotate about x1 axis by -incl
    x2 = x1
    y2 = cosi * y1
    Z = -sini * y1

    # rotate about z2 axis by Ω
     if orbit.Ω === nothing
         return SA[x2, y2, Z]
     end
     X = cosΩ * x2 - sinΩ * y2
     Y = sinΩ * x2 + cosΩ * y2
     return SA[X, Y, Z]
end

function Base.show(io::IO, orbit::KeplerianOrbit)
    a = orbit.a
    aRₛ = orbit.aRₛ
    b = orbit.b
    ecc = orbit.ecc
    P = orbit.P
    ρₛ = orbit.ρₛ
    r_star = orbit.r_star
    t₀ = orbit.t₀
    incl = orbit.incl
    Ω = orbit.Ω
    ω = orbit.ω
    print(
        io,
        """KeplerianOrbit(
            a=$(orbit.a), aRₛ=$(orbit.aRₛ),
            b=$(orbit.b), ecc=$(orbit.ecc), P=$(orbit.P),
            ρₛ=$(orbit.ρₛ), r_star=$(orbit.r_star),
            t₀=$(orbit.t₀), incl=$(orbit.incl),
            Ω=$(orbit.Ω), ω = $(orbit.ω)
        )"""
    )
end

function Base.show(io::IO, ::MIME"text/plain", orbit::KeplerianOrbit)
    print(
        io,
        """
        KeplerianOrbit
         a: $(orbit.a)
         aRₛ: $(orbit.aRₛ)
         b: $(orbit.b)
         ecc: $(orbit.ecc)
         P: $(orbit.P)
         ρₛ: $(orbit.ρₛ)
         r_star: $(orbit.r_star)
         t₀: $(orbit.t₀)
         incl: $(orbit.incl)
         Ω: $(orbit.Ω)
         ω: $(orbit.ω)
        """
    )
end
