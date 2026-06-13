# Narrator Voice Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the reader choose a narrator voice per book from a curated catalog (with bundled previews), re-narrating chapters lazily-on-play or via an explicit hold-to-re-render.

**Architecture:** Backend already routes `?engine=`; add `?voice=` and derive Kokoro's language from the voice prefix, sharing one `KPipeline` per language. The Swift client owns a static voice catalog, stores the choice on `Book` (SwiftData), threads it through the chapter download, stamps the voice each `chapter.mp3` was rendered in, and surfaces a "Narrator" cluster control opening a voice-list panel.

**Tech Stack:** Python 3.13 / FastAPI / pytest (backend); Swift 6 / SwiftUI / SwiftData / Swift Testing (client).

**Source spec:** `docs/superpowers/specs/2026-06-13-vimarsha-voice-selection-design.md`

**Conventions:** TDD (failing test → minimal impl → green → commit). Four chunks (A–D); each ends with a `--no-ff` merge to `main` and a push. Backend tests: `cd backend && uv run pytest`. Client tests: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' test`. Every commit carries the trailer `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

**Branch for chunk A:** `git checkout main && git checkout -b feat/voice-backend`

---

## Chunk A — Backend `?voice=` + Kokoro language-from-prefix

### Task A1: Pure language-from-voice helper

**Files:**
- Modify: `backend/src/vimarsha/tts.py` (add `kokoro_lang` near `KokoroSynth`)
- Test: `backend/tests/test_tts_engine.py`

- [ ] **Step 1: Write the failing test** — append to `backend/tests/test_tts_engine.py`:

```python
from vimarsha.tts import kokoro_lang


def test_kokoro_lang_from_voice_prefix():
    assert kokoro_lang("af_heart") == "a"   # American
    assert kokoro_lang("am_michael") == "a"
    assert kokoro_lang("bf_emma") == "b"     # British
    assert kokoro_lang("bm_george") == "b"
    assert kokoro_lang("") == "a"            # empty → default American
    assert kokoro_lang("B_weird") == "b"     # case-insensitive prefix
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_tts_engine.py::test_kokoro_lang_from_voice_prefix -q`
Expected: FAIL — `ImportError: cannot import name 'kokoro_lang'`.

- [ ] **Step 3: Write minimal implementation** — add to `backend/src/vimarsha/tts.py` ABOVE `class KokoroSynth`:

```python
def kokoro_lang(voice: str) -> str:
    """Kokoro encodes language in the voice prefix: 'b*' = British English, everything
    else = American English. (See Kokoro voice naming: <lang><gender>_<name>.)"""
    return "b" if voice[:1].lower() == "b" else "a"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_tts_engine.py::test_kokoro_lang_from_voice_prefix -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/tts.py backend/tests/test_tts_engine.py
git commit -m "feat(backend): kokoro_lang — derive language from voice prefix

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task A2: KokoroSynth uses per-voice language + shared pipeline cache

**Files:**
- Modify: `backend/src/vimarsha/tts.py` (`KokoroSynth.__init__`)

- [ ] **Step 1: Replace `KokoroSynth.__init__`** in `backend/src/vimarsha/tts.py`. The current body resolves device (mps→cpu) then builds `KPipeline(lang_code=lang_code, device=…)`. Replace the whole `__init__` with this (note: `lang_code` is now derived from `voice`, and the `KPipeline` is shared per `(device, lang)` so a synth-per-voice is cheap):

```python
class KokoroSynth:
    """Kokoro-82M TTS adapter (StyleTTS2-based) — far faster than autoregressive Chatterbox.

    Same ``Synthesizer`` contract (mono float32 @ ``sample_rate``); swappable per-request via
    ``VIMARSHA_TTS=kokoro``. Requires the ``[kokoro]`` extra. Lazily imports ``kokoro`` so the
    rest of the package runs without it. Kokoro renders at 24 kHz.
    """

    sample_rate = 24000
    # Shared KPipeline per (device, lang) — the model loads once per language, not per voice,
    # so the server can cache a cheap KokoroSynth per (engine, voice).
    _pipelines: dict[tuple[str, str], object] = {}

    def __init__(
        self,
        voice: str = "af_heart",
        device: str | None = None,
        speed: float = 1.0,
    ):
        from kokoro import KPipeline

        resolved = _pick_device(device)
        # Kokoro's iSTFT vocoder calls ``aten::angle``, which Apple's MPS backend doesn't
        # implement (pytorch#141287) — it crashes there. Kokoro-82M is small, so on MPS we run
        # on CPU (still near real-time). CUDA, the production target, is unaffected.
        if resolved == "mps":
            resolved = "cpu"
        self._device = resolved
        self._voice = voice
        self._speed = speed
        lang_code = kokoro_lang(voice)
        key = (resolved, lang_code)
        pipe = KokoroSynth._pipelines.get(key)
        if pipe is None:
            pipe = KPipeline(lang_code=lang_code, device=resolved)
            KokoroSynth._pipelines[key] = pipe
        self._pipeline = pipe
```

(Leave `KokoroSynth.synthesize` unchanged — it already uses `self._voice`.)

- [ ] **Step 2: Verify nothing imports the old `lang_code`/`audio_prompt` kwargs** — `cd backend && rg -n "KokoroSynth\(" src tests` should show only no-arg or `voice=`/`device=` constructions. Expected: only the registry in `tts.py` and tests construct it; none pass `lang_code=`.

- [ ] **Step 3: Run the full suite to confirm no regressions** (the model isn't loaded by unit tests):

Run: `cd backend && uv run pytest -q`
Expected: PASS (same count as before; no test constructs a real `KokoroSynth`).

- [ ] **Step 4: Commit**

```bash
git add backend/src/vimarsha/tts.py
git commit -m "feat(backend): KokoroSynth derives lang from voice + shares one pipeline per language

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task A3: `voice` ctor arg on Chatterbox + per-(engine,voice) server cache

**Files:**
- Modify: `backend/src/vimarsha/tts.py` (`ChatterboxSynth.__init__` accepts `voice`)
- Modify: `backend/src/vimarsha/server.py` (`_cached_synth`, `synth_for`, `_resolve_synth`)
- Test: `backend/tests/test_tts_engine.py`

- [ ] **Step 1: Write the failing test** — replace the existing `test_synth_for_override_caches_per_engine` in `backend/tests/test_tts_engine.py` with the voice-aware version, and add a per-voice-distinct test:

