# Plan 3c — Client UI: Library, Book, Player (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Flutter UI on top of the Plan 3b data layer — app bootstrap + routing, a Library screen (add book, list title/author), a Book screen (chapter index with live download badges), and a Player screen (play/pause, seek, speed, resume) — so the app is usable end-to-end against the real backend.

**Architecture:** Riverpod `StreamProvider`s expose the repositories' `watch*` streams to widgets. A `PlayerController` (`ChangeNotifier`) wraps the `AudioHandler` seam: it loads a cached chapter audio file, restores the saved position, exposes position/duration/playing/speed, and persists progress (throttled + on pause/dispose) via `ChapterRepository`. File picking and the audio device are behind injectable providers so every screen and the controller are widget/unit-tested with fakes — no real device or backend in tests. `main()` wires a real on-disk Drift DB + `FileStore` (app documents dir) and `go_router`.

**Tech Stack:** Builds on Plan 3a/3b. Uses flutter_riverpod, go_router, file_picker, just_audio, drift (NativeDatabase file), path_provider. No new packages.

**Prerequisite:** Plan 3b merged to `main` (BackendClient, AudioHandler, repositories, providers, models).

---

## Branch setup (controller does this before Task 1)

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git checkout main && git checkout -b feat/client-ui
```

---

## File Structure

```
app/lib/
  main.dart                              # bootstrap: db + FileStore + ProviderScope + router
  app.dart                               # MaterialApp.router + go_router config
  core/providers.dart                    # + audioHandlerProvider, stream providers, filePickerProvider, playerControllerProvider
  features/library/library_screen.dart   # list books, add-book FAB
  features/book/book_screen.dart         # chapter index + download badges
  features/player/player_controller.dart # ChangeNotifier wrapping AudioHandler
  features/player/player_screen.dart     # transport UI
app/test/support/fake_audio_handler.dart
app/test/features/player/player_controller_test.dart
app/test/features/library/library_screen_test.dart
app/test/features/book/book_screen_test.dart
app/test/features/player/player_screen_test.dart
app/test/app_boot_test.dart
```

---

## Task 1: FakeAudioHandler (test support)

**Files:**
- Create: `app/test/support/fake_audio_handler.dart`

- [ ] **Step 1: Write `app/test/support/fake_audio_handler.dart`**

```dart
import 'dart:async';

import 'package:vimarsha/core/audio/audio_handler.dart';

/// Controllable AudioHandler for tests: you push position/playing events and
/// inspect the calls made to it.
class FakeAudioHandler implements AudioHandler {
  final _position = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();

  Duration _pos = Duration.zero;
  Duration? loadedDuration = const Duration(seconds: 60);

  String? loadedPath;
  bool playCalled = false;
  bool pauseCalled = false;
  double speed = 1.0;
  final List<Duration> seeks = [];
  bool disposed = false;

  /// Test helper: emit a position event (also updates `position`).
  void emitPosition(Duration d) {
    _pos = d;
    _position.add(d);
  }

  /// Test helper: emit a playing-state event.
  void emitPlaying(bool v) => _playing.add(v);

  @override
  Future<Duration?> load(String filePath) async {
    loadedPath = filePath;
    return loadedDuration;
  }

  @override
  Future<void> play() async {
    playCalled = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalled = true;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _pos = position;
  }

