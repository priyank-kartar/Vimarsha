# Plan 4a — Figure Images + Player Sync Logic (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver figure images from backend to client and give `PlayerController` the brains to map playback position to the narrated paragraph and the active figure(s) — the data/logic layer the Plan 4b reading UI will consume. No new UI.

**Architecture:** The backend extracts each figure's image from the EPUB at import, names it stably, records it on `Figure.image`, and serves it via `GET /image/{name}`. The client downloads + caches images alongside audio/bundle, can re-read the cached bundle, and `PlayerController` derives `currentBlockId`, `currentFigures`, image paths, and `seekToBlock` from the position it already tracks.

**Tech Stack:** Backend: Python 3.13, FastAPI, ebooklib, pytest. Client: Flutter, Riverpod, drift, dio, freezed. No new packages.

**Prerequisite:** Plans 1–3c merged. Spec: `docs/superpowers/specs/2026-06-08-vimarsha-figure-overlay-design.md`.

---

## Branch setup (controller does this before Task 1)

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git checkout main && git checkout -b feat/figure-data-sync
```

---

## File Structure

```
backend/
  src/vimarsha/epub_reader.py     # Chapter gains `href`
  src/vimarsha/models.py          # Figure gains `image`
  src/vimarsha/figure_images.py   # NEW: extract_images()
  src/vimarsha/server.py          # /import wires extract_images; + GET /image/{name}
  tests/conftest.py               # fixture EPUB gains 2 real PNG image files + manifest items
  tests/test_figure_images.py     # NEW
  tests/test_server_image.py      # NEW
app/
  lib/core/models/figure.dart            # gains `image`
  lib/core/backend/backend_client.dart   # + downloadImage
  lib/core/backend/dio_backend_client.dart # + downloadImage
  lib/core/storage/file_store.dart       # + imageFile / imagesDir
  lib/features/book/chapter_repository.dart # caches images; + loadBundle
  lib/features/player/player_controller.dart # sync logic + FileStore
  lib/core/providers.dart                # playerControllerProvider passes fileStore
  test/support/fake_backend_client.dart  # + downloadImage
  test/core/backend/dio_backend_client_test.dart   # + downloadImage test
  test/core/storage/file_store_test.dart           # + imageFile test
  test/features/book/chapter_repository_test.dart   # + image caching + loadBundle tests
  test/features/player/player_controller_test.dart  # + sync tests
shared/bundle.schema.json          # regenerated (Figure.image)
```

---

## Task 1: Backend — `Figure.image`, `Chapter.href`, and `extract_images`

**Files:** Modify `epub_reader.py`, `models.py`, `tests/conftest.py`; Create
`figure_images.py`, `tests/test_figure_images.py`; regenerate schema.

- [ ] **Step 1: Add real PNG images to the fixture EPUB**

In `backend/tests/conftest.py`, add this constant near the top (after the imports):

```python
# Minimal valid 1x1 PNG, used as fixture figure images.
PNG_1PX = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
    "0000000a49444154789c6360000002000154a24f5f0000000049454e44ae426082"
)
```

In the `CONTENT_OPF` string's `<manifest>`, add two image items so it reads:

```xml
  <manifest>
    <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
    <item id="img-cycle" href="images/cycle.png" media-type="image/png"/>
    <item id="img-variant" href="images/variant.png" media-type="image/png"/>
  </manifest>
```

In BOTH fixture builders (`sample_epub` and `sample_epub_no_author`), add the two
image files to the zip (right after the `chap1.xhtml` write):

```python
        z.writestr("OEBPS/images/cycle.png", PNG_1PX)
        z.writestr("OEBPS/images/variant.png", PNG_1PX)
```

- [ ] **Step 2: Write the failing test**

```python
# backend/tests/test_figure_images.py
from vimarsha.epub_reader import read_chapters
from vimarsha.ingest import ingest_epub
from vimarsha.figure_images import extract_images
from vimarsha.models import Figure


