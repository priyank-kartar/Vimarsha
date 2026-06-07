import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.bookId, required this.index});

  final String bookId;
  final int index;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _loaded = false;

  ({String bookId, int index}) get _args =>
      (bookId: widget.bookId, index: widget.index);

  @override
  void initState() {
    super.initState();
    // Load after first frame so the provider exists.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(playerControllerProvider(_args));
      final Chapter? row =
          await ref.read(chapterRepositoryProvider).getChapter(widget.bookId, widget.index);
      final path = row?.audioPath;
      if (path != null) await controller.load(path);
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(playerControllerProvider(_args));
    final maxMs = c.duration.inMilliseconds == 0 ? 1 : c.duration.inMilliseconds;
    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Slider(
                    value: c.position.inMilliseconds.clamp(0, maxMs).toDouble(),
                    max: maxMs.toDouble(),
                    onChanged: (v) =>
                        c.seek(Duration(milliseconds: v.round())),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(c.position)),
                      Text(_fmt(c.duration)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 48,
                        icon: Icon(c.playing ? Icons.pause : Icons.play_arrow),
                        onPressed: () => c.playing ? c.pause() : c.play(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<double>(
                    value: c.speed,
                    items: [
                      for (final s in _speeds)
                        DropdownMenuItem(
                          value: s,
                          child: Text('${s.toStringAsFixed(s == s.roundToDouble() ? 1 : 2)}×'),
                        ),
                    ],
                    onChanged: (v) => v == null ? null : c.setSpeed(v),
                  ),
                ],
              ),
            ),
    );
  }
}
