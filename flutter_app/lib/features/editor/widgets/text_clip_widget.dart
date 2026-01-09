import 'package:flutter/material.dart';

import '../models/editor_models.dart';
import '../models/text_clip_models.dart';

/// Widget for displaying text clips on the timeline
class TextClipWidget extends StatefulWidget {
  /// The text clip to display
  final TextClip clip;

  /// Zoom level in pixels per second
  final double pixelsPerSecond;

  /// Whether this clip is currently selected
  final bool isSelected;

  /// Whether text editing mode is active
  final bool isEditing;

  /// Called when the clip is tapped
  final VoidCallback? onTap;

  /// Called when user wants to edit the text
  final VoidCallback? onEditText;

  /// Called during drag updates for moving the clip
  final Function(DragUpdateDetails)? onDragUpdate;

  /// Called when drag ends
  final Function(DragEndDetails)? onDragEnd;

  /// Called during resize operations
  final Function(double deltaWidth, bool fromStart)? onResize;

  /// Called when resize ends
  final VoidCallback? onResizeEnd;

  const TextClipWidget({
    super.key,
    required this.clip,
    required this.pixelsPerSecond,
    this.isSelected = false,
    this.isEditing = false,
    this.onTap,
    this.onEditText,
    this.onDragUpdate,
    this.onDragEnd,
    this.onResize,
    this.onResizeEnd,
  });

  @override
  State<TextClipWidget> createState() => _TextClipWidgetState();
}

