using BenchmarkTools
using Unitful, UnitfulAstro
using Transits.Orbits: KeplerianOrbit, flip,
                       relative_position, compute_aor,
                       _star_position, _planet_position,
                       stringify_units

const G_nom = 2942.2062175044193 # Rsun^3/Msun/d^2
const MsunRsun_to_gcc = (1.0u"Msun/Rsun^3" |> u"g/cm^3").val

function compute_r(orbit, t)
    pos = relative_position.(orbit, t)
    r = map(pos) do arr
        hypot(arr[1], arr[2])
    end
    return r
end

# Convert vector of vectors -> matrix
as_matrix(pos) = reinterpret(reshape, Float64, pos) |> permutedims

# Tests from:
# https://github.com/exoplanet-dev/exoplanet/blob/main/tests/orbits/keplerian_test.py

@testset "KeplerianOrbit: sky coords" begin
    # Comparison coords from `batman`
    sky_coords = load("./python_code/test_data/KeplerianOrbit_sky_coords.jld2")

    # Create comparison orbits from Transits.jl
    orbits = [
        KeplerianOrbit(
            aR_star = sky_coords["a"][i],
            P = sky_coords["period"][i],
            incl = sky_coords["incl"][i],
            t_0 = sky_coords["t0"][i],
            ecc = sky_coords["e"][i],
            Omega = 0.0,
            omega = sky_coords["omega"][i],
        )
        for i in 1:length(sky_coords["t0"])
    ]

    # Compute coords
    t = sky_coords["t"]
    x = Matrix{Float64}(undef, length(sky_coords["t"]), length(sky_coords["t0"]))
    y = similar(x)
    z = similar(x)
    for (orbit, x_i, y_i, z_i) in zip(orbits, eachcol(x), eachcol(y), eachcol(z))
        pos = relative_position.(orbit, t) |> as_matrix
        a, b, c = eachcol(pos)
        x_i .= a
        y_i .= b
        z_i .= c
    end

    # Compare
    m = sky_coords["m"]
    r = hypot.(x, y)
    r_Transits = r[m]
    r_batman = sky_coords["r_batman"][m]

    @test sum(m) > 0
    @test allclose(r_Transits, r_batman, atol=2e-5)
    @test all(z[m] .> 0)
    no_transit = @. (z[!(m)] < 0) | (r[!(m)] > 2)
    @test all(no_transit)
end

@testset "KeplerianOrbit: construction performance" begin
    b_rho_star = @benchmark KeplerianOrbit(
        rho_star = 2.0,
        R_star = 0.5,
        period = 2.0,
        ecc = 0.0,
        t_0 = 0.0,
        incl = π / 2.0,
        Omega = 0.0,
        omega = 0.0,
    )

    b_rho_star_units = @benchmark KeplerianOrbit(
        rho_star = 2.0u"g/cm^3",
        R_star = 0.5u"Rsun",
        period = 2.0u"d",
        ecc = 0.0,
        t_0 = 0.0u"d",
        incl = 90.0u"°",
        Omega = 0.0u"°",
        omega = 0.0u"°",
    )

    b_aR_star = @benchmark KeplerianOrbit(
        aR_star = 7.5,
        P = 2.0,
        incl = π / 2.0,
        t_0 = 0.0,
        ecc = 0.0,
        Omega = 0.0,
        omega = 0.0,
    )

    b_aR_star_units = @benchmark KeplerianOrbit(
        aR_star = 7.5,
        P = 2.0u"d",
        incl = 90.0u"°",
        t_0 = 0.0u"d",
        ecc = 0.0,
        Omega = 0.0u"°",
        omega = 0.0u"°",
    )

    # Units
    @test median(b_rho_star_units.times) ≤ 100_000 # ns
    @test b_rho_star_units.allocs ≤ 500
    @test median(b_aR_star_units.times) ≤ 100_000   # ns
    @test b_aR_star_units.allocs ≤ 500

    if v"1.6" ≤ Base.VERSION < v"1.7-"
        @test b_rho_star.allocs == b_rho_star.memory == 0
        @test median(b_rho_star.times) ≤ 500 # ns
        @test b_aR_star.allocs == b_aR_star.memory == 0
        @test median(b_aR_star.times) ≤ 500 # ns
    else
        # TODO: investigate performance regression
        @test median(b_rho_star.times) ≤ 20_000 # ns
        @test median(b_aR_star.times) ≤ 20_000 # ns
    end
