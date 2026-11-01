# Mitigating Catastrophic Technological Risk under Information Asymmetry

Research code for the paper *"Mitigating Catastrophic Technological Risk under
Information Asymmetry: A Signaling Game and Agent-Based Network Approach to
Battery Thermal Runaway"* (submitted to *Risk Analysis*).

The project studies how over-compensation guarantees ("replace a burnt vehicle")
can resolve both the informational friction (manufacturers privately know their
battery safety margin) and the social amplification of risk (panic cascades on
social networks) surrounding battery thermal runaway. It couples a micro-level
signaling game with a prospect-theory consumer to a macro-level agent-based
cascade on a scale-free network.

## Repository structure

```
├── src/
│   └── model.jl              # Core model: micro signaling game + macro ABM cascade
├── run_experiments.jl        # Experiment driver (reproduces all results)
├── gen_figures.py            # Generates the publication figures from results/
├── figures/                  # Publication figures (Figure 1–7)
├── results/                  # All numerical results (CSV)
├── README.md
└── .gitignore
```

## Key results

| Quantity | Value |
|---|---|
| Separating-equilibrium liability interval | C ∈ [218.3, 2182.5] (¥10,000) |
| Information rent (dread × loss aversion × loss) | Δ_risk = 10.91 |
| Critical runaway rate, no intervention | p_crit = 0.0035 |
| Critical runaway rate, transparency + compensation + KOL | p_crit = 0.0101 |
| Steady-state resilience at p = 0.008 (no intervention) | 5.7% |
| Steady-state resilience at p = 0.008 (full mitigation) | 57.0% |

The micro model embeds a prospect-theory consumer with loss aversion λ and a
dread multiplier δ (probability overweighting of rare catastrophic events). The
macro model is a linear-threshold panic cascade on a Barabási–Albert scale-free
network, with KOL influence amplification, trust-repair compensation, and a
percolation phase transition. Five propositions (with proofs in the paper's
Appendix A) characterize the separating equilibrium and the monotone comparative
statics of the critical threshold.

## Quick start

Requirements: Julia ≥ 1.10 (with `Graphs.jl`), Python ≥ 3.9 (with `matplotlib`,
`numpy`).

```bash
# 1. Run all experiments (writes results/*.csv)
julia run_experiments.jl

# 2. Generate publication figures (writes figures/*.png)
python3 gen_figures.py
```

The network generation is seeded (`Random.seed!(42)`), so every run reproduces
the exact numbers reported in the paper.

## Citation

If you use this code, please cite:

Hu, X. (2026). Mitigating Catastrophic Technological Risk under Information
Asymmetry: A Signaling Game and Agent-Based Network Approach to Battery Thermal
Runaway. *Risk Analysis* (submitted).
