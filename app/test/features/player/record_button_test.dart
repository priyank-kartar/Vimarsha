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
    await tester.runAsync(() async {
      await controller.load('/a.mp3');
      await controller.play(); // playing before recording
    });

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

    // release — _stop() triggers saveMemo which has real dart:io (ensureMemosDir, file copy)
    // runAsync around gesture.up lets those futures complete before we assert
    await tester.runAsync(() async {
      await gesture.up();
      // Give the async-void _stop() chain enough real time to complete
      // (stop → existsSync/lengthSync → saveMemo → ensureMemosDir.create → file.copy → db.insert → transcribe)
      for (var i = 0; i < 20; i++) {
        final rows = await db.select(db.memos).get();
        if (rows.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();
    expect(recorder.isRecording, isFalse);

    final memos = await db.select(db.memos).get();
    expect(memos, hasLength(1));
    expect(memos.single.bookId, 'b1');
  });

  testWidgets('releasing during start does not strand the recording', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tmp = Directory.systemTemp.createTempSync('rb2');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final files = FileStore(tmp);
    final audio = FakeAudioHandler();
    final recorder = FakeRecorderHandler();
    final chapters =
        ChapterRepository(db: db, files: files, backend: FakeBackendClient());
    final controller = PlayerController(
        audio: audio, chapters: chapters, files: files, bookId: 'b1', index: 0);
    addTearDown(controller.dispose);
    await tester.runAsync(() async {
      await controller.load('/a.mp3');
      await controller.play();
    });

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

    // Press then release almost immediately (before start() finishes awaiting).
    await tester.runAsync(() async {
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(RecordButton)));
      await gesture.up();
      // let the start→stop sequence settle
      for (var i = 0; i < 20; i++) {
        if (!recorder.isRecording && controller.playing) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();

    // The recorder must not be left running, and playback must have resumed.
    expect(recorder.isRecording, isFalse);
    expect(controller.playing, isTrue);
  });
}
