# Plan 4b — Reading View, Figure Overlay & Player Polish (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the player into a reading + listening screen — chapter text with the narrated paragraph highlighted and auto-scrolled, tap-a-paragraph-to-seek, a synced floating figure card (stacked, tap-to-switch, full-screen), a deterministic Figures gallery, and refined player chrome (title header, skip ±15s, compact speed).

**Architecture:** New widgets (`ReadingView`, `FigureOverlay`, `FiguresGallery`) each take a `PlayerController` (a `ChangeNotifier`) directly and rebuild via `ListenableBuilder` — so they're unit-tested by constructing a real controller with a fixture bundle + fake audio, no provider scope needed. `PlayerScreen` composes them and reads the controller from `playerControllerProvider`. The controller already exposes `currentBlockId`, `currentFigures`, `imagePathFor`, `seekToBlock` (Plan 4a); this plan adds a small `skip(delta)`.

**Tech Stack:** Flutter, Riverpod, `scrollable_positioned_list` (new dep) for "scroll to paragraph N". No backend changes.

**Prerequisite:** Plan 4a merged (figure images + `PlayerController` sync logic).

---

## Branch setup (controller does this before Task 1)

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git checkout main && git checkout -b feat/reading-ui
```

---

## File Structure

```
app/
  pubspec.yaml                                  # + scrollable_positioned_list
  lib/features/library/library_repository.dart  # + getBook
  lib/features/player/player_controller.dart     # + skip(delta)
  lib/features/player/reading_view.dart          # NEW
  lib/features/player/figure_overlay.dart        # NEW
  lib/features/player/figures_gallery.dart       # NEW
  lib/features/player/player_screen.dart         # composes the above + chrome
  test/features/library/library_repository_test.dart   # + getBook test
  test/features/player/reading_view_test.dart    # NEW
  test/features/player/figure_overlay_test.dart  # NEW
  test/features/player/figures_gallery_test.dart # NEW
  test/features/player/player_screen_test.dart   # updated for new layout
```

Throughout these tests, a shared helper builds a real `PlayerController` with a
fixture bundle written to a temp `FileStore`. Define it inline per test file (it
is small) — see Task 2 Step 1 for the canonical version; later test files repeat it.

---

## Task 1: Dependency + `LibraryRepository.getBook` + `PlayerController.skip`

**Files:** `app/pubspec.yaml`, `library_repository.dart`,
`library_repository_test.dart`, `player_controller.dart`,
`player_controller_test.dart`

- [ ] **Step 1: Add the dependency**

```bash
cd app && flutter pub add scrollable_positioned_list
```

- [ ] **Step 2: Write failing tests**

Append to `app/test/features/library/library_repository_test.dart` (inside `main`):

```dart
  test('getBook returns the stored book or null', () async {
    expect(await repo().getBook('missing'), isNull);
    await repo().addBook(pickedEpub); // inserts book 'bookX'
    final book = await repo().getBook('bookX');
    expect(book, isNotNull);
    expect(book!.title, 'Test Book');
  });
```

Append to `app/test/features/player/player_controller_test.dart` (inside `main`,
reusing the `make()` helper that builds a controller with a temp `FileStore`):

```dart
  test('skip clamps within [0, duration]', () async {
    final c = make();
    await c.load('/a.mp3'); // FakeAudioHandler duration = 60s
    await c.seek(const Duration(seconds: 10));
    await c.skip(const Duration(seconds: -15));
    expect(audio.seeks.last, Duration.zero); // clamped at 0
    await c.seek(const Duration(seconds: 55));
    await c.skip(const Duration(seconds: 15));
    expect(audio.seeks.last, const Duration(seconds: 60)); // clamped at duration
    c.dispose();
  });
```

(If the existing `make()` doesn't pass `files`, it was updated in Plan 4a to do
so; keep it.)

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd app && flutter test test/features/library/library_repository_test.dart test/features/player/player_controller_test.dart 2>&1 | tail -5`
Expected: FAIL — `getBook`/`skip` undefined.

- [ ] **Step 4: Add `getBook` to `app/lib/features/library/library_repository.dart`**

Add this method (after `watchBooks`):

```dart
  Future<Book?> getBook(String bookId) =>
      (_db.select(_db.books)..where((b) => b.id.equals(bookId)))
          .getSingleOrNull();
```

