import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'audio/audio_handler.dart';
import 'audio/just_audio_handler.dart';
import 'audio/recorder_handler.dart';
import 'audio/record_recorder_handler.dart';
import '../features/notes/memo_repository.dart';
import 'backend/backend_client.dart';
import 'backend/dio_backend_client.dart';
import 'db/database.dart';
import 'settings/app_settings.dart';
import 'storage/file_store.dart';
import '../features/library/library_repository.dart';
import '../features/book/chapter_repository.dart';
import '../features/player/player_controller.dart';

/// Overridden in main() with a real opened database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// Overridden in main() with a FileStore rooted at the app documents dir.
final fileStoreProvider = Provider<FileStore>(
  (ref) => throw UnimplementedError('fileStoreProvider must be overridden'),
);

final settingsProvider = Provider<AppSettings>((ref) => const AppSettings());

final dioProvider = Provider<Dio>((ref) {
  final settings = ref.watch(settingsProvider);
  return Dio(BaseOptions(baseUrl: settings.backendBaseUrl));
});

final backendClientProvider = Provider<BackendClient>(
  (ref) => DioBackendClient(ref.watch(dioProvider)),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    db: ref.watch(databaseProvider),
    files: ref.watch(fileStoreProvider),
    backend: ref.watch(backendClientProvider),
  ),
);

final chapterRepositoryProvider = Provider<ChapterRepository>(
  (ref) => ChapterRepository(
    db: ref.watch(databaseProvider),
    files: ref.watch(fileStoreProvider),
    backend: ref.watch(backendClientProvider),
  ),
);

/// The audio device seam. Overridden with a fake in tests.
final audioHandlerProvider = Provider<AudioHandler>((ref) {
  final handler = JustAudioHandler();
  ref.onDispose(handler.dispose);
  return handler;
});

/// A SEPARATE audio handler for memo playback on the Notes screen, so playing a
/// memo never drives the chapter player's position stream (which would corrupt
/// the saved reading position).
final memoAudioHandlerProvider = Provider<AudioHandler>((ref) {
  final handler = JustAudioHandler();
  ref.onDispose(handler.dispose);
  return handler;
});

/// Streams the library (title/author rows) for the library screen.
final booksStreamProvider = StreamProvider<List<Book>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchBooks(),
);

/// Streams a book's chapters (with download status) for the book screen.
final chaptersStreamProvider =
    StreamProvider.family<List<Chapter>, String>(
  (ref, bookId) => ref.watch(chapterRepositoryProvider).watchChapters(bookId),
);

/// Picks an EPUB from disk. Returns the file, or null if cancelled.
/// Overridden in tests so widget tests never hit the platform picker.
typedef EpubPicker = Future<File?> Function();

Future<File?> _pickEpubFromDisk() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['epub'],
  );
  final path = result?.files.single.path;
  return path == null ? null : File(path);
}

final filePickerProvider = Provider<EpubPicker>((ref) => _pickEpubFromDisk);

final recorderHandlerProvider = Provider<RecorderHandler>((ref) {
  final handler = RecordRecorderHandler();
  ref.onDispose(handler.dispose);
  return handler;
});

final memoRepositoryProvider = Provider<MemoRepository>(
  (ref) => MemoRepository(
    db: ref.watch(databaseProvider),
    files: ref.watch(fileStoreProvider),
    backend: ref.watch(backendClientProvider),
  ),
);

final memosStreamProvider = StreamProvider<List<Memo>>(
  (ref) => ref.watch(memoRepositoryProvider).watchMemos(),
);

/// One PlayerController per (bookId, index). Auto-disposed when the player
/// screen is left, which cancels subscriptions and saves final progress.
final playerControllerProvider = ChangeNotifierProvider.autoDispose
    .family<PlayerController, ({String bookId, int index})>((ref, args) {
  return PlayerController(
    audio: ref.watch(audioHandlerProvider),
    chapters: ref.watch(chapterRepositoryProvider),
    files: ref.watch(fileStoreProvider),
    bookId: args.bookId,
    index: args.index,
  );
});
