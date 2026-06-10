# Vimarsha — Deep-Dive Conversation (Plan 6 Design)

**Design spec — 2026-06-10**

Talk *with* the book: open a Discuss panel from the player, ask questions (typed
or spoken) about the passage being read, and get grounded answers from a local
LLM — optionally read aloud. Conversations are ephemeral unless explicitly saved,
and saved threads are reviewable. Playback keeps going while you discuss.

This is **Plan 6**, split into:
- **Plan 6a** — backend + data/logic: LLM seam + `/chat` + `/speak`, client
  `BackendClient.chat/speak`, `ChatThreads`/`ChatMessages` tables, `ChatRepository`
  (persistence), `ChatController` (live conversation). No new screens.
- **Plan 6b** — UI: the Discuss panel (opened by double-tapping record), the
  record button's dual gesture, and the Conversations review screen.

Depends on Plans 1–5b. The **figure-mention LLM fallback** (reusing this LLM seam
at import time) is a separate follow-on (Plan 7), out of scope here.

---

## 1. Scope

In scope:
- A **Discuss panel** opened by **double-tapping the record button** in the player
  (single hold still records a memo). Opening Discuss does **not** pause playback.
- Ask by **keyboard (default)** or a secondary **hold-to-talk** mic (transcribed
  via the existing `/transcribe`).
- Answers from a **local LLM (Ollama)**, grounded in the **passage currently being
  narrated at the moment each question is sent** (the live paragraph + a window +
  any active figure) plus the running conversation. So the grounding rides along
  with playback — a follow-up asked a minute later is grounded on what's being
  read then. Answer shown as **text first**, with a **speaker** button to read it
  aloud via Chatterbox (`/speak`).
- Conversation is **ephemeral** until the user taps **Save**; each Save creates a
  **new** thread (multiple per chapter allowed), listed on a **Conversations**
  screen (review, reopen as read-only history, delete).

Out of scope: streaming token-by-token replies, editing saved threads, the
figure-mention LLM fallback (Plan 7), cloud LLM (the seam allows it later but v1
is Ollama).

---

## 2. Backend (Plan 6a)

- **LLM seam:** `LlmClient` protocol with `reply(messages, context) -> str`, and
  **`OllamaLlmClient`** that POSTs to a local Ollama server
  (`http://localhost:11434/api/chat`, default model `llama3.2:3b`, configurable).
  Behind a cached `get_llm()` dependency (overridden by a fake in tests).
