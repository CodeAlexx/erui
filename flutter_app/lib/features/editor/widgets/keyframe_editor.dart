import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/keyframe_models.dart';

/// Bezier curve editor for keyframe animation.
///
/// Provides a canvas for adding, removing, and manipulating keyframes
/// with support for bezier curve handles and value graph visualization.
class KeyframeEditor extends ConsumerStatefulWidget {
  /// Keyframe track being edited
  final KeyframeTrack track;

  /// Visible time range
  final EditorTimeRange visibleRange;

  /// Pixels per second for horizontal scaling
  final double pixelsPerSecond;

  /// Height of the editor
  final double height;

  /// Called when track is modified
  final ValueChanged<KeyframeTrack>? onTrackChanged;

  /// Called when a keyframe is selected
  final ValueChanged<Keyframe?>? onKeyframeSelected;

  const KeyframeEditor({
    super.key,
    required this.track,
    required this.visibleRange,
    required this.pixelsPerSecond,
    this.height = 120,
    this.onTrackChanged,
    this.onKeyframeSelected,
  });

  @override
  ConsumerState<KeyframeEditor> createState() => _KeyframeEditorState();
}

class _KeyframeEditorState extends ConsumerState<KeyframeEditor> {
  EditorId? _selectedKeyframeId;
  EditorId? _draggingKeyframeId;
  bool _draggingHandleIn = false;
  bool _draggingHandleOut = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(context),

