// Widget test for BookScreen. Drives the chapter list with a controlled stream
// and a spy ChapterRepository (drift .watch() doesn't emit under fake-async;
// download/status reactivity is covered by ChapterRepository's own tests).
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/book/book_screen.dart';
import 'package:vimarsha/features/book/chapter_repository.dart';

import '../../support/fake_backend_client.dart';

Chapter _ch(int i, String title, String status) => Chapter(
      bookId: 'b1',
      chapterIndex: i,
      chapterId: 'c$i',
      title: title,
      downloadStatus: status,
      positionMs: 0,
    );

/// Records downloadChapter calls without touching the network/db.
class SpyChapterRepo extends ChapterRepository {
  SpyChapterRepo({required super.db, required super.files, required super.backend});
  int? downloadedIndex;

  @override
  Future<void> downloadChapter(String bookId, int index) async {
    downloadedIndex = index;
  }
}

void main() {
  late SpyChapterRepo spy;

  Future<void> pump(WidgetTester tester, List<Chapter> chapters) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dir = Directory.systemTemp.createTempSync('bs');
    spy = SpyChapterRepo(db: db, files: FileStore(dir), backend: FakeBackendClient());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chapterRepositoryProvider.overrideWithValue(spy),
        chaptersStreamProvider('b1').overrideWith((ref) => Stream.value(chapters)),
      ],
      child: const MaterialApp(home: BookScreen(bookId: 'b1')),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lists chapters with a download badge for not-downloaded',
      (tester) async {
    await pump(tester, [_ch(0, 'Chapter One', 'none'), _ch(1, 'Chapter Two', 'ready')]);
    expect(find.text('Chapter One'), findsOneWidget);
    expect(find.text('Chapter Two'), findsOneWidget);
    expect(find.byIcon(Icons.download), findsOneWidget); // not-downloaded
    expect(find.byIcon(Icons.check_circle), findsOneWidget); // ready
  });

  testWidgets('tapping the download affordance triggers downloadChapter',
      (tester) async {
    await pump(tester, [_ch(0, 'Chapter One', 'none')]);
    await tester.tap(find.byIcon(Icons.download));
    await tester.pump();
    expect(spy.downloadedIndex, 0);
  });
}
