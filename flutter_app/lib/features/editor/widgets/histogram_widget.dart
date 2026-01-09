import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/scopes_provider.dart';
import '../services/scope_analyzer.dart';

/// Display modes for histogram
enum HistogramMode {
  /// RGB channels stacked
  stacked,

  /// RGB channels overlaid
  overlay,

  /// Luminance only
  luminance,
}

/// Widget for displaying a video histogram.
///
/// Shows RGB and/or luminance distribution with optional
/// stacked or overlay display modes.
class HistogramWidget extends ConsumerWidget {
  /// Current frame data to analyze
  final Uint8List? frameData;

  /// Display mode
  final HistogramMode mode;

  /// Called when mode changes
  final ValueChanged<HistogramMode>? onModeChanged;

  /// Background color
  final Color? backgroundColor;

  const HistogramWidget({
    super.key,
    this.frameData,
    this.mode = HistogramMode.overlay,
    this.onModeChanged,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final scopeData = ref.watch(histogramDataProvider);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with mode selector
          _buildHeader(context),

          // Histogram display
          Expanded(
            child: scopeData.when(
              data: (data) => data != null
                  ? CustomPaint(
                      painter: _HistogramPainter(
                        data: data,
                        mode: mode,
                        gridColor: colorScheme.onSurface.withOpacity(0.2),
                      ),
                      size: Size.infinite,
                    )
                  : _buildEmptyState(context),
              loading: () => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontSize: 12,
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.onSurface.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'HISTOGRAM',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          _ModeButton(
            label: 'RGB',
            tooltip: 'RGB Overlay',
            isSelected: mode == HistogramMode.overlay,
            onTap: () => onModeChanged?.call(HistogramMode.overlay),
          ),
          const SizedBox(width: 4),
          _ModeButton(
            label: 'STK',
            tooltip: 'RGB Stacked',
            isSelected: mode == HistogramMode.stacked,
            onTap: () => onModeChanged?.call(HistogramMode.stacked),
          ),
          const SizedBox(width: 4),
          _ModeButton(
            label: 'Y',
            tooltip: 'Luminance',
            isSelected: mode == HistogramMode.luminance,
            onTap: () => onModeChanged?.call(HistogramMode.luminance),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Text(
        'No signal',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Mode selection button
class _ModeButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ModeButton({
    required this.label,
    required this.tooltip,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white24 : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for histogram display
class _HistogramPainter extends CustomPainter {
  final HistogramData data;
  final HistogramMode mode;
  final Color gridColor;

  _HistogramPainter({
    required this.data,
    required this.mode,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid
    _drawGrid(canvas, size);

    // Draw histogram based on mode
    switch (mode) {
      case HistogramMode.overlay:
        _drawOverlayHistogram(canvas, size);
        break;
      case HistogramMode.stacked:
        _drawStackedHistogram(canvas, size);
        break;
      case HistogramMode.luminance:
        _drawLuminanceHistogram(canvas, size);
        break;
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = gridColor;

    // Vertical lines at 0, 64, 128, 192, 255
    for (final level in [0, 64, 128, 192, 255]) {
      final x = level / 255 * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines at 25%, 50%, 75%
    for (final pct in [0.25, 0.5, 0.75]) {
      final y = size.height * (1 - pct);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawOverlayHistogram(Canvas canvas, Size size) {
    final channels = [
      (data.red, Colors.red.withOpacity(0.5)),
      (data.green, Colors.green.withOpacity(0.5)),
      (data.blue, Colors.blue.withOpacity(0.5)),
    ];

    for (final channel in channels) {
      _drawChannel(canvas, size, channel.$1, channel.$2);
    }

    // Also draw luminance as white overlay
    _drawChannel(canvas, size, data.luminance, Colors.white.withOpacity(0.3));
  }

  void _drawStackedHistogram(Canvas canvas, Size size) {
    final thirdHeight = size.height / 3;

    // Red channel
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, thirdHeight));
    _drawChannel(
        canvas, Size(size.width, thirdHeight), data.red, Colors.red);
    canvas.restore();

    // Green channel
    canvas.save();
    canvas.translate(0, thirdHeight);
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, thirdHeight));
    _drawChannel(
        canvas, Size(size.width, thirdHeight), data.green, Colors.green);
    canvas.restore();

    // Blue channel
    canvas.save();
    canvas.translate(0, thirdHeight * 2);
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, thirdHeight));
    _drawChannel(
        canvas, Size(size.width, thirdHeight), data.blue, Colors.blue);
    canvas.restore();
  }

  void _drawLuminanceHistogram(Canvas canvas, Size size) {
    _drawChannel(canvas, size, data.luminance, Colors.white);
  }

  void _drawChannel(
      Canvas canvas, Size size, List<double> values, Color color) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    final path = Path();
    path.moveTo(0, size.height);

    final binWidth = size.width / values.length;

    for (int i = 0; i < values.length; i++) {
      final x = i * binWidth;
      final y = size.height - (values[i] * size.height);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Draw outline
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withOpacity(0.8);

    final outlinePath = Path();
    outlinePath.moveTo(0, size.height - (values[0] * size.height));
    for (int i = 1; i < values.length; i++) {
      final x = i * binWidth;
      final y = size.height - (values[i] * size.height);
      outlinePath.lineTo(x, y);
    }

    canvas.drawPath(outlinePath, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant _HistogramPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.mode != mode ||
        oldDelegate.gridColor != gridColor;
  }
}
