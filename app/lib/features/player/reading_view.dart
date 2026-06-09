import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/models/block.dart';
import 'player_controller.dart';

/// Renders the chapter text, highlights + auto-scrolls the narrated paragraph,
/// and seeks when a paragraph is tapped. Driven by [PlayerController].
///
/// Uses [ScrollablePositionedList] so it can scroll to a paragraph by index even
/// when that paragraph hasn't been built yet (e.g. resuming deep in a chapter).
class ReadingView extends StatefulWidget {
  const ReadingView({super.key, required this.controller});

  final PlayerController controller;

  @override
  State<ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends State<ReadingView> {
  final _itemScroll = ItemScrollController();
  String? _lastScrolledTo;
  DateTime _lastUserScroll = DateTime.fromMillisecondsSinceEpoch(0);

  static const _userScrollCooldown = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  bool get _recentlyUserScrolled =>
      DateTime.now().difference(_lastUserScroll) < _userScrollCooldown;

  void _onChange() {
    final id = widget.controller.currentBlockId;
    // Don't yank the view back while the user is reading ahead.
    if (id == null || id == _lastScrolledTo || _recentlyUserScrolled) return;
    final blocks = widget.controller.bundle?.blocks ?? const <Block>[];
    final idx = blocks.indexWhere((b) => b.id == id);
    if (idx >= 0 && _itemScroll.isAttached) {
      _lastScrolledTo = id;
      _itemScroll.scrollTo(
        index: idx,
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
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification && n.dragDetails != null) {
              _lastUserScroll = DateTime.now();
            }
            return false;
          },
          child: ScrollablePositionedList.builder(
            itemScrollController: _itemScroll,
            itemCount: blocks.length,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 160),
            itemBuilder: (context, i) {
              final b = blocks[i];
              final text = b.text ?? b.caption ?? '';
              if (text.isEmpty) return const SizedBox.shrink();
              final active = b.id == activeId;
              final isQuote = b.kind == 'blockquote' || b.kind == 'pullquote';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: GestureDetector(
                  onTap: () => widget.controller.seekToBlock(b.id),
                  child: Container(
                    key: active ? const ValueKey('reading-active') : null,
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12)
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
          ),
        );
      },
    );
  }
}
