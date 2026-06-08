import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/backend/backend_client.dart';
import '../../core/db/database.dart';
import '../../core/models/chapter_bundle.dart';
import '../../core/storage/file_store.dart';

/// Owns per-chapter download (narrated bundle + audio) and reading progress.
class ChapterRepository {
  ChapterRepository({
    required AppDatabase db,
    required FileStore files,
    required BackendClient backend,
  })  : _db = db,
        _files = files,
        _backend = backend;

  final AppDatabase _db;
  final FileStore _files;
  final BackendClient _backend;

  Future<void> _setStatus(String bookId, int index, String status) =>
      (_db.update(_db.chapters)
            ..where((c) => c.bookId.equals(bookId) & c.chapterIndex.equals(index)))
          .write(ChaptersCompanion(downloadStatus: Value(status)));

  /// Download a chapter: narrate via the backend, cache bundle + audio, mark
  /// ready. On any failure, partial files are removed and status becomes error.
  Future<void> downloadChapter(String bookId, int index) async {
    await _setStatus(bookId, index, 'downloading');
    try {
      final epub = _files.epubFile(bookId);
      final bundle = await _backend.importChapter(epub, index);
      final audioName = bundle.audio;
      if (audioName == null) {
        throw StateError('bundle has no audio for $bookId/$index');
      }

      await _files.ensureChapterDir(bookId, index);
      final bundleFile = _files.bundleFile(bookId, index);
      await bundleFile.writeAsString(jsonEncode(bundle.toJson()));

      final bytes = await _backend.downloadAudio(audioName);
      if (bytes.isEmpty) {
        throw StateError('empty audio for $bookId/$index');
      }
      final audioFile = _files.audioFile(bookId, index);
      await audioFile.writeAsBytes(bytes);

      // Cache figure images (best-effort; a failure here does not fail the chapter).
      for (final fig in bundle.figureMap) {
        final imageName = fig.image;
        if (imageName == null) continue;
        try {
          final imgBytes = await _backend.downloadImage(imageName);
          if (imgBytes.isNotEmpty) {
            await _files.ensureImagesDir(bookId, index);
            await _files.imageFile(bookId, index, imageName).writeAsBytes(imgBytes);
          }
        } catch (_) {/* non-fatal: card will show without the image */}
      }

      await (_db.update(_db.chapters)
            ..where((c) => c.bookId.equals(bookId) & c.chapterIndex.equals(index)))
          .write(ChaptersCompanion(
        downloadStatus: const Value('ready'),
        bundlePath: Value(bundleFile.path),
        audioPath: Value(audioFile.path),
      ));
    } catch (_) {
      // Best-effort cleanup: never let a cleanup failure mask the real error or
      // leave the row stuck in 'downloading'.
      try {
        await _files.removeChapter(bookId, index);
      } catch (_) {/* ignore */}
      try {
        await _setStatus(bookId, index, 'error');
      } catch (_) {/* ignore */}
      rethrow;
    }
  }

  Future<void> saveProgress(String bookId, int index, int positionMs) =>
      (_db.update(_db.chapters)
            ..where((c) => c.bookId.equals(bookId) & c.chapterIndex.equals(index)))
          .write(ChaptersCompanion(positionMs: Value(positionMs)));

  Stream<List<Chapter>> watchChapters(String bookId) => (_db.select(_db.chapters)
        ..where((c) => c.bookId.equals(bookId))
        ..orderBy([(c) => OrderingTerm(expression: c.chapterIndex)]))
      .watch();

  Future<Chapter?> getChapter(String bookId, int index) =>
      (_db.select(_db.chapters)
            ..where((c) => c.bookId.equals(bookId) & c.chapterIndex.equals(index)))
          .getSingleOrNull();

  /// Read and parse the cached bundle JSON for a chapter, or null if absent.
  Future<ChapterBundle?> loadBundle(String bookId, int index) async {
    final file = _files.bundleFile(bookId, index);
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return ChapterBundle.fromJson(json);
  }
}
