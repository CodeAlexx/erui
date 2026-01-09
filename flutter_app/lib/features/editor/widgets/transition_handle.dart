import 'package:flutter/material.dart';

import '../models/editor_models.dart';
import '../models/transition_models.dart';

/// Diamond-shaped draggable widget for adding transitions between clips.
///
/// Appears between adjacent clips on the timeline when hovering
/// or when a transition is already applied.
class TransitionHandle extends StatefulWidget {
  /// Position between clips (in pixels from left)
  final double position;

  /// Existing transition (null if no transition)
  final Transition? transition;

  /// Whether the handle is currently visible
  final bool isVisible;

  /// Whether the handle is currently being hovered
  final bool isHovered;

  /// Called when the handle is tapped to add/edit a transition
  final VoidCallback? onTap;

  /// Called when the handle is double-tapped to remove transition
  final VoidCallback? onDoubleTap;

  /// Called when the transition duration is changed by dragging
  final ValueChanged<EditorTime>? onDurationChanged;

  /// Size of the handle
  final double size;

  const TransitionHandle({
    super.key,
    required this.position,
    this.transition,
    this.isVisible = true,
    this.isHovered = false,
    this.onTap,
    this.onDoubleTap,
    this.onDurationChanged,
    this.size = 20,
  });

  @override
  State<TransitionHandle> createState() => _TransitionHandleState();
}

