import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/editor_models.dart';

/// A time ruler widget for video editor timeline.
///
/// Displays time markers (frames, seconds, minutes) with adaptive density
/// based on zoom level. Supports click-to-seek and drag-to-scrub functionality.
class TimeRuler extends StatefulWidget {
  /// Zoom level in pixels per second.
  final double pixelsPerSecond;

  /// Total timeline duration.
  final EditorTime duration;

  /// Current scroll offset.
  final EditorTime scrollOffset;

  /// Current playhead position.
  final EditorTime playheadPosition;

  /// In point marker (optional).
  final EditorTime? inPoint;

  /// Out point marker (optional).
  final EditorTime? outPoint;

  /// Frame rate for frame display.
  final double frameRate;

  /// Callback when playhead position changes via interaction.
  final ValueChanged<EditorTime>? onPlayheadChanged;

  /// Callback when in point is set (e.g., via context menu or key).
  final ValueChanged<EditorTime>? onInPointSet;

  /// Callback when out point is set.
  final ValueChanged<EditorTime>? onOutPointSet;

  /// Height of the ruler widget.
  final double height;

  const TimeRuler({
    super.key,
    required this.pixelsPerSecond,
    required this.duration,
    required this.scrollOffset,
    required this.playheadPosition,
    this.inPoint,
    this.outPoint,
    this.frameRate = 30.0,
    this.onPlayheadChanged,
    this.onInPointSet,
    this.onOutPointSet,
    this.height = 30.0,
  });

  @override
  State<TimeRuler> createState() => _TimeRulerState();
}

