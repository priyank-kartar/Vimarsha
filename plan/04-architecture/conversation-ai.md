# Conversation AI (Discuss)

> **Status:** Draft · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). The grounded-conversation feature. The data
> layer is **built and merged** (backend `LlmClient`/Ollama + `/chat` + `/speak`; the
> Flutter client's `ChatRepository`/`ChatController` are the frozen behavioral reference);
> the native UI is bucket P5. Original spec:
> [`docs/superpowers/specs/2026-06-10-vimarsha-deep-dive-conversation-design.md`](../../docs/superpowers/specs/2026-06-10-vimarsha-deep-dive-conversation-design.md).

## What Discuss is

A conversation about **exactly where you are in the book** — explain this paragraph, push
back on the argument, define the term — not a general chatbot wearing a book costume.

## Grounding (the load-bearing idea)

`POST /chat` receives a `ChatContext` snapshot from the player (book/chapter/paragraph +
surrounding text window) and builds a grounded prompt; the model answers *from the passage*.
Properties to keep in the native rebuild:

- The context snapshot is taken **when the panel opens** (the user is asking about what
  they just heard, even if audio continues).
- Threads are **save-on-demand** (a conversation is ephemeral until the user keeps it) →
  Conversations state.
- Replies are text-first; the speaker control sends reply text to `/speak` (Chatterbox) —
  same voice as narration (one voice = one narrator persona).

## Interaction rules (from the spec; UI lands in P5)

- Opening Discuss does **not** pause narration.
- **Pause-on-audio-conflict:** narration pauses while a reply speaks or while the user
  voice-types (hold-to-talk → `/transcribe`), resumes if it was playing
  ([sound-design ladder](../03-design/sound-design.md)).
- Typed input is the default; hold-to-talk is the secondary affordance.
- The panel is a glass plane morphing within the canvas — never a sheet
  ([screen-flows](../03-design/screen-flows.md)).

## Model strategy

| Phase | Model | Notes |
|---|---|---|
| Dev / P5 | Ollama `llama3.2:3b` locally | already the wired seam; good enough to build UX against |
| Hosted (P7+) | TBD (Q-LLM) | pick by eval: grounded-answer faithfulness on a passage-QA set, latency, cost; 💎 "Discuss depth" (F35) may tier model/context size |

## Guardrails (write before P5 ships)

Stay in the book: the prompt instructs grounding + honest "the passage doesn't say";
no medical/legal/financial advice persona even when books cover those topics (answer *about
the text*); user content (questions, memos) never trains anything — see
[privacy-security](privacy-security.md).
