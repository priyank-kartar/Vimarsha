# Plan 3b — Client Data Layer + Real-Chatterbox Integration Test (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the client's data layer — the backend HTTP client, the audio-handler seam, the Library/Chapter repositories, and the Riverpod wiring — fully unit-tested with fakes, then prove the whole stack against a **real backend running real Chatterbox** via an opt-in integration test.

**Architecture:** `DioBackendClient` implements the `BackendClient` interface (multipart upload to `/toc` and `/import`, byte download from `/audio`). `JustAudioHandler` implements the `AudioHandler` interface. `LibraryRepository` and `ChapterRepository` compose Drift + FileStore + BackendClient with all logic unit-tested using real in-memory Drift, real temp dirs, and a fake `BackendClient`. Riverpod providers wire it together and are override-friendly. A separate `test_integration/` suite (excluded from the default `flutter test`) drives the real pipeline.

**Tech Stack:** Builds on Plan 3a. Adds Dart `uuid` (runtime) and `http_mock_adapter` (dev). Backend `[tts]` extra (Chatterbox/torch) for the integration test, run on Apple Silicon MPS locally (or a RunPod CUDA box). ffprobe (already installed) asserts real audio duration.

**Prerequisite:** Plan 3a merged to `main` (models, FileStore, Drift `AppDatabase`, backend `/toc`).

---

## Branch setup (controller does this before Task 1)

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git checkout main && git checkout -b feat/client-data-layer
```

---

## File Structure

```
app/lib/core/
  models/toc_response.dart            # freezed TocResponse {book, chapters}
  settings/app_settings.dart          # backend base URL
  backend/backend_client.dart         # interface
  backend/dio_backend_client.dart     # Dio impl
  audio/audio_handler.dart            # interface
  audio/just_audio_handler.dart       # just_audio impl
app/lib/features/
  library/library_repository.dart
  book/chapter_repository.dart
app/lib/core/providers.dart           # Riverpod providers (override-friendly)
app/test/support/fake_backend_client.dart
app/test/core/models/toc_response_test.dart
app/test/core/backend/dio_backend_client_test.dart
app/test/features/library/library_repository_test.dart
app/test/features/book/chapter_repository_test.dart
app/test/core/providers_test.dart
app/test_integration/real_backend_test.dart   # opt-in, NOT in default `flutter test`
shared/fixtures/sample.epub                    # committed real EPUB for the integration test
backend/Dockerfile
backend/docs/runpod.md
```

---

## Task 1: `TocResponse` model

**Files:**
- Create: `app/lib/core/models/toc_response.dart`, `app/test/core/models/toc_response_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/models/toc_response_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/models/toc_response.dart';