```python
def test_synth_for_passes_voice_and_caches_per_engine_and_voice(monkeypatch):
    """A per-request (engine, voice) builds a cached instance carrying that voice; blank
    engine+voice keeps the injected default."""
    import vimarsha.server as server

    class _RecordingFake:
        sample_rate = 16000

        def __init__(self, voice=None):
            self.voice = voice

        def synthesize(self, text):  # noqa: ARG002
            import numpy as np
            return np.zeros(1, dtype=np.float32)

    default = _RecordingFake(voice="default")
    server._synth_cache.clear()
    monkeypatch.setattr(server, "synth_class", lambda name: _RecordingFake)
    try:
        # blank engine+voice → the injected default, unchanged
        assert server.synth_for(None, None, default) is default
        # a voice builds a fake carrying it, stable per (engine, voice)
        a = server.synth_for("kokoro", "af_bella", default)
        assert a.voice == "af_bella"
        assert server.synth_for("kokoro", "af_bella", default) is a   # cached
        # a different voice is a different cached instance
        b = server.synth_for("kokoro", "bm_george", default)
        assert b is not a and b.voice == "bm_george"
    finally:
        server._synth_cache.clear()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_tts_engine.py::test_synth_for_passes_voice_and_caches_per_engine_and_voice -q`
Expected: FAIL — `synth_for()` takes 2 positional args, not 3.

- [ ] **Step 3a: Give `ChatterboxSynth` a `voice` kwarg** — change its signature in `backend/src/vimarsha/tts.py` from:

```python
    def __init__(self, device: str | None = None, audio_prompt_path: str | None = None):
```

