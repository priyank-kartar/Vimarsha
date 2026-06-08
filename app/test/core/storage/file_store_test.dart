// app/test/core/storage/file_store_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/storage/file_store.dart';

void main() {
  late Directory tmp;
  late FileStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vimarsha_fs');
    store = FileStore(tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('paths are namespaced by book id and chapter index', () {
    expect(store.epubFile('bookA').path,
        '${tmp.path}/books/bookA/book.epub');
    expect(store.bundleFile('bookA', 2).path,
        '${tmp.path}/books/bookA/ch2/bundle.json');
    expect(store.audioFile('bookA', 2).path,
        '${tmp.path}/books/bookA/ch2/audio.mp3');
  });

  test('ensureChapterDir creates the chapter directory', () async {
    final dir = await store.ensureChapterDir('bookA', 1);
    expect(dir.existsSync(), isTrue);
    expect(dir.path, '${tmp.path}/books/bookA/ch1');
  });

  test('removeBook deletes the whole book directory', () async {
    await store.ensureChapterDir('bookA', 0);
    await store.removeBook('bookA');
    expect(Directory('${tmp.path}/books/bookA').existsSync(), isFalse);
  });

  test('rejects book ids that attempt path traversal', () {
    // All path-deriving methods route through bookDir -> _safeId.
    expect(() => store.bookDir('../evil'), throwsArgumentError);
    expect(() => store.epubFile('a/b'), throwsArgumentError);
    expect(() => store.chapterDir(r'a\b', 0), throwsArgumentError);
  });

  test('image files live under the chapter images dir', () {
    expect(store.imageFile('bookA', 2, 'chap1_b2.png').path,
        '${tmp.path}/books/bookA/ch2/images/chap1_b2.png');
  });

  test('rejects image names that attempt path traversal', () {
    expect(() => store.imageFile('bookA', 0, '../evil.png'), throwsArgumentError);
    expect(() => store.imageFile('bookA', 0, 'a/b.png'), throwsArgumentError);
  });
}
