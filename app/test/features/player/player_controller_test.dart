// app/test/features/player/player_controller_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/models/block.dart';
import 'package:vimarsha/core/models/chapter_bundle.dart';
import 'package:vimarsha/core/models/figure.dart';
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
      audio: audio, chapters: chapters,
      files: FileStore(Directory.systemTemp.createTempSync('pc')),
      bookId: 'b1', index: 0);

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

  ChapterBundle testBundle() => const ChapterBundle(
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
    final repo = ChapterRepository(db: db, files: files, backend: FakeBackendClient());
    await files.ensureChapterDir('b1', 0);
    await files.bundleFile('b1', 0)
        .writeAsString(jsonEncode(testBundle().toJson()));
    final c = PlayerController(
        audio: audio, chapters: repo, files: files, bookId: 'b1', index: 0);
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
    final f1 = testBundle().figureMap[0];
    final f2 = testBundle().figureMap[1];
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
}
