import 'dart:io';

import '../models/chapter_bundle.dart';
import '../models/toc_response.dart';

/// The seam over the network. Real impl: [DioBackendClient]; tests use a fake.
abstract class BackendClient {
  /// Upload an EPUB and get its book metadata + chapter list (no narration).
  Future<TocResponse> fetchToc(File epub);

  /// Upload an EPUB and narrate one chapter; returns the full bundle.
  Future<ChapterBundle> importChapter(File epub, int chapterIndex);

  /// Download the bytes of a generated chapter audio file by its name.
  Future<List<int>> downloadAudio(String audioName);
}
