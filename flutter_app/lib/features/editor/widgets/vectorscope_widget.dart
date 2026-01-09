import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/scopes_provider.dart';
import '../services/scope_analyzer.dart';

/// Widget for displaying a video vectorscope.
///
/// Shows color distribution in UV color space with skin tone line
/// and color targets for reference.
class VectorscopeWidget extends ConsumerWidget {
  /// Current frame data to analyze
  final Uint8List? frameData;

  /// Whether to show skin tone reference line
  final bool showSkinToneLine;

  /// Whether to show color targets
  final bool showTargets;

  /// Zoom level (1.0 = normal, 2.0 = 2x zoom)
  final double zoom;

  /// Called when zoom changes
  final ValueChanged<double>? onZoomChanged;

  /// Background color
  final Color? backgroundColor;

  const VectorscopeWidget({
    super.key,
    this.frameData,
    this.showSkinToneLine = true,
    this.showTargets = true,
    this.zoom = 1.0,
    this.onZoomChanged,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final scopeData = ref.watch(vectorscopeDataProvider);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with controls
          _buildHeader(context),

          // Vectorscope display
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: scopeData.when(
                data: (data) => data != null
                    ? CustomPaint(
                        painter: _VectorscopePainter(
                          data: data,
                          showSkinToneLine: showSkinToneLine,
                          showTargets: showTargets,
                          zoom: zoom,
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
          ),

          // Zoom control
          _buildZoomControl(context),
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
            'VECTORSCOPE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            '${zoom.toStringAsFixed(1)}x',
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControl(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 16),
            onPressed: zoom > 0.5
                ? () => onZoomChanged?.call((zoom - 0.5).clamp(0.5, 4.0))
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            color: Colors.grey,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                activeTrackColor: Colors.grey[600],
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Colors.grey[400],
              ),
              child: Slider(
                value: zoom,
                min: 0.5,
                max: 4.0,
                onChanged: onZoomChanged,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 16),
            onPressed: zoom < 4.0
                ? () => onZoomChanged?.call((zoom + 0.5).clamp(0.5, 4.0))
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            color: Colors.grey,
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

/// Custom painter for vectorscope display
class _VectorscopePainter extends CustomPainter {
  final VectorscopeData data;
  final bool showSkinToneLine;
  final bool showTargets;
  final double zoom;

  _VectorscopePainter({
    required this.data,
    required this.showSkinToneLine,
    required this.showTargets,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 10;

    // Draw graticule (grid)
    _drawGraticule(canvas, center, radius);

    // Draw color targets
    if (showTargets) {
      _drawColorTargets(canvas, center, radius);
    }

    // Draw skin tone line
    if (showSkinToneLine) {
      _drawSkinToneLine(canvas, center, radius);
    }

    // Draw data points
    _drawDataPoints(canvas, center, radius);
  }

  void _drawGraticule(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.grey.withOpacity(0.3);

    // Draw circles
    for (final r in [0.25, 0.5, 0.75, 1.0]) {
      canvas.drawCircle(center, radius * r / zoom, paint);
    }

    // Draw crosshairs
    canvas.drawLine(
      Offset(center.dx - radius / zoom, center.dy),
      Offset(center.dx + radius / zoom, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius / zoom),
      Offset(center.dx, center.dy + radius / zoom),
      paint,
    );

    // Draw I and Q axis labels
    final textStyle = TextStyle(
      color: Colors.grey.withOpacity(0.5),
      fontSize: 10,
    );
    _drawText(canvas, 'Q', Offset(center.dx + radius / zoom + 4, center.dy - 6),
        textStyle);
    _drawText(canvas, 'I', Offset(center.dx - 4, center.dy - radius / zoom - 12),
        textStyle);
  }

  void _drawColorTargets(Canvas canvas, Offset center, double radius) {
    // Standard color bar positions in UV space (normalized)
    final targets = {
      'R': (Offset(0.35, -0.22), Colors.red),
      'Mg': (Offset(0.22, 0.35), const Color(0xFFFF00FF)),
      'B': (Offset(-0.13, 0.38), Colors.blue),
      'Cy': (Offset(-0.35, 0.22), Colors.cyan),
      'G': (Offset(-0.22, -0.35), Colors.green),
      'Yl': (Offset(0.13, -0.38), Colors.yellow),
    };

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final entry in targets.entries) {
      final pos = entry.value.$1;
      final color = entry.value.$2;
      paint.color = color.withOpacity(0.7);

      final x = center.dx + pos.dx * radius * 2 / zoom;
      final y = center.dy + pos.dy * radius * 2 / zoom;

      // Draw target box
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: 12, height: 12),
        paint,
      );

      // Draw label
      final textStyle = TextStyle(
        color: color.withOpacity(0.8),
        fontSize: 8,
        fontWeight: FontWeight.bold,
      );
      _drawText(canvas, entry.key, Offset(x - 6, y + 8), textStyle);
    }
  }

  void _drawSkinToneLine(Canvas canvas, Offset center, double radius) {
    // Skin tone line at approximately 123 degrees
    final angle = 123 * math.pi / 180;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.orange.withOpacity(0.5);

    final endX = center.dx + math.cos(angle) * radius / zoom;
    final endY = center.dy - math.sin(angle) * radius / zoom;

    canvas.drawLine(center, Offset(endX, endY), paint);

    // Draw label
    final textStyle = TextStyle(
      color: Colors.orange.withOpacity(0.7),
      fontSize: 8,
    );
    _drawText(canvas, 'SKIN',
        Offset(endX + 4, endY - 4), textStyle);
  }

  void _drawDataPoints(Canvas canvas, Offset center, double radius) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < data.points.length; i++) {
      final point = data.points[i];
      final intensity = data.intensities[i];

      final x = center.dx + point.dx * radius * 2 / zoom;
      final y = center.dy + point.dy * radius * 2 / zoom;

      // Color based on position (approximate)
      final hue = (math.atan2(-point.dy, point.dx) * 180 / math.pi + 180) % 360;
      paint.color =
          HSVColor.fromAHSV(0.6, hue, intensity, 1.0).toColor();

      canvas.drawCircle(Offset(x, y), 0.8, paint);
    }
  }

  void _drawText(
      Canvas canvas, String text, Offset position, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _VectorscopePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.showSkinToneLine != showSkinToneLine ||
        oldDelegate.showTargets != showTargets ||
        oldDelegate.zoom != zoom;
  }
}
