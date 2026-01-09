import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Custom painter for audio waveform visualization.
///
/// Draws a waveform from amplitude data as a series of bars
/// or a continuous line depending on the style.
class WaveformPainter extends CustomPainter {
  /// Normalized amplitude values (0.0 to 1.0)
  final List<double> amplitudes;

  /// Primary color for the waveform
  final Color color;

  /// Optional secondary color for gradient effect
  final Color? secondaryColor;

  /// Style of waveform rendering
  final WaveformStyle style;

  /// Current playback progress (0.0 to 1.0), null if not playing
  final double? progress;

  /// Color for the played portion of the waveform
  final Color? playedColor;

  /// Whether to mirror the waveform (show both above and below center)
  final bool mirror;

  /// Spacing between bars (for bar style)
  final double barSpacing;

  /// Minimum bar height as a fraction of total height
  final double minBarHeight;

  /// Corner radius for bars (for bar style)
  final double barRadius;

  WaveformPainter({
    required this.amplitudes,
    required this.color,
    this.secondaryColor,
    this.style = WaveformStyle.bars,
    this.progress,
    this.playedColor,
    this.mirror = true,
    this.barSpacing = 1.0,
    this.minBarHeight = 0.05,
    this.barRadius = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    switch (style) {
      case WaveformStyle.bars:
        _drawBars(canvas, size);
        break;
      case WaveformStyle.line:
        _drawLine(canvas, size);
        break;
      case WaveformStyle.filled:
        _drawFilled(canvas, size);
        break;
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      Paint()
        ..color = color.withOpacity(0.3)
        ..strokeWidth = 1,
    );
  }

  void _drawBars(Canvas canvas, Size size) {
    final barCount = amplitudes.length;
    final totalBarWidth = (size.width - (barCount - 1) * barSpacing) / barCount;
    final barWidth = totalBarWidth.clamp(1.0, 10.0);
    final actualSpacing =
        barCount > 1 ? (size.width - barWidth * barCount) / (barCount - 1) : 0;

    final centerY = size.height / 2;
    final maxBarHeight = mirror ? size.height / 2 : size.height;

    for (int i = 0; i < barCount; i++) {
      final amplitude = amplitudes[i].clamp(0.0, 1.0);
      final barHeight = math.max(
        maxBarHeight * amplitude,
        maxBarHeight * minBarHeight,
      );

      final x = i * (barWidth + actualSpacing);
      final isPlayed = progress != null && (i / barCount) <= progress!;

      final barColor = isPlayed && playedColor != null ? playedColor! : color;

      final paint = Paint()..color = barColor;

      if (mirror) {
        // Draw bar above and below center
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + barWidth / 2, centerY),
            width: barWidth,
            height: barHeight * 2,
          ),
          Radius.circular(barRadius),
        );
        canvas.drawRRect(rect, paint);
      } else {
        // Draw bar from bottom up
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
          Radius.circular(barRadius),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  void _drawLine(Canvas canvas, Size size) {
    if (amplitudes.length < 2) return;

    final centerY = size.height / 2;
    final maxAmplitude = mirror ? size.height / 2 : size.height;

    final path = Path();
    final playedPath = Path();

    for (int i = 0; i < amplitudes.length; i++) {
      final x = (i / (amplitudes.length - 1)) * size.width;
      final amplitude = amplitudes[i].clamp(0.0, 1.0);
      final y = mirror
          ? centerY - (amplitude * maxAmplitude)
          : size.height - (amplitude * maxAmplitude);

      if (i == 0) {
        path.moveTo(x, y);
        if (progress != null) playedPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        if (progress != null && (i / amplitudes.length) <= progress!) {
          playedPath.lineTo(x, y);
        }
      }
    }

    if (mirror) {
      // Draw bottom half
      for (int i = amplitudes.length - 1; i >= 0; i--) {
        final x = (i / (amplitudes.length - 1)) * size.width;
        final amplitude = amplitudes[i].clamp(0.0, 1.0);
        final y = centerY + (amplitude * maxAmplitude);
        path.lineTo(x, y);
        if (progress != null && (i / amplitudes.length) <= progress!) {
          playedPath.lineTo(x, y);
        }
      }
    }

    path.close();

    // Draw unplayed portion
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    // Draw played portion
    if (progress != null && playedColor != null) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress!, size.height));
      canvas.drawPath(
        path,
        Paint()
          ..color = playedColor!
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
    }