- **`POST /chat`** — body `{messages: [{role, text}], context: {passage,
  figureCaption?, bookTitle, chapterTitle}}` where `context` is the snapshot
  attached to the **latest** user message (the passage being narrated when it was
  sent). Builds a grounded system prompt ("You are discussing this passage from
  {book}/{chapter}: … Answer using it; say if it's not covered.") + the message
  history, calls the LLM, returns `{reply}`.
- **`POST /speak`** — `{text}` → `ChatterboxSynth` → MP3 bytes
  (`audio/mpeg`). Reuses the existing synth + `audio_io`. The opt-in
  read-the-answer-aloud path.
- New backend dep: `httpx` (call Ollama). Ollama itself runs as a separate local
  process the user starts (`ollama serve` + `ollama pull llama3.2:3b`); documented,
  not bundled.

---

## 3. Client data + logic (Plan 6a)

- **`BackendClient.chat(List<ChatMessage> messages, ChatContext context) ->
  Future<String>`** and **`speak(String text) -> Future<List<int>>`** (+ fakes
  with throw hooks).
- **`ChatMessage`** model (`role` `user|assistant`, `text`) and **`ChatContext`**
  (`passage`, `figureCaption?`, `bookTitle`, `chapterTitle`).
- **`ChatController`** (Riverpod `ChangeNotifier`/Notifier, **in-memory**): holds
  `List<ChatMessage>` + a `sending` flag; constructed with a `ChatContext
  Function()` `contextSnapshot` that reads the *live* passage (current paragraph +
  window + active figure) at call time. `sendMessage(text)` appends the user
  message, calls `backend.chat(messages, contextSnapshot())` — snapshotting the
  passage **at send time** — appends the assistant reply; on backend failure
  appends an error/marker the UI can retry. **Nothing is persisted here.**
- **Drift `ChatThreads`** (`id`, `bookId`, `chapterIndex`, `anchorBlockId?`,
  `title?`, `createdAt`) + **`ChatMessages`** (`id`, `threadId`, `role`, `text`,
  `createdAt`); schema migration 2→3 (`createTable` both). Multiple threads per
  `(bookId, chapterIndex)` are allowed.
- **`ChatRepository`** (persistence only): `saveThread({bookId, chapterIndex,
  anchorBlockId, title, messages}) -> Future<String>` always inserts a **new**
  thread + its messages in a transaction (one per Save), `watchThreads`,
  `watchMessages(threadId)`, `getThreadMessages`, `deleteThread`.

---

## 4. UI (Plan 6b)

- **Record button → dual gesture:** switch the hold-to-record from
  `onTapDown/onTapUp` to **`onLongPressStart/onLongPressEnd`** so it coexists with
  **`onDoubleTap` → open the Discuss panel**. Double-tap does not touch playback.
- **Discuss panel** (a bottom sheet / route over the player; **chapter playback
  continues**):
  - Chat transcript (user/assistant bubbles) from the `ChatController`.
  - Input row: a **TextField (default focus)** + **Send**, and a secondary
    **hold-to-talk mic** that records → `/transcribe` → drops the text into the
    field for review/send.
  - Each assistant bubble: text + a **speaker** icon → `BackendClient.speak` →
    play the returned audio on the **separate aux/memo handler**
    (`memoAudioHandlerProvider`).
  - **Pause-on-audio-conflict (client-side only):** opening the panel does NOT
    pause the chapter, but two concrete in-panel actions DO — (a) tapping the
    **speaker** to hear a reply aloud, and (b) **voice-typing** a question
    (hold-to-talk recording). While either is active the chapter playback is
    paused so the streams don't overlap, and resumes afterward **if it was
    playing**. This is purely client-side (the `PlayerController`); the backend
    is unaware.
  - A **Save** button persists the thread (`ChatRepository.saveThread`) with the
    captured book/chapter/anchor; a "saved" confirmation. Closing without Save
    discards the conversation.
- **Conversations screen** (top-level; a library app-bar icon next to Notes):
  `watchThreads` list (book · chapter · title/snippet); tap → a read-only thread
  view (`watchMessages`); delete.

---

## 5. Architecture & boundaries

- The LLM is a new seam (`LlmClient`) mirroring the TTS/transcriber seams; the
  figure-mention fallback (Plan 7) reuses it. `BackendClient` gains `chat`/`speak`.
- **Live conversation (`ChatController`, ephemeral) is cleanly separated from
  persistence (`ChatRepository`, save-on-demand).** The panel composes both; the
  Conversations screen only reads persistence.
- Reply audio uses the existing `memoAudioHandlerProvider` (separate from the
  chapter player), so speaking an answer never disturbs the running narration.
- Context is **snapshotted per user message** (the paragraph being read + window +
  active figure caption at send time), so a thread stays coherent as playback
  advances and follow-ups are grounded on what's being read then. The thread's
  `anchorBlockId` records where Discuss was opened, for reference.

---

## 6. Error handling

- **Ollama not running / `/chat` fails:** the assistant turn shows an error
  bubble with Retry; the conversation and prior turns are intact.
- **`/speak` fails or backend down:** the text answer stays; the speaker button
  shows a brief error, no crash.
- **`/transcribe` fails for a spoken question:** fall back to the text field (the
  user can type); no lost panel state.
- **Save with an empty conversation:** Save is disabled until there's at least one
  exchange.
- **Deleted thread / missing data:** Conversations handles empty/missing
  gracefully.

---

## 7. Testing

- **Backend (pytest):** `/chat` returns the fake `LlmClient`'s reply for a posted
  conversation+context (no Ollama in CI); `/speak` returns audio bytes via a fake
  synth; prompt-building includes the passage.
- **Client unit (6a):** `ChatController.sendMessage` appends user+assistant turns
  via a fake `BackendClient` and surfaces a failure turn; `ChatRepository.saveThread`
  persists thread+messages (and only on call), `watchThreads`/`watchMessages`
  ordering, `deleteThread`; a 2→3 migration test (fabricate a v2 DB, open at v3,
  assert chat tables exist + prior data survives).
- **Client widget (6b):** double-tapping the record button opens the panel and
  does **not** pause the controller; typing + Send appends bubbles and calls the
  repo's chat path; the speaker button calls `speak` on the aux handler; Save
  persists a thread; Conversations lists saved threads and opens one. (Stream
  overrides / in-memory patterns as before.)
- **Manual gate:** with the backend + `ollama serve` running, double-tap record
  mid-playback, ask a question about the passage (typed), confirm a grounded answer
  while audio continues, read it aloud, Save, and find it under Conversations.

---

## 8. Build order

**Plan 6a:** (1) backend LLM seam + `/chat`; (2) backend `/speak`; (3) client
`BackendClient.chat/speak` + `ChatMessage`/`ChatContext` + fakes; (4)
`ChatThreads`/`ChatMessages` tables + 2→3 migration + `ChatRepository`; (5)
`ChatController` (live conversation).

**Plan 6b:** (6) record button dual gesture (long-press + double-tap); (7) Discuss
panel (chat, keyboard input + hold-to-talk, speak, Save); (8) Conversations screen
+ library entry point; (9) manual macOS + Ollama verification.
