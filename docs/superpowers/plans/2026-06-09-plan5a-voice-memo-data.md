# Plan 5a — Voice Memo Data Layer + Transcribe Backend (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything needed to capture, store, and transcribe a voice memo — minus the UI: a backend `/transcribe` endpoint, a `RecorderHandler` mic seam, the `Memos` table + `MemoRepository`, and mic entitlements.

**Architecture:** Backend gains `POST /transcribe` (faster-whisper behind a `get_transcriber` dependency so tests inject a fake). The client gets a `RecorderHandler` interface (real `record`-package impl + fake), `BackendClient.transcribe`, a `FileStore` memos dir, a Drift `Memos` table (with a schema migration), and a `MemoRepository` that orchestrates record→store→transcribe with graceful offline degradation.

**Tech Stack:** Backend: Python 3.13, FastAPI, faster-whisper (in `[tts]` extra), pytest. Client: Flutter, Riverpod, drift, dio, `record` (new). No new UI.

**Prerequisite:** Plans 1–4b merged. Spec: `docs/superpowers/specs/2026-06-09-vimarsha-voice-memos-design.md`.

---

## Branch setup (controller does this before Task 1)

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git checkout main && git checkout -b feat/voice-memo-data
```

---

## File Structure

```
backend/
  src/vimarsha/transcribe.py        # NEW: Transcriber protocol + FasterWhisperTranscriber
  src/vimarsha/server.py            # + get_transcriber + POST /transcribe
  pyproject.toml                    # faster-whisper in [tts] extra
  tests/test_server_transcribe.py   # NEW (fake transcriber)
app/
  pubspec.yaml                              # + record
  lib/core/audio/recorder_handler.dart       # NEW: interface + RecorderPermissionDenied
  lib/core/audio/record_recorder_handler.dart# NEW: record-package impl
  lib/core/backend/backend_client.dart        # + transcribe
  lib/core/backend/dio_backend_client.dart    # + transcribe
  lib/core/storage/file_store.dart            # + memosDir/memoFile/ensureMemosDir
  lib/core/db/database.dart                   # + Memos table + migration (schemaVersion 2)
  lib/features/notes/memo_repository.dart      # NEW
  lib/core/providers.dart                     # + recorderHandlerProvider, memoRepositoryProvider
  macos/Runner/DebugProfile.entitlements      # + audio-input
  macos/Runner/Release.entitlements           # + audio-input
  macos/Runner/Info.plist                     # + NSMicrophoneUsageDescription
  test/support/fake_backend_client.dart        # + transcribe
  test/support/fake_recorder_handler.dart      # NEW
  test/core/backend/dio_backend_client_test.dart  # + transcribe test
  test/core/storage/file_store_test.dart          # + memoFile test
  test/core/db/database_test.dart                 # + Memos insert test
  test/features/notes/memo_repository_test.dart    # NEW
```

---

## Task 1: Backend — `/transcribe` + transcriber seam

**Files:** Create `backend/src/vimarsha/transcribe.py`, `backend/tests/test_server_transcribe.py`; Modify `backend/src/vimarsha/server.py`, `backend/pyproject.toml`.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_server_transcribe.py
from fastapi.testclient import TestClient

from vimarsha.server import app, get_transcriber


class _FakeTranscriber:
    def transcribe(self, audio_path: str) -> str:
        return "hello from the test"


def test_transcribe_returns_text(tmp_path):
    app.dependency_overrides[get_transcriber] = lambda: _FakeTranscriber()
    clip = tmp_path / "memo.m4a"
    clip.write_bytes(b"\x00\x01\x02\x03")
    client = TestClient(app)
    with open(clip, "rb") as f:
        resp = client.post("/transcribe", files={"file": ("memo.m4a", f, "audio/m4a")})
    assert resp.status_code == 200
    assert resp.json() == {"text": "hello from the test"}
    app.dependency_overrides.clear()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && uv run pytest tests/test_server_transcribe.py -v`
Expected: FAIL — `cannot import name 'get_transcriber'` / 404 on `/transcribe`.

- [ ] **Step 3: Write `backend/src/vimarsha/transcribe.py`**

