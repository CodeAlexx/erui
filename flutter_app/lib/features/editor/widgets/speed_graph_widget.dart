import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/speed_ramp_models.dart';
import '../models/keyframe_models.dart';
import '../providers/speed_ramp_provider.dart';
import '../services/speed_ramp_service.dart';

/// Graph widget for editing speed ramp curves
class SpeedGraphWidget extends ConsumerStatefulWidget {
  final EditorId clipId;
  final EditorTime duration;
  final double height;
  final double pixelsPerSecond;

  const SpeedGraphWidget({
    super.key,
    required this.clipId,
    required this.duration,
    this.height = 150,
    this.pixelsPerSecond = 100,
  });

  @override
  ConsumerState<SpeedGraphWidget> createState() => _SpeedGraphWidgetState();
}

class _SpeedGraphWidgetState extends ConsumerState<SpeedGraphWidget> {
  EditorId? _selectedKeyframeId;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final curve = ref.watch(clipSpeedCurveProvider(widget.clipId));
    final graphData = ref.watch(
      speedGraphDataProvider((widget.clipId, widget.duration)),
    );

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context, curve),

          // Graph
          Expanded(
            child: GestureDetector(
              onDoubleTapDown: (details) => _addKeyframe(details.localPosition),
              child: CustomPaint(
                painter: _SpeedGraphPainter(
                  curve: curve,
                  graphData: graphData,
                  duration: widget.duration,
                  pixelsPerSecond: widget.pixelsPerSecond,
                  selectedKeyframeId: _selectedKeyframeId,
                  gridColor: colorScheme.onSurface.withOpacity(0.1),
                  curveColor: colorScheme.primary,
                  keyframeColor: colorScheme.primary,
                  selectedColor: colorScheme.secondary,
                  baselineColor: colorScheme.tertiary,
                ),
                child: Stack(
                  children: [
                    // Keyframe handles
                    if (curve != null)
                      ...curve.keyframes.map((kf) => _buildKeyframeHandle(kf, curve)),
                  ],
                ),
              ),
            ),
          ),

          // Controls
          _buildControls(context, curve),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TimeRemapCurve? curve) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.speed, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Speed Graph',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          Switch(
            value: curve?.enabled ?? false,
            onChanged: (value) {
              ref.read(speedRampProvider.notifier).setCurveEnabled(widget.clipId, value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKeyframeHandle(SpeedKeyframe kf, TimeRemapCurve curve) {
    final colorScheme = Theme.of(context).colorScheme;
    final headerHeight = 36.0;
    final controlsHeight = 48.0;
    final graphHeight = widget.height - headerHeight - controlsHeight;

    // Calculate position
    final x = kf.sourceTime.inSeconds * widget.pixelsPerSecond;
    final y = graphHeight * (1 - (kf.speed.clamp(0, 4) / 4));

    final isSelected = _selectedKeyframeId == kf.id;

    return Positioned(
      left: x - 8,
      top: headerHeight + y - 8,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedKeyframeId = kf.id);
          ref.read(speedRampProvider.notifier).selectKeyframe(kf.id);
        },
        onPanStart: (_) {
          setState(() {
            _selectedKeyframeId = kf.id;
            _dragging = true;
          });
        },
        onPanUpdate: (details) {
          // Calculate new time and speed
          final newTime = EditorTime.fromSeconds(
            kf.sourceTime.inSeconds + details.delta.dx / widget.pixelsPerSecond,
          );
          final speedDelta = -details.delta.dy / graphHeight * 4;
          final newSpeed = (kf.speed + speedDelta).clamp(0.0, 4.0);

          ref.read(speedRampProvider.notifier).updateKeyframe(
            widget.clipId,
            kf.copyWith(
              sourceTime: newTime,
              outputTime: newTime,
              speed: newSpeed,
            ),
          );
        },
        onPanEnd: (_) => setState(() => _dragging = false),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.secondary : colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.onPrimary,
              width: 2,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: colorScheme.secondary.withOpacity(0.5), blurRadius: 4)]
                : null,
          ),
          child: Center(
            child: Text(
              '${kf.speed.toStringAsFixed(1)}x',
              style: TextStyle(
                fontSize: 6,
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, TimeRemapCurve? curve) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          // Presets dropdown
          PopupMenuButton<SpeedRampPreset>(
            tooltip: 'Apply Preset',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune, size: 14),
                  const SizedBox(width: 4),
                  const Text('Presets', style: TextStyle(fontSize: 11)),
                  const Icon(Icons.arrow_drop_down, size: 14),
                ],
              ),
            ),
            onSelected: (preset) {
              ref.read(speedRampProvider.notifier).applyPreset(
                widget.clipId,
                preset,
                widget.duration,
              );
            },
            itemBuilder: (context) => SpeedRampPresets.builtIn
                .map((p) => PopupMenuItem(
                      value: p,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontSize: 12)),
                          Text(
                            p.description,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(width: 8),

          // Delete selected keyframe
          if (_selectedKeyframeId != null)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: colorScheme.error),
              onPressed: () {
                ref.read(speedRampProvider.notifier).removeKeyframe(
                  widget.clipId,
                  _selectedKeyframeId!,
                );
                setState(() => _selectedKeyframeId = null);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Delete Keyframe',
            ),

          const Spacer(),

          // Optical flow toggle
          Tooltip(
            message: 'Enable optical flow for smoother slow motion',
            child: FilterChip(
              label: const Text('Optical Flow', style: TextStyle(fontSize: 10)),
              selected: curve?.opticalFlow ?? false,
              onSelected: curve?.enabled == true
                  ? (value) {
                      ref.read(speedRampProvider.notifier).setOpticalFlow(
                        widget.clipId,
                        value,
                      );
                    }
                  : null,
            ),
          ),

          const SizedBox(width: 4),

          // Maintain pitch toggle
          Tooltip(
            message: 'Maintain audio pitch during speed changes',
            child: FilterChip(
              label: const Text('Keep Pitch', style: TextStyle(fontSize: 10)),
              selected: curve?.maintainPitch ?? true,
              onSelected: curve?.enabled == true
                  ? (value) {
                      ref.read(speedRampProvider.notifier).setMaintainPitch(
                        widget.clipId,
                        value,
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void _addKeyframe(Offset position) {
    final headerHeight = 36.0;
    final controlsHeight = 48.0;
    final graphHeight = widget.height - headerHeight - controlsHeight;

    // Calculate time and speed from position
    final time = EditorTime.fromSeconds(position.dx / widget.pixelsPerSecond);
    final speed = ((1 - (position.dy - headerHeight) / graphHeight) * 4).clamp(0.0, 4.0);

    ref.read(speedRampProvider.notifier).addKeyframe(
      widget.clipId,
      time,
      speed,
      interpolation: KeyframeType.bezier,
    );
  }
}

/// Custom painter for speed graph
class _SpeedGraphPainter extends CustomPainter {
  final TimeRemapCurve? curve;
  final List<SpeedGraphPoint> graphData;
  final EditorTime duration;
  final double pixelsPerSecond;
  final EditorId? selectedKeyframeId;
  final Color gridColor;
  final Color curveColor;
  final Color keyframeColor;
  final Color selectedColor;
  final Color baselineColor;

  _SpeedGraphPainter({
    this.curve,
    required this.graphData,
    required this.duration,
    required this.pixelsPerSecond,
    this.selectedKeyframeId,
    required this.gridColor,
    required this.curveColor,
    required this.keyframeColor,
    required this.selectedColor,
    required this.baselineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final headerHeight = 36.0;
    final controlsHeight = 48.0;
    final graphHeight = size.height - headerHeight - controlsHeight;
    final graphTop = headerHeight;

    // Draw grid
    _drawGrid(canvas, size, graphHeight, graphTop);

    // Draw 100% baseline
    _drawBaseline(canvas, size, graphHeight, graphTop);

    // Draw curve
    _drawCurve(canvas, size, graphHeight, graphTop);
  }

  void _drawGrid(Canvas canvas, Size size, double graphHeight, double graphTop) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = gridColor;

    // Speed grid lines (0%, 100%, 200%, 300%, 400%)
    for (final pct in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = graphTop + graphHeight * (1 - pct);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Time grid lines (every second)
    final totalSeconds = duration.inSeconds.ceil();
    for (int s = 0; s <= totalSeconds; s++) {
      final x = s * pixelsPerSecond;
      if (x <= size.width) {
        canvas.drawLine(Offset(x, graphTop), Offset(x, graphTop + graphHeight), paint);
      }
    }
  }

  void _drawBaseline(Canvas canvas, Size size, double graphHeight, double graphTop) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = baselineColor.withOpacity(0.5);

    // 100% (1x) speed line
    final y = graphTop + graphHeight * 0.75; // 1x is at 25% from bottom (1/4 of 4x max)
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  void _drawCurve(Canvas canvas, Size size, double graphHeight, double graphTop) {
    if (graphData.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = curveColor;

    final path = Path();
    bool started = false;

    for (final point in graphData) {
      final x = point.time.inSeconds * pixelsPerSecond;
      final y = graphTop + graphHeight * (1 - (point.speed.clamp(0, 4) / 4));

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw area under curve
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = curveColor.withOpacity(0.1);

    final fillPath = Path.from(path)
      ..lineTo(graphData.last.time.inSeconds * pixelsPerSecond, graphTop + graphHeight)
      ..lineTo(0, graphTop + graphHeight)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SpeedGraphPainter oldDelegate) {
    return oldDelegate.curve != curve ||
        oldDelegate.selectedKeyframeId != selectedKeyframeId;
  }
}
