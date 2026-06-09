// app/test/core/db/database_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('insert a book and read it back', () async {
    await db.into(db.books).insert(BooksCompanion.insert(
          id: 'b1', title: 'Test Book', author: const Value('Ada'),
          epubPath: '/tmp/b1/book.epub',
        ));
    final rows = await db.select(db.books).get();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Test Book');
    expect(rows.single.author, 'Ada');
  });

  test('chapter download status defaults to none and position to 0', () async {
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
          bookId: 'b1', chapterIndex: 0, chapterId: 'chap1', title: 'The Engine',
        ));
    final ch = (await db.select(db.chapters).get()).single;
    expect(ch.downloadStatus, 'none');
    expect(ch.positionMs, 0);
    expect(ch.bundlePath, isNull);
  });

  test('chapter primary key is (bookId, chapterIndex)', () async {
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
          bookId: 'b1', chapterIndex: 0, chapterId: 'chap1', title: 'A'));
    // same (bookId, index) must conflict
    expect(
      () => db.into(db.chapters).insert(ChaptersCompanion.insert(
            bookId: 'b1', chapterIndex: 0, chapterId: 'chap1', title: 'A')),
      throwsA(isA<Exception>()),
    );
  });

  test('insert a memo and read it back; defaults applied', () async {
    await db.into(db.memos).insert(MemosCompanion.insert(
          id: 'm1', bookId: 'b1', chapterIndex: 0,
          positionMs: const Value(4200), audioPath: '/tmp/m1.m4a'));
    final m = (await db.select(db.memos).get()).single;
    expect(m.id, 'm1');
    expect(m.transcriptStatus, 'pending');
    expect(m.transcript, isNull);
    expect(m.positionMs, 4200);
  });
}
