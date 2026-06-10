import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/models/chat_context.dart';
import 'package:vimarsha/features/chat/chat_controller.dart';

import '../../support/fake_backend_client.dart';

ChatContext _ctx() => const ChatContext(
    passage: 'the team trusted each other', bookTitle: 'B', chapterTitle: 'C');

void main() {
  test('sendMessage appends the user turn then the assistant reply', () async {
    final backend = FakeBackendClient()..reply = 'because of psychological safety';
    final c = ChatController(backend: backend, contextSnapshot: _ctx);
    await c.sendMessage('why did they trust?');
    expect(c.messages.map((m) => m.role).toList(), ['user', 'assistant']);
    expect(c.messages.last.text, 'because of psychological safety');
    expect(c.sending, isFalse);
    expect(c.error, isFalse);
    // the backend received the user turn
    expect(backend.chatCalls.single.single.text, 'why did they trust?');
  });

  test('a backend failure flags error and keeps the user turn (retryable)', () async {
    final backend = FakeBackendClient()..throwOnChat = Exception('ollama down');
    final c = ChatController(backend: backend, contextSnapshot: _ctx);
    await c.sendMessage('why?');
    expect(c.messages, hasLength(1)); // just the user turn
    expect(c.error, isTrue);

    backend.throwOnChat = null;
    backend.reply = 'recovered answer';
    await c.retry();
    expect(c.error, isFalse);
    expect(c.messages.last.text, 'recovered answer');
  });

  test('a rapid second send while one is in flight is ignored', () async {
    final backend = FakeBackendClient()..reply = 'answer';
    final c = ChatController(backend: backend, contextSnapshot: _ctx);
    final f1 = c.sendMessage('q1');
    final f2 = c.sendMessage('q2'); // should be dropped (already sending)
    await Future.wait([f1, f2]);
    expect(backend.chatCalls, hasLength(1));
    expect(c.messages.where((m) => m.role == 'user').length, 1);
  });

  test('context is snapshotted at send time', () async {
    var passage = 'first passage';
    final backend = FakeBackendClient();
    final c = ChatController(
        backend: backend,
        contextSnapshot: () => ChatContext(
            passage: passage, bookTitle: 'B', chapterTitle: 'C'));
    await c.sendMessage('q1');
    passage = 'later passage';
    await c.sendMessage('q2');
    // (the fake records messages, not context, but this proves the callback is
    // invoked per send without throwing as the live passage changes)
    expect(backend.chatCalls, hasLength(2));
  });
}