def test_extract_writes_images_and_sets_image_field(sample_epub, tmp_path):
    bundle = ingest_epub(str(sample_epub))[0]
    href = read_chapters(str(sample_epub))[0].href
    figs = extract_images(
        str(sample_epub), bundle.chapter_id, href, bundle.figure_map, str(tmp_path)
    )
    by_id = {f.figure_id: f for f in figs}
    # the two <figure> blocks (b2, b8) get image files; pullquote (b5) does not
    assert by_id["b2"].image is not None
    assert by_id["b8"].image is not None
    assert by_id["b5"].image is None
    assert (tmp_path / by_id["b2"].image).is_file()
    assert (tmp_path / by_id["b2"].image).read_bytes()[:4] == b"\x89PNG"


def test_missing_asset_leaves_image_none(sample_epub, tmp_path):
    fig = Figure(figure_id="bX", kind="figure", asset="images/missing.png",
                 start_para="bX", end_para="bX")
    out = extract_images(str(sample_epub), "chap1", "chap1.xhtml", [fig], str(tmp_path))
    assert out[0].image is None  # unresolved asset is skipped, no error
```

- [ ] **Step 3: Add `href` to `Chapter` in `backend/src/vimarsha/epub_reader.py`**

```python
@dataclass
class Chapter:
    chapter_id: str
    title: str
    html: str
    href: str = ""
```

And set it in `read_chapters` (the `Chapter(...)` construction):

```python
        chapters.append(
            Chapter(
                chapter_id=idref,
                title=item.get_name(),
                html=html,
                href=item.get_name(),
            )
        )
```

- [ ] **Step 4: Add `image` to `Figure` in `backend/src/vimarsha/models.py`**

Add this field to the `Figure` model (after `end_ms`):

```python
    image: Optional[str] = None          # served image filename, filled at import (Plan 4a)
```

- [ ] **Step 5: Write `backend/src/vimarsha/figure_images.py`**

```python
from __future__ import annotations

import posixpath
from pathlib import Path

from ebooklib import epub

from vimarsha.models import Figure


def _resolve(chapter_href: str, asset: str) -> str:
    """Resolve an image src that is relative to the chapter document."""
    base = posixpath.dirname(chapter_href)
    return posixpath.normpath(posixpath.join(base, asset))


def extract_images(
    epub_path: str,
    chapter_id: str,
    chapter_href: str,
    figures: list[Figure],
    out_dir: str,
) -> list[Figure]:
    """For each figure with an asset, copy its EPUB image into out_dir under a
    stable name and set figure.image. Unresolvable assets are skipped (image
    stays None). Returns the same figures (mutated in place)."""
    book = epub.read_epub(epub_path)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    for fig in figures:
        if not fig.asset:
            continue
        href = _resolve(chapter_href, fig.asset)
        item = book.get_item_with_href(href)
        if item is None:
            continue
        ext = posixpath.splitext(href)[1] or ".img"
        name = f"{chapter_id}_{fig.figure_id}{ext}"
        (out / name).write_bytes(item.get_content())
        fig.image = name
    return figures
```

- [ ] **Step 6: Run tests to verify they fail then pass**

Run: `cd backend && uv run pytest tests/test_figure_images.py -v`
Expected: first FAIL (`ModuleNotFoundError: vimarsha.figure_images`), then after Steps 3–5, PASS (2 passed).

- [ ] **Step 7: Run the full backend suite (conftest changed)**

Run: `cd backend && uv run pytest`
Expected: all pass (47 prior + 2 new = 49). The added image files/manifest items don't affect document-only tests.

- [ ] **Step 8: Regenerate the shared schema**

Run: `cd backend && uv run python scripts/export_schema.py`
Expected: `shared/bundle.schema.json` updated; it now lists `image` under the Figure definition.

- [ ] **Step 9: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add backend/src/vimarsha/epub_reader.py backend/src/vimarsha/models.py backend/src/vimarsha/figure_images.py backend/tests/conftest.py backend/tests/test_figure_images.py shared/bundle.schema.json
git commit -m "feat: extract figure images from EPUB at import (Plan 4a Task 1)"
```

