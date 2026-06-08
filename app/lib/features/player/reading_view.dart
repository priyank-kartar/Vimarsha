import 'package:flutter/material.dart';

import '../../core/models/block.dart';
import 'player_controller.dart';

/// Renders the chapter text, highlights + auto-scrolls the narrated paragraph,
/// and seeks when a paragraph is tapped. Driven by [PlayerController].
class ReadingView extends StatefulWidget {
  const ReadingView({super.key, required this.controller});

  final PlayerController controller;

  @override
  State<ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends State<ReadingView> {
  final _scrollCtrl = ScrollController();
  final _itemKeys = <String, GlobalKey>{};
  String? _lastScrolledTo;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onChange() {
    final id = widget.controller.currentBlockId;
    if (id == null || id == _lastScrolledTo) return;
    final key = _itemKeys[id];
    if (key?.currentContext != null) {
      _lastScrolledTo = id;
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        alignment: 0.3,
      );
    }
  }

  TextStyle? _styleFor(Block b, BuildContext context) {
    final t = Theme.of(context).textTheme;
    switch (b.kind) {
      case 'heading':
        return (b.level ?? 1) <= 1 ? t.headlineSmall : t.titleLarge;
      case 'blockquote':
      case 'pullquote':
        return t.titleMedium?.copyWith(fontStyle: FontStyle.italic);
      default:
        return t.bodyLarge?.copyWith(height: 1.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final blocks = widget.controller.bundle?.blocks ?? const <Block>[];
        final activeId = widget.controller.currentBlockId;
        // Rebuild key map for current block set.
        for (final b in blocks) {
          _itemKeys.putIfAbsent(b.id, () => GlobalKey());
        }
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 160),
          itemCount: blocks.length,
          itemBuilder: (context, i) {
            final b = blocks[i];
            final text = b.text ?? b.caption ?? '';
            if (text.isEmpty) return const SizedBox.shrink();
            final active = b.id == activeId;
            final isQuote = b.kind == 'blockquote' || b.kind == 'pullquote';
            return Padding(
              key: _itemKeys[b.id],
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: GestureDetector(
                onTap: () => widget.controller.seekToBlock(b.id),
                child: Container(
                  key: active ? const ValueKey('reading-active') : null,
                  decoration: BoxDecoration(
                    color: active
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                        : null,
                    border: isQuote
                        ? Border(
                            left: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3))
                        : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: EdgeInsets.fromLTRB(isQuote ? 12 : 6, 6, 6, 6),
                  child: Text(text, style: _styleFor(b, context)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
