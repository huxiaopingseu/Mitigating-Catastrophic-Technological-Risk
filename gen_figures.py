#!/usr/bin/env python3
# Generate publication figures for the paper from results/*.csv
import os
import csv
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch, Rectangle
from matplotlib.lines import Line2D

BASE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(BASE, "results")
FIG = os.path.join(BASE, "figures")
os.makedirs(FIG, exist_ok=True)

plt.rcParams.update({
    "font.family": "serif",
    "font.serif": ["DejaVu Serif", "Times New Roman"],
    "font.size": 11,
    "axes.titlesize": 12,
    "axes.labelsize": 12,
    "legend.fontsize": 9.5,
    "xtick.labelsize": 10,
    "ytick.labelsize": 10,
    "axes.linewidth": 0.8,
    "figure.dpi": 150,
})

def read(fname):
    with open(os.path.join(RES, fname)) as f:
        return list(csv.reader(f))

def col(rows, name):
    h = rows[0]
    return [float(r[h.index(name)]) for r in rows[1:]]

# scenario palette
SCEN = {
    "opaque_no_comp":       ("Opaque, no compensation ($D{=}0.8$, $\\sigma{=}0$)", "#d62728"),
    "transparent_no_comp":  ("Transparent, no compensation ($D{=}0.2$, $\\sigma{=}0$)", "#1f77b4"),
    "opaque_comp":          ("Opaque, compensation ($D{=}0.8$, $\\sigma{=}0.3$)", "#2ca02c"),
    "transparent_comp_KOL": ("Transparent, compensation + KOL targeting ($D{=}0.2$, $\\sigma{=}0.3$)", "#9467bd"),
}

# =========================================================================
# Figure 1 — conceptual framework (three-layer diagram)
# =========================================================================
def fig1():
    fig, ax = plt.subplots(figsize=(9.6, 5.6))
    ax.axis("off")
    ax.set_xlim(0, 10); ax.set_ylim(0, 7.2)

    def box(x, y, w, h, text, fc, fs=9.5):
        ax.add_patch(FancyBboxPatch((x, y), w, h,
                     boxstyle="round,pad=0.06", fc=fc, ec="#333333", lw=1.0))
        ax.text(x + w/2, y + h/2, text, ha="center", va="center", fontsize=fs)

    # layer labels
    ax.text(0.15, 6.75, "Micro (signaling game)", fontsize=13, fontweight="bold", color="#7a1f1f")
    ax.text(0.15, 4.05, "Mapping bridge", fontsize=13, fontweight="bold", color="#4a4a4a")
    ax.text(0.15, 1.35, "Macro (agent-based network)", fontsize=13, fontweight="bold", color="#1f3a6e")

    # micro layer
    box(0.6, 5.4, 2.4, 0.85, r"Firm type $\theta\in\{H,L\}$" + "\n" + r"runaway rate $p_H<p_L$", "#f7dcdc")
    box(3.6, 5.4, 2.4, 0.85, r"Signal: guarantee $w\in[0,1]$" + "\n(over-compensation)", "#f7dcdc")
    box(6.6, 5.4, 2.8, 0.85, r"Loss-averse consumer" + "\n" + r"WTP $p^*(w;\mu)$, posterior $\mu$", "#f7dcdc")
    box(2.0, 4.55, 5.4, 0.6, r"Separating equilibrium  $C\in[C_{\min},C_{\max}]$  (Propositions 1–3)", "#fdf0f0")
    for (x0, x1) in [(3.0, 3.6), (6.0, 6.6)]:
        ax.add_patch(FancyArrowPatch((x0, 5.82), (x1, 5.82),
                     arrowstyle="-|>", mutation_scale=16, color="#555555"))

    # bridge
    box(2.0, 3.15, 5.4, 0.6,
        r"$\tau_i = \tau_0\,(1 - \rho_i\,D)$   (information distortion $D$ lowers tolerance)",
        "#e8e8e8")
    ax.add_patch(FancyArrowPatch((3.0, 4.55), (3.0, 3.75),
                 arrowstyle="-|>", mutation_scale=16, color="#555555"))

    # macro layer
    box(0.6, 1.9, 2.6, 0.85, "Scale-free social network\n(Barabási–Albert, KOL hubs)", "#d6e2f5")
    box(3.7, 1.9, 2.6, 0.85, "Panic cascade\n(shock $p$ + threshold contagion)", "#d6e2f5")
    box(6.8, 1.9, 2.6, 0.85, "Trust repair $\\sigma$\n(uniform or KOL-targeted)", "#d6e2f5")
    box(2.0, 0.55, 5.4, 0.6, "Phase transition $p_{\\mathrm{crit}}$ and reputational resilience  (Proposition 4)", "#eef3fc")
    ax.add_patch(FancyArrowPatch((3.2, 3.15), (3.2, 2.75),
                 arrowstyle="-|>", mutation_scale=16, color="#555555"))
    for (x0, x1) in [(3.2, 3.7), (6.3, 6.8)]:
        ax.add_patch(FancyArrowPatch((x0, 2.32), (x1, 2.32),
                     arrowstyle="-|>", mutation_scale=16, color="#555555"))

    fig.tight_layout(pad=0.4)
    fig.savefig(os.path.join(FIG, "fig1_framework.png"), bbox_inches="tight")
    plt.close(fig)

