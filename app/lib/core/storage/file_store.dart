import 'dart:io';

import 'package:path/path.dart' as p;

/// Owns the on-disk layout for cached books: the original EPUB, and per-chapter
/// bundle JSON + audio. All paths are derived from a single root directory.
class FileStore {
  FileStore(this.root);

  final Directory root;

  Directory _booksDir() => Directory(p.join(root.path, 'books'));
  Directory bookDir(String bookId) => Directory(p.join(_booksDir().path, bookId));
  Directory chapterDir(String bookId, int index) =>
      Directory(p.join(bookDir(bookId).path, 'ch$index'));

  File epubFile(String bookId) => File(p.join(bookDir(bookId).path, 'book.epub'));
  File bundleFile(String bookId, int index) =>
      File(p.join(chapterDir(bookId, index).path, 'bundle.json'));
  File audioFile(String bookId, int index) =>
      File(p.join(chapterDir(bookId, index).path, 'audio.mp3'));

  Future<Directory> ensureBookDir(String bookId) =>
      bookDir(bookId).create(recursive: true);
  Future<Directory> ensureChapterDir(String bookId, int index) =>
      chapterDir(bookId, index).create(recursive: true);

  Future<void> removeBook(String bookId) async {
    final dir = bookDir(bookId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> removeChapter(String bookId, int index) async {
    final dir = chapterDir(bookId, index);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