```python
from __future__ import annotations

from typing import Optional, Protocol


class Transcriber(Protocol):
    def transcribe(self, audio_path: str) -> str:
        """Return the transcript text for an audio file."""
        ...


class FasterWhisperTranscriber:
    """Real transcriber. Requires the `[tts]` extra (faster-whisper). CPU + int8
    by default (works on Apple Silicon; CTranslate2 has no MPS backend)."""

    def __init__(
        self,
        model_size: str = "base",
        device: str = "cpu",
        compute_type: str = "int8",
    ):
        from faster_whisper import WhisperModel

        self._model = WhisperModel(model_size, device=device, compute_type=compute_type)

    def transcribe(self, audio_path: str) -> str:
        segments, _info = self._model.transcribe(audio_path)
        return "".join(seg.text for seg in segments).strip()
```

- [ ] **Step 4: Add `get_transcriber` + `/transcribe` to `backend/src/vimarsha/server.py`**

Add the import (merge):

```python
from vimarsha.transcribe import FasterWhisperTranscriber, Transcriber
```

Add a cached factory + route (place near `get_synth`/the other routes):

```python
_transcriber: Transcriber | None = None


def get_transcriber() -> Transcriber:
    """Cached faster-whisper transcriber (loaded once); overridden in tests."""
    global _transcriber
    if _transcriber is None:
        _transcriber = FasterWhisperTranscriber()
    return _transcriber


@app.post("/transcribe")
async def transcribe(
    file: UploadFile = File(...),
    transcriber: Transcriber = Depends(get_transcriber),
):
    suffix = Path(file.filename or "audio").suffix or ".m4a"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await file.read())
        tmp.flush()
        tmp_path_str = tmp.name
    try:
        text = await run_in_threadpool(transcriber.transcribe, tmp_path_str)
    finally:
        Path(tmp_path_str).unlink(missing_ok=True)
    return {"text": text}
```

- [ ] **Step 5: Add `faster-whisper` to the `[tts]` extra in `backend/pyproject.toml`**

```toml
[project.optional-dependencies]
tts = [
    "chatterbox-tts",
    "faster-whisper",
    "setuptools<81",
    "torch",
    "torchaudio",
]
```

- [ ] **Step 6: Run test to verify it passes**

Run: `cd backend && uv run pytest tests/test_server_transcribe.py -v`
Expected: PASS (the fake transcriber is injected; no model download).

- [ ] **Step 7: Full backend suite**

Run: `cd backend && uv run pytest`
Expected: all pass (prior 51 + 1 new = 52).

- [ ] **Step 8: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add backend/src/vimarsha/transcribe.py backend/src/vimarsha/server.py backend/pyproject.toml backend/tests/test_server_transcribe.py
git commit -m "feat: POST /transcribe with faster-whisper seam (Plan 5a Task 1)"
```

---

## Task 2: Client — `RecorderHandler` + `record` impl + fake + mic entitlements

**Files:** Modify `app/pubspec.yaml`, macOS entitlements + Info.plist; Create
`recorder_handler.dart`, `record_recorder_handler.dart`,
`test/support/fake_recorder_handler.dart`.

- [ ] **Step 1: Add the `record` dependency**

```bash
cd app && flutter pub add record
```

- [ ] **Step 2: Write `app/lib/core/audio/recorder_handler.dart`**

```dart
/// The microphone seam. Real impl: [RecordRecorderHandler]; tests use a fake.
abstract class RecorderHandler {
  /// Begin recording to [filePath]. Throws [RecorderPermissionDenied] if the
  /// mic permission is not granted.
  Future<void> start(String filePath);

  /// Stop recording; returns the recorded file path (or null if nothing).
  Future<String?> stop();

  bool get isRecording;

  Future<void> dispose();
}

class RecorderPermissionDenied implements Exception {
  const RecorderPermissionDenied();
  @override
  String toString() => 'Microphone permission denied';
}
```

- [ ] **Step 3: Write `app/lib/core/audio/record_recorder_handler.dart`**

```dart
import 'package:record/record.dart';

import 'recorder_handler.dart';

class RecordRecorderHandler implements RecorderHandler {
  RecordRecorderHandler([AudioRecorder? recorder])
      : _rec = recorder ?? AudioRecorder();