---

## Task 2: Backend — wire `/import` to extract images + serve `GET /image/{name}`

**Files:** Modify `backend/src/vimarsha/server.py`; Create `backend/tests/test_server_image.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_server_image.py
from fastapi.testclient import TestClient

from vimarsha.server import app, get_synth
from tests.fakes import FakeSynth


def _client(tmp_path):
    app.dependency_overrides[get_synth] = lambda: FakeSynth()
    app.state.audio_dir = str(tmp_path)
    return TestClient(app)


def test_import_fills_figure_image_and_serves_it(tmp_path, sample_epub):
    client = _client(tmp_path)
    with open(sample_epub, "rb") as f:
        resp = client.post("/import?chapter_index=0",
                           files={"file": ("s.epub", f, "application/epub+zip")})
    assert resp.status_code == 200
    figures = resp.json()["figureMap"]
    img = next(fig for fig in figures if fig["figureId"] == "b2")
    assert img["image"]  # filename present

    got = client.get(f"/image/{img['image']}")
    assert got.status_code == 200
    assert got.content[:4] == b"\x89PNG"
    app.dependency_overrides.clear()


def test_image_path_traversal_is_rejected(tmp_path):
    client = _client(tmp_path)
    assert client.get("/image/..%2f..%2fetc%2fpasswd").status_code == 404
    app.dependency_overrides.clear()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_server_image.py -v`
Expected: FAIL — the figure has no `image` key (extract not wired) / `/image` route 404 for the valid case.

- [ ] **Step 3: Update `backend/src/vimarsha/server.py`**

Add imports (merge with existing):

```python
from vimarsha.epub_reader import read_chapters
from vimarsha.figure_images import extract_images
```

Replace the `import_chapter` body so the EPUB survives until images are
extracted, and resolve the chapter href:

```python
@app.post("/import")
async def import_chapter(
    chapter_index: int = 0,
    file: UploadFile = File(...),
    synth: Synthesizer = Depends(get_synth),
):
    data = await file.read()
    with tempfile.NamedTemporaryFile(suffix=".epub", delete=False) as tmp:
        tmp.write(data)
        tmp.flush()
        tmp_path_str = tmp.name
    try:
        chapters = await run_in_threadpool(read_chapters, tmp_path_str)
        bundles = await run_in_threadpool(ingest_epub, tmp_path_str)
        if not (0 <= chapter_index < len(bundles)):
            raise HTTPException(status_code=404, detail="chapter_index out of range")
        narrated = await run_in_threadpool(
            narrate_bundle, bundles[chapter_index], synth, app.state.audio_dir
        )
        await run_in_threadpool(
            extract_images,
            tmp_path_str,
            narrated.chapter_id,
            chapters[chapter_index].href,
            narrated.figure_map,
            app.state.audio_dir,
        )
    finally:
        Path(tmp_path_str).unlink(missing_ok=True)
    return narrated.model_dump(by_alias=True, exclude_none=True)
```

Add the image route (below `get_audio`):

```python
@app.get("/image/{name}")
def get_image(name: str):
    base = Path(app.state.audio_dir).resolve()
    path = (base / name).resolve()
    if not path.is_file() or not path.is_relative_to(base):
        raise HTTPException(status_code=404, detail="image not found")
    return FileResponse(str(path))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_server_image.py -v`
Expected: PASS (2 passed).

- [ ] **Step 5: Run full backend suite**

Run: `cd backend && uv run pytest`
Expected: all pass (51 total).

- [ ] **Step 6: Commit**

```bash
git add backend/src/vimarsha/server.py backend/tests/test_server_image.py
git commit -m "feat: /import extracts figure images; GET /image serves them (Plan 4a Task 2)"
```

---