# =========================================================================
# Figure 2 — micro: single-crossing + separating interval vs loss aversion
# =========================================================================
def fig2():
    rows = read("micro_single_crossing.csv")
    w = col(rows, "w"); PiH = col(rows, "Pi_H"); PiL = col(rows, "Pi_L")
    lrows = read("micro_lambda_sweep.csv")
    lam = col(lrows, "lambda"); Cmin = col(lrows, "C_min"); Cmax = col(lrows, "C_max")

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(9.4, 4.1))
    ax1.plot(w, PiH, color="#1f77b4", lw=2, label=r"$\Pi_H(w;\mu{=}1)$, type $H$")
    ax1.plot(w, PiL, color="#d62728", lw=2, label=r"$\Pi_L(w;\mu{=}1)$, type $L$")
    ax1.set_xlabel(r"Guarantee level $w$")
    ax1.set_ylabel("Firm profit")
    ax1.set_title("(a) Single-crossing property", fontsize=11)
    ax1.legend(frameon=False)
    ax1.annotate(r"steeper cost for $L$: $\partial^2\Pi/\partial w\,\partial p_\theta=-C<0$",
                 xy=(0.72, 1.5), xytext=(0.18, 0.5), fontsize=8.5, color="#333333",
                 arrowprops=dict(arrowstyle="->", color="#555555"))
    ax1.grid(alpha=0.3)

    ax2.plot(lam, Cmin, color="#1f77b4", lw=2, label=r"$C_{\min}$")
    ax2.plot(lam, Cmax, color="#d62728", lw=2, label=r"$C_{\max}$")
    ax2.fill_between(lam, Cmin, Cmax, color="#bbbbbb", alpha=0.35,
                     label="separating equilibrium exists")
    ax2.set_xlabel(r"Loss-aversion coefficient $\lambda$")
    ax2.set_ylabel(r"Liability interval $C$")
    ax2.set_title("(b) Equilibrium interval vs loss aversion", fontsize=11)
    ax2.legend(frameon=False, loc="upper left")
    ax2.grid(alpha=0.3)

    fig.tight_layout()
    fig.savefig(os.path.join(FIG, "fig2_signaling.png"), bbox_inches="tight")
    plt.close(fig)

# =========================================================================
# Figure 3 — macro trajectories
# =========================================================================
def fig3():
    rows = read("macro_trajectories.csv")
    h = rows[0]
    t = [int(float(r[0])) for r in rows[1:]]
    fig, ax = plt.subplots(figsize=(6.2, 4.2))
    for key, (label, color) in SCEN.items():
        y = [float(r[h.index(key)]) for r in rows[1:]]
        ax.plot(t, y, color=color, lw=2, label=label)
    ax.set_xlabel("Time step $t$")
    ax.set_ylabel("Active-owner fraction (resilience)")
    ax.set_title("Panic-cascade trajectories at $p=0.008$", fontsize=11)
    ax.set_ylim(-0.02, 1.02)
    ax.legend(frameon=False, fontsize=8.2, loc="center left", bbox_to_anchor=(0.01, 0.35))
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(FIG, "fig3_trajectories.png"), bbox_inches="tight")
    plt.close(fig)