- [ ] **Step 5: Add `skip` to `app/lib/features/player/player_controller.dart`**

Add this method (after `seek`):

```dart
  /// Seek forward/back by [delta], clamped to [0, duration].
  Future<void> skip(Duration delta) async {
    final target = position + delta;
    final maxd = duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > maxd ? maxd : target);
    await seek(clamped);
  }
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd app && flutter test test/features/library/library_repository_test.dart test/features/player/player_controller_test.dart 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/pubspec.yaml app/pubspec.lock app/lib/features/library/library_repository.dart app/test/features/library/library_repository_test.dart app/lib/features/player/player_controller.dart app/test/features/player/player_controller_test.dart
git commit -m "feat: getBook + PlayerController.skip + scrollable_positioned_list dep (Plan 4b Task 1)"
```

---

## Task 2: `ReadingView` widget

**Files:** Create `app/lib/features/player/reading_view.dart`,
`app/test/features/player/reading_view_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/player/reading_view_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/models/block.dart';
import 'package:vimarsha/core/models/chapter_bundle.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/book/chapter_repository.dart';
import 'package:vimarsha/features/player/player_controller.dart';
import 'package:vimarsha/features/player/reading_view.dart';

import '../../support/fake_audio_handler.dart';
import '../../support/fake_backend_client.dart';

ChapterBundle testBundle() => const ChapterBundle(
      chapterId: 'c1', title: 'The Engine',
      blocks: [
        Block(id: 'h0', index: 0, kind: 'heading', level: 1, text: 'The Engine'),
        Block(id: 'p0', index: 1, kind: 'paragraph', text: 'First paragraph.'),
        Block(id: 'p1', index: 2, kind: 'paragraph', text: 'Second paragraph.'),
        Block(id: 'q0', index: 3, kind: 'pullquote', text: 'A pithy quote.'),
      ],
      figureMap: [],
      paraTimings: {'h0': [0, 1000], 'p0': [1000, 3000], 'p1': [3000, 6000], 'q0': [6000, 8000]},
    );

Future<PlayerController> makeController(WidgetTester tester) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final tmp = Directory.systemTemp.createTempSync('rv');
  addTearDown(() => tmp.deleteSync(recursive: true));
  final files = FileStore(tmp);
  await files.ensureChapterDir('b1', 0);
  await files.bundleFile('b1', 0).writeAsString(jsonEncode(testBundle().toJson()));
  final chapters = ChapterRepository(db: db, files: files, backend: FakeBackendClient());
  final audio = FakeAudioHandler();
  final c = PlayerController(
      audio: audio, chapters: chapters, files: files, bookId: 'b1', index: 0);
  await c.load('/a.mp3');
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('renders block text and highlights the current paragraph',
      (tester) async {
    final c = await makeController(tester);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReadingView(controller: c))));
    await tester.pump();

    expect(find.text('First paragraph.'), findsOneWidget);
    expect(find.text('A pithy quote.'), findsOneWidget);

    // drive position into p1's range -> it becomes the active (highlighted) block
    await c.seek(const Duration(milliseconds: 4000));
    await tester.pump();
    expect(c.currentBlockId, 'p1');
    expect(find.byKey(const ValueKey('reading-active')), findsOneWidget);
  });

  testWidgets('tapping a paragraph seeks to it', (tester) async {
    final c = await makeController(tester);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReadingView(controller: c))));
    await tester.pump();
    await tester.tap(find.text('Second paragraph.'));
    await tester.pump();
    // p1 starts at 3000ms
    expect(c.position, const Duration(milliseconds: 3000));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/player/reading_view_test.dart 2>&1 | tail -5`
Expected: FAIL — `reading_view.dart` does not exist.