end

@testset "KeplerianOrbit: orbital elements" begin
    orbit = KeplerianOrbit(
        cos_omega=√(2)/2, sin_omega=√(2)/2,
        period=2.0, t_0=0.0, b=0.01, M_star=1.0, R_star=1.0, ecc=0.0,
    )
    @test orbit.omega == atan(orbit.sin_omega/orbit.cos_omega)

    orbit = KeplerianOrbit(
        period = 0.9,
        t_0 = 0.0,
        duration = 0.02,
        R_star = 1.0,
        M_star = 1.0,
        r = 0.0001,
        ecc = 0.01,
        omega = 0.0,
    );
    ecc = orbit.ecc
    sin_omega = orbit.sin_omega
    incl_factor_inv  = (1.0 - ecc^2) / (1.0 + ecc * sin_omega)
    c = sin(π * orbit.duration / (incl_factor_inv) / orbit.period)
    c_sq = c^2
    ecc_sin_omega = ecc*sin_omega
    aor = orbit.a_planet / orbit.R_star
    @test orbit.b == √(
        (aor^2 * c_sq - 1.0) /
        (
            c_sq * ecc_sin_omega^2 +
            2.0*c_sq*ecc_sin_omega +
            c_sq - ecc^4 + 2.0*ecc^2 - 1.0
        )
    ) * (1.0 - ecc^2)
    @test orbit.sin_incl == sin(orbit.incl)

    orbit = KeplerianOrbit(
        period=2.0, t_0=0.0, M_star=1.0, R_star=1.0,
        ecc=0.01, omega=0.1, r=0.01,
    )
    @test isnothing(orbit.duration)
end

@testset "KeplerianOrbit: valid inputs" begin
    @test_throws ArgumentError("`b` must also be provided for a circular orbit if `duration given`") KeplerianOrbit(
        duration=0.01,
        period=2.0, t_0=0.0, R_star=1.0
    )
    @test_throws ArgumentError("`r` must also be provided if `duration` given") KeplerianOrbit(
        duration=0.01, b=0.0,
        period=2.0, t_0=0.0, R_star=1.0
    )
    #@test_throws ArgumentError("Only `ω`, or `cos_ω` and `sin_ω` can be provided") KeplerianOrbit(
    #    omega=0.0, cos_omega=1.0, sin_omega=0.0,
    #    period=2.0, t_0=0.0, b=0.0, M_star=1.0, R_star=1.0, ecc=0.0,
    #)
    #@test_throws ArgumentError("`ω` must also be provided if `ecc` specified") KeplerianOrbit(
    #    rho_star=2.0, R_star=0.5, period=2.0, t_0=0.0, incl=π/2.0, Omega=0.0, ecc=0.0,
    #)
    @test_throws ArgumentError("Only `incl`, `b`, or `duration` can be given") KeplerianOrbit(
        incl=π/2.0, b=0.0, duration=1.0,
        period=2.0, t_0=0.0, R_star=1.0, r=0.01,
    )
    @test_throws ArgumentError("Please specify either `t0` or `tp`") KeplerianOrbit(
        b=0.0, period=2.0, R_star=1.0, M_star=1.0,
    )
    @test_throws ArgumentError("Please only specify one of `t0` or `tp`") KeplerianOrbit(
        b=0.0, period=2.0, R_star=1.0, M_star=1.0, t0=0.0, tp=1.0,
    )
    @test_throws ArgumentError("At least `a` or `P` must be specified") KeplerianOrbit(
        b=0.0, R_star=1.0, M_star=1.0,
    )
    @test_throws ArgumentError("If both `a` and `P` are given, `rho_star` or `M_star` cannot be defined") KeplerianOrbit(
        rho_star=2.0,
        R_star=0.5, a=7.5, period=2.0, t_0=0.0, incl=π/2.0, Omega=0.0, omega=0.0, ecc=0.0,
    )
    @test_throws ArgumentError("If both `a` and `P` are given, `rho_star` or `M_star` cannot be defined") KeplerianOrbit(
        M_star=1.0,
        R_star=0.5, a=7.5, period=2.0, t_0=0.0, incl=π/2.0, Omega=0.0, omega=0.0, ecc=0.0,
    )
    @test_throws ArgumentError("Must provide exactly two of: `rho_star`, `R_star`, or `M_star` if rho_star not implied") KeplerianOrbit(
        R_star=0.5,
        period=2.0, t_0=0.0, incl=π/2.0, Omega=0.0, omega=0.0, ecc=0.0,
    )
    @test_throws ArgumentError("Must provide exactly two of: `rho_star`, `R_star`, or `M_star` if rho_star not implied") KeplerianOrbit(
        M_star=0.5,
        period=2.0, t_0=0.0, incl=π/2.0, Omega=0.0, omega=0.0, ecc=0.0,
    )
    @test_throws ArgumentError("Must provide exactly two of: `rho_star`, `R_star`, or `M_star` if rho_star not implied") KeplerianOrbit(
        M_star=0.5, R_star=0.5, rho_star=0.5,
        period=2.0, t_0=0.0, incl=π/2.0, Omega=0.0, omega=0.0, ecc=0.0,
    )
