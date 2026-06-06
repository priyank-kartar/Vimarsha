# Plan 3a — Client Scaffold, Models & Storage + Backend `/toc` (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fast no-audio `POST /toc` (with book title/author) to the backend, then scaffold the Flutter app with freezed models that parse the shared bundle contract and a tested storage layer (FileStore + Drift), so Plan 3b can build repositories, screens, and the player on top.

**Architecture:** Backend gains a book-metadata extractor and a `/toc` endpoint reusing the existing no-ML ingest. The Flutter app (`/app`, macOS dev target) is layered: `core/models` (freezed mirrors of `shared/bundle.schema.json`), `core/storage/FileStore` (filesystem paths), and `core/db/AppDatabase` (Drift: Books, Chapters). Everything in this plan is unit-tested with real code (real ingest, real Drift in-memory, real temp dirs) — no fakes yet.

**Tech Stack:** Backend: Python 3.13, uv, FastAPI, pytest (existing). Client: Flutter 3.44 / Dart 3.12, flutter_riverpod, drift + sqlite3_flutter_libs + path_provider + path, freezed + json_serializable + build_runner. (just_audio, dio, go_router, file_picker are added now but first used in Plan 3b.)

**Prerequisite:** Plans 1–2 merged to `main` (backend ingestion + narration, `shared/bundle.schema.json`, `shared/fixtures/sample-chapter.bundle.json`). Flutter SDK installed; macOS desktop available.

---

## Branch setup (controller does this before Task 1)

Create a feature branch off `main`:
```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git checkout main && git checkout -b feat/client-scaffold
```

---

## File Structure

```
backend/
  src/vimarsha/metadata.py        # read_book_meta(epub) -> BookMeta
  src/vimarsha/models.py          # + BookMeta, ChapterSummary, TocResponse
  src/vimarsha/server.py          # + POST /toc
  tests/test_metadata.py
  tests/test_server_toc.py
  tests/conftest.py               # add dc:creator to the OPF fixture

app/                              # NEW Flutter project (created in Task 3)
  pubspec.yaml
  lib/core/models/{block,figure,chapter_bundle,chapter_summary,book_meta}.dart
  lib/core/storage/file_store.dart
  lib/core/db/database.dart
  test/core/models/models_test.dart
  test/core/storage/file_store_test.dart
  test/core/db/database_test.dart
```

---

## Task 1: Backend — book metadata extractor

**Files:**
- Modify: `backend/src/vimarsha/models.py`, `backend/tests/conftest.py`
- Create: `backend/src/vimarsha/metadata.py`, `backend/tests/test_metadata.py`

- [ ] **Step 1: Add `<dc:creator>` to the OPF fixture so author is testable**

In `backend/tests/conftest.py`, find the `CONTENT_OPF` string's `<metadata ...>` block and add a creator line right after the `<dc:title>` line so it reads:

```xml
    <dc:title>Test Book</dc:title>
    <dc:creator>Ada Lovelace</dc:creator>
    <dc:language>en</dc:language>
```

(Leave everything else in conftest unchanged.)

- [ ] **Step 2: Write the failing test**

```python
# backend/tests/test_metadata.py
from vimarsha.metadata import read_book_meta
from vimarsha.models import BookMeta


def test_reads_title_and_author(sample_epub):
    meta = read_book_meta(str(sample_epub))
    assert isinstance(meta, BookMeta)
    assert meta.title == "Test Book"
    assert meta.author == "Ada Lovelace"


def test_missing_author_is_empty_string(sample_epub_no_author):
    meta = read_book_meta(str(sample_epub_no_author))
    assert meta.title == "Test Book"
    assert meta.author == ""
```

- [ ] **Step 3: Add the `sample_epub_no_author` fixture to `backend/tests/conftest.py`**

Append this fixture (it builds an EPUB whose OPF has no `<dc:creator>`):

```python
CONTENT_OPF_NO_AUTHOR = CONTENT_OPF.replace(
    "    <dc:creator>Ada Lovelace</dc:creator>\n", ""
)


@pytest.fixture
def sample_epub_no_author(tmp_path: Path) -> Path:
    path = tmp_path / "sample_no_author.epub"
    with zipfile.ZipFile(path, "w") as z:
        z.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        z.writestr("META-INF/container.xml", CONTAINER_XML)
        z.writestr("OEBPS/content.opf", CONTENT_OPF_NO_AUTHOR)
        z.writestr("OEBPS/chap1.xhtml", CHAPTER_XHTML)
    return path
```

- [ ] **Step 4: Add `BookMeta` to `backend/src/vimarsha/models.py`**

