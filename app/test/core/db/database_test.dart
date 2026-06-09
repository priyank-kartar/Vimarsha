// app/test/core/db/database_test.dart
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
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

  test('upgrading a v1 database adds memos and preserves existing data',
      () async {
    final dir = Directory.systemTemp.createTempSync('mig');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/v1.sqlite';

    // Fabricate a schemaVersion-1 database: the old tables, a row, user_version=1.
    final raw = sqlite3.open(path);
    raw.execute('CREATE TABLE books (id TEXT NOT NULL PRIMARY KEY, '
        "title TEXT NOT NULL, author TEXT NOT NULL DEFAULT '', "
        'epub_path TEXT NOT NULL, created_at INTEGER NOT NULL);');
    raw.execute('CREATE TABLE chapters (book_id TEXT NOT NULL, '
        'chapter_index INTEGER NOT NULL, chapter_id TEXT NOT NULL, '
        "title TEXT NOT NULL, download_status TEXT NOT NULL DEFAULT 'none', "
        'bundle_path TEXT, audio_path TEXT, duration_ms INTEGER, '
        'position_ms INTEGER NOT NULL DEFAULT 0, '
        'PRIMARY KEY (book_id, chapter_index));');
    raw.execute("INSERT INTO books (id, title, author, epub_path, created_at) "
        "VALUES ('b1', 'Old Book', 'Ada', '/x', 1700000000);");
    raw.execute('PRAGMA user_version = 1;');
    raw.close();

    // Opening via drift runs onUpgrade (1 -> 2): the memos table is created.
    final migrated = AppDatabase(NativeDatabase(File(path)));
    addTearDown(migrated.close);

    // memos table now exists and is usable
    await migrated.into(migrated.memos).insert(MemosCompanion.insert(
          id: 'm1', bookId: 'b1', chapterIndex: 0, audioPath: '/tmp/m.m4a'));
    expect((await migrated.select(migrated.memos).get()).single.id, 'm1');
    // pre-existing data survived the upgrade
    expect((await migrated.select(migrated.books).get()).single.title, 'Old Book');
  });
}
