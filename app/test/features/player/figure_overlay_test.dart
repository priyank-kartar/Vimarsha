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
    late PlayerController c;
    await tester.runAsync(() async {
      c = await makeController();
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FigureOverlay(controller: c))));
    await tester.pump();
    expect(find.text('Quote one'), findsNothing);

    await tester.runAsync(() => c.seek(const Duration(milliseconds: 2000))); // only f1 active
    await tester.pump();
    expect(find.text('Quote one'), findsOneWidget);
  });

  testWidgets('stacked figures show a counter and tap switches', (tester) async {
    late PlayerController c;
    await tester.runAsync(() async {
      c = await makeController();
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FigureOverlay(controller: c))));
    await tester.runAsync(() => c.seek(const Duration(milliseconds: 4500))); // f1 and f2 both active
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Quote one'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('figure-next')));
    await tester.pump();
    expect(find.text('Quote two'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
  });
}