## Task 3: Client — `Figure.image`, `downloadImage`, `FileStore.imageFile`

**Files:** Modify `figure.dart`, `backend_client.dart`, `dio_backend_client.dart`,
`file_store.dart`, `test/support/fake_backend_client.dart`; tests in
`dio_backend_client_test.dart`, `file_store_test.dart`.

- [ ] **Step 1: Add `image` to `app/lib/core/models/figure.dart`**

```dart
@freezed
abstract class Figure with _$Figure {
  const factory Figure({
    required String figureId,
    required String kind,
    String? asset,
    String? caption,
    String? label,
    required String startPara,
    required String endPara,
    int? startMs,
    int? endMs,
    String? image,
  }) = _Figure;

  factory Figure.fromJson(Map<String, dynamic> json) => _$FigureFromJson(json);
}
```

- [ ] **Step 2: Add `downloadImage` to the interface `app/lib/core/backend/backend_client.dart`**

```dart
  /// Download the bytes of a figure image by its served name.
  Future<List<int>> downloadImage(String imageName);
```

- [ ] **Step 3: Implement it in `app/lib/core/backend/dio_backend_client.dart`**

Add this method (mirrors `downloadAudio`):

```dart
  @override
  Future<List<int>> downloadImage(String imageName) async {
    final resp = await _dio.get<List<int>>(
      '/image/$imageName',
      options: Options(responseType: ResponseType.bytes),
    );
    return resp.data ?? <int>[];
  }
```

- [ ] **Step 4: Add image paths to `app/lib/core/storage/file_store.dart`**

Add these methods (next to `audioFile`):

```dart
  Directory imagesDir(String bookId, int index) =>
      Directory(p.join(chapterDir(bookId, index).path, 'images'));
  File imageFile(String bookId, int index, String name) =>
      File(p.join(imagesDir(bookId, index).path, name));

  Future<Directory> ensureImagesDir(String bookId, int index) =>
      imagesDir(bookId, index).create(recursive: true);
```

- [ ] **Step 5: Add `downloadImage` to `app/test/support/fake_backend_client.dart`**

Add a field and method:

```dart
  /// bytes returned by downloadImage (any name); records requested names.
  List<int> image = const [137, 80, 78, 71]; // "\x89PNG"
  final List<String> imageRequests = [];

  @override
  Future<List<int>> downloadImage(String imageName) async {
    imageRequests.add(imageName);
    return image;
  }
```

- [ ] **Step 6: Write the failing tests**

Append to `app/test/core/backend/dio_backend_client_test.dart` (inside `main`):

```dart
  test('downloadImage gets /image/<name> as raw bytes', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final payload = [137, 80, 78, 71, 13, 10];
    server.listen((req) {
      req.response
        ..headers.contentType = ContentType('image', 'png')
        ..add(payload);
      req.response.close();
    });
    final realDio = Dio(BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'));
    final bytes = await DioBackendClient(realDio).downloadImage('chap1_b2.png');
    expect(bytes, payload);
  });
```

Append to `app/test/core/storage/file_store_test.dart` (inside `main`):

```dart
  test('image files live under the chapter images dir', () {
    expect(store.imageFile('bookA', 2, 'chap1_b2.png').path,
        '${tmp.path}/books/bookA/ch2/images/chap1_b2.png');
  });
```

- [ ] **Step 7: Generate code + run the tests**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -2`
Then: `cd app && flutter test test/core/backend/dio_backend_client_test.dart test/core/storage/file_store_test.dart 2>&1 | tail -3`
Expected: build succeeds; both files pass (incl. the 2 new tests). `flutter analyze` clean.

- [ ] **Step 8: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/models/figure.dart app/lib/core/backend app/lib/core/storage/file_store.dart app/test/support/fake_backend_client.dart app/test/core/backend/dio_backend_client_test.dart app/test/core/storage/file_store_test.dart
git commit -m "feat: client downloadImage + FileStore image paths + Figure.image (Plan 4a Task 3)"
```

