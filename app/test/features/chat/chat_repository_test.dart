import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/models/chat_message.dart';
import 'package:vimarsha/features/chat/chat_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ChatRepository repo() => ChatRepository(db: db, idGen: () => 'thread1');

  test('saveThread persists a thread and its messages', () async {
    final id = await repo().saveThread(
      bookId: 'b1', chapterIndex: 2, anchorBlockId: 'p3', title: 'Why?',
      messages: const [
        ChatMessage(role: 'user', text: 'why did they trust?'),
        ChatMessage(role: 'assistant', text: 'because of safety'),
      ],
    );
    expect(id, 'thread1');
    final t = (await db.select(db.chatThreads).get()).single;
    expect(t.bookId, 'b1');
    expect(t.chapterIndex, 2);
    expect(t.title, 'Why?');
    final lines = await (db.select(db.chatLines)
          ..orderBy([(l) => OrderingTerm(expression: l.createdAt)]))
        .get();
    expect(lines.map((l) => l.role).toList(), ['user', 'assistant']);
    expect(lines.first.body, 'why did they trust?');
  });

  test('each saveThread creates a new thread (multiple per chapter)', () async {
    var n = 0;
    final r = ChatRepository(db: db, idGen: () => 'th${n++}');
    await r.saveThread(bookId: 'b1', chapterIndex: 0, messages: const [
      ChatMessage(role: 'user', text: 'a')]);
    await r.saveThread(bookId: 'b1', chapterIndex: 0, messages: const [
      ChatMessage(role: 'user', text: 'b')]);
    expect((await db.select(db.chatThreads).get()).length, 2);
  });

  test('watchMessages returns a thread\'s lines; deleteThread clears both', () async {
    await repo().saveThread(bookId: 'b1', chapterIndex: 0, messages: const [
      ChatMessage(role: 'user', text: 'hi')]);
    final lines = await repo().watchMessages('thread1').first;
    expect(lines, hasLength(1));
    await repo().deleteThread('thread1');
    expect(await db.select(db.chatThreads).get(), isEmpty);
    expect(await db.select(db.chatLines).get(), isEmpty);
  });
}
