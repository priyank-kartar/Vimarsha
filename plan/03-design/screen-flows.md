# Screen Flows — States of One Surface

> **Status:** Reviewed · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). The state map and the morph that connects each
> pair. There are no pages ([design-principles #1](design-principles.md)); the system
> keyboard is the single sanctioned OS surface. Implementable detail accrues per V-item.

## State map

```
            ┌────────────────────────────────────────────────┐
            │              LIBRARY STACK  (home)             │
            │   editorial header · depth-stacked hardbacks   │
            └───────┬────────────────────────────────────────┘
       scroll-settle│  (grow-to-front)
            ┌───────▼────────┐   fan from focused book
            │   BOOK FOCUS   │──────────────► CHAPTER FAN (Q-CHAP)
            │ +glass cluster │
            └───┬─────┬──────┘
   Play: cover  │     │ Figures / Memo / Discuss (also reachable while reading)
   opens        │     │
            ┌───▼─────▼──────────────────────────────┐
            │        NARRATED READING SURFACE         │
            │ serif body · live highlight · transport │
            └──┬──────────┬───────────┬───────────┬───┘
   span timer  │   grid    │   hold    │  double-  │
            ┌──▼───┐  ┌────▼────┐ ┌────▼───┐ ┌────▼────┐
            │FIGURE│  │ FIGURES │ │  MEMO  │ │ DISCUSS │
            │OVERLAY│ │ GALLERY │ │ RECORD │ │  PANEL  │
            └──────┘  └─────────┘ └───┬────┘ └────┬────┘
                                  ┌───▼────┐ ┌────▼──────────┐
                                  │ NOTES  │ │ CONVERSATIONS │
                                  └────────┘ └───────────────┘
```

## Morph choreography per transition

| From → To | Morph (named patterns / glass moments) | Notes |
|---|---|---|
| Stack ↔ Book focus | scroll-settle + grow-to-front; control cluster morphs out of the cover (glass #5) | no tap needed to focus; cluster re-absorbs on scroll |
| Book focus ↔ Chapter fan | secondary fan from the focused book (Q-CHAP default) | designed in the V06/V17 pass |
| Focus/Play ↔ Reading surface | the cover is the shared element — hardback opens into the canvas (matched geometry) | V17; back-morph on close, never a dismiss-pop |
| Reading ↔ Figure overlay | figure morphs out of its passage on the glass carrier (glass #8), recedes at endMs | stacking when spans overlap |
| Reading ↔ Figures gallery | surface reflows into a morphed grid | selecting a figure may seek to its span |
| Reading ↔ Memo record | hold gesture on the mic control; aqua waveform puck while held | release → transcript chip → Notes |
| Reading ↔ Discuss panel | glass plane morphs up *within* the canvas — never `.sheet` | opening does NOT pause playback; pause-on-audio-conflict applies while replies speak / voice-typing |
| Notes / Conversations | "morphed list state": the surface reflows into a scrollable list on the same canvas | concrete choreography owned by P4/P5 specs |

## Per-state accessibility hooks

Each state must declare: its Reduce-Motion form, its VoiceOver rotor/actions, and its
Dynamic-Type stress behavior — tracked as the matrix in [accessibility](accessibility.md).
