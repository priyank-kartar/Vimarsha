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
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
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
