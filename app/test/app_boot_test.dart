// Boots the full app (router) and checks it lands on the Library screen.
// booksStreamProvider is overridden so the screen doesn't depend on drift's
// .watch() emitting under fake-async.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimarsha/app.dart';
import 'package:vimarsha/core/db/database.dart';
import 'package:vimarsha/core/providers.dart';

void main() {
  testWidgets('app boots to the Library screen', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        booksStreamProvider.overrideWith((ref) => Stream.value(<Book>[])),
      ],
      child: const VimarshaApp(),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('library has a Notes button', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        booksStreamProvider.overrideWith((ref) => Stream.value(<Book>[])),
      ],
      child: const VimarshaApp(),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
  });
}
