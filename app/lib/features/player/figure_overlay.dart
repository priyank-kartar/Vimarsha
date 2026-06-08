import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/models/figure.dart';
import 'player_controller.dart';

/// Floating card over the reading text showing the figure(s) active at the
/// current playback position. Overlapping figures stack; tap chevrons to switch.
class FigureOverlay extends StatefulWidget {
  const FigureOverlay({super.key, required this.controller});

  final PlayerController controller;

  @override
  State<FigureOverlay> createState() => _FigureOverlayState();
}

class _FigureOverlayState extends State<FigureOverlay> {
  int _selected = 0;
  String _lastKey = '';

  void _reconcile(List<Figure> figs) {
    final key = figs.map((f) => f.figureId).join(',');
    if (key != _lastKey) {
      _lastKey = key;
      _selected = 0;
    } else if (_selected >= figs.length) {
      _selected = 0;
    }
  }

  void _openFull(BuildContext context, Figure f, String? imagePath) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (imagePath != null && File(imagePath).existsSync())
              Flexible(child: InteractiveViewer(child: Image.file(File(imagePath))))
            else if (f.caption != null)
              Text(f.caption!, style: Theme.of(context).textTheme.titleMedium),
            if (f.label != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(f.label!, style: Theme.of(context).textTheme.labelLarge),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final figs = widget.controller.currentFigures;
        if (figs.isEmpty) return const SizedBox.shrink();
        _reconcile(figs);
        final f = figs[_selected];
        final imagePath = widget.controller.imagePathFor(f);
        final hasImage = imagePath != null && File(imagePath).existsSync();

        return Align(
          alignment: Alignment.bottomCenter,
          child: Card(
            margin: const EdgeInsets.all(12),
            elevation: 6,
            child: InkWell(
              onTap: () => _openFull(context, f, imagePath),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (hasImage)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: Image.file(File(imagePath), fit: BoxFit.contain),
                    )
                  else if (f.caption != null)
                    Text(f.caption!,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontStyle: FontStyle.italic)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(
                      child: Text(
                        f.label ?? (hasImage ? (f.caption ?? '') : ''),
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (figs.length > 1) Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        key: const ValueKey('figure-prev'),
                        icon: const Icon(Icons.chevron_left), iconSize: 20,
                        onPressed: () => setState(() {
                          final prev = _selected - 1;
                          _selected = prev < 0 ? figs.length - 1 : prev;
                        }),
                      ),
                      Text('${_selected + 1} / ${figs.length}'),
                      IconButton(
                        key: const ValueKey('figure-next'),
                        icon: const Icon(Icons.chevron_right), iconSize: 20,
                        onPressed: () =>
                            setState(() => _selected = (_selected + 1) % figs.length),
                      ),
                    ]),
                  ]),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
