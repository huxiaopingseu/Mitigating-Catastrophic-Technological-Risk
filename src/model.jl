# =============================================================================
#  Model code for "Mitigating Catastrophic Technological Risk under Information
#  Asymmetry: A Signaling Game and Agent-Based Network Approach to Battery
#  Thermal Runaway"
#
#  Part 1 (micro):  a Spence-style signaling game with a prospect-theory
#                   (loss-averse) consumer and a separating equilibrium.
#  Part 2 (macro):  an agent-based panic-cascade on a scale-free social network
#                   with KOL influence amplification, trust-repair compensation,
#                   and a percolation phase transition.
# =============================================================================

module RiskModel

using Graphs
using Random
using Statistics

export MicroParams, MacroParams, WTP, profit, barp, delta_risk,
       separating_bounds, mimicry_threshold, single_crossing,
       run_cascade, steady_resilience, estimate_Q, theoretical_pcrit,
       S_, I_, R_

# -----------------------------------------------------------------------------
#  MICRO — signaling game with a loss-averse consumer
# -----------------------------------------------------------------------------

mutable struct MicroParams
    V::Float64      # intrinsic use value of the vehicle
    c::Float64      # marginal production cost
    λ::Float64      # loss-aversion coefficient (prospect theory)
    L::Float64      # total physical + psychological loss from a runaway
    φ::Float64      # efficiency with which compensation offsets loss
    pH::Float64     # runaway probability, high-safety type
    pL::Float64     # runaway probability, low-safety type
    q::Float64      # prior probability P(θ = H)
    δ::Float64      # dread multiplier (probability overweighting), δ ≥ 1
end

# Posterior *objective* runaway probability under belief μ = P(θ = H).
barp(μ, P::MicroParams) = μ * P.pH + (1 - μ) * P.pL

# Posterior *perceived* runaway probability: the consumer overweights the rare
# catastrophic event by the dread multiplier δ (prospect-theory probability
# weighting to first order).
perceived_barp(μ, P::MicroParams) = P.δ * barp(μ, P)

# Consumer willingness-to-pay for guarantee level w ∈ [0,1] under belief μ.
WTP(w, μ, P::MicroParams) = P.V - perceived_barp(μ, P) * (1 - P.φ * w) * P.λ * P.L

# Firm profit for type θ (∈ {:H, :L}), guarantee w, belief μ, liability C.
# The firm is rational: its expected payout uses the objective rate p_θ.
function profit(θ::Symbol, w, μ, P::MicroParams, C)
    pθ = θ === :H ? P.pH : P.pL
    WTP(w, μ, P) - P.c - pθ * w * C
end

# Information rent from mimicking the high-safety signal.
delta_risk(P::MicroParams) = P.δ * (P.pL - (1 - P.φ) * P.pH) * P.λ * P.L

# Separating-equilibrium liability interval [C_min, C_max].
function separating_bounds(P::MicroParams)
    Δ = delta_risk(P)
    return (Δ / P.pL, Δ / P.pH)
end

# Mimicry threshold p_L^* = δ p_H (1-φ) λL / (δ λL - C), valid when C < δ λL.
mimicry_threshold(P::MicroParams, C) = P.δ * P.pH * (1 - P.φ) * P.λ * P.L / (P.δ * P.λ * P.L - C)

# Single-crossing derivative ∂²Π/∂w∂p_θ = -C < 0.
single_crossing(C) = -C

# -----------------------------------------------------------------------------
#  MACRO — agent-based panic cascade on a social network
# -----------------------------------------------------------------------------

struct MacroParams
    p::Float64      # per-step spontaneous thermal-runaway (incident) rate
    γ::Float64      # perception memory (update) rate
    α::Float64      # KOL influence amplification exponent
    wp::Float64     # panic-node contagion weight relative to a churned node
    σ::Float64      # compensation (trust-repair) intensity
    D::Float64      # information-distortion index (0 = transparent, 1 = opaque)
    τ0::Float64     # base tolerance threshold
    qP::Float64     # P(S→I) when over threshold (else S→R)
    r::Float64      # recovery threshold ratio (I→S when μ ≤ r·τ)
    qC::Float64     # P(I→R) per step when not recovering
    target_kol::Bool
    kol_frac::Float64
    κ::Float64      # extra compensation multiplier for targeted KOLs
end

const S_ = 0   # susceptible / active owner
const I_ = 1   # infected  / panicking owner
const R_ = 2   # removed   / churned owner (absorbing)

