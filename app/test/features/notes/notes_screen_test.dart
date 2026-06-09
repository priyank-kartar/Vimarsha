import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/book/chapter_repository.dart';
import 'package:vimarsha/features/notes/notes_screen.dart';

import '../../support/fake_backend_client.dart';

/// Spy chapter repo to verify "open at pin" sets the resume position.
class SpyChapterRepo extends ChapterRepository {
  SpyChapterRepo({required super.db, required super.files, required super.backend});
  int? savedMs;
  @override
  Future<void> saveProgress(String bookId, int index, int positionMs) async {
    savedMs = positionMs;
  }
}

// A pre-built Memo for all tests — avoids drift watch-under-fake-async issues.
final _memo = Memo(
  id: 'm1',
  bookId: 'b1',
  chapterIndex: 2,
  positionMs: 7000,
  audioPath: '/tmp/m1.m4a',
  transcript: 'come back to this',
  transcriptStatus: 'done',
  createdAt: DateTime(2025),
);

void main() {
  late AppDatabase db;
  late SpyChapterRepo chapters;

  Future<void> pump(WidgetTester tester) async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tmp = Directory.systemTemp.createTempSync('notes');
    final files = FileStore(tmp);
    chapters = SpyChapterRepo(db: db, files: files, backend: FakeBackendClient());
    // Insert a book so the title lookup works via booksStreamProvider.
    await db.into(db.books).insert(BooksCompanion.insert(
        id: 'b1', title: 'The Culture Code', epubPath: 'x'));
    // Override memosStreamProvider with Stream.value to avoid drift's
    // pending-timer issue under fake-async; override booksStreamProvider
    // similarly so the book title resolves without a live watch.
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, s) => const NotesScreen()),
      GoRoute(path: '/player/:bookId/:index', builder: (_, s) => const SizedBox()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWithValue(files),
        backendClientProvider.overrideWithValue(FakeBackendClient()),
        chapterRepositoryProvider.overrideWithValue(chapters),
        booksStreamProvider.overrideWith(
          (ref) => Stream.value([
            Book(
              id: 'b1', title: 'The Culture Code', author: '', epubPath: 'x',
              createdAt: DateTime(2025),
            ),
          ])),
        memosStreamProvider.overrideWith(
          (ref) => Stream.value([_memo])),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lists memos with transcript and book/chapter', (tester) async {
    await pump(tester);
    expect(find.text('come back to this'), findsOneWidget);
    expect(find.textContaining('The Culture Code'), findsOneWidget);
  });

  testWidgets('open-at-pin sets the chapter resume position', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pump();
    expect(chapters.savedMs, 7000);
  });
}
