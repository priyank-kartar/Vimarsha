# Plan 5b — Voice Memo UI: Record Button + Notes Screen (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The user-facing voice-memo feature: a hold-to-record button in the player (press = pause + record, release = save + auto-resume; recording freezes the reading view) and a top-level Notes screen to review, play, jump to, retry, and delete memos.

**Architecture:** A `RecordButton` widget (takes the `PlayerController` + book/index, reads `recorderHandlerProvider`/`memoRepositoryProvider`/`fileStoreProvider`) records to a `FileStore` temp path — no `path_provider` — so it's widget-testable. A `NotesScreen` consumes a `memosStreamProvider`; memo playback uses the existing `audioHandlerProvider`; "open at pin" sets the chapter's resume position then navigates to the player. A `/notes` route + a library app-bar button.

**Tech Stack:** Flutter, Riverpod, go_router. Builds on Plan 5a (`MemoRepository`, `RecorderHandler`, `Memos`). No backend changes.

**Prerequisite:** Plan 5a merged.

---

## Branch setup (controller does this before Task 1)

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git checkout main && git checkout -b feat/voice-memo-ui
```

---

## File Structure

```
app/lib/core/storage/file_store.dart          # + newRecordingFile()
app/lib/core/providers.dart                    # + memosStreamProvider
app/lib/features/player/record_button.dart      # NEW
app/lib/features/player/player_screen.dart      # mount RecordButton in chrome
app/lib/features/notes/notes_screen.dart        # NEW
app/lib/features/library/library_screen.dart    # + Notes app-bar action
app/lib/app.dart                                # + /notes route
app/test/core/storage/file_store_test.dart       # + newRecordingFile test
app/test/features/player/record_button_test.dart # NEW
app/test/features/notes/notes_screen_test.dart    # NEW
```

---

## Task 1: `FileStore.newRecordingFile` + `RecordButton`

**Files:** Modify `file_store.dart`, `file_store_test.dart`; Create
`record_button.dart`, `record_button_test.dart`.

- [ ] **Step 1: Add a recording temp path to `app/lib/core/storage/file_store.dart`**

```dart
  Directory _recDir() => Directory(p.join(root.path, 'rec'));
  Future<File> newRecordingFile() async {
    await _recDir().create(recursive: true);
    return File(p.join(_recDir().path, 'rec_${DateTime.now().microsecondsSinceEpoch}.m4a'));
  }
```

Append to `app/test/core/storage/file_store_test.dart` (inside `main`):

```dart
  test('newRecordingFile lives under rec/ and creates the dir', () async {
    final f = await store.newRecordingFile();
    expect(f.path, startsWith('${tmp.path}/rec/'));
    expect(f.path, endsWith('.m4a'));
    expect(Directory('${tmp.path}/rec').existsSync(), isTrue);
  });
```

- [ ] **Step 2: Write the failing widget test**

```dart
// app/test/features/player/record_button_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/book/chapter_repository.dart';
import 'package:vimarsha/features/player/player_controller.dart';
import 'package:vimarsha/features/player/record_button.dart';

import '../../support/fake_audio_handler.dart';
import '../../support/fake_backend_client.dart';
import '../../support/fake_recorder_handler.dart';