end

@testset "KeplerianOrbit: implied inputs" begin
    # R_star ≡ 1.0 R⊙ if not specified
    orbit_no_R_star = KeplerianOrbit(
        rho_star=2.0, period=2.0, t_0=0.0,
        incl=π/2.0, Omega=0.0, omega=0.0, ecc=0.0
    )
    @test orbit_no_R_star.R_star == one(orbit_no_R_star.a)

    # Compute M_tot if `a` and `period` given
    orbit_a_period = KeplerianOrbit(
        a=1.0, period=1.0, t_0=0.0,
        incl=π/2.0, Omega=0.0, omega=0.0, ecc=0.0
    )
    @test orbit_a_period.M_planet + orbit_a_period.M_star == 4.0 * π^2 / G_nom

    # Compute `R_star` from `M_star`
    orbit_M_star = KeplerianOrbit(
        M_star=4.0*π, rho_star = 1.0, period = 2.0, t_0 = 0.0,
        incl = π / 2.0, Omega = 0.0, omega = 0.0, ecc = 0.0
    )
    @test orbit_M_star.R_star == 3.0^(1/3)
end

@testset "KeplerianOrbit: small star" begin
    # Sample model from `Transits.jl`
    orbit = KeplerianOrbit(
        R_star = 0.189,
        M_star = 0.151,
        period =  0.4626413,
        t_0 = 0.2,
        b = 0.5,
        ecc = 0.1,
        omega = 0.1,
    )

    # Comparison coords from `batman`
    small_star = load("./python_code/test_data/KeplerianOrbit_small_star.jld2")

    # Compare
    t = small_star["t"]
    r_batman = small_star["r_batman"]
    m = small_star["m"]
    r = compute_r(orbit, t)
    @test sum(m) > 0
    @test allclose(r_batman[m], r[m], atol=2e-5)
end

@testset "KeplerianOrbit: impact" begin
    # Sample model from `Transits.jl`
    orbit = KeplerianOrbit(
        R_star = 0.189,
        M_star = 0.151,
        P = 0.4626413,
        t_0 = 0.2,
        b = 0.5,
        ecc = 0.8,
        omega = 0.1,
    )

    pos = relative_position.(orbit, orbit.t0)
    @test allclose(hypot(pos[1], pos[2]), orbit.b)
end

@testset "KeplerianOrbit: flip" begin
    orbit = KeplerianOrbit(
        M_star = 1.3,
        R_star = 1.1,
        t_0 = 0.5,
        period = 100.0,
        ecc = 0.3,
        incl = 0.25*π,
        omega = 0.5,
        Omega = 1.0,
        M_planet = 0.1,
    )

    orbit_flipped = flip(orbit, 0.7)

    t = range(0, 100; length=1_000)

    u_star = as_matrix(_star_position.(orbit, orbit.R_star, t))
    u_planet_flipped = as_matrix(_planet_position.(orbit_flipped, orbit.R_star, t))
    for i in 1:3
        @test allclose(u_star[:, i], u_planet_flipped[:, i], atol=1e-5)
    end

    u_planet = as_matrix(_planet_position.(orbit, orbit.R_star, t))
    u_star_flipped = as_matrix(_star_position.(orbit_flipped, orbit.R_star, t))
    for i in 1:3
        @test allclose(u_planet[:, i], u_star_flipped[:, i], atol=1e-5)
    end
end