"""
    run_cascade(g, mp; T, rng)

Simulate one panic cascade. Returns `(resilience_trajectory, final_states, ks, kbar)`
where `resilience_trajectory[t]` is the active-owner fraction after step `t`.
"""
function run_cascade(g::AbstractGraph, mp::MacroParams; T::Int, rng::AbstractRNG)
    N = nv(g)
    ks = degree(g)
    kbar = mean(ks)

    # Heterogeneous risk aversion + micro-macro threshold mapping
    ρ = rand(rng, N)
    τ = mp.τ0 .* (1.0 .- ρ .* mp.D)

    # KOLs: the top kol_frac nodes by degree
    nk = max(1, round(Int, mp.kol_frac * N))
    kols = sortperm(ks, rev = true)[1:nk]
    iskol = falses(N); iskol[kols] .= true

    # Neighbour lists and influence weights w_ij = (k_j / <k>)^α
    nbrs = [collect(neighbors(g, i)) for i in 1:N]
    wv(j) = (ks[j] / kbar)^mp.α
    wsum = [sum((wv(j) for j in nbrs[i]), init = 0.0) for i in 1:N]

    state = zeros(Int, N)
    μ = zeros(N)
    resil = Float64[]

    for t in 1:T
        push!(resil, count(x -> x == S_, state) / N)
        ns = copy(state)
        for i in 1:N
            state[i] == R_ && continue
            # (Rule 1) spontaneous thermal-runaway incident
            if rand(rng) < mp.p
                ns[i] = R_
                continue
            end
            # (Rule 2) weighted activated-neighbour fraction (panic cascade)
            #   a churned neighbour (R) contributes full weight, a panicking
            #   neighbour (I) contributes a damped weight w_p.
            num = 0.0
            for j in nbrs[i]
                state[j] == R_ && (num += wv(j))
                state[j] == I_ && (num += mp.wp * wv(j))
            end
            expo = wsum[i] > 0.0 ? num / wsum[i] : 0.0
            μi = (1 - mp.γ) * μ[i] + mp.γ * expo
            # (Rule 3) trust-repair compensation, boosted for targeted KOLs
            σeff = mp.σ
            (mp.target_kol && iskol[i]) && (σeff *= (1 + mp.κ))
            μadj = max(0.0, μi - σeff)
            μ[i] = μi
            # (Rule 4) threshold transition
            if state[i] == S_
                if μadj > τ[i]
                    ns[i] = rand(rng) < mp.qP ? I_ : R_
                end
            elseif state[i] == I_
                if μadj <= mp.r * τ[i]
                    ns[i] = S_                 # trust repaired
                elseif rand(rng) < mp.qC
                    ns[i] = R_                 # permanent defection
                end
            end
        end
        state .= ns
    end
    return resil, state, ks, kbar
end

# Steady-state resilience (active-owner fraction at the horizon).
steady_resilience(resil) = resil[end]

"""
    estimate_Q(g, mp; nboot, rng)

Mean-field estimate of the edge transmission probability Q = P(a node activates
given a single activated neighbour). Starting from zero perception, a single
activated neighbour j contributes exposure w_j / Σ w, which becomes
μ = γ·(w_j/Σw); the node activates if μ - σ_eff > τ.
"""
function estimate_Q(g::AbstractGraph, mp::MacroParams; nboot::Int, rng::AbstractRNG)
    N = nv(g)
    ks = degree(g)
    kbar = mean(ks)
    wv(j) = (ks[j] / kbar)^mp.α
    nk = max(1, round(Int, mp.kol_frac * N))
    kols = sortperm(ks, rev = true)[1:nk]
    iskol = falses(N); iskol[kols] .= true
    nbrs = [collect(neighbors(g, i)) for i in 1:N]
    wsum = [sum((wv(j) for j in nbrs[i]), init = 0.0) for i in 1:N]

    cnt = 0
    n = 0
    for i in 1:N
        isempty(nbrs[i]) && continue
        n += 1
        j = rand(rng, nbrs[i])
        expo = wsum[i] > 0.0 ? wv(j) / wsum[i] : 0.0
        σeff = mp.σ
        (mp.target_kol && iskol[i]) && (σeff *= (1 + mp.κ))
        μadj = max(0.0, mp.γ * expo - σeff)
        ρi = rand(rng)
        τi = mp.τ0 * (1.0 - ρi * mp.D)
        (μadj > τi) && (cnt += 1)
    end
    return cnt / n
end

"""
    theoretical_pcrit(g, mp; nboot, rng)

Mean-field / branching-process critical incident rate. The effective per-edge
transmission probability is T_eff(p) = p + (1-p)Q, and a giant panic component
emerges when R0 = T_eff · (<k²-k>/<k>) > 1. Hence

    p_crit = (T_c - Q) / (1 - Q),   T_c = <k> / <k² - k>.
"""
function theoretical_pcrit(g::AbstractGraph, mp::MacroParams; nboot::Int, rng::AbstractRNG)
    ks = degree(g)
    kbar = mean(ks)
    Tc = kbar / (mean(ks .^ 2) - kbar)
    Q = estimate_Q(g, mp; nboot = nboot, rng = rng)
    pcrit = (Tc - Q) / (1.0 - Q)
    return (pcrit = pcrit, Tc = Tc, Q = Q, kbar = kbar, k2bar = mean(ks .^ 2))
end

end # module
