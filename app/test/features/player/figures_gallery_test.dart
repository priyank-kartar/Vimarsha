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
    late PlayerController c;
    await tester.runAsync(() async {
      c = await makeController();
    });
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
