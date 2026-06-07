// Widget test for LibraryScreen. Drives the screen with a controlled stream
// (drift's .watch() doesn't emit under flutter_test's fake-async clock — the
// repository<->drift integration is covered by repository tests instead).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';
import 'package:vimarsha/features/library/library_screen.dart';

Book _book() => Book(
      id: 'b1',
      title: 'The Culture Code',
      author: 'Daniel Coyle',
      epubPath: 'x',
      createdAt: DateTime(2020, 1, 1),
    );

Future<void> _pump(WidgetTester tester, List<Book> books) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      booksStreamProvider.overrideWith((ref) => Stream.value(books)),
    ],
    child: const MaterialApp(home: LibraryScreen()),
  ));
  await tester.pump(); // deliver the stream value
  await tester.pump(); // render the data state
}

void main() {
  testWidgets('shows empty state when no books', (tester) async {
    await _pump(tester, const []);
    expect(find.text('No books yet'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('lists books with title and author', (tester) async {
    await _pump(tester, [_book()]);
    expect(find.text('The Culture Code'), findsOneWidget);
    expect(find.text('Daniel Coyle'), findsOneWidget);
  });
}
