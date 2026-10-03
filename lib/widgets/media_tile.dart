import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../theme/app_theme.dart';

class MediaTile extends StatefulWidget {
  final MediaItem item;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const MediaTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    this.playing = false,
    this.onDelete,
  });

  @override
  State<MediaTile> createState() => _MediaTileState();
}

class _MediaTileState extends State<MediaTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final selected = widget.selected;
    final subtitle = (item.group != null && item.group!.isNotEmpty)
        ? item.group!
        : (Uri.tryParse(item.url)?.host ?? item.url);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected
              ? DP.accent.withValues(alpha: .14)
              : _hover
                  ? DP.raised
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _thumb(item),
                          if (selected)
                            ColoredBox(
                              color: Colors.black.withValues(alpha: .58),
                              child: Center(
                                child: _EqBars(active: widget.playing),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: selected ? DP.accent : DP.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: DP.muted),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onDelete != null)
                    Opacity(
                      opacity: _hover || selected ? 1 : .45,
                      child: IconButton(
                        tooltip: 'Remove from playlist',
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: DP.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb(MediaItem item) {
    final logo = item.logo;
    if (logo != null && logo.isNotEmpty) {
      return Container(
        color: DP.raised,
        child: Image.network(
          logo,
          fit: BoxFit.cover,
          cacheWidth: 120,
          errorBuilder: (_, __, ___) => _placeholder(item),
        ),
      );
    }
    return _placeholder(item);
  }

  Widget _placeholder(MediaItem item) {
    final t = item.title.trim();
    final initial = t.isEmpty ? '?' : String.fromCharCode(t.runes.first).toUpperCase();
    return Container(
      color: DP.raised,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: DP.muted,
        ),
      ),
    );
  }
}

/// Three-bar equalizer. Animates while [active], rests when paused.
class _EqBars extends StatefulWidget {
  final bool active;
  const _EqBars({required this.active});

  @override
  State<_EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<_EqBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _EqBars old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value * 2 * math.pi;
        final phases = [0.0, 1.3, 2.6];
        return SizedBox(
          height: 18,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final p in phases)
                Container(
                  width: 3.5,
                  height: 18 * (.3 + .7 * math.sin(t + p).abs()),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: DP.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
