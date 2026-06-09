import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import 'figure_overlay.dart';
import 'figures_gallery.dart';
import 'player_controller.dart';
import 'reading_view.dart';
import 'record_button.dart';

const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
}

String _speedLabel(double s) =>
    '${s.toStringAsFixed(s == s.roundToDouble() ? 1 : 2)}×';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.bookId, required this.index});

  final String bookId;
  final int index;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _loaded = false;
  String? _error;
  String _bookTitle = '';
  double? _dragMs;

  ({String bookId, int index}) get _args =>
      (bookId: widget.bookId, index: widget.index);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      String? error;
      var bookTitle = '';
      try {
        final controller = ref.read(playerControllerProvider(_args));
        final book =
            await ref.read(libraryRepositoryProvider).getBook(widget.bookId);
        bookTitle = book?.title ?? '';
        final Chapter? row = await ref
            .read(chapterRepositoryProvider)
            .getChapter(widget.bookId, widget.index);
        final path = row?.audioPath;
        if (path == null) {
          error = 'This chapter has no audio. Try downloading it again.';
        } else {
          await controller.load(path);
        }
      } catch (e) {
        error = "Couldn't play this chapter: $e";
      }
      if (mounted) {
        setState(() {
          _loaded = true;
          _error = error;
          _bookTitle = bookTitle;
        });
      }
    });
  }

  void _cycleSpeed(PlayerController c) {
    final i = _speeds.indexOf(c.speed);
    c.setSpeed(_speeds[(i + 1) % _speeds.length]);
  }

  void _openFigures(PlayerController c) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => FiguresGallery(controller: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(playerControllerProvider(_args));
    final chapterTitle = c.bundle?.title ?? '';
    final figureCount = c.bundle?.figureMap.length ?? 0;
    final maxMs = c.duration.inMilliseconds == 0 ? 1 : c.duration.inMilliseconds;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chapterTitle.isEmpty ? 'Now Playing' : chapterTitle,
                style: const TextStyle(fontSize: 16),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_bookTitle.isNotEmpty)
              Text(_bookTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          if (figureCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge(
                label: Text('$figureCount'),
                child: IconButton(
                  icon: const Icon(Icons.collections_bookmark),
                  tooltip: 'Figures',
                  onPressed: () => _openFigures(c),
                ),
              ),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : Stack(
                  children: [
                    Positioned.fill(child: ReadingView(controller: c)),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 88,
                      child: FigureOverlay(controller: c),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _Transport(
                        c: c,
                        bookId: widget.bookId,
                        index: widget.index,
                        maxMs: maxMs,
                        dragMs: _dragMs,
                        onDrag: (v) => setState(() => _dragMs = v),
                        onDragEnd: (v) {
                          c.seek(Duration(milliseconds: v.round()));
                          setState(() => _dragMs = null);
                        },
                        onCycleSpeed: () => _cycleSpeed(c),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({
    required this.c,
    required this.bookId,
    required this.index,
    required this.maxMs,
    required this.dragMs,
    required this.onDrag,
    required this.onDragEnd,
    required this.onCycleSpeed,
  });

  final PlayerController c;
  final String bookId;
  final int index;
  final int maxMs;
  final double? dragMs;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onDragEnd;
  final VoidCallback onCycleSpeed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Slider(
            value: (dragMs ?? c.position.inMilliseconds.toDouble())
                .clamp(0, maxMs.toDouble()),
            max: maxMs.toDouble(),
            onChanged: onDrag,
            onChangeEnd: onDragEnd,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_fmt(c.position)),
              Text(_fmt(c.duration)),
            ]),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              icon: const Icon(Icons.replay_10),
              iconSize: 32,
              onPressed: () => c.skip(const Duration(seconds: -15)),
            ),
            const SizedBox(width: 8),
            IconButton(
              iconSize: 48,
              icon: Icon(c.playing ? Icons.pause : Icons.play_arrow),
              onPressed: () => c.playing ? c.pause() : c.play(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.forward_10),
              iconSize: 32,
              onPressed: () => c.skip(const Duration(seconds: 15)),
            ),
            const SizedBox(width: 16),
            ActionChip(label: Text(_speedLabel(c.speed)), onPressed: onCycleSpeed),
            const SizedBox(width: 16),
            RecordButton(controller: c, bookId: bookId, index: index),
          ]),
        ]),
      ),
    );
  }
}