          // Canvas
          Expanded(
            child: GestureDetector(
              onDoubleTapDown: (details) {
                _addKeyframeAt(details.localPosition);
              },
              child: CustomPaint(
                painter: _KeyframePainter(
                  track: widget.track,
                  visibleRange: widget.visibleRange,
                  pixelsPerSecond: widget.pixelsPerSecond,
                  selectedKeyframeId: _selectedKeyframeId,
                  gridColor: colorScheme.onSurface.withOpacity(0.1),
                  curveColor: colorScheme.primary,
                  keyframeColor: colorScheme.primary,
                  selectedColor: colorScheme.secondary,
                ),
                child: Stack(
                  children: [
                    // Keyframe handles
                    ...widget.track.sortedKeyframes.map((kf) {
                      return _KeyframeHandle(
                        keyframe: kf,
                        track: widget.track,
                        visibleRange: widget.visibleRange,
                        pixelsPerSecond: widget.pixelsPerSecond,
                        editorHeight: widget.height - 24, // Minus header
                        isSelected: _selectedKeyframeId == kf.id,
                        onTap: () {
                          setState(() {
                            _selectedKeyframeId = kf.id;
                          });
                          widget.onKeyframeSelected?.call(kf);
                        },
                        onDragUpdate: (delta) {
                          _moveKeyframe(kf, delta);
                        },
                        onHandleInDrag: (delta) {
                          _moveHandle(kf, delta, isIn: true);
                        },
                        onHandleOutDrag: (delta) {
                          _moveHandle(kf, delta, isIn: false);
                        },
                        onDelete: () {
                          _deleteKeyframe(kf);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timeline,
            size: 14,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.track.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),

          // Interpolation selector
          if (_selectedKeyframeId != null)
            PopupMenuButton<KeyframeType>(
              tooltip: 'Interpolation',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getSelectedKeyframe()?.type.displayName ?? '',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 14),
                  ],
                ),
              ),
              onSelected: (type) {
                _changeInterpolation(type);
              },
              itemBuilder: (context) => KeyframeType.values
                  .map((type) => PopupMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ))
                  .toList(),
            ),

          const SizedBox(width: 8),

          // Delete button
          if (_selectedKeyframeId != null)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 16, color: colorScheme.error),
              onPressed: () {
                final kf = _getSelectedKeyframe();
                if (kf != null) _deleteKeyframe(kf);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
        ],
      ),
    );
  }

  Keyframe? _getSelectedKeyframe() {
    if (_selectedKeyframeId == null) return null;
    for (final kf in widget.track.keyframes) {
      if (kf.id == _selectedKeyframeId) return kf;
    }
    return null;
  }

  void _addKeyframeAt(Offset position) {
    // Convert position to time and value
    final headerHeight = 24.0;
    final canvasHeight = widget.height - headerHeight;

    final time = EditorTime(
      (widget.visibleRange.start.microseconds +
              (position.dx / widget.pixelsPerSecond * 1000000))
          .round(),
    );

    final normalizedY = 1 - ((position.dy - headerHeight) / canvasHeight);
    final value = widget.track.minValue +
        normalizedY * (widget.track.maxValue - widget.track.minValue);

    final newKeyframe = Keyframe.create(
      time: time,
      value: value.clamp(widget.track.minValue, widget.track.maxValue),
    );

    final updatedTrack = widget.track.addKeyframe(newKeyframe);
    widget.onTrackChanged?.call(updatedTrack);

    setState(() {
      _selectedKeyframeId = newKeyframe.id;
    });
    widget.onKeyframeSelected?.call(newKeyframe);
  }

  void _moveKeyframe(Keyframe keyframe, Offset delta) {
    final timeChange = (delta.dx / widget.pixelsPerSecond * 1000000).round();
    final canvasHeight = widget.height - 24;
    final valueRange = widget.track.maxValue - widget.track.minValue;
    final valueChange = -delta.dy / canvasHeight * valueRange;

    final newTime = EditorTime(keyframe.time.microseconds + timeChange);
    final newValue =
        (keyframe.value + valueChange).clamp(widget.track.minValue, widget.track.maxValue);

    final updatedKeyframe = keyframe.copyWith(time: newTime, value: newValue);
    final updatedTrack = widget.track.updateKeyframe(updatedKeyframe);
    widget.onTrackChanged?.call(updatedTrack);
  }

  void _moveHandle(Keyframe keyframe, Offset delta, {required bool isIn}) {
    final handle = isIn ? keyframe.handleIn : keyframe.handleOut;
    if (handle == null) return;

    final canvasHeight = widget.height - 24;
    final valueRange = widget.track.maxValue - widget.track.minValue;

    final timeChange = delta.dx / widget.pixelsPerSecond;
    final valueChange = -delta.dy / canvasHeight * valueRange;

    final newHandle = BezierHandle(
      handle.x + timeChange,
      handle.y + valueChange,
    );

    final updatedKeyframe = isIn
        ? keyframe.copyWith(handleIn: newHandle)
        : keyframe.copyWith(handleOut: newHandle);
    final updatedTrack = widget.track.updateKeyframe(updatedKeyframe);
    widget.onTrackChanged?.call(updatedTrack);
  }

  void _deleteKeyframe(Keyframe keyframe) {
    final updatedTrack = widget.track.removeKeyframe(keyframe.id);
    widget.onTrackChanged?.call(updatedTrack);

    setState(() {
      _selectedKeyframeId = null;
    });
    widget.onKeyframeSelected?.call(null);
  }

  void _changeInterpolation(KeyframeType type) {
    final keyframe = _getSelectedKeyframe();
    if (keyframe == null) return;

    BezierHandle? handleIn;
    BezierHandle? handleOut;

    if (type == KeyframeType.bezier) {
      handleIn = const BezierHandle(-0.25, 0);
      handleOut = const BezierHandle(0.25, 0);
    }

    final updatedKeyframe = keyframe.copyWith(
      type: type,
      handleIn: handleIn,
      handleOut: handleOut,
    );
    final updatedTrack = widget.track.updateKeyframe(updatedKeyframe);
    widget.onTrackChanged?.call(updatedTrack);
  }
}

/// Custom painter for keyframe curves
class _KeyframePainter extends CustomPainter {
  final KeyframeTrack track;
  final EditorTimeRange visibleRange;
  final double pixelsPerSecond;
  final EditorId? selectedKeyframeId;
  final Color gridColor;
  final Color curveColor;
  final Color keyframeColor;
  final Color selectedColor;