Append:

```python
class BookMeta(BaseModel):
    """Book-level metadata from the EPUB OPF (distinct from chapter titles)."""
    model_config = ConfigDict(populate_by_name=True)

    title: str
    author: str = ""
```

- [ ] **Step 5: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_metadata.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'vimarsha.metadata'`

- [ ] **Step 6: Write `backend/src/vimarsha/metadata.py`**

```python
from __future__ import annotations

from ebooklib import epub

from vimarsha.models import BookMeta


def _first(values) -> str:
    """ebooklib metadata is a list of (value, attrs) tuples; take the first value."""
    if values:
        return values[0][0] or ""
    return ""


def read_book_meta(epub_path: str) -> BookMeta:
    """Read book-level title and author (creator) from the EPUB OPF."""
    book = epub.read_epub(epub_path)
    title = _first(book.get_metadata("DC", "title"))
    author = _first(book.get_metadata("DC", "creator"))
    return BookMeta(title=title, author=author)
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_metadata.py -v`
Expected: PASS (2 passed)

- [ ] **Step 8: Run the full backend suite (conftest changed — make sure nothing broke)**

Run: `cd backend && uv run pytest`
Expected: all pass (the prior 41 + 2 new = 43). If a Plan-1 test asserted exact OPF content it would break — none do; the chapter title comes from the `<h1>`, not the OPF.

- [ ] **Step 9: Commit**

```bash
git add backend/src/vimarsha/metadata.py backend/src/vimarsha/models.py backend/tests/test_metadata.py backend/tests/conftest.py
git commit -m "feat: book metadata extractor (title/author) from EPUB OPF (Plan 3a Task 1)"
```

---

## Task 2: Backend — `POST /toc` endpoint

Returns book metadata + the ordered chapter list with NO narration (fast, GPU-free).

**Files:**
- Modify: `backend/src/vimarsha/models.py`, `backend/src/vimarsha/server.py`
- Create: `backend/tests/test_server_toc.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_server_toc.py
from fastapi.testclient import TestClient

from vimarsha.server import app


def test_toc_returns_book_meta_and_chapters(sample_epub):
    client = TestClient(app)
    with open(sample_epub, "rb") as f:
        resp = client.post(
            "/toc",
            files={"file": ("sample.epub", f, "application/epub+zip")},
        )
    assert resp.status_code == 200
    data = resp.json()
    assert data["book"] == {"title": "Test Book", "author": "Ada Lovelace"}
    assert data["chapters"] == [
        {"index": 0, "chapterId": "chap1", "title": "The Engine"}
    ]