  @override
  Future<void> setSpeed(double s) async => speed = s;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Duration get position => _pos;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _position.close();
    await _playing.close();
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd app && flutter analyze test/support/fake_audio_handler.dart 2>&1 | tail -3`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/test/support/fake_audio_handler.dart
git commit -m "test: FakeAudioHandler test double (Plan 3c Task 1)"
```

---

## Task 2: PlayerController

**Files:**
- Create: `app/lib/features/player/player_controller.dart`, `app/test/features/player/player_controller_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/player/player_controller_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/book/chapter_repository.dart';
import 'package:vimarsha/features/player/player_controller.dart';

import '../../support/fake_audio_handler.dart';
import '../../support/fake_backend_client.dart';

void main() {
  late AppDatabase db;
  late FakeAudioHandler audio;
  late ChapterRepository chapters;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('pc');
    chapters = ChapterRepository(
        db: db, files: FileStore(tmp), backend: FakeBackendClient());
    audio = FakeAudioHandler();
    await db.into(db.books).insert(
        BooksCompanion.insert(id: 'b1', title: 'T', epubPath: 'x'));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        bookId: 'b1', chapterIndex: 0, chapterId: 'c1', title: 'Ch',
        positionMs: const Value(4000)));
  });
  tearDown(() async => db.close());

  PlayerController make() => PlayerController(
      audio: audio, chapters: chapters, bookId: 'b1', index: 0);

  test('load restores saved position and reports duration', () async {
    final c = make();
    await c.load('/path/audio.mp3');
    expect(audio.loadedPath, '/path/audio.mp3');
    expect(audio.seeks.last, const Duration(milliseconds: 4000));
    expect(c.duration, const Duration(seconds: 60));
    c.dispose();
  });

  test('play and pause delegate to the handler', () async {
    final c = make();
    await c.load('/a.mp3');
    await c.play();
    expect(audio.playCalled, isTrue);
    expect(c.playing, isTrue);
    await c.pause();
    expect(audio.pauseCalled, isTrue);
    expect(c.playing, isFalse);
    c.dispose();
  });

  test('seek and setSpeed delegate to the handler', () async {
    final c = make();
    await c.load('/a.mp3');
    await c.seek(const Duration(seconds: 10));
    expect(audio.seeks.last, const Duration(seconds: 10));
    await c.setSpeed(1.5);
    expect(audio.speed, 1.5);
    expect(c.speed, 1.5);
    c.dispose();
  });

  test('position events update state and notify listeners', () async {
    final c = make();
    await c.load('/a.mp3');
    var notified = 0;
    c.addListener(() => notified++);
    audio.emitPosition(const Duration(seconds: 7));
    await Future<void>.delayed(Duration.zero);
    expect(c.position, const Duration(seconds: 7));
    expect(notified, greaterThan(0));
    c.dispose();
  });

  test('pause persists current position to the chapter row', () async {
    final c = make();
    await c.load('/a.mp3');
    audio.emitPosition(const Duration(seconds: 12));
    await Future<void>.delayed(Duration.zero);
    await c.pause();
    final row = await (db.select(db.chapters)
          ..where((t) => t.bookId.equals('b1') & t.chapterIndex.equals(0)))
        .getSingle();
    expect(row.positionMs, 12000);
    c.dispose();
  });

  test('position advancing past the save interval persists progress', () async {
    final c = make();
    await c.load('/a.mp3');
    audio.emitPosition(const Duration(seconds: 6)); // >5s since last save (0)
    await Future<void>.delayed(Duration.zero);
    final row = await (db.select(db.chapters)
          ..where((t) => t.bookId.equals('b1') & t.chapterIndex.equals(0)))
        .getSingle();
    expect(row.positionMs, 6000);
    c.dispose();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/player/player_controller_test.dart 2>&1 | tail -5`
Expected: FAIL — `player_controller.dart` does not exist.

- [ ] **Step 3: Write `app/lib/features/player/player_controller.dart`**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/audio/audio_handler.dart';
import '../book/chapter_repository.dart';

/// Drives playback of one cached chapter: loads audio, restores the saved
/// position, mirrors the handler's position/playing into listenable state, and
/// persists reading progress (throttled, and on pause/dispose).
class PlayerController extends ChangeNotifier {
  PlayerController({
    required AudioHandler audio,
    required ChapterRepository chapters,
    required this.bookId,
    required this.index,
  })  : _audio = audio,
        _chapters = chapters;