  final AudioRecorder _rec;
  bool _recording = false;

  @override
  bool get isRecording => _recording;

  @override
  Future<void> start(String filePath) async {
    if (!await _rec.hasPermission()) {
      throw const RecorderPermissionDenied();
    }
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
    _recording = true;
  }

  @override
  Future<String?> stop() async {
    final path = await _rec.stop();
    _recording = false;
    return path;
  }

  @override
  Future<void> dispose() => _rec.dispose();
}
```

- [ ] **Step 4: Write `app/test/support/fake_recorder_handler.dart`**

```dart
import 'dart:io';

import 'package:vimarsha/core/audio/recorder_handler.dart';

/// In-test recorder: writes a small fake clip to the requested path on start so
/// the repository has a real file to copy.
class FakeRecorderHandler implements RecorderHandler {
  bool permissionDenied = false;
  bool _recording = false;
  String? startedPath;

  @override
  bool get isRecording => _recording;

  @override
  Future<void> start(String filePath) async {
    if (permissionDenied) throw const RecorderPermissionDenied();
    await File(filePath).writeAsBytes(const [1, 2, 3, 4]);
    startedPath = filePath;
    _recording = true;
  }

  @override
  Future<String?> stop() async {
    _recording = false;
    return startedPath;
  }

  @override
  Future<void> dispose() async {}
}
```

- [ ] **Step 5: Add macOS mic entitlements**

In BOTH `app/macos/Runner/DebugProfile.entitlements` and
`app/macos/Runner/Release.entitlements`, add inside the `<dict>`:

```xml
	<key>com.apple.security.device.audio-input</key>
	<true/>
```

In `app/macos/Runner/Info.plist`, add inside the top-level `<dict>`:

```xml
	<key>NSMicrophoneUsageDescription</key>
	<string>Vimarsha records voice notes about what you're reading.</string>
```

- [ ] **Step 6: Verify it compiles**

Run: `cd app && flutter analyze lib/core/audio test/support/fake_recorder_handler.dart 2>&1 | tail -3`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/pubspec.yaml app/pubspec.lock app/lib/core/audio/recorder_handler.dart app/lib/core/audio/record_recorder_handler.dart app/test/support/fake_recorder_handler.dart app/macos/Runner/DebugProfile.entitlements app/macos/Runner/Release.entitlements app/macos/Runner/Info.plist
git commit -m "feat: RecorderHandler seam + record impl + mic entitlements (Plan 5a Task 2)"
```

---

## Task 3: Client — `BackendClient.transcribe` + `FileStore.memoFile`

**Files:** Modify `backend_client.dart`, `dio_backend_client.dart`,
`file_store.dart`, `test/support/fake_backend_client.dart`,
`dio_backend_client_test.dart`, `file_store_test.dart`.

- [ ] **Step 1: Add `transcribe` to `app/lib/core/backend/backend_client.dart`**

```dart
  /// Upload an audio clip and get its transcript text.
  Future<String> transcribe(File audio);
```

- [ ] **Step 2: Implement it in `app/lib/core/backend/dio_backend_client.dart`**

```dart
  @override
  Future<String> transcribe(File audio) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(audio.path, filename: 'memo.m4a'),
    });
    final resp = await _dio.post('/transcribe', data: form);
    return (resp.data as Map<String, dynamic>)['text'] as String;
  }
```

- [ ] **Step 3: Add memo paths to `app/lib/core/storage/file_store.dart`**

```dart
  Directory memosDir() => Directory(p.join(root.path, 'memos'));
  File memoFile(String memoId) =>
      File(p.join(memosDir().path, '${_safeName(memoId)}.m4a'));
  Future<Directory> ensureMemosDir() => memosDir().create(recursive: true);
```

- [ ] **Step 4: Add `transcribe` to `app/test/support/fake_backend_client.dart`**

```dart
  String transcript = 'fake transcript';
  Object? throwOnTranscribe;
  final List<String> transcribeRequests = [];

  @override
  Future<String> transcribe(File audio) async {
    transcribeRequests.add(audio.path);
    if (throwOnTranscribe != null) throw throwOnTranscribe!;
    return transcript;
  }
```