# =========================================================================
# Figure 4 — phase transition
# =========================================================================
def fig4():
    rows = read("macro_phase_transition.csv")
    h = rows[0]
    p = [float(r[0]) for r in rows[1:]]
    pcrit = {"opaque_no_comp": 0.0035, "transparent_no_comp": 0.0076,
             "opaque_comp": 0.0076, "transparent_comp_KOL": 0.0101}
    fig, ax = plt.subplots(figsize=(6.4, 4.3))
    for key, (label, color) in SCEN.items():
        y = [float(r[h.index(key)]) for r in rows[1:]]
        ax.plot(p, y, color=color, lw=2, label=label)
        ax.axvline(pcrit[key], color=color, ls="--", lw=1.0, alpha=0.7)
    ax.set_xlabel(r"Spontaneous thermal-runaway rate $p$")
    ax.set_ylabel("Steady-state active-owner fraction")
    ax.set_title("Phase transition of reputational resilience", fontsize=11)
    ax.set_ylim(-0.02, 1.02)
    ax.legend(frameon=False, fontsize=8.2, loc="lower left")
    ax.grid(alpha=0.3)
    ax.annotate(r"$p_{\mathrm{crit}}$ shifts right", xy=(0.0115, 0.30), xytext=(0.011, 0.62),
                fontsize=9, ha="center",
                arrowprops=dict(arrowstyle="->", color="#333333"))
    fig.tight_layout()
    fig.savefig(os.path.join(FIG, "fig4_phase_transition.png"), bbox_inches="tight")
    plt.close(fig)

# =========================================================================
# Figure 5 — comparative statics + topology robustness
# =========================================================================
def fig5():
    srows = read("macro_pcrit_sigma.csv"); sig = col(srows, "sigma"); ps = col(srows, "p_crit")
    drows = read("macro_pcrit_D.csv"); Dv = col(drows, "D"); pd = col(drows, "p_crit")
    arows = read("macro_pcrit_alpha.csv"); al = col(arows, "alpha"); pa = col(arows, "p_crit")
    rrows = read("macro_robustness.csv")

    fig, axes = plt.subplots(1, 4, figsize=(12.6, 3.4))
    axes[0].plot(sig, ps, "o-", color="#2ca02c", lw=1.6, ms=4)
    axes[0].set_xlabel(r"Compensation $\sigma$"); axes[0].set_ylabel(r"$p_{\mathrm{crit}}$")
    axes[0].set_title(r"(a) $p_{\mathrm{crit}}$ vs $\sigma$", fontsize=10.5)
    axes[0].grid(alpha=0.3)

    axes[1].plot(Dv, pd, "o-", color="#1f77b4", lw=1.6, ms=4)
    axes[1].set_xlabel(r"Information distortion $D$")
    axes[1].set_title(r"(b) $p_{\mathrm{crit}}$ vs $D$", fontsize=10.5)
    axes[1].grid(alpha=0.3)

    axes[2].plot(al, pa, "o-", color="#d62728", lw=1.6, ms=4)
    axes[2].set_xlabel(r"KOL amplification $\alpha$")
    axes[2].set_title(r"(c) $p_{\mathrm{crit}}$ vs $\alpha$", fontsize=10.5)
    axes[2].grid(alpha=0.3)

    names = [r[0] for r in rrows[1:]]
    vals = [float(r[1]) for r in rrows[1:]]
    cols = ["#d62728", "#1f77b4", "#2ca02c"]
    axes[3].bar(names, vals, color=cols, width=0.55)
    axes[3].set_ylabel(r"$p_{\mathrm{crit}}$")
    axes[3].set_title("(d) Topology robustness", fontsize=10.5)
    axes[3].grid(alpha=0.3, axis="y")
    for i, v in enumerate(vals):
        axes[3].text(i, v + 0.0001, f"{v:.3f}", ha="center", fontsize=8.5)

    fig.tight_layout()
    fig.savefig(os.path.join(FIG, "fig5_comparative.png"), bbox_inches="tight")
    plt.close(fig)

