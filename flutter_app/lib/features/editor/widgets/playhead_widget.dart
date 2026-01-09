import 'package:flutter/material.dart';
import '../models/editor_models.dart' hide Clip;

/// A playhead widget for video timeline editors.
///
/// Displays a vertical red line with a triangular head indicating the current
/// playback position. Supports dragging to scrub through the timeline with
/// optional frame snapping and time tooltips.
class PlayheadWidget extends StatefulWidget {
  /// Current playhead position in timeline time.
  final EditorTime position;

  /// Scale factor for converting time to pixels.
  final double pixelsPerSecond;

  /// Current scroll offset of the timeline.
  final EditorTime scrollOffset;

  /// Total height of the timeline area.
  final double height;

  /// Whether the playhead is currently being dragged.
  final bool isDragging;

  /// Whether playback is currently active.
  final bool isPlaying;

  /// Callback when the playhead position changes during drag.
  final Function(EditorTime)? onPositionChanged;

  /// Callback when drag operation starts.
  final VoidCallback? onDragStart;

  /// Callback when drag operation ends.
  final VoidCallback? onDragEnd;

  /// Whether to snap to frame boundaries when dragging.
  final bool snapToFrames;

  /// Frame rate for snapping calculations (default 30 fps).
  final double frameRate;

  /// Width of the draggable hit area.
  final double hitAreaWidth;

  const PlayheadWidget({
    super.key,
    required this.position,
    required this.pixelsPerSecond,
    required this.scrollOffset,
    required this.height,
    this.isDragging = false,
    this.isPlaying = false,
    this.onPositionChanged,
    this.onDragStart,
    this.onDragEnd,
    this.snapToFrames = false,
    this.frameRate = 30.0,
    this.hitAreaWidth = 20.0,
  });

  @override
  State<PlayheadWidget> createState() => _PlayheadWidgetState();
}

