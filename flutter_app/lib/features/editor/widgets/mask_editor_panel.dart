import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/mask_models.dart';
import '../providers/mask_provider.dart';

/// Panel for editing masks on clips.
///
/// Features:
/// - Shape tool selection
/// - Mask list with reordering
/// - Feather and opacity controls
/// - Invert and enable toggles
/// - Bezier point editing
class MaskEditorPanel extends ConsumerWidget {
  final VoidCallback? onClose;

  const MaskEditorPanel({super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final maskState = ref.watch(maskProvider);
    final isEditing = maskState.isEditing;
    final clipMasks = maskState.activeClipMasks;
    final selectedMask = maskState.selectedMask;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context),

          // Tool bar
          _buildToolBar(context, ref, maskState.currentTool),

          // Mask list
          Expanded(
            child: clipMasks == null || clipMasks.masks.isEmpty
                ? _buildEmptyState(context)
                : _buildMaskList(context, ref, clipMasks.masks, selectedMask?.id),
          ),

          // Properties panel
          if (selectedMask != null)
            _buildPropertiesPanel(context, ref, selectedMask),
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
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.gradient, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Masks',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildToolBar(BuildContext context, WidgetRef ref, MaskType currentTool) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          // Shape tools
          _ToolButton(
            icon: Icons.crop_square,
            tooltip: 'Rectangle',
            isSelected: currentTool == MaskType.rectangle,
            onPressed: () {
              ref.read(maskProvider.notifier).setTool(MaskType.rectangle);
            },
          ),
          _ToolButton(
            icon: Icons.circle_outlined,
            tooltip: 'Ellipse',
            isSelected: currentTool == MaskType.ellipse,
            onPressed: () {
              ref.read(maskProvider.notifier).setTool(MaskType.ellipse);
            },
          ),
          _ToolButton(
            icon: Icons.gesture,
            tooltip: 'Bezier',
            isSelected: currentTool == MaskType.bezier,
            onPressed: () {
              ref.read(maskProvider.notifier).setTool(MaskType.bezier);
            },
          ),
          _ToolButton(
            icon: Icons.brightness_6,
            tooltip: 'Luminosity',
            isSelected: currentTool == MaskType.luminosity,
            onPressed: () {
              ref.read(maskProvider.notifier).setTool(MaskType.luminosity);
            },
          ),

          const Spacer(),

          // Add mask button
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
            onPressed: () {
              _addMask(ref, currentTool);
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _addMask(WidgetRef ref, MaskType type) {
    switch (type) {
      case MaskType.rectangle:
        ref.read(maskProvider.notifier).addRectangleMask();
        break;
      case MaskType.ellipse:
        ref.read(maskProvider.notifier).addEllipseMask();
        break;
      case MaskType.bezier:
        ref.read(maskProvider.notifier).addBezierMask();
        break;
      case MaskType.luminosity:
        ref.read(maskProvider.notifier).addLuminosityMask();
        break;
      case MaskType.freehand:
      case MaskType.colorKey:
        // TODO: Implement
        break;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.layers_clear,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No masks',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a shape tool and click Add',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaskList(
      BuildContext context, WidgetRef ref, List<Mask> masks, EditorId? selectedId) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: masks.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        ref.read(maskProvider.notifier).reorderMasks(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final mask = masks[index];
        final isSelected = mask.id == selectedId;

        return _MaskListItem(
          key: ValueKey(mask.id),
          mask: mask,
          isSelected: isSelected,
          onTap: () {
            ref.read(maskProvider.notifier).selectMask(mask.id);
          },
          onToggleEnabled: () {
            ref.read(maskProvider.notifier).toggleMaskEnabled(mask.id);
          },
          onToggleInverted: () {
            ref.read(maskProvider.notifier).toggleMaskInverted(mask.id);
          },
          onDelete: () {
            ref.read(maskProvider.notifier).removeMask(mask.id);
          },
        );
      },
    );
  }

  Widget _buildPropertiesPanel(BuildContext context, WidgetRef ref, Mask mask) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Properties',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Feather
          _PropertySlider(
            label: 'Feather',
            value: mask.feather,
            min: 0,
            max: 100,
            onChanged: (v) {
              ref.read(maskProvider.notifier).setMaskFeather(mask.id, v);
            },
          ),

          const SizedBox(height: 8),

          // Opacity
          _PropertySlider(
            label: 'Opacity',
            value: mask.opacity * 100,
            min: 0,
            max: 100,
            suffix: '%',
            onChanged: (v) {
              ref.read(maskProvider.notifier).setMaskOpacity(mask.id, v / 100);
            },
          ),

          const SizedBox(height: 8),

          // Expansion
          _PropertySlider(
            label: 'Expansion',
            value: mask.expansion,
            min: -100,
            max: 100,
            onChanged: (v) {
              ref.read(maskProvider.notifier).updateMask(
                mask.copyWith(expansion: v),
              );
            },
          ),

          // Type-specific controls
          const SizedBox(height: 12),
          _buildTypeSpecificControls(context, ref, mask),
        ],
      ),
    );
  }

  Widget _buildTypeSpecificControls(BuildContext context, WidgetRef ref, Mask mask) {
    if (mask is RectangleMask) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PropertySlider(
            label: 'Corner Radius',
            value: mask.cornerRadius * 100,
            min: 0,
            max: 100,
            suffix: '%',
            onChanged: (v) {
              ref.read(maskProvider.notifier).updateMask(
                mask.copyWith(cornerRadius: v / 100),
              );
            },
          ),
          const SizedBox(height: 8),
          _PropertySlider(
            label: 'Rotation',
            value: mask.rotation,
            min: -180,
            max: 180,
            suffix: '°',
            onChanged: (v) {
              ref.read(maskProvider.notifier).updateMask(
                mask.copyWith(rotation: v),
              );
            },
          ),
        ],
      );
    } else if (mask is EllipseMask) {
      return _PropertySlider(
        label: 'Rotation',
        value: mask.rotation,
        min: -180,
        max: 180,
        suffix: '°',
        onChanged: (v) {
          ref.read(maskProvider.notifier).updateMask(
            mask.copyWith(rotation: v),
          );
        },
      );
    } else if (mask is LuminosityMask) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PropertySlider(
            label: 'Low Threshold',
            value: mask.lowThreshold.toDouble(),
            min: 0,
            max: 255,
            onChanged: (v) {
              ref.read(maskProvider.notifier).updateMask(
                mask.copyWith(lowThreshold: v.round()),
              );
            },
          ),
          const SizedBox(height: 8),
          _PropertySlider(
            label: 'High Threshold',
            value: mask.highThreshold.toDouble(),
            min: 0,
            max: 255,
            onChanged: (v) {
              ref.read(maskProvider.notifier).updateMask(
                mask.copyWith(highThreshold: v.round()),
              );
            },
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

/// Tool button for mask types
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Mask list item
class _MaskListItem extends StatelessWidget {
  final Mask mask;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onToggleEnabled;
  final VoidCallback onToggleInverted;
  final VoidCallback onDelete;

  const _MaskListItem({
    super.key,
    required this.mask,
    required this.isSelected,
    required this.onTap,
    required this.onToggleEnabled,
    required this.onToggleInverted,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primaryContainer.withOpacity(0.5) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isSelected ? Border.all(color: colorScheme.primary.withOpacity(0.5)) : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          mask.type.icon,
          size: 18,
          color: mask.enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          mask.name,
          style: TextStyle(
            fontSize: 12,
            color: mask.enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          mask.type.displayName,
          style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Invert toggle
            IconButton(
              icon: Icon(
                mask.inverted ? Icons.invert_colors : Icons.invert_colors_off,
                size: 16,
                color: mask.inverted ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              onPressed: onToggleInverted,
              tooltip: 'Invert',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            // Enable toggle
            IconButton(
              icon: Icon(
                mask.enabled ? Icons.visibility : Icons.visibility_off,
                size: 16,
              ),
              onPressed: onToggleEnabled,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            // Delete
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: colorScheme.error),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            // Drag handle
            ReorderableDragStartListener(
              index: 0,
              child: Icon(Icons.drag_handle, size: 18, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Property slider widget
class _PropertySlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String? suffix;
  final ValueChanged<double> onChanged;

  const _PropertySlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            '${value.round()}${suffix ?? ''}',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
