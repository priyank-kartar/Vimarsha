import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/backend/backend_client.dart';
import '../../core/db/database.dart';
import '../../core/storage/file_store.dart';

/// Owns voice memos: capture-to-storage, transcription (graceful offline),
/// listing, retry, delete.
class MemoRepository {
  MemoRepository({
    required AppDatabase db,
    required FileStore files,
    required BackendClient backend,
    String Function()? idGen,
  })  : _db = db,
        _files = files,
        _backend = backend,
        _idGen = idGen ?? (() => const Uuid().v4());

  final AppDatabase _db;
  final FileStore _files;
  final BackendClient _backend;
  final String Function() _idGen;

  /// Store a recorded clip as a memo pinned to a paragraph, then transcribe.
  /// A transcription failure is non-fatal: the memo + audio are kept and the
  /// status becomes `error` (retryable). Returns the memo id.
  Future<String> saveMemo({
    required String bookId,
    required int chapterIndex,
    required String? blockId,
    required int positionMs,
    required File recordedFile,
  }) async {
    final id = _idGen();
    await _files.ensureMemosDir();
    final dest = _files.memoFile(id);
    await recordedFile.copy(dest.path);
    await _db.into(_db.memos).insert(MemosCompanion.insert(
          id: id,
          bookId: bookId,
          chapterIndex: chapterIndex,
          blockId: Value(blockId),
          positionMs: Value(positionMs),
          audioPath: dest.path,
        ));
    await _transcribe(id, dest);
    return id;
  }

  Future<void> _transcribe(String memoId, File audio) async {
    try {
      final text = await _backend.transcribe(audio);
      await (_db.update(_db.memos)..where((m) => m.id.equals(memoId))).write(
          MemosCompanion(
              transcript: Value(text), transcriptStatus: const Value('done')));
    } catch (_) {
      await (_db.update(_db.memos)..where((m) => m.id.equals(memoId)))
          .write(const MemosCompanion(transcriptStatus: Value('error')));
    }
  }

  Future<void> retryTranscription(String memoId) async {
    final memo = await getMemo(memoId);
    if (memo == null) return;
    await _transcribe(memoId, File(memo.audioPath));
  }

  Stream<List<Memo>> watchMemos() => (_db.select(_db.memos)
        ..orderBy([(m) => OrderingTerm(expression: m.createdAt, mode: OrderingMode.desc)]))
      .watch();

  Stream<List<Memo>> watchMemosForBook(String bookId) => (_db.select(_db.memos)
        ..where((m) => m.bookId.equals(bookId))
        ..orderBy([(m) => OrderingTerm(expression: m.createdAt, mode: OrderingMode.desc)]))
      .watch();

  Future<Memo?> getMemo(String memoId) =>
      (_db.select(_db.memos)..where((m) => m.id.equals(memoId))).getSingleOrNull();

  Future<void> deleteMemo(String memoId) async {
    final memo = await getMemo(memoId);
    if (memo != null) {
      final f = File(memo.audioPath);
      if (await f.exists()) await f.delete();
    }
    await (_db.delete(_db.memos)..where((m) => m.id.equals(memoId))).go();
  }
}
