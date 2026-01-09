import 'package:flutter/material.dart';

import '../models/editor_models.dart';
import '../models/nested_sequence_models.dart';

/// Helper to get the source clip count from a sequence
int _getSourceClipCount(NestedSequence sequence) {
  if (sequence is CompoundClip) {
    return _getSourceClipCount(sequence);
  }
  // For regular NestedSequence, count all clips in inner tracks
  int count = 0;
  for (final track in sequence.innerTracks) {
    count += track.clips.length;
  }
  return count;
}

/// Visual badge indicator for nested sequences (compound clips)
class NestedSequenceBadge extends StatelessWidget {
  /// The nested sequence to display
  final NestedSequence sequence;

  /// Whether this badge is in a selected state
  final bool isSelected;

  /// Badge size (small, medium, large)
  final NestedSequenceBadgeSize size;

  /// Callback when the badge is tapped
  final VoidCallback? onTap;

  /// Callback when user wants to open the nested sequence
  final VoidCallback? onOpen;

  const NestedSequenceBadge({
    super.key,
    required this.sequence,
    this.isSelected = false,
    this.size = NestedSequenceBadgeSize.medium,
    this.onTap,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeColor = sequence.color ?? colorScheme.tertiary;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onOpen,
      child: Container(
        padding: _getPadding(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              badgeColor.withOpacity(0.9),
              badgeColor.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(size == NestedSequenceBadgeSize.small ? 4 : 6),
          border: Border.all(
            color: isSelected ? colorScheme.primary : badgeColor.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StackedIcon(
              color: Colors.white,
              size: _getIconSize(),
              clipCount: _getSourceClipCount(sequence),
            ),
            if (size != NestedSequenceBadgeSize.small) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  sequence.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _getFontSize(),
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(color: Colors.black38, blurRadius: 2),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
            if (size == NestedSequenceBadgeSize.large && onOpen != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.open_in_new,
                size: 12,
                color: Colors.white.withOpacity(0.7),
              ),
            ],
          ],
        ),
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case NestedSequenceBadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 4, vertical: 2);
      case NestedSequenceBadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 6, vertical: 4);
      case NestedSequenceBadgeSize.large:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
    }
  }

  double _getIconSize() {
    switch (size) {
      case NestedSequenceBadgeSize.small:
        return 10;
      case NestedSequenceBadgeSize.medium:
        return 14;
      case NestedSequenceBadgeSize.large:
        return 18;
    }
  }

  double _getFontSize() {
    switch (size) {
      case NestedSequenceBadgeSize.small:
        return 9;
      case NestedSequenceBadgeSize.medium:
        return 11;
      case NestedSequenceBadgeSize.large:
        return 13;
    }
  }
}

/// Sizes for the nested sequence badge
enum NestedSequenceBadgeSize { small, medium, large }

/// Custom stacked rectangles icon for nested sequences
class _StackedIcon extends StatelessWidget {
  final Color color;
  final double size;
  final int clipCount;

  const _StackedIcon({
    required this.color,
    required this.size,
    this.clipCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StackedIconPainter(
          color: color,
          clipCount: clipCount,
        ),
      ),
    );
  }
}

class _StackedIconPainter extends CustomPainter {
  final Color color;
  final int clipCount;

  _StackedIconPainter({
    required this.color,
    required this.clipCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Draw stacked rectangles to represent compound clip
    final layerCount = clipCount.clamp(2, 4);
    final offsetStep = size.width * 0.15;
    final rectWidth = size.width * 0.7;
    final rectHeight = size.height * 0.5;

    for (int i = layerCount - 1; i >= 0; i--) {
      final offset = i * offsetStep;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          offset,
          offset,
          rectWidth,
          rectHeight,
        ),
        const Radius.circular(2),
      );

      // Fill back layers, stroke all
      if (i > 0) {
        canvas.drawRRect(rect, fillPaint);
      }
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StackedIconPainter oldDelegate) {
    return color != oldDelegate.color || clipCount != oldDelegate.clipCount;
  }
}

/// Inline indicator shown on timeline clips that are part of a nested sequence
class NestedSequenceIndicator extends StatelessWidget {
  final bool isNested;
  final VoidCallback? onTap;

  const NestedSequenceIndicator({
    super.key,
    required this.isNested,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isNested) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Compound Clip',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Icon(
            Icons.layers,
            size: 10,
            color: colorScheme.onTertiaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Widget shown in the timeline representing a full nested sequence clip
class NestedSequenceClipWidget extends StatelessWidget {
  final NestedSequence sequence;
  final double pixelsPerSecond;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final Function(DragUpdateDetails)? onDragUpdate;
  final Function(DragEndDetails)? onDragEnd;

  const NestedSequenceClipWidget({
    super.key,
    required this.sequence,
    required this.pixelsPerSecond,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clipWidth = sequence.duration.inSeconds * pixelsPerSecond;
    final badgeColor = sequence.color ?? colorScheme.tertiary;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onPanUpdate: onDragUpdate,
      onPanEnd: onDragEnd,
      child: Container(
        width: clipWidth.clamp(50.0, double.infinity),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              badgeColor.withOpacity(0.9),
              badgeColor.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? colorScheme.primary : badgeColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          children: [
            // Pattern background
            Positioned.fill(
              child: CustomPaint(
                painter: _CompoundPatternPainter(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),

            // Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    _StackedIcon(
                      color: Colors.white,
                      size: 14,
                      clipCount: _getSourceClipCount(sequence),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sequence.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 2),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${_getSourceClipCount(sequence)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Duration badge
            Positioned(
              bottom: 4,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  _formatDuration(sequence.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(EditorTime duration) {
    final seconds = duration.inSeconds;
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)}s';
    }
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toStringAsFixed(0).padLeft(2, '0')}';
  }
}

/// Custom painter for compound clip background pattern
class _CompoundPatternPainter extends CustomPainter {
  final Color color;

  _CompoundPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw diagonal stripes pattern
    const spacing = 16.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CompoundPatternPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