class _TextClipWidgetState extends State<TextClipWidget>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isResizingStart = false;
  bool _isResizingEnd = false;

  late AnimationController _selectionAnimController;
  late Animation<double> _selectionGlow;

  static const double _resizeHandleWidth = 8.0;
  static const double _minClipWidth = 40.0;

  @override
  void initState() {
    super.initState();
    _selectionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _selectionGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _selectionAnimController, curve: Curves.easeInOut),
    );

    if (widget.isSelected) {
      _selectionAnimController.forward();
    }
  }

  @override
  void didUpdateWidget(TextClipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _selectionAnimController.forward();
      } else {
        _selectionAnimController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _selectionAnimController.dispose();
    super.dispose();
  }

  double get _clipWidth {
    final width = widget.clip.duration.inSeconds * widget.pixelsPerSecond;
    return width.clamp(_minClipWidth, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clipColor = const Color(0xFFAB68FF); // Purple for text clips

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: _getCursor(),
      child: AnimatedBuilder(
        animation: _selectionGlow,
        builder: (context, child) {
          return Container(
            width: _clipWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
                if (widget.isSelected)
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.4 * _selectionGlow.value),
                    blurRadius: 12 * _selectionGlow.value,
                    spreadRadius: 2 * _selectionGlow.value,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  // Main content
                  _buildClipContent(clipColor, colorScheme),

                  // Selection border
                  if (widget.isSelected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Resize handles
                  if (_isHovered) ...[
                    _buildResizeHandle(true),
                    _buildResizeHandle(false),
                  ],

                  // Drag area
                  Positioned(
                    left: _resizeHandleWidth,
                    right: _resizeHandleWidth,
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: widget.onTap,
                      onDoubleTap: widget.onEditText,
                      onPanUpdate: widget.onDragUpdate,
                      onPanEnd: widget.onDragEnd,
                      behavior: HitTestBehavior.opaque,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClipContent(Color clipColor, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            clipColor.withOpacity(0.9),
            clipColor.withOpacity(0.6),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Text preview background
          Positioned.fill(
            child: _buildTextPreview(colorScheme),
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(clipColor),
          ),

          // Animation indicator
          if (widget.clip.animation != null)
            Positioned(
              bottom: 4,
              left: 6,
              child: _buildAnimationBadge(colorScheme),
            ),

          // Duration badge
          Positioned(
            bottom: 4,
            right: 6,
            child: _buildDurationBadge(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPreview(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 22),
      child: Center(
        child: Text(
          widget.clip.text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
            fontWeight: widget.clip.style.fontWeight,
            fontStyle: widget.clip.style.italic ? FontStyle.italic : FontStyle.normal,
            shadows: const [Shadow(color: Colors.black38, blurRadius: 2)],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildHeader(Color clipColor) {
    final darkerColor = HSLColor.fromColor(clipColor)
        .withLightness((HSLColor.fromColor(clipColor).lightness * 0.6).clamp(0.0, 1.0))
        .toColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            darkerColor.withOpacity(0.9),
            darkerColor.withOpacity(0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.text_fields_rounded,
            size: 14,
            color: Colors.white.withOpacity(0.9),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.clip.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'EDIT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimationBadge(ColorScheme colorScheme) {
    final animType = widget.clip.animation!.type;
    IconData icon;
    switch (animType) {
      case TextAnimationType.fadeIn:
      case TextAnimationType.fadeOut:
      case TextAnimationType.fadeInOut:
        icon = Icons.gradient;
        break;
      case TextAnimationType.slideInLeft:
      case TextAnimationType.slideInRight:
      case TextAnimationType.slideInTop:
      case TextAnimationType.slideInBottom:
        icon = Icons.arrow_forward;
        break;
      case TextAnimationType.typewriter:
      case TextAnimationType.wordByWord:
        icon = Icons.keyboard;
        break;
      case TextAnimationType.scaleIn:
      case TextAnimationType.scaleOut:
        icon = Icons.zoom_in;
        break;
      case TextAnimationType.bounce:
        icon = Icons.sports_handball;
        break;
      case TextAnimationType.shake:
        icon = Icons.vibration;
        break;
      case TextAnimationType.none:
        icon = Icons.animation;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white.withOpacity(0.8)),
          const SizedBox(width: 2),
          Text(
            animType.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        _formatDuration(widget.clip.duration),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildResizeHandle(bool isStart) {
    return Positioned(
      left: isStart ? 0 : null,
      right: isStart ? null : 0,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          setState(() {
            if (isStart) _isResizingStart = true;
            else _isResizingEnd = true;
          });
        },
        onHorizontalDragUpdate: (details) {
          widget.onResize?.call(details.delta.dx, isStart);
        },
        onHorizontalDragEnd: (_) {
          setState(() {
            _isResizingStart = false;
            _isResizingEnd = false;
          });
          widget.onResizeEnd?.call();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _resizeHandleWidth,
          decoration: BoxDecoration(
            color: (_isResizingStart && isStart) || (_isResizingEnd && !isStart)
                ? Colors.white.withOpacity(0.4)
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.horizontal(
              left: isStart ? const Radius.circular(6) : Radius.zero,
              right: isStart ? Radius.zero : const Radius.circular(6),
            ),
          ),
          child: Center(
            child: Container(
              width: 2,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  MouseCursor _getCursor() {
    if (_isResizingStart || _isResizingEnd) {
      return SystemMouseCursors.resizeColumn;
    }
    return SystemMouseCursors.grab;
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

/// Overlay widget for editing text content directly on the preview
class TextClipOverlay extends StatelessWidget {
  final TextClip clip;
  final Size previewSize;
  final bool isSelected;
  final VoidCallback? onTap;
  final Function(Offset)? onPositionChanged;

  const TextClipOverlay({
    super.key,
    required this.clip,
    required this.previewSize,
    this.isSelected = false,
    this.onTap,
    this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final position = clip.position;

    return Positioned(
      left: position.dx * previewSize.width,
      top: position.dy * previewSize.height,
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (details) {
          final newX = (position.dx * previewSize.width + details.delta.dx) / previewSize.width;
          final newY = (position.dy * previewSize.height + details.delta.dy) / previewSize.height;
          onPositionChanged?.call(Offset(newX.clamp(0.0, 1.0), newY.clamp(0.0, 1.0)));
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: colorScheme.primary, width: 2)
                : null,
            borderRadius: BorderRadius.circular(4),
            color: isSelected ? colorScheme.primary.withOpacity(0.1) : null,
          ),
          child: _buildTextContent(),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    final style = clip.style;

    return Text(
      clip.text,
      style: TextStyle(
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
        fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
        color: style.color,
        decoration: style.underline ? TextDecoration.underline : null,
        shadows: style.shadowColor != null
            ? [
                Shadow(
                  color: style.shadowColor!,
                  offset: style.shadowOffset ?? const Offset(2, 2),
                  blurRadius: style.shadowBlur ?? 4,
                ),
              ]
            : null,
        letterSpacing: style.letterSpacing,
      ),
      textAlign: style.textAlign,
    );
  }
}
