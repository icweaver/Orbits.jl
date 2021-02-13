
using StaticArrays

struct QuadLimbDark{T,VT <: StaticVector{3,T}} <: AbstractLimbDark
    n_max::Int
    u_n::VT
    g_n::VT
    norm::T
end

@doc raw"""
    QuadLimbDark(u::AbstractVector)
"""
function QuadLimbDark(u::AbstractVector{T}) where T
    n_max = length(u)
    # add constant u_0 term
    if n_max == 0
        u_n = SA[-one(T), zero(T), zero(T)]
    elseif n_max == 1
        u_n = SA[-one(T), only(u), zero(T)]
    else
        u_n = SA[-one(T), u[begin], u[begin + 1]]
    end

    # get Green's basis coefficients
    g_n = compute_gn(u_n)

    # calculate flux normalization factor, which only depends on first two terms
    norm = inv(π * (g_n[begin] + 2/3 * g_n[begin + 1]))

    return QuadLimbDark(n_max, u_n, g_n, norm)
end

function compute(ld::QuadLimbDark, b::T, r) where T

    ## check for trivial cases
    if b ≥ 1 + r || iszero(r)
        # completely unobscured
        return one(T)
    elseif r ≥ 1 + b
        # completely obscured
        return zero(T)
    end

    r2 = r^2
    b2 = b^2

    if iszero(b)
        onemr2 = 1 - r2
        sqrt1mr2 = sqrt(onemr2)

        # annular ellipse
        flux = ld.g_n[begin] * onemr2 + 2/3 * ld.g_n[begin + 1] * sqrt1mr2^3
        if ld.n_max > 1
            flux -= ld.g_n[begin + 2] * 2 * r2 * onemr2
        end
        return flux * π * ld.norm
    end

    # take a moment to calculate values used repeatedly in the
    # numerical routines ahead
    onembmr2 = (r + 1 - b) * (1 - r + b)
    onembmr2inv = inv(onembmr2)
    sqonembmr2 = sqrt(onembmr2)
    br = b * r
    fourbr = 4 * br
    fourbrinv = inv(fourbr)
    sqbr = sqrt(br)
    sqbrinv = inv(sqbr)
    onembpr2 = (1 - r - b) * (1 + b + r)
    sqarea = sqarea_triangle(one(T), r, b)
    k2 = max(0, onembpr2 * fourbrinv + 1)
    k = sqrt(k2)
    onemr2mb2 = (1 - r) * (1 + r) - b2
    onemr2pb2 = (1 - r) * (1 + r) + b2
    if k2 > 1
        if k2 > 2
            kc2 = 1 - inv(k2)
        else
            kc2 = onembpr2 * onembmr2inv
        end
    else
        if k2 > 0.5
            kc2 = (r - 1 + b) * (b + r + 1) * fourbrinv
        else
            kc2 = 1 - k2
        end
    end
    kc = sqrt(kc2)

    ## Compute uniform term
    s0, kap0, kite_area2, kck = compute_uniform(b, r; b2, r2, sqarea, fourbrinv)

    flux = ld.g_n[begin] * s0

    if ld.n_max == 0
        return flux * ld.norm
    end

    ## compute linear term
    s1, Eofk, Em1mKdm = compute_linear(b, r; k2, kc, kc2, r2, b2, br, fourbr, sqbr, onembmr2, onembpr2, onembmr2inv)

    flux += ld.g_n[begin + 1] * s1

    if ld.n_max == 1
        return flux * ld.norm
    end

    ## calculate quadratic term
    s2 = compute_quadratic(b, r; s0, r2, b2, kap0, kite_area2, k2)
    flux += ld.g_n[begin + 2] * s2

    return flux * ld.norm
end

function compute_gn(u_n::StaticVector{3,T}) where T
    g_0 = 1 - u_n[begin + 1] - 1.5 * u_n[begin + 2]
    g_1 = u_n[begin + 1] + 2 * u_n[begin + 2]
    g_2 = -0.25 * u_n[begin + 2]
    return SA[g_0, g_1, g_2]
end