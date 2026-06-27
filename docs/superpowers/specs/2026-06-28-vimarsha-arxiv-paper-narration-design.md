# Vimarsha — arXiv Paper Narration (Scientific Literature Phase 2c)

> **Status:** Design · **Date:** 2026-06-28 · **Track:** Scientific Literature
> (Phase 1 = section shell · Phase 2a = arXiv LaTeX → blocks · Phase 2b = math-to-speech ·
> **2c = this: wire the section to the backend end-to-end + render equations**)
> Spans backend (one endpoint) + Swift client (network seam, persistence, UI) + one new
> SwiftUI rendering unit + one new dependency.

## Problem

The Scientific Literature section (Phase 1) is a shell: an "Add a paper" pill with a stub
`onAddPaper` callback and an empty state. The backend can already turn an arXiv reference into
a narrated `ChapterBundle` (Phase 2a ingest + Phase 2b math-to-speech), but **nothing exposes
that over HTTP**, the Swift client has no way to submit a paper, and equations aren't rendered
on screen. Phase 2c connects the section to the backend: paste an arXiv link → the paper is
ingested, narrated, listed, and opens in the reading surface with equations typeset natively
and read aloud.

## Approach (decided)

Reuse the **existing book pipeline** end to end — a paper is modeled as a single-chapter
`Book` — so the proven download/reading/player/figure stack works on papers unchanged. The
only genuinely new pieces are: one backend endpoint, one client network method + store
method, a paper-input UI in the section, and one native equation-rendering view.

**Equation rendering = SwiftMath**, a native LaTeX math typesetter (the maintained Swift port
of iosMath; `github.com/mgriebling/SwiftMath`). KaTeX itself is JavaScript and needs a
`WKWebView`; SwiftMath renders LaTeX math to native views with a real TeX layout engine +
bundled fonts, fully offline, no web layer — the "KaTeX-quality without a web layer" middle
ground. It is the repo's **first third-party Swift dependency**.

Rejected: a `WKWebView`+KaTeX layer (adds a web-rendering surface, sizing/scroll/theming
integration); server-side pre-rendered equation images (backend dependency + asset plumbing +
sizing); narrate-only with no visual math (below the quality bar the owner set).

## Architecture

### Backend — one new endpoint `POST /arxiv`

- **Request:** JSON `{ "ref": "<arxiv id or url>", "engine"?: str, "voice"?: str }`.
  `ref` accepts any form `normalize_arxiv_id` handles (bare id, `arxiv.org/abs/…`,
  `arXiv:…v5`, `…/pdf/…`).
- **Behavior:** reuses the **existing async job machinery** that `/import` already has
  (narration is minutes-long; `/import` returns a `job_id` and the client polls
  `GET /import/status/{job_id}` — see `server.py` `_jobs` / `_run_import_job`). `POST /arxiv`
  enqueues a job that runs:
  1. `ingest_arxiv(ref)` → whole-paper `ChapterBundle` (paragraphs + headings + equation
     blocks, math-to-speech already applied by `ingest_arxiv`'s `verbalize_blocks`),
  2. `narrate_bundle(bundle, synth, audio_dir)` → fills `audio` + `paraTimings` (equation
     blocks now narrate via Phase 2b),
  and stores `{status: ready, bundle}` (or `{status: error, error}`) under the `job_id`.
- **Response:** `{ "jobId": "<id>" }` immediately. The client polls `/import/status/{job_id}`
  (existing endpoint, unchanged) → the serialized `ChapterBundle`; audio via the existing
  `GET /audio/{name}`.
- **Errors:** `ingest_arxiv` raises `ValueError` for a bad/empty paper ("no LaTeX source",
  "produced no readable text"); the job records it as `{status: error, error: <message>}`,
  surfaced to the client (same path as a failed chapter import). A malformed `ref` that
  normalizes to nothing → 400 at submit time.
- **Engine/voice:** optional, threaded through the existing `synth_for` / remote-narrator
  resolution exactly like `/import` (so a premium/remote engine dispatches remotely; the
  default local engine narrates locally). No new synth code.
- **No `figureMap`** for papers in this cut (figures/plots are out of scope) — the bundle's
  `figureMap` is empty; the reading surface's figure overlay simply has nothing to show.

### Client persistence — reuse `Book` / `Chapter`

- `Book` gains `kind: String` (default `"book"`; papers set `"paper"`). The Scientific
  Literature section lists `store.papers` (the `kind == "paper"` slice); My Books lists the
  `kind == "book"` slice. (SwiftData: adding a non-optional property with a default is a
  lightweight migration; existing rows default to `"book"`.)
- A paper = one `Book` holding **one** `Chapter` (the whole-paper bundle). The existing
  `Chapter` status lifecycle (none/pending/ready/error) carries the narration state.
- **Title** comes from the polled `ChapterBundle.title` (already set by `ingest_arxiv` from
  `arxiv_metadata`). **Author is best-effort and out of scope for this cut**: the contract
  (`ChapterBundle`) has no author field and we are not changing the schema, so the paper
  `Book.author` is left blank (the card shows the title + the arXiv id). Surfacing the author
  is a trivial later addition (add it to the `/arxiv` response or the status payload) and is
  explicitly deferred.

### Client network — `BackendClient.ingestArxiv`

- Protocol gains `func ingestArxiv(ref: String, engine: String?, voice: String?) async throws
  -> String` (returns `jobId`) and reuses the existing import-status polling + audio download
  already used by `ChapterDownloader`. `FakeBackendClient` implements it for tests.

### Client store — `LibraryStore.addPaper(ref:)`

- Parallels `addBook`: create the `Book(kind: "paper")` + its single `Chapter` in `pending`,
  kick the store-owned job (`ingestArxiv` → poll → cache bundle JSON + `chapter.mp3` in the
  container via the existing `ChapterDownloader` path), set the chapter/book to `ready` or
  `error`. Cancellable + self-healing on load, like chapter downloads. Title/author update
  from the response as soon as available.

### Client UI — the section + the reading equation view

- **Add-a-paper input:** the pill opens a small glass input plane *within* the section (a
  morph, not a sheet — Prime Directive): a text field (paste arXiv link/id) + submit. Also
  wire `onOpenURL` so an `arxiv.org` link shared to Vimarsha calls `addPaper`.
- **Paper list:** the empty state is replaced by a list of paper cards once `store.papers` is
  non-empty. Each card shows title/author and a **status** (narrating… / ready / error+retry)
  mirroring the chapter-download status UI. A `ready` card taps to open the reading surface.
- **`MathBlockView` (new, the only new rendering unit):** a SwiftUI wrapper over SwiftMath's
  `MTMathUILabel` via `UIViewRepresentable` (iOS) / `NSViewRepresentable` (macOS), rendering
  an `equation` block's `latex` as native typeset math — matte "paper" (content-vs-glass
  rule), centered, sized to fit width with a sensible max. **Graceful fallback:** if SwiftMath
  reports a parse error (`label.error != nil`) or produces empty output, render the LaTeX
  source as monospaced text instead — never blank, never a crash. `ReadingBlocksView` routes
  `equation` blocks to `MathBlockView` (today they fall through to text).