---

## Task 4: Client — `ChapterRepository` image caching + `loadBundle`

**Files:** Modify `app/lib/features/book/chapter_repository.dart`,
`app/test/features/book/chapter_repository_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `app/test/features/book/chapter_repository_test.dart` (inside `main`).
First, add `Figure`/`Block` imports at the top of the file:

```dart
import 'package:vimarsha/core/models/figure.dart';
```

Then update the `_bundle()` helper to include a figure with an image, and add tests:

```dart
ChapterBundle _bundleWithFigure() => const ChapterBundle(
      chapterId: 'chap1',
      title: 'The Engine',
      blocks: [],
      figureMap: [
        Figure(
          figureId: 'b2', kind: 'figure', startPara: 'b2', endPara: 'b3',
          startMs: 0, endMs: 1000, image: 'chap1_b2.png',
        ),
      ],
      audio: 'chap1.mp3',
      paraTimings: {},
    );

void _mainImageTests() {} // marker; place the tests below inside the existing main()
```

Add these `test(...)` calls inside `main()` (reuse the existing `db`, `files`,
`backend`, `repo()` setup):

```dart
  test('downloadChapter caches figure images', () async {
    backend.bundle = _bundleWithFigure();
    await repo().downloadChapter('bookX', 0);
    expect(backend.imageRequests, contains('chap1_b2.png'));
    expect(files.imageFile('bookX', 0, 'chap1_b2.png').existsSync(), isTrue);
  });

  test('downloadChapter still succeeds if an image download fails', () async {
    backend.bundle = _bundleWithFigure();
    backend.throwOnImage = Exception('img boom');
    await repo().downloadChapter('bookX', 0);
    final c = await row();
    expect(c.downloadStatus, 'ready'); // image failure is non-fatal
  });

  test('loadBundle round-trips the cached bundle', () async {
    backend.bundle = _bundleWithFigure();
    await repo().downloadChapter('bookX', 0);
    final loaded = await repo().loadBundle('bookX', 0);
    expect(loaded, isNotNull);
    expect(loaded!.figureMap.single.image, 'chap1_b2.png');
  });
```

Add a `throwOnImage` hook to `FakeBackendClient` (in `test/support/fake_backend_client.dart`):

```dart
  Object? throwOnImage;
```
and at the top of `downloadImage`: `if (throwOnImage != null) throw throwOnImage!;`

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/book/chapter_repository_test.dart 2>&1 | tail -5`
Expected: FAIL — `loadBundle` undefined / images not cached.

- [ ] **Step 3: Update `app/lib/features/book/chapter_repository.dart`**

Add the import at the top:

```dart
import '../../core/models/chapter_bundle.dart';
```

Inside `downloadChapter`, after the audio is written and before the DB `update`
to `ready`, add image caching:

```dart
      // Cache figure images (best-effort; a failure here does not fail the chapter).
      for (final fig in bundle.figureMap) {
        final imageName = fig.image;
        if (imageName == null) continue;
        try {
          final imgBytes = await _backend.downloadImage(imageName);
          if (imgBytes.isNotEmpty) {
            await _files.ensureImagesDir(bookId, index);
            await _files.imageFile(bookId, index, imageName).writeAsBytes(imgBytes);
          }
        } catch (_) {/* non-fatal: card will show without the image */}
      }
```

Add the `loadBundle` method (after `getChapter`):

```dart
  /// Read and parse the cached bundle JSON for a chapter, or null if absent.
  Future<ChapterBundle?> loadBundle(String bookId, int index) async {
    final file = _files.bundleFile(bookId, index);
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return ChapterBundle.fromJson(json);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/book/chapter_repository_test.dart 2>&1 | tail -5`
Expected: PASS (existing + 3 new).

