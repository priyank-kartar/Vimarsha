// app/test/core/models/toc_response_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/models/toc_response.dart';

void main() {
  test('parses /toc response shape', () {
    final toc = TocResponse.fromJson({
      'book': {'title': 'Test Book', 'author': 'Ada Lovelace'},
      'chapters': [
        {'index': 0, 'chapterId': 'chap1', 'title': 'The Engine'},
      ],
    });
    expect(toc.book.title, 'Test Book');
    expect(toc.book.author, 'Ada Lovelace');
    expect(toc.chapters, hasLength(1));
    expect(toc.chapters.single.chapterId, 'chap1');
    expect(toc.chapters.single.index, 0);
  });
}
