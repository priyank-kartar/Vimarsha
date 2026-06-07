import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

class BookScreen extends ConsumerWidget {
  const BookScreen({super.key, required this.bookId});

  final String bookId;

  Widget _trailing(BuildContext context, WidgetRef ref, Chapter c) {
    switch (c.downloadStatus) {
      case 'ready':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'downloading':
        return const SizedBox(
          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
      case 'error':
        return IconButton(
          icon: const Icon(Icons.error, color: Colors.red),
          onPressed: () =>
              ref.read(chapterRepositoryProvider).downloadChapter(bookId, c.chapterIndex),
        );
      default:
        return IconButton(
          icon: const Icon(Icons.download),
          onPressed: () =>
              ref.read(chapterRepositoryProvider).downloadChapter(bookId, c.chapterIndex),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(chaptersStreamProvider(bookId));
    return Scaffold(
      appBar: AppBar(title: const Text('Chapters')),
      body: chapters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) {
            final c = list[i];
            final ready = c.downloadStatus == 'ready';
            return ListTile(
              title: Text(c.title),
              trailing: _trailing(context, ref, c),
              enabled: ready,
              onTap: ready
                  ? () => context.go('/player/$bookId/${c.chapterIndex}')
                  : null,
            );
          },
        ),
      ),
    );
  }
}
