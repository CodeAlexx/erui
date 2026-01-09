import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/prompt_region.dart';
import '../../providers/lora_provider.dart';
import 'widgets/region_canvas.dart';

/// State for regional prompting
class RegionalPromptState {
  final List<PromptRegion> regions;
  final String? selectedRegionId;
  final bool enabled;
  final String? backgroundImageUrl;
  final double aspectRatio;

  const RegionalPromptState({
    this.regions = const [],
    this.selectedRegionId,
    this.enabled = false,
    this.backgroundImageUrl,
    this.aspectRatio = 1.0,
  });

  RegionalPromptState copyWith({
    List<PromptRegion>? regions,
    String? selectedRegionId,
    bool? enabled,
    String? backgroundImageUrl,
    double? aspectRatio,
    bool clearSelection = false,
  }) {
    return RegionalPromptState(
      regions: regions ?? this.regions,
      selectedRegionId: clearSelection ? null : (selectedRegionId ?? this.selectedRegionId),
      enabled: enabled ?? this.enabled,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }

  /// Get currently selected region
  PromptRegion? get selectedRegion {
    if (selectedRegionId == null) return null;
    try {
      return regions.firstWhere((r) => r.id == selectedRegionId);
    } catch (_) {
      return null;
    }
  }

  /// Export all regions to combined prompt syntax
  String toPromptSyntax() {
    if (regions.isEmpty) return '';
    return regions.map((r) => r.toPromptSyntax()).join('\n');
  }
}

/// Regional prompt state notifier
class RegionalPromptNotifier extends StateNotifier<RegionalPromptState> {
  RegionalPromptNotifier() : super(const RegionalPromptState());

  /// Toggle regional prompting on/off
  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
  }

  /// Set background image for the canvas
  void setBackgroundImage(String? url) {
    state = state.copyWith(backgroundImageUrl: url);
  }

  /// Set canvas aspect ratio
  void setAspectRatio(double ratio) {
    state = state.copyWith(aspectRatio: ratio);
  }

  /// Add a new region
  void addRegion(PromptRegion region) {
    state = state.copyWith(
      regions: [...state.regions, region],
      selectedRegionId: region.id,
    );
  }

  /// Update an existing region
  void updateRegion(PromptRegion region) {
    state = state.copyWith(
      regions: state.regions.map((r) => r.id == region.id ? region : r).toList(),
    );
  }

  /// Delete a region
  void deleteRegion(String regionId) {
    final newRegions = state.regions.where((r) => r.id != regionId).toList();
    state = state.copyWith(
      regions: newRegions,
      clearSelection: state.selectedRegionId == regionId,
    );
  }

  /// Select a region
  void selectRegion(String? regionId) {
    state = state.copyWith(
      selectedRegionId: regionId,
      clearSelection: regionId == null,
    );
  }

  /// Clear all regions
  void clearAllRegions() {
    state = state.copyWith(regions: [], clearSelection: true);
  }

  /// Update region prompt
  void updateRegionPrompt(String regionId, String prompt) {
    state = state.copyWith(
      regions: state.regions.map((r) {
        if (r.id == regionId) {
          return r.copyWith(prompt: prompt);
        }
        return r;
      }).toList(),
    );
  }

  /// Update region strength
  void updateRegionStrength(String regionId, double strength) {
    state = state.copyWith(
      regions: state.regions.map((r) {
        if (r.id == regionId) {
          return r.copyWith(strength: strength);
        }
        return r;
      }).toList(),
    );
  }

  /// Update region LoRA
  void updateRegionLora(String regionId, String? loraName, double loraStrength) {
    state = state.copyWith(
      regions: state.regions.map((r) {
        if (r.id == regionId) {
          return r.copyWith(loraName: loraName, loraStrength: loraStrength);
        }
        return r;
      }).toList(),
    );
  }

  /// Clear LoRA from region
  void clearRegionLora(String regionId) {
    state = state.copyWith(
      regions: state.regions.map((r) {
        if (r.id == regionId) {
          return r.clearLora();
        }
        return r;
      }).toList(),
    );
  }

  /// Import regions from prompt syntax
  void importFromSyntax(String syntax) {
    final lines = syntax.split('\n').where((l) => l.trim().isNotEmpty);
    final newRegions = <PromptRegion>[];

    for (final line in lines) {
      final region = PromptRegion.fromPromptSyntax(
        line,
        RegionColors.getNextColor(newRegions),
      );
      if (region != null) {
        newRegions.add(region);
      }
    }

    if (newRegions.isNotEmpty) {
      state = state.copyWith(regions: newRegions, enabled: true);
    }
  }
}

