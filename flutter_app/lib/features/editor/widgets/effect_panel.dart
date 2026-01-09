import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/effect_models.dart';
import '../providers/effects_provider.dart';

/// Panel for managing video effects on the selected clip.
///
/// Shows a list of applied effects with parameter sliders.
/// Supports adding, removing, reordering, and toggling effects.
class EffectPanel extends ConsumerStatefulWidget {
  /// ID of the clip to edit effects for (null for no selection)
  final EditorId? clipId;

  /// Called when the panel should be closed
  final VoidCallback? onClose;

  const EffectPanel({
    super.key,
    this.clipId,
    this.onClose,
  });

  @override
  ConsumerState<EffectPanel> createState() => _EffectPanelState();
}

class _EffectPanelState extends ConsumerState<EffectPanel> {
  /// Currently expanded effect ID (for showing parameters)
  EditorId? _expandedEffectId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Get effects for the current clip
    final clipEffects = widget.clipId != null
        ? ref.watch(clipEffectsProvider(widget.clipId!))
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
                : _buildEffectsList(context, clipEffects),
          ),

          // Add effect button
          if (widget.clipId != null) _buildAddEffectButton(context),
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
          Icon(Icons.auto_fix_high, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Effects',
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
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
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
            Icons.movie_filter_outlined,
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
            'Select a clip to add effects',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEffectsList(BuildContext context, ClipEffects? clipEffects) {
    final colorScheme = Theme.of(context).colorScheme;

    if (clipEffects == null || clipEffects.effects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 48,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No effects applied',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Click + to add an effect',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: clipEffects.effects.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        ref
            .read(effectsNotifierProvider.notifier)
            .reorderEffect(widget.clipId!, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final effect = clipEffects.effects[index];
        return _EffectCard(
          key: ValueKey(effect.id),
          effect: effect,
          isExpanded: effect.id == _expandedEffectId,
          onTap: () {
            setState(() {
              _expandedEffectId =
                  _expandedEffectId == effect.id ? null : effect.id;
            });
          },
          onToggle: (enabled) {
            ref.read(effectsNotifierProvider.notifier).updateEffect(
                  widget.clipId!,
                  effect.copyWith(enabled: enabled),
                );
          },
          onParameterChanged: (paramName, value) {
            ref.read(effectsNotifierProvider.notifier).updateEffect(
                  widget.clipId!,
                  effect.withParameter(paramName, value),
                );
          },
          onDelete: () {
            ref.read(effectsNotifierProvider.notifier).removeEffect(
                  widget.clipId!,
                  effect.id,
                );
          },
          onReset: () {
            ref.read(effectsNotifierProvider.notifier).updateEffect(
                  widget.clipId!,
                  VideoEffect.defaultFor(effect.type, id: effect.id),
                );
          },
        );
      },
    );
  }

  Widget _buildAddEffectButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: FilledButton.tonalIcon(
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Effect'),
        onPressed: () => _showAddEffectDialog(context),
      ),
    );
  }

  void _showAddEffectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddEffectDialog(
        onSelect: (type) {
          if (widget.clipId != null) {
            final effect = VideoEffect.defaultFor(type);
            ref.read(effectsNotifierProvider.notifier).addEffect(
                  widget.clipId!,
                  effect,
                );
            setState(() {
              _expandedEffectId = effect.id;
            });
          }
        },
      ),
    );
  }
}

/// Card widget for a single effect in the list
class _EffectCard extends StatelessWidget {
  final VideoEffect effect;
  final bool isExpanded;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;
  final void Function(String paramName, double value)? onParameterChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onReset;

  const _EffectCard({
    super.key,
    required this.effect,
    required this.isExpanded,
    this.onTap,
    this.onToggle,
    this.onParameterChanged,
    this.onDelete,
    this.onReset,
  });

  IconData _getIcon() {
    switch (effect.type) {
      case EffectType.brightness:
        return Icons.brightness_6;
      case EffectType.contrast:
        return Icons.contrast;
      case EffectType.saturation:
        return Icons.palette;
      case EffectType.blur:
        return Icons.blur_on;
      case EffectType.sharpen:
        return Icons.deblur;
      case EffectType.colorCorrect:
        return Icons.color_lens;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: effect.enabled
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainerHigh.withOpacity(0.5),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Drag handle
                  ReorderableDragStartListener(
                    index: 0,
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Effect icon
                  Icon(
                    _getIcon(),
                    size: 20,
                    color: effect.enabled
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  // Effect name
                  Expanded(
                    child: Text(
                      effect.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: effect.enabled
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Toggle switch
                  Switch(
                    value: effect.enabled,
                    onChanged: onToggle,
                  ),
                  // Expand/collapse indicator
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Parameters (when expanded)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // Parameter sliders
                  ...VideoEffect.getParameterNames(effect.type).map((paramName) {
                    final range =
                        VideoEffect.getParameterRange(effect.type, paramName);
                    final value = effect.parameters[paramName] ?? range.defaultVal;
                    final label =
                        VideoEffect.getParameterLabel(effect.type, paramName);

                    return _ParameterSlider(
                      label: label,
                      value: value,
                      min: range.min,
                      max: range.max,
                      defaultValue: range.defaultVal,
                      onChanged: effect.enabled
                          ? (v) => onParameterChanged?.call(paramName, v)
                          : null,
                    );
                  }),
                  const SizedBox(height: 8),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onReset,
                        child: const Text('Reset'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.error,
                        ),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Slider widget for an effect parameter
class _ParameterSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final ValueChanged<double>? onChanged;

  const _ParameterSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.defaultValue,
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
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: onChanged != null
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                inactiveTrackColor: colorScheme.onSurface.withOpacity(0.1),
                thumbColor: onChanged != null
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              value.toStringAsFixed(0),
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

/// Dialog for selecting an effect type to add
class _AddEffectDialog extends StatelessWidget {
  final ValueChanged<EffectType>? onSelect;

  const _AddEffectDialog({this.onSelect});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Group effects by category
    final colorEffects = [
      EffectType.brightness,
      EffectType.contrast,
      EffectType.saturation,
      EffectType.colorCorrect,
    ];
    final stylizeEffects = [
      EffectType.blur,
      EffectType.sharpen,
    ];

    return AlertDialog(
      title: const Text('Add Effect'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color category
            Text(
              'Color',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: colorEffects.map((type) {
                return _EffectChip(
                  type: type,
                  onTap: () {
                    onSelect?.call(type);
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Stylize category
            Text(
              'Stylize',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stylizeEffects.map((type) {
                return _EffectChip(
                  type: type,
                  onTap: () {
                    onSelect?.call(type);
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Chip widget for an effect type in the add dialog
class _EffectChip extends StatelessWidget {
  final EffectType type;
  final VoidCallback? onTap;

  const _EffectChip({
    required this.type,
    this.onTap,
  });

  IconData _getIcon() {
    switch (type) {
      case EffectType.brightness:
        return Icons.brightness_6;
      case EffectType.contrast:
        return Icons.contrast;
      case EffectType.saturation:
        return Icons.palette;
      case EffectType.blur:
        return Icons.blur_on;
      case EffectType.sharpen:
        return Icons.deblur;
      case EffectType.colorCorrect:
        return Icons.color_lens;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(_getIcon(), size: 18),
      label: Text(type.displayName),
      onPressed: onTap,
    );
  }
}