- [ ] **Step 3: Write `app/lib/features/player/reading_view.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/models/block.dart';
import 'player_controller.dart';

/// Renders the chapter text, highlights + auto-scrolls the narrated paragraph,
/// and seeks when a paragraph is tapped. Driven by [PlayerController].
class ReadingView extends StatefulWidget {
  const ReadingView({super.key, required this.controller});

  final PlayerController controller;

  @override
  State<ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends State<ReadingView> {
  final _itemScroll = ItemScrollController();
  String? _lastScrolledTo;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final id = widget.controller.currentBlockId;
    if (id == null || id == _lastScrolledTo) return;
    final blocks = widget.controller.bundle?.blocks ?? const [];
    final idx = blocks.indexWhere((b) => b.id == id);
    if (idx >= 0 && _itemScroll.isAttached) {
      _lastScrolledTo = id;
      _itemScroll.scrollTo(
        index: idx,
        duration: const Duration(milliseconds: 350),
        alignment: 0.3,
      );
    }
  }

  TextStyle? _styleFor(Block b, BuildContext context) {
    final t = Theme.of(context).textTheme;
    switch (b.kind) {
      case 'heading':
        return (b.level ?? 1) <= 1 ? t.headlineSmall : t.titleLarge;
      case 'blockquote':
      case 'pullquote':
        return t.titleMedium?.copyWith(fontStyle: FontStyle.italic);
      default:
        return t.bodyLarge?.copyWith(height: 1.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final blocks = widget.controller.bundle?.blocks ?? const <Block>[];
        final activeId = widget.controller.currentBlockId;
        return ScrollablePositionedList.builder(
          itemScrollController: _itemScroll,
          itemCount: blocks.length,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 160),
          itemBuilder: (context, i) {
            final b = blocks[i];
            final text = b.text ?? b.caption ?? '';
            if (text.isEmpty) return const SizedBox.shrink();
            final active = b.id == activeId;
            final isQuote = b.kind == 'blockquote' || b.kind == 'pullquote';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: GestureDetector(
                onTap: () => widget.controller.seekToBlock(b.id),
                child: Container(
                  key: active ? const ValueKey('reading-active') : null,
                  decoration: BoxDecoration(
                    color: active
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                        : null,
                    border: isQuote
                        ? Border(
                            left: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3))
                        : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: EdgeInsets.fromLTRB(isQuote ? 12 : 6, 6, 6, 6),
                  child: Text(text, style: _styleFor(b, context)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/player/reading_view_test.dart 2>&1 | tail -5`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/features/player/reading_view.dart app/test/features/player/reading_view_test.dart
git commit -m "feat: ReadingView (typography, highlight, auto-scroll, tap-to-seek) (Plan 4b Task 2)"
```

---

## Task 3: `FigureOverlay` widget (stacked, tap-to-switch, full-screen)

**Files:** Create `app/lib/features/player/figure_overlay.dart`,
`app/test/features/player/figure_overlay_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/player/figure_overlay_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/models/chapter_bundle.dart';
import 'package:vimarsha/core/models/figure.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/book/chapter_repository.dart';
import 'package:vimarsha/features/player/player_controller.dart';
import 'package:vimarsha/features/player/figure_overlay.dart';

import '../../support/fake_audio_handler.dart';
import '../../support/fake_backend_client.dart';

ChapterBundle bundleWithFigures() => const ChapterBundle(
      chapterId: 'c1', title: 'Ch',
      blocks: [],
      figureMap: [
        Figure(figureId: 'f1', kind: 'pullquote', caption: 'Quote one',
            startPara: 'p0', endPara: 'p0', startMs: 1000, endMs: 5000),
        Figure(figureId: 'f2', kind: 'pullquote', caption: 'Quote two',
            startPara: 'p0', endPara: 'p0', startMs: 4000, endMs: 8000),
      ],
      paraTimings: {'p0': [0, 9000]},
    );