/// Provider for regional prompting state
final regionalPromptProvider =
    StateNotifierProvider<RegionalPromptNotifier, RegionalPromptState>((ref) {
  return RegionalPromptNotifier();
});

/// Main regional prompt editor widget
class RegionalPromptEditor extends ConsumerStatefulWidget {
  /// Optional callback when regions change
  final ValueChanged<List<PromptRegion>>? onRegionsChanged;

  const RegionalPromptEditor({super.key, this.onRegionsChanged});

  @override
  ConsumerState<RegionalPromptEditor> createState() => _RegionalPromptEditorState();
}

class _RegionalPromptEditorState extends ConsumerState<RegionalPromptEditor> {
  final _promptController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(regionalPromptProvider);
    final selectedRegion = state.selectedRegion;

    // Update prompt controller when selection changes
    if (selectedRegion != null && _promptController.text != selectedRegion.prompt) {
      _promptController.text = selectedRegion.prompt;
    } else if (selectedRegion == null && _promptController.text.isNotEmpty) {
      _promptController.clear();
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Left side - Canvas
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Toolbar
                _buildToolbar(context, state),
                const Divider(height: 1),
                // Canvas
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: RegionCanvas(
                      regions: state.regions,
                      selectedRegionId: state.selectedRegionId,
                      backgroundImageUrl: state.backgroundImageUrl,
                      aspectRatio: state.aspectRatio,
                      onRegionSelected: (id) {
                        ref.read(regionalPromptProvider.notifier).selectRegion(id);
                      },
                      onRegionCreated: (region) {
                        ref.read(regionalPromptProvider.notifier).addRegion(region);
                        widget.onRegionsChanged?.call([...state.regions, region]);
                      },
                      onRegionUpdated: (region) {
                        ref.read(regionalPromptProvider.notifier).updateRegion(region);
                        widget.onRegionsChanged?.call(
                          state.regions.map((r) => r.id == region.id ? region : r).toList(),
                        );
                      },
                      onRegionDeleted: (id) {
                        ref.read(regionalPromptProvider.notifier).deleteRegion(id);
                        widget.onRegionsChanged?.call(
                          state.regions.where((r) => r.id != id).toList(),
                        );
                      },
                    ),
                  ),
                ),
                // Instructions
                Container(
                  padding: const EdgeInsets.all(8),
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        'Drag to create regions | Click to select | Drag corners to resize',
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(width: 1, color: colorScheme.outlineVariant),
          // Right side - Region list and editor
          SizedBox(
            width: 300,
            child: Column(
              children: [
                // Region list header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.layers, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Regions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const Spacer(),
                      Text('${state.regions.length}', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                // Region list
                Expanded(
                  child: state.regions.isEmpty
                      ? _buildEmptyRegionList(context)
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: state.regions.length,
                          itemBuilder: (context, index) {
                            final region = state.regions[index];
                            return _buildRegionListItem(context, region, state.selectedRegionId == region.id);
                          },
                        ),
                ),
                // Selected region editor
                if (selectedRegion != null) ...[
                  const Divider(height: 1),
                  _buildRegionEditor(context, selectedRegion),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, RegionalPromptState state) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text('Regional Prompting', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          // Add region button
          TextButton.icon(
            onPressed: () {
              // Add centered region
              final region = PromptRegion(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                x: 0.25,
                y: 0.25,
                width: 0.5,
                height: 0.5,
                color: RegionColors.getNextColor(state.regions),
              );
              ref.read(regionalPromptProvider.notifier).addRegion(region);
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Region'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
          const SizedBox(width: 8),
          // Clear all button
          TextButton.icon(
            onPressed: state.regions.isEmpty
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear All Regions?'),
                        content: const Text('This will remove all regions. This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ref.read(regionalPromptProvider.notifier).clearAllRegions();
                            },
                            child: Text('Clear All', style: TextStyle(color: colorScheme.error)),
                          ),
                        ],
                      ),
                    );
                  },
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Clear All'),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
          const SizedBox(width: 8),
          // Export button
          IconButton(
            onPressed: state.regions.isEmpty
                ? null
                : () => _showExportDialog(context, state),
            icon: const Icon(Icons.code, size: 18),
            tooltip: 'Export Prompt Syntax',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRegionList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_outlined, size: 40, color: colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'No regions yet',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Drag on canvas to create',
            style: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionListItem(BuildContext context, PromptRegion region, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ref.read(regionalPromptProvider.notifier).selectRegion(region.id),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // Color indicator
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: region.color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
                ),
              ),
              const SizedBox(width: 8),
              // Region info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      region.prompt.isEmpty ? 'Region ${ref.read(regionalPromptProvider).regions.indexOf(region) + 1}' : region.prompt,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Strength: ${region.strength.toStringAsFixed(2)}${region.loraName != null ? ' | LoRA: ${region.loraName}' : ''}',
                      style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Delete button
              IconButton(
                onPressed: () => ref.read(regionalPromptProvider.notifier).deleteRegion(region.id),
                icon: Icon(Icons.close, size: 16, color: colorScheme.error),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete region',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegionEditor(BuildContext context, PromptRegion region) {
    final colorScheme = Theme.of(context).colorScheme;
    final lorasAsync = ref.watch(loraListProvider);
    final loras = lorasAsync.valueOrNull ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Prompt field
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: region.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text('Edit Region', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            decoration: InputDecoration(
              hintText: 'Enter prompt for this region...',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            style: const TextStyle(fontSize: 12),
            maxLines: 3,
            minLines: 2,
            onChanged: (value) {
              ref.read(regionalPromptProvider.notifier).updateRegionPrompt(region.id, value);
            },
          ),
          const SizedBox(height: 12),

          // Strength slider
          Row(
            children: [
              Text('Strength:', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              Expanded(
                child: Slider(
                  value: region.strength,
                  min: 0.0,
                  max: 1.5,
                  divisions: 30,
                  onChanged: (value) {
                    ref.read(regionalPromptProvider.notifier).updateRegionStrength(region.id, value);
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(region.strength.toStringAsFixed(2), style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),

          // LoRA selector
          const SizedBox(height: 8),
          Row(
            children: [
              Text('LoRA:', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: region.loraName,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  isExpanded: true,
                  hint: const Text('None', style: TextStyle(fontSize: 11)),
                  style: const TextStyle(fontSize: 11),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('None')),
                    ...loras.map((lora) => DropdownMenuItem<String?>(
                      value: lora.name,
                      child: Text(lora.title, overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      ref.read(regionalPromptProvider.notifier).clearRegionLora(region.id);
                    } else {
                      ref.read(regionalPromptProvider.notifier).updateRegionLora(region.id, value, region.loraStrength);
                    }
                  },
                ),
              ),
            ],
          ),

          // LoRA strength (only if LoRA selected)
          if (region.loraName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text('LoRA Strength:', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                Expanded(
                  child: Slider(
                    value: region.loraStrength,
                    min: 0.0,
                    max: 2.0,
                    divisions: 40,
                    onChanged: (value) {
                      ref.read(regionalPromptProvider.notifier).updateRegionLora(region.id, region.loraName, value);
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(region.loraStrength.toStringAsFixed(2), style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],

          // Position info
          const SizedBox(height: 8),
          Text(
            'Position: (${(region.x * 100).toStringAsFixed(0)}%, ${(region.y * 100).toStringAsFixed(0)}%) | Size: ${(region.width * 100).toStringAsFixed(0)}% x ${(region.height * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, RegionalPromptState state) {
    final syntax = state.toPromptSyntax();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Prompt Syntax'),
        content: Container(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Copy this syntax to use in your prompt:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  syntax,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Compact toggle button for enabling regional prompting in the main UI
class RegionalPromptToggle extends ConsumerWidget {
  const RegionalPromptToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(regionalPromptProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: state.enabled ? 'Disable Regional Prompting' : 'Enable Regional Prompting',
      child: InkWell(
        onTap: () {
          ref.read(regionalPromptProvider.notifier).setEnabled(!state.enabled);
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: state.enabled ? colorScheme.primaryContainer : null,
            border: Border.all(
              color: state.enabled ? colorScheme.primary : colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view,
                size: 16,
                color: state.enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Regions${state.regions.isNotEmpty ? ' (${state.regions.length})' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: state.enabled ? FontWeight.w600 : FontWeight.normal,
                  color: state.enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
