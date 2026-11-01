# =============================================================================
#  Experiment driver — runs all micro (signaling game) and macro (ABM cascade)
#  experiments and writes results to results/*.csv.
# =============================================================================

include("src/model.jl")
using .RiskModel
using Graphs, Random, Statistics, DelimitedFiles

const OUT = "results"
mkpath(OUT)

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
writecsv(name, header, rows) = begin
    open(joinpath(OUT, name), "w") do io
        println(io, join(header, ","))
        for r in rows
            println(io, join(string.(r), ","))
        end
    end
end

# empirical critical incident rate: smallest p where mean active fraction < 0.5
function empirical_pcrit(ps, actives)
    for k in 1:length(ps)
        actives[k] < 0.5 && return ps[k]
    end
    return NaN
end

# ---------------------------------------------------------------------------
# MICRO experiments
# ---------------------------------------------------------------------------
println("=== MICRO: signaling game ===")
P = MicroParams(30.0, 18.0, 2.25, 40.0, 0.7, 0.005, 0.05, 0.5, 2.5)

# (1) baseline equilibrium
Cmin, Cmax = separating_bounds(P)
Δ = delta_risk(P)
wtp_H = WTP(1.0, 1.0, P)
wtp_L = WTP(0.0, 0.0, P)
profit_H_sig = profit(:H, 1.0, 1.0, P, 200.0)
profit_H_nosig = profit(:H, 0.0, 0.0, P, 200.0)
profit_L_nosig = profit(:L, 0.0, 0.0, P, 200.0)
profit_L_mimic = profit(:L, 1.0, 1.0, P, 200.0)
println("  C_min=", round(Cmin,digits=3), " C_max=", round(Cmax,digits=3),
        " Δ_risk=", round(Δ,digits=3))
println("  WTP(H-signal)=", round(wtp_H,digits=3), " WTP(L)=", round(wtp_L,digits=3),
        " premium=", round(wtp_H-wtp_L,digits=3))
println("  Π_H(w=1)=", round(profit_H_sig,digits=3), " Π_H(w=0)=", round(profit_H_nosig,digits=3),
        " Π_L(w=0)=", round(profit_L_nosig,digits=3), " Π_L(w=1,mimic)=", round(profit_L_mimic,digits=3))
writecsv("micro_baseline.csv",
    ["quantity","value"],
    [["V",P.V],["c",P.c],["lambda",P.λ],["delta",P.δ],["L",P.L],["phi",P.φ],
     ["p_H",P.pH],["p_L",P.pL],["q",P.q],
     ["Delta_risk",Δ],["C_min",Cmin],["C_max",Cmax],
     ["WTP_H",wtp_H],["WTP_L",wtp_L],["price_premium",wtp_H-wtp_L],
     ["Pi_H_signal",profit_H_sig],["Pi_H_nosig",profit_H_nosig],
     ["Pi_L_nosig",profit_L_nosig],["Pi_L_mimic",profit_L_mimic]])

# (2) lambda sweep -> C_min, C_max  (Proposition 2)
rows = Any[["lambda","C_min","C_max","interval_width"]]
for λ in 1.0:0.25:4.0
    Pλ = MicroParams(P.V,P.c,λ,P.L,P.φ,P.pH,P.pL,P.q,P.δ)
    lo, hi = separating_bounds(Pλ)
    push!(rows, [λ, lo, hi, hi-lo])
end
writecsv("micro_lambda_sweep.csv", rows[1], rows[2:end])

# (3) phi sweep -> C_min, C_max
rows = Any[["phi","C_min","C_max"]]
for φ in 0.0:0.05:1.0
    Pφ = MicroParams(P.V,P.c,P.λ,P.L,φ,P.pH,P.pL,P.q,P.δ)
    lo, hi = separating_bounds(Pφ)
    push!(rows, [φ, lo, hi])
end
writecsv("micro_phi_sweep.csv", rows[1], rows[2:end])

# (4) mimicry threshold p* vs C  (Proposition 3), valid for C < δλL
rows = Any[["C","p_star"]]
for C in range(0.0, P.δ*P.λ*P.L, length=200)
    C >= P.δ*P.λ*P.L - 1e-9 && continue
    push!(rows, [C, mimicry_threshold(P, C)])
end
writecsv("micro_mimicry.csv", rows[1], rows[2:end])

