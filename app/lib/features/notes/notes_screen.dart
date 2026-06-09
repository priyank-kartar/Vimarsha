import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_handler.dart';
import '../../core/db/database.dart';
import '../../core/providers.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  // Captured when a memo is played, so dispose() can stop it WITHOUT using `ref`
  // (ref is unusable in dispose()).
  AudioHandler? _memoAudio;

  @override
  void dispose() {
    _memoAudio?.pause();
    super.dispose();
  }

  Future<void> _openAtPin(Memo m) async {
    // Set the chapter's resume point to the memo's position, then open the player.
    await ref
        .read(chapterRepositoryProvider)
        .saveProgress(m.bookId, m.chapterIndex, m.positionMs);
    if (mounted) context.push('/player/${m.bookId}/${m.chapterIndex}');
  }

  Future<void> _play(Memo m) async {
    if (!File(m.audioPath).existsSync()) return;
    final audio = ref.read(memoAudioHandlerProvider); // separate from the chapter player
    _memoAudio = audio;
    await audio.load(m.audioPath);
    await audio.play();
  }

  @override
  Widget build(BuildContext context) {
    final memos = ref.watch(memosStreamProvider);
    final books = ref.watch(booksStreamProvider).asData?.value ?? const <Book>[];
    final titles = {for (final b in books) b.id: b.title};

    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: memos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No voice notes yet'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final m = list[i];
              final book = titles[m.bookId] ?? 'Book';
              final subtitle = '$book · Chapter ${m.chapterIndex + 1}';
              final title = switch (m.transcriptStatus) {
                'done' => m.transcript ?? '(no transcript)',
                'error' => 'Transcription failed',
                _ => 'Transcribing…',
              };
              return ListTile(
                title: Text(title),
                subtitle: Text(subtitle),
                leading: IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Play memo',
                  onPressed: () => _play(m),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (m.transcriptStatus == 'error')
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Retry transcription',
                      onPressed: () =>
                          ref.read(memoRepositoryProvider).retryTranscription(m.id),
                    ),
                  IconButton(
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Open at this spot',
                    onPressed: () => _openAtPin(m),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () =>
                        ref.read(memoRepositoryProvider).deleteMemo(m.id),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
