// app/test/features/notes/memo_repository_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/notes/memo_repository.dart';

import '../../support/fake_backend_client.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late FileStore files;
  late FakeBackendClient backend;
  late File recorded;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('memo');
    files = FileStore(tmp);
    backend = FakeBackendClient();
    recorded = File('${tmp.path}/rec.m4a')..writeAsBytesSync(const [9, 9, 9]);
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  MemoRepository repo() => MemoRepository(
      db: db, files: files, backend: backend, idGen: () => 'memoX');

  Future<Memo> row() async => (await db.select(db.memos).get()).single;

  test('saveMemo caches audio, inserts row, fills transcript', () async {
    backend.transcript = 'this is my note';
    final id = await repo().saveMemo(
        bookId: 'b1', chapterIndex: 0, blockId: 'p3', positionMs: 4200,
        recordedFile: recorded);
    expect(id, 'memoX');
    expect(files.memoFile('memoX').existsSync(), isTrue);
    final m = await row();
    expect(m.bookId, 'b1');
    expect(m.blockId, 'p3');
    expect(m.positionMs, 4200);
    expect(m.transcript, 'this is my note');
    expect(m.transcriptStatus, 'done');
    expect(backend.transcribeRequests, isNotEmpty);
  });

  test('backend failure keeps the memo with error status', () async {
    backend.throwOnTranscribe = Exception('offline');
    await repo().saveMemo(
        bookId: 'b1', chapterIndex: 0, blockId: null, positionMs: 0,
        recordedFile: recorded);
    final m = await row();
    expect(m.transcriptStatus, 'error');
    expect(m.transcript, isNull);
    expect(files.memoFile('memoX').existsSync(), isTrue); // audio kept
  });

  test('retryTranscription fills a previously failed memo', () async {
    backend.throwOnTranscribe = Exception('offline');
    await repo().saveMemo(
        bookId: 'b1', chapterIndex: 0, blockId: null, positionMs: 0,
        recordedFile: recorded);
    backend.throwOnTranscribe = null;
    backend.transcript = 'recovered';
    await repo().retryTranscription('memoX');
    final m = await row();
    expect(m.transcriptStatus, 'done');
    expect(m.transcript, 'recovered');
  });

  test('deleteMemo removes the row and the audio file', () async {
    await repo().saveMemo(
        bookId: 'b1', chapterIndex: 0, blockId: null, positionMs: 0,
        recordedFile: recorded);
    await repo().deleteMemo('memoX');
    expect(await db.select(db.memos).get(), isEmpty);
    expect(files.memoFile('memoX').existsSync(), isFalse);
  });

  test('watchMemos emits saved memos', () async {
    await repo().saveMemo(
        bookId: 'b1', chapterIndex: 0, blockId: null, positionMs: 0,
        recordedFile: recorded);
    final memos = await repo().watchMemos().first;
    expect(memos.single.id, 'memoX');
  });
}
