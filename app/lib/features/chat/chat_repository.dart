import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/models/chat_message.dart';

/// Persistence for saved conversations. Threads + lines are written ONLY when
/// the user taps Save; each save creates a new thread.
class ChatRepository {
  ChatRepository({required AppDatabase db, String Function()? idGen})
      : _db = db,
        _idGen = idGen ?? (() => const Uuid().v4());

  final AppDatabase _db;
  final String Function() _idGen;
  static const _uuid = Uuid();

  Future<String> saveThread({
    required String bookId,
    required int chapterIndex,
    String? anchorBlockId,
    String? title,
    required List<ChatMessage> messages,
  }) async {
    final threadId = _idGen();
    await _db.transaction(() async {
      await _db.into(_db.chatThreads).insert(ChatThreadsCompanion.insert(
            id: threadId,
            bookId: bookId,
            chapterIndex: chapterIndex,
            anchorBlockId: Value(anchorBlockId),
            title: Value(title),
          ));
      for (final m in messages) {
        await _db.into(_db.chatLines).insert(ChatLinesCompanion.insert(
              id: _uuid.v4(),
              threadId: threadId,
              role: m.role,
              body: m.text,
            ));
      }
    });
    return threadId;
  }

  Stream<List<ChatThread>> watchThreads() => (_db.select(_db.chatThreads)
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
      .watch();

  Stream<List<ChatLine>> watchMessages(String threadId) => (_db.select(_db.chatLines)
        ..where((l) => l.threadId.equals(threadId))
        ..orderBy([(l) => OrderingTerm(expression: l.createdAt)]))
      .watch();

  Future<List<ChatLine>> getThreadMessages(String threadId) =>
      (_db.select(_db.chatLines)
            ..where((l) => l.threadId.equals(threadId))
            ..orderBy([(l) => OrderingTerm(expression: l.createdAt)]))
          .get();

  Future<void> deleteThread(String threadId) async {
    await (_db.delete(_db.chatLines)..where((l) => l.threadId.equals(threadId))).go();
    await (_db.delete(_db.chatThreads)..where((t) => t.id.equals(threadId))).go();
  }
}