# (4b) dread (δ) sweep -> C_min, C_max  (Proposition on probability overweighting)
rows = Any[["delta","C_min","C_max","interval_width"]]
for δ in 1.0:0.25:4.0
    Pδ = MicroParams(P.V,P.c,P.λ,P.L,P.φ,P.pH,P.pL,P.q,δ)
    lo, hi = separating_bounds(Pδ)
    push!(rows, [δ, lo, hi, hi-lo])
end
writecsv("micro_delta_sweep.csv", rows[1], rows[2:end])

# (4c) micro one-way sensitivity: p_H, p_L, λ, δ, φ -> C_min, C_max
rows = Any[["parameter","low","baseline","high","Cmin_low","Cmin_high","Cmax_low","Cmax_high"]]
for (name, lo, hi, field) in [
        ("dread δ", 1.0, 4.0, :δ),
        ("loss aversion λ", 1.5, 3.0, :λ),
        ("offset efficiency φ", 0.4, 1.0, :φ),
        ("runaway rate p_H", 0.002, 0.01, :pH),
        ("runaway rate p_L", 0.03, 0.08, :pL)]
    mk(v) = begin
        Px = MicroParams(P.V,P.c,P.λ,P.L,P.φ,P.pH,P.pL,P.q,P.δ)
        setproperty!(Px, field, v); Px
    end
    Pl, Ph = mk(lo), mk(hi)
    cll, clh = separating_bounds(Pl)
    chl, chh = separating_bounds(Ph)
    push!(rows, [name, lo, getproperty(P, field), hi, cll, chl, clh, chh])
end
writecsv("micro_sensitivity.csv", rows[1], rows[2:end])

# (5) single-crossing: profit vs w for H and L at C=200
rows = Any[["w","Pi_H","Pi_L"]]
for w in 0.0:0.02:1.0
    push!(rows, [w, profit(:H,w,1.0,P,200.0), profit(:L,w,1.0,P,200.0)])
end
writecsv("micro_single_crossing.csv", rows[1], rows[2:end])

# ---------------------------------------------------------------------------
# MACRO experiments
# ---------------------------------------------------------------------------
println("\n=== MACRO: agent-based cascade ===")
N = 3000
m = 3
Random.seed!(42)                 # deterministic network generation
g_ba = barabasi_albert(N, m)
g_ws = watts_strogatz(N, 6, 0.1)
g_er = erdos_renyi(N, 6.0/N)
T = 60
nseeds = 5

# scenario set: (label, D, σ, targeting)
scenarios = [
    ("opaque_no_comp",   0.8, 0.0, false),
    ("transparent_no_comp", 0.2, 0.0, false),
    ("opaque_comp",      0.8, 0.3, false),
    ("transparent_comp_KOL", 0.2, 0.3, true),
]

# (6) trajectories (resilience vs time) for the 4 scenarios at p=0.008
println("  trajectories (p=0.008)...")
p0 = 0.008
trows = Dict{String,Vector{Float64}}()
for (label, D, σ, tgt) in scenarios
    mp = MacroParams(p0, 0.3, 1.5, 0.6, σ, D, 0.7, 0.65, 0.4, 0.25, tgt, 0.05, 1.0)
    acc = zeros(T)
    for s in 1:nseeds
        r, _, _, _ = run_cascade(g_ba, mp; T=T, rng=MersenneTwister(100+s))
        acc .+= r
    end
    trows[label] = acc ./ nseeds
end
open(joinpath(OUT, "macro_trajectories.csv"), "w") do io
    println(io, "t," * join([l for (l,_,_,_) in scenarios], ","))
    for t in 1:T
        println(io, join([t; [trows[l][t] for (l,_,_,_) in scenarios]], ","))
    end
end

# (7) phase transition: resilience vs p for the 4 scenarios
println("  phase transition...")
ps = range(0.001, 0.02, length=24) |> collect
# build matrix: p x scenarios x seeds
pmat = Dict{Tuple{Float64,String},Vector{Float64}}()
for (label, D, σ, tgt) in scenarios, p in ps
    mp = MacroParams(p, 0.3, 1.5, 0.6, σ, D, 0.7, 0.65, 0.4, 0.25, tgt, 0.05, 1.0)
    vals = [steady_resilience(run_cascade(g_ba, mp; T=T, rng=MersenneTwister(200+s))[1]) for s in 1:nseeds]
    pmat[(p,label)] = vals
end
open(joinpath(OUT, "macro_phase_transition.csv"), "w") do io
    println(io, "p," * join([l for (l,_,_,_) in scenarios], ","))
    for p in ps
        println(io, join([p; [mean(pmat[(p,l)]) for (l,_,_,_) in scenarios]], ","))
    end