to (accept and ignore `voice` so the uniform factory works; Chatterbox's single voice is unaffected):

```python
    def __init__(
        self,
        voice: str | None = None,  # accepted for a uniform factory; Chatterbox has one voice
        device: str | None = None,
        audio_prompt_path: str | None = None,
    ):
```

- [ ] **Step 3b: Make the server cache key on `(engine, voice)`** — in `backend/src/vimarsha/server.py` replace `_cached_synth` and `synth_for` with:

```python
def _cached_synth(engine: str | None, voice: str | None) -> Synthesizer:
    cls = synth_class(engine)  # raises ValueError on an unknown name
    key = f"{cls.__name__}:{voice or ''}"
    if key not in _synth_cache:
        _synth_cache[key] = cls(voice=voice) if voice else cls()
    return _synth_cache[key]


def get_synth() -> Synthesizer:
    """The default-engine synth (``VIMARSHA_TTS`` → ``vimarsha.tts.synth_class``); cached and
    dependency-injected so tests can override it with a fake."""
    return _cached_synth(os.environ.get("VIMARSHA_TTS"), None)


def synth_for(engine: str | None, voice: str | None, default: Synthesizer) -> Synthesizer:
    """Per-request engine/voice override (the client picks via ``?engine=`` / ``?voice=``).
    Blank engine AND voice keep the injected ``default`` (so the env default and test overrides
    win); otherwise a cached instance for that (engine, voice). Raises ``ValueError`` on an
    unknown engine name."""
    if not (engine and engine.strip()) and not (voice and voice.strip()):
        return default
    return _cached_synth(engine, voice)
```

- [ ] **Step 3c: Thread `voice` through the resolver** — in `backend/src/vimarsha/server.py` replace `_resolve_synth` with:

```python
def _resolve_synth(engine: str | None, voice: str | None, default: Synthesizer) -> Synthesizer:
    try:
        return synth_for(engine, voice, default)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from None
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_tts_engine.py::test_synth_for_passes_voice_and_caches_per_engine_and_voice -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/tts.py backend/src/vimarsha/server.py backend/tests/test_tts_engine.py
git commit -m "feat(backend): per-(engine,voice) synth cache + uniform voice ctor

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task A4: `?voice=` on `/import` and `/speak`

**Files:**
- Modify: `backend/src/vimarsha/server.py` (`import_chapter`, `speak` signatures + `_resolve_synth` calls)
- Test: `backend/tests/test_tts_engine.py`

- [ ] **Step 1: Write the failing test** — append to `backend/tests/test_tts_engine.py`:

```python
def test_speak_threads_voice_to_synth(monkeypatch):
    """POST /speak?engine=kokoro&voice=af_bella builds a synth carrying that voice."""
    from fastapi.testclient import TestClient
    import vimarsha.server as server

    class _RecordingFake:
        sample_rate = 16000

        def __init__(self, voice=None):
            self.voice = voice
            _RecordingFake.last_voice = voice

        def synthesize(self, text):  # noqa: ARG002
            import numpy as np
            return np.ones(8000, dtype=np.float32) * 0.01

    server._synth_cache.clear()
    monkeypatch.setattr(server, "synth_class", lambda name: _RecordingFake)
    server.app.dependency_overrides[server.get_synth] = lambda: _RecordingFake(voice="default")
    try:
        client = TestClient(server.app)
        resp = client.post("/speak?engine=kokoro&voice=af_bella", json={"text": "hello there"})
        assert resp.status_code == 200
        assert _RecordingFake.last_voice == "af_bella"
    finally:
        server.app.dependency_overrides.clear()
        server._synth_cache.clear()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_tts_engine.py::test_speak_threads_voice_to_synth -q`
Expected: FAIL — `/speak` ignores `voice`, so `last_voice` is never `af_bella` (assertion fails).

- [ ] **Step 3a: Add `voice` to `/import`** — in `backend/src/vimarsha/server.py` change the `import_chapter` signature and resolve call:

```python
@app.post("/import")
async def import_chapter(
    chapter_index: int = 0,
    engine: str | None = None,
    voice: str | None = None,
    file: UploadFile = File(...),
    synth: Synthesizer = Depends(get_synth),
):
    synth = _resolve_synth(engine, voice, synth)
    data = await file.read()
```

- [ ] **Step 3b: Add `voice` to `/speak`** — change the `speak` signature and resolve call:

```python
@app.post("/speak")
async def speak(
    req: SpeakRequest,
    engine: str | None = None,
    voice: str | None = None,
    synth: Synthesizer = Depends(get_synth),
):
    synth = _resolve_synth(engine, voice, synth)
    if not req.text.strip():
        raise HTTPException(status_code=400, detail="empty text")
```

- [ ] **Step 4: Run the full suite**

Run: `cd backend && uv run pytest -q`
Expected: PASS (all, including the new voice test and the existing `test_speak_rejects_unknown_engine`).

- [ ] **Step 5: Commit**

```bash
git add backend/src/vimarsha/server.py backend/tests/test_tts_engine.py
git commit -m "feat(backend): ?voice= on /import and /speak

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task A5: Merge chunk A

- [ ] **Step 1: Confirm green** — `cd backend && uv run pytest -q` → PASS.
- [ ] **Step 2: Merge + push**

```bash
git checkout main
git merge --no-ff feat/voice-backend -m "Merge: backend ?voice= + Kokoro language-from-prefix

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin main
```

---

## Chunk B — Voice catalog, persistence, preview clips

**Branch:** `git checkout -b feat/voice-catalog`

### Task B1: The voice catalog

**Files:**
- Create: `apple/Vimarsha/Library/NarratorVoice.swift`
- Test: `apple/VimarshaTests/NarratorVoiceTests.swift`

- [ ] **Step 1: Write the failing test** — create `apple/VimarshaTests/NarratorVoiceTests.swift`:

```swift
import Testing
@testable import Vimarsha

@Suite("Narrator voice catalog")
struct NarratorVoiceTests {
    @Test func catalogHasDistinctVoicesAndADefault() {
        let ids = VoiceCatalog.all.map(\.id)
        #expect(ids.count >= 5)
        #expect(Set(ids).count == ids.count)                       // unique display names
        #expect(ids.contains(VoiceCatalog.defaultId))              // default is in the catalog
        #expect(VoiceCatalog.defaultId == "Aria")
        #expect(VoiceCatalog.all.allSatisfy { $0.engine == "kokoro" })
    }

    @Test func voiceLookupFallsBackToDefault() {
        #expect(VoiceCatalog.voice(id: "Imogen").kokoroVoice == "bf_emma")
        #expect(VoiceCatalog.voice(id: "nonexistent").id == VoiceCatalog.defaultId)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/NarratorVoiceTests test 2>&1 | grep -E "error:|TEST"`
Expected: build error — `Cannot find 'VoiceCatalog' in scope`.

- [ ] **Step 3: Write minimal implementation** — create `apple/Vimarsha/Library/NarratorVoice.swift`:

```swift
import Foundation

/// One selectable narrator voice. Display name (`id`) is the global name the reader sees;
/// `kokoroVoice` is the backend voice token sent as `?voice=`; `engine` is hidden from the UI
/// (all Kokoro for v1). `previewResource` is the bundled preview clip's base name.
nonisolated struct NarratorVoice: Identifiable, Equatable, Sendable {
    let id: String          // e.g. "Aria"
    let kokoroVoice: String // e.g. "af_heart"
    let engine: String      // "kokoro"

    /// `Resources/VoicePreviews/<kokoroVoice>.mp3` — keyed on the stable backend token so a
    /// rename of the display name never orphans a clip.
    var previewResource: String { kokoroVoice }
}

/// The curated, client-owned catalog (the single source of truth for names + default).
nonisolated enum VoiceCatalog {
    static let all: [NarratorVoice] = [
        NarratorVoice(id: "Aria",   kokoroVoice: "af_heart",   engine: "kokoro"),
        NarratorVoice(id: "Stella", kokoroVoice: "af_bella",   engine: "kokoro"),
        NarratorVoice(id: "Milo",   kokoroVoice: "am_michael", engine: "kokoro"),
        NarratorVoice(id: "Imogen", kokoroVoice: "bf_emma",    engine: "kokoro"),
        NarratorVoice(id: "Edmund", kokoroVoice: "bm_george",  engine: "kokoro"),
    ]

    static let defaultId = "Aria"

    static func voice(id: String) -> NarratorVoice {
        all.first { $0.id == id } ?? all.first { $0.id == defaultId } ?? all[0]
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/NarratorVoiceTests test 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)"`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Library/NarratorVoice.swift apple/VimarshaTests/NarratorVoiceTests.swift
git commit -m "feat(apple): curated narrator-voice catalog

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task B2: Persist the choice — `Book.voiceId` + `Chapter.narratedVoiceId`

**Files:**
- Modify: `apple/Vimarsha/Persistence/Models.swift` (`Book`, `Chapter`)
- Test: `apple/VimarshaTests/VoicePersistenceTests.swift`

> **SwiftData note:** both new properties have safe defaults (`voiceId` a stored default, `narratedVoiceId` optional), so SwiftData performs an automatic **lightweight** migration of an existing on-disk store — no `VersionedSchema`/`MigrationPlan` needed. The test below verifies the defaults a migrated/new row gets. (A true old-store fabrication isn't practical under SwiftData the way it was for Drift; the defaulted/optional columns are the migration-safety mechanism.)

- [ ] **Step 1: Write the failing test** — create `apple/VimarshaTests/VoicePersistenceTests.swift`:

```swift
import Testing
import SwiftData
@testable import Vimarsha

@Suite("Voice persistence defaults")
struct VoicePersistenceTests {
    @MainActor
    private func newContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Book.self, Chapter.self, Memo.self, ChatThread.self, ChatLine.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return container.mainContext
    }

    @MainActor
    @Test func newBookDefaultsToAria() throws {
        let ctx = try newContext()
        let book = Book(title: "T", author: "A", epubPath: "p")
        ctx.insert(book)
        #expect(book.voiceId == "Aria")
    }

    @MainActor
    @Test func newChapterHasNoNarratedVoiceYet() throws {
        let ctx = try newContext()
        let ch = Chapter(index: 0, title: "Ch")
        ctx.insert(ch)
        #expect(ch.narratedVoiceId == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/VoicePersistenceTests test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: build error — `value of type 'Book' has no member 'voiceId'`.

- [ ] **Step 3a: Add `voiceId` to `Book`** — in `apple/Vimarsha/Persistence/Models.swift`, add the stored property (after `var lastOpenedAt: Date?`):

```swift
    /// The chosen narrator voice id (`VoiceCatalog` display name). Defaulted so adding it is a
    /// SwiftData lightweight migration; existing books open as "Aria".
    var voiceId: String = VoiceCatalog.defaultId
```

- [ ] **Step 3b: Add `narratedVoiceId` to `Chapter`** — add (after `var audioPath: String?`):

```swift
    /// The voice the cached `chapter.mp3` was rendered in; nil until first narrated. When it
    /// differs from the owning book's `voiceId`, the cached audio is stale (re-render needed).
    var narratedVoiceId: String?
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/VoicePersistenceTests test 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)"`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Persistence/Models.swift apple/VimarshaTests/VoicePersistenceTests.swift
git commit -m "feat(apple): persist Book.voiceId + Chapter.narratedVoiceId (lightweight migration)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task B3: Stale predicate

**Files:**
- Create: `apple/Vimarsha/Library/ChapterStaleness.swift`
- Test: `apple/VimarshaTests/ChapterStalenessTests.swift`

- [ ] **Step 1: Write the failing test** — create `apple/VimarshaTests/ChapterStalenessTests.swift`:

```swift
import Testing
@testable import Vimarsha

@Suite("Chapter staleness vs selected voice")
struct ChapterStalenessTests {
    @Test func readyChapterIsStaleWhenVoiceDiffers() {
        #expect(ChapterStaleness.isStale(status: .ready, narratedVoiceId: "Aria", bookVoiceId: "Milo"))
        #expect(!ChapterStaleness.isStale(status: .ready, narratedVoiceId: "Milo", bookVoiceId: "Milo"))
    }

    @Test func nonReadyChaptersAreNeverStale() {
        // none/pending/error have nothing cached to be stale.
        #expect(!ChapterStaleness.isStale(status: .none, narratedVoiceId: nil, bookVoiceId: "Milo"))
        #expect(!ChapterStaleness.isStale(status: .pending, narratedVoiceId: "Aria", bookVoiceId: "Milo"))
        #expect(!ChapterStaleness.isStale(status: .error, narratedVoiceId: "Aria", bookVoiceId: "Milo"))
    }

    @Test func readyWithNilNarratedVoiceIsNotStale() {
        // Pre-voice cached audio (nil) is treated as matching — never force a surprise re-render
        // of chapters narrated before this feature existed.
        #expect(!ChapterStaleness.isStale(status: .ready, narratedVoiceId: nil, bookVoiceId: "Milo"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/ChapterStalenessTests test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: build error — `Cannot find 'ChapterStaleness' in scope`.

- [ ] **Step 3: Write minimal implementation** — create `apple/Vimarsha/Library/ChapterStaleness.swift`:

```swift
import Foundation

/// Whether a cached chapter's audio no longer matches the book's selected voice. Pure so it's
/// unit-testable and usable from both the chapter list (hint + hold-to-re-render) and the
/// open/play path (lazy re-render).
nonisolated enum ChapterStaleness {
    static func isStale(status: ChapterStatus, narratedVoiceId: String?, bookVoiceId: String) -> Bool {
        // Only a READY chapter has cached audio that can be stale. A nil narratedVoiceId is
        // pre-voice audio — treat as matching so we never surprise-re-render old chapters.
        guard status == .ready, let narrated = narratedVoiceId else { return false }
        return narrated != bookVoiceId
    }
}

extension Chapter {
    /// Convenience over the pure predicate using the owning book's selected voice.
    var isStaleForBookVoice: Bool {
        guard let book else { return false }
        return ChapterStaleness.isStale(
            status: status, narratedVoiceId: narratedVoiceId, bookVoiceId: book.voiceId
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/ChapterStalenessTests test 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)"`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Library/ChapterStaleness.swift apple/VimarshaTests/ChapterStalenessTests.swift
git commit -m "feat(apple): pure stale-vs-voice predicate for chapters

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task B4: Generate + bundle the preview clips

**Files:**
- Create: `apple/Vimarsha/Resources/VoicePreviews/af_heart.mp3`, `af_bella.mp3`, `am_michael.mp3`, `bf_emma.mp3`, `bm_george.mp3`
- Modify: `apple/Vimarsha.xcodeproj` (ensure the folder is in the app target's bundle resources — folder-synchronized, so dropping files in should suffice; verify in step 3)
- Test: `apple/VimarshaTests/VoicePreviewResourceTests.swift`

- [ ] **Step 1: Write the failing test** — create `apple/VimarshaTests/VoicePreviewResourceTests.swift`:

```swift
import Testing
import Foundation
@testable import Vimarsha

@Suite("Bundled voice previews")
struct VoicePreviewResourceTests {
    @Test func everyVoiceHasABundledPreviewClip() {
        for voice in VoiceCatalog.all {
            let url = Bundle.main.url(
                forResource: voice.previewResource, withExtension: "mp3", subdirectory: "VoicePreviews"
            ) ?? Bundle.main.url(forResource: voice.previewResource, withExtension: "mp3")
            #expect(url != nil, "missing preview clip for \(voice.id) (\(voice.previewResource).mp3)")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/VoicePreviewResourceTests test 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)"`
Expected: `** TEST FAILED **` (no clips bundled yet).

- [ ] **Step 3: Generate the clips** — the Kokoro backend must be running with the `[kokoro]` extra (`cd backend && VIMARSHA_TTS=kokoro uv run uvicorn vimarsha.server:app --port 8000 &`). Then, from the repo root:

```bash
mkdir -p apple/Vimarsha/Resources/VoicePreviews
SAMPLE='In the quiet between chapters, a voice begins to read.'
for v in af_heart af_bella am_michael bf_emma bm_george; do
  curl -s -X POST "http://localhost:8000/speak?engine=kokoro&voice=$v" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"$SAMPLE\"}" \
    -o "apple/Vimarsha/Resources/VoicePreviews/$v.mp3"
  echo "$v -> $(stat -f%z apple/Vimarsha/Resources/VoicePreviews/$v.mp3) bytes"
done
```

Expected: five non-trivial `.mp3` files (tens of KB each). Confirm each plays (`afplay apple/Vimarsha/Resources/VoicePreviews/af_heart.mp3`).

- [ ] **Step 4: Verify they land in the app bundle** — the Xcode project is folder-synchronized, but **bundle resources** sometimes need the folder added as a resource reference. Build and re-run the test:

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/VoicePreviewResourceTests test 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)"`
Expected: `** TEST SUCCEEDED **`. If it still fails, the folder isn't being copied — in Xcode add `Vimarsha/Resources/VoicePreviews` to the Vimarsha target's "Copy Bundle Resources" build phase (as a folder reference), then re-run.

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Resources/VoicePreviews apple/VimarshaTests/VoicePreviewResourceTests.swift apple/Vimarsha.xcodeproj
git commit -m "feat(apple): bundle per-voice preview clips

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task B5: Merge chunk B

- [ ] **Step 1: Full client suite green** — `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' test 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)"` → SUCCEEDED.
- [ ] **Step 2: Merge + push**

```bash
git checkout main
git merge --no-ff feat/voice-catalog -m "Merge: voice catalog + persistence + preview clips

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin main
```

---

## Chunk C — Download path: voice threading, stamping, re-render

**Branch:** `git checkout -b feat/voice-download`

### Task C1: Client sends `voice` on `/import`

**Files:**
- Modify: `apple/Vimarsha/Backend/BackendClient.swift` (protocol + impl + `importURL`)
- Modify: `apple/Vimarsha/Backend/ChapterDownloader.swift` (`download` gains `voice:`)
- Test: `apple/VimarshaTests/BackendClientTests.swift`

> The current client sends a fixed `engine = "kokoro"`. Voice is **per-book**, so it must be a
> per-call argument (not a client-wide property). We add `voice:` to `importChapter` and
> `ChapterDownloader.download`, and derive the engine from the catalog entry.

- [ ] **Step 1: Write the failing test** — replace `importURLCarriesTheEngineWhenSet` in `apple/VimarshaTests/BackendClientTests.swift` and add a voice case:

```swift
    @Test func importURLCarriesEngineAndVoiceWhenSet() {
        let url = URLSessionBackendClient.importURL(
            baseURL: URL(string: "http://localhost:8000")!,
            chapterIndex: 3, engine: "kokoro", voice: "bf_emma"
        )
        #expect(url.absoluteString
            == "http://localhost:8000/import?chapter_index=3&engine=kokoro&voice=bf_emma")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/BackendClientTests test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: build error — extra argument `voice` in call to `importURL`.

- [ ] **Step 3a: Extend `importURL`** — in `apple/Vimarsha/Backend/BackendClient.swift` replace `importURL`:

```swift
    /// `chapter_index` (and optional `engine`/`voice`) ride as query parameters (the FastAPI
    /// signature), not form data.
    static func importURL(
        baseURL: URL, chapterIndex: Int, engine: String? = nil, voice: String? = nil
    ) -> URL {
        var items = [URLQueryItem(name: "chapter_index", value: "\(chapterIndex)")]
        if let engine, !engine.isEmpty { items.append(URLQueryItem(name: "engine", value: engine)) }
        if let voice, !voice.isEmpty { items.append(URLQueryItem(name: "voice", value: voice)) }
        return baseURL.appending(path: "import").appending(queryItems: items)
    }
```

- [ ] **Step 3b: Add `voice` to the protocol + impl** — in `BackendClient.swift`, change the protocol method:

```swift
    /// `POST /import?chapter_index=N&engine=…&voice=…` — narrate ONE chapter → the full
    /// `ChapterBundle`. `engine`/`voice` are the per-book narrator selection.
    func importChapter(epubAt url: URL, chapterIndex: Int, engine: String?, voice: String?) async throws -> ChapterBundleDTO
```

and the `URLSessionBackendClient` implementation (replacing the existing `importChapter` and removing the now-unused `engine` stored property — engine comes per call):

```swift
    func importChapter(
        epubAt url: URL, chapterIndex: Int, engine: String?, voice: String?
    ) async throws -> ChapterBundleDTO {
        try JSONDecoder().decode(
            ChapterBundleDTO.self,
            from: try await uploadEpub(
                at: url,
                to: Self.importURL(baseURL: baseURL, chapterIndex: chapterIndex,
                                   engine: engine, voice: voice)
            )
        )
    }
```

Delete the `var engine: String? = "kokoro"` stored property and its doc comment (engine is now passed per call). Update `speak` to take engine/voice params too:

```swift
    func speak(text: String, engine: String?, voice: String?) async throws -> Data {
        var items: [URLQueryItem] = []
        if let engine, !engine.isEmpty { items.append(URLQueryItem(name: "engine", value: engine)) }
        if let voice, !voice.isEmpty { items.append(URLQueryItem(name: "voice", value: voice)) }
        var url = baseURL.appending(path: "speak")
        if !items.isEmpty { url = url.appending(queryItems: items) }
        let request = try Self.jsonRequest(url: url, body: SpeakRequestBody(text: text))
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        return data
    }
```

and update the protocol's `speak` declaration:

```swift
    /// `POST /speak?engine=…&voice=…` — arbitrary text → MP3 bytes in the chosen voice.
    func speak(text: String, engine: String?, voice: String?) async throws -> Data
```

- [ ] **Step 3c: Thread `voice` through `ChapterDownloader`** — in `apple/Vimarsha/Backend/ChapterDownloader.swift` change `download` and the `importChapter` call:

```swift
    func download(
        epubRelativePath: String, bookId: UUID, chapterIndex: Int, engine: String?, voice: String?
    ) async throws -> CachedChapter {
        let chapterRelativePath = "Library/Books/\(bookId.uuidString)/chapters/\(chapterIndex)"
        let chapterDir = containerRoot.appending(path: chapterRelativePath)
        let fm = FileManager.default
        do {
            let bundle = try await backend.importChapter(
                epubAt: containerRoot.appending(path: epubRelativePath),
                chapterIndex: chapterIndex, engine: engine, voice: voice
            )
```

(the rest of `download` is unchanged.)

- [ ] **Step 3d: Fix the call sites** — anything that called the old signatures must be updated (the compiler will list them). Known call sites:
  - `apple/Vimarsha/Library/LibraryStore.swift` `downloadChapter` (updated in C2 below — for now, to keep the build green, pass `engine: nil, voice: nil` to `downloader.download(…)`),
  - any `FakeBackendClient` / test doubles implementing `BackendClient` must add the new `engine`/`voice` params to `importChapter` and `speak`,
  - `ReplySpeaker` (calls `backend.speak`) must pass `engine: nil, voice: nil` for now (book voice is wired into Discuss-speak in a later task if desired; out of scope here → nil keeps the backend default).

Search and fix: `cd apple && rg -n "importChapter\(|\.speak\(|func importChapter|func speak" Vimarsha VimarshaTests`.

- [ ] **Step 4: Run test + build to verify pass**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/BackendClientTests test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: `** TEST SUCCEEDED **` (and no compile errors anywhere — fix any remaining call sites the same way).

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Backend/BackendClient.swift apple/Vimarsha/Backend/ChapterDownloader.swift apple/VimarshaTests
git commit -m "feat(apple): per-call engine+voice on importChapter/speak/download

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task C2: `LibraryStore` downloads in the book's voice + stamps it; adds re-render

**Files:**
- Modify: `apple/Vimarsha/Library/LibraryStore.swift` (`downloadChapter`, new `rerenderChapter`)
- Test: `apple/VimarshaTests/LibraryStoreVoiceTests.swift`

> `FakeBackendClient` (the test double) must record the `voice` it received on `importChapter`.
> If the existing fake doesn't expose it, extend it in this task.

- [ ] **Step 1: Write the failing test** — create `apple/VimarshaTests/LibraryStoreVoiceTests.swift`. (Use the existing in-repo test double pattern; this assumes a `FakeBackendClient` recording `lastImportVoice` — extend whatever fake the other LibraryStore tests use, see `rg -n "BackendClient" VimarshaTests`.)

```swift
import Testing
import SwiftData
@testable import Vimarsha

@Suite("LibraryStore narrates in the book's voice")
struct LibraryStoreVoiceTests {
    @MainActor
    @Test func downloadStampsNarratedVoiceFromBook() async throws {
        let env = try VoiceStoreEnv.make()            // helper: container + store + fake backend + a book/chapter
        env.book.voiceId = "Milo"
        let task = env.store.downloadChapter(env.chapter)
        await task?.value
        #expect(env.fake.lastImportVoice == "am_michael")     // Milo → am_michael
        #expect(env.chapter.status == .ready)
        #expect(env.chapter.narratedVoiceId == "Milo")
    }

    @MainActor
    @Test func rerenderReDownloadsAReadyChapterInCurrentVoice() async throws {
        let env = try VoiceStoreEnv.make()
        env.book.voiceId = "Aria"
        await env.store.downloadChapter(env.chapter)?.value
        #expect(env.chapter.narratedVoiceId == "Aria")
        env.book.voiceId = "Imogen"                            // user switches voice
        #expect(env.chapter.isStaleForBookVoice)
        await env.store.rerenderChapter(env.chapter)?.value
        #expect(env.fake.lastImportVoice == "bf_emma")         // Imogen → bf_emma
        #expect(env.chapter.narratedVoiceId == "Imogen")
        #expect(!env.chapter.isStaleForBookVoice)
    }
}
```

(Provide `VoiceStoreEnv.make()` in the same file — a small helper building an in-memory `ModelContainer`, inserting a `Book` + one `Chapter`, and a `LibraryStore(context:backend:)` with a `FakeBackendClient`. Mirror the setup already used by existing `LibraryStore` tests; reuse their fake if it records the import voice, else add `var lastImportVoice: String?` to it and set it in its `importChapter`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/LibraryStoreVoiceTests test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: build error — `rerenderChapter` / `lastImportVoice` not found.

- [ ] **Step 3a: Thread voice + stamp in `downloadChapter`** — in `apple/Vimarsha/Library/LibraryStore.swift`, inside `downloadChapter`, derive the voice from the book and pass it, then stamp on success. Replace the `downloader.download(…)` call and the success block:

```swift
        let downloader = ChapterDownloader(containerRoot: importer.containerRoot, backend: backend)
        let voice = VoiceCatalog.voice(id: book.voiceId)
        let (epubPath, bookId, index, chapterId, voiceId, kokoroVoice, engine) =
            (book.epubPath, book.id, chapter.index, chapter.id, book.voiceId, voice.kokoroVoice, voice.engine)
        let task = Task { [weak self] in
            do {
                let cached = try await downloader.download(
                    epubRelativePath: epubPath, bookId: bookId, chapterIndex: index,
                    engine: engine, voice: kokoroVoice
                )
                guard let self, !Task.isCancelled else { return }
                chapter.bundlePath = cached.bundleRelativePath
                chapter.audioPath = cached.audioRelativePath
                chapter.narratedVoiceId = voiceId
                chapter.status = .ready
                try? self.context.save()
            } catch {
```

(the `catch` block and `downloadTasks` bookkeeping are unchanged.)

- [ ] **Step 3b: Add `rerenderChapter`** — add to `LibraryStore` (just below `downloadChapter`). It is `downloadChapter` without the none/error guard (re-renders a `ready` chapter too), reusing the same body:

```swift
    /// Re-narrate a chapter in the book's CURRENT voice, regardless of its present status
    /// (hold-to-re-render, or a stale chapter opened). Cancels any in-flight job for it first.
    @discardableResult
    func rerenderChapter(_ chapter: Chapter) -> Task<Void, Never>? {
        guard let book = chapter.book else { return nil }
        downloadTasks[chapter.id]?.cancel()
        chapter.status = .pending
        chapter.errorReason = nil
        try? context.save()

        let downloader = ChapterDownloader(containerRoot: importer.containerRoot, backend: backend)
        let voice = VoiceCatalog.voice(id: book.voiceId)
        let (epubPath, bookId, index, chapterId, voiceId, kokoroVoice, engine) =
            (book.epubPath, book.id, chapter.index, chapter.id, book.voiceId, voice.kokoroVoice, voice.engine)
        let task = Task { [weak self] in
            do {
                let cached = try await downloader.download(
                    epubRelativePath: epubPath, bookId: bookId, chapterIndex: index,
                    engine: engine, voice: kokoroVoice
                )
                guard let self, !Task.isCancelled else { return }
                chapter.bundlePath = cached.bundleRelativePath
                chapter.audioPath = cached.audioRelativePath
                chapter.narratedVoiceId = voiceId
                chapter.status = .ready
                try? self.context.save()
            } catch {
                guard let self, !Task.isCancelled, !(error is CancellationError) else { return }
                chapter.status = .error
                chapter.errorReason = "Narration failed"
                try? self.context.save()
            }
            self?.downloadTasks[chapterId] = nil
        }
        downloadTasks[chapterId] = task
        return task
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/LibraryStoreVoiceTests test 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)"`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Library/LibraryStore.swift apple/VimarshaTests/LibraryStoreVoiceTests.swift
git commit -m "feat(apple): narrate in the book's voice, stamp it, add rerenderChapter

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task C3: Merge chunk C

- [ ] **Step 1: Full client suite green** — `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' test 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)"` → SUCCEEDED.
- [ ] **Step 2: Merge + push**

```bash
git checkout main
git merge --no-ff feat/voice-download -m "Merge: download in book voice + stamp + rerender

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin main
```

---

## Chunk D — UI: Narrator control, voice panel, preview, chapter-list stale hint + hold

**Branch:** `git checkout -b feat/voice-ui`

### Task D1: Add the `.narrator` cluster control

**Files:**
- Modify: `apple/Vimarsha/Library/ControlCluster.swift` (`Control` enum)
- Test: `apple/VimarshaTests/ControlClusterTests.swift`

- [ ] **Step 1: Update the failing test** — in `apple/VimarshaTests/ControlClusterTests.swift`, change the `allCases` assertion to include `.narrator` (find it via `rg -n "allCases" apple/VimarshaTests/ControlClusterTests.swift`):

```swift
        #expect(ControlCluster.Control.allCases == [.play, .narrator, .memo, .conversations])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/ControlClusterTests test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: build error — `Type 'ControlCluster.Control' has no member 'narrator'`.

- [ ] **Step 3: Add the case** — in `apple/Vimarsha/Library/ControlCluster.swift`, update the enum and its `symbol`/`label`:

```swift
    enum Control: Int, CaseIterable, Identifiable, Hashable {
        case play, narrator, memo, conversations

        var id: Int { rawValue }

        var symbol: String {
            switch self {
            case .play: "play.fill"
            case .narrator: "person.wave.2.fill"
            case .memo: "mic.fill"
            case .conversations: "bubble.left.and.bubble.right.fill"
            }
        }

        var label: String {
            switch self {
            case .play: "Play"
            case .narrator: "Narrator"
            case .memo: "Voice notes"
            case .conversations: "Saved discussions"
            }
        }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/ControlClusterTests test 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)"`
Expected: `** TEST SUCCEEDED **`. (`ControlClusterView` reads `Control.allCases` and the per-control `tint` keys only `.play`; the new control renders as a `sky` control automatically — no view change needed.)

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Library/ControlCluster.swift apple/VimarshaTests/ControlClusterTests.swift
git commit -m "feat(apple): add Narrator control to the focus cluster

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task D2: The voice-list panel view

**Files:**
- Create: `apple/Vimarsha/Library/VoicePickerView.swift`
- Create: `apple/Vimarsha/Library/VoicePreviewPlayer.swift`
- Test: `apple/VimarshaTests/VoicePreviewPlayerTests.swift`

- [ ] **Step 1: Write the failing test** (for the preview player's selection logic — the view itself is exercised by the build + snapshot, but the player is unit-testable) — create `apple/VimarshaTests/VoicePreviewPlayerTests.swift`:

```swift
import Testing
import Foundation
@testable import Vimarsha

@Suite("Voice preview player")
@MainActor
struct VoicePreviewPlayerTests {
    final class FakeEngine: AudioEngine {
        var loadedURL: URL?
        var played = false
        var onFinish: (() -> Void)?
        func load(url: URL) throws -> Int { loadedURL = url; return 1000 }
        func play() { played = true }
        func pause() {}
        func stop() {}
        func seek(toMs ms: Int) {}
        func setRate(_ rate: Double) {}
        var positionMs: Int { 0 }
        var durationMs: Int { 1000 }
        var isPlaying: Bool { played }
    }

    @Test func previewLoadsTheBundledClipForTheVoice() throws {
        let engine = FakeEngine()
        let player = VoicePreviewPlayer(engine: engine)
        try player.preview(VoiceCatalog.voice(id: "Aria"))
        #expect(engine.loadedURL?.lastPathComponent == "af_heart.mp3")
        #expect(engine.played)
    }
}
```

> Confirm the real `AudioEngine` protocol members against `apple/Vimarsha/Audio/AudioEngine.swift` (`load(url:) throws -> Int`, `play`, `pause`, `stop`, `seek(toMs:)`, `setRate(_:)`, `positionMs`, `durationMs`, `isPlaying`, `onFinish`) and match the fake to them exactly.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/VoicePreviewPlayerTests test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: build error — `Cannot find 'VoicePreviewPlayer' in scope`.

- [ ] **Step 3a: Implement the preview player** — create `apple/Vimarsha/Library/VoicePreviewPlayer.swift`:

```swift
import Foundation

/// Plays a bundled voice-preview clip through an `AudioEngine`. A lightweight, ephemeral
/// player owned by the voice panel — distinct from the chapter player. The caller pauses
/// chapter narration around a preview (the memo-playback courtesy).
@MainActor
final class VoicePreviewPlayer {
    private let engine: any AudioEngine

    init(engine: any AudioEngine) {
        self.engine = engine
    }

    enum PreviewError: Error { case missingClip(String) }

    /// Load and play the bundled clip for `voice`. Throws if the resource is missing (which
    /// the bundled-resource test prevents in release).
    func preview(_ voice: NarratorVoice) throws {
        let url = Bundle.main.url(
            forResource: voice.previewResource, withExtension: "mp3", subdirectory: "VoicePreviews"
        ) ?? Bundle.main.url(forResource: voice.previewResource, withExtension: "mp3")
        guard let url else { throw PreviewError.missingClip(voice.previewResource) }
        _ = try engine.load(url: url)
        engine.play()
    }

    func stop() { engine.stop() }
}
```

- [ ] **Step 3b: Implement the panel view** — create `apple/Vimarsha/Library/VoicePickerView.swift` (mirrors `ChapterListView`'s glass-plane chrome; rows are catalog voices with a check + a ▶ preview button; a warning notice up top):

```swift
import SwiftUI

/// The narrator-voice picker — a glass-backed list plane that rises within the library surface
/// (the sanctioned morphed-list state, apple/CLAUDE.md §UI map), never a sheet. Mirrors
/// `ChapterListView`'s chrome. Selecting a row sets the book's voice and dismisses; a ▶ button
/// previews the bundled clip. A warning makes the re-download cost of switching explicit.
struct VoicePickerView: View {
    let currentVoiceId: String
    var reduceTransparency: Bool = false
    var onPreview: (NarratorVoice) -> Void = { _ in }
    var onSelect: (NarratorVoice) -> Void = { _ in }
    var onClose: () -> Void = {}

    @ScaledMetric(relativeTo: .title3) private var titleSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.top, 22).padding(.bottom, 10)
            warning.padding(.horizontal, 24).padding(.bottom, 12)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(VoiceCatalog.all) { voice in
                        row(voice)
                        if voice.id != VoiceCatalog.all.last?.id {
                            Divider().overlay(Palette.textPrimary.opacity(0.08))
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 18)
            }
        }
        .frame(maxWidth: 420).frame(maxHeight: 520)
        .background {
            let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
            if reduceTransparency { shape.fill(Palette.surface) }
            else { Color.clear.glassEffect(.regular.tint(Palette.sky.opacity(0.18)), in: shape) }
        }
        .padding(.horizontal, 24)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("NARRATOR")
                .font(.system(size: labelSize, weight: .medium)).tracking(4)
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
            Text("Choose a voice")
                .font(.system(size: titleSize, weight: .regular, design: .serif)).tracking(1)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary.opacity(0.7)).frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .background(Circle().fill(Palette.textPrimary.opacity(0.06)))
            .padding(.trailing, 14)
            .accessibilityLabel("Close voice picker")
        }
    }

    private var warning: some View {
        Text("Changing the voice re-downloads each chapter in the new voice before it plays.")
            .font(.caption2)
            .foregroundStyle(Palette.textPrimary.opacity(0.6))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func row(_ voice: NarratorVoice) -> some View {
        HStack(spacing: 14) {
            Image(systemName: voice.id == currentVoiceId ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 19))
                .foregroundStyle(voice.id == currentVoiceId ? Palette.aqua.opacity(0.9) : Palette.textPrimary.opacity(0.3))
            Text(voice.id)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 12)
            Button { onPreview(voice) } label: {
                Image(systemName: "play.circle").font(.system(size: 19)).foregroundStyle(Palette.sky)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview \(voice.id)")
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(voice) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(voice.id)\(voice.id == currentVoiceId ? ", selected" : "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onSelect(voice) }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/VoicePreviewPlayerTests test 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)"`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Library/VoicePickerView.swift apple/Vimarsha/Library/VoicePreviewPlayer.swift apple/VimarshaTests/VoicePreviewPlayerTests.swift
git commit -m "feat(apple): voice picker panel + bundled-clip preview player

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task D3: Wire the panel into the library surface

**Files:**
- Modify: `apple/Vimarsha/Library/LibraryStackView.swift` (state, overlay, cluster `onActivate`)

- [ ] **Step 1: Add state** — in `apple/Vimarsha/Library/LibraryStackView.swift`, beside `@State private var conversationsBook: Book?` (≈ line 98) add:

```swift
    /// The book whose narrator-voice picker is open (nil = closed).
    @State private var voiceBook: Book?
    /// Ephemeral player for voice previews — borrows the shared memo audio engine.
    @State private var voicePreview: VoicePreviewPlayer?
```

- [ ] **Step 2: Handle the `.narrator` control** — in the cluster `onActivate` switch (≈ line 353), add a case (and because the switch is now exhaustive over four cases, no `default` needed):

```swift
                case .narrator:
                    voicePreview = VoicePreviewPlayer(engine: audioEngine)
                    withAnimation(chapterPlaneAnimation) { voiceBook = book }
```

- [ ] **Step 3: Add the panel overlay** — next to `.overlay { bookConversationsPlane }` (≈ line 221) add `.overlay { voicePickerPlane }`, and add the plane builder near `chapterListPlane` (≈ line 463):

```swift
    @ViewBuilder
    private var voicePickerPlane: some View {
        if let book = voiceBook {
            ZStack {
                Palette.ink0.opacity(0.45).ignoresSafeArea()
                    .onTapGesture { closeVoicePicker() }
                    .accessibilityLabel("Dismiss voice picker").accessibilityAddTraits(.isButton)
                VoicePickerView(
                    currentVoiceId: book.voiceId,
                    reduceTransparency: reduceTransparency,
                    onPreview: { voice in
                        // Courtesy pause of chapter playback while previewing (memo pattern).
                        player?.pause()
                        try? voicePreview?.preview(voice)
                    },
                    onSelect: { voice in
                        book.voiceId = voice.id
                        try? store?.saveContext()       // see step 4
                        closeVoicePicker()
                    },
                    onClose: { closeVoicePicker() }
                )
            }
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func closeVoicePicker() {
        voicePreview?.stop()
        voicePreview = nil
        withAnimation(chapterPlaneAnimation) { voiceBook = nil }
    }
```

- [ ] **Step 4: Persist the selection** — `book.voiceId = …` must be saved. If `LibraryStore` lacks a public save, add one. In `apple/Vimarsha/Library/LibraryStore.swift`:

```swift
    /// Persist pending model edits (e.g. a voice change made in the UI).
    func saveContext() throws { try context.save() }
```

(If a public save already exists, use it instead and skip this.)

- [ ] **Step 5: Build to verify** (no new unit test — the wiring is exercised by the full build + the existing surface tests):

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' build 2>&1 | grep -E "error:|\*\* BUILD"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add apple/Vimarsha/Library/LibraryStackView.swift apple/Vimarsha/Library/LibraryStore.swift
git commit -m "feat(apple): open the voice picker from the Narrator control

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task D4: Chapter-list stale hint + hold-to-re-render

**Files:**
- Modify: `apple/Vimarsha/Library/ChapterListView.swift` (`ChapterListView`, `ChapterRowsView`, `ChapterRow`)
- Modify: `apple/Vimarsha/Library/LibraryStackView.swift` (`chapterListPlane` passes `onRerender` + handles stale open)
- Test: `apple/VimarshaTests/ChapterRowStaleTests.swift`

- [ ] **Step 1: Write the failing test** — create `apple/VimarshaTests/ChapterRowStaleTests.swift`. The stale predicate already has unit coverage (Task B3); here we assert the row exposes a re-render action and the plane routes a stale open to re-render. Test the routing decision as a pure helper:

```swift
import Testing
@testable import Vimarsha

@Suite("Stale-open routing")
struct ChapterRowStaleTests {
    @Test func openingAStaleReadyChapterReRendersInsteadOfReading() {
        // A ready+stale chapter tapped to "open" should re-render, not open the (stale) audio.
        #expect(ChapterOpenRouting.action(status: .ready, isStale: true) == .rerender)
        #expect(ChapterOpenRouting.action(status: .ready, isStale: false) == .open)
        #expect(ChapterOpenRouting.action(status: .none, isStale: false) == .download)
        #expect(ChapterOpenRouting.action(status: .error, isStale: false) == .download)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' -only-testing:VimarshaTests/ChapterRowStaleTests test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: build error — `Cannot find 'ChapterOpenRouting' in scope`.

- [ ] **Step 3a: Add the routing helper** — append to `apple/Vimarsha/Library/ChapterStaleness.swift`:

```swift
/// What tapping a chapter row should do, given its status and staleness — keeps the decision
/// pure and testable, off the view.
nonisolated enum ChapterOpenRouting {
    enum Action: Equatable { case open, rerender, download }

    static func action(status: ChapterStatus, isStale: Bool) -> Action {
        switch status {
        case .ready: return isStale ? .rerender : .open
        case .none, .error: return .download
        case .pending: return .open   // unreachable (pending rows aren't buttons); harmless default
        }
    }
}
```

- [ ] **Step 3b: Surface staleness + hold gesture in `ChapterListView`** — thread the book's voice down and add the re-render callback. In `apple/Vimarsha/Library/ChapterListView.swift`:
  - add to `ChapterListView`: `var onRerender: (Chapter) -> Void = { _ in }` and pass `currentVoiceId: book.voiceId` + `onRerender` into `ChapterRowsView`;
  - add the same two params to `ChapterRowsView` and pass them to each `ChapterRow`;
  - in `ChapterRow`, add `let currentVoiceId: String` and `var onRerender: (Chapter) -> Void`, compute `private var isStale: Bool { ChapterStaleness.isStale(status: chapter.status, narratedVoiceId: chapter.narratedVoiceId, bookVoiceId: currentVoiceId) }`, and:
    - in `rowContent`, under the title `VStack`, when `isStale` show a hint:
      ```swift
                  if isStale {
                      Text("Will re-narrate in \(currentVoiceId)")
                          .font(.caption2)
                          .foregroundStyle(Palette.sky.opacity(0.85))
                  }
      ```
    - on the row `Group`, add a long-press to re-render and route a stale open through `ChapterOpenRouting`:
      ```swift
              .onLongPressGesture(minimumDuration: 0.5) { onRerender(chapter) }
      ```
    - change the `.ready` button action to route via staleness:
      ```swift
              case .ready:
                  Button {
                      switch ChapterOpenRouting.action(status: .ready, isStale: isStale) {
                      case .rerender: onRerender(chapter)
                      case .open: onOpen(chapter)
                      case .download: onDownload(chapter)
                      }
                  } label: { rowContent }
                  .buttonStyle(.plain)
      ```

- [ ] **Step 3c: Wire `onRerender` in the plane** — in `apple/Vimarsha/Library/LibraryStackView.swift` `chapterListPlane`, add to the `ChapterListView(...)` call:

```swift
                    onRerender: { chapter in store?.rerenderChapter(chapter) },
```

- [ ] **Step 4: Run test + full suite**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' test 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Library/ChapterListView.swift apple/Vimarsha/Library/ChapterStaleness.swift apple/Vimarsha/Library/LibraryStackView.swift apple/VimarshaTests/ChapterRowStaleTests.swift
git commit -m "feat(apple): chapter-list stale hint + hold-to-re-render

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

### Task D5: Merge chunk D + live smoke

- [ ] **Step 1: Full suite + build** — `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=macOS' test 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)"` → SUCCEEDED.
- [ ] **Step 2: Live smoke** — with the Kokoro backend running, launch the app, focus a book, tap **Narrator**, preview a couple of voices, pick one, open the chapter list, confirm the **"Will re-narrate in <voice>"** hint on a previously-ready chapter, and **hold** it to re-render (watch it go pending → ready). Then play and confirm the new voice.
- [ ] **Step 3: Merge + push**

```bash
git checkout main
git merge --no-ff feat/voice-ui -m "Merge: voice picker UI + chapter-list stale hint + hold-to-re-render

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin main
```

---

## Self-review notes (resolved)

- **Spec coverage:** catalog (B1) · `?voice=` (A4) · lang-from-prefix (A1–A2) · per-(engine,voice) cache (A3) · `Book.voiceId`/`Chapter.narratedVoiceId` + migration default (B2) · lazy re-render on stale open (D4 routing) · hold-to-re-render (C2 `rerenderChapter` + D4 gesture) · Narrator control (D1) · voice panel with warning (D2–D3) · bundled previews (B4) + preview player (D2–D3). All present.
- **Type consistency:** `importChapter(epubAt:chapterIndex:engine:voice:)`, `speak(text:engine:voice:)`, `ChapterDownloader.download(…engine:voice:)`, `VoiceCatalog.voice(id:)`, `ChapterStaleness.isStale(status:narratedVoiceId:bookVoiceId:)`, `ChapterOpenRouting.action(status:isStale:)`, `LibraryStore.rerenderChapter(_:)`/`saveContext()` are used consistently across tasks.
- **Known integration points to confirm at execution time (not placeholders, but verify against current code):** the exact `FakeBackendClient`/test-double used by existing `LibraryStore`/`BackendClient` tests (extend it for `engine`/`voice` + `lastImportVoice`); the precise `AudioEngine` protocol members (match the preview `FakeEngine`); and whether the Xcode target needs `Resources/VoicePreviews` added to Copy Bundle Resources (B4 step 4).
```