  _KeyframePainter({
    required this.track,
    required this.visibleRange,
    required this.pixelsPerSecond,
    this.selectedKeyframeId,
    required this.gridColor,
    required this.curveColor,
    required this.keyframeColor,
    required this.selectedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final headerHeight = 24.0;
    final canvasHeight = size.height - headerHeight;

    // Draw grid
    _drawGrid(canvas, size, canvasHeight, headerHeight);

    // Draw curve
    _drawCurve(canvas, size, canvasHeight, headerHeight);
  }

  void _drawGrid(
      Canvas canvas, Size size, double canvasHeight, double headerHeight) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = gridColor;

    // Value grid lines (min, mid, max)
    for (final pct in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = headerHeight + canvasHeight * (1 - pct);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Time grid lines (every second)
    final startSecond = visibleRange.start.inSeconds.floor();
    final endSecond = visibleRange.end.inSeconds.ceil();
    for (int s = startSecond; s <= endSecond; s++) {
      final x = (s - visibleRange.start.inSeconds) * pixelsPerSecond;
      canvas.drawLine(
          Offset(x, headerHeight), Offset(x, size.height), paint);
    }
  }

  void _drawCurve(
      Canvas canvas, Size size, double canvasHeight, double headerHeight) {
    if (track.keyframes.isEmpty) return;

    final sorted = track.sortedKeyframes;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = curveColor;

    final path = Path();
    bool started = false;

    // Draw line segments between keyframes
    for (int i = 0; i < sorted.length - 1; i++) {
      final kf1 = sorted[i];
      final kf2 = sorted[i + 1];

      final x1 = _timeToX(kf1.time, size.width);
      final y1 = _valueToY(kf1.value, canvasHeight, headerHeight);
      final x2 = _timeToX(kf2.time, size.width);
      final y2 = _valueToY(kf2.value, canvasHeight, headerHeight);

      if (!started) {
        path.moveTo(x1, y1);
        started = true;
      }

      switch (kf1.type) {
        case KeyframeType.hold:
          path.lineTo(x2, y1);
          path.lineTo(x2, y2);
          break;
        case KeyframeType.linear:
          path.lineTo(x2, y2);
          break;
        case KeyframeType.bezier:
          final h1 = kf1.handleOut ?? const BezierHandle(0.25, 0);
          final h2 = kf2.handleIn ?? const BezierHandle(-0.25, 0);
          final cx1 = x1 + h1.x * pixelsPerSecond;
          final cy1 = y1 - h1.y * canvasHeight / (track.maxValue - track.minValue);
          final cx2 = x2 + h2.x * pixelsPerSecond;
          final cy2 = y2 - h2.y * canvasHeight / (track.maxValue - track.minValue);
          path.cubicTo(cx1, cy1, cx2, cy2, x2, y2);
          break;
        case KeyframeType.easeIn:
        case KeyframeType.easeOut:
        case KeyframeType.easeInOut:
          // Simplified easing - use quadratic bezier
          final midX = (x1 + x2) / 2;
          final midY = kf1.type == KeyframeType.easeIn ? y1 : y2;
          path.quadraticBezierTo(midX, midY, x2, y2);
          break;
      }
    }

    canvas.drawPath(path, paint);
  }

  double _timeToX(EditorTime time, double width) {
    return (time.inSeconds - visibleRange.start.inSeconds) * pixelsPerSecond;
  }

  double _valueToY(double value, double canvasHeight, double headerHeight) {
    final normalized =
        (value - track.minValue) / (track.maxValue - track.minValue);
    return headerHeight + canvasHeight * (1 - normalized);
  }

  @override
  bool shouldRepaint(covariant _KeyframePainter oldDelegate) {
    return oldDelegate.track != track ||
        oldDelegate.visibleRange != visibleRange ||
        oldDelegate.selectedKeyframeId != selectedKeyframeId;
  }
}

/// Draggable keyframe handle widget
class _KeyframeHandle extends StatelessWidget {
  final Keyframe keyframe;
  final KeyframeTrack track;
  final EditorTimeRange visibleRange;
  final double pixelsPerSecond;
  final double editorHeight;
  final bool isSelected;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onDragUpdate;
  final ValueChanged<Offset>? onHandleInDrag;
  final ValueChanged<Offset>? onHandleOutDrag;
  final VoidCallback? onDelete;

  const _KeyframeHandle({
    required this.keyframe,
    required this.track,
    required this.visibleRange,
    required this.pixelsPerSecond,
    required this.editorHeight,
    required this.isSelected,
    this.onTap,
    this.onDragUpdate,
    this.onHandleInDrag,
    this.onHandleOutDrag,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final x = (keyframe.time.inSeconds - visibleRange.start.inSeconds) *
        pixelsPerSecond;
    final normalized =
        (keyframe.value - track.minValue) / (track.maxValue - track.minValue);
    final y = editorHeight * (1 - normalized);

    return Positioned(
      left: x - 6,
      top: 24 + y - 6, // Account for header
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (details) => onDragUpdate?.call(details.delta),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            border: Border.all(
              color: isSelected ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary,
              width: 2,
            ),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
