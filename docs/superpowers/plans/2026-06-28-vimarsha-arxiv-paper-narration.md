# arXiv Paper Narration (Scientific Literature Phase 2c) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Paste an arXiv link in the Scientific Literature section → the backend ingests + narrates the paper → it lists as a paper card → opens in the existing reading surface with equations typeset natively (SwiftMath) and read aloud (Phase 2b).

**Architecture:** A paper is modeled as a single-chapter `Book` (`kind: "paper"`, storing the arXiv `ref` instead of an EPUB), so the existing download/reading/player stack is reused unchanged. One new backend endpoint `POST /arxiv` reuses the existing async job machinery (`ingest_arxiv` → `narrate_bundle` → poll `/import/status`). The only new rendering unit is `MathBlockView`, a native LaTeX typesetter over the new SwiftMath dependency, with a source-text fallback.

**Tech Stack:** Python 3.13 FastAPI + pytest (backend); Swift 6 / SwiftUI iOS 26 + macOS 26, SwiftData, Swift Testing; **SwiftMath** (new SPM dependency, `github.com/mgriebling/SwiftMath`).

## Global Constraints

- **TDD**: failing test → run-fail → minimal impl → run-pass → commit. Small commits.
- **Commit trailer** on every commit (verbatim, blank line before it):
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- **Backend tests** run from `backend/` with `uv run pytest` (FakeSynth — no GPU). Whole suite stays green (115 passed, 1 skipped baseline).
- **Swift tests/build** from `apple/`:
  `xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
  and the macOS destination; both stay green. `xcodebuild` build must succeed (SourceKit cross-file "Cannot find type" diagnostics are spurious — trust the build result).
- **No contract change**: `/arxiv` returns `{jobId}`; the polled bundle is the existing `ChapterBundle`; the client polls the existing `GET /import/status/{job_id}`. Do not modify `ChapterBundle`/`shared/bundle.schema.json`.
- **Reuse the async job machinery** in `server.py` (`_jobs`, `_jobs_lock`, the `/import/status/{job_id}` endpoint). Do not add a second job store.
- **Reuse the engine/voice resolution** (`synth_for` / `_resolve_synth` / `_resolve_remote_narrator` / `REMOTE_ENGINES`) exactly as `/import` does.
- **Author is deferred** (out of scope): paper `Book.author` is `""`. **Figures deferred**: papers have empty `figureMap`. **PDF/OCR deferred**: arXiv LaTeX only.
- **MathBlockView never crashes and never renders blank**: an unparseable equation falls back to its LaTeX source text.
- **Live narration needs a TTS engine in the venv** (`uv sync --extra tts` or `--extra kokoro`); only the opt-in live test (Task 8) needs it — every other test uses FakeSynth / FakeBackendClient.

---

## File structure

**Backend**
- `backend/src/vimarsha/models.py` — **modify**: add `ArxivRequest` DTO.
- `backend/src/vimarsha/server.py` — **modify**: add `POST /arxiv` route + `_run_arxiv_job` helper (mirrors `_run_import_job`).
- `backend/tests/test_arxiv_endpoint.py` — **new**: endpoint + job tests (FakeSynth).

**Swift — networking**
- `apple/Vimarsha/Backend/BackendClient.swift` — **modify**: protocol method `ingestArxiv` + `URLSessionBackendClient` impl + `ArxivRequestBody` DTO.
- `apple/Vimarsha/Backend/FakeBackendClient.swift` (wherever the fake lives) — **modify**: implement `ingestArxiv`.
- `apple/VimarshaTests/…` — **new/modify**: `ingestArxiv` test.

**Swift — persistence + store**
- `apple/Vimarsha/Persistence/Models.swift` — **modify**: `Book.kind` + `Book.arxivRef`.
- `apple/Vimarsha/Library/LibraryStore.swift` — **modify**: `books`/`papers` split + `addPaper(ref:)`.
- `apple/VimarshaTests/…` — **new/modify**: `papers` slice + `addPaper` lifecycle tests.

**Swift — rendering + dependency**
- `apple/Vimarsha.xcodeproj/project.pbxproj` — **modify**: SwiftMath SPM package reference (setup; may be an Xcode UI step).
- `apple/Vimarsha/Reading/MathBlockView.swift` — **new**: SwiftMath wrapper + fallback.
- `apple/Vimarsha/Reading/ReadingBlocksView.swift` — **modify**: route `equation` blocks to `MathBlockView`.
- `apple/VimarshaTests/…` — **new**: MathBlockView fallback test.

**Swift — UI**
- `apple/Vimarsha/Library/ScientificLiteratureView.swift` — **modify**: paste-link input plane + paper list + status/retry; `onAddPaper` → `store.addPaper`.
- `apple/Vimarsha/VimarshaApp.swift` — **modify**: pass the store into `ScientificLiteratureView`; route `onOpenURL` arxiv links to `addPaper`.

---

### Task 1: Backend — `POST /arxiv` endpoint + async job

**Files:**
- Modify: `backend/src/vimarsha/models.py` (add `ArxivRequest`)
- Modify: `backend/src/vimarsha/server.py` (add route + `_run_arxiv_job`)
- Test: `backend/tests/test_arxiv_endpoint.py`

**Interfaces:**
- Consumes: `vimarsha.arxiv_ingest.ingest_arxiv(ref) -> ChapterBundle`; `vimarsha.narrate.narrate_bundle(bundle, synth, out_dir) -> ChapterBundle`; existing `_jobs`/`_jobs_lock`, `synth_for`/`_resolve_synth`, `REMOTE_ENGINES`, `get_synth`, `_sweep_cache`, `app.state.audio_dir`.
- Produces: `POST /arxiv` returning `{"jobId": str, "status": "pending"}`, pollable at the existing `GET /import/status/{job_id}` → `{status: ready, bundle}` | `{status: error, error}`. (Remote engines are out of scope for arXiv in this cut — narrate locally only.)

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_arxiv_endpoint.py
"""POST /arxiv enqueues ingest+narrate of an arXiv paper and is pollable at /import/status.
Uses FakeSynth (no GPU) and monkeypatches ingest_arxiv so no network is hit."""
import time

from fastapi.testclient import TestClient

from vimarsha import server
from vimarsha.models import Block, ChapterBundle
from tests.fakes import FakeSynth


def _poll(client, job_id, tries=50):
    for _ in range(tries):
        r = client.get(f"/import/status/{job_id}")
        if r.json()["status"] != "pending":
            return r.json()
        time.sleep(0.05)
    raise AssertionError("job never left pending")


def test_arxiv_submit_then_ready(monkeypatch, tmp_path):
    server.app.state.audio_dir = str(tmp_path)
    server.app.dependency_overrides[server.get_synth] = lambda: FakeSynth()

    def fake_ingest(ref: str) -> ChapterBundle:
        return ChapterBundle(
            chapterId=f"arxiv-{ref}", title="Attention Is All You Need",
            blocks=[Block(id="b0", index=0, kind="paragraph", text="Hello world.")],
            figureMap=[],
        )
    monkeypatch.setattr(server, "ingest_arxiv", fake_ingest, raising=False)

    client = TestClient(server.app)
    r = client.post("/arxiv", json={"ref": "1706.03762"})
    assert r.status_code == 200
    job_id = r.json()["jobId"]
    assert r.json()["status"] == "pending"

    result = _poll(client, job_id)
    assert result["status"] == "ready", result
    bundle = result["bundle"]
    assert bundle["title"] == "Attention Is All You Need"
    assert bundle["audio"]                      # narrate_bundle filled audio
    server.app.dependency_overrides.clear()


def test_arxiv_ingest_error_becomes_job_error(monkeypatch, tmp_path):
    server.app.state.audio_dir = str(tmp_path)
    server.app.dependency_overrides[server.get_synth] = lambda: FakeSynth()

    def boom(ref: str):
        raise ValueError("arXiv:bad produced no readable text")
    monkeypatch.setattr(server, "ingest_arxiv", boom, raising=False)

    client = TestClient(server.app)
    job_id = client.post("/arxiv", json={"ref": "bad"}).json()["jobId"]
    result = _poll(client, job_id)
    assert result["status"] == "error"
    assert "readable text" in result["error"]
    server.app.dependency_overrides.clear()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_arxiv_endpoint.py -v`
