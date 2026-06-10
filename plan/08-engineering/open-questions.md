# Open Questions & Pending Decisions

> **Status:** Living · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). Each has a **proposed default** so work isn't
> blocked — flip any during review. Resolved items move to the top and link to the
> [decision log](../00-overview/decision-log.md).

## Recently resolved
- **Client framework** → native SwiftUI + Liquid Glass — [ADR-004](../00-overview/decision-log.md#adr-004--client-pivot-native-swiftui--liquid-glass-ios-26--macos-26).
- **Cover art source** → client-side extraction — [ADR-006](../00-overview/decision-log.md#adr-006--cover-art-is-client-side).
- **Flutter's fate** → frozen reference — [ADR-007](../00-overview/decision-log.md#adr-007--freeze-the-flutter-client-all-new-feature-work-is-swift-only).
- **Ambition** → App Store product — [ADR-008](../00-overview/decision-log.md#adr-008--ambition-app-store-product).
- **Backend final scope** → hosted GPU service — [ADR-009](../00-overview/decision-log.md#adr-009--final-scope-backend-hosted-gpu-narration-service).

## Product / scope
| # | Question | Proposed default | Impact |
|---|---|---|---|
| Q-FREE | **Free-tier shape** — N free chapters? one free book? a lower-quality on-device voice unlimited + premium GPU voice? | **N free full-quality chapters** (taste the hero), decide N after Q-COST | Conversion vs COGS |
| Q-ODV | **On-device TTS fallback tier** (AVSpeechSynthesizer / personal voice) for offline-import or free users? | **Not in v1** — one quality bar; revisit if Q-COST makes free chapters too dear | Scope, quality story |
| Q-MAC | **macOS app's role at launch** — co-launch, later, or dev-only? | **Build multiplatform throughout, co-launch only if free** (no extra workstream); iPhone is the launch story | Launch scope |
| Q-DRM | **DRM-protected EPUBs** — detect and message, or stay silent? | **Detect + honest "can't read DRM" message** at import | Trust, support load |
| Q-LOOP | **Stack end behavior** — loop (reference wraps), snap, or stop? | **Stop with a soft settle** (loop reads as a bug with a real library); revisit after V09 | Feel |

## Architecture / engineering
| # | Question | Proposed default | Impact |
|---|---|---|---|
| Q-COST | **Cost per narrated chapter-hour** on serverless GPU (RunPod-class)? | **Measure during P7 alpha** before any pricing ADR | Pricing, free tier |
| Q-QUEUE | **Hosted queue semantics** — sync request (client waits) vs async + push? | **Async job + poll** first (matches the per-chapter status model); push later | P7 design |
| Q-SYNTH | **`get_synth()` model reload per `/import`** (memory balloon + latency) | **Cache the model like `get_transcriber`/`get_llm`** — cheap win, do opportunistically pre-P7 | Backend perf |
| Q-VOICE | **Voice selection** — single house voice or per-book choice? | **Single great default voice** for v1; choice is a premium follow-up | Scope |
| Q-LLM | **Discuss model in hosted scope** (Ollama llama3.2:3b is the dev model) | **Defer to P5/P7**: pick by eval against grounded-answer quality | Quality, cost |

## Design
| # | Question | Proposed default | Impact |
|---|---|---|---|
| Q-HDR | **Library header wording** — "VIMARSHA / LIBRARY / MY BOOKS" is placeholder | Keep until first-run flow design (P8); revisit with naming | Brand feel |
| Q-CHAP | **Chapter browsing surface** — fan from the focused book vs morph to a chapter stack? | **Secondary fan from book focus** (stays on-surface); spec in V06/V17 design pass | Core UX |

When a row resolves: add the ADR, move the row to "Recently resolved", and update the
affected docs (don't leave stale defaults inline elsewhere — link here instead).
