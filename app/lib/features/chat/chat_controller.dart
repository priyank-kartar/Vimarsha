import 'package:flutter/foundation.dart';

import '../../core/backend/backend_client.dart';
import '../../core/models/chat_context.dart';
import '../../core/models/chat_message.dart';

/// Holds one live, in-memory conversation. Snapshots the passage context at each
/// send so grounding follows playback. Nothing is persisted here — saving is the
/// repository's job, on explicit user action.
class ChatController extends ChangeNotifier {
  ChatController({
    required BackendClient backend,
    required ChatContext Function() contextSnapshot,
  })  : _backend = backend,
        _contextSnapshot = contextSnapshot;

  final BackendClient _backend;
  final ChatContext Function() _contextSnapshot;

  final List<ChatMessage> messages = [];
  bool sending = false;
  bool error = false;

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || sending) return;
    sending = true; // claim synchronously so a rapid second call is ignored
    messages.add(ChatMessage(role: 'user', text: trimmed));
    await _send();
  }

  /// Re-send after a failure (the last turn is the unanswered user message).
  Future<void> retry() async {
    if (sending) return;
    sending = true;
    await _send();
  }

  Future<void> _send() async {
    // `sending` is already set true by the caller (synchronously) so the guard
    // and the flag live together; here we just run the request.
    error = false;
    notifyListeners();
    try {
      final reply = await _backend.chat(List.of(messages), _contextSnapshot());
      messages.add(ChatMessage(role: 'assistant', text: reply));
    } catch (_) {
      error = true;
    } finally {
      sending = false;
      notifyListeners();
    }
  }
}
