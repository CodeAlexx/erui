import 'package:flutter/material.dart';

import '../models/editor_models.dart' hide Clip;
import '../models/transition_models.dart';

/// A grid dialog for selecting transition types.
///
/// Shows thumbnails of each transition type with descriptions.
/// Returns the selected [TransitionType] or null if cancelled.
class TransitionPicker extends StatefulWidget {
  /// Currently selected transition type (for highlighting)
  final TransitionType? selectedType;

  /// Default duration for new transitions
  final EditorTime defaultDuration;

  /// Called when a transition is selected
  final void Function(TransitionType type, EditorTime duration)? onSelect;

  const TransitionPicker({
    super.key,
    this.selectedType,
    this.defaultDuration = const EditorTime(500000), // 0.5 seconds
    this.onSelect,
  });

  /// Show the transition picker as a dialog
  static Future<({TransitionType type, EditorTime duration})?> show(
    BuildContext context, {
    TransitionType? selectedType,
    EditorTime? defaultDuration,
  }) async {
    return showDialog<({TransitionType type, EditorTime duration})>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 500,
            maxHeight: 600,
          ),
          child: TransitionPicker(
            selectedType: selectedType,
            defaultDuration: defaultDuration ?? const EditorTime(500000),
            onSelect: (type, duration) {
              Navigator.of(context).pop((type: type, duration: duration));
            },
          ),
        ),
      ),
    );
  }

  @override
  State<TransitionPicker> createState() => _TransitionPickerState();
}

class _TransitionPickerState extends State<TransitionPicker> {
  late TransitionType _selectedType;
  late double _durationSeconds;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.selectedType ?? TransitionType.crossDissolve;
    _durationSeconds = widget.defaultDuration.inSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.compare_arrows,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'Select Transition',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Transition grid
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transition types grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: TransitionType.values.length,
                  itemBuilder: (context, index) {
                    final type = TransitionType.values[index];
                    return _TransitionCard(
                      type: type,
                      isSelected: type == _selectedType,
                      onTap: () {
                        setState(() {
                          _selectedType = type;
                        });
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Duration slider
                Text(
                  'Duration',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _durationSeconds,
                        min: 0.1,
                        max: 3.0,
                        divisions: 29,
                        label: '${_durationSeconds.toStringAsFixed(1)}s',
                        onChanged: (value) {
                          setState(() {
                            _durationSeconds = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${_durationSeconds.toStringAsFixed(1)}s',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Preset buttons
                Wrap(
                  spacing: 8,
                  children: [0.25, 0.5, 1.0, 1.5, 2.0].map((duration) {
                    return FilterChip(
                      label: Text('${duration}s'),
                      selected: (_durationSeconds - duration).abs() < 0.01,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _durationSeconds = duration;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        // Footer with actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final duration = EditorTime.fromSeconds(_durationSeconds);
                  widget.onSelect?.call(_selectedType, duration);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Card widget for a single transition type in the grid
class _TransitionCard extends StatelessWidget {
  final TransitionType type;
  final bool isSelected;
  final VoidCallback? onTap;

  const _TransitionCard({
    required this.type,
    required this.isSelected,
    this.onTap,
  });

  IconData _getIcon() {
    switch (type) {
      case TransitionType.crossDissolve:
        return Icons.blur_on;
      case TransitionType.fade:
        return Icons.gradient;
      case TransitionType.wipe:
        return Icons.swipe;
      case TransitionType.slideLeft:
        return Icons.arrow_back;
      case TransitionType.slideRight:
        return Icons.arrow_forward;
      case TransitionType.dissolve:
        return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: colorScheme.primary, width: 2)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with animated preview
              _TransitionPreview(
                type: type,
                isSelected: isSelected,
              ),
              const SizedBox(height: 8),
              // Label
              Text(
                type.displayName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated preview of a transition type
class _TransitionPreview extends StatefulWidget {
  final TransitionType type;
  final bool isSelected;

  const _TransitionPreview({
    required this.type,
    required this.isSelected,
  });

  @override
  State<_TransitionPreview> createState() => _TransitionPreviewState();
}

class _TransitionPreviewState extends State<_TransitionPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    if (widget.isSelected) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_TransitionPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.repeat(reverse: true);
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 48,
      height: 36,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _TransitionPreviewPainter(
              type: widget.type,
              progress: _controller.value,
              color1: colorScheme.primary.withOpacity(0.7),
              color2: colorScheme.secondary.withOpacity(0.7),
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for transition preview animation
class _TransitionPreviewPainter extends CustomPainter {
  final TransitionType type;
  final double progress;
  final Color color1;
  final Color color2;

  _TransitionPreviewPainter({
    required this.type,
    required this.progress,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    // Draw based on transition type
    switch (type) {
      case TransitionType.crossDissolve:
      case TransitionType.fade:
        // Opacity blend
        canvas.drawRect(rect, paint1);
        canvas.drawRect(
          rect,
          Paint()..color = color2.withOpacity(progress),
        );
        break;

      case TransitionType.wipe:
      case TransitionType.slideLeft:
        // Wipe from right
        canvas.drawRect(rect, paint1);
        final wipeRect = Rect.fromLTRB(
          size.width * (1 - progress),
          0,
          size.width,
          size.height,
        );
        canvas.drawRect(wipeRect, paint2);
        break;

      case TransitionType.slideRight:
        // Wipe from left
        canvas.drawRect(rect, paint1);
        final wipeRect = Rect.fromLTRB(
          0,
          0,
          size.width * progress,
          size.height,
        );
        canvas.drawRect(wipeRect, paint2);
        break;

      case TransitionType.dissolve:
        // Pattern dissolve (simplified as checkerboard)
        canvas.drawRect(rect, paint1);
        final squareSize = 4.0;
        for (double x = 0; x < size.width; x += squareSize) {
          for (double y = 0; y < size.height; y += squareSize) {
            final show = (x + y) / (size.width + size.height) < progress;
            if (show) {
              canvas.drawRect(
                Rect.fromLTWH(x, y, squareSize, squareSize),
                paint2,
              );
            }
          }
        }
        break;
    }

    // Border
    canvas.drawRect(
      rect,
      Paint()
        ..color = color1.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _TransitionPreviewPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        type != oldDelegate.type ||
        color1 != oldDelegate.color1 ||
        color2 != oldDelegate.color2;
  }
}