- [ ] **Step 5: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/features/book/chapter_repository.dart app/test/features/book/chapter_repository_test.dart app/test/support/fake_backend_client.dart
git commit -m "feat: ChapterRepository caches figure images + loadBundle (Plan 4a Task 4)"
```

---

## Task 5: Client — `PlayerController` sync logic

The controller gains the bundle + `FileStore`, and derives reading/figure state
from position.

**Files:** Modify `app/lib/features/player/player_controller.dart`,
`app/lib/core/providers.dart`, `app/test/features/player/player_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `app/test/features/player/player_controller_test.dart`. Add imports:

```dart
import 'package:vimarsha/core/models/chapter_bundle.dart';
import 'package:vimarsha/core/models/block.dart';
import 'package:vimarsha/core/models/figure.dart';
```

Add a bundle-backed controller helper and tests inside `main()` (reuses the
existing `db`, `audio`, `chapters`, `FileStore` setup; note `FileStore` is
already imported in this test):

```dart
  ChapterBundle _bundle() => const ChapterBundle(
        chapterId: 'c1', title: 'Ch',
        blocks: [
          Block(id: 'p0', index: 0, kind: 'paragraph', text: 'one'),
          Block(id: 'p1', index: 1, kind: 'paragraph', text: 'two'),
        ],
        figureMap: [
          Figure(figureId: 'f1', kind: 'figure', startPara: 'p0', endPara: 'p1',
              startMs: 1000, endMs: 5000, image: 'c1_f1.png'),
          Figure(figureId: 'f2', kind: 'figure', startPara: 'p1', endPara: 'p1',
              startMs: 4000, endMs: 8000),
        ],
        paraTimings: {'p0': [0, 3000], 'p1': [3000, 9000]},
      );

  Future<PlayerController> loadedWithBundle(Directory tmp) async {
    // write the bundle to the FileStore where loadBundle expects it
    final files = FileStore(tmp);
    await files.ensureChapterDir('b1', 0);
    await files.bundleFile('b1', 0)
        .writeAsString(jsonEncode(_bundle().toJson()));
    final c = PlayerController(
        audio: audio, chapters: chapters, files: files, bookId: 'b1', index: 0);
    await c.load('/a.mp3');
    return c;
  }

  test('currentBlockId tracks the narrated paragraph', () async {
    final tmp = Directory.systemTemp.createTempSync('pcb');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final c = await loadedWithBundle(tmp);
    audio.emitPosition(const Duration(milliseconds: 1500));
    await Future<void>.delayed(Duration.zero);
    expect(c.currentBlockId, 'p0');
    audio.emitPosition(const Duration(milliseconds: 4000));
    await Future<void>.delayed(Duration.zero);
    expect(c.currentBlockId, 'p1');
    c.dispose();
  });

  test('currentFigures includes all figures active at the position', () async {
    final tmp = Directory.systemTemp.createTempSync('pcf');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final c = await loadedWithBundle(tmp);
    audio.emitPosition(const Duration(milliseconds: 4500)); // f1 [1000,5000] and f2 [4000,8000]
    await Future<void>.delayed(Duration.zero);
    expect(c.currentFigures.map((f) => f.figureId), ['f1', 'f2']);
    audio.emitPosition(const Duration(milliseconds: 200)); // none
    await Future<void>.delayed(Duration.zero);
    expect(c.currentFigures, isEmpty);
    c.dispose();
  });

  test('imagePathFor resolves to the cached file; null when no image', () async {
    final tmp = Directory.systemTemp.createTempSync('pci');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final c = await loadedWithBundle(tmp);
    final f1 = _bundle().figureMap[0];
    final f2 = _bundle().figureMap[1];
    expect(c.imagePathFor(f1), endsWith('/books/b1/ch0/images/c1_f1.png'));
    expect(c.imagePathFor(f2), isNull);
    c.dispose();
  });

  test('seekToBlock seeks to the block start ms', () async {
    final tmp = Directory.systemTemp.createTempSync('pcs');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final c = await loadedWithBundle(tmp);
    await c.seekToBlock('p1');
    expect(audio.seeks.last, const Duration(milliseconds: 3000));
    c.dispose();
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/player/player_controller_test.dart 2>&1 | tail -5`
Expected: FAIL — `PlayerController` has no `files` param / `currentBlockId` etc.

