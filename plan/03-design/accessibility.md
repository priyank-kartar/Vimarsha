# Accessibility

> **Status:** Reviewed · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). Parity, not fallback
> ([principle 8](design-principles.md)) — and for persona P3 this *is* the product.
> Canonical implementation rules: [apple/CLAUDE.md §Accessibility](../../apple/CLAUDE.md).
> The P9 audit walks this doc state-by-state.

## The four commitments

1. **Reduce Motion** — continuous-layout effects get a designed static layout (the
   depth-stack becomes a flat full-size list); discrete morphs become cross-dissolves or
   instant swaps. Nothing is reachable only via a motion gesture.
2. **Reduce Transparency** — every glass element has a token-tinted matte twin (pattern
   established in V03's top scrim).
3. **Dynamic Type** — `@ScaledMetric`/relative styles everywhere including display serif;
   every state survives XXL (stack, reading surface, overlays).
4. **VoiceOver** — zero-chrome design ⇒ explicit accessibility actions for every gesture
   (focus a book, play, open figures, record memo, discuss); the reading surface exposes
   paragraph navigation; figures have meaningful labels (caption text, not "image").

## The state × setting matrix (filled per V-item, audited in P9)

| State | Reduce Motion form | Reduce Transparency | VO actions | Dynamic Type stress |
|---|---|---|---|---|
| Library stack | flat full-size list (✅ V03) | matte top scrim (✅ V03) | per-book: focus/activate (V06) | header scales, cards reflow (✅ V03 via ScaledMetric) |
| Book focus + cluster | instant cluster appear | matte cluster chips | 4 labeled actions | cluster wraps |
| Reading surface | no auto-scroll animation (jump) | n/a (paper) | paragraph rotor + play/pause | body reflows, measure holds |
| Figure overlay | fade in/out | matte carrier | announced + inspectable | caption scales |
| Memo record | static level meter | matte puck | start/stop actions | — |
| Discuss panel | instant present | matte plane | message list + send/talk | input + replies scale |

Rows are owned by their V-items; the audit (P9) verifies the whole table on device with the
settings actually enabled — not by code inspection.

## Audio-specific

- Narration is the alternative format for the *book*; the app's own UI must never rely on
  narration to be operable (VO users may run both).
- Ducking and pause-on-audio-conflict rules ([sound-design](sound-design.md)) keep VO,
  narration, and spoken replies from talking over each other; VO has priority.