  final AudioHandler _audio;
  final ChapterRepository _chapters;
  final String bookId;
  final int index;

  static const _saveInterval = Duration(seconds: 5);

  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playing = false;
  double speed = 1.0;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;
  Duration _lastSaved = Duration.zero;

  Future<void> load(String audioPath) async {
    final dur = await _audio.load(audioPath);
    if (dur != null) duration = dur;

    final row = await _chapters.getChapter(bookId, index);
    final resume = Duration(milliseconds: row?.positionMs ?? 0);
    position = resume;
    _lastSaved = resume;
    if (resume > Duration.zero) {
      await _audio.seek(resume);
    }

    _posSub = _audio.positionStream.listen(_onPosition);
    _playSub = _audio.playingStream.listen((p) {
      playing = p;
      notifyListeners();
    });
    notifyListeners();
  }

  void _onPosition(Duration p) {
    position = p;
    if ((p - _lastSaved).abs() >= _saveInterval) {
      _lastSaved = p;
      unawaited(_chapters.saveProgress(bookId, index, p.inMilliseconds));
    }
    notifyListeners();
  }

  Future<void> play() => _audio.play();

  Future<void> pause() async {
    await _audio.pause();
    await _persist();
  }

  Future<void> seek(Duration to) async {
    await _audio.seek(to);
    position = to;
    notifyListeners();
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
    _posSub?.cancel();
    _playSub?.cancel();
    // best-effort final save
    unawaited(_chapters.saveProgress(bookId, index, position.inMilliseconds));
    unawaited(_audio.dispose());
    super.dispose();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/player/player_controller_test.dart 2>&1 | tail -5`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/features/player/player_controller.dart app/test/features/player/player_controller_test.dart
git commit -m "feat: PlayerController (load/resume/transport/progress) (Plan 3c Task 2)"
```

---

## Task 3: Providers for UI (streams, audio handler, file picker, player)

**Files:**
- Modify: `app/lib/core/providers.dart`
- Test: `app/test/core/providers_ui_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/core/providers_ui_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/audio/audio_handler.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/core/storage/file_store.dart';

import '../support/fake_audio_handler.dart';
import '../support/fake_backend_client.dart';

void main() {
  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
      fileStoreProvider.overrideWithValue(
          FileStore(Directory.systemTemp.createTempSync('pui'))),
      backendClientProvider.overrideWithValue(FakeBackendClient()),
      audioHandlerProvider.overrideWithValue(FakeAudioHandler()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('audioHandlerProvider can be overridden', () {
    expect(container().read(audioHandlerProvider), isA<AudioHandler>());
  });

  test('booksStreamProvider yields an empty list initially', () async {
    final c = container();
    final books = await c.read(booksStreamProvider.future);
    expect(books, isEmpty);
  });

  test('filePickerProvider returns a callable', () {
    expect(container().read(filePickerProvider), isA<Function>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/providers_ui_test.dart 2>&1 | tail -5`
Expected: FAIL — `audioHandlerProvider`/`booksStreamProvider`/`filePickerProvider` undefined.

- [ ] **Step 3: Append to `app/lib/core/providers.dart`**

Add these imports at the top (merge with existing):

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'audio/audio_handler.dart';
import 'audio/just_audio_handler.dart';
import 'db/database.dart' show Book, Chapter;
```

Append these providers at the end of the file:

```dart
/// The audio device seam. Overridden with a fake in tests.
final audioHandlerProvider = Provider<AudioHandler>((ref) {
  final handler = JustAudioHandler();
  ref.onDispose(handler.dispose);
  return handler;
});

/// Streams the library (title/author rows) for the library screen.
final booksStreamProvider = StreamProvider<List<Book>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchBooks(),
);

/// Streams a book's chapters (with download status) for the book screen.
final chaptersStreamProvider =
    StreamProvider.family<List<Chapter>, String>(
  (ref, bookId) => ref.watch(chapterRepositoryProvider).watchChapters(bookId),
);

/// Picks an EPUB from disk. Returns the file, or null if cancelled.
/// Overridden in tests so widget tests never hit the platform picker.
typedef EpubPicker = Future<File?> Function();

Future<File?> _pickEpubFromDisk() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['epub'],
  );
  final path = result?.files.single.path;
  return path == null ? null : File(path);
}