- [ ] **Step 3: Update `app/lib/features/player/player_controller.dart`**

Add the import and `FileStore`/bundle fields, load the bundle, and compute the
derived state. Full updated file:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/audio/audio_handler.dart';
import '../../core/db/database.dart';
import '../../core/models/chapter_bundle.dart';
import '../../core/models/figure.dart';
import '../../core/storage/file_store.dart';
import '../book/chapter_repository.dart';

/// Drives playback of one cached chapter: loads audio + bundle, restores the
/// saved position, mirrors position/playing into listenable state, derives the
/// narrated paragraph and active figures, and persists progress.
class PlayerController extends ChangeNotifier {
  PlayerController({
    required AudioHandler audio,
    required ChapterRepository chapters,
    required FileStore files,
    required this.bookId,
    required this.index,
  })  : _audio = audio,
        _chapters = chapters,
        _files = files;

  final AudioHandler _audio;
  final ChapterRepository _chapters;
  final FileStore _files;
  final String bookId;
  final int index;

  static const _saveInterval = Duration(seconds: 5);

  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playing = false;
  double speed = 1.0;

  ChapterBundle? bundle;
  String? currentBlockId;
  List<Figure> currentFigures = const [];

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;
  Duration _lastSaved = Duration.zero;
  bool _disposed = false;

  Future<void> load(String audioPath) async {
    if (_posSub != null) return;
    final dur = await _audio.load(audioPath);
    if (dur != null) duration = dur;

    bundle = await _chapters.loadBundle(bookId, index);

    final row = await _chapters.getChapter(bookId, index);
    final resume = Duration(milliseconds: row?.positionMs ?? 0);
    position = resume;
    _lastSaved = Duration.zero;
    if (resume > Duration.zero) await _audio.seek(resume);
    _recompute();

    _posSub = _audio.positionStream.listen(_onPosition);
    _playSub = _audio.playingStream.listen((p) {
      if (_disposed) return;
      playing = p;
      notifyListeners();
    });
    notifyListeners();
  }

  void _onPosition(Duration p) {
    if (_disposed) return;
    position = p;
    if ((p - _lastSaved).abs() >= _saveInterval) {
      _lastSaved = p;
      unawaited(_chapters.saveProgress(bookId, index, p.inMilliseconds));
    }
    _recompute();
    notifyListeners();
  }

  /// Recompute the narrated paragraph + active figures from `position`.
  void _recompute() {
    final b = bundle;
    if (b == null) return;
    final ms = position.inMilliseconds;

    String? blockId;
    var bestStart = -1;
    b.paraTimings.forEach((id, range) {
      final start = range.isNotEmpty ? range[0] : 0;
      if (start <= ms && start > bestStart) {
        bestStart = start;
        blockId = id;
      }
    });
    currentBlockId = blockId;

    currentFigures = b.figureMap
        .where((f) =>
            f.startMs != null &&
            f.endMs != null &&
            ms >= f.startMs! &&
            ms <= f.endMs!)
        .toList();
  }

  /// Resolve a figure's cached image to a local file path (null if no image).
  String? imagePathFor(Figure figure) {
    final name = figure.image;
    if (name == null) return null;
    return _files.imageFile(bookId, index, name).path;
  }

  Future<void> play() => _audio.play();

  Future<void> pause() async {
    await _audio.pause();
    await _persist();
  }

  Future<void> seek(Duration to) async {
    await _audio.seek(to);
    position = to;
    _recompute();
    notifyListeners();
  }

  /// Seek to the start of a block (by id), using its paragraph timing.
  Future<void> seekToBlock(String blockId) async {
    final range = bundle?.paraTimings[blockId];
    if (range == null || range.isEmpty) return;
    await seek(Duration(milliseconds: range[0]));
  }