    // Draw outline
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawFilled(Canvas canvas, Size size) {
    if (amplitudes.length < 2) return;

    final centerY = size.height / 2;
    final maxAmplitude = mirror ? size.height / 2 : size.height;

    final path = Path();
    path.moveTo(0, mirror ? centerY : size.height);

    for (int i = 0; i < amplitudes.length; i++) {
      final x = (i / (amplitudes.length - 1)) * size.width;
      final amplitude = amplitudes[i].clamp(0.0, 1.0);
      final y = mirror
          ? centerY - (amplitude * maxAmplitude)
          : size.height - (amplitude * maxAmplitude);
      path.lineTo(x, y);
    }

    if (mirror) {
      // Complete the bottom half
      for (int i = amplitudes.length - 1; i >= 0; i--) {
        final x = (i / (amplitudes.length - 1)) * size.width;
        final amplitude = amplitudes[i].clamp(0.0, 1.0);
        final y = centerY + (amplitude * maxAmplitude);
        path.lineTo(x, y);
      }
    } else {
      path.lineTo(size.width, size.height);
    }

    path.close();

    // Create gradient if secondary color provided
    final paint = Paint()..style = PaintingStyle.fill;

    if (secondaryColor != null) {
      paint.shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [color, secondaryColor!],
      );
    } else {
      paint.color = color.withOpacity(0.7);
    }

    canvas.drawPath(path, paint);

    // Draw progress overlay
    if (progress != null && playedColor != null) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress!, size.height));
      canvas.drawPath(
        path,
        Paint()
          ..color = playedColor!
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return amplitudes != oldDelegate.amplitudes ||
        color != oldDelegate.color ||
        secondaryColor != oldDelegate.secondaryColor ||
        style != oldDelegate.style ||
        progress != oldDelegate.progress ||
        playedColor != oldDelegate.playedColor ||
        mirror != oldDelegate.mirror;
  }
}

/// Styles for waveform rendering
enum WaveformStyle {
  /// Render as vertical bars
  bars,

  /// Render as a continuous line
  line,

  /// Render as a filled shape
  filled,
}

/// Widget that displays an audio waveform
class WaveformWidget extends StatelessWidget {
  /// Normalized amplitude data (0.0 to 1.0)
  final List<double> amplitudes;

  /// Primary waveform color
  final Color color;

  /// Secondary color for gradient (optional)
  final Color? secondaryColor;

  /// Rendering style
  final WaveformStyle style;

  /// Current playback progress (0.0 to 1.0)
  final double? progress;

  /// Color for played portion
  final Color? playedColor;

  /// Whether to mirror the waveform
  final bool mirror;

  /// Height of the waveform
  final double height;

  const WaveformWidget({
    super.key,
    required this.amplitudes,
    required this.color,
    this.secondaryColor,
    this.style = WaveformStyle.bars,
    this.progress,
    this.playedColor,
    this.mirror = true,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: WaveformPainter(
          amplitudes: amplitudes,
          color: color,
          secondaryColor: secondaryColor,
          style: style,
          progress: progress,
          playedColor: playedColor,
          mirror: mirror,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Animated waveform that shows audio levels in real-time
class LiveWaveformWidget extends StatefulWidget {
  /// Stream of amplitude values
  final Stream<double>? amplitudeStream;

  /// Number of samples to display
  final int sampleCount;

  /// Primary waveform color
  final Color color;

  /// Rendering style
  final WaveformStyle style;

  /// Height of the waveform
  final double height;

  const LiveWaveformWidget({
    super.key,
    this.amplitudeStream,
    this.sampleCount = 50,
    required this.color,
    this.style = WaveformStyle.bars,
    this.height = 60,
  });

  @override
  State<LiveWaveformWidget> createState() => _LiveWaveformWidgetState();
}

class _LiveWaveformWidgetState extends State<LiveWaveformWidget> {
  late List<double> _samples;

  @override
  void initState() {
    super.initState();
    _samples = List.filled(widget.sampleCount, 0.0);

    widget.amplitudeStream?.listen((amplitude) {
      if (mounted) {
        setState(() {
          _samples.removeAt(0);
          _samples.add(amplitude.clamp(0.0, 1.0));
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WaveformWidget(
      amplitudes: _samples,
      color: widget.color,
      style: widget.style,
      height: widget.height,
      mirror: true,
    );
  }
}
