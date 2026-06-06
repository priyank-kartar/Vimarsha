// app/test/core/providers_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/library/library_repository.dart';
import 'package:vimarsha/features/book/chapter_repository.dart';

import '../support/fake_backend_client.dart';

void main() {
  test('repository providers build from overridden db/files/backend', () {
    final db = AppDatabase(NativeDatabase.memory());
    final tmp = Directory.systemTemp.createTempSync('prov');
    addTearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      fileStoreProvider.overrideWithValue(FileStore(tmp)),
      backendClientProvider.overrideWithValue(FakeBackendClient()),
    ]);
    addTearDown(container.dispose);

    expect(container.read(libraryRepositoryProvider), isA<LibraryRepository>());
    expect(container.read(chapterRepositoryProvider), isA<ChapterRepository>());
  });

  test('backendClientProvider builds a DioBackendClient by default', () {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
      fileStoreProvider.overrideWithValue(
          FileStore(Directory.systemTemp.createTempSync('prov2'))),
    ]);
    addTearDown(container.dispose);
    // Reading it must not throw (constructs Dio from settings).
    expect(container.read(backendClientProvider), isNotNull);
  });
}