class _TransitionHandleState extends State<TransitionHandle>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    if (widget.isVisible || widget.transition != null) {
      _animController.forward();
    }
  }

  @override
  void didUpdateWidget(TransitionHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.isVisible || widget.transition != null) !=
        (oldWidget.isVisible || oldWidget.transition != null)) {
      if (widget.isVisible || widget.transition != null) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasTransition = widget.transition != null;

    return Positioned(
      left: widget.position - widget.size / 2,
      top: 0,
      bottom: 0,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Opacity(
            opacity: hasTransition ? 1.0 : _opacityAnimation.value,
            child: Transform.scale(
              scale: hasTransition ? 1.0 : _scaleAnimation.value,
              child: child,
            ),
          );
        },
        child: Center(
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: GestureDetector(
              onTap: widget.onTap,
              onDoubleTap: widget.onDoubleTap,
              child: Tooltip(
                message: hasTransition
                    ? '${widget.transition!.displayName} - Double-click to remove'
                    : 'Add transition',
                child: _TransitionDiamond(
                  size: widget.size,
                  hasTransition: hasTransition,
                  transitionType: widget.transition?.type,
                  isHovered: _isHovering || widget.isHovered,
                  primaryColor: colorScheme.primary,
                  secondaryColor: colorScheme.secondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Diamond-shaped visual indicator for transitions
class _TransitionDiamond extends StatelessWidget {
  final double size;
  final bool hasTransition;
  final TransitionType? transitionType;
  final bool isHovered;
  final Color primaryColor;
  final Color secondaryColor;

  const _TransitionDiamond({
    required this.size,
    required this.hasTransition,
    this.transitionType,
    required this.isHovered,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DiamondPainter(
          hasTransition: hasTransition,
          transitionType: transitionType,
          isHovered: isHovered,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
        ),
        child: hasTransition
            ? Center(
                child: Icon(
                  _getTransitionIcon(transitionType!),
                  size: size * 0.5,
                  color: Colors.white,
                ),
              )
            : null,
      ),
    );
  }

  IconData _getTransitionIcon(TransitionType type) {
    switch (type) {
      case TransitionType.crossDissolve:
        return Icons.blur_on;
      case TransitionType.fade:
        return Icons.gradient;
      case TransitionType.wipe:
        return Icons.swipe;
      case TransitionType.slideLeft:
        return Icons.arrow_back;
      case TransitionType.slideRight:
        return Icons.arrow_forward;
      case TransitionType.dissolve:
        return Icons.auto_awesome;
    }
  }
}

/// Custom painter for the diamond shape
class _DiamondPainter extends CustomPainter {
  final bool hasTransition;
  final TransitionType? transitionType;
  final bool isHovered;
  final Color primaryColor;
  final Color secondaryColor;

  _DiamondPainter({
    required this.hasTransition,
    this.transitionType,
    required this.isHovered,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Create diamond path
    final path = Path()
      ..moveTo(center.dx, center.dy - radius) // Top
      ..lineTo(center.dx + radius, center.dy) // Right
      ..lineTo(center.dx, center.dy + radius) // Bottom
      ..lineTo(center.dx - radius, center.dy) // Left
      ..close();

    // Draw shadow
    if (hasTransition || isHovered) {
      canvas.drawPath(
        path.shift(const Offset(1, 2)),
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Draw fill
    if (hasTransition) {
      // Gradient fill for active transition
      final gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, secondaryColor],
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCenter(
            center: center,
            width: size.width,
            height: size.height,
          ),
        );

      canvas.drawPath(path, paint);
    } else {
      // Outline only for potential transition
      canvas.drawPath(
        path,
        Paint()
          ..color = isHovered
              ? primaryColor.withOpacity(0.3)
              : primaryColor.withOpacity(0.1)
          ..style = PaintingStyle.fill,
      );
    }

    // Draw border
    canvas.drawPath(
      path,
      Paint()
        ..color = hasTransition
            ? Colors.white.withOpacity(0.5)
            : (isHovered ? primaryColor : primaryColor.withOpacity(0.5))
        ..style = PaintingStyle.stroke
        ..strokeWidth = hasTransition ? 1.5 : 1,
    );

    // Draw plus icon if no transition and hovering
    if (!hasTransition && isHovered) {
      final iconPaint = Paint()
        ..color = primaryColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      final iconSize = radius * 0.4;
      canvas.drawLine(
        Offset(center.dx - iconSize, center.dy),
        Offset(center.dx + iconSize, center.dy),
        iconPaint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - iconSize),
        Offset(center.dx, center.dy + iconSize),
        iconPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiamondPainter oldDelegate) {
    return hasTransition != oldDelegate.hasTransition ||
        transitionType != oldDelegate.transitionType ||
        isHovered != oldDelegate.isHovered ||
        primaryColor != oldDelegate.primaryColor ||
        secondaryColor != oldDelegate.secondaryColor;
  }
}

/// Container widget that shows transition handles between clips
class TransitionHandlesOverlay extends StatelessWidget {
  /// List of clips on the track (sorted by start time)
  final List<EditorClip> clips;

  /// Map of transitions by their start clip ID
  final Map<EditorId, Transition> transitions;

  /// Pixels per second (zoom level)
  final double pixelsPerSecond;

  /// Scroll offset
  final EditorTime scrollOffset;

  /// Called when a transition handle is tapped
  final void Function(EditorId startClipId, EditorId endClipId)? onAddTransition;

  /// Called when a transition should be removed
  final void Function(EditorId transitionId)? onRemoveTransition;

  /// Called when a transition duration is changed
  final void Function(EditorId transitionId, EditorTime newDuration)?
      onTransitionDurationChanged;

  const TransitionHandlesOverlay({
    super.key,
    required this.clips,
    required this.transitions,
    required this.pixelsPerSecond,
    required this.scrollOffset,
    this.onAddTransition,
    this.onRemoveTransition,
    this.onTransitionDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (clips.length < 2) return const SizedBox.shrink();

    // Find adjacent clip pairs
    final sortedClips = List<EditorClip>.from(clips)
      ..sort((a, b) =>
          a.timelineStart.microseconds.compareTo(b.timelineStart.microseconds));

    final handles = <Widget>[];

    for (int i = 0; i < sortedClips.length - 1; i++) {
      final clip1 = sortedClips[i];
      final clip2 = sortedClips[i + 1];

      // Check if clips are adjacent (within a small tolerance)
      final gap = clip2.timelineStart.microseconds -
          clip1.timelineEnd.microseconds;
      const tolerance = 100000; // 100ms tolerance

      if (gap.abs() <= tolerance) {
        // Clips are adjacent - show transition handle
        final handlePosition =
            (clip1.timelineEnd.inSeconds - scrollOffset.inSeconds) *
                pixelsPerSecond;

        final existingTransition = transitions[clip1.id];

        handles.add(
          TransitionHandle(
            key: ValueKey('transition_${clip1.id}_${clip2.id}'),
            position: handlePosition,
            transition: existingTransition,
            isVisible: true,
            onTap: () {
              if (existingTransition != null) {
                // Edit existing transition
                onAddTransition?.call(clip1.id, clip2.id);
              } else {
                // Add new transition
                onAddTransition?.call(clip1.id, clip2.id);
              }
            },
            onDoubleTap: existingTransition != null
                ? () => onRemoveTransition?.call(existingTransition.id)
                : null,
            onDurationChanged: existingTransition != null
                ? (duration) => onTransitionDurationChanged?.call(
                      existingTransition.id,
                      duration,
                    )
                : null,
          ),
        );
      }
    }

    return Stack(children: handles);
  }
}
