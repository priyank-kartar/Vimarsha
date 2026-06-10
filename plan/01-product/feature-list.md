# Feature List

> **Status:** Living · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). The F-numbered inventory, initial → final
> scope. Tier markers: `v1` (M1–M3) · `v1.x` (M4) · `v2` (M5+) · 💎 premium-candidate
> (final call in [monetization](../05-monetization/monetization.md)). Build mapping:
> [build-roadmap](../08-engineering/build-roadmap.md).

## Library & import
- **F01** `v1` Living-library depth-stack of real covers (the signature surface). (V03–V09)
- **F02** `v1` EPUB import via document picker; security-scoped storage. (V10)
- **F03** `v1` Client-side cover extraction + generated cloth fallback. (V11)
- **F04** `v1` Book focus + glass control cluster (Play/Figures/Memo/Discuss). (V06–V07)
- **F05** `v1.x` Share-sheet import ("Open in Vimarsha").
- **F06** `v2` Library search/sort/collections (only when libraries grow).

## Narration & playback
- **F10** `v1` Per-chapter GPU narration (Chatterbox) with paragraph timings. (V14)
- **F11** `v1` Player: play/pause/seek/speed/resume + progress persistence. (V16)
- **F12** `v1` Offline replay of cached chapters. (V14/V21)
- **F13** `v1` Chapter status surface (none/pending/ready/error + retry). (V14)
- **F14** `v2` 💎 Hosted narration (no self-run backend) with metered minutes. (P7)
- **F15** `v2` 💎 Whole-book background narration queue.
- **F16** `v2` Voice choice (single house voice in v1 — Q-VOICE).

## Reading surface & figures
- **F20** `v1` Reading surface: serif body, live paragraph highlight, auto-scroll. (V18)
- **F21** `v1` Tap-a-paragraph-to-seek + glass transport cluster. (V19)
- **F22** `v1` Figure auto-pop on glass carrier at span times; stacking. (V20)
- **F23** `v1` Figures gallery (morphed grid; the reliable path to any figure). (V20)
- **F24** `v2` LLM figure-mention fallback at import (precision upgrade). (P6)

## Memos & Discuss
- **F30** `v1.x` Hold-to-record voice memo at paragraph pin → Whisper transcript. (P4)
- **F31** `v1.x` Notes state: play / open-at-pin / retry / delete. (P4)
- **F32** `v1.x` Discuss: grounded chat, typed default + hold-to-talk. (P5)
- **F33** `v1.x` Spoken replies (`/speak`) + pause-on-audio-conflict. (P5)
- **F34** `v1.x` Save threads → Conversations state (reopen read-only, delete). (P5)
- **F35** `v2` 💎 Discuss depth (bigger hosted model, longer context). (P7+)

## Platform & polish
- **F40** `v1` Dark-first + light themes; full palette-as-canvas. (V02, done)
- **F41** `v1` Accessibility matrix: RM/RT/Dynamic Type/VoiceOver per state. (P9 audit)
- **F42** `v1` macOS build from the same codebase (launch role: Q-MAC).
- **F43** `v2` Accounts: Sign in with Apple (arrives only with hosted — ADR-009). (P7)
- **F44** `v2` Onboarding: first-run → first narrated chapter < 2 min. (P8)
- **F45** `v2` 💎 Paywall + free-tier metering. (P8)

## Explicitly not features
No bank of public-domain books, no social feed, no in-app EPUB purchasing, no DRM cracking
(detect + message — Q-DRM), no general-knowledge chatbot persona.