class _TimeRulerState extends State<TimeRuler> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapDown: (details) => _handleTap(details, constraints.maxWidth),
            onHorizontalDragStart: (details) {
              _isDragging = true;
              _handleDrag(details.localPosition.dx, constraints.maxWidth);
            },
            onHorizontalDragUpdate: (details) {
              if (_isDragging) {
                _handleDrag(details.localPosition.dx, constraints.maxWidth);
              }
            },
            onHorizontalDragEnd: (_) => _isDragging = false,
            onHorizontalDragCancel: () => _isDragging = false,
            child: ClipRect(
              child: CustomPaint(
                size: Size(constraints.maxWidth, widget.height),
                painter: _TimeRulerPainter(
                  pixelsPerSecond: widget.pixelsPerSecond,
                  duration: widget.duration,
                  scrollOffset: widget.scrollOffset,
                  playheadPosition: widget.playheadPosition,
                  inPoint: widget.inPoint,
                  outPoint: widget.outPoint,
                  frameRate: widget.frameRate,
                  colorScheme: Theme.of(context).colorScheme,
                  textStyle: Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 10),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleTap(TapDownDetails details, double width) {
    final time = _positionToTime(details.localPosition.dx, width);
    widget.onPlayheadChanged?.call(time);
  }

  void _handleDrag(double x, double width) {
    final time = _positionToTime(x, width);
    widget.onPlayheadChanged?.call(time);
  }

  EditorTime _positionToTime(double x, double width) {
    final scrollOffsetSeconds = widget.scrollOffset.inSeconds;
    final seconds = scrollOffsetSeconds + (x / widget.pixelsPerSecond);
    final clampedSeconds = seconds.clamp(0.0, widget.duration.inSeconds);
    return EditorTime.fromSeconds(clampedSeconds);
  }
}

/// Custom painter for the time ruler.
class _TimeRulerPainter extends CustomPainter {
  final double pixelsPerSecond;
  final EditorTime duration;
  final EditorTime scrollOffset;
  final EditorTime playheadPosition;
  final EditorTime? inPoint;
  final EditorTime? outPoint;
  final double frameRate;
  final ColorScheme colorScheme;
  final TextStyle textStyle;

  _TimeRulerPainter({
    required this.pixelsPerSecond,
    required this.duration,
    required this.scrollOffset,
    required this.playheadPosition,
    this.inPoint,
    this.outPoint,
    required this.frameRate,
    required this.colorScheme,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawInOutRegion(canvas, size);
    _drawMarkers(canvas, size);
    _drawInOutPoints(canvas, size);
    _drawPlayhead(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorScheme.surfaceContainerHighest
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Bottom border
    final borderPaint = Paint()
      ..color = colorScheme.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      borderPaint,
    );
  }

  void _drawInOutRegion(Canvas canvas, Size size) {
    if (inPoint == null || outPoint == null) return;

    final inX = _timeToPosition(inPoint!, size.width);
    final outX = _timeToPosition(outPoint!, size.width);

    if (outX <= 0 || inX >= size.width) return;

    final clampedInX = math.max(0.0, inX);
    final clampedOutX = math.min(size.width, outX);

    final paint = Paint()
      ..color = colorScheme.primaryContainer.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTRB(clampedInX, 0, clampedOutX, size.height),
      paint,
    );
  }

  void _drawMarkers(Canvas canvas, Size size) {
    final markerConfig = _calculateMarkerConfig();
    final scrollSeconds = scrollOffset.inSeconds;
    final visibleSeconds = size.width / pixelsPerSecond;
    final endSeconds = math.min(
      scrollSeconds + visibleSeconds + markerConfig.majorInterval,
      duration.inSeconds,
    );

    // Calculate starting point aligned to major interval
    final startSeconds = (scrollSeconds / markerConfig.majorInterval).floor() *
        markerConfig.majorInterval;

    final majorPaint = Paint()
      ..color = colorScheme.onSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final minorPaint = Paint()
      ..color = colorScheme.onSurfaceVariant.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final labelColor = colorScheme.onSurface;

    // Draw markers
    double time = startSeconds;
    while (time <= endSeconds) {
      final x = _timeToPosition(EditorTime.fromSeconds(time), size.width);

      if (x >= -50 && x <= size.width + 50) {
        // Check if this is a major marker
        final isMajor = _isMajorMarker(time, markerConfig.majorInterval);

        if (isMajor) {
          // Draw major marker
          canvas.drawLine(
            Offset(x, size.height - 12),
            Offset(x, size.height),
            majorPaint,
          );

          // Draw label
          final label = _formatTime(time, markerConfig.showFrames);
          _drawLabel(canvas, label, x, size.height - 14, labelColor);
        } else {
          // Draw minor marker
          canvas.drawLine(
            Offset(x, size.height - 6),
            Offset(x, size.height),
            minorPaint,
          );
        }
      }

      time += markerConfig.minorInterval;
    }
  }

  _MarkerConfig _calculateMarkerConfig() {
    // Determine marker intervals based on zoom level
    // At low zoom (zoomed out), show fewer markers
    // At high zoom (zoomed in), show more detail

    // Target: approximately 80-150 pixels between major markers
    final targetMajorPixels = 100.0;
    final idealMajorInterval = targetMajorPixels / pixelsPerSecond;

    // Standard intervals in seconds
    final intervals = [
      _MarkerConfig(3600, 600, false),    // 1 hour major, 10 min minor
      _MarkerConfig(1800, 300, false),    // 30 min major, 5 min minor
      _MarkerConfig(600, 60, false),      // 10 min major, 1 min minor
      _MarkerConfig(300, 60, false),      // 5 min major, 1 min minor
      _MarkerConfig(60, 10, false),       // 1 min major, 10 sec minor
      _MarkerConfig(30, 5, false),        // 30 sec major, 5 sec minor
      _MarkerConfig(10, 1, false),        // 10 sec major, 1 sec minor
      _MarkerConfig(5, 1, false),         // 5 sec major, 1 sec minor
      _MarkerConfig(1, 0.5, false),       // 1 sec major, 0.5 sec minor
      _MarkerConfig(1, 1/frameRate, true), // 1 sec major, per-frame minor
      _MarkerConfig(0.5, 1/frameRate, true), // 0.5 sec major, per-frame minor
      _MarkerConfig(10/frameRate, 1/frameRate, true), // 10 frames major, per-frame minor
      _MarkerConfig(5/frameRate, 1/frameRate, true),  // 5 frames major, per-frame minor
      _MarkerConfig(1/frameRate, 1/frameRate, true),  // per-frame major
    ];

    // Find the best matching interval
    for (final config in intervals) {
      if (config.majorInterval <= idealMajorInterval * 2) {
        return config;
      }
    }

    return intervals.last;
  }

  bool _isMajorMarker(double time, double majorInterval) {
    // Account for floating point precision
    final remainder = time % majorInterval;
    return remainder < 0.0001 || (majorInterval - remainder) < 0.0001;
  }

  String _formatTime(double seconds, bool showFrames) {
    final totalSeconds = seconds.abs();
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final secs = (totalSeconds % 60).floor();
    final frames = ((totalSeconds % 1) * frameRate).round();

    if (showFrames && totalSeconds < 60) {
      // Show frames for short durations when zoomed in
      if (totalSeconds < 1) {
        return '${frames}f';
      }
      return '$secs:${frames.toString().padLeft(2, '0')}';
    }

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    if (minutes > 0 || totalSeconds >= 60) {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    }
    return '${secs}s';
  }

  void _drawLabel(Canvas canvas, String text, double x, double y, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(
          color: color,
          fontSize: 10,
          fontFeatures: [const FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Center the text on the marker
    final textX = x - textPainter.width / 2;
    final textY = y - textPainter.height;

    textPainter.paint(canvas, Offset(textX, math.max(2, textY)));
  }

  void _drawInOutPoints(Canvas canvas, Size size) {
    // Draw in point triangle
    if (inPoint != null) {
      final x = _timeToPosition(inPoint!, size.width);
      if (x >= -10 && x <= size.width + 10) {
        _drawTriangleMarker(canvas, x, size.height, colorScheme.primary, true);
      }
    }

    // Draw out point triangle
    if (outPoint != null) {
      final x = _timeToPosition(outPoint!, size.width);
      if (x >= -10 && x <= size.width + 10) {
        _drawTriangleMarker(canvas, x, size.height, colorScheme.primary, false);
      }
    }
  }

  void _drawTriangleMarker(Canvas canvas, double x, double baseY, Color color, bool isInPoint) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final triangleSize = 8.0;

    if (isInPoint) {
      // In point: triangle pointing right, attached at left edge
      path.moveTo(x, baseY);
      path.lineTo(x, baseY - triangleSize);
      path.lineTo(x + triangleSize, baseY);
      path.close();
    } else {
      // Out point: triangle pointing left, attached at right edge
      path.moveTo(x, baseY);
      path.lineTo(x, baseY - triangleSize);
      path.lineTo(x - triangleSize, baseY);
      path.close();
    }

    canvas.drawPath(path, paint);

    // Draw outline for visibility
    final outlinePaint = Paint()
      ..color = colorScheme.onPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, outlinePaint);
  }

  void _drawPlayhead(Canvas canvas, Size size) {
    final x = _timeToPosition(playheadPosition, size.width);

    if (x < -10 || x > size.width + 10) return;

    // Draw playhead line
    final linePaint = Paint()
      ..color = colorScheme.error
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      linePaint,
    );

    // Draw playhead handle (inverted triangle at top)
    final handlePaint = Paint()
      ..color = colorScheme.error
      ..style = PaintingStyle.fill;

    final handlePath = Path();
    final handleWidth = 10.0;
    final handleHeight = 8.0;

    handlePath.moveTo(x - handleWidth / 2, 0);
    handlePath.lineTo(x + handleWidth / 2, 0);
    handlePath.lineTo(x, handleHeight);
    handlePath.close();

    canvas.drawPath(handlePath, handlePaint);
  }

  double _timeToPosition(EditorTime time, double width) {
    final scrollSeconds = scrollOffset.inSeconds;
    final timeSeconds = time.inSeconds;
    return (timeSeconds - scrollSeconds) * pixelsPerSecond;
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) {
    return pixelsPerSecond != oldDelegate.pixelsPerSecond ||
        duration != oldDelegate.duration ||
        scrollOffset != oldDelegate.scrollOffset ||
        playheadPosition != oldDelegate.playheadPosition ||
        inPoint != oldDelegate.inPoint ||
        outPoint != oldDelegate.outPoint ||
        frameRate != oldDelegate.frameRate ||
        colorScheme != oldDelegate.colorScheme;
  }
}

/// Configuration for marker intervals.
class _MarkerConfig {
  /// Interval for major markers (with labels) in seconds.
  final double majorInterval;

  /// Interval for minor markers (tick marks) in seconds.
  final double minorInterval;

  /// Whether to show frame numbers instead of time.
  final bool showFrames;

  const _MarkerConfig(this.majorInterval, this.minorInterval, this.showFrames);
}
