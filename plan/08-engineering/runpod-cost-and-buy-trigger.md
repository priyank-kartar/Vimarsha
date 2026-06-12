# RunPod Cost Tracking & GPU Buy-Trigger

> **Purpose:** decide *when* buying GPU hardware beats renting RunPod, expressed in RunPod's
> own metric (**monthly GPU-hours**), and log actual usage toward that line.
> **Owner:** founder (feeds usage numbers); the agent maintains the ledger + verdict.
> Started 2026-06-12. Prices are planning estimates — **verify against live RunPod billing.**

## Decision in one line

Buy hardware when **RunPod GPU-hours/month** are **high AND steady** enough that capex pays
back inside ~12 months. Until then, rent (serverless scale-to-zero).

## Two separate swap thresholds (both already Docker-swappable)

| Swap | Trigger | Why |
|---|---|---|
| **Mac → RunPod** | real usage > ~5% (~37 GPU-hrs/mo), i.e. the first real users | dev Mac is MPS-slow + can't serve others |
| **RunPod → owned GPU** | sustained spend over the buy-trigger below | capex beats opex only at steady high duty |

## Buy-trigger table (RunPod 4090 ≈ $0.40/hr — UPDATE with your real rate)

`break-even GPU-hours = hardware_price / (runpod_$hr − owned_marginal_$hr)`, owned marginal
≈ $0.08/hr (power only; ignores your ops time).

| Buy target | All-in ~price | Break-even GPU-hrs | 12-mo payback = | ≈ RunPod $/mo |
|---|---:|---:|---:|---:|
| Used RTX 3090 box (24GB, 936 GB/s) | $1,400 | 4,375 | **~365 GPU-hrs/mo** | ~$150 |
| RTX 4090 box (24GB, ~1 TB/s) | $2,500 | 7,800 | **~650 GPU-hrs/mo** | ~$260 |
| RTX 5090 box (32GB, ~1.7 TB/s) | $3,000 | 9,400 | **~780 GPU-hrs/mo** | ~$310 |

**Rules of thumb:**
- **> ~$150/mo (~365 GPU-hrs/mo)** → start the 3090 buy conversation.
- **> ~$260/mo (~650 GPU-hrs/mo)** → 4090 pays back in a year.
- **< ~$50–100/mo** → stay on RunPod; owned hardware would idle.
- **Spiky** usage favors RunPod even at high totals (scale-to-zero + burst). Owned wins on a
  **steady baseline**; the eventual answer is **hybrid** (own baseline, burst to RunPod).

## Hardware/workload notes
- **DGX Spark is NOT the pick for TTS** — ~273 GB/s bandwidth (≈ M4 Pro); autoregressive
  decode is bandwidth-bound, so a 4090 (~1 TB/s) beats it per-stream for less money. Spark
  only makes sense if also running large LLMs (`/chat`, figure-detection) or heavy batching.
- **Block batching** (in progress in `narrate_bundle`) changes $/chapter by ~10× and moves
  every number here — re-derive the table once batched throughput is benchmarked.
- Benchmark first: rent a 4090 + an A100/H100 for ~1 hr each (~$1–3), run batched
  `narrate_bundle` on a real chapter, record **it/s, chapter-min/wall-min, $/chapter**.

## Usage ledger (append monthly — feed me your RunPod billing export)

| Month | GPU-hrs | $ spent | Avg GPU type/$hr | Shape (steady/spiky) | Verdict vs buy-line |
|---|---:|---:|---|---|---|
| _2026-06_ | _tbd_ | _tbd_ | _tbd_ | _tbd_ | below — keep renting |

**How to update:** paste your RunPod usage (GPU-hours + $ for the month, or the billing CSV)
and I'll append a row, recompute months-to-payback at current burn, and flag when you cross a
buy-trigger. (RunPod also has a billing API — say the word and I'll write a small puller so
this updates itself.)