end
# also per-scenario mean+std for error reporting
open(joinpath(OUT, "macro_phase_transition_std.csv"), "w") do io
    println(io, "p,label,mean,std")
    for (label,_,_,_) in scenarios, p in ps
        v = pmat[(p,label)]
        println(io, join([p, label, mean(v), std(v)], ","))
    end
end
# empirical p_crit for each scenario
pcs = Dict{String,Float64}()
for (label,_,_,_) in scenarios
    means = [mean(pmat[(p,label)]) for p in ps]
    pcs[label] = empirical_pcrit(ps, means)
end
println("  empirical p_crit: ", pcs)

# (8) comparative statics: p_crit vs σ, D, α
println("  comparative statics...")
# p_crit vs σ (at D=0.6, no targeting)
rows = Any[["sigma","p_crit"]]
for σ in 0.0:0.05:0.5
    lps = range(0.001, 0.03, length=30) |> collect
    act = Float64[]
    for p in lps
        mp = MacroParams(p, 0.3, 1.5, 0.6, σ, 0.6, 0.7, 0.65, 0.4, 0.25, false, 0.05, 1.0)
        push!(act, mean([steady_resilience(run_cascade(g_ba, mp; T=T, rng=MersenneTwister(300+s))[1]) for s in 1:3]))
    end
    push!(rows, [σ, empirical_pcrit(lps, act)])
end
writecsv("macro_pcrit_sigma.csv", rows[1], rows[2:end])

# p_crit vs D (at σ=0.1)
rows = Any[["D","p_crit"]]
for D in 0.0:0.1:1.0
    lps = range(0.001, 0.03, length=30) |> collect
    act = Float64[]
    for p in lps
        mp = MacroParams(p, 0.3, 1.5, 0.6, 0.1, D, 0.7, 0.65, 0.4, 0.25, false, 0.05, 1.0)
        push!(act, mean([steady_resilience(run_cascade(g_ba, mp; T=T, rng=MersenneTwister(400+s))[1]) for s in 1:3]))
    end
    push!(rows, [D, empirical_pcrit(lps, act)])
end
writecsv("macro_pcrit_D.csv", rows[1], rows[2:end])

# p_crit vs α (KOL amplification), at D=0.6, σ=0.1
rows = Any[["alpha","p_crit"]]
for α in 0.0:0.25:3.0
    lps = range(0.001, 0.03, length=30) |> collect
    act = Float64[]
    for p in lps
        mp = MacroParams(p, 0.3, α, 0.6, 0.1, 0.6, 0.7, 0.65, 0.4, 0.25, false, 0.05, 1.0)
        push!(act, mean([steady_resilience(run_cascade(g_ba, mp; T=T, rng=MersenneTwister(500+s))[1]) for s in 1:3]))
    end
    push!(rows, [α, empirical_pcrit(lps, act)])
end
writecsv("macro_pcrit_alpha.csv", rows[1], rows[2:end])

# (9) heatmap: (D, σ) grid -> resilience at p=0.008
println("  heatmap...")
Dgrid = 0.0:0.1:1.0
σgrid = 0.0:0.05:0.5
open(joinpath(OUT, "macro_heatmap.csv"), "w") do io
    println(io, "D,sigma,resilience")
    for D in Dgrid, σ in σgrid
        mp = MacroParams(0.008, 0.3, 1.5, 0.6, σ, D, 0.7, 0.65, 0.4, 0.25, false, 0.05, 1.0)
        val = mean([steady_resilience(run_cascade(g_ba, mp; T=T, rng=MersenneTwister(600+s))[1]) for s in 1:3])
        println(io, join([D, σ, val], ","))
    end
end

# (10) robustness: network topology BA vs WS vs ER, p_crit (fine grid)
println("  robustness across topologies...")
rows = Any[["topology","p_crit","mean_degree","max_degree","degree_dispersion"]]
for (name, g) in (("BA", g_ba), ("WS", g_ws), ("ER", g_er))
    ks = degree(g)
    kbar = mean(ks)
    disp = (mean(ks .^ 2) - kbar) / kbar   # <k^2-k>/<k>
    lps = range(0.001, 0.02, length=60) |> collect
    act = Float64[]
    for p in lps
        mp = MacroParams(p, 0.3, 1.5, 0.6, 0.0, 0.6, 0.7, 0.65, 0.4, 0.25, false, 0.05, 1.0)
        push!(act, mean([steady_resilience(run_cascade(g, mp; T=T, rng=MersenneTwister(700+s))[1]) for s in 1:5]))
    end
    push!(rows, [name, empirical_pcrit(lps, act), kbar, maximum(ks), disp])
