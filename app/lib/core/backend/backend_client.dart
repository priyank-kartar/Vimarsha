import 'dart:io';

import '../models/chapter_bundle.dart';
import '../models/chat_context.dart';
import '../models/chat_message.dart';
import '../models/toc_response.dart';

/// The seam over the network. Real impl: [DioBackendClient]; tests use a fake.
abstract class BackendClient {
  /// Upload an EPUB and get its book metadata + chapter list (no narration).
  Future<TocResponse> fetchToc(File epub);

  /// Upload an EPUB and narrate one chapter; returns the full bundle.
  Future<ChapterBundle> importChapter(File epub, int chapterIndex);

  /// Download the bytes of a generated chapter audio file by its name.
  Future<List<int>> downloadAudio(String audioName);

  /// Download the bytes of a figure image by its served name.
  Future<List<int>> downloadImage(String imageName);

  /// Upload an audio clip and get its transcript text.
  Future<String> transcribe(File audio);

  /// Ask the LLM, grounded in [context], given the running conversation.
  Future<String> chat(List<ChatMessage> messages, ChatContext context);

  /// Synthesize [text] to speech; returns MP3 bytes.
  Future<List<int>> speak(String text);
}
