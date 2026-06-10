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

  test('insert a chat thread + line', () async {
    await db.into(db.chatThreads).insert(ChatThreadsCompanion.insert(
        id: 't1', bookId: 'b1', chapterIndex: 0, title: const Value('Why trust?')));
    await db.into(db.chatLines).insert(ChatLinesCompanion.insert(
        id: 'l1', threadId: 't1', role: 'user', body: 'why?'));
    expect((await db.select(db.chatThreads).get()).single.title, 'Why trust?');
    expect((await db.select(db.chatLines).get()).single.body, 'why?');
  });

  test('upgrading a v2 database adds chat tables and preserves data', () async {
    final dir = Directory.systemTemp.createTempSync('mig3');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/v2.sqlite';
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
    raw.execute('CREATE TABLE memos (id TEXT NOT NULL PRIMARY KEY, '
        'book_id TEXT NOT NULL, chapter_index INTEGER NOT NULL, block_id TEXT, '
        'position_ms INTEGER NOT NULL DEFAULT 0, audio_path TEXT NOT NULL, '
        "transcript TEXT, transcript_status TEXT NOT NULL DEFAULT 'pending', "
        'created_at INTEGER NOT NULL);');
    raw.execute("INSERT INTO books (id, title, author, epub_path, created_at) "
        "VALUES ('b1', 'Old Book', 'Ada', '/x', 1700000000);");
    raw.execute('PRAGMA user_version = 2;');
    raw.close();

    final migrated = AppDatabase(NativeDatabase(File(path)));
    addTearDown(migrated.close);
    await migrated.into(migrated.chatThreads).insert(
        ChatThreadsCompanion.insert(id: 't1', bookId: 'b1', chapterIndex: 0));
    expect((await migrated.select(migrated.chatThreads).get()).single.id, 't1');
    expect((await migrated.select(migrated.books).get()).single.title, 'Old Book');
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

    // a v1 DB runs BOTH the from<2 (memos) and from<3 (chat) upgrade steps
    await migrated.into(migrated.memos).insert(MemosCompanion.insert(
          id: 'm1', bookId: 'b1', chapterIndex: 0, audioPath: '/tmp/m.m4a'));
    expect((await migrated.select(migrated.memos).get()).single.id, 'm1');
    await migrated.into(migrated.chatThreads).insert(
        ChatThreadsCompanion.insert(id: 't1', bookId: 'b1', chapterIndex: 0));
    expect((await migrated.select(migrated.chatThreads).get()).single.id, 't1');
    // pre-existing data survived the upgrade
    expect((await migrated.select(migrated.books).get()).single.title, 'Old Book');
  });
}