final filePickerProvider = Provider<EpubPicker>((ref) => _pickEpubFromDisk);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/core/providers_ui_test.dart 2>&1 | tail -5`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/providers.dart app/test/core/providers_ui_test.dart
git commit -m "feat: UI providers (audio, book/chapter streams, file picker) (Plan 3c Task 3)"
```

---

## Task 4: Library screen

**Files:**
- Create: `app/lib/features/library/library_screen.dart`, `app/test/features/library/library_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/library/library_screen_test.dart
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/library/library_screen.dart';

import '../../support/fake_backend_client.dart';

void main() {
  late AppDatabase db;

  Future<void> pump(WidgetTester tester) async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWithValue(
            FileStore(Directory.systemTemp.createTempSync('ls'))),
        backendClientProvider.overrideWithValue(FakeBackendClient()),
      ],
      child: const MaterialApp(home: LibraryScreen()),
    ));
  }

  testWidgets('shows empty state when no books', (tester) async {
    await pump(tester);
    await tester.pump();
    expect(find.text('No books yet'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('lists books with title and author', (tester) async {
    await pump(tester);
    await db.into(db.books).insert(BooksCompanion.insert(
        id: 'b1', title: 'The Culture Code', author: const Value('Daniel Coyle'),
        epubPath: 'x'));
    await tester.pump(); // let the stream emit
    await tester.pump();
    expect(find.text('The Culture Code'), findsOneWidget);
    expect(find.text('Daniel Coyle'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/library/library_screen_test.dart 2>&1 | tail -5`
Expected: FAIL — `library_screen.dart` does not exist.

- [ ] **Step 3: Write `app/lib/features/library/library_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Future<void> _addBook(BuildContext context, WidgetRef ref) async {
    final pick = ref.read(filePickerProvider);
    final file = await pick();
    if (file == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(libraryRepositoryProvider).addBook(file);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not add book: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addBook(context, ref),
        child: const Icon(Icons.add),
      ),
      body: books.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No books yet'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final b = list[i];
              return ListTile(
                leading: const Icon(Icons.menu_book),
                title: Text(b.title),
                subtitle: b.author.isEmpty ? null : Text(b.author),
                onTap: () => context.go('/book/${b.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/library/library_screen_test.dart 2>&1 | tail -5`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/features/library/library_screen.dart app/test/features/library/library_screen_test.dart
git commit -m "feat: Library screen (list books, add via picker) (Plan 3c Task 4)"
```

---

## Task 5: Book screen (chapter index + download badges)

**Files:**
- Create: `app/lib/features/book/book_screen.dart`, `app/test/features/book/book_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/book/book_screen_test.dart
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/book/book_screen.dart';

import '../../support/fake_backend_client.dart';