## Integration points (small, additive)

- `server.py`: add the `POST /arxiv` route + its job runner (reuses `_jobs`,
  `_run_import_job`-style helper, `synth_for`/remote resolution). DTO `ArxivRequest`.
- `models.py`/contract: the `/arxiv` response is just `{jobId}`; the polled bundle is the
  existing `ChapterBundle` (no schema change). The paper's title is the bundle's `title`;
  author is deferred (see Persistence) — the contract is unchanged.
- Swift: `BackendClient` protocol + `URLSessionBackendClient` + `FakeBackendClient`;
  `Book.kind`; `LibraryStore.addPaper` + `papers`; `ScientificLiteratureView` input + list;
  `MathBlockView`; `ReadingBlocksView` equation routing.
- **Dependency:** add SwiftMath via SPM. The folder-synchronized `project.pbxproj` needs a
  package reference (`XCRemoteSwiftPackageReference` + product dependency) — done once via
  Xcode → *Add Package Dependencies* → `github.com/mgriebling/SwiftMath` (pinned to a release),
  or an equivalent pbxproj edit. This is a manual/explicit setup step, called out in the plan.

## Testing (TDD where there's logic)

- **Backend:** `POST /arxiv` request validation + job lifecycle against `FakeSynth` (no GPU),
  mirroring the `/import` tests: a submit returns a `jobId`; a job over a fake bundle reaches
  `ready` with audio; a bad `ref` → 400; an ingest `ValueError` → `{status: error}`. One
  opt-in **live** test ingests+narrates a tiny real arXiv id end-to-end (gated by the live
  env var, like the math-to-speech live test) — requires a working TTS engine in the venv.
- **Swift:** `BackendClient.ingestArxiv` + status polling against `FakeBackendClient`;
  `LibraryStore.addPaper` state machine (pending → ready / error, cancel, self-heal) over an
  in-memory SwiftData store; `MathBlockView` fallback (unparseable LaTeX → source text) as a
  pure check; `Book.kind` slicing (`papers` vs books). The reading/player/figure stack is
  already covered.
- Both suites stay green; the existing reading-surface snapshots get an `equation`-block case.

## Scope / YAGNI

- **In:** arXiv-LaTeX papers only; paste-link + `onOpenURL` input; async ingest+narrate via
  the existing job machinery; paper list with status/retry; reading surface with
  SwiftMath-rendered + narrated equations; graceful render fallback.
- **Out (later phases):** PDF/OCR papers (Z.AI GLM OCR); figures/plots from papers
  (`figureMap`); equation-level narration highlight (equations render statically; surrounding
  text still highlights); multi-"chapter" papers (a paper is one chapter); citation/reference
  resolution.

## Risks

- **SwiftMath coverage:** it typesets most common math (fractions, scripts, roots, sums,
  integrals, matrices, Greek, operators) but not arbitrary LaTeX/custom macros → mitigated by
  the source-text fallback (degrade, never crash), the same philosophy as the verbalizer.
- **pbxproj + SPM:** adding the first package to a folder-synchronized project is a manual
  Xcode step; the plan calls it out so implementation isn't blocked guessing at pbxproj.
- **Live narration blocked by the venv:** end-to-end live verification needs the TTS engine
  reinstalled (`uv sync --extra tts`/`--extra kokoro`); the machine-testable layers
  (FakeSynth/FakeBackendClient) do not.
- **Long jobs / single process:** `_jobs` is in-process (today's single dev backend); a
  multi-worker deploy would need a shared store — already noted in `server.py`, unchanged here.