  Future<void> setSpeed(double s) async {
    await _audio.setSpeed(s);
    speed = s;
    notifyListeners();
  }

  Future<void> _persist() async {
    _lastSaved = position;
    await _chapters.saveProgress(bookId, index, position.inMilliseconds);
  }

  @override
  void dispose() {
    _disposed = true;
    _posSub?.cancel();
    _playSub?.cancel();
    unawaited(_audio.pause());
    unawaited(_chapters.saveProgress(bookId, index, position.inMilliseconds));
    super.dispose();
  }
}
```

- [ ] **Step 4: Update `playerControllerProvider` in `app/lib/core/providers.dart`**

It must pass `files`. Update the provider body:

```dart
final playerControllerProvider = ChangeNotifierProvider.autoDispose
    .family<PlayerController, ({String bookId, int index})>((ref, args) {
  return PlayerController(
    audio: ref.watch(audioHandlerProvider),
    chapters: ref.watch(chapterRepositoryProvider),
    files: ref.watch(fileStoreProvider),
    bookId: args.bookId,
    index: args.index,
  );
});
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/player/player_controller_test.dart 2>&1 | tail -5`
Expected: PASS (existing 6 + 4 new). Note the existing tests construct
`PlayerController(...)` without `files`; update those constructions to pass
`files: FileStore(Directory.systemTemp.createTempSync('pc'))` (the existing
tests don't load a bundle, so `currentBlockId` stays null — fine).

- [ ] **Step 6: Full app suite + analyze + backend suite**

Run: `cd app && flutter analyze 2>&1 | tail -2 && flutter test 2>&1 | tail -3`
Expected: `No issues found!`; all pass (player_screen_test still passes — its
`playerControllerProvider` override now builds with `files` from the overridden
`fileStoreProvider`, which the test already provides).
Run: `cd backend && uv run pytest 2>&1 | tail -1` → 51 passed.

- [ ] **Step 7: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/features/player/player_controller.dart app/lib/core/providers.dart app/test/features/player/player_controller_test.dart
git commit -m "feat: PlayerController sync logic (currentBlockId/currentFigures/seekToBlock) (Plan 4a Task 5)"
```

---

## Self-Review

**Spec coverage (§2 backend, §3 client data/sync):**
- §2.1 `Chapter.href` → Task 1. ✅
- §2.2 `extract_images` (+ skip unresolved) → Task 1. ✅
- §2.3 `Figure.image` + schema → Task 1. ✅
- §2.4 `/import` wiring + `/image` endpoint (+ traversal guard) → Task 2. ✅
- §3 `downloadImage` + `FileStore.imageFile` → Task 3. ✅
- §3 `ChapterRepository` image caching (non-fatal) + `loadBundle` → Task 4. ✅
- §3 `PlayerController` `currentBlockId` / `currentFigures` (overlap case) /
  `imagePathFor` / `seekToBlock` → Task 5. ✅
- Reading UI, overlay, gallery, player chrome → Plan 4b (out of scope). Noted.

**Placeholder scan:** none — every step has concrete code/commands + expected output.

**Type consistency:** `Figure.image` is `Optional[str]`/`String?` on both sides
with JSON key `image`. `extract_images(epub_path, chapter_id, chapter_href,
figures, out_dir)` signature matches its test and the `/import` call.
`PlayerController` constructor (`audio, chapters, files, bookId, index`) matches
the provider and all test constructions. `downloadImage(name)`, `imageFile(bookId,
index, name)`, `loadBundle(bookId, index)`, `currentBlockId`, `currentFigures`,
`imagePathFor`, `seekToBlock` names are consistent across source, tests, and
`FakeBackendClient`. `paraTimings` values are `List<int>` `[start, end]` as in
Plan 2/3. The existing `player_controller_test.dart` and `player_screen_test.dart`
constructions are explicitly updated to pass `files`.