class _PlayheadWidgetState extends State<PlayheadWidget>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _isDraggingLocal = false;
  EditorTime? _dragStartPosition;
  double? _dragStartX;

  /// Calculate the x position in pixels for the playhead.
  double get _playheadX {
    final offsetTime = widget.position - widget.scrollOffset;
    return offsetTime.inSeconds * widget.pixelsPerSecond;
  }

  /// Convert a pixel x position to EditorTime.
  EditorTime _pixelsToTime(double x) {
    final seconds = x / widget.pixelsPerSecond;
    var time = EditorTime.fromSeconds(seconds) + widget.scrollOffset;

    // Ensure time is not negative
    if (time.microseconds < 0) {
      time = const EditorTime.zero();
    }

    // Snap to frame boundaries if enabled
    if (widget.snapToFrames) {
      final frames = time.toFrames(widget.frameRate);
      time = EditorTime.fromFrames(frames, widget.frameRate);
    }

    return time;
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isDraggingLocal = true;
      _dragStartPosition = widget.position;
      _dragStartX = details.localPosition.dx;
    });
    widget.onDragStart?.call();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingLocal || _dragStartX == null) return;

    final deltaX = details.localPosition.dx - _dragStartX!;
    final newX = _playheadX + deltaX;
    final newTime = _pixelsToTime(newX);

    widget.onPositionChanged?.call(newTime);
    _dragStartX = details.localPosition.dx;
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _isDraggingLocal = false;
      _dragStartPosition = null;
      _dragStartX = null;
    });
    widget.onDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final x = _playheadX;
    final showPlayhead = x >= -_PlayheadPainter.headWidth &&
        x <= MediaQuery.of(context).size.width + _PlayheadPainter.headWidth;

    if (!showPlayhead) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: x - widget.hitAreaWidth / 2,
      top: 0,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          child: SizedBox(
            width: widget.hitAreaWidth,
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Playhead line and head
                Positioned(
                  left: widget.hitAreaWidth / 2 - _PlayheadPainter.lineWidth / 2,
                  top: 0,
                  child: CustomPaint(
                    size: Size(_PlayheadPainter.headWidth, widget.height),
                    painter: _PlayheadPainter(
                      isHovering: _isHovering || _isDraggingLocal || widget.isDragging,
                      isPlaying: widget.isPlaying,
                    ),
                  ),
                ),
                // Time tooltip during drag
                if (_isDraggingLocal || widget.isDragging)
                  Positioned(
                    left: widget.hitAreaWidth / 2 - 40,
                    top: _PlayheadPainter.headHeight + 4,
                    child: _TimeTooltip(time: widget.position),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the playhead line and triangular head.
class _PlayheadPainter extends CustomPainter {
  static const double lineWidth = 2.0;
  static const double headWidth = 14.0;
  static const double headHeight = 16.0;
  static const Color playheadColor = Color(0xFFFF4444);
  static const Color glowColor = Color(0x66FF4444);

  final bool isHovering;
  final bool isPlaying;

  _PlayheadPainter({
    this.isHovering = false,
    this.isPlaying = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lineX = headWidth / 2;

    // Draw glow/shadow effect for visibility
    if (isHovering || isPlaying) {
      final glowPaint = Paint()
        ..color = glowColor
        ..strokeWidth = lineWidth + 4
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawLine(
        Offset(lineX, headHeight),
        Offset(lineX, size.height),
        glowPaint,
      );
    }

    // Draw main line
    final linePaint = Paint()
      ..color = playheadColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(lineX, headHeight - 2),
      Offset(lineX, size.height),
      linePaint,
    );

    // Draw triangular head
    final headPath = Path()
      ..moveTo(0, 0)
      ..lineTo(headWidth, 0)
      ..lineTo(headWidth, headHeight * 0.4)
      ..lineTo(lineX, headHeight)
      ..lineTo(0, headHeight * 0.4)
      ..close();

    // Head shadow/glow
    if (isHovering || isPlaying) {
      final shadowPaint = Paint()
        ..color = glowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawPath(headPath, shadowPaint);
    }

    // Head fill
    final headFillPaint = Paint()
      ..color = playheadColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(headPath, headFillPaint);

    // Head border for definition
    final headBorderPaint = Paint()
      ..color = const Color(0xFFCC3333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(headPath, headBorderPaint);
  }

  @override
  bool shouldRepaint(_PlayheadPainter oldDelegate) {
    return oldDelegate.isHovering != isHovering ||
        oldDelegate.isPlaying != isPlaying;
  }
}

/// Tooltip showing current time during drag operations.
class _TimeTooltip extends StatelessWidget {
  final EditorTime time;

  const _TimeTooltip({required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xE6222222),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFFFF4444),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        time.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// An animated version of the playhead that smoothly animates position changes.
///
/// Use this when you need smooth playback animation rather than frame-by-frame updates.
class AnimatedPlayheadWidget extends StatefulWidget {
  /// Current playhead position in timeline time.
  final EditorTime position;

  /// Scale factor for converting time to pixels.
  final double pixelsPerSecond;

  /// Current scroll offset of the timeline.
  final EditorTime scrollOffset;

  /// Total height of the timeline area.
  final double height;

  /// Whether the playhead is currently being dragged.
  final bool isDragging;

  /// Whether playback is currently active.
  final bool isPlaying;

  /// Callback when the playhead position changes during drag.
  final Function(EditorTime)? onPositionChanged;

  /// Callback when drag operation starts.
  final VoidCallback? onDragStart;

  /// Callback when drag operation ends.
  final VoidCallback? onDragEnd;

  /// Whether to snap to frame boundaries when dragging.
  final bool snapToFrames;

  /// Frame rate for snapping calculations.
  final double frameRate;

  /// Duration of position animation.
  final Duration animationDuration;

  const AnimatedPlayheadWidget({
    super.key,
    required this.position,
    required this.pixelsPerSecond,
    required this.scrollOffset,
    required this.height,
    this.isDragging = false,
    this.isPlaying = false,
    this.onPositionChanged,
    this.onDragStart,
    this.onDragEnd,
    this.snapToFrames = false,
    this.frameRate = 30.0,
    this.animationDuration = const Duration(milliseconds: 100),
  });

  @override
  State<AnimatedPlayheadWidget> createState() => _AnimatedPlayheadWidgetState();
}

class _AnimatedPlayheadWidgetState extends State<AnimatedPlayheadWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  double _currentX = 0;
  double _targetX = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _currentX = _calculateX();
    _targetX = _currentX;
    _positionAnimation = Tween<double>(begin: _currentX, end: _currentX)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(AnimatedPlayheadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newX = _calculateX();
    if ((newX - _targetX).abs() > 0.5) {
      _targetX = newX;

      // Skip animation during drag or rapid playback
      if (widget.isDragging || (widget.isPlaying && _controller.isAnimating)) {
        _currentX = newX;
        _positionAnimation = Tween<double>(begin: newX, end: newX)
            .animate(_controller);
      } else {
        _positionAnimation = Tween<double>(begin: _currentX, end: newX)
            .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
        _controller.forward(from: 0);
      }
    }
  }

  double _calculateX() {
    final offsetTime = widget.position - widget.scrollOffset;
    return offsetTime.inSeconds * widget.pixelsPerSecond;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _positionAnimation,
      builder: (context, child) {
        _currentX = _positionAnimation.value;
        return PlayheadWidget(
          position: widget.position,
          pixelsPerSecond: widget.pixelsPerSecond,
          scrollOffset: widget.scrollOffset,
          height: widget.height,
          isDragging: widget.isDragging,
          isPlaying: widget.isPlaying,
          onPositionChanged: widget.onPositionChanged,
          onDragStart: widget.onDragStart,
          onDragEnd: widget.onDragEnd,
          snapToFrames: widget.snapToFrames,
          frameRate: widget.frameRate,
        );
      },
    );
  }
}