- [ ] **Step 5: Write the failing tests**

Append to `app/test/core/backend/dio_backend_client_test.dart` (inside `main`):

```dart
  test('transcribe posts /transcribe and returns text', () async {
    adapter.onPost(
      '/transcribe',
      (server) => server.reply(200, {'text': 'spoken words'}),
      data: Matchers.any,
    );
    final text = await client.transcribe(epub); // any file works as the upload
    expect(text, 'spoken words');
  });
```

Append to `app/test/core/storage/file_store_test.dart` (inside `main`):

```dart
  test('memo files live under the memos dir', () {
    expect(store.memoFile('m123').path, '${tmp.path}/memos/m123.m4a');
  });

  test('rejects memo ids that attempt path traversal', () {
    expect(() => store.memoFile('../evil'), throwsArgumentError);
  });
```

- [ ] **Step 6: Run tests**

Run: `cd app && flutter test test/core/backend/dio_backend_client_test.dart test/core/storage/file_store_test.dart 2>&1 | tail -3`
Expected: PASS (incl. the 3 new). `flutter analyze` clean.

- [ ] **Step 7: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/backend app/lib/core/storage/file_store.dart app/test/support/fake_backend_client.dart app/test/core/backend/dio_backend_client_test.dart app/test/core/storage/file_store_test.dart
git commit -m "feat: BackendClient.transcribe + FileStore memo paths (Plan 5a Task 3)"
```

---

## Task 4: Client — `Memos` table + migration + `MemoRepository`

**Files:** Modify `app/lib/core/db/database.dart`, `app/lib/core/providers.dart`,
`app/test/core/db/database_test.dart`; Create
`app/lib/features/notes/memo_repository.dart`,
`app/test/features/notes/memo_repository_test.dart`.

- [ ] **Step 1: Write the failing DB test**

Append to `app/test/core/db/database_test.dart` (inside `main`):

```dart
  test('insert a memo and read it back; defaults applied', () async {
    await db.into(db.memos).insert(MemosCompanion.insert(
          id: 'm1', bookId: 'b1', chapterIndex: 0,
          positionMs: const Value(4200), audioPath: '/tmp/m1.m4a'));
    final m = (await db.select(db.memos).get()).single;
    expect(m.id, 'm1');
    expect(m.transcriptStatus, 'pending');
    expect(m.transcript, isNull);
    expect(m.positionMs, 4200);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/db/database_test.dart 2>&1 | tail -4`
Expected: FAIL — `db.memos`/`MemosCompanion` undefined.

- [ ] **Step 3: Update `app/lib/core/db/database.dart`**

Add the `Memos` table (after `Chapters`):

```dart
class Memos extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  TextColumn get blockId => text().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  TextColumn get audioPath => text()();
  TextColumn get transcript => text().nullable()();
  TextColumn get transcriptStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

Update the `@DriftDatabase` annotation + bump the schema version + add a
migration so existing on-disk databases gain the table:

```dart
@DriftDatabase(tables: [Books, Chapters, Memos])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(memos);
        },
      );
}
```

- [ ] **Step 4: Generate code + run the DB test**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -2`
Then: `cd app && flutter test test/core/db/database_test.dart 2>&1 | tail -3`
Expected: build succeeds; DB tests pass (existing + new).

- [ ] **Step 5: Write the failing `MemoRepository` test**

```dart
// app/test/features/notes/memo_repository_test.dart
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/notes/memo_repository.dart';

import '../../support/fake_backend_client.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late FileStore files;
  late FakeBackendClient backend;
  late File recorded;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('memo');
    files = FileStore(tmp);
    backend = FakeBackendClient();
    recorded = File('${tmp.path}/rec.m4a')..writeAsBytesSync(const [9, 9, 9]);
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  MemoRepository repo() => MemoRepository(
      db: db, files: files, backend: backend, idGen: () => 'memoX');

  Future<Memo> row() async => (await db.select(db.memos).get()).single;

  test('saveMemo caches audio, inserts row, fills transcript', () async {
    backend.transcript = 'this is my note';
    final id = await repo().saveMemo(
        bookId: 'b1', chapterIndex: 0, blockId: 'p3', positionMs: 4200,
        recordedFile: recorded);
    expect(id, 'memoX');
    expect(files.memoFile('memoX').existsSync(), isTrue);
    final m = await row();
    expect(m.bookId, 'b1');
    expect(m.blockId, 'p3');
    expect(m.positionMs, 4200);
    expect(m.transcript, 'this is my note');
    expect(m.transcriptStatus, 'done');
    expect(backend.transcribeRequests, isNotEmpty);
  });

  test('backend failure keeps the memo with error status', () async {
    backend.throwOnTranscribe = Exception('offline');
    await repo().saveMemo(
        bookId: 'b1', chapterIndex: 0, blockId: null, positionMs: 0,
        recordedFile: recorded);
    final m = await row();
    expect(m.transcriptStatus, 'error');
    expect(m.transcript, isNull);
    expect(files.memoFile('memoX').existsSync(), isTrue); // audio kept
  });

  test('retryTranscription fills a previously failed memo', () async {
    backend.throwOnTranscribe = Exception('offline');
    await repo().saveMemo(
        bookId: 'b1', chapterIndex: 0, blockId: null, positionMs: 0,
        recordedFile: recorded);
    backend.throwOnTranscribe = null;
    backend.transcript = 'recovered';
    await repo().retryTranscription('memoX');
    final m = await row();
    expect(m.transcriptStatus, 'done');
    expect(m.transcript, 'recovered');
  });

  test('deleteMemo removes the row and the audio file', () async {
    await repo().saveMemo(
        bookId: 'b1', chapterIndex: 0, blockId: null, positionMs: 0,
        recordedFile: recorded);
    await repo().deleteMemo('memoX');
    expect(await db.select(db.memos).get(), isEmpty);
    expect(files.memoFile('memoX').existsSync(), isFalse);
  });

  test('watchMemos emits saved memos', () async {
    await repo().saveMemo(
        bookId: 'b1', chapterIndex: 0, blockId: null, positionMs: 0,
        recordedFile: recorded);
    final memos = await repo().watchMemos().first;
    expect(memos.single.id, 'memoX');
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `cd app && flutter test test/features/notes/memo_repository_test.dart 2>&1 | tail -4`
Expected: FAIL — `memo_repository.dart` does not exist.

- [ ] **Step 7: Write `app/lib/features/notes/memo_repository.dart`**

```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/backend/backend_client.dart';
import '../../core/db/database.dart';
import '../../core/storage/file_store.dart';

/// Owns voice memos: capture-to-storage, transcription (graceful offline),
/// listing, retry, delete.
class MemoRepository {
  MemoRepository({
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

  /// Store a recorded clip as a memo pinned to a paragraph, then transcribe.
  /// A transcription failure is non-fatal: the memo + audio are kept and the
  /// status becomes `error` (retryable). Returns the memo id.
  Future<String> saveMemo({
    required String bookId,
    required int chapterIndex,
    required String? blockId,
    required int positionMs,
    required File recordedFile,
  }) async {
    final id = _idGen();
    await _files.ensureMemosDir();
    final dest = _files.memoFile(id);
    await recordedFile.copy(dest.path);
    await _db.into(_db.memos).insert(MemosCompanion.insert(
          id: id,
          bookId: bookId,
          chapterIndex: chapterIndex,
          blockId: Value(blockId),
          positionMs: Value(positionMs),
          audioPath: dest.path,
        ));
    await _transcribe(id, dest);
    return id;
  }

  Future<void> _transcribe(String memoId, File audio) async {
    try {
      final text = await _backend.transcribe(audio);
      await (_db.update(_db.memos)..where((m) => m.id.equals(memoId))).write(
          MemosCompanion(
              transcript: Value(text), transcriptStatus: const Value('done')));
    } catch (_) {
      await (_db.update(_db.memos)..where((m) => m.id.equals(memoId)))
          .write(const MemosCompanion(transcriptStatus: Value('error')));
    }
  }

  Future<void> retryTranscription(String memoId) async {
    final memo = await getMemo(memoId);
    if (memo == null) return;
    await _transcribe(memoId, File(memo.audioPath));
  }

  Stream<List<Memo>> watchMemos() => (_db.select(_db.memos)
        ..orderBy([(m) => OrderingTerm(expression: m.createdAt, mode: OrderingMode.desc)]))
      .watch();

  Stream<List<Memo>> watchMemosForBook(String bookId) => (_db.select(_db.memos)
        ..where((m) => m.bookId.equals(bookId))
        ..orderBy([(m) => OrderingTerm(expression: m.createdAt, mode: OrderingMode.desc)]))
      .watch();

  Future<Memo?> getMemo(String memoId) =>
      (_db.select(_db.memos)..where((m) => m.id.equals(memoId))).getSingleOrNull();

  Future<void> deleteMemo(String memoId) async {
    final memo = await getMemo(memoId);
    if (memo != null) {
      final f = File(memo.audioPath);
      if (await f.exists()) await f.delete();
    }
    await (_db.delete(_db.memos)..where((m) => m.id.equals(memoId))).go();
  }
}
```

- [ ] **Step 8: Add providers to `app/lib/core/providers.dart`**

Add imports (merge):

```dart
import 'audio/recorder_handler.dart';
import 'audio/record_recorder_handler.dart';
import '../features/notes/memo_repository.dart';
```

Append:

```dart
final recorderHandlerProvider = Provider<RecorderHandler>((ref) {
  final handler = RecordRecorderHandler();
  ref.onDispose(handler.dispose);
  return handler;
});

final memoRepositoryProvider = Provider<MemoRepository>(
  (ref) => MemoRepository(
    db: ref.watch(databaseProvider),
    files: ref.watch(fileStoreProvider),
    backend: ref.watch(backendClientProvider),
  ),
);
```

- [ ] **Step 9: Run tests + analyze + full suites**

Run: `cd app && flutter test test/features/notes/memo_repository_test.dart 2>&1 | tail -3`
Expected: PASS (5 tests).
Run: `cd app && flutter analyze 2>&1 | tail -2 && flutter test 2>&1 | tail -3`
Expected: `No issues found!`; all app tests pass.
Run: `cd backend && uv run pytest 2>&1 | tail -1` → 52 passed.

- [ ] **Step 10: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/db/database.dart app/lib/features/notes/memo_repository.dart app/lib/core/providers.dart app/test/core/db/database_test.dart app/test/features/notes/memo_repository_test.dart
git commit -m "feat: Memos table + migration + MemoRepository (Plan 5a Task 4)"
```

---

## Self-Review

**Spec coverage (§2 backend, §3 client data):**
- §2 `/transcribe` + faster-whisper behind `get_transcriber` → Task 1. ✅
- §3 `RecorderHandler` interface + `record` impl + fake → Task 2. ✅
- §3 mic entitlements + Info.plist → Task 2. ✅
- §3 `BackendClient.transcribe` + `FileStore.memoFile` → Task 3. ✅
- §3 `Memos` table (+ migration) → Task 4. ✅
- §3 `MemoRepository` (save/transcribe non-fatal/retry/watch/watchForBook/delete) → Task 4. ✅
- Record button + Notes screen → Plan 5b (out of scope). Noted.

**Placeholder scan:** none — every step has concrete code/commands + expected output.

**Type consistency:** `Transcriber.transcribe(audio_path) -> str` matches the fake and `/transcribe`. `RecorderHandler` (`start`/`stop`/`isRecording`/`dispose`) identical across interface, `RecordRecorderHandler`, and `FakeRecorderHandler`; `RecorderPermissionDenied` shared. `BackendClient.transcribe(File) -> Future<String>` matches Dio impl + fake. `FileStore.memoFile(id)`/`ensureMemosDir` consistent. `Memos` columns (`id`, `bookId`, `chapterIndex`, `blockId`, `positionMs`, `audioPath`, `transcript`, `transcriptStatus`, `createdAt`) match `MemosCompanion.insert` usage and `MemoRepository`. `MemoRepository` method names (`saveMemo`, `retryTranscription`, `watchMemos`, `watchMemosForBook`, `getMemo`, `deleteMemo`) consistent between source and tests; `idGen` injection mirrors `LibraryRepository`. Providers (`recorderHandlerProvider`, `memoRepositoryProvider`) reference existing `databaseProvider`/`fileStoreProvider`/`backendClientProvider`.