void main() {
  testWidgets('hold records (pauses playback), release saves a memo', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tmp = Directory.systemTemp.createTempSync('rb');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final files = FileStore(tmp);
    final audio = FakeAudioHandler();
    final recorder = FakeRecorderHandler();
    final chapters = ChapterRepository(db: db, files: files, backend: FakeBackendClient());
    final controller = PlayerController(
        audio: audio, chapters: chapters, files: files, bookId: 'b1', index: 0);
    addTearDown(controller.dispose);
    await controller.load('/a.mp3');
    await controller.play(); // playing before recording

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWithValue(files),
        backendClientProvider.overrideWithValue(FakeBackendClient()),
        recorderHandlerProvider.overrideWithValue(recorder),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: RecordButton(controller: controller, bookId: 'b1', index: 0),
        ),
      ),
    ));
    await tester.pump();

    // press and hold
    final gesture = await tester.startGesture(tester.getCenter(find.byType(RecordButton)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(recorder.isRecording, isTrue);
    expect(audio.pauseCalled, isTrue); // playback paused while recording

    // release
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(recorder.isRecording, isFalse);

    final memos = await db.select(db.memos).get();
    expect(memos, hasLength(1));
    expect(memos.single.bookId, 'b1');
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/features/player/record_button_test.dart 2>&1 | tail -5`
Expected: FAIL — `record_button.dart` does not exist.

- [ ] **Step 4: Write `app/lib/features/player/record_button.dart`**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/recorder_handler.dart';
import '../../core/providers.dart';
import 'player_controller.dart';

/// Hold-to-record: press to pause playback + start recording, release to stop,
/// save the memo, and auto-resume playback (if it was playing).
class RecordButton extends ConsumerStatefulWidget {
  const RecordButton({
    super.key,
    required this.controller,
    required this.bookId,
    required this.index,
  });

  final PlayerController controller;
  final String bookId;
  final int index;

  @override
  ConsumerState<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends ConsumerState<RecordButton> {
  bool _recording = false;
  bool _wasPlaying = false;
  File? _file;

  Future<void> _start() async {
    if (_recording) return;
    _wasPlaying = widget.controller.playing;
    await widget.controller.pause(); // also freezes the reading view (position stops)
    final file = await ref.read(fileStoreProvider).newRecordingFile();
    try {
      await ref.read(recorderHandlerProvider).start(file.path);
      _file = file;
      setState(() => _recording = true);
    } on RecorderPermissionDenied {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    setState(() => _recording = false);
    final path = await ref.read(recorderHandlerProvider).stop();
    final messenger = mounted ? ScaffoldMessenger.of(context) : null;
    if (path != null) {
      final f = File(path);
      if (await f.exists() && await f.length() > 0) {
        await ref.read(memoRepositoryProvider).saveMemo(
              bookId: widget.bookId,
              chapterIndex: widget.index,
              blockId: widget.controller.currentBlockId,
              positionMs: widget.controller.position.inMilliseconds,
              recordedFile: f,
            );
        messenger?.showSnackBar(
          const SnackBar(content: Text('Memo saved · transcribing…')),
        );
      }
    }
    _file = null;
    if (_wasPlaying) await widget.controller.play();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _stop(),
      onTapCancel: _stop,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _recording ? Colors.red : Colors.red.shade400,
          boxShadow: _recording
              ? [BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 4)]
              : null,
        ),
        child: Icon(_recording ? Icons.stop : Icons.mic, color: Colors.white),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/player/record_button_test.dart test/core/storage/file_store_test.dart 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/storage/file_store.dart app/lib/features/player/record_button.dart app/test/features/player/record_button_test.dart app/test/core/storage/file_store_test.dart
git commit -m "feat: hold-to-record RecordButton + FileStore.newRecordingFile (Plan 5b Task 1)"
```

---

## Task 2: Mount `RecordButton` in the player chrome

**Files:** Modify `app/lib/features/player/player_screen.dart`,
`app/test/features/player/player_screen_test.dart`.

- [ ] **Step 1: Add the assertion to the player screen test**

In `app/test/features/player/player_screen_test.dart`, add after the existing
play-icon assertions (inside the same test):

```dart
    expect(find.byType(RecordButton), findsOneWidget); // hold-to-record present
```

And add the import at the top:

```dart
import 'package:vimarsha/features/player/record_button.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/player/player_screen_test.dart 2>&1 | tail -5`
Expected: FAIL — `RecordButton` not found in the tree.

- [ ] **Step 3: Mount it in `app/lib/features/player/player_screen.dart`**

Add the import:

```dart
import 'record_button.dart';
```

In the `_Transport`'s control `Row` (where the skip/play/speed controls are),
add the record button after the speed chip. Change the `ActionChip(...)` line so
the row ends with:

```dart
            ActionChip(label: Text(_speedLabel(c.speed)), onPressed: onCycleSpeed),
            const SizedBox(width: 16),
            RecordButton(controller: c, bookId: bookId, index: index),
```

`_Transport` needs `bookId`/`index` — add them to its constructor and fields, and
pass them from `PlayerScreen.build` (`bookId: widget.bookId, index: widget.index`).
Concretely, update `_Transport`:

```dart
class _Transport extends StatelessWidget {
  const _Transport({
    required this.c,
    required this.bookId,
    required this.index,
    required this.maxMs,
    required this.dragMs,
    required this.onDrag,
    required this.onDragEnd,
    required this.onCycleSpeed,
  });

  final PlayerController c;
  final String bookId;
  final int index;
  final int maxMs;
  final double? dragMs;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onDragEnd;
  final VoidCallback onCycleSpeed;
```

and where `PlayerScreen` builds `_Transport(...)`, add `bookId: widget.bookId,
index: widget.index,`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/player/player_screen_test.dart 2>&1 | tail -5`
Expected: PASS. (The player_screen test overrides `recorderHandlerProvider`? It
does not need to — `RecordButton` only reads the recorder on press, not at build;
mounting it is inert. No override needed for this test.)

- [ ] **Step 5: Run analyze**

Run: `cd app && flutter analyze 2>&1 | tail -2`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/features/player/player_screen.dart app/test/features/player/player_screen_test.dart
git commit -m "feat: mount RecordButton in the player transport (Plan 5b Task 2)"
```

---

## Task 3: `NotesScreen` + `memosStreamProvider`

**Files:** Modify `app/lib/core/providers.dart`; Create
`app/lib/features/notes/notes_screen.dart`, `app/test/features/notes/notes_screen_test.dart`.

- [ ] **Step 1: Add `memosStreamProvider` to `app/lib/core/providers.dart`**

Add (the `MemoRepository`/`Memo` are already importable via existing imports;
add `import 'db/database.dart' show Book, Chapter, Memo;` if `Memo` isn't yet in
scope — `Book`/`Chapter` already are):

```dart
final memosStreamProvider = StreamProvider<List<Memo>>(
  (ref) => ref.watch(memoRepositoryProvider).watchMemos(),
);
```

- [ ] **Step 2: Write the failing test**

```dart
// app/test/features/notes/notes_screen_test.dart
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/book/chapter_repository.dart';
import 'package:vimarsha/features/notes/notes_screen.dart';

import '../../support/fake_backend_client.dart';

/// Spy chapter repo to verify "open at pin" sets the resume position.
class SpyChapterRepo extends ChapterRepository {
  SpyChapterRepo({required super.db, required super.files, required super.backend});
  int? savedMs;
  @override
  Future<void> saveProgress(String bookId, int index, int positionMs) async {
    savedMs = positionMs;
  }
}

void main() {
  late AppDatabase db;
  late SpyChapterRepo chapters;

  Future<void> pump(WidgetTester tester) async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tmp = Directory.systemTemp.createTempSync('notes');
    final files = FileStore(tmp);
    chapters = SpyChapterRepo(db: db, files: files, backend: FakeBackendClient());
    await db.into(db.books).insert(BooksCompanion.insert(
        id: 'b1', title: 'The Culture Code', epubPath: 'x'));
    await db.into(db.memos).insert(MemosCompanion.insert(
        id: 'm1', bookId: 'b1', chapterIndex: 2, positionMs: const Value(7000),
        audioPath: '/tmp/m1.m4a', transcript: const Value('come back to this'),
        transcriptStatus: const Value('done')));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWithValue(files),
        backendClientProvider.overrideWithValue(FakeBackendClient()),
        chapterRepositoryProvider.overrideWithValue(chapters),
        memosStreamProvider.overrideWith(
          (ref) => ref.watch(memoRepositoryProvider).watchMemos()),
      ],
      child: const MaterialApp(home: NotesScreen()),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lists memos with transcript and book/chapter', (tester) async {
    await pump(tester);
    expect(find.text('come back to this'), findsOneWidget);
    expect(find.textContaining('The Culture Code'), findsOneWidget);
  });

  testWidgets('open-at-pin sets the chapter resume position', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pump();
    expect(chapters.savedMs, 7000);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd app && flutter test test/features/notes/notes_screen_test.dart 2>&1 | tail -5`
Expected: FAIL — `notes_screen.dart` does not exist.

- [ ] **Step 4: Write `app/lib/features/notes/notes_screen.dart`**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  Future<void> _openAtPin(BuildContext context, WidgetRef ref, Memo m) async {
    // Set the chapter's resume point to the memo's position, then open the player.
    await ref.read(chapterRepositoryProvider)
        .saveProgress(m.bookId, m.chapterIndex, m.positionMs);
    if (context.mounted) context.push('/player/${m.bookId}/${m.chapterIndex}');
  }

  Future<void> _play(WidgetRef ref, Memo m) async {
    if (!File(m.audioPath).existsSync()) return;
    final audio = ref.read(audioHandlerProvider);
    await audio.load(m.audioPath);
    await audio.play();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memos = ref.watch(memosStreamProvider);
    final books = ref.watch(booksStreamProvider).valueOrNull ?? const <Book>[];
    final titles = {for (final b in books) b.id: b.title};

    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: memos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No voice notes yet'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final m = list[i];
              final book = titles[m.bookId] ?? 'Book';
              final subtitle = '$book · Chapter ${m.chapterIndex + 1}';
              final title = switch (m.transcriptStatus) {
                'done' => m.transcript ?? '(no transcript)',
                'error' => 'Transcription failed',
                _ => 'Transcribing…',
              };
              return ListTile(
                title: Text(title),
                subtitle: Text(subtitle),
                leading: IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Play memo',
                  onPressed: () => _play(ref, m),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (m.transcriptStatus == 'error')
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Retry transcription',
                      onPressed: () =>
                          ref.read(memoRepositoryProvider).retryTranscription(m.id),
                    ),
                  IconButton(
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Open at this spot',
                    onPressed: () => _openAtPin(context, ref, m),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () =>
                        ref.read(memoRepositoryProvider).deleteMemo(m.id),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/features/notes/notes_screen_test.dart 2>&1 | tail -5`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/core/providers.dart app/lib/features/notes/notes_screen.dart app/test/features/notes/notes_screen_test.dart
git commit -m "feat: Notes screen (list, play, open-at-pin, retry, delete) (Plan 5b Task 3)"
```

---

## Task 4: `/notes` route + library entry point

**Files:** Modify `app/lib/app.dart`, `app/lib/features/library/library_screen.dart`,
`app/test/app_boot_test.dart`.

- [ ] **Step 1: Add the route to `app/lib/app.dart`**

Add the import:

```dart
import 'features/notes/notes_screen.dart';
```

Add a route inside `_buildRouter`'s `routes`:

```dart
        GoRoute(path: '/notes', builder: (_, __) => const NotesScreen()),
```

- [ ] **Step 2: Add a Notes action to the library app bar**

In `app/lib/features/library/library_screen.dart`, change the `AppBar` to include
an actions button:

```dart
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sticky_note_2_outlined),
            tooltip: 'Notes',
            onPressed: () => context.push('/notes'),
          ),
        ],
      ),
```

- [ ] **Step 3: Extend `app/test/app_boot_test.dart` to cover the Notes button**

Add this test (the existing boot test stays):

```dart
  testWidgets('library has a Notes button', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        booksStreamProvider.overrideWith((ref) => Stream.value(<Book>[])),
      ],
      child: const VimarshaApp(),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
  });
```

(Add `import 'package:vimarsha/core/db/database.dart';` to the test if `Book`
isn't already imported.)

- [ ] **Step 4: Run test to verify it fails then passes**

Run: `cd app && flutter test test/app_boot_test.dart 2>&1 | tail -5`
Expected: first FAIL (no notes icon), then PASS after Steps 1–2.

- [ ] **Step 5: Full app suite + analyze + backend**

Run: `cd app && flutter analyze 2>&1 | tail -2 && flutter test 2>&1 | tail -3`
Expected: `No issues found!`; all app tests pass.
Run: `cd backend && uv run pytest 2>&1 | tail -1` → 51 passed (unchanged).

- [ ] **Step 6: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/app.dart app/lib/features/library/library_screen.dart app/test/app_boot_test.dart
git commit -m "feat: /notes route + library Notes button (Plan 5b Task 4)"
```

---

## Task 5: Manual macOS verification (manual gate — controller runs)

- [ ] **Step 1: Build check**

Run: `cd app && flutter build macos --debug 2>&1 | tail -3`
Expected: build succeeds.

- [ ] **Step 2: Manual smoke (documented; controller performs with the real backend)**

With the backend running, open a downloaded chapter, **press and hold** the red
record button → grant mic permission on first use → speak → release. Confirm:
playback paused while holding and resumed on release; a "saved · transcribing…"
toast; then open **Notes** (library app bar) → the memo appears with its
transcript, **play** replays it, **open-at-pin** returns to the right spot, and
**delete** removes it.

> If a GUI/mic run isn't possible here, `flutter build macos --debug` succeeding
> is the automated gate; the interactive smoke is documented for the user.

- [ ] **Step 3: Commit any tweaks**

```bash
git commit -am "chore: Plan 5b macOS tweaks" || echo "no changes"
```

---

## Self-Review

**Spec coverage (§4 UI):**
- Hold-to-record button: press→pause+record, release→save+auto-resume(if was playing); recording freezes the reading view (playback paused → position frozen) → Tasks 1–2. ✅
- Notes screen: list all memos, play, open-at-pin, retry (error only), delete → Task 3. ✅
- Top-level entry point (library Notes button) + `/notes` route → Task 4. ✅
- Manual macOS gate → Task 5. ✅

**Placeholder scan:** none — every step has concrete code/commands + expected output.

**Type consistency:** `RecordButton(controller, bookId, index)` matches its test and the player mount. It reads `recorderHandlerProvider`/`memoRepositoryProvider`/`fileStoreProvider` (all from Plan 5a). `FileStore.newRecordingFile()` matches its test + `RecordButton`. `memosStreamProvider` (List<Memo>) matches `NotesScreen`. `MemoRepository.saveMemo/retryTranscription/deleteMemo` and `ChapterRepository.saveProgress` signatures match Plan 5a. `RecorderHandler.start/stop/isRecording` + `RecorderPermissionDenied` from Plan 5a. `Memo` fields (`bookId`, `chapterIndex`, `positionMs`, `transcript`, `transcriptStatus`, `audioPath`, `id`) match the Plan 5a table. `_Transport` gains `bookId`/`index` consistently between its constructor and the `PlayerScreen` call site.
