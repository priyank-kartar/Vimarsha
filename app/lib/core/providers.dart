import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend/backend_client.dart';
import 'backend/dio_backend_client.dart';
import 'db/database.dart';
import 'settings/app_settings.dart';
import 'storage/file_store.dart';
import '../features/library/library_repository.dart';
import '../features/book/chapter_repository.dart';

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