@testset "KeplerianOrbit: flip circular" begin
    t = range(0, 100; length=1_000)

    orbit = KeplerianOrbit(
        M_star = 1.3,
        M_planet = 0.1,
        R_star = 1.0,
        P = 100.0,
        t_0 = 0.5,
        incl = 45.0,
        ecc = 0.0,
        omega = 0.5,
        Omega = 1.0
    )
    orbit_flipped = flip(orbit, 0.7)

    u_star = as_matrix(_star_position.(orbit, orbit.R_star, t))
    u_planet_flipped = as_matrix(_planet_position.(orbit_flipped, orbit.R_star, t))
    for i in 1:3
        @test allclose(u_star[:, i], u_planet_flipped[:, i], atol=1e-5)
    end

    u_planet = as_matrix(_planet_position.(orbit, orbit.R_star, t))
    u_star_flipped = as_matrix(_star_position.(orbit_flipped, orbit.R_star, t))
    for i in 1:3
        @test allclose(u_planet[:, i], u_star_flipped[:, i], atol=1e-5)
    end
end

@testset "KeplerianOrbit: compute_aor" begin
    duration = 0.12
    period = 10.1235
    b = 0.34
    r = 0.06
    R_star = 0.7
    aor = compute_aor(duration, period, b, r=r)

    for orbit in [
        KeplerianOrbit(
            period=period, t_0=0.0, b=b, a=R_star * aor, R_star=R_star
        ),
        KeplerianOrbit(
            period = period,
            t_0 = 0.0,
            b = b,
            duration = duration,
            R_star = R_star,
            r = r,
        ),
        ]

        x, y, z = _planet_position(orbit, R_star, 0.5*duration)
        @test allclose(hypot(x, y), 1.0 + r)
        x, y, z = _planet_position(orbit, R_star, -0.5*duration)
        @test allclose(hypot(x, y), 1.0 + r)
        x, y, z = _planet_position(orbit, R_star, period + 0.5*duration)
        @test allclose(hypot(x, y), 1.0 + r)
    end
end

@testset "KeplerianOrbit: stringify_units" begin
    #@test stringify_units(1u"Rsun", "Rsun") == "1 R⊙"
    @test stringify_units(1, "R⊙") == "1.0000 R⊙"
end

@testset "KeplerianOrbit: unit conversions" begin
    orbit = KeplerianOrbit(a=12.0, t_0=0.0, b=0.0, R_star=1.0, M_star=1.0, M_planet=0.01, r=0.01)
    rho_planet_1 = orbit.rho_planet*u"Msun/Rsun^3" |> u"g/cm^3"
    rho_planet_2 = orbit.rho_planet * MsunRsun_to_gcc
    @test rho_planet_1.val == rho_planet_2

    orbit = KeplerianOrbit(a=12.0u"Rsun", t_0=0.0u"d", b=0.0, R_star=1.0u"Rsun", M_star=1.0u"Msun")
    @test isnan(orbit.rho_planet)

    orbit = KeplerianOrbit(a=12.0u"Rsun", t_0=0.0u"d", b=0.0, R_star=1.0u"Rsun", M_planet=0.01u"Msun", M_star=1.0u"Msun", r=0.01)
    rho_planet = orbit.rho_planet |> u"g/cm^3"
    rho_star = orbit.rho_star |> u"g/cm^3"
    @test rho_planet.val == orbit.rho_planet.val*MsunRsun_to_gcc
    @test rho_star.val == orbit.rho_star.val*MsunRsun_to_gcc
end

@testset "KeplerianOrbit: aliased kwargs" begin
    orbit_standard_1 = KeplerianOrbit(a=12.0, t_0=0.0, b=0.0, R_star=1.0, M_star=1.0, M_planet=0.01, r=0.01)
    orbit_kwarg_alias_1 = KeplerianOrbit(a=12.0, t0=0.0, b=0.0, Rs=1.0, Ms=1.0, Mp=0.01, RpRs=0.01)
    @test orbit_standard_1 === orbit_kwarg_alias_1

    orbit_standard_2 = KeplerianOrbit(
        rho_star = 2.0, R_star = 0.5, period = 2.0, ecc = 0.0, t_0 = 0.0,
        incl = π / 2.0, Omega = 0.0, omega = 0.0,
    )
    orbit_kwarg_alias_2 = KeplerianOrbit(
        ρ_star = 2.0, Rs = 0.5, P = 2.0, e = 0.0, t0 = 0.0,
        incl = π / 2.0, Ω = 0.0, ω = 0.0,
    )
    @test orbit_standard_2 === orbit_kwarg_alias_2
end
