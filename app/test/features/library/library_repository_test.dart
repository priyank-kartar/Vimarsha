// app/test/features/library/library_repository_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/models/book_meta.dart';
import 'package:vimarsha/core/models/chapter_summary.dart';
import 'package:vimarsha/core/models/toc_response.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/library/library_repository.dart';

import '../../support/fake_backend_client.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late FileStore files;
  late FakeBackendClient backend;
  late File pickedEpub;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('lib');
    files = FileStore(tmp);
    backend = FakeBackendClient(
      toc: const TocResponse(
        book: BookMeta(title: 'Test Book', author: 'Ada'),
        chapters: [
          ChapterSummary(index: 0, chapterId: 'chap1', title: 'The Engine'),
          ChapterSummary(index: 1, chapterId: 'chap2', title: 'The Wheel'),
        ],
      ),
    );
    pickedEpub = File('${tmp.path}/picked.epub')..writeAsBytesSync([9, 9, 9]);
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  LibraryRepository repo() => LibraryRepository(
        db: db, files: files, backend: backend, idGen: () => 'bookX');

  test('addBook copies epub, stores book + chapters, returns id', () async {
    final id = await repo().addBook(pickedEpub);
    expect(id, 'bookX');

    expect(files.epubFile('bookX').existsSync(), isTrue);

    final books = await db.select(db.books).get();
    expect(books.single.title, 'Test Book');
    expect(books.single.author, 'Ada');

    final chapters = await db.select(db.chapters).get();
    expect(chapters, hasLength(2));
    expect(chapters.every((c) => c.downloadStatus == 'none'), isTrue);
    expect(chapters.map((c) => c.chapterIndex).toList()..sort(), [0, 1]);
  });

  test('backend failure leaves no rows and removes the copied epub', () async {
    backend.throwOnToc = Exception('boom');
    await expectLater(repo().addBook(pickedEpub), throwsException);
    expect(await db.select(db.books).get(), isEmpty);
    expect(await db.select(db.chapters).get(), isEmpty);
    expect(Directory('${tmp.path}/books/bookX').existsSync(), isFalse);
  });

  test('watchBooks emits inserted books', () async {
    await repo().addBook(pickedEpub);
    final books = await repo().watchBooks().first;
    expect(books.single.id, 'bookX');
  });

  test('getBook returns the stored book or null', () async {
    expect(await repo().getBook('missing'), isNull);
    await repo().addBook(pickedEpub); // inserts book 'bookX'
    final book = await repo().getBook('bookX');
    expect(book, isNotNull);
    expect(book!.title, 'Test Book');
  });
}
