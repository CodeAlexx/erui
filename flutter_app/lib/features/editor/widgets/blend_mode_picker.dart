import 'package:flutter/material.dart';

import '../models/blend_mode_models.dart';

/// Widget for selecting blend modes
class BlendModePicker extends StatelessWidget {
  final VideoBlendMode value;
  final ValueChanged<VideoBlendMode> onChanged;
  final bool showPreview;

  const BlendModePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.showPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VideoBlendMode>(
      initialValue: value,
      tooltip: 'Blend Mode',
      onSelected: onChanged,
      child: _BlendModeChip(mode: value),
      itemBuilder: (context) => _buildMenuItems(context),
    );
  }

  List<PopupMenuEntry<VideoBlendMode>> _buildMenuItems(BuildContext context) {
    final items = <PopupMenuEntry<VideoBlendMode>>[];

    for (final category in BlendModeCategory.all) {
      // Category header
      items.add(PopupMenuItem(
        enabled: false,
        height: 32,
        child: Text(
          category.name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ));

      // Modes in category
      for (final mode in category.modes) {
        items.add(PopupMenuItem(
          value: mode,
          height: 40,
          child: _BlendModeMenuItem(
            mode: mode,
            isSelected: mode == value,
          ),
        ));
      }

      // Divider between categories
      if (category != BlendModeCategory.all.last) {
        items.add(const PopupMenuDivider());
      }
    }

    return items;
  }
}

/// Chip showing current blend mode
class _BlendModeChip extends StatelessWidget {
  final VideoBlendMode mode;

  const _BlendModeChip({required this.mode});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BlendModeIcon(mode: mode, size: 16),
          const SizedBox(width: 6),
          Text(
            mode.displayName,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// Menu item for blend mode
class _BlendModeMenuItem extends StatelessWidget {
  final VideoBlendMode mode;
  final bool isSelected;

  const _BlendModeMenuItem({
    required this.mode,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        _BlendModeIcon(mode: mode, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mode.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (isSelected)
          Icon(
            Icons.check,
            size: 16,
            color: colorScheme.primary,
          ),
      ],
    );
  }
}

/// Visual icon for blend mode
class _BlendModeIcon extends StatelessWidget {
  final VideoBlendMode mode;
  final double size;

  const _BlendModeIcon({
    required this.mode,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _BlendModeIconPainter(mode: mode),
    );
  }
}

/// Custom painter for blend mode icon
class _BlendModeIconPainter extends CustomPainter {
  final VideoBlendMode mode;

  _BlendModeIconPainter({required this.mode});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw two overlapping circles to represent blending
    final circle1 = Rect.fromLTWH(0, 0, size.width * 0.7, size.height * 0.7);
    final circle2 = Rect.fromLTWH(
      size.width * 0.3,
      size.height * 0.3,
      size.width * 0.7,
      size.height * 0.7,
    );

    final paint1 = Paint()
      ..color = _getBaseColor()
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = _getBlendColor()
      ..style = PaintingStyle.fill;

    canvas.drawOval(circle1, paint1);
    canvas.drawOval(circle2, paint2);
  }

  Color _getBaseColor() {
    return Colors.blue.withOpacity(0.7);
  }

  Color _getBlendColor() {
    switch (mode.category) {
      case 'Darken':
        return Colors.black.withOpacity(0.5);
      case 'Lighten':
        return Colors.white.withOpacity(0.7);
      case 'Contrast':
        return Colors.orange.withOpacity(0.6);
      case 'Inversion':
        return Colors.yellow.withOpacity(0.6);
      case 'Stylize':
        return Colors.purple.withOpacity(0.6);
      default:
        return Colors.red.withOpacity(0.5);
    }
  }

  @override
  bool shouldRepaint(covariant _BlendModeIconPainter oldDelegate) {
    return oldDelegate.mode != mode;
  }
}

/// Dropdown for blend mode selection
class BlendModeDropdown extends StatelessWidget {
  final VideoBlendMode value;
  final ValueChanged<VideoBlendMode> onChanged;

  const BlendModeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<VideoBlendMode>(
      value: value,
      underline: const SizedBox(),
      isDense: true,
      items: VideoBlendMode.values.map((mode) {
        return DropdownMenuItem(
          value: mode,
          child: Text(mode.displayName),
        );
      }).toList(),
      onChanged: (mode) {
        if (mode != null) onChanged(mode);
      },
    );
  }
}

/// Grid view of blend modes for visual selection
class BlendModeGrid extends StatelessWidget {
  final VideoBlendMode value;
  final ValueChanged<VideoBlendMode> onChanged;

  const BlendModeGrid({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final category in BlendModeCategory.all) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: category.modes.map((mode) {
                  final isSelected = mode == value;
                  return InkWell(
                    onTap: () => onChanged(mode),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 80,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          _BlendModeIcon(mode: mode, size: 32),
                          const SizedBox(height: 4),
                          Text(
                            mode.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Blend mode with opacity control
class BlendModeWithOpacity extends StatelessWidget {
  final ClipBlendSettings settings;
  final ValueChanged<ClipBlendSettings> onChanged;

  const BlendModeWithOpacity({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: BlendModePicker(
                value: settings.mode,
                onChanged: (mode) {
                  onChanged(settings.copyWith(mode: mode));
                },
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: settings.enabled,
              onChanged: (enabled) {
                onChanged(settings.copyWith(enabled: enabled));
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Opacity',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Slider(
                value: settings.opacity,
                min: 0,
                max: 1,
                onChanged: settings.enabled
                    ? (opacity) {
                        onChanged(settings.copyWith(opacity: opacity));
                      }
                    : null,
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${(settings.opacity * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
