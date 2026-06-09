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
import 'package:vimarsha/features/book/chapter_repository.dart';
import 'package:vimarsha/features/player/player_screen.dart';
import 'package:vimarsha/features/player/record_button.dart';

import '../../support/fake_audio_handler.dart';
import '../../support/fake_backend_client.dart';

ChapterBundle bundle() => const ChapterBundle(
      chapterId: 'c1', title: 'The Engine',
      blocks: [Block(id: 'p0', index: 0, kind: 'paragraph', text: 'Hello there.')],
      figureMap: [], paraTimings: {'p0': [0, 5000]});

/// Returns the bundle from memory so the player's load() does no real disk I/O
/// (which would never complete under the widget-test fake clock).
class FakeChapterRepo extends ChapterRepository {
  FakeChapterRepo({required super.db, required super.files, required super.backend});

  @override
  Future<ChapterBundle?> loadBundle(String bookId, int index) async => bundle();
}

void main() {
  testWidgets('renders title header, transport, and reading text', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final audio = FakeAudioHandler();
    final dir = Directory.systemTemp.createTempSync('ps');
    final files = FileStore(dir);
    final chapters = FakeChapterRepo(db: db, files: files, backend: FakeBackendClient());
    await db.into(db.books).insert(BooksCompanion.insert(
        id: 'b1', title: 'Test Book', author: const Value('Ada'), epubPath: 'x'));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        bookId: 'b1', chapterIndex: 0, chapterId: 'c1', title: 'The Engine',
        audioPath: Value('${dir.path}/a.mp3'), downloadStatus: const Value('ready')));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWithValue(files),
        backendClientProvider.overrideWithValue(FakeBackendClient()),
        audioHandlerProvider.overrideWithValue(audio),
        chapterRepositoryProvider.overrideWithValue(chapters),
      ],
      child: const MaterialApp(home: PlayerScreen(bookId: 'b1', index: 0)),
    ));
    // load() is all in-memory/drift now -> completes on microtasks.
    await tester.pump(); // fire post-frame load()
    await tester.pump(); // rebuild loaded
    await tester.pump(const Duration(milliseconds: 400)); // settle auto-scroll

    expect(find.text('Test Book'), findsOneWidget); // book title in header
    expect(find.text('The Engine'), findsWidgets); // chapter title (header + maybe text)
    expect(find.text('Hello there.'), findsOneWidget); // reading text rendered
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.replay_10), findsOneWidget); // skip back
    expect(find.byIcon(Icons.forward_10), findsOneWidget); // skip fwd

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(audio.playCalled, isTrue);
    expect(find.text('1.0×'), findsOneWidget); // compact speed chip
    expect(find.byType(RecordButton), findsOneWidget); // hold-to-record present
  });
}
