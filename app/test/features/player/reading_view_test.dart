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
  late PlayerController c;
  await tester.runAsync(() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tmp = Directory.systemTemp.createTempSync('rv');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final files = FileStore(tmp);
    await files.ensureChapterDir('b1', 0);
    await files.bundleFile('b1', 0).writeAsString(jsonEncode(testBundle().toJson()));
    final chapters = ChapterRepository(db: db, files: files, backend: FakeBackendClient());
    final audio = FakeAudioHandler();
    c = PlayerController(
        audio: audio, chapters: chapters, files: files, bookId: 'b1', index: 0);
    await c.load('/a.mp3');
    addTearDown(c.dispose);
  });
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
    await tester.runAsync(() => c.seek(const Duration(milliseconds: 4000)));
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
