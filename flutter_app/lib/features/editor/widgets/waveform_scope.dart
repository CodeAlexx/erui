import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/scopes_provider.dart';
import '../services/scope_analyzer.dart';

/// Widget for displaying a video waveform scope.
///
/// Shows luminance or RGB values vertically aligned with frame columns.
/// Includes IRE scale markers and mode switching.
class WaveformScope extends ConsumerWidget {
  /// Current frame data to analyze
  final Uint8List? frameData;

  /// Display mode (luma, parade, overlay)
  final WaveformMode mode;

  /// Called when mode changes
  final ValueChanged<WaveformMode>? onModeChanged;

  /// Background color
  final Color? backgroundColor;

  const WaveformScope({
    super.key,
    this.frameData,
    this.mode = WaveformMode.luma,
    this.onModeChanged,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final scopeData = ref.watch(waveformDataProvider);

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

          // Waveform display
          Expanded(
            child: scopeData.when(
              data: (data) => data != null
                  ? CustomPaint(
                      painter: _WaveformPainter(
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
            'WAVEFORM',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          _ModeButton(
            label: 'Y',
            tooltip: 'Luma',
            isSelected: mode == WaveformMode.luma,
            onTap: () => onModeChanged?.call(WaveformMode.luma),
          ),
          const SizedBox(width: 4),
          _ModeButton(
            label: 'RGB',
            tooltip: 'RGB Parade',
            isSelected: mode == WaveformMode.rgbParade,
            onTap: () => onModeChanged?.call(WaveformMode.rgbParade),
          ),
          const SizedBox(width: 4),
          _ModeButton(
            label: 'OVL',
            tooltip: 'RGB Overlay',
            isSelected: mode == WaveformMode.rgbOverlay,
            onTap: () => onModeChanged?.call(WaveformMode.rgbOverlay),
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

/// Custom painter for waveform display
class _WaveformPainter extends CustomPainter {
  final WaveformData data;
  final WaveformMode mode;
  final Color gridColor;

  _WaveformPainter({
    required this.data,
    required this.mode,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid and IRE markers
    _drawGrid(canvas, size);

    // Draw waveform based on mode
    switch (mode) {
      case WaveformMode.luma:
        _drawLumaWaveform(canvas, size);
        break;
      case WaveformMode.rgbParade:
        _drawRGBParade(canvas, size);
        break;
      case WaveformMode.rgbOverlay:
        _drawRGBOverlay(canvas, size);
        break;
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = gridColor;

    final textStyle = TextStyle(
      color: gridColor,
      fontSize: 8,
    );

    // IRE levels: 0, 25, 50, 75, 100
    for (final ire in [0, 25, 50, 75, 100]) {
      final y = size.height - (ire / 100 * size.height);
      canvas.drawLine(Offset(20, y), Offset(size.width, y), paint);

      // Draw label
      final textPainter = TextPainter(
        text: TextSpan(text: '$ire', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(2, y - 4));
    }

    // Draw broadcast safe zone (7.5 IRE for black, 100 IRE for white)
    final safeZonePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.yellow.withOpacity(0.3);

    final blackLevel = size.height - (7.5 / 100 * size.height);
    canvas.drawLine(
      Offset(20, blackLevel),
      Offset(size.width, blackLevel),
      safeZonePaint,
    );
  }

  void _drawLumaWaveform(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.green.withOpacity(0.8);

    final columnWidth = (size.width - 20) / data.lumaColumns.length;

    for (int col = 0; col < data.lumaColumns.length; col++) {
      final values = data.lumaColumns[col];
      final x = 20 + col * columnWidth;

      for (final luma in values) {
        final y = size.height - (luma * size.height);
        canvas.drawCircle(Offset(x + columnWidth / 2, y), 0.5, paint);
      }
    }
  }

  void _drawRGBParade(Canvas canvas, Size size) {
    if (!data.hasRGBData) return;

    final paradeWidth = (size.width - 20) / 3;
    final channels = [
      (data.redColumns!, Colors.red),
      (data.greenColumns!, Colors.green),
      (data.blueColumns!, Colors.blue),
    ];

    for (int ch = 0; ch < channels.length; ch++) {
      final columns = channels[ch].$1;
      final color = channels[ch].$2;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withOpacity(0.8);

      final columnWidth = paradeWidth / columns.length;
      final startX = 20 + ch * paradeWidth;

      for (int col = 0; col < columns.length; col++) {
        final values = columns[col];
        final x = startX + col * columnWidth;

        for (final value in values) {
          final y = size.height - (value * size.height);
          canvas.drawCircle(Offset(x + columnWidth / 2, y), 0.5, paint);
        }
      }
    }
  }

  void _drawRGBOverlay(Canvas canvas, Size size) {
    if (!data.hasRGBData) return;

    final columnWidth = (size.width - 20) / data.lumaColumns.length;
    final channels = [
      (data.redColumns!, Colors.red.withOpacity(0.5)),
      (data.greenColumns!, Colors.green.withOpacity(0.5)),
      (data.blueColumns!, Colors.blue.withOpacity(0.5)),
    ];

    for (final channel in channels) {
      final columns = channel.$1;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = channel.$2;

      for (int col = 0; col < columns.length; col++) {
        final values = columns[col];
        final x = 20 + col * columnWidth;

        for (final value in values) {
          final y = size.height - (value * size.height);
          canvas.drawCircle(Offset(x + columnWidth / 2, y), 0.5, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.mode != mode ||
        oldDelegate.gridColor != gridColor;
  }
}
