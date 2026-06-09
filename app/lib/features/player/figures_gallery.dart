import 'dart:io';

import 'package:flutter/material.dart';

import 'player_controller.dart';

/// Lists every figure in the chapter (independent of playback timing) — the
/// reliable way to reach any figure. Each row can jump playback to where the
/// figure is discussed.
class FiguresGallery extends StatelessWidget {
  const FiguresGallery({super.key, required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final figs = controller.bundle?.figureMap ?? const [];
    if (figs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No figures in this chapter'),
        ),
      );
    }
    return ListView.builder(
      itemCount: figs.length,
      itemBuilder: (context, i) {
        final f = figs[i];
        final imagePath = controller.imagePathFor(f);
        final hasImage = imagePath != null && File(imagePath).existsSync();
        return ListTile(
          leading: hasImage
              ? SizedBox(
                  width: 48, height: 48,
                  child: Image.file(File(imagePath), fit: BoxFit.cover))
              : const Icon(Icons.format_quote),
          title: Text(f.label ?? f.caption ?? f.kind),
          subtitle: f.label != null && f.caption != null ? Text(f.caption!) : null,
          trailing: IconButton(
            key: ValueKey('goto-${f.figureId}'),
            icon: const Icon(Icons.my_location),
            tooltip: 'Go to in audio',
            onPressed: () => controller.seekToBlock(f.startPara),
          ),
        );
      },
    );
  }
}
