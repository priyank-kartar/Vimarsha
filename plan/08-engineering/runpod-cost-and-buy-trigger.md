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

## Measured throughput — live benchmark (2026-06-13)

First live CUDA run. **RunPod A40** (~696 GB/s, $0.44/hr, Ubuntu base image + `uv sync --extra tts`),
real `narrate_bundle` path on an 18.5k-char prose chapter (Flatland slice). Unbatched, single-stream.

| Metric | MPS (M4, prior) | **A40 (measured)** |
|---|---|---|
| Chatterbox sampling loop | ~2 it/s | **~55 it/s (~27×)** |
| 18.5k-char chapter wall | hours (ch01 didn't finish in 2h) | **502.7 s (8.4 min)** |
| Audio produced | — | 898 s (15.0 min) |
| Realtime factor (audio÷wall) | ~0.13× | **1.79× (faster than realtime)** |
| chars/sec | — | 36.8 |
| Model load (one-time/process) | — | 44.3 s |
| **$/18k chapter** | — | **$0.061** |
| **$/64k chapter** (Bohm ch01) | — | **~$0.21** |
| GPU mem after block | climbed → swap | flat, released to 0 (CUDA `empty_cache` OK) |

**Read-across (bandwidth-bound autoregressive decode scales ~linearly with mem bandwidth):**
| GPU | Bandwidth | ~Realtime factor | ~$/18k chapter @ typical RunPod rate |
|---|---:|---:|---:|
| A40 (measured) | 696 GB/s | 1.79× | $0.061 @ $0.44 |
| RTX 4090 (buy-target) | ~1008 GB/s | ~2.6× | ~$0.044 @ $0.50 |
| RTX 5090 (buy-target) | ~1792 GB/s | ~4.6× | needs torch≥cu128 (lockfile pins cu124) |
| H100 | ~3350 GB/s | ~8.6× | ~$0.012 @ $2.50 |

Notes: ~$2/book unbatched single-stream on A40. **Block batching** (deferred `feat/batched-narration`)
is a further ~10× on $/chapter and re-derives everything. The 5090 (only available consumer card)
is blocked by our torch 2.6+cu124 pin (no sm_120 kernels) — bump to cu128 before benchmarking it.

## Usage ledger (append monthly — feed me your RunPod billing export)

| Month | GPU-hrs | $ spent | Avg GPU type/$hr | Shape (steady/spiky) | Verdict vs buy-line |
|---|---:|---:|---|---|---|
| _2026-06_ | ~0.7 (benchmark) | ~$0.30 | A40 @ $0.44 | one-off test | below — keep renting |

**How to update:** paste your RunPod usage (GPU-hours + $ for the month, or the billing CSV)
and I'll append a row, recompute months-to-payback at current burn, and flag when you cross a
buy-trigger. (RunPod also has a billing API — say the word and I'll write a small puller so
this updates itself.)