def test_toc_does_not_require_a_synth(sample_epub):
    # /toc must not construct ChatterboxSynth (no GPU in CI). No dependency override here;
    # if it tried to build the real synth, this test would error on import/torch.
    client = TestClient(app)
    with open(sample_epub, "rb") as f:
        resp = client.post("/toc", files={"file": ("s.epub", f, "application/epub+zip")})
    assert resp.status_code == 200
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_server_toc.py -v`
Expected: FAIL — 404 (route not found) on the POST.

- [ ] **Step 3: Add `ChapterSummary` and `TocResponse` to `backend/src/vimarsha/models.py`**

Append:

```python
class ChapterSummary(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    index: int
    chapter_id: str = Field(alias="chapterId")
    title: str


class TocResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    book: BookMeta
    chapters: list[ChapterSummary]
```

- [ ] **Step 4: Add the `/toc` route to `backend/src/vimarsha/server.py`**

Add these imports at the top (merge with existing imports):

```python
from fastapi.concurrency import run_in_threadpool

from vimarsha.metadata import read_book_meta
from vimarsha.models import ChapterSummary, TocResponse
```

Add this route (place it above the existing `/import` route):

```python
@app.post("/toc")
async def toc(file: UploadFile = File(...)):
    import tempfile
    from pathlib import Path as _Path

    tmp = tempfile.NamedTemporaryFile(suffix=".epub", delete=False)
    try:
        tmp.write(await file.read())
        tmp.flush()
        tmp.close()
        meta = await run_in_threadpool(read_book_meta, tmp.name)
        bundles = await run_in_threadpool(ingest_epub, tmp.name)
    finally:
        _Path(tmp.name).unlink(missing_ok=True)

    chapters = [
        ChapterSummary(index=i, chapter_id=b.chapter_id, title=b.title)
        for i, b in enumerate(bundles)
    ]
    return TocResponse(book=meta, chapters=chapters).model_dump(
        by_alias=True, exclude_none=True
    )
```

(`ingest_epub` is already imported in `server.py` from Plan 2; if not, add `from vimarsha.ingest import ingest_epub`.)

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_server_toc.py -v`
Expected: PASS (2 passed)

- [ ] **Step 6: Run the full backend suite**

Run: `cd backend && uv run pytest`
Expected: all pass (45 total).

- [ ] **Step 7: Commit**

```bash
git add backend/src/vimarsha/models.py backend/src/vimarsha/server.py backend/tests/test_server_toc.py
git commit -m "feat: POST /toc returns book meta + chapter list, no narration (Plan 3a Task 2)"
```

---

## Task 3: Flutter project scaffold

**Files:** Create the `app/` Flutter project + dependencies.

- [ ] **Step 1: Create the Flutter app**

Run from repo root:
```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
flutter create --org com.vimarsha --project-name vimarsha --platforms=macos app
```

- [ ] **Step 2: Add dependencies**

```bash
cd app
flutter pub add flutter_riverpod just_audio dio go_router file_picker path path_provider
flutter pub add drift sqlite3_flutter_libs
flutter pub add freezed_annotation json_annotation
flutter pub add dev:build_runner dev:freezed dev:json_serializable dev:drift_dev
```

- [ ] **Step 3: Sanity-check the toolchain**

Run: `cd app && flutter analyze 2>&1 | tail -5 && flutter test 2>&1 | tail -5`
Expected: `flutter analyze` reports no errors; the default `flutter test` (the counter widget test from `flutter create`) passes.

- [ ] **Step 4: Delete the default sample test and main scaffolding we'll replace**

```bash
cd app
rm -f test/widget_test.dart
```
Replace `app/lib/main.dart` with a minimal placeholder so analyze stays clean:

```dart
import 'package:flutter/material.dart';

void main() => runApp(const VimarshaApp());

class VimarshaApp extends StatelessWidget {
  const VimarshaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Vimarsha'))),
    );
  }
}
```

- [ ] **Step 5: Verify analyze still clean**

Run: `cd app && flutter analyze 2>&1 | tail -3`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app
git commit -m "chore: scaffold Flutter app (macOS) with core deps (Plan 3a Task 3)"
```

---

## Task 4: Freezed models mirroring the shared contract

**Files:**
- Create: `app/lib/core/models/{block,figure,chapter_bundle,chapter_summary,book_meta}.dart`
- Test: `app/test/core/models/models_test.dart`

- [ ] **Step 1: Write the failing test (parses the committed shared fixture)**

```dart
// app/test/core/models/models_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/models/chapter_bundle.dart';
import 'package:vimarsha/core/models/book_meta.dart';

void main() {
  test('parses the shared sample bundle fixture', () {
    final file = File('../shared/fixtures/sample-chapter.bundle.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final bundle = ChapterBundle.fromJson(json);

    expect(bundle.chapterId, 'chap1');
    expect(bundle.title, 'The Engine');
    expect(bundle.blocks, isNotEmpty);
    expect(bundle.audio, 'chap1.mp3');
    // figure ms ranges were filled by narration
    final fig = bundle.figureMap.firstWhere((f) => f.figureId == 'b2');
    expect(fig.kind, 'figure');
    expect(fig.startMs, isNotNull);
    expect(fig.endMs, greaterThan(fig.startMs!));
    // paraTimings is a map of [start,end]
    expect(bundle.paraTimings['b0'], hasLength(2));
  });

  test('round-trips to json and back', () {
    final file = File('../shared/fixtures/sample-chapter.bundle.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final bundle = ChapterBundle.fromJson(json);
    final again = ChapterBundle.fromJson(bundle.toJson());
    expect(again, bundle);
  });

  test('book meta parses title and author', () {
    final meta = BookMeta.fromJson({'title': 'Test Book', 'author': 'Ada Lovelace'});
    expect(meta.title, 'Test Book');
    expect(meta.author, 'Ada Lovelace');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/models/models_test.dart 2>&1 | tail -5`
Expected: FAIL — compile error, `chapter_bundle.dart` does not exist.

- [ ] **Step 3: Write the model source files**

`app/lib/core/models/block.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'block.freezed.dart';
part 'block.g.dart';

@freezed
class Block with _$Block {
  const factory Block({
    required String id,
    required int index,
    required String kind,
    String? text,
    int? level,
    String? src,
    String? alt,
    String? caption,
    String? html,
  }) = _Block;

  factory Block.fromJson(Map<String, dynamic> json) => _$BlockFromJson(json);
}
```

`app/lib/core/models/figure.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'figure.freezed.dart';
part 'figure.g.dart';

@freezed
class Figure with _$Figure {
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
  }) = _Figure;

  factory Figure.fromJson(Map<String, dynamic> json) => _$FigureFromJson(json);
}
```

`app/lib/core/models/chapter_bundle.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'block.dart';
import 'figure.dart';

part 'chapter_bundle.freezed.dart';
part 'chapter_bundle.g.dart';

@freezed
class ChapterBundle with _$ChapterBundle {
  const factory ChapterBundle({
    required String chapterId,
    required String title,
    required List<Block> blocks,
    required List<Figure> figureMap,
    String? audio,
    @Default(<String, List<int>>{}) Map<String, List<int>> paraTimings,
  }) = _ChapterBundle;

  factory ChapterBundle.fromJson(Map<String, dynamic> json) =>
      _$ChapterBundleFromJson(json);
}
```

`app/lib/core/models/chapter_summary.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chapter_summary.freezed.dart';
part 'chapter_summary.g.dart';

@freezed
class ChapterSummary with _$ChapterSummary {
  const factory ChapterSummary({
    required int index,
    required String chapterId,
    required String title,
  }) = _ChapterSummary;

  factory ChapterSummary.fromJson(Map<String, dynamic> json) =>
      _$ChapterSummaryFromJson(json);
}
```

`app/lib/core/models/book_meta.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_meta.freezed.dart';
part 'book_meta.g.dart';

@freezed
class BookMeta with _$BookMeta {
  const factory BookMeta({
    required String title,
    @Default('') String author,
  }) = _BookMeta;

  factory BookMeta.fromJson(Map<String, dynamic> json) =>
      _$BookMetaFromJson(json);
}
```

- [ ] **Step 4: Generate freezed/json code**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5`
Expected: "Succeeded" with generated `.freezed.dart` and `.g.dart` files.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/core/models/models_test.dart 2>&1 | tail -5`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit (include generated files so CI need not run codegen)**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/models app/test/core/models
git commit -m "feat: freezed models mirroring the shared bundle contract (Plan 3a Task 4)"
```

---

## Task 5: FileStore (filesystem layout)

**Files:**
- Create: `app/lib/core/storage/file_store.dart`
- Test: `app/test/core/storage/file_store_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/storage/file_store_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/storage/file_store.dart';

void main() {
  late Directory tmp;
  late FileStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vimarsha_fs');
    store = FileStore(tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('paths are namespaced by book id and chapter index', () {
    expect(store.epubFile('bookA').path,
        '${tmp.path}/books/bookA/book.epub');
    expect(store.bundleFile('bookA', 2).path,
        '${tmp.path}/books/bookA/ch2/bundle.json');
    expect(store.audioFile('bookA', 2).path,
        '${tmp.path}/books/bookA/ch2/audio.mp3');
  });

  test('ensureChapterDir creates the chapter directory', () async {
    final dir = await store.ensureChapterDir('bookA', 1);
    expect(dir.existsSync(), isTrue);
    expect(dir.path, '${tmp.path}/books/bookA/ch1');
  });

  test('removeBook deletes the whole book directory', () async {
    await store.ensureChapterDir('bookA', 0);
    await store.removeBook('bookA');
    expect(Directory('${tmp.path}/books/bookA').existsSync(), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/storage/file_store_test.dart 2>&1 | tail -5`
Expected: FAIL — `file_store.dart` does not exist.

- [ ] **Step 3: Write `app/lib/core/storage/file_store.dart`**

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

/// Owns the on-disk layout for cached books: the original EPUB, and per-chapter
/// bundle JSON + audio. All paths are derived from a single root directory.
class FileStore {
  FileStore(this.root);

  final Directory root;

  Directory _booksDir() => Directory(p.join(root.path, 'books'));
  Directory bookDir(String bookId) => Directory(p.join(_booksDir().path, bookId));
  Directory chapterDir(String bookId, int index) =>
      Directory(p.join(bookDir(bookId).path, 'ch$index'));

  File epubFile(String bookId) => File(p.join(bookDir(bookId).path, 'book.epub'));
  File bundleFile(String bookId, int index) =>
      File(p.join(chapterDir(bookId, index).path, 'bundle.json'));
  File audioFile(String bookId, int index) =>
      File(p.join(chapterDir(bookId, index).path, 'audio.mp3'));

  Future<Directory> ensureBookDir(String bookId) =>
      bookDir(bookId).create(recursive: true);
  Future<Directory> ensureChapterDir(String bookId, int index) =>
      chapterDir(bookId, index).create(recursive: true);

  Future<void> removeBook(String bookId) async {
    final dir = bookDir(bookId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> removeChapter(String bookId, int index) async {
    final dir = chapterDir(bookId, index);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/storage/file_store_test.dart 2>&1 | tail -5`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/storage app/test/core/storage
git commit -m "feat: FileStore on-disk layout for cached books (Plan 3a Task 5)"
```

---

## Task 6: Drift database (Books, Chapters)

**Files:**
- Create: `app/lib/core/db/database.dart`
- Test: `app/test/core/db/database_test.dart`

- [ ] **Step 1: Write the failing test (real in-memory Drift)**

```dart
// app/test/core/db/database_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('insert a book and read it back', () async {
    await db.into(db.books).insert(BooksCompanion.insert(
          id: 'b1', title: 'Test Book', author: const Value('Ada'),
          epubPath: '/tmp/b1/book.epub',
        ));
    final rows = await db.select(db.books).get();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Test Book');
    expect(rows.single.author, 'Ada');
  });

  test('chapter download status defaults to none and position to 0', () async {
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
          bookId: 'b1', chapterIndex: 0, chapterId: 'chap1', title: 'The Engine',
        ));
    final ch = (await db.select(db.chapters).get()).single;
    expect(ch.downloadStatus, 'none');
    expect(ch.positionMs, 0);
    expect(ch.bundlePath, isNull);
  });

  test('chapter primary key is (bookId, chapterIndex)', () async {
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
          bookId: 'b1', chapterIndex: 0, chapterId: 'chap1', title: 'A'));
    // same (bookId, index) must conflict
    expect(
      () => db.into(db.chapters).insert(ChaptersCompanion.insert(
            bookId: 'b1', chapterIndex: 0, chapterId: 'chap1', title: 'A')),
      throwsA(isA<Exception>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/db/database_test.dart 2>&1 | tail -5`
Expected: FAIL — `database.dart` does not exist.

- [ ] **Step 3: Write `app/lib/core/db/database.dart`**

```dart
import 'package:drift/drift.dart';

part 'database.g.dart';

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().withDefault(const Constant(''))();
  TextColumn get epubPath => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Chapters extends Table {
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  TextColumn get chapterId => text()();
  TextColumn get title => text()();
  TextColumn get downloadStatus => text().withDefault(const Constant('none'))();
  TextColumn get bundlePath => text().nullable()();
  TextColumn get audioPath => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {bookId, chapterIndex};
}

@DriftDatabase(tables: [Books, Chapters])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
```

- [ ] **Step 4: Generate Drift code**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5`
Expected: "Succeeded"; `database.g.dart` generated.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/core/db/database_test.dart 2>&1 | tail -5`
Expected: PASS (3 tests).

- [ ] **Step 6: Run the whole app test suite + analyze**

Run: `cd app && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -5`
Expected: `No issues found!` and all tests pass (models 3 + file_store 3 + database 3 = 9).

- [ ] **Step 7: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/db app/test/core/db
git commit -m "feat: Drift database for Books and Chapters (Plan 3a Task 6)"
```

---

## Self-Review

**Spec coverage (Phase 3 spec §2.1 structure, §2.3 persistence, §3 backend additions, §6 testing):**
- §3.1 metadata extractor → Task 1. ✅
- §3.2 `/toc` (book meta + chapters, no narration) → Task 2. ✅
- §2.1 Flutter scaffold (macOS, Riverpod/just_audio/dio/etc. deps) → Task 3. ✅
- §2.1 freezed models mirroring contract + §6 model fixture test → Task 4. ✅
- §2.3 FileStore → Task 5. ✅
- §2.3 Drift Books/Chapters → Task 6. ✅
- Repositories, BackendClient, AudioHandler, screens, player, Dockerfile/RunPod, integration test → **Plan 3b** (explicitly out of scope for 3a). Noted, not gaps.

**Placeholder scan:** none — every step has concrete code/commands + expected output.

**Type consistency:** Backend `BookMeta`/`ChapterSummary`/`TocResponse` field aliases (`chapterId`) match the camelCase contract and the Dart models. Dart Drift column getter is `chapterIndex` (avoids the SQL reserved word `index`) and the tests use `chapterIndex` consistently in `ChaptersCompanion.insert`. Model field names (`figureId`, `startPara`, `startMs`, `paraTimings`, `figureMap`) match `shared/bundle.schema.json` exactly so `fromJson` needs no `@JsonKey`. `FileStore` method names (`epubFile`, `bundleFile`, `audioFile`, `ensureChapterDir`, `removeBook`) are consistent between source and tests.
