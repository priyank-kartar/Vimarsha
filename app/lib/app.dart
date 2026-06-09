import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/book/book_screen.dart';
import 'features/library/library_screen.dart';
import 'features/notes/notes_screen.dart';
import 'features/player/player_screen.dart';

GoRouter _buildRouter() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, _) => const LibraryScreen()),
        GoRoute(
          path: '/book/:id',
          builder: (_, s) => BookScreen(bookId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/player/:bookId/:index',
          builder: (_, s) => PlayerScreen(
            bookId: s.pathParameters['bookId']!,
            index: int.parse(s.pathParameters['index']!),
          ),
        ),
        GoRoute(path: '/notes', builder: (_, s) => const NotesScreen()),
      ],
    );

class VimarshaApp extends ConsumerStatefulWidget {
  const VimarshaApp({super.key});

  @override
  ConsumerState<VimarshaApp> createState() => _VimarshaAppState();
}

class _VimarshaAppState extends ConsumerState<VimarshaApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Vimarsha',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      routerConfig: _router,
    );
  }
}