end
writecsv("macro_robustness.csv", rows[1], rows[2:end])

# (11) theory check: structural epidemic threshold vs empirical p_crit
println("  theory check...")
ks = degree(g_ba)
kbar = mean(ks)
Tc = kbar / (mean(ks .^ 2) - kbar)
rows = Any[["label","D","sigma","target","empirical_pcrit","Tc"]]
for (label, D, σ, tgt) in scenarios
    push!(rows, [label, D, σ, Int(tgt), pcs[label], Tc])
end
writecsv("macro_theory.csv", rows[1], rows[2:end])

# KOL targeting contrast at p=0.008 (extra evidence for targeted mitigation)
println("  KOL targeting contrast...")
rows = Any[["targeting","sigma","D","resilience_mean","resilience_std"]]
for (tgt, D, σ) in ((false,0.8,0.3), (true,0.8,0.3), (false,0.6,0.2), (true,0.6,0.2))
    mp = MacroParams(0.008, 0.3, 1.5, 0.6, σ, D, 0.7, 0.65, 0.4, 0.25, tgt, 0.05, 1.0)
    vals = [steady_resilience(run_cascade(g_ba, mp; T=T, rng=MersenneTwister(900+s))[1]) for s in 1:10]
    push!(rows, [Int(tgt), σ, D, mean(vals), std(vals)])
end
writecsv("macro_kol_targeting.csv", rows[1], rows[2:end])

# (12) macro one-way sensitivity analysis (tornado)
println("  sensitivity analysis (macro)...")
function macro_pcrit(; γ=0.3, α=1.5, wp=0.6, σ=0.0, D=0.6, τ0=0.7, qP=0.65, r=0.4, qC=0.25, target=false, κ=1.0)
    lps = range(0.001, 0.02, length=20) |> collect
    act = Float64[]
    for p in lps
        mp = MacroParams(p, γ, α, wp, σ, D, τ0, qP, r, qC, target, 0.05, κ)
        push!(act, mean([steady_resilience(run_cascade(g_ba, mp; T=T, rng=MersenneTwister(3000+s))[1]) for s in 1:3]))
    end
    return empirical_pcrit(lps, act)
end

base_pcrit = macro_pcrit()
rows = Any[["parameter","low","baseline","high","pcrit_low","pcrit_high"]]
for (name, lo, base, hi, kw) in [
        ("memory rate γ", 0.1, 0.3, 0.5, :γ),
        ("KOL amplification α", 0.5, 1.5, 2.5, :α),
        ("panic weight w_p", 0.2, 0.6, 1.0, :wp),
        ("base tolerance τ_0", 0.5, 0.7, 0.9, :τ0),
        ("panic probability q_P", 0.4, 0.65, 0.9, :qP),
        ("churn probability q_C", 0.1, 0.25, 0.5, :qC),
        ("recovery ratio r", 0.2, 0.4, 0.6, :r),
        ("KOL boost κ", 0.5, 1.0, 2.0, :κ)]
    lokw = Dict(:γ=>0.3,:α=>1.5,:wp=>0.6,:σ=>0.0,:D=>0.6,:τ0=>0.7,:qP=>0.65,:r=>0.4,:qC=>0.25,:target=>false,:κ=>1.0)
    lokw[kw] = lo
    hikw = Dict(lokw); hikw[kw] = hi
    pl = macro_pcrit(; lokw...)
    ph = macro_pcrit(; hikw...)
    push!(rows, [name, lo, base, hi, pl, ph])
end
writecsv("macro_sensitivity.csv", rows[1], rows[2:end])

# network-size and attachment robustness
println("  network-size robustness...")
rows = Any[["N","m","p_crit"]]
for (Nx, mx) in ((1000,3), (3000,3), (5000,3), (3000,2), (3000,4))
    gx = barabasi_albert(Nx, mx)
    lps = range(0.001, 0.02, length=20) |> collect
    act = Float64[]
    for p in lps
        mp = MacroParams(p, 0.3, 1.5, 0.6, 0.0, 0.6, 0.7, 0.65, 0.4, 0.25, false, 0.05, 1.0)
        push!(act, mean([steady_resilience(run_cascade(gx, mp; T=T, rng=MersenneTwister(4000+s))[1]) for s in 1:3]))
    end
    push!(rows, [Nx, mx, empirical_pcrit(lps, act)])
end
writecsv("macro_network_sensitivity.csv", rows[1], rows[2:end])

println("\nAll results written to ", OUT, "/")