Expected: FAIL — `POST /arxiv` 404 (route doesn't exist).

- [ ] **Step 3: Write minimal implementation**

In `models.py`, add the request DTO (near `SpeakRequest`):

```python
class ArxivRequest(BaseModel):
    """Submit an arXiv paper for ingest + narration. `ref` is any form normalize_arxiv_id
    accepts (bare id, abs/pdf URL, arXiv:…v5)."""
    ref: str
    engine: str | None = None
    voice: str | None = None
```

In `server.py`:
- add imports near the other vimarsha imports:
  `from vimarsha.arxiv_ingest import ingest_arxiv`
  `from vimarsha.narrate import narrate_bundle`
  and add `ArxivRequest` to the `from vimarsha.models import …` line.
- add the job runner next to `_run_import_job`:

```python
def _run_arxiv_job(job_id: str, ref: str, synth: Synthesizer) -> None:
    try:
        bundle = ingest_arxiv(ref)                       # Phase 2a/2b: blocks + math-to-speech
        narrated = narrate_bundle(bundle, synth, app.state.audio_dir)
        out = narrated.model_dump(by_alias=True, exclude_none=True)
        with _jobs_lock:
            _jobs[job_id] = {"status": "ready", "bundle": out}
    except Exception as exc:  # noqa: BLE001 — surfaced to the client as the job's error
        with _jobs_lock:
            _jobs[job_id] = {"status": "error", "error": str(exc)}
```

- add the route (near `/import`):

```python
@app.post("/arxiv")
async def import_arxiv(req: ArxivRequest, synth: Synthesizer = Depends(get_synth)):
    """Enqueue ingest+narration of an arXiv paper; poll /import/status/{job_id}. arXiv papers
    narrate locally (no remote dispatch in this cut). Validation is fast; the work is threaded."""
    ref = req.ref.strip()
    if not ref:
        raise HTTPException(status_code=400, detail="empty ref")
    synth_for_job = _resolve_synth(req.engine, req.voice, synth)  # validates engine → 400
    _sweep_cache()
    job_id = uuid.uuid4().hex
    with _jobs_lock:
        _jobs[job_id] = {"status": "pending"}
    threading.Thread(
        target=_run_arxiv_job, args=(job_id, ref, synth_for_job), daemon=True
    ).start()
    return {"jobId": job_id, "status": "pending"}
```

> **Note:** `ingest_arxiv` is imported at module scope so the tests can `monkeypatch.setattr(server, "ingest_arxiv", …)`. Keep it a module-level name (don't import it inside the function).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_arxiv_endpoint.py -v`
Expected: PASS (both tests).

- [ ] **Step 5: Run the full suite + commit**

Run: `cd backend && uv run pytest -q` → green (117 passed, 1 skipped).

```bash
git add backend/src/vimarsha/models.py backend/src/vimarsha/server.py backend/tests/test_arxiv_endpoint.py
git commit -m "feat(backend): POST /arxiv — ingest + narrate an arXiv paper (Phase 2c)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Swift — `BackendClient.ingestArxiv`

**Files:**
- Modify: `apple/Vimarsha/Backend/BackendClient.swift`
- Modify: the fake client file (find it: `grep -rl "FakeBackendClient" apple/VimarshaTests apple/Vimarsha`)
- Test: a new test in `apple/VimarshaTests/` (e.g. `BackendArxivTests.swift`)

**Interfaces:**
- Consumes: existing `ImportJobDTO` (`jobId`), `ImportStatusDTO` (`status`, `bundle`, `error`), `ChapterBundleDTO`, `BackendError`, `Self.validate`, `Self.jsonRequest`, `session`, `baseURL`. (Read `importChapter` in BackendClient.swift — `ingestArxiv` mirrors its submit-then-poll exactly, only the submit differs.)
- Produces: `func ingestArxiv(ref: String, engine: String?, voice: String?) async throws -> ChapterBundleDTO` on the `BackendClient` protocol; implemented on `URLSessionBackendClient` and `FakeBackendClient`.

- [ ] **Step 1: Write the failing test**

```swift
// apple/VimarshaTests/BackendArxivTests.swift
import Testing
@testable import Vimarsha

@Test func fakeBackendIngestArxivReturnsBundle() async throws {
    let fake = FakeBackendClient()
    // Arrange whatever the fake exposes to script a bundle (mirror how other Fake tests do it).
    let bundle = try await fake.ingestArxiv(ref: "1706.03762", engine: nil, voice: nil)
    #expect(bundle.chapterId.contains("arxiv") || !bundle.blocks.isEmpty)
}
```

> Read the existing `FakeBackendClient` first and follow its scripting style (it likely has settable stored results / records calls). Make `ingestArxiv` return a scripted `ChapterBundleDTO` and record the `ref`, mirroring how `importChapter` is faked. Adjust the test's `#expect` to assert against the fake's scripted bundle.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: FAIL — `value of type 'FakeBackendClient' has no member 'ingestArxiv'` (and the protocol lacks it).

- [ ] **Step 3: Write minimal implementation**

In `BackendClient.swift` protocol (`protocol BackendClient: Sendable`), add:

```swift
    /// Submit an arXiv ref for ingest+narration; polls /import/status internally (like
    /// importChapter) and returns the narrated bundle.
    func ingestArxiv(ref: String, engine: String?, voice: String?) async throws -> ChapterBundleDTO
```

Add a request body DTO (near the other private DTOs, e.g. `ChatRequestBody`):

```swift
private struct ArxivRequestBody: Encodable {
    let ref: String
    let engine: String?
    let voice: String?
}
```

Implement on `URLSessionBackendClient` (mirror `importChapter`'s poll loop verbatim; only the submit changes from multipart to JSON):

```swift
    func ingestArxiv(ref: String, engine: String?, voice: String?) async throws -> ChapterBundleDTO {
        // 1. Submit (engine validation surfaces here as a non-2xx).
        let request = try Self.jsonRequest(
            url: baseURL.appending(path: "arxiv"),
            body: ArxivRequestBody(ref: ref, engine: engine, voice: voice)
        )
        let (submitData, submitResponse) = try await session.data(for: request)
        try Self.validate(submitResponse)
        let job = try JSONDecoder().decode(ImportJobDTO.self, from: submitData)

        // 2. Poll until ready/error (identical to importChapter).
        let statusURL = baseURL.appending(path: "import")
            .appending(path: "status").appending(path: job.jobId)
        let deadline = Date().addingTimeInterval(3 * 60 * 60)
        while Date() < deadline {
            try await Task.sleep(for: .seconds(2))
            let (data, response) = try await session.data(from: statusURL)
            try Self.validate(response)
            let status = try JSONDecoder().decode(ImportStatusDTO.self, from: data)
            switch status.status {
            case "ready":
                if let bundle = status.bundle { return bundle }
                throw BackendError.importFailed("ready job returned no bundle")
            case "error":
                throw BackendError.importFailed(status.error ?? "narration failed")
            default:
                continue
            }
        }
        throw BackendError.importTimedOut
    }
```

> If `Self.jsonRequest` isn't the exact helper name, read how `chat` builds its JSON request and mirror that. Implement `ingestArxiv` on `FakeBackendClient` per Step 1.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Backend/ apple/VimarshaTests/BackendArxivTests.swift
git commit -m "feat(apple): BackendClient.ingestArxiv — submit /arxiv + poll (Phase 2c)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Swift — `Book.kind` + `Book.arxivRef` + papers slice

**Files:**
- Modify: `apple/Vimarsha/Persistence/Models.swift` (`Book`)
- Modify: `apple/Vimarsha/Library/LibraryStore.swift` (`papers` computed; `books` already exists)
- Test: a new test (e.g. `apple/VimarshaTests/PaperModelTests.swift`)

**Interfaces:**
- Consumes: existing `Book` `@Model`, `LibraryStore.books`.
- Produces: `Book.kind: String` (default `"book"`), `Book.arxivRef: String?` (default `nil`); `Book.isPaper: Bool`; `LibraryStore.papers: [Book]` (the `kind == "paper"` slice) and the My Books shelf is the `kind == "book"` slice.

- [ ] **Step 1: Write the failing test**

```swift
// apple/VimarshaTests/PaperModelTests.swift
import Testing
import SwiftData
@testable import Vimarsha

@Test func bookKindDefaultsToBookAndPaperFlagWorks() throws {
    let b = Book(title: "A Book", author: "X", epubPath: "p.epub")
    #expect(b.kind == "book")
    #expect(b.isPaper == false)
    let p = Book(title: "A Paper", author: "", epubPath: "")
    p.kind = "paper"
    p.arxivRef = "1706.03762"
    #expect(p.isPaper == true)
    #expect(p.arxivRef == "1706.03762")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: FAIL — `Book` has no `kind`/`arxivRef`/`isPaper`.

- [ ] **Step 3: Write minimal implementation**

In `Models.swift` `Book`, add stored properties with defaults (lightweight SwiftData migration, exactly like `voiceId`):

```swift
    /// "book" (EPUB) or "paper" (arXiv). Defaulted so adding it is a lightweight migration;
    /// existing rows are books.
    var kind: String = "book"
    /// For papers: the arXiv ref to re-ingest on (re-)narration. Books have no epub-less source.
    var arxivRef: String?

    var isPaper: Bool { kind == "paper" }
```

In `LibraryStore.swift`, add the papers slice and make the existing shelf/books reflect only `kind == "book"`. Add:

```swift
    /// Papers (Scientific Literature section) — the `kind == "paper"` slice.
    var papers: [Book] { books.filter { $0.isPaper } }
```

> Read how `shelf`/`books` feed the My Books library. If `shelf` is built from `books`, filter it to `!$0.isPaper` so papers don't appear in My Books (and vice-versa). Keep that change minimal and covered by the existing library behavior.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Persistence/Models.swift apple/Vimarsha/Library/LibraryStore.swift apple/VimarshaTests/PaperModelTests.swift
git commit -m "feat(apple): Book.kind + arxivRef + papers slice (Phase 2c)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Swift — `LibraryStore.addPaper(ref:)`

**Files:**
- Modify: `apple/Vimarsha/Library/LibraryStore.swift`
- Test: `apple/VimarshaTests/AddPaperTests.swift`

**Interfaces:**
- Consumes: `BackendClient.ingestArxiv` (Task 2); `Book(kind:"paper", arxivRef:)` (Task 3); the existing bundle/audio caching used after a chapter import (read `addBook` + `ChapterDownloader` to find the helper that writes `bundle.json` + `chapter.mp3` to `Library/Books/<id>/chapters/0/` and marks the `Chapter` ready). The store's `client`, `context`, container directory, and `books` reload.
- Produces: `func addPaper(ref: String) async` — creates a `Book(kind:"paper")` + one `Chapter(index:0)` in `.pending`, runs the ingest job (`client.ingestArxiv` → cache bundle+audio), sets the chapter/book `.ready` or `.error` (errorReason set), persists, reloads `books`. Title is set from the returned `bundle.title`. Cancellable + self-healing like `downloadChapter`.

- [ ] **Step 1: Write the failing test**

```swift
// apple/VimarshaTests/AddPaperTests.swift
import Testing
import SwiftData
@testable import Vimarsha

@MainActor
@Test func addPaperCreatesReadyPaperFromFakeBackend() async throws {
    // Build an in-memory store with a FakeBackendClient scripted to return a paper bundle
    // for ingestArxiv (mirror the existing addBook / download tests' setup).
    let store = try LibraryStore.inMemoryForTesting(/* inject FakeBackendClient with a scripted
        arxiv bundle titled "Attention Is All You Need" + a 1-block body + fake audio */)

    await store.addPaper(ref: "1706.03762")

    let papers = store.papers
    #expect(papers.count == 1)
    let paper = try #require(papers.first)
    #expect(paper.isPaper)
    #expect(paper.arxivRef == "1706.03762")
    #expect(paper.title == "Attention Is All You Need")
    let chapter = try #require(paper.chapters.first)
    #expect(chapter.status == .ready)
}
```

> Read `AddBookTests` / the existing download tests to see exactly how an in-memory `LibraryStore` + scripted `FakeBackendClient` are constructed, and reuse that harness verbatim (helper name, injection). Adjust the test to that harness. If the fake needs scripted audio bytes, give it a tiny valid stub the way the chapter-download tests do.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: FAIL — `LibraryStore` has no `addPaper`.

- [ ] **Step 3: Write minimal implementation**

Add `addPaper(ref:)` to `LibraryStore`, mirroring `addBook` + the chapter-download caching. The body:
1. Create `Book(title: "arXiv:\(ref)", author: "", epubPath: "")`, set `kind = "paper"`, `arxivRef = ref`; insert; create `Chapter(index: 0, title: "Paper")`, attach, set `.pending`; `try context.save()`; reload `books`.
2. In a cancellable store-owned task: `let bundle = try await client.ingestArxiv(ref: ref, engine: nil, voice: book.voiceId == VoiceCatalog.defaultId ? nil : book.voiceId)`.
3. Cache the bundle JSON + download `bundle.audio` via the same helper `downloadChapter` uses to write `Library/Books/<id>/chapters/0/{bundle.json,chapter.mp3}` and set `chapter.bundlePath`/`audioPath`/`durationMs`/`.ready`. Update `book.title = bundle.title`.
4. On any thrown error: `chapter.status = .error`, `chapter.errorReason = <message>`, keep the row (retryable). Always `try? context.save()` + reload.

> This mirrors `downloadChapter` almost exactly — the ONLY difference is step 2 fetches via `ingestArxiv(ref:)` instead of `importChapter(epubAt:)`. Read `downloadChapter` and factor the shared "cache a fetched ChapterBundleDTO → mark ready" tail into a private helper both call, rather than duplicating it (DRY). Show that helper in your implementation.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Library/LibraryStore.swift apple/VimarshaTests/AddPaperTests.swift
git commit -m "feat(apple): LibraryStore.addPaper — ingest+cache an arXiv paper (Phase 2c)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Swift — SwiftMath dependency + `MathBlockView`

**Files:**
- Modify: `apple/Vimarsha.xcodeproj/project.pbxproj` (add the SwiftMath SPM package — **setup step**)
- Create: `apple/Vimarsha/Reading/MathBlockView.swift`
- Test: `apple/VimarshaTests/MathBlockViewTests.swift`

**Interfaces:**
- Consumes: SwiftMath (`import SwiftMath`; `MTMathUILabel`, its `.latex` and `.error`).
- Produces: `struct MathBlockView: View` taking `latex: String`; renders typeset math, falling back to source text when SwiftMath can't parse it. A pure helper `MathBlockView.canRender(_ latex: String) -> Bool` (testable without a live view) that returns false when `MTMathUILabel` reports an error for that latex.

- [ ] **Step 1: Add the SwiftMath package (setup — do this first; it's not TDD)**

Add the SPM dependency. Preferred: open `apple/Vimarsha.xcodeproj` in Xcode → File → Add Package Dependencies → `https://github.com/mgriebling/SwiftMath` → pin to the latest release → add the `SwiftMath` library product to the **Vimarsha** target. (Folder-synchronized projects still need the package reference in `project.pbxproj`; the Xcode UI writes it correctly.)

If doing it head-less, add to `project.pbxproj`: an `XCRemoteSwiftPackageReference` for SwiftMath, a `XCSwiftPackageProductDependency` for the `SwiftMath` product, the product in the Vimarsha target's `Frameworks` build phase, and the package ref in the project's `packageReferences`. **Verify** with: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5` resolving SwiftMath and succeeding. If the headless edit doesn't resolve, STOP and report — the user adds it via Xcode (one click), then continue.

- [ ] **Step 2: Write the failing test**

```swift
// apple/VimarshaTests/MathBlockViewTests.swift
import Testing
@testable import Vimarsha

@Test func canRenderAcceptsValidLatexAndRejectsGarbage() {
    #expect(MathBlockView.canRender("E = mc^2") == true)
    #expect(MathBlockView.canRender(#"\frac{a}{b}"#) == true)
    // An unparseable construct must report not-renderable (→ source-text fallback).
    #expect(MathBlockView.canRender(#"\frac{a}{"#) == false)   // unbalanced
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: FAIL — no `MathBlockView`.

- [ ] **Step 4: Write minimal implementation**

```swift
// apple/Vimarsha/Reading/MathBlockView.swift
import SwiftUI
import SwiftMath

#if canImport(UIKit)
import UIKit
private typealias PlatformViewRepresentable = UIViewRepresentable
#else
import AppKit
private typealias PlatformViewRepresentable = NSViewRepresentable
#endif

/// A display equation typeset natively from its LaTeX (SwiftMath / MTMathUILabel) — matte
/// "paper" per the content-vs-glass rule. Unparseable LaTeX falls back to its source text so a
/// figure-dense paper never shows a blank or crashes (mirrors the verbalizer's no-fail rule).
struct MathBlockView: View {
    let latex: String

    var body: some View {
        if MathBlockView.canRender(latex) {
            MathLabel(latex: latex)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        } else {
            Text(latex)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(Palette.textPrimary.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
    }

    /// True when SwiftMath can parse this LaTeX (no MTMathUILabel error). Pure enough to unit-test.
    static func canRender(_ latex: String) -> Bool {
        let label = MTMathUILabel()
        label.latex = latex
        return label.error == nil && !(latex.trimmingCharacters(in: .whitespaces).isEmpty)
    }
}

private struct MathLabel: PlatformViewRepresentable {
    let latex: String

    #if canImport(UIKit)
    func makeUIView(context: Context) -> MTMathUILabel { configured() }
    func updateUIView(_ label: MTMathUILabel, context: Context) { apply(to: label) }
    #else
    func makeNSView(context: Context) -> MTMathUILabel { configured() }
    func updateNSView(_ label: MTMathUILabel, context: Context) { apply(to: label) }
    #endif

    private func configured() -> MTMathUILabel {
        let label = MTMathUILabel()
        label.textAlignment = .center
        label.labelMode = .display
        apply(to: label)
        return label
    }

    private func apply(to label: MTMathUILabel) {
        label.latex = latex
        label.textColor = PlatformColor(Palette.textPrimary)
    }
}

#if canImport(UIKit)
private typealias PlatformColor = UIColor
#else
private typealias PlatformColor = NSColor
#endif
```

> If the exact SwiftMath API differs (e.g. `MTMathUILabel.labelMode`/`.error` names), open its source/README from the resolved package and adjust — the test (`canRender`) is the contract: valid LaTeX → true, unbalanced → false, and the view must fall back to `Text(latex)` when false. Confirm `PlatformColor(Palette.textPrimary)` compiles (Palette returns SwiftUI `Color`; convert via `UIColor(_:)`/`NSColor(_:)`).

- [ ] **Step 5: Run test to verify it passes**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apple/Vimarsha.xcodeproj/project.pbxproj apple/Vimarsha/Reading/MathBlockView.swift apple/VimarshaTests/MathBlockViewTests.swift
git commit -m "feat(apple): SwiftMath dependency + MathBlockView (native equation render) (Phase 2c)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Swift — route `equation` blocks to `MathBlockView`

**Files:**
- Modify: `apple/Vimarsha/Reading/ReadingBlocksView.swift`
- Test: extend `apple/VimarshaTests/MathBlockViewTests.swift` (or a reading-blocks snapshot test if one exists)

**Interfaces:**
- Consumes: `MathBlockView(latex:)` (Task 5); the block DTO's `kind`/`latex` fields (an `equation` block carries `latex`).
- Produces: `ReadingBlocksView` renders `kind == "equation"` blocks via `MathBlockView(latex: block.latex ?? "")` instead of falling through to plain text.

- [ ] **Step 1: Write the failing test**

```swift
// add to MathBlockViewTests.swift — assert the routing decision via a pure helper.
@Test func equationBlocksRouteToMath() {
    // ReadingBlocksView exposes a pure classifier for what a block renders as.
    #expect(ReadingBlocksView.rendersAsMath(kind: "equation"))
    #expect(ReadingBlocksView.rendersAsMath(kind: "paragraph") == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: FAIL — no `rendersAsMath`.

- [ ] **Step 3: Write minimal implementation**

Read `ReadingBlocksView` to see how it switches on `block.kind`. Add the classifier and the routing:

```swift
    /// Display equations render as native math (Task 5); everything else stays text/paper.
    static func rendersAsMath(kind: String) -> Bool { kind == "equation" }
```

In the block-rendering switch, add a branch before the text default:

```swift
        if ReadingBlocksView.rendersAsMath(kind: block.kind) {
            MathBlockView(latex: block.latex ?? "")
        } else {
            // …existing text/figure/heading rendering…
        }
```

> Match the surrounding style exactly (the existing switch/if structure, padding, and the active-highlight wash — an equation block should still get the narration highlight background like other narrated blocks, since Phase 2b makes equations narratable). Keep the math view matte (no glass).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: PASS. Also rebuild to confirm the reading surface compiles with the new branch.

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Reading/ReadingBlocksView.swift apple/VimarshaTests/MathBlockViewTests.swift
git commit -m "feat(apple): render equation blocks as native math in the reading surface (Phase 2c)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Swift — Scientific Literature input + paper list + wiring

**Files:**
- Modify: `apple/Vimarsha/Library/ScientificLiteratureView.swift`
- Modify: `apple/Vimarsha/VimarshaApp.swift`
- Test: `apple/VimarshaTests/ArxivRefParsingTests.swift`

**Interfaces:**
- Consumes: `LibraryStore.addPaper(ref:)` + `LibraryStore.papers` (Tasks 3–4); the reading-surface open path the library already uses (a paper opens the same reading surface as a book — reuse the existing open mechanism).
- Produces: `ScientificLiteratureView(store:)` with a paste-link input plane (text field + submit), a paper list with per-card status (narrating…/ready/error+retry), tapping a ready card opens it; a pure `ArxivRef.looksValid(_:)` guard so the submit button enables only on a plausible ref; `VimarshaApp` passes the store in and routes `onOpenURL` arxiv links to `addPaper`.

- [ ] **Step 1: Write the failing test**

```swift
// apple/VimarshaTests/ArxivRefParsingTests.swift
import Testing
@testable import Vimarsha

@Test func arxivRefValidation() {
    #expect(ArxivRef.looksValid("1706.03762"))
    #expect(ArxivRef.looksValid("https://arxiv.org/abs/1706.03762v5"))
    #expect(ArxivRef.looksValid("arXiv:2401.00001"))
    #expect(ArxivRef.looksValid("hello") == false)
    #expect(ArxivRef.looksValid("") == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: FAIL — no `ArxivRef`.

- [ ] **Step 3: Write minimal implementation**

Add the pure validator (in `ScientificLiteratureView.swift` or a small `ArxivRef.swift`):

```swift
enum ArxivRef {
    /// A plausible arXiv id or URL: a modern id (1706.03762, optional vN) or an old-style id,
    /// possibly wrapped in an abs/pdf URL or "arXiv:" prefix.
    static func looksValid(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return false }
        return s.range(of: #"\d{4}\.\d{4,5}(v\d+)?"#, options: .regularExpression) != nil
            || s.range(of: #"[a-z\-]+(\.[A-Z]{2})?/\d{7}"#, options: .regularExpression) != nil
    }
}
```

Then build the UI (no unit test for layout — match the existing section/plane style):
- Replace the stub `onAddPaper` flow with an input plane: a `@State private var refText`, a glass text field + submit button (enabled when `ArxivRef.looksValid(refText)`), submit → `Task { await store.addPaper(ref: refText) }` then clear.
- Replace the empty state with: if `store.papers.isEmpty` show the empty state, else a list of paper cards. Each card shows `paper.title` and its chapter status (`pending` → "Narrating…" with a spinner; `error` → message + Retry calling `addPaper(ref: paper.arxivRef!)` again or a dedicated retry; `ready` → tappable, opens the reading surface via the same path the library uses).
- `ScientificLiteratureView` takes `var store: LibraryStore?` (nil → empty state/no input, like the library previews).

In `VimarshaApp.swift`:
- pass the store: `ScientificLiteratureView(store: store)`.
- route arxiv deep links: in the existing `.onOpenURL`, if the URL host contains `arxiv.org`, `Task { await store?.addPaper(ref: url.absoluteString) }` instead of `addBook(from:)`.

> Read `ChapterListView`/`ChapterRowsView` for the status-row pattern (Narrating…/ready/error+retry) and reuse its look. Reuse the library's existing "open this book's reading surface" mechanism for a ready paper rather than inventing one — a paper is just a `Book`.

- [ ] **Step 4: Run test + build to verify**

Run: `cd apple && xcodebuild -scheme Vimarsha -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: PASS (`ArxivRefParsingTests`) and the app builds with the new UI.

- [ ] **Step 5: Commit**

```bash
git add apple/Vimarsha/Library/ScientificLiteratureView.swift apple/Vimarsha/VimarshaApp.swift apple/VimarshaTests/ArxivRefParsingTests.swift
git commit -m "feat(apple): Scientific Literature — paste arXiv link, paper list, open+narrate (Phase 2c)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: [verify] Live end-to-end (opt-in)

**Files:**
- Test: `backend/tests/test_arxiv_endpoint.py` (add an opt-in live test)

**Interfaces:** Consumes the real `ingest_arxiv` + a real synth. **Requires** the venv TTS engine (`uv sync --extra tts` or `--extra kokoro`) — otherwise narration 500s (the current known breakage).

- [ ] **Step 1: Add the opt-in live test (gated like the math-to-speech live test)**

```python
import os
import pytest

@pytest.mark.skipif(os.environ.get("VIMARSHA_LIVE") != "1", reason="hits arxiv.org + real TTS")
def test_arxiv_live_short_paper_narrates(tmp_path):
    """Real ingest + real narration of a tiny paper; asserts a bundle with audio + equation
    blocks that carry spoken text and no LaTeX leakage."""
    from vimarsha import server
    from vimarsha.tts import synth_class
    server.app.state.audio_dir = str(tmp_path)
    synth = synth_class(os.environ.get("VIMARSHA_TTS"))()
    from vimarsha.arxiv_ingest import ingest_arxiv
    from vimarsha.narrate import narrate_bundle
    bundle = narrate_bundle(ingest_arxiv("1706.03762"), synth, str(tmp_path))
    assert bundle.audio
    eqs = [b for b in bundle.blocks if b.kind == "equation"]
    assert eqs and all(b.text and "$" not in b.text for b in eqs)
```

- [ ] **Step 2: Run it (only if the venv has a TTS engine)**

Run: `cd backend && uv sync --extra kokoro && VIMARSHA_TTS=kokoro VIMARSHA_LIVE=1 uv run pytest tests/test_arxiv_endpoint.py::test_arxiv_live_short_paper_narrates -v`
Expected: PASS (or SKIP by default). If the venv has no TTS engine, it's expected to be skipped/blocked — note it; do not fail the task on the missing engine.

- [ ] **Step 3: Human device verification (deferred checklist)**

On a device with the backend reachable and a TTS engine installed: paste `1706.03762` in Scientific Literature → card shows Narrating… → ready → open → equations typeset on screen and read aloud. Record the outcome; this is the human gate.

- [ ] **Step 4: Commit**

```bash
git add backend/tests/test_arxiv_endpoint.py
git commit -m "test(backend): opt-in live arXiv narration end-to-end (Phase 2c)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Notes for the implementer

- **`ingest_arxiv` already does math-to-speech** (Phase 2b's `verbalize_blocks` runs inside it), so `narrate_bundle` reads equation blocks with no extra work. Don't re-verbalize.
- **A paper has no EPUB.** Its `Book.epubPath` is `""` and `arxivRef` holds the source; re-narration re-submits the ref. The reading surface/player load the cached `bundle.json` + `chapter.mp3`, not the EPUB, so a paper reads exactly like a book once cached. Covers fall back to the generated cloth cover (no `coverPath`).
- **DRY the caching:** Task 4 must share the "cache a fetched `ChapterBundleDTO` → mark the chapter ready" tail with `downloadChapter`; only the fetch differs (arxiv vs epub).
- **SwiftMath is the one dependency** and the one place a headless agent may get stuck (pbxproj). If `xcodebuild` won't resolve it, stop and have the user add it via Xcode once, then resume.
- **SourceKit "Cannot find type" diagnostics across files are spurious** in this project (folder-synchronized target) — trust `xcodebuild`'s `** BUILD SUCCEEDED **` / test result, not the editor squiggles.
- Final: feature branch → small commits → both suites green → `--no-ff` merge to `main`.
```
