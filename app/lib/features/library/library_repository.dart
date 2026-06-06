import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/backend/backend_client.dart';
import '../../core/db/database.dart';
import '../../core/storage/file_store.dart';

/// Owns the library: importing a book's table of contents and listing books.
class LibraryRepository {
  LibraryRepository({
    required AppDatabase db,
    required FileStore files,
    required BackendClient backend,
    String Function()? idGen,
  })  : _db = db,
        _files = files,
        _backend = backend,
        _idGen = idGen ?? (() => const Uuid().v4());

  final AppDatabase _db;
  final FileStore _files;
  final BackendClient _backend;
  final String Function() _idGen;

  /// Copy the picked EPUB into the store, fetch its TOC, and persist the book
  /// and its chapter rows. Returns the new book id. On backend failure, no rows
  /// are written and the copied EPUB is removed (no half-state).
  Future<String> addBook(File pickedEpub) async {
    // Precondition: _idGen yields a fresh id (UUID v4 by default). The failure
    // cleanup removes bookId's directory, which assumes this call created it.
    final bookId = _idGen();
    await _files.ensureBookDir(bookId);
    final stored = _files.epubFile(bookId);
    await pickedEpub.copy(stored.path);

    try {
      final toc = await _backend.fetchToc(stored);
      await _db.transaction(() async {
        await _db.into(_db.books).insert(BooksCompanion.insert(
              id: bookId,
              title: toc.book.title,
              author: Value(toc.book.author),
              epubPath: stored.path,
            ));
        for (final c in toc.chapters) {
          await _db.into(_db.chapters).insert(ChaptersCompanion.insert(
                bookId: bookId,
                chapterIndex: c.index,
                chapterId: c.chapterId,
                title: c.title,
              ));
        }
      });
      return bookId;
    } catch (_) {
      await _files.removeBook(bookId);
      rethrow;
    }
  }

  Stream<List<Book>> watchBooks() =>
      (_db.select(_db.books)..orderBy([(b) => OrderingTerm(expression: b.createdAt)]))
          .watch();

  Future<void> deleteBook(String bookId) async {
    await (_db.delete(_db.chapters)..where((c) => c.bookId.equals(bookId))).go();
    await (_db.delete(_db.books)..where((b) => b.id.equals(bookId))).go();
    await _files.removeBook(bookId);
  }
}