void main() {
  late AppDatabase db;

  Future<void> pump(WidgetTester tester) async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.books).insert(BooksCompanion.insert(
        id: 'b1', title: 'Book One', epubPath: 'x'));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        bookId: 'b1', chapterIndex: 0, chapterId: 'c1', title: 'Chapter One'));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        bookId: 'b1', chapterIndex: 1, chapterId: 'c2', title: 'Chapter Two',
        downloadStatus: const Value('ready')));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWithValue(
            FileStore(Directory.systemTemp.createTempSync('bs'))),
        backendClientProvider.overrideWithValue(FakeBackendClient()),
      ],
      child: const MaterialApp(home: BookScreen(bookId: 'b1')),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lists chapters with a download badge for not-downloaded',
      (tester) async {
    await pump(tester);
    expect(find.text('Chapter One'), findsOneWidget);
    expect(find.text('Chapter Two'), findsOneWidget);
    // not-downloaded chapter shows a download affordance
    expect(find.byIcon(Icons.download), findsOneWidget);
    // ready chapter shows the offline/ready badge
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping a not-downloaded chapter triggers download', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.download));
    await tester.pump(); // status -> downloading
    // FakeBackendClient has no bundle set -> download fails -> error status.
    // Either way, the row leaves 'none': a progress or error indicator appears.
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byIcon(Icons.download), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/book/book_screen_test.dart 2>&1 | tail -5`
Expected: FAIL — `book_screen.dart` does not exist.

- [ ] **Step 3: Write `app/lib/features/book/book_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

class BookScreen extends ConsumerWidget {
  const BookScreen({super.key, required this.bookId});

  final String bookId;

  Widget _trailing(BuildContext context, WidgetRef ref, Chapter c) {
    switch (c.downloadStatus) {
      case 'ready':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'downloading':
        return const SizedBox(
          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
      case 'error':
        return IconButton(
          icon: const Icon(Icons.error, color: Colors.red),
          onPressed: () =>
              ref.read(chapterRepositoryProvider).downloadChapter(bookId, c.chapterIndex),
        );
      default:
        return IconButton(
          icon: const Icon(Icons.download),
          onPressed: () =>
              ref.read(chapterRepositoryProvider).downloadChapter(bookId, c.chapterIndex),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(chaptersStreamProvider(bookId));
    return Scaffold(
      appBar: AppBar(title: const Text('Chapters')),
      body: chapters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) {
            final c = list[i];
            final ready = c.downloadStatus == 'ready';
            return ListTile(
              title: Text(c.title),
              trailing: _trailing(context, ref, c),
              enabled: ready,
              onTap: ready
                  ? () => context.go('/player/$bookId/${c.chapterIndex}')
                  : null,
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/book/book_screen_test.dart 2>&1 | tail -5`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/features/book/book_screen.dart app/test/features/book/book_screen_test.dart
git commit -m "feat: Book screen with chapter index + download badges (Plan 3c Task 5)"
```

---

## Task 6: Player screen

**Files:**
- Modify: `app/lib/core/providers.dart` (add `playerControllerProvider`)
- Create: `app/lib/features/player/player_screen.dart`, `app/test/features/player/player_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/player/player_screen_test.dart
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/player/player_screen.dart';

import '../../support/fake_audio_handler.dart';
import '../../support/fake_backend_client.dart';

void main() {
  testWidgets('renders transport and play toggles to pause', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final audio = FakeAudioHandler();
    final dir = Directory.systemTemp.createTempSync('ps');
    await db.into(db.books).insert(
        BooksCompanion.insert(id: 'b1', title: 'T', epubPath: 'x'));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        bookId: 'b1', chapterIndex: 0, chapterId: 'c1', title: 'Ch',
        audioPath: Value('${dir.path}/a.mp3'),
        downloadStatus: const Value('ready')));
    // create the audio file so load() has a path (FakeAudioHandler ignores content)
    File('${dir.path}/a.mp3').writeAsBytesSync([0]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWithValue(FileStore(dir)),
        backendClientProvider.overrideWithValue(FakeBackendClient()),
        audioHandlerProvider.overrideWithValue(audio),
      ],
      child: const MaterialApp(home: PlayerScreen(bookId: 'b1', index: 0)),
    ));
    await tester.pump(); // load()
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(audio.playCalled, isTrue);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    // speed control present
    expect(find.text('1.0×'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/player/player_screen_test.dart 2>&1 | tail -5`
Expected: FAIL — `player_screen.dart` / `playerControllerProvider` undefined.

- [ ] **Step 3: Add `playerControllerProvider` to `app/lib/core/providers.dart`**

Add this import (merge):

```dart
import '../features/player/player_controller.dart';
```

Append:

```dart
/// One PlayerController per (bookId, index). Auto-disposed when the player
/// screen is left, which cancels subscriptions and saves final progress.
final playerControllerProvider = ChangeNotifierProvider.autoDispose
    .family<PlayerController, ({String bookId, int index})>((ref, args) {
  return PlayerController(
    audio: ref.watch(audioHandlerProvider),
    chapters: ref.watch(chapterRepositoryProvider),
    bookId: args.bookId,
    index: args.index,
  );
});
```

- [ ] **Step 4: Write `app/lib/features/player/player_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.bookId, required this.index});

  final String bookId;
  final int index;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _loaded = false;

  ({String bookId, int index}) get _args =>
      (bookId: widget.bookId, index: widget.index);

  @override
  void initState() {
    super.initState();
    // Load after first frame so the provider exists.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(playerControllerProvider(_args));
      final Chapter? row =
          await ref.read(chapterRepositoryProvider).getChapter(widget.bookId, widget.index);
      final path = row?.audioPath;
      if (path != null) await controller.load(path);
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(playerControllerProvider(_args));
    final maxMs = c.duration.inMilliseconds == 0 ? 1 : c.duration.inMilliseconds;
    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Slider(
                    value: c.position.inMilliseconds.clamp(0, maxMs).toDouble(),
                    max: maxMs.toDouble(),
                    onChanged: (v) =>
                        c.seek(Duration(milliseconds: v.round())),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(c.position)),
                      Text(_fmt(c.duration)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 48,
                        icon: Icon(c.playing ? Icons.pause : Icons.play_arrow),
                        onPressed: () => c.playing ? c.pause() : c.play(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<double>(
                    value: c.speed,
                    items: [
                      for (final s in _speeds)
                        DropdownMenuItem(
                          value: s,
                          child: Text('${s.toStringAsFixed(s == s.roundToDouble() ? 1 : 2)}×'),
                        ),
                    ],
                    onChanged: (v) => v == null ? null : c.setSpeed(v),
                  ),
                ],
              ),
            ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/player/player_screen_test.dart 2>&1 | tail -5`
Expected: PASS. (If the speed label assertion is brittle, the controller's default speed is 1.0 → `'1.0×'`.)

- [ ] **Step 6: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/providers.dart app/lib/features/player/player_screen.dart app/test/features/player/player_screen_test.dart
git commit -m "feat: Player screen (transport, seek, speed, resume) (Plan 3c Task 6)"
```

---

## Task 7: App bootstrap + routing

**Files:**
- Create: `app/lib/app.dart`
- Modify: `app/lib/main.dart`
- Test: `app/test/app_boot_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/app_boot_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/app.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/core/storage/file_store.dart';

import 'support/fake_backend_client.dart';

void main() {
  testWidgets('app boots to the Library screen', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWithValue(
            FileStore(Directory.systemTemp.createTempSync('boot'))),
        backendClientProvider.overrideWithValue(FakeBackendClient()),
      ],
      child: const VimarshaApp(),
    ));
    await tester.pump();
    expect(find.text('Library'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/app_boot_test.dart 2>&1 | tail -5`
Expected: FAIL — `VimarshaApp` in `app.dart` does not exist.

- [ ] **Step 3: Write `app/lib/app.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/book/book_screen.dart';
import 'features/library/library_screen.dart';
import 'features/player/player_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const LibraryScreen()),
    GoRoute(
      path: '/book/:id',
      builder: (_, s) => BookScreen(bookId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/player/:bookId/:index',
      builder: (_, s) => PlayerScreen(
        bookId: s.pathParameters['bookId']!,
        index: int.parse(s.pathParameters['index']!),
      ),
    ),
  ],
);

class VimarshaApp extends ConsumerWidget {
  const VimarshaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Vimarsha',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      routerConfig: _router,
    );
  }
}
```

Note: the library screen uses `context.go('/book/:id')`; with go_router these navigate within `_router`.

- [ ] **Step 4: Write `app/lib/main.dart`**

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'core/providers.dart';
import 'core/storage/file_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(docs.path, 'vimarsha', 'vimarsha.sqlite'));
  await dbFile.parent.create(recursive: true);
  final db = AppDatabase(NativeDatabase.createInBackground(dbFile));
  final fileStore = FileStore(Directory(p.join(docs.path, 'vimarsha')));

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      fileStoreProvider.overrideWithValue(fileStore),
    ],
    child: const VimarshaApp(),
  ));
}
```

(Note: `File` and `Directory` come from `dart:io`; add `import 'dart:io';` at the top of `main.dart`.)

- [ ] **Step 5: Run test + full suite + analyze**

Run: `cd app && flutter test 2>&1 | tail -5 && flutter analyze 2>&1 | tail -3`
Expected: all tests pass (Plan 3a 10 + 3b 16 + 3c: player_controller 6, providers_ui 3, library_screen 2, book_screen 2, player_screen 1, app_boot 1 = 41 total), and `No issues found!`.

- [ ] **Step 6: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/app.dart app/lib/main.dart app/test/app_boot_test.dart
git commit -m "feat: app bootstrap + go_router wiring (Plan 3c Task 7)"
```

---

## Task 8: Manual macOS run (manual gate — controller runs this)

This step builds and runs the real app on macOS against the live backend. It is a manual verification, not an automated test.

- [ ] **Step 1: Confirm macOS build compiles**

Run: `cd app && flutter build macos --debug 2>&1 | tail -5`
Expected: build succeeds.

- [ ] **Step 2: Manual smoke (documented; controller performs)**

With the backend running (`cd backend && uv run uvicorn vimarsha.server:app --port 8000`):
`cd app && flutter run -d macos`
Then: tap **+**, pick the Culture Code EPUB → the library shows title + author → open it → chapter list with download badges → download a short chapter → open the player → play/seek/speed work and the position resumes on reopen.

> If a GUI run isn't possible in this environment, `flutter build macos --debug` succeeding is the automated gate; the interactive smoke is documented for the user to run.

- [ ] **Step 3: Commit (if any tweaks were needed)**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git commit -am "chore: macOS run tweaks (Plan 3c Task 8)" || echo "no changes"
```

---

## Self-Review

**Spec coverage (Phase 3 spec §2.1 features, §4 data flow UI, §6 testing):**
- Library screen (list title+author, add via picker) → Task 4. ✅
- Book screen (chapter index + download badges, statuses) → Task 5. ✅
- Player (play/pause, seek, speed, resume) → Tasks 2 + 6. ✅
- App bootstrap (real db + FileStore + router) → Task 7. ✅
- UI providers / fakes / widget tests → Tasks 1, 3, and per-screen tests. ✅
- Figure overlay → Plan 4 (out of scope). Noted.

**Placeholder scan:** none — every step has concrete code/commands + expected output. Task 8 Step 2 is an explicit manual gate with an automated fallback (`flutter build macos`).

**Type consistency:** Providers added (`audioHandlerProvider`, `booksStreamProvider`, `chaptersStreamProvider`, `filePickerProvider`, `playerControllerProvider`) are referenced consistently across screens and tests. `PlayerController` constructor params (`audio`, `chapters`, `bookId`, `index`) match the provider and tests. Drift `Book`/`Chapter` row types and fields (`downloadStatus`, `chapterIndex`, `audioPath`, `positionMs`, `author`, `title`) match Plan 3a's schema and Plan 3b's repositories. `ChapterRepository.getChapter/saveProgress/watchChapters/downloadChapter` signatures match Plan 3b. Routes (`/`, `/book/:id`, `/player/:bookId/:index`) are consistent between `app.dart` and the `context.go` calls in the library/book screens.
