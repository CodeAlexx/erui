import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/color_grading_models.dart';
import '../models/editor_models.dart';
import '../providers/color_grading_provider.dart';

/// Panel containing color wheels for lift/gamma/gain adjustment.
///
/// Features three circular color wheels for shadows, midtones, and highlights,
/// plus master sliders for exposure, contrast, saturation, and temperature.
class ColorWheelsPanel extends ConsumerStatefulWidget {
  /// Clip ID to edit color grading for
  final EditorId? clipId;

  /// Called when the panel should close
  final VoidCallback? onClose;

  const ColorWheelsPanel({
    super.key,
    this.clipId,
    this.onClose,
  });

  @override
  ConsumerState<ColorWheelsPanel> createState() => _ColorWheelsPanelState();
}

class _ColorWheelsPanelState extends ConsumerState<ColorWheelsPanel> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final colorGrade = widget.clipId != null
        ? ref.watch(clipColorGradeProvider(widget.clipId!))
        : null;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(context),

          // Content
          Expanded(
            child: widget.clipId == null
                ? _buildEmptyState(context)
                : _buildContent(context, colorGrade),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
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
          Icon(Icons.palette, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Color Grading',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.color_lens_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No clip selected',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a clip to adjust colors',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorGrade? grade) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveGrade = grade ?? ColorGrade.defaults();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enable toggle
          Row(
            children: [
              Text(
                'Enable Color Grading',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Switch(
                value: effectiveGrade.enabled,
                onChanged: (value) {
                  if (widget.clipId != null) {
                    ref.read(colorGradingNotifierProvider.notifier).updateGrade(
                          widget.clipId!,
                          effectiveGrade.copyWith(enabled: value),
                        );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Color wheels row
          Row(
            children: [
              Expanded(
                child: _ColorWheelControl(
                  label: 'Lift',
                  sublabel: 'Shadows',
                  value: effectiveGrade.lift,
                  enabled: effectiveGrade.enabled,
                  onChanged: (wheel) {
                    if (widget.clipId != null) {
                      ref
                          .read(colorGradingNotifierProvider.notifier)
                          .updateGrade(
                            widget.clipId!,
                            effectiveGrade.copyWith(lift: wheel),
                          );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ColorWheelControl(
                  label: 'Gamma',
                  sublabel: 'Midtones',
                  value: effectiveGrade.gamma,
                  enabled: effectiveGrade.enabled,
                  onChanged: (wheel) {
                    if (widget.clipId != null) {
                      ref
                          .read(colorGradingNotifierProvider.notifier)
                          .updateGrade(
                            widget.clipId!,
                            effectiveGrade.copyWith(gamma: wheel),
                          );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ColorWheelControl(
                  label: 'Gain',
                  sublabel: 'Highlights',
                  value: effectiveGrade.gain,
                  enabled: effectiveGrade.enabled,
                  onChanged: (wheel) {
                    if (widget.clipId != null) {
                      ref
                          .read(colorGradingNotifierProvider.notifier)
                          .updateGrade(
                            widget.clipId!,
                            effectiveGrade.copyWith(gain: wheel),
                          );
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Master controls
          Text(
            'MASTER CONTROLS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          _SliderControl(
            label: 'Exposure',
            value: effectiveGrade.exposure,
            min: -2.0,
            max: 2.0,
            defaultValue: 0.0,
            enabled: effectiveGrade.enabled,
            onChanged: (value) {
              if (widget.clipId != null) {
                ref.read(colorGradingNotifierProvider.notifier).updateGrade(
                      widget.clipId!,
                      effectiveGrade.copyWith(exposure: value),
                    );
              }
            },
          ),

          _SliderControl(
            label: 'Contrast',
            value: effectiveGrade.contrast,
            min: 0.0,
            max: 2.0,
            defaultValue: 1.0,
            enabled: effectiveGrade.enabled,
            onChanged: (value) {
              if (widget.clipId != null) {
                ref.read(colorGradingNotifierProvider.notifier).updateGrade(
                      widget.clipId!,
                      effectiveGrade.copyWith(contrast: value),
                    );
              }
            },
          ),

          _SliderControl(
            label: 'Saturation',
            value: effectiveGrade.saturation,
            min: 0.0,
            max: 2.0,
            defaultValue: 1.0,
            enabled: effectiveGrade.enabled,
            onChanged: (value) {
              if (widget.clipId != null) {
                ref.read(colorGradingNotifierProvider.notifier).updateGrade(
                      widget.clipId!,
                      effectiveGrade.copyWith(saturation: value),
                    );
              }
            },
          ),

          _SliderControl(
            label: 'Temperature',
            value: effectiveGrade.temperature,
            min: -100.0,
            max: 100.0,
            defaultValue: 0.0,
            enabled: effectiveGrade.enabled,
            onChanged: (value) {
              if (widget.clipId != null) {
                ref.read(colorGradingNotifierProvider.notifier).updateGrade(
                      widget.clipId!,
                      effectiveGrade.copyWith(temperature: value),
                    );
              }
            },
          ),

          _SliderControl(
            label: 'Tint',
            value: effectiveGrade.tint,
            min: -100.0,
            max: 100.0,
            defaultValue: 0.0,
            enabled: effectiveGrade.enabled,
            onChanged: (value) {
              if (widget.clipId != null) {
                ref.read(colorGradingNotifierProvider.notifier).updateGrade(
                      widget.clipId!,
                      effectiveGrade.copyWith(tint: value),
                    );
              }
            },
          ),

          const SizedBox(height: 16),

          // Reset button
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset All'),
              onPressed: effectiveGrade.enabled
                  ? () {
                      if (widget.clipId != null) {
                        ref
                            .read(colorGradingNotifierProvider.notifier)
                            .resetGrade(widget.clipId!);
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual color wheel control
class _ColorWheelControl extends StatefulWidget {
  final String label;
  final String sublabel;
  final ColorWheel value;
  final bool enabled;
  final ValueChanged<ColorWheel>? onChanged;

  const _ColorWheelControl({
    required this.label,
    required this.sublabel,
    required this.value,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<_ColorWheelControl> createState() => _ColorWheelControlState();
}

class _ColorWheelControlState extends State<_ColorWheelControl> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: widget.enabled
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          widget.sublabel,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1,
          child: GestureDetector(
            onPanUpdate: widget.enabled
                ? (details) {
                    final box = context.findRenderObject() as RenderBox;
                    final center = box.size.center(Offset.zero);
                    final radius = box.size.width / 2;
                    final localPos = details.localPosition - center;

                    // Normalize to -1..1 range
                    final x = (localPos.dx / radius).clamp(-1.0, 1.0);
                    final y = (localPos.dy / radius).clamp(-1.0, 1.0);

                    widget.onChanged?.call(ColorWheel(
                      red: x,
                      green: -y, // Invert Y for intuitive control
                      blue: widget.value.blue,
                      master: widget.value.master,
                    ));
                  }
                : null,
            onDoubleTap: widget.enabled
                ? () {
                    widget.onChanged?.call(const ColorWheel.neutral());
                  }
                : null,
            child: CustomPaint(
              painter: _ColorWheelPainter(
                value: widget.value,
                enabled: widget.enabled,
                primaryColor: colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Master slider
        SizedBox(
          height: 24,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor:
                  widget.enabled ? colorScheme.primary : colorScheme.outline,
              inactiveTrackColor: colorScheme.outline.withOpacity(0.3),
              thumbColor:
                  widget.enabled ? colorScheme.primary : colorScheme.outline,
            ),
            child: Slider(
              value: widget.value.master,
              min: -1.0,
              max: 1.0,
              onChanged: widget.enabled
                  ? (value) {
                      widget.onChanged
                          ?.call(widget.value.copyWith(master: value));
                    }
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for color wheel
class _ColorWheelPainter extends CustomPainter {
  final ColorWheel value;
  final bool enabled;
  final Color primaryColor;

  _ColorWheelPainter({
    required this.value,
    required this.enabled,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;

    // Draw color wheel gradient
    final wheelPaint = Paint()..style = PaintingStyle.fill;

    // Draw hue circle segments
    for (int i = 0; i < 360; i += 5) {
      final startAngle = i * math.pi / 180;
      final sweepAngle = 6 * math.pi / 180;

      wheelPaint.shader = SweepGradient(
        colors: [
          HSVColor.fromAHSV(1, i.toDouble(), 0.8, 0.9).toColor(),
          HSVColor.fromAHSV(1, (i + 5) % 360, 0.8, 0.9).toColor(),
        ],
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        wheelPaint,
      );
    }

    // Draw center gradient (white to transparent)
    final centerGradient = RadialGradient(
      colors: [
        enabled ? Colors.grey[800]! : Colors.grey[600]!,
        enabled
            ? Colors.grey[800]!.withOpacity(0.0)
            : Colors.grey[600]!.withOpacity(0.0),
      ],
    );
    canvas.drawCircle(
      center,
      radius * 0.5,
      Paint()
        ..shader = centerGradient
            .createShader(Rect.fromCircle(center: center, radius: radius * 0.5)),
    );

    // Draw border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = enabled ? Colors.grey[600]! : Colors.grey[700]!,
    );

    // Draw crosshairs
    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.grey[500]!.withOpacity(0.5);
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      crossPaint,
    );

    // Draw position indicator
    if (enabled) {
      final indicatorX = center.dx + value.red * radius * 0.9;
      final indicatorY = center.dy - value.green * radius * 0.9;

      canvas.drawCircle(
        Offset(indicatorX, indicatorY),
        8,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(indicatorX, indicatorY),
        8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = primaryColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.enabled != enabled ||
        oldDelegate.primaryColor != primaryColor;
  }
}

/// Slider control with label and value display
class _SliderControl extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final bool enabled;
  final ValueChanged<double>? onChanged;

  const _SliderControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.defaultValue,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDefault = (value - defaultValue).abs() < 0.01;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor:
                    enabled ? colorScheme.primary : colorScheme.outline,
                inactiveTrackColor: colorScheme.onSurface.withOpacity(0.1),
                thumbColor: enabled ? colorScheme.primary : colorScheme.outline,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isDefault ? FontWeight.normal : FontWeight.w600,
                color: isDefault
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.primary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
