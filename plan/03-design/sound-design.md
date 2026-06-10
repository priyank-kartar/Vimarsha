# Sound Design

> **Status:** Draft · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). An audio-first product needs designed audio
> behavior, not just a working player. Owns the rules the player/Discuss V-items implement.

## Narration voice direction

- One house voice for v1 (Q-VOICE): warm, unhurried, slightly literary — the bar is "a
  friend who reads well," not broadcast announcer. Chatterbox settings tuned once and
  pinned (a voice change after launch resets users' familiarity).
- Speed control is the listener's, not the voice's: 0.8×–2.5×, pitch-preserved.

## The audio-priority ladder (highest first)

1. **VoiceOver** — always wins; everything else ducks or pauses.
2. **Spoken Discuss replies** (`/speak`) — *pause* chapter narration (not duck), resume
   after if it was playing (the pause-on-audio-conflict rule, carried from the old Plan 6b
   spec).
3. **Chapter narration** — the main channel.
4. **Earcons/UI sounds** — duck nothing; they fit in gaps.

Voice-typing (hold-to-talk) also pauses narration — the mic must not hear the narrator.

## System integration (lands with V16, polish in P9)

- **Audio session:** `.playback` category (narration audible in silent mode, like any
  audiobook app); interruptions (calls) pause and resume per system convention.
- **Lock screen / Control Center / AirPods:** Now Playing metadata (book title, chapter,
  cover art), play/pause/seek/speed; headphone remote works eyes-free.
- **Background audio** entitlement; narration continues when the app backgrounds.
- Bluetooth/CarPlay-adjacent behavior verified in P9 (commuter persona P1 lives here).

## Earcons (sparse by design)

At most: narration-ready chime (a narration job finishing while you're elsewhere), memo
start/stop ticks, Discuss reply-arrived tap. All optional under one "UI sounds" setting;
none carry sole meaning (principle 6: visual/VO equivalents always exist).

## Open

Figure auto-pop: silent by default (the *visual* is the moment) — revisit only if eyes-free
users ask for an audible cue (it would need to not interrupt narration). Earcon palette
itself undesigned (design-system gap when P9 nears).