Future<PlayerController> makeController() async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final tmp = Directory.systemTemp.createTempSync('fo');
  addTearDown(() => tmp.deleteSync(recursive: true));
  final files = FileStore(tmp);
  await files.ensureChapterDir('b1', 0);
  await files.bundleFile('b1', 0).writeAsString(jsonEncode(bundleWithFigures().toJson()));
  final c = PlayerController(
      audio: FakeAudioHandler(), chapters: ChapterRepository(db: db, files: files, backend: FakeBackendClient()),
      files: files, bookId: 'b1', index: 0);
  await c.load('/a.mp3');
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('hidden when no figure active, shown when one is', (tester) async {
    final c = await makeController();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FigureOverlay(controller: c))));
    await tester.pump();
    expect(find.text('Quote one'), findsNothing);

    await c.seek(const Duration(milliseconds: 2000)); // only f1 active
    await tester.pump();
    expect(find.text('Quote one'), findsOneWidget);
  });

  testWidgets('stacked figures show a counter and tap switches', (tester) async {
    final c = await makeController();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FigureOverlay(controller: c))));
    await c.seek(const Duration(milliseconds: 4500)); // f1 and f2 both active
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Quote one'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('figure-next')));
    await tester.pump();
    expect(find.text('Quote two'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/player/figure_overlay_test.dart 2>&1 | tail -5`
Expected: FAIL — `figure_overlay.dart` does not exist.

- [ ] **Step 3: Write `app/lib/features/player/figure_overlay.dart`**

```dart
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/models/figure.dart';
import 'player_controller.dart';

/// Floating card over the reading text showing the figure(s) active at the
/// current playback position. Overlapping figures stack; tap chevrons to switch.
class FigureOverlay extends StatefulWidget {
  const FigureOverlay({super.key, required this.controller});

  final PlayerController controller;

  @override
  State<FigureOverlay> createState() => _FigureOverlayState();
}

class _FigureOverlayState extends State<FigureOverlay> {
  int _selected = 0;
  String _lastKey = '';

  void _reconcile(List<Figure> figs) {
    final key = figs.map((f) => f.figureId).join(',');
    if (key != _lastKey) {
      _lastKey = key;
      _selected = 0;
    } else if (_selected >= figs.length) {
      _selected = 0;
    }
  }

  void _openFull(BuildContext context, Figure f, String? imagePath) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (imagePath != null && File(imagePath).existsSync())
              Flexible(child: InteractiveViewer(child: Image.file(File(imagePath))))
            else if (f.caption != null)
              Text(f.caption!, style: Theme.of(context).textTheme.titleMedium),
            if (f.label != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(f.label!, style: Theme.of(context).textTheme.labelLarge),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final figs = widget.controller.currentFigures;
        if (figs.isEmpty) return const SizedBox.shrink();
        _reconcile(figs);
        final f = figs[_selected];
        final imagePath = widget.controller.imagePathFor(f);
        final hasImage = imagePath != null && File(imagePath).existsSync();

        return Align(
          alignment: Alignment.bottomCenter,
          child: Card(
            margin: const EdgeInsets.all(12),
            elevation: 6,
            child: InkWell(
              onTap: () => _openFull(context, f, imagePath),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (hasImage)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: Image.file(File(imagePath), fit: BoxFit.contain),
                    )
                  else if (f.caption != null)
                    Text(f.caption!,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontStyle: FontStyle.italic)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(
                      child: Text(
                        f.label ?? (hasImage ? (f.caption ?? '') : ''),
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (figs.length > 1) Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        key: const ValueKey('figure-prev'),
                        icon: const Icon(Icons.chevron_left), iconSize: 20,
                        onPressed: () => setState(() =>
                            _selected = (_selected - 1) % figs.length < 0
                                ? figs.length - 1 : (_selected - 1) % figs.length),
                      ),
                      Text('${_selected + 1} / ${figs.length}'),
                      IconButton(
                        key: const ValueKey('figure-next'),
                        icon: const Icon(Icons.chevron_right), iconSize: 20,
                        onPressed: () =>
                            setState(() => _selected = (_selected + 1) % figs.length),
                      ),
                    ]),
                  ]),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/player/figure_overlay_test.dart 2>&1 | tail -5`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/features/player/figure_overlay.dart app/test/features/player/figure_overlay_test.dart
git commit -m "feat: FigureOverlay floating card (stacked, tap-to-switch, full-screen) (Plan 4b Task 3)"
```

---

## Task 4: `FiguresGallery` (browse-all backbone)

**Files:** Create `app/lib/features/player/figures_gallery.dart`,
`app/test/features/player/figures_gallery_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/features/player/figures_gallery_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/models/chapter_bundle.dart';
import 'package:vimarsha/core/models/figure.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/book/chapter_repository.dart';
import 'package:vimarsha/features/player/player_controller.dart';
import 'package:vimarsha/features/player/figures_gallery.dart';

import '../../support/fake_audio_handler.dart';
import '../../support/fake_backend_client.dart';

ChapterBundle galleryBundle() => const ChapterBundle(
      chapterId: 'c1', title: 'Ch', blocks: [],
      figureMap: [
        Figure(figureId: 'f1', kind: 'pullquote', caption: 'Alpha quote',
            startPara: 'p0', endPara: 'p0', startMs: 1000, endMs: 2000),
        Figure(figureId: 'f2', kind: 'figure', caption: 'Beta diagram',
            label: 'Figure 2', startPara: 'p1', endPara: 'p1',
            startMs: 5000, endMs: 6000),
      ],
      paraTimings: {'p0': [0, 3000], 'p1': [3000, 9000]},
    );

Future<PlayerController> makeController() async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final tmp = Directory.systemTemp.createTempSync('fg');
  addTearDown(() => tmp.deleteSync(recursive: true));
  final files = FileStore(tmp);
  await files.ensureChapterDir('b1', 0);
  await files.bundleFile('b1', 0).writeAsString(jsonEncode(galleryBundle().toJson()));
  final c = PlayerController(
      audio: FakeAudioHandler(), chapters: ChapterRepository(db: db, files: files, backend: FakeBackendClient()),
      files: files, bookId: 'b1', index: 0);
  await c.load('/a.mp3');
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('lists all figures and "go to" seeks (works while paused)',
      (tester) async {
    final c = await makeController();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FiguresGallery(controller: c))));
    await tester.pump();

    expect(find.text('Alpha quote'), findsOneWidget);
    expect(find.text('Beta diagram'), findsOneWidget);
    expect(find.text('Figure 2'), findsOneWidget);

    // "go to in audio" on the second figure (starts at its startPara p1 = 3000ms)
    await tester.tap(find.byKey(const ValueKey('goto-f2')));
    await tester.pump();
    expect(c.position, const Duration(milliseconds: 3000));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/player/figures_gallery_test.dart 2>&1 | tail -5`
Expected: FAIL — `figures_gallery.dart` does not exist.

- [ ] **Step 3: Write `app/lib/features/player/figures_gallery.dart`**

```dart
import 'dart:io';

import 'package:flutter/material.dart';

import 'player_controller.dart';

/// Lists every figure in the chapter (independent of playback timing) — the
/// reliable way to reach any figure. Each row can jump playback to where the
/// figure is discussed.
class FiguresGallery extends StatelessWidget {
  const FiguresGallery({super.key, required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final figs = controller.bundle?.figureMap ?? const [];
    if (figs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No figures in this chapter'),
        ),
      );
    }
    return ListView.builder(
      itemCount: figs.length,
      itemBuilder: (context, i) {
        final f = figs[i];
        final imagePath = controller.imagePathFor(f);
        final hasImage = imagePath != null && File(imagePath).existsSync();
        return ListTile(
          leading: hasImage
              ? SizedBox(
                  width: 48, height: 48,
                  child: Image.file(File(imagePath), fit: BoxFit.cover))
              : const Icon(Icons.format_quote),
          title: Text(f.label ?? f.caption ?? f.kind),
          subtitle: f.label != null && f.caption != null ? Text(f.caption!) : null,
          trailing: IconButton(
            key: ValueKey('goto-${f.figureId}'),
            icon: const Icon(Icons.my_location),
            tooltip: 'Go to in audio',
            onPressed: () => controller.seekToBlock(f.startPara),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/player/figures_gallery_test.dart 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/features/player/figures_gallery.dart app/test/features/player/figures_gallery_test.dart
git commit -m "feat: FiguresGallery — list all chapter figures + go-to (Plan 4b Task 4)"
```

---

## Task 5: Compose into `PlayerScreen` + chrome refinements

**Files:** Modify `app/lib/features/player/player_screen.dart`,
`app/test/features/player/player_screen_test.dart`

- [ ] **Step 1: Update the widget test**

Replace `app/test/features/player/player_screen_test.dart` with:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/models/block.dart';
import 'package:vimarsha/core/models/chapter_bundle.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/player/player_screen.dart';

import '../../support/fake_audio_handler.dart';
import '../../support/fake_backend_client.dart';

ChapterBundle bundle() => const ChapterBundle(
      chapterId: 'c1', title: 'The Engine',
      blocks: [Block(id: 'p0', index: 0, kind: 'paragraph', text: 'Hello there.')],
      figureMap: [], paraTimings: {'p0': [0, 5000]});

void main() {
  testWidgets('renders title header, transport, and reading text', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final audio = FakeAudioHandler();
    final dir = Directory.systemTemp.createTempSync('ps');
    final files = FileStore(dir);
    await files.ensureChapterDir('b1', 0);
    await files.bundleFile('b1', 0).writeAsString(jsonEncode(bundle().toJson()));
    await db.into(db.books).insert(BooksCompanion.insert(
        id: 'b1', title: 'Test Book', author: const Value('Ada'), epubPath: 'x'));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        bookId: 'b1', chapterIndex: 0, chapterId: 'c1', title: 'The Engine',
        audioPath: Value('${dir.path}/a.mp3'), downloadStatus: const Value('ready')));
    File('${dir.path}/a.mp3').writeAsBytesSync([0]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWithValue(files),
        backendClientProvider.overrideWithValue(FakeBackendClient()),
        audioHandlerProvider.overrideWithValue(audio),
      ],
      child: const MaterialApp(home: PlayerScreen(bookId: 'b1', index: 0)),
    ));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump();

    expect(find.text('Test Book'), findsOneWidget);   // book title
    expect(find.text('The Engine'), findsWidgets);     // chapter title (header + maybe text)
    expect(find.text('Hello there.'), findsOneWidget); // reading text rendered
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.replay_10), findsOneWidget); // skip back
    expect(find.byIcon(Icons.forward_10), findsOneWidget); // skip fwd
    expect(find.byIcon(Icons.collections_bookmark), findsOneWidget); // figures button

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(audio.playCalled, isTrue);
    expect(find.text('1.0×'), findsOneWidget); // compact speed chip
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/player/player_screen_test.dart 2>&1 | tail -5`
Expected: FAIL — new layout (title header / skip icons / figures button) not present yet.

- [ ] **Step 3: Rewrite `app/lib/features/player/player_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import 'figure_overlay.dart';
import 'figures_gallery.dart';
import 'player_controller.dart';
import 'reading_view.dart';

