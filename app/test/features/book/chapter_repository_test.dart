// app/test/features/book/chapter_repository_test.dart
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/models/chapter_bundle.dart';
import 'package:vimarsha/core/models/figure.dart';
import 'package:vimarsha/core/storage/file_store.dart';
import 'package:vimarsha/features/book/chapter_repository.dart';

import '../../support/fake_backend_client.dart';

ChapterBundle _bundle() => const ChapterBundle(
      chapterId: 'chap1',
      title: 'The Engine',
      blocks: [],
      figureMap: [],
      audio: 'chap1.mp3',
      paraTimings: {},
    );

ChapterBundle _bundleWithFigure() => const ChapterBundle(
      chapterId: 'chap1',
      title: 'The Engine',
      blocks: [],
      figureMap: [
        Figure(
          figureId: 'b2', kind: 'figure', startPara: 'b2', endPara: 'b3',
          startMs: 0, endMs: 1000, image: 'chap1_b2.png',
        ),
      ],
      audio: 'chap1.mp3',
      paraTimings: {},
    );

void main() {
  late AppDatabase db;
  late Directory tmp;
  late FileStore files;
  late FakeBackendClient backend;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('chap');
    files = FileStore(tmp);
    backend = FakeBackendClient(bundle: _bundle(), audio: [1, 2, 3, 4, 5]);
    // seed a book + one chapter row + a stored epub
    await files.ensureBookDir('bookX');
    await files.epubFile('bookX').writeAsBytes([0]);
    await db.into(db.books).insert(BooksCompanion.insert(
        id: 'bookX', title: 'B', epubPath: files.epubFile('bookX').path));
    await db.into(db.chapters).insert(ChaptersCompanion.insert(
        bookId: 'bookX', chapterIndex: 0, chapterId: 'chap1', title: 'The Engine'));
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  ChapterRepository repo() =>
      ChapterRepository(db: db, files: files, backend: backend);

  Future<Chapter> row() async => (await (db.select(db.chapters)
        ..where((c) => c.bookId.equals('bookX') & c.chapterIndex.equals(0)))
      .get())
      .single;

  test('downloadChapter writes bundle + audio and marks ready', () async {
    await repo().downloadChapter('bookX', 0);
    final c = await row();
    expect(c.downloadStatus, 'ready');
    expect(c.bundlePath, files.bundleFile('bookX', 0).path);
    expect(c.audioPath, files.audioFile('bookX', 0).path);
    expect(files.bundleFile('bookX', 0).existsSync(), isTrue);
    expect(files.audioFile('bookX', 0).readAsBytesSync(), [1, 2, 3, 4, 5]);
  });

  test('import failure marks error and cleans partial files', () async {
    backend.throwOnImport = Exception('nope');
    await expectLater(repo().downloadChapter('bookX', 0), throwsException);
    final c = await row();
    expect(c.downloadStatus, 'error');
    expect(files.audioFile('bookX', 0).existsSync(), isFalse);
  });

  test('empty audio body marks error, not ready', () async {
    backend.audio = const [];
    await expectLater(
        repo().downloadChapter('bookX', 0), throwsA(isA<Error>()));
    final c = await row();
    expect(c.downloadStatus, 'error');
    expect(files.audioFile('bookX', 0).existsSync(), isFalse);
  });

  test('saveProgress persists positionMs', () async {
    await repo().saveProgress('bookX', 0, 4200);
    expect((await row()).positionMs, 4200);
  });

  test('watchChapters emits chapters in order', () async {
    final chapters = await repo().watchChapters('bookX').first;
    expect(chapters.single.chapterId, 'chap1');
  });

  test('downloadChapter caches figure images', () async {
    backend.bundle = _bundleWithFigure();
    await repo().downloadChapter('bookX', 0);
    expect(backend.imageRequests, contains('chap1_b2.png'));
    expect(files.imageFile('bookX', 0, 'chap1_b2.png').existsSync(), isTrue);
  });

  test('downloadChapter still succeeds if an image download fails', () async {
    backend.bundle = _bundleWithFigure();
    backend.throwOnImage = Exception('img boom');
    await repo().downloadChapter('bookX', 0);
    final c = await row();
    expect(c.downloadStatus, 'ready'); // image failure is non-fatal
  });

  test('loadBundle round-trips the cached bundle', () async {
    backend.bundle = _bundleWithFigure();
    await repo().downloadChapter('bookX', 0);
    final loaded = await repo().loadBundle('bookX', 0);
    expect(loaded, isNotNull);
    expect(loaded!.figureMap.single.image, 'chap1_b2.png');
  });
}