void main() {
  test('parses /toc response shape', () {
    final toc = TocResponse.fromJson({
      'book': {'title': 'Test Book', 'author': 'Ada Lovelace'},
      'chapters': [
        {'index': 0, 'chapterId': 'chap1', 'title': 'The Engine'},
      ],
    });
    expect(toc.book.title, 'Test Book');
    expect(toc.book.author, 'Ada Lovelace');
    expect(toc.chapters, hasLength(1));
    expect(toc.chapters.single.chapterId, 'chap1');
    expect(toc.chapters.single.index, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/models/toc_response_test.dart 2>&1 | tail -5`
Expected: FAIL — `toc_response.dart` does not exist.

- [ ] **Step 3: Write `app/lib/core/models/toc_response.dart`**

(Uses freezed v3 `abstract class` form, matching the Plan 3a models.)

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'book_meta.dart';
import 'chapter_summary.dart';

part 'toc_response.freezed.dart';
part 'toc_response.g.dart';

@freezed
abstract class TocResponse with _$TocResponse {
  const factory TocResponse({
    required BookMeta book,
    required List<ChapterSummary> chapters,
  }) = _TocResponse;

  factory TocResponse.fromJson(Map<String, dynamic> json) =>
      _$TocResponseFromJson(json);
}
```

- [ ] **Step 4: Generate code**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -3`
Expected: "Succeeded"; `toc_response.freezed.dart` + `.g.dart` generated.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/core/models/toc_response_test.dart 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/models/toc_response.dart app/test/core/models/toc_response_test.dart
git commit -m "feat: TocResponse model (Plan 3b Task 1)"
```

---

## Task 2: App settings (backend base URL)

**Files:**
- Create: `app/lib/core/settings/app_settings.dart`, `app/test/core/settings/app_settings_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/settings/app_settings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/settings/app_settings.dart';

void main() {
  test('default base url points at localhost backend', () {
    expect(const AppSettings().backendBaseUrl, 'http://localhost:8000');
  });

  test('base url is overridable', () {
    const s = AppSettings(backendBaseUrl: 'http://10.0.0.5:8000');
    expect(s.backendBaseUrl, 'http://10.0.0.5:8000');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/settings/app_settings_test.dart 2>&1 | tail -5`
Expected: FAIL — `app_settings.dart` does not exist.

- [ ] **Step 3: Write `app/lib/core/settings/app_settings.dart`**

```dart
/// Immutable app configuration. For now just the backend location; the client
/// points at localhost (local MPS backend) by default and can be repointed at a
/// LAN/RunPod URL.
class AppSettings {
  const AppSettings({this.backendBaseUrl = 'http://localhost:8000'});

  final String backendBaseUrl;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/settings/app_settings_test.dart 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/settings app/test/core/settings
git commit -m "feat: AppSettings with backend base URL (Plan 3b Task 2)"
```

---

## Task 3: `BackendClient` interface + `DioBackendClient`

**Files:**
- Create: `app/lib/core/backend/backend_client.dart`, `app/lib/core/backend/dio_backend_client.dart`, `app/test/core/backend/dio_backend_client_test.dart`
- Add deps: `uuid`, `http_mock_adapter` (dev)

- [ ] **Step 1: Add dependencies**

```bash
cd app
flutter pub add uuid
flutter pub add dev:http_mock_adapter
```

- [ ] **Step 2: Write the interface `app/lib/core/backend/backend_client.dart`**

```dart
import 'dart:io';

import '../models/chapter_bundle.dart';
import '../models/toc_response.dart';

/// The seam over the network. Real impl: [DioBackendClient]; tests use a fake.
abstract class BackendClient {
  /// Upload an EPUB and get its book metadata + chapter list (no narration).
  Future<TocResponse> fetchToc(File epub);

  /// Upload an EPUB and narrate one chapter; returns the full bundle.
  Future<ChapterBundle> importChapter(File epub, int chapterIndex);

  /// Download the bytes of a generated chapter audio file by its name.
  Future<List<int>> downloadAudio(String audioName);
}
```

- [ ] **Step 3: Write the failing test**

```dart
// app/test/core/backend/dio_backend_client_test.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:vimarsha/core/backend/dio_backend_client.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late DioBackendClient client;
  late File epub;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = DioAdapter(dio: dio);
    client = DioBackendClient(dio);
    epub = File('${Directory.systemTemp.createTempSync('be').path}/book.epub')
      ..writeAsBytesSync([1, 2, 3]);
  });

  test('fetchToc posts to /toc and parses the response', () async {
    adapter.onPost(
      '/toc',
      (server) => server.reply(200, {
        'book': {'title': 'B', 'author': 'A'},
        'chapters': [
          {'index': 0, 'chapterId': 'chap1', 'title': 'One'}
        ],
      }),
      data: Matchers.any,
    );
    final toc = await client.fetchToc(epub);
    expect(toc.book.title, 'B');
    expect(toc.chapters.single.chapterId, 'chap1');
  });

  test('importChapter posts to /import with chapter_index and parses bundle',
      () async {
    adapter.onPost(
      '/import',
      (server) => server.reply(200, {
        'chapterId': 'chap1',
        'title': 'One',
        'blocks': [
          {'id': 'b0', 'index': 0, 'kind': 'paragraph', 'text': 'hi'}
        ],
        'figureMap': [],
        'audio': 'chap1.mp3',
        'paraTimings': {
          'b0': [0, 1000]
        },
      }),
      data: Matchers.any,
      queryParameters: {'chapter_index': 0},
    );
    final bundle = await client.importChapter(epub, 0);
    expect(bundle.chapterId, 'chap1');
    expect(bundle.audio, 'chap1.mp3');
    expect(bundle.paraTimings['b0'], [0, 1000]);
  });

  test('downloadAudio gets /audio/<name> as bytes', () async {
    adapter.onGet(
      '/audio/chap1.mp3',
      (server) => server.reply(200, [10, 20, 30]),
    );
    final bytes = await client.downloadAudio('chap1.mp3');
    expect(bytes, [10, 20, 30]);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `cd app && flutter test test/core/backend/dio_backend_client_test.dart 2>&1 | tail -5`
Expected: FAIL — `dio_backend_client.dart` does not exist.

- [ ] **Step 5: Write `app/lib/core/backend/dio_backend_client.dart`**

```dart
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/chapter_bundle.dart';
import '../models/toc_response.dart';
import 'backend_client.dart';

class DioBackendClient implements BackendClient {
  DioBackendClient(this._dio);

  final Dio _dio;

  Future<FormData> _epubForm(File epub) async => FormData.fromMap({
        'file': await MultipartFile.fromFile(epub.path, filename: 'book.epub'),
      });

  @override
  Future<TocResponse> fetchToc(File epub) async {
    final resp = await _dio.post('/toc', data: await _epubForm(epub));
    return TocResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  @override
  Future<ChapterBundle> importChapter(File epub, int chapterIndex) async {
    final resp = await _dio.post(
      '/import',
      data: await _epubForm(epub),
      queryParameters: {'chapter_index': chapterIndex},
    );
    return ChapterBundle.fromJson(resp.data as Map<String, dynamic>);
  }

  @override
  Future<List<int>> downloadAudio(String audioName) async {
    final resp = await _dio.get<List<int>>(
      '/audio/$audioName',
      options: Options(responseType: ResponseType.bytes),
    );
    return resp.data ?? <int>[];
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd app && flutter test test/core/backend/dio_backend_client_test.dart 2>&1 | tail -5`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/backend app/test/core/backend app/pubspec.yaml app/pubspec.lock
git commit -m "feat: BackendClient interface + DioBackendClient (Plan 3b Task 3)"
```

---

## Task 4: `AudioHandler` interface + `JustAudioHandler`

The interface is the test seam used by the player (Plan 3c); the real impl is a thin wrapper. No unit test here — `just_audio` needs a platform/device, so `JustAudioHandler` is exercised by the integration test + manual run. The interface's behavior is tested via a fake in repository/player tests.

**Files:**
- Create: `app/lib/core/audio/audio_handler.dart`, `app/lib/core/audio/just_audio_handler.dart`

- [ ] **Step 1: Write the interface `app/lib/core/audio/audio_handler.dart`**

```dart
/// The seam over the audio device. Real impl: [JustAudioHandler]; the player
/// controller is tested against a fake implementation.
abstract class AudioHandler {
  /// Load a local audio file; returns its total duration if known.
  Future<Duration?> load(String filePath);

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);

  /// Current playback position (updates as audio plays).
  Stream<Duration> get positionStream;

  /// Whether audio is currently playing.
  Stream<bool> get playingStream;

  Duration get position;

  Future<void> dispose();
}
```

- [ ] **Step 2: Write `app/lib/core/audio/just_audio_handler.dart`**

```dart
import 'package:just_audio/just_audio.dart';

import 'audio_handler.dart';

class JustAudioHandler implements AudioHandler {
  JustAudioHandler([AudioPlayer? player]) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<Duration?> load(String filePath) => _player.setFilePath(filePath);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Duration get position => _player.position;

  @override
  Future<void> dispose() => _player.dispose();
}
```

- [ ] **Step 3: Verify it compiles**

Run: `cd app && flutter analyze lib/core/audio 2>&1 | tail -3`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/audio
git commit -m "feat: AudioHandler interface + JustAudioHandler wrapper (Plan 3b Task 4)"
```

---

## Task 5: Fake BackendClient (test support) + `LibraryRepository`

**Files:**
- Create: `app/test/support/fake_backend_client.dart`, `app/lib/features/library/library_repository.dart`, `app/test/features/library/library_repository_test.dart`

- [ ] **Step 1: Write the fake `app/test/support/fake_backend_client.dart`**

```dart
import 'dart:io';

import 'package:vimarsha/core/backend/backend_client.dart';
import 'package:vimarsha/core/models/chapter_bundle.dart';
import 'package:vimarsha/core/models/toc_response.dart';

/// In-test BackendClient. Returns canned values; can be told to throw.
class FakeBackendClient implements BackendClient {
  FakeBackendClient({this.toc, this.bundle, this.audio = const [1, 2, 3, 4]});

  TocResponse? toc;
  ChapterBundle? bundle;
  List<int> audio;
  Object? throwOnToc;
  Object? throwOnImport;

  int tocCalls = 0;
  int importCalls = 0;

  @override
  Future<TocResponse> fetchToc(File epub) async {
    tocCalls++;
    if (throwOnToc != null) throw throwOnToc!;
    return toc!;
  }

  @override
  Future<ChapterBundle> importChapter(File epub, int chapterIndex) async {
    importCalls++;
    if (throwOnImport != null) throw throwOnImport!;
    return bundle!;
  }

  @override
  Future<List<int>> downloadAudio(String audioName) async => audio;
}
```

- [ ] **Step 2: Write the failing test**

```dart
// app/test/features/library/library_repository_test.dart
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/models/book_meta.dart';
import 'package:vimarsha/core/models/chapter_summary.dart';
import 'package:vimarsha/core/models/toc_response.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/library/library_repository.dart';

import '../../support/fake_backend_client.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late FileStore files;
  late FakeBackendClient backend;
  late File pickedEpub;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('lib');
    files = FileStore(tmp);
    backend = FakeBackendClient(
      toc: const TocResponse(
        book: BookMeta(title: 'Test Book', author: 'Ada'),
        chapters: [
          ChapterSummary(index: 0, chapterId: 'chap1', title: 'The Engine'),
          ChapterSummary(index: 1, chapterId: 'chap2', title: 'The Wheel'),
        ],
      ),
    );
    pickedEpub = File('${tmp.path}/picked.epub')..writeAsBytesSync([9, 9, 9]);
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  LibraryRepository repo() => LibraryRepository(
        db: db, files: files, backend: backend, idGen: () => 'bookX');

  test('addBook copies epub, stores book + chapters, returns id', () async {
    final id = await repo().addBook(pickedEpub);
    expect(id, 'bookX');

    expect(files.epubFile('bookX').existsSync(), isTrue);

    final books = await db.select(db.books).get();
    expect(books.single.title, 'Test Book');
    expect(books.single.author, 'Ada');

    final chapters = await db.select(db.chapters).get();
    expect(chapters, hasLength(2));
    expect(chapters.every((c) => c.downloadStatus == 'none'), isTrue);
    expect(chapters.map((c) => c.chapterIndex).toList()..sort(), [0, 1]);
  });

  test('backend failure leaves no rows and removes the copied epub', () async {
    backend.throwOnToc = Exception('boom');
    await expectLater(repo().addBook(pickedEpub), throwsException);
    expect(await db.select(db.books).get(), isEmpty);
    expect(await db.select(db.chapters).get(), isEmpty);
    expect(Directory('${tmp.path}/books/bookX').existsSync(), isFalse);
  });

  test('watchBooks emits inserted books', () async {
    await repo().addBook(pickedEpub);
    final books = await repo().watchBooks().first;
    expect(books.single.id, 'bookX');
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/features/library/library_repository_test.dart 2>&1 | tail -5`
Expected: FAIL — `library_repository.dart` does not exist.

- [ ] **Step 4: Write `app/lib/features/library/library_repository.dart`**

```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/backend/backend_client.dart';
import '../../core/db/database.dart';
import '../../core/storage/file_store.dart';

/// Owns the library: importing a book's table of contents and listing books.
class LibraryRepository {
  LibraryRepository({
    required AppDatabase db,
    required FileStore files,
    required BackendClient backend,
    String Function()? idGen,
  })  : _db = db,
        _files = files,
        _backend = backend,
        _idGen = idGen ?? (() => const Uuid().v4());

  final AppDatabase _db;
  final FileStore _files;
  final BackendClient _backend;
  final String Function() _idGen;

  /// Copy the picked EPUB into the store, fetch its TOC, and persist the book
  /// and its chapter rows. Returns the new book id. On backend failure, no rows
  /// are written and the copied EPUB is removed (no half-state).
  Future<String> addBook(File pickedEpub) async {
    final bookId = _idGen();
    await _files.ensureBookDir(bookId);
    final stored = _files.epubFile(bookId);
    await pickedEpub.copy(stored.path);

    try {
      final toc = await _backend.fetchToc(stored);
      await _db.transaction(() async {
        await _db.into(_db.books).insert(BooksCompanion.insert(
              id: bookId,
              title: toc.book.title,
              author: Value(toc.book.author),
              epubPath: stored.path,
            ));
        for (final c in toc.chapters) {
          await _db.into(_db.chapters).insert(ChaptersCompanion.insert(
                bookId: bookId,
                chapterIndex: c.index,
                chapterId: c.chapterId,
                title: c.title,
              ));
        }
      });
      return bookId;
    } catch (_) {
      await _files.removeBook(bookId);
      rethrow;
    }
  }

  Stream<List<Book>> watchBooks() =>
      (_db.select(_db.books)..orderBy([(b) => OrderingTerm(expression: b.createdAt)]))
          .watch();

  Future<void> deleteBook(String bookId) async {
    await (_db.delete(_db.chapters)..where((c) => c.bookId.equals(bookId))).go();
    await (_db.delete(_db.books)..where((b) => b.id.equals(bookId))).go();
    await _files.removeBook(bookId);
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/library/library_repository_test.dart 2>&1 | tail -5`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/test/support app/lib/features/library app/test/features/library
git commit -m "feat: LibraryRepository (add book, list, delete) + fake backend (Plan 3b Task 5)"
```

---

## Task 6: `ChapterRepository`

**Files:**
- Create: `app/lib/features/book/chapter_repository.dart`, `app/test/features/book/chapter_repository_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/book/chapter_repository_test.dart
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/models/chapter_bundle.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/book/chapter_repository.dart';

import '../../support/fake_backend_client.dart';

ChapterBundle _bundle() => const ChapterBundle(
      chapterId: 'chap1',
      title: 'The Engine',
      blocks: [],
      figureMap: [],
      audio: 'chap1.mp3',
      paraTimings: {},
    );

void main() {
  late AppDatabase db;
  late Directory tmp;
  late FileStore files;
  late FakeBackendClient backend;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('chap');
    files = FileStore(tmp);
    backend = FakeBackendClient(bundle: _bundle(), audio: [1, 2, 3, 4, 5]);
    // seed a book + one chapter row + a stored epub
    await files.ensureBookDir('bookX');
    await files.epubFile('bookX').writeAsBytes([0]);
    await db.into(db.books).insert(BooksCompanion.insert(
        id: 'bookX', title: 'B', epubPath: files.epubFile('bookX').path));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        bookId: 'bookX', chapterIndex: 0, chapterId: 'chap1', title: 'The Engine'));
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  ChapterRepository repo() =>
      ChapterRepository(db: db, files: files, backend: backend);

  Future<Chapter> row() async => (await (db.select(db.chapters)
        ..where((c) => c.bookId.equals('bookX') & c.chapterIndex.equals(0)))
      .get())
      .single;

  test('downloadChapter writes bundle + audio and marks ready', () async {
    await repo().downloadChapter('bookX', 0);
    final c = await row();
    expect(c.downloadStatus, 'ready');
    expect(c.bundlePath, files.bundleFile('bookX', 0).path);
    expect(c.audioPath, files.audioFile('bookX', 0).path);
    expect(files.bundleFile('bookX', 0).existsSync(), isTrue);
    expect(files.audioFile('bookX', 0).readAsBytesSync(), [1, 2, 3, 4, 5]);
  });

  test('import failure marks error and cleans partial files', () async {
    backend.throwOnImport = Exception('nope');
    await expectLater(repo().downloadChapter('bookX', 0), throwsException);
    final c = await row();
    expect(c.downloadStatus, 'error');
    expect(files.audioFile('bookX', 0).existsSync(), isFalse);
  });

  test('saveProgress persists positionMs', () async {
    await repo().saveProgress('bookX', 0, 4200);
    expect((await row()).positionMs, 4200);
  });

  test('watchChapters emits chapters in order', () async {
    final chapters = await repo().watchChapters('bookX').first;
    expect(chapters.single.chapterId, 'chap1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/book/chapter_repository_test.dart 2>&1 | tail -5`
Expected: FAIL — `chapter_repository.dart` does not exist.

- [ ] **Step 3: Write `app/lib/features/book/chapter_repository.dart`**

```dart
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/backend/backend_client.dart';
import '../../core/db/database.dart';
import '../../core/storage/file_store.dart';

/// Owns per-chapter download (narrated bundle + audio) and reading progress.
class ChapterRepository {
  ChapterRepository({
    required AppDatabase db,
    required FileStore files,
    required BackendClient backend,
  })  : _db = db,
        _files = files,
        _backend = backend;

  final AppDatabase _db;
  final FileStore _files;
  final BackendClient _backend;

  Future<void> _setStatus(String bookId, int index, String status) =>
      (_db.update(_db.chapters)
            ..where((c) => c.bookId.equals(bookId) & c.chapterIndex.equals(index)))
          .write(ChaptersCompanion(downloadStatus: Value(status)));

  /// Download a chapter: narrate via the backend, cache bundle + audio, mark
  /// ready. On any failure, partial files are removed and status becomes error.
  Future<void> downloadChapter(String bookId, int index) async {
    await _setStatus(bookId, index, 'downloading');
    try {
      final epub = _files.epubFile(bookId);
      final bundle = await _backend.importChapter(epub, index);
      final audioName = bundle.audio;
      if (audioName == null) {
        throw StateError('bundle has no audio for $bookId/$index');
      }

      await _files.ensureChapterDir(bookId, index);
      final bundleFile = _files.bundleFile(bookId, index);
      await bundleFile.writeAsString(jsonEncode(bundle.toJson()));

      final bytes = await _backend.downloadAudio(audioName);
      final audioFile = _files.audioFile(bookId, index);
      await audioFile.writeAsBytes(bytes);

      await (_db.update(_db.chapters)
            ..where((c) => c.bookId.equals(bookId) & c.chapterIndex.equals(index)))
          .write(ChaptersCompanion(
        downloadStatus: const Value('ready'),
        bundlePath: Value(bundleFile.path),
        audioPath: Value(audioFile.path),
      ));
    } catch (_) {
      await _files.removeChapter(bookId, index);
      await _setStatus(bookId, index, 'error');
      rethrow;
    }
  }

  Future<void> saveProgress(String bookId, int index, int positionMs) =>
      (_db.update(_db.chapters)
            ..where((c) => c.bookId.equals(bookId) & c.chapterIndex.equals(index)))
          .write(ChaptersCompanion(positionMs: Value(positionMs)));

  Stream<List<Chapter>> watchChapters(String bookId) => (_db.select(_db.chapters)
        ..where((c) => c.bookId.equals(bookId))
        ..orderBy([(c) => OrderingTerm(expression: c.chapterIndex)]))
      .watch();

  Future<Chapter?> getChapter(String bookId, int index) =>
      (_db.select(_db.chapters)
            ..where((c) => c.bookId.equals(bookId) & c.chapterIndex.equals(index)))
          .getSingleOrNull();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/book/chapter_repository_test.dart 2>&1 | tail -5`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/features/book app/test/features/book
git commit -m "feat: ChapterRepository (lazy download, status, progress) (Plan 3b Task 6)"
```

---

## Task 7: Riverpod providers

**Files:**
- Create: `app/lib/core/providers.dart`, `app/test/core/providers_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/providers_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/library/library_repository.dart';
import 'package:vimarsha/features/book/chapter_repository.dart';

import '../support/fake_backend_client.dart';

void main() {
  test('repository providers build from overridden db/files/backend', () {
    final db = AppDatabase(NativeDatabase.memory());
    final tmp = Directory.systemTemp.createTempSync('prov');
    addTearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      fileStoreProvider.overrideWithValue(FileStore(tmp)),
      backendClientProvider.overrideWithValue(FakeBackendClient()),
    ]);
    addTearDown(container.dispose);

    expect(container.read(libraryRepositoryProvider), isA<LibraryRepository>());
    expect(container.read(chapterRepositoryProvider), isA<ChapterRepository>());
  });

  test('backendClientProvider builds a DioBackendClient by default', () {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
      fileStoreProvider.overrideWithValue(
          FileStore(Directory.systemTemp.createTempSync('prov2'))),
    ]);
    addTearDown(container.dispose);
    // Reading it must not throw (constructs Dio from settings).
    expect(container.read(backendClientProvider), isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/providers_test.dart 2>&1 | tail -5`
Expected: FAIL — `providers.dart` does not exist.

- [ ] **Step 3: Write `app/lib/core/providers.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend/backend_client.dart';
import 'backend/dio_backend_client.dart';
import 'db/database.dart';
import 'settings/app_settings.dart';
import 'storage/file_store.dart';
import '../features/library/library_repository.dart';
import '../features/book/chapter_repository.dart';

/// Overridden in main() with a real opened database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// Overridden in main() with a FileStore rooted at the app documents dir.
final fileStoreProvider = Provider<FileStore>(
  (ref) => throw UnimplementedError('fileStoreProvider must be overridden'),
);

final settingsProvider = Provider<AppSettings>((ref) => const AppSettings());

final dioProvider = Provider<Dio>((ref) {
  final settings = ref.watch(settingsProvider);
  return Dio(BaseOptions(baseUrl: settings.backendBaseUrl));
});

final backendClientProvider = Provider<BackendClient>(
  (ref) => DioBackendClient(ref.watch(dioProvider)),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    db: ref.watch(databaseProvider),
    files: ref.watch(fileStoreProvider),
    backend: ref.watch(backendClientProvider),
  ),
);

final chapterRepositoryProvider = Provider<ChapterRepository>(
  (ref) => ChapterRepository(
    db: ref.watch(databaseProvider),
    files: ref.watch(fileStoreProvider),
    backend: ref.watch(backendClientProvider),
  ),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/providers_test.dart 2>&1 | tail -5`
Expected: PASS (2 tests).

- [ ] **Step 5: Run the whole app suite + analyze**

Run: `cd app && flutter analyze 2>&1 | tail -3 && flutter test 2>&1 | tail -5`
Expected: `No issues found!` and all unit tests pass (Plan 3a 10 + 3b: toc 1, settings 2, dio client 3, library 3, chapter 4, providers 2 = 25 total).

- [ ] **Step 6: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/providers.dart app/test/core/providers_test.dart
git commit -m "feat: Riverpod providers wiring db/files/backend/repos (Plan 3b Task 7)"
```

---

## Task 8: Backend Dockerfile + RunPod notes

**Files:**
- Create: `backend/Dockerfile`, `backend/.dockerignore`, `backend/docs/runpod.md`

- [ ] **Step 1: Write `backend/Dockerfile`**

```dockerfile
# Vimarsha backend with real Chatterbox TTS (CUDA). For RunPod or any GPU host.
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3.11 python3-pip ffmpeg git curl \
    && rm -rf /var/lib/apt/lists/*

# uv for fast, reproducible installs
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /app
COPY pyproject.toml uv.lock ./
COPY src ./src
# Install with the real-TTS extra (chatterbox-tts + torch).
RUN uv sync --extra tts --frozen

EXPOSE 8000
CMD ["uv", "run", "uvicorn", "vimarsha.server:app", "--host", "0.0.0.0", "--port", "8000"]
```

- [ ] **Step 2: Write `backend/.dockerignore`**

```gitignore
.venv/
__pycache__/
*.pyc
.pytest_cache/
tests/
docs/
```

- [ ] **Step 3: Write `backend/docs/runpod.md`**

```markdown
# Running the Vimarsha backend on a GPU box

The backend is a stateless FastAPI service. Two ways to run it with **real Chatterbox**:

## Local (Apple Silicon, MPS) — default for dev
    cd backend
    uv sync --extra tts          # first run downloads the Chatterbox model
    uv run uvicorn vimarsha.server:app --port 8000
The client's default base URL (`http://localhost:8000`) points here.

## RunPod (CUDA) — for heavier / CI runs
1. Build and push the image (from `backend/`):
       docker build -t <your-registry>/vimarsha-backend:latest .
       docker push <your-registry>/vimarsha-backend:latest
2. Create a RunPod GPU pod from that image, expose port 8000.
3. Point the client at the pod URL by constructing `AppSettings(backendBaseUrl: 'https://<pod>-8000.proxy.runpod.net')` (wired into settings in a later plan), or set it when running the integration test:
       VIMARSHA_BACKEND_URL=https://<pod>-8000.proxy.runpod.net flutter test test_integration/real_backend_test.dart

The first `/import` is slow (model load + narration); subsequent calls are faster.
```

- [ ] **Step 4: Sanity-check the Dockerfile parses (no build needed)**

Run: `cd backend && docker --version >/dev/null 2>&1 && echo "docker present (build optional)" || echo "docker not installed — skip build, file is still committed"`
Expected: prints one of the two messages (we do not require a Docker build here).

- [ ] **Step 5: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add backend/Dockerfile backend/.dockerignore backend/docs/runpod.md
git commit -m "chore: backend Dockerfile + RunPod run notes (Plan 3b Task 8)"
```

---

## Task 9: Committed sample EPUB fixture for the integration test

**Files:**
- Create: `shared/fixtures/sample.epub`

- [ ] **Step 1: Generate a real EPUB from the backend test constants**

Run:
```bash
cd backend && uv run python - <<'PY'
import zipfile
from pathlib import Path
from tests.conftest import CHAPTER_XHTML, CONTAINER_XML, CONTENT_OPF
out = Path("..") / "shared" / "fixtures" / "sample.epub"
out.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(out, "w") as z:
    z.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
    z.writestr("META-INF/container.xml", CONTAINER_XML)
    z.writestr("OEBPS/content.opf", CONTENT_OPF)
    z.writestr("OEBPS/chap1.xhtml", CHAPTER_XHTML)
print("wrote", out.resolve())
PY
```
Expected: prints the path to `shared/fixtures/sample.epub`.

- [ ] **Step 2: Verify it's a valid EPUB the backend can read**

Run:
```bash
cd backend && uv run python -c "
from vimarsha.metadata import read_book_meta
from vimarsha.ingest import ingest_epub
m = read_book_meta('../shared/fixtures/sample.epub')
b = ingest_epub('../shared/fixtures/sample.epub')
print(m.title, '|', m.author, '|', len(b), 'chapters')
"
```
Expected: `Test Book | Ada Lovelace | 1 chapters`

- [ ] **Step 3: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add shared/fixtures/sample.epub
git commit -m "test: committed sample.epub fixture for integration tests (Plan 3b Task 9)"
```

---

## Task 10: Real-Chatterbox integration test (opt-in)

This test hits a **running backend with real Chatterbox** and asserts the true pipeline: TOC, narration (real audio with timings + figure ms), and that the downloaded audio is a real, non-trivial MP3 (verified with `ffprobe`). It lives in `test_integration/` so the default `flutter test` (which only runs `test/`) never executes it.

**Files:**
- Create: `app/test_integration/real_backend_test.dart`, `app/test_integration/README.md`

- [ ] **Step 1: Write `app/test_integration/real_backend_test.dart`**

```dart
// Opt-in. Requires a running backend with real Chatterbox.
// Run: VIMARSHA_BACKEND_URL=http://localhost:8000 \
//        flutter test test_integration/real_backend_test.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/backend/dio_backend_client.dart';

void main() {
  final baseUrl =
      Platform.environment['VIMARSHA_BACKEND_URL'] ?? 'http://localhost:8000';

  late DioBackendClient client;
  late File epub;

  setUpAll(() {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5), // narration can be slow
    ));
    client = DioBackendClient(dio);
    epub = File('../shared/fixtures/sample.epub');
    expect(epub.existsSync(), isTrue,
        reason: 'run Plan 3b Task 9 to generate the fixture');
  });

  test('real backend: /toc returns book metadata + chapters', () async {
    final toc = await client.fetchToc(epub);
    expect(toc.book.title, 'Test Book');
    expect(toc.book.author, 'Ada Lovelace');
    expect(toc.chapters, isNotEmpty);
    expect(toc.chapters.first.title, 'The Engine');
  });

  test('real backend: import produces a narrated bundle with figure timings',
      () async {
    final bundle = await client.importChapter(epub, 0);
    expect(bundle.chapterId, 'chap1');
    expect(bundle.audio, isNotNull);
    expect(bundle.paraTimings, isNotEmpty);
    // Figure 1 (block b2) should have real ms span filled by narration.
    final fig = bundle.figureMap.firstWhere((f) => f.figureId == 'b2');
    expect(fig.startMs, isNotNull);
    expect(fig.endMs, greaterThan(fig.startMs!));

    // Download the audio and confirm it is a real, non-trivial MP3.
    final bytes = await client.downloadAudio(bundle.audio!);
    expect(bytes.length, greaterThan(5000),
        reason: 'real narration should be more than a few KB');

    final tmp = File('${Directory.systemTemp.createTempSync('itaudio').path}/a.mp3')
      ..writeAsBytesSync(bytes);
    final probe = await Process.run('ffprobe', [
      '-v', 'error', '-show_entries', 'format=duration',
      '-of', 'default=nw=1:nk=1', tmp.path,
    ]);
    expect(probe.exitCode, 0, reason: 'ffprobe must read the MP3');
    final duration = double.parse((probe.stdout as String).trim());
    expect(duration, greaterThan(1.0),
        reason: 'a narrated chapter should be over a second of audio');
  });
}
```

- [ ] **Step 2: Write `app/test_integration/README.md`**

```markdown
# Integration tests (real backend, real Chatterbox)

These are NOT run by `flutter test` (which only runs `test/`). Run them explicitly,
against a backend serving real Chatterbox.

1. Start the backend with the real TTS extra (see `backend/docs/runpod.md`):
       cd backend
       uv sync --extra tts
       uv run uvicorn vimarsha.server:app --port 8000
   (First run downloads the Chatterbox model and is slow.)

2. From `app/`, run the integration suite:
       flutter test test_integration/real_backend_test.dart
   Or against a RunPod URL:
       VIMARSHA_BACKEND_URL=https://<pod>-8000.proxy.runpod.net \
         flutter test test_integration/real_backend_test.dart

What it proves: `/toc` metadata, real narration with paragraph timings + figure
ms spans, and that the downloaded audio is a real MP3 over a second long (via ffprobe).
```

- [ ] **Step 3: Confirm the default unit suite still ignores it**

Run: `cd app && flutter test 2>&1 | tail -3`
Expected: the 25 unit tests pass; nothing under `test_integration/` runs.

- [ ] **Step 4: Run the integration test for real (manual gate)**

Start the backend per the README (`uv sync --extra tts`, then uvicorn on :8000), then:
Run: `cd app && flutter test test_integration/real_backend_test.dart 2>&1 | tail -10`
Expected: both integration tests PASS — real `/toc`, a narrated bundle with `b2` figure ms span, and a downloaded MP3 whose ffprobe duration > 1.0s.

> If no GPU/MPS backend is available in the execution environment, this step is the documented manual gate: report it as not-run-here with the exact command, rather than faking a pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/test_integration
git commit -m "test: opt-in real-Chatterbox integration test (Plan 3b Task 10)"
```

---

## Self-Review

**Spec coverage (Phase 3 spec §2.1 backend/audio seams, §2.2 fakes, §4 data flow, §6 testing, §7 RunPod):**
- §2.2 `BackendClient` + `DioBackendClient` → Task 3. ✅
- §2.2 `AudioHandler` + `JustAudioHandler` → Task 4. ✅
- §4 add-book flow (copy epub, /toc, persist) → Task 5 (`LibraryRepository`). ✅
- §4 lazy download (status transitions, cache, error cleanup) + progress → Task 6 (`ChapterRepository`). ✅
- §2.1 Riverpod wiring → Task 7. ✅
- §7 Dockerfile + RunPod notes → Task 8. ✅
- §6 integration (real Chatterbox) → Tasks 9–10. ✅
- Screens + player controller → **Plan 3c** (out of scope). Noted, not gaps.

**Placeholder scan:** none — every step has concrete code/commands + expected output. The one "manual gate" (Task 10 Step 4) is explicit about reporting not-run-here rather than faking.

**Type consistency:** `BackendClient` methods (`fetchToc`, `importChapter`, `downloadAudio`) are identical in the interface, `DioBackendClient`, and `FakeBackendClient`, and are called consistently in both repositories and the integration test. `AudioHandler` members match between interface and `JustAudioHandler`. Drift companions use `chapterIndex` and `Value(...)` exactly as generated in Plan 3a; `BooksCompanion.insert`/`ChaptersCompanion.insert` argument names match the Plan 3a schema. Provider names (`databaseProvider`, `fileStoreProvider`, `settingsProvider`, `dioProvider`, `backendClientProvider`, `libraryRepositoryProvider`, `chapterRepositoryProvider`) are consistent between `providers.dart` and `providers_test.dart`. Model field access (`bundle.audio`, `bundle.paraTimings`, `figure.startMs/endMs`, `toc.book.title/author`, `chapter.chapterId`) matches the Plan 3a freezed models and the shared contract.
