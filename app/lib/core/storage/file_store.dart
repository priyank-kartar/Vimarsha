import 'dart:io';

import 'package:path/path.dart' as p;

/// Owns the on-disk layout for cached books: the original EPUB, and per-chapter
/// bundle JSON + audio. All paths are derived from a single root directory.
class FileStore {
  FileStore(this.root);

  final Directory root;

  /// Reject ids that could escape the store root via path traversal. `bookId`
  /// is a server-generated UUID in normal use, but this primitive owns a
  /// recursive delete, so we never trust the caller blindly.
  static String _safeId(String bookId) {
    if (bookId.isEmpty ||
        bookId.contains('/') ||
        bookId.contains(r'\') ||
        bookId.contains('..')) {
      throw ArgumentError.value(bookId, 'bookId', 'invalid book id');
    }
    return bookId;
  }

  /// Reject a file name (server-supplied) that isn't a plain basename, so a
  /// crafted image name can't escape the chapter's images directory.
  static String _safeName(String name) {
    if (name.isEmpty || name.contains('/') || name.contains(r'\') ||
        name.contains('..') || p.basename(name) != name) {
      throw ArgumentError.value(name, 'name', 'invalid file name');
    }
    return name;
  }

  Directory _booksDir() => Directory(p.join(root.path, 'books'));
  Directory bookDir(String bookId) =>
      Directory(p.join(_booksDir().path, _safeId(bookId)));
  Directory chapterDir(String bookId, int index) =>
      Directory(p.join(bookDir(bookId).path, 'ch$index'));

  File epubFile(String bookId) => File(p.join(bookDir(bookId).path, 'book.epub'));
  File bundleFile(String bookId, int index) =>
      File(p.join(chapterDir(bookId, index).path, 'bundle.json'));
  File audioFile(String bookId, int index) =>
      File(p.join(chapterDir(bookId, index).path, 'audio.mp3'));

  Directory imagesDir(String bookId, int index) =>
      Directory(p.join(chapterDir(bookId, index).path, 'images'));
  File imageFile(String bookId, int index, String name) =>
      File(p.join(imagesDir(bookId, index).path, _safeName(name)));

  Future<Directory> ensureImagesDir(String bookId, int index) =>
      imagesDir(bookId, index).create(recursive: true);

  Directory memosDir() => Directory(p.join(root.path, 'memos'));
  File memoFile(String memoId) =>
      File(p.join(memosDir().path, '${_safeName(memoId)}.m4a'));
  Future<Directory> ensureMemosDir() => memosDir().create(recursive: true);

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

  Directory _recDir() => Directory(p.join(root.path, 'rec'));
  Future<File> newRecordingFile() async {
    _recDir().createSync(recursive: true);
    return File(p.join(_recDir().path, 'rec_${DateTime.now().microsecondsSinceEpoch}.m4a'));
  }
}