const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
}

String _speedLabel(double s) =>
    '${s.toStringAsFixed(s == s.roundToDouble() ? 1 : 2)}×';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.bookId, required this.index});

  final String bookId;
  final int index;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _loaded = false;
  String? _error;
  String _bookTitle = '';
  double? _dragMs;

  ({String bookId, int index}) get _args =>
      (bookId: widget.bookId, index: widget.index);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      String? error;
      var bookTitle = '';
      try {
        final controller = ref.read(playerControllerProvider(_args));
        final book = await ref.read(libraryRepositoryProvider).getBook(widget.bookId);
        bookTitle = book?.title ?? '';
        final Chapter? row = await ref
            .read(chapterRepositoryProvider)
            .getChapter(widget.bookId, widget.index);
        final path = row?.audioPath;
        if (path == null) {
          error = 'This chapter has no audio. Try downloading it again.';
        } else {
          await controller.load(path);
        }
      } catch (e) {
        error = "Couldn't play this chapter: $e";
      }
      if (mounted) {
        setState(() {
          _loaded = true;
          _error = error;
          _bookTitle = bookTitle;
        });
      }
    });
  }

  void _cycleSpeed(PlayerController c) {
    final i = _speeds.indexOf(c.speed);
    c.setSpeed(_speeds[(i + 1) % _speeds.length]);
  }

  void _openFigures(PlayerController c) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => FiguresGallery(controller: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(playerControllerProvider(_args));
    final chapterTitle = c.bundle?.title ?? '';
    final figureCount = c.bundle?.figureMap.length ?? 0;
    final maxMs = c.duration.inMilliseconds == 0 ? 1 : c.duration.inMilliseconds;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chapterTitle.isEmpty ? 'Now Playing' : chapterTitle,
                style: const TextStyle(fontSize: 16)),
            if (_bookTitle.isNotEmpty)
              Text(_bookTitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          if (figureCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge(
                label: Text('$figureCount'),
                child: IconButton(
                  icon: const Icon(Icons.collections_bookmark),
                  tooltip: 'Figures',
                  onPressed: () => _openFigures(c),
                ),
              ),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : Stack(
              children: [
                Positioned.fill(child: ReadingView(controller: c)),
                Positioned(
                  left: 0, right: 0, bottom: 88,
                  child: FigureOverlay(controller: c),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _Transport(
                    c: c,
                    maxMs: maxMs,
                    dragMs: _dragMs,
                    onDrag: (v) => setState(() => _dragMs = v),
                    onDragEnd: (v) {
                      c.seek(Duration(milliseconds: v.round()));
                      setState(() => _dragMs = null);
                    },
                    onCycleSpeed: () => _cycleSpeed(c),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({
    required this.c,
    required this.maxMs,
    required this.dragMs,
    required this.onDrag,
    required this.onDragEnd,
    required this.onCycleSpeed,
  });

  final PlayerController c;
  final int maxMs;
  final double? dragMs;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onDragEnd;
  final VoidCallback onCycleSpeed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Slider(
            value: (dragMs ?? c.position.inMilliseconds.toDouble())
                .clamp(0, maxMs.toDouble()),
            max: maxMs.toDouble(),
            onChanged: onDrag,
            onChangeEnd: onDragEnd,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_fmt(c.position)),
              Text(_fmt(c.duration)),
            ]),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              icon: const Icon(Icons.replay_10), iconSize: 32,
              onPressed: () => c.skip(const Duration(seconds: -15)),
            ),
            const SizedBox(width: 8),
            IconButton(
              iconSize: 48,
              icon: Icon(c.playing ? Icons.pause : Icons.play_arrow),
              onPressed: () => c.playing ? c.pause() : c.play(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.forward_10), iconSize: 32,
              onPressed: () => c.skip(const Duration(seconds: 15)),
            ),
            const SizedBox(width: 16),
            ActionChip(label: Text(_speedLabel(c.speed)), onPressed: onCycleSpeed),
          ]),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/player/player_screen_test.dart 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 5: Full app suite + analyze**

Run: `cd app && flutter analyze 2>&1 | tail -2 && flutter test 2>&1 | tail -3`
Expected: `No issues found!`; all pass (existing + reading_view 2 + figure_overlay 2 + figures_gallery 1 + library getBook 1 + controller skip 1 + updated player_screen).

- [ ] **Step 6: Commit**

```bash
cd /Users/sachmeet/Documents/Kartar3/Vimarsha
git add app/lib/features/player/player_screen.dart app/test/features/player/player_screen_test.dart
git commit -m "feat: PlayerScreen reading layout + chrome (title, skip ±15, speed chip, figures) (Plan 4b Task 5)"
```

---

## Task 6: Manual macOS verification (manual gate — controller runs)

- [ ] **Step 1: Build check**

Run: `cd app && flutter build macos --debug 2>&1 | tail -3`
Expected: build succeeds.

- [ ] **Step 2: Manual smoke (documented; controller performs with the real backend)**

Start the backend (`cd backend && uv run uvicorn vimarsha.server:app --port 8000`),
launch the app, download a figure-rich chapter (e.g. "The Christmas Truce"), open
the player, and confirm: the text renders and **highlights + auto-scrolls** with
the audio; **tapping a paragraph seeks**; the **figure card** pops during its range
(and the **Figures button** lists all figures + "go to" works); **skip ±15s** and
the **speed chip** work.

> If a GUI run isn't possible here, `flutter build macos --debug` succeeding is the
> automated gate; the interactive smoke is documented for the user.

- [ ] **Step 3: Commit any tweaks**

```bash
git commit -am "chore: Plan 4b macOS tweaks" || echo "no changes"
```

---

## Self-Review

**Spec coverage (§4 reading UI, overlay, gallery, chrome):**
- Reading view: typography, highlight, auto-scroll, tap-to-seek → Task 2. ✅
- Figure overlay: floating card, image/quote, full-screen, stacked + tap-to-switch → Task 3. ✅
- Figures gallery: list-all + go-to-in-audio (works while paused) → Task 4. ✅
- Player chrome: title header, skip ±15s, compact speed chip, layout → Task 5. ✅
- `scrollable_positioned_list` dep + `getBook` + `skip` → Task 1. ✅
- Manual macOS gate → Task 6. ✅

**Placeholder scan:** none — every step has concrete code/commands + expected output.

**Type consistency:** Widgets take `PlayerController` and read its Plan-4a API
(`bundle`, `currentBlockId`, `currentFigures`, `imagePathFor`, `seekToBlock`) +
new `skip`. `ReadingView`/`FigureOverlay`/`FiguresGallery` constructors all take
a named `controller`. `getBook(bookId) -> Future<Book?>` matches its test and the
player's use. Icons referenced in the test (`replay_10`, `forward_10`,
`collections_bookmark`, `play_arrow`) match the screen. `_speeds`/`_speedLabel`
shared between screen and chip. Block/Figure field access (`text`, `caption`,
`label`, `kind`, `level`, `startPara`, `image`) matches the freezed models.
