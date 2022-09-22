using RecipesBase: apply_recipe

@testset "KeplerianOrbit plotting" begin
    b_aR_star = KeplerianOrbit(
        aR_star = 7.5,
        P = 2.0,
        incl = π / 2.0,
        t0 = 0.0,
        ecc = 0.0,
        Omega = 0.0,
        omega = 0.0,
    )
    recipes = apply_recipe(Dict{Symbol,Any}(), b_aR_star)
    for rec in recipes
        @test getfield(rec, 1) ==
              Dict{Symbol,Any}(:seriestype => :line, :xguide => "Δx", :yguide => "Δy")

        x = rec.args[1]
        y = rec.args[2]

        @test length(x) == length(y)
    end
end
@testset "KeplerianOrbit plotting with units" begin
    b_rho_star_units = KeplerianOrbit(
        rho_star = 2.0u"g/cm^3",
        R_star = 0.5u"Rsun",
        period = 2.0u"d",
        ecc = 0.0,
        t0 = 0.0u"d",
        incl = 90.0u"°",
        Omega = 0.0u"°",
        omega = 0.0u"°",
    )

    recipes = apply_recipe(Dict{Symbol,Any}(), b_rho_star_units)
    for rec in recipes
        @test getfield(rec, 1) ==
              Dict{Symbol,Any}(:seriestype => :line, :xguide => "Δx", :yguide => "Δy")

        x = rec.args[1]
        y = rec.args[2]

        @test length(x) == length(y)
    end
end
