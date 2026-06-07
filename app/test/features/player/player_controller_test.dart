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
