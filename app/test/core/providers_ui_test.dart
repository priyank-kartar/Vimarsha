// app/test/core/providers_ui_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/audio/audio_handler.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/core/storage/file_store.dart';

import '../support/fake_audio_handler.dart';
import '../support/fake_backend_client.dart';

void main() {
  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
      fileStoreProvider.overrideWithValue(
          FileStore(Directory.systemTemp.createTempSync('pui'))),
      backendClientProvider.overrideWithValue(FakeBackendClient()),
      audioHandlerProvider.overrideWithValue(FakeAudioHandler()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('audioHandlerProvider can be overridden', () {
    expect(container().read(audioHandlerProvider), isA<AudioHandler>());
  });

  test('booksStreamProvider yields an empty list initially', () async {
    final c = container();
    // Riverpod 3: listen to keep the stream provider alive (otherwise stream
    // is paused when no listeners, and .future never resolves).
    final sub = c.listen(booksStreamProvider, (prev, next) {});
    addTearDown(sub.close);
    final books = await c.read(booksStreamProvider.future);
    expect(books, isEmpty);
  });

  test('filePickerProvider returns a callable', () {
    expect(container().read(filePickerProvider), isA<Function>());
  });
}
