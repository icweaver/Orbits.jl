### A Pluto.jl notebook ###
# v0.14.4

using Markdown
using InteractiveUtils

# ╔═╡ fe341026-7278-11eb-2490-0f2ffdeae45e
begin
	using Revise
	import Pkg
	Pkg.activate("..")
	Pkg.instantiate()
	using PlutoUI
	using StatsPlots
	using Transits
	using Unitful
	using UnitfulAstro
	using BenchmarkTools
end

# ╔═╡ bef5c239-6f93-4377-9fd8-37400c52b3ea
using KeywordCalls

# ╔═╡ 29f28a74-77f8-11eb-2b70-dd1462a347fc
TableOfContents(depth=6)

# ╔═╡ bddb767e-77f8-11eb-2692-ad86467f0c81
md"## Unitless examples"

# ╔═╡ e54167b0-55f3-426a-b7ac-a93e8565297f
begin
	make_orbit_ρₛ() = KeplerianOrbit((
		ρₛ = 2.0,
		Rₛ = 0.5,
		P = 2.0,
		ecc = 0.0,
		t₀ = 0.0,
		incl = π / 2.0,
		#b = 0.0,
		Ω = 0.0,
		ω = 0.0,
	))
	
	make_orbit_ρₛ_KC() = KeplerianOrbit_KC(
		ρₛ = 2.0,
		Rₛ = 0.5,
		P = 2.0,
		ecc = 0.0,
		t₀ = 0.0,
		incl = π / 2.0,
		#b = 0.0,
		Ω = 0.0,
		ω = 0.0,
	)
	
	make_orbit_ρₛ_KD() = KeplerianOrbit_KD(
		ρₛ = 2.0,
		Rₛ = 0.5,
		P = 2.0,
		ecc = 0.0,
		t₀ = 0.0,
		incl = π / 2.0,
		#b = 0.0,
		Ω = 0.0,
		ω = 0.0,
	)
	
	orbit_ρₛ,
	orbit_ρₛ_KC,
	orbit_ρₛ_KD = make_orbit_ρₛ(), make_orbit_ρₛ_KC(), make_orbit_ρₛ_KD()
end

# ╔═╡ a6af8efb-ae5e-4f5c-af72-a8687d9bac29
make_orbit_aRₛ() = KeplerianOrbit((
	aRₛ = 7.5,
	P = 2.0,
	incl = π / 2.0,
	# b = 0.0,
	t₀ = 0.0,
	ecc = 0.0,
	Ω = 0.0,
	ω = 0.0,
))

# ╔═╡ 5825aaca-dfb7-4fdd-9dd5-992990b00276
f(nt::NamedTuple{(:a, :b)}) = nt.a, nt.b

# ╔═╡ 5455123b-0757-4bd0-9298-78fa800b705b
f(nt::NamedTuple{(:α, :β)}) = nt.α, nt.β

# ╔═╡ 8e69af99-fc97-4273-9a0d-ff087b37b8a9
@kwcall f(a, b)

# ╔═╡ 0b635f09-3256-4a09-9bf3-e650b160d68d
@kwcall f(α, β)

# ╔═╡ 6e876947-3dfb-4b39-be94-800c71fa3845
f(a=1, b=2)

# ╔═╡ d9901424-d32a-48b7-a506-1cf6a1792606
f(α=1, β=2)

# ╔═╡ f0c2b1b2-b851-4f00-8899-6cf871c190d5
make_orbit_aRₛ()

# ╔═╡ 497322b7-5ff9-4699-8d98-677db5a14061
orbit_aRₛ = make_orbit_aRₛ()

# ╔═╡ b7eb5e36-b4a2-43a8-934d-b76adb794f9f
with_terminal() do
	@btime make_orbit_ρₛ()
	@btime make_orbit_ρₛ_KC()
	@btime make_orbit_ρₛ_KD()
end

# ╔═╡ 5274fb9f-999c-440a-aad2-ce5356157b34
md"""
## Light curves
"""

# ╔═╡ 1a94a407-7a09-4c5f-8796-2570d41ddb4d
t = -3:0.01:3 # days

# ╔═╡ f8b8bf9b-e667-4c9c-9eb3-126d9b5e71a2
u = [0.4, 0.26] # Quadratic LD coeffs

# ╔═╡ 638405b7-0f1e-4eb1-85d6-d17dc04f8699
ld = PolynomialLimbDark(u)

# ╔═╡ 18e62e17-79e0-4586-bfa1-e837c1f17368
fluxes_ρₛ = @. ld(orbit_ρₛ, t, 0.2)

# ╔═╡ 83e060ef-d17d-4561-9808-67a4146642c7
fluxes_aRₛ = @. ld(orbit_aRₛ, t, 0.2)

# ╔═╡ eb9d7c0c-0790-466c-a722-06c9b41b96cd
begin
	p = plot(xlabel="Time (days)", ylabel="Relative flux")
	plot!(p, t, fluxes_ρₛ, lw=5, label="ρₛ")
	plot!(p, t, fluxes_aRₛ, label="aRₛ")
end

# ╔═╡ Cell order:
# ╟─29f28a74-77f8-11eb-2b70-dd1462a347fc
# ╟─bddb767e-77f8-11eb-2692-ad86467f0c81
# ╠═e54167b0-55f3-426a-b7ac-a93e8565297f
# ╠═a6af8efb-ae5e-4f5c-af72-a8687d9bac29
# ╠═bef5c239-6f93-4377-9fd8-37400c52b3ea
# ╠═5825aaca-dfb7-4fdd-9dd5-992990b00276
# ╠═5455123b-0757-4bd0-9298-78fa800b705b
# ╠═8e69af99-fc97-4273-9a0d-ff087b37b8a9
# ╠═0b635f09-3256-4a09-9bf3-e650b160d68d
# ╠═6e876947-3dfb-4b39-be94-800c71fa3845
# ╠═d9901424-d32a-48b7-a506-1cf6a1792606
# ╠═f0c2b1b2-b851-4f00-8899-6cf871c190d5
# ╠═497322b7-5ff9-4699-8d98-677db5a14061
# ╠═b7eb5e36-b4a2-43a8-934d-b76adb794f9f
# ╟─5274fb9f-999c-440a-aad2-ce5356157b34
# ╠═1a94a407-7a09-4c5f-8796-2570d41ddb4d
# ╠═f8b8bf9b-e667-4c9c-9eb3-126d9b5e71a2
# ╠═638405b7-0f1e-4eb1-85d6-d17dc04f8699
# ╠═18e62e17-79e0-4586-bfa1-e837c1f17368
# ╠═83e060ef-d17d-4561-9808-67a4146642c7
# ╠═eb9d7c0c-0790-466c-a722-06c9b41b96cd
# ╠═fe341026-7278-11eb-2490-0f2ffdeae45e