# =========================================================================
# Figure 6 — resilience heatmap in (D, sigma) space
# =========================================================================
def fig6():
    rows = read("macro_heatmap.csv")
    Ds = sorted(set(float(r[0]) for r in rows[1:]))
    Ss = sorted(set(float(r[1]) for r in rows[1:]))
    Z = np.zeros((len(Ss), len(Ds)))
    for r in rows[1:]:
        d, s, v = float(r[0]), float(r[1]), float(r[2])
        Z[Ss.index(s), Ds.index(d)] = v
    fig, ax = plt.subplots(figsize=(6.2, 4.4))
    im = ax.imshow(Z, origin="lower", aspect="auto", cmap="RdYlGn",
                   extent=[Ds[0], Ds[-1], Ss[0], Ss[-1]], vmin=0, vmax=1)
    ax.set_xlabel(r"Information distortion $D$")
    ax.set_ylabel(r"Compensation intensity $\sigma$")
    ax.set_title("Systemic resilience heatmap at $p=0.008$", fontsize=11)
    cb = fig.colorbar(im, ax=ax, pad=0.02)
    cb.set_label("Steady-state active-owner fraction")
    ax.contour(Z, levels=[0.5], colors="black", linewidths=1.4, linestyles="--",
               extent=[Ds[0], Ds[-1], Ss[0], Ss[-1]])
    ax.text(0.85, 0.06, "safe zone", fontsize=9, color="black", fontweight="bold")
    ax.text(0.1, 0.42, "crisis zone", fontsize=9, color="white", fontweight="bold")
    fig.tight_layout()
    fig.savefig(os.path.join(FIG, "fig6_heatmap.png"), bbox_inches="tight")
    plt.close(fig)

# =========================================================================
# Figure 7 — macro one-way sensitivity tornado
# =========================================================================
def fig7():
    rows = read("macro_sensitivity.csv")
    h = rows[0]
    data = []
    for r in rows[1:]:
        name = r[h.index("parameter")]
        lo = float(r[h.index("pcrit_low")])
        hi = float(r[h.index("pcrit_high")])
        base = float(r[h.index("baseline")])
        data.append((name, lo, hi, base))
    # sort by range descending
    data.sort(key=lambda d: abs(d[2]-d[1]), reverse=True)
    names = [d[0] for d in data][::-1]
    los = [d[1] for d in data][::-1]
    his = [d[2] for d in data][::-1]
    bases = [d[3] for d in data][::-1]

    fig, ax = plt.subplots(figsize=(6.4, 4.4))
    y = np.arange(len(names))
    for i in range(len(names)):
        ax.plot([los[i], his[i]], [y[i], y[i]], color="#333333", lw=6, solid_capstyle="butt")
        # direction marker
        if his[i] > los[i]:
            ax.plot(his[i], y[i], ">", color="#d62728", ms=7)
            ax.plot(los[i], y[i], "<", color="#1f77b4", ms=7)
        else:
            ax.plot(los[i], y[i], ">", color="#1f77b4", ms=7)
            ax.plot(his[i], y[i], "<", color="#d62728", ms=7)
    # baseline vertical line
    base_pcrit = 0.005
    ax.axvline(base_pcrit, color="#888888", ls="--", lw=1.0)
    ax.set_yticks(y)
    ax.set_yticklabels(names, fontsize=9)
    ax.set_xlabel(r"Critical runaway rate $p_{\mathrm{crit}}$")
    ax.set_title("One-way sensitivity of the phase-transition boundary", fontsize=11)
    ax.set_xlim(0.001, 0.008)
    ax.grid(alpha=0.3, axis="x")
    fig.tight_layout()
    fig.savefig(os.path.join(FIG, "fig7_tornado.png"), bbox_inches="tight")
    plt.close(fig)

for f in (fig1, fig2, fig3, fig4, fig5, fig6, fig7):
    f()
    print("wrote", f.__name__)

print("done")
