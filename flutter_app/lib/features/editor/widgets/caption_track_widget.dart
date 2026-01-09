import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart' hide Clip;
import '../models/caption_models.dart';
import '../providers/caption_provider.dart';
import '../providers/editor_provider.dart';

/// Widget for displaying captions on the timeline.
///
/// Features:
/// - Caption blocks visualization
/// - Drag to reposition
/// - Resize handles for timing
/// - Multi-select support
class CaptionTrackWidget extends ConsumerWidget {
  final CaptionTrack track;
  final double pixelsPerSecond;
  final double height;

  const CaptionTrackWidget({
    super.key,
    required this.track,
    required this.pixelsPerSecond,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedIds = ref.watch(captionProvider).selectedCaptionIds;
    final currentTime = ref.watch(playheadPositionProvider);

    if (!track.isVisible) {
      return SizedBox(height: height);
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Track background grid lines would go here

          // Caption blocks
          ...track.captions.map((caption) {
            final left = caption.startTime.inSeconds * pixelsPerSecond;
            final width = caption.duration.inSeconds * pixelsPerSecond;
            final isSelected = selectedIds.contains(caption.id);
            final isActive = caption.isActiveAt(currentTime);

            return Positioned(
              left: left,
              top: 2,
              child: _CaptionBlock(
                caption: caption,
                width: width.clamp(20.0, double.infinity),
                height: height - 4,
                isSelected: isSelected,
                isActive: isActive,
                isLocked: track.isLocked,
                pixelsPerSecond: pixelsPerSecond,
                onTap: () {
                  ref.read(captionProvider.notifier).selectCaptions({caption.id});
                },
                onMove: track.isLocked
                    ? null
                    : (delta) {
                        final deltaTime = EditorTime.fromSeconds(delta / pixelsPerSecond);
                        ref.read(captionProvider.notifier).updateCaption(
                          caption.copyWith(
                            startTime: EditorTime(caption.startTime.microseconds + deltaTime.microseconds),
                            endTime: EditorTime(caption.endTime.microseconds + deltaTime.microseconds),
                          ),
                        );
                      },
                onResizeStart: track.isLocked
                    ? null
                    : (delta) {
                        final deltaTime = EditorTime.fromSeconds(delta / pixelsPerSecond);
                        final newStart = EditorTime(caption.startTime.microseconds + deltaTime.microseconds);
                        if (newStart < caption.endTime) {
                          ref.read(captionProvider.notifier).updateCaption(
                            caption.copyWith(startTime: newStart),
                          );
                        }
                      },
                onResizeEnd: track.isLocked
                    ? null
                    : (delta) {
                        final deltaTime = EditorTime.fromSeconds(delta / pixelsPerSecond);
                        final newEnd = EditorTime(caption.endTime.microseconds + deltaTime.microseconds);
                        if (newEnd > caption.startTime) {
                          ref.read(captionProvider.notifier).updateCaption(
                            caption.copyWith(endTime: newEnd),
                          );
                        }
                      },
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Individual caption block on timeline
class _CaptionBlock extends StatefulWidget {
  final Caption caption;
  final double width;
  final double height;
  final bool isSelected;
  final bool isActive;
  final bool isLocked;
  final double pixelsPerSecond;
  final VoidCallback onTap;
  final void Function(double delta)? onMove;
  final void Function(double delta)? onResizeStart;
  final void Function(double delta)? onResizeEnd;

  const _CaptionBlock({
    required this.caption,
    required this.width,
    required this.height,
    required this.isSelected,
    required this.isActive,
    required this.isLocked,
    required this.pixelsPerSecond,
    required this.onTap,
    this.onMove,
    this.onResizeStart,
    this.onResizeEnd,
  });

  @override
  State<_CaptionBlock> createState() => _CaptionBlockState();
}

class _CaptionBlockState extends State<_CaptionBlock> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: widget.isLocked ? MouseCursor.defer : SystemMouseCursors.move,
      child: GestureDetector(
        onTap: widget.onTap,
        onHorizontalDragStart: widget.onMove != null
            ? (_) => setState(() => _isDragging = true)
            : null,
        onHorizontalDragUpdate: widget.onMove != null
            ? (details) => widget.onMove!(details.delta.dx)
            : null,
        onHorizontalDragEnd: widget.onMove != null
            ? (_) => setState(() => _isDragging = false)
            : null,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.isActive
                ? colorScheme.primary.withOpacity(0.8)
                : widget.isSelected
                    ? colorScheme.primaryContainer
                    : colorScheme.tertiaryContainer.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.isSelected
                  ? colorScheme.primary
                  : widget.isActive
                      ? colorScheme.primary
                      : colorScheme.outline.withOpacity(0.3),
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: _isDragging
                ? [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Caption text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  widget.caption.text,
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isActive
                        ? colorScheme.onPrimary
                        : colorScheme.onTertiaryContainer,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 2,
                ),
              ),

              // Resize handles
              if (_isHovering && !widget.isLocked) ...[
                // Left handle
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _ResizeHandle(
                    isLeft: true,
                    onDrag: widget.onResizeStart,
                  ),
                ),

                // Right handle
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _ResizeHandle(
                    isLeft: false,
                    onDrag: widget.onResizeEnd,
                  ),
                ),
              ],

              // Lock indicator
              if (widget.isLocked)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Icon(
                    Icons.lock,
                    size: 10,
                    color: colorScheme.onTertiaryContainer.withOpacity(0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resize handle for caption blocks
class _ResizeHandle extends StatelessWidget {
  final bool isLeft;
  final void Function(double delta)? onDrag;

  const _ResizeHandle({
    required this.isLeft,
    this.onDrag,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) => onDrag?.call(details.delta.dx),
        child: Container(
          width: 6,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.5),
            borderRadius: BorderRadius.only(
              topLeft: isLeft ? const Radius.circular(4) : Radius.zero,
              bottomLeft: isLeft ? const Radius.circular(4) : Radius.zero,
              topRight: !isLeft ? const Radius.circular(4) : Radius.zero,
              bottomRight: !isLeft ? const Radius.circular(4) : Radius.zero,
            ),
          ),
        ),
      ),
    );
  }
}

/// Caption overlay widget for preview
class CaptionOverlay extends ConsumerWidget {
  final Size videoSize;

  const CaptionOverlay({
    super.key,
    required this.videoSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showInPreview = ref.watch(captionVisibilityProvider);
    if (!showInPreview) return const SizedBox.shrink();

    final currentTime = ref.watch(playheadPositionProvider);
    final caption = ref.watch(currentCaptionProvider(currentTime));
    final activeTrack = ref.watch(activeCaptionTrackProvider);

    if (caption == null || activeTrack == null) return const SizedBox.shrink();

    final style = caption.style ?? activeTrack.style;
    final position = caption.position ?? activeTrack.position;

    return Positioned(
      left: videoSize.width * position.marginHorizontal,
      right: videoSize.width * position.marginHorizontal,
      bottom: position.vertical > 0.5
          ? videoSize.height * (1 - position.vertical)
          : null,
      top: position.vertical <= 0.5 ? videoSize.height * position.vertical : null,
      child: _CaptionText(
        text: caption.text,
        style: style,
        alignment: position.horizontal,
      ),
    );
  }
}

/// Caption text rendering
class _CaptionText extends StatelessWidget {
  final String text;
  final CaptionStyle style;
  final CaptionAlignment alignment;

  const _CaptionText({
    required this.text,
    required this.style,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    TextAlign textAlign;
    switch (alignment) {
      case CaptionAlignment.left:
        textAlign = TextAlign.left;
        break;
      case CaptionAlignment.center:
        textAlign = TextAlign.center;
        break;
      case CaptionAlignment.right:
        textAlign = TextAlign.right;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: style.backgroundColor != null
          ? BoxDecoration(
              color: style.backgroundColor!.withOpacity(style.backgroundOpacity),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontFamily: style.fontFamily,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
          decoration: style.underline ? TextDecoration.underline : null,
          color: style.textColor,
          shadows: style.outlineWidth > 0
              ? [
                  Shadow(
                    color: style.outlineColor ?? Colors.black,
                    blurRadius: style.outlineWidth,
                    offset: const Offset(1, 1),
                  ),
                  Shadow(
                    color: style.outlineColor ?? Colors.black,
                    blurRadius: style.outlineWidth,
                    offset: const Offset(-1, -1),
                  ),
                  Shadow(
                    color: style.outlineColor ?? Colors.black,
                    blurRadius: style.outlineWidth,
                    offset: const Offset(1, -1),
                  ),
                  Shadow(
                    color: style.outlineColor ?? Colors.black,
                    blurRadius: style.outlineWidth,
                    offset: const Offset(-1, 1),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
