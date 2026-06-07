import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'core/providers.dart';
import 'core/storage/file_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(docs.path, 'vimarsha', 'vimarsha.sqlite'));
  await dbFile.parent.create(recursive: true);
  final db = AppDatabase(NativeDatabase.createInBackground(dbFile));
  final fileStore = FileStore(Directory(p.join(docs.path, 'vimarsha')));

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      fileStoreProvider.overrideWithValue(fileStore),
    ],
    child: const VimarshaApp(),
  ));
}
