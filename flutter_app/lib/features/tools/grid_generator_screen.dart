import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/grid_config.dart';
import '../../providers/generation_provider.dart';
import '../../providers/models_provider.dart';
import '../../services/grid_generator_service.dart';
import '../../widgets/image_viewer_dialog.dart';

/// Grid Generator Screen
///
/// Allows users to configure and run parameter grid explorations.
/// Generates multiple images with varying parameters to find optimal settings.
class GridGeneratorScreen extends ConsumerStatefulWidget {
  final VoidCallback? onCollapse;
  const GridGeneratorScreen({super.key, this.onCollapse});

  @override
  ConsumerState<GridGeneratorScreen> createState() => _GridGeneratorScreenState();
}

class _GridGeneratorScreenState extends ConsumerState<GridGeneratorScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    ref.watch(gridConfigProvider);
    final gridState = ref.watch(gridGeneratorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grid Generator'),
        actions: [
          // Preset menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Load Preset',
            onSelected: (value) => _loadPreset(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'cfg_steps',
                child: Text('CFG vs Steps'),
              ),
              const PopupMenuItem(
                value: 'samplers',
                child: Text('Sampler Comparison'),
              ),
              const PopupMenuItem(
                value: 'seeds',
                child: Text('Seed Exploration'),
              ),
            ],
          ),
          // Reset button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Configuration',
            onPressed: () => ref.read(gridConfigProvider.notifier).reset(),
          ),
          // Collapse button
          if (widget.onCollapse != null)
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Collapse panel',
              onPressed: widget.onCollapse,
            ),
        ],
      ),
      body: Row(
        children: [
          // Left side - Configuration
          SizedBox(
            width: 400,
            child: _ConfigurationPanel(),
          ),
          VerticalDivider(width: 1, color: colorScheme.outlineVariant),
          // Right side - Preview/Results
          Expanded(
            child: gridState.isGenerating || gridState.items.isNotEmpty
                ? _ResultsPanel()
                : _PreviewPanel(),
          ),
        ],
      ),
    );
  }

  void _loadPreset(String preset) {
    final notifier = ref.read(gridConfigProvider.notifier);
    switch (preset) {
      case 'cfg_steps':
        notifier.loadPreset(GridConfigNotifier.cfgStepsPreset());
        break;
      case 'samplers':
        notifier.loadPreset(GridConfigNotifier.samplerPreset());
        break;
      case 'seeds':
        notifier.loadPreset(GridConfigNotifier.seedExplorationPreset());
        break;
    }
  }
}

/// Configuration panel for setting up grid axes
class _ConfigurationPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final gridConfig = ref.watch(gridConfigProvider);
    final gridState = ref.watch(gridGeneratorProvider);
    final baseParams = ref.watch(generationParamsProvider);

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Grid summary
          _GridSummary(config: gridConfig),
          Divider(height: 1, color: colorScheme.outlineVariant),
          // Axes configuration
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // X Axis
                _AxisConfigCard(
                  title: 'X Axis (Required)',
                  axis: gridConfig.xAxis,
                  axisIndex: 0,
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                // Y Axis
                _AxisConfigCard(
                  title: 'Y Axis (Optional)',
                  axis: gridConfig.yAxis,
                  axisIndex: 1,
                  isRequired: false,
                ),
                const SizedBox(height: 16),
                // Z Axis
                _AxisConfigCard(
                  title: 'Z Axis (Optional)',
                  axis: gridConfig.zAxis,
                  axisIndex: 2,
                  isRequired: false,
                ),
                const SizedBox(height: 24),
                // Output options
                _OutputOptions(),
              ],
            ),
          ),
          // Generate button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: gridState.isGenerating
                  ? _GenerationControls()
                  : FilledButton.icon(
                      onPressed: gridConfig.isValid
                          ? () => _startGeneration(ref, gridConfig, baseParams)
                          : null,
                      icon: const Icon(Icons.grid_view),
                      label: Text(
                        gridConfig.isValid
                            ? 'Generate ${gridConfig.totalImages} Images'
                            : 'Configure axes to generate',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _startGeneration(WidgetRef ref, GridConfig config, GenerationParams params) {
    ref.read(gridGeneratorProvider.notifier).startGeneration(config, params);
  }
}

/// Grid summary showing dimensions and image count
class _GridSummary extends StatelessWidget {
  final GridConfig config;

  const _GridSummary({required this.config});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        children: [
          Icon(Icons.grid_4x4, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grid: ${config.dimensionString}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  config.isValid
                      ? '${config.totalImages} images to generate'
                      : 'Configure at least one axis',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (config.isValid)
            Text(
              'Est. ${_formatDuration(config.estimateTime())}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }
}

/// Card for configuring a single axis
class _AxisConfigCard extends ConsumerStatefulWidget {
  final String title;
  final GridAxis? axis;
  final int axisIndex;
  final bool isRequired;

  const _AxisConfigCard({
    required this.title,
    required this.axis,
    required this.axisIndex,
    required this.isRequired,
  });

  @override
  ConsumerState<_AxisConfigCard> createState() => _AxisConfigCardState();
}

class _AxisConfigCardState extends ConsumerState<_AxisConfigCard> {
  final TextEditingController _valuesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.axis != null) {
      _valuesController.text = widget.axis!.values.join(', ');
    }
  }

  @override
  void didUpdateWidget(_AxisConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.axis?.values != oldWidget.axis?.values) {
      _valuesController.text = widget.axis?.values.join(', ') ?? '';
    }
  }

  @override
  void dispose() {
    _valuesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final models = ref.watch(modelsProvider);
    final isActive = widget.axis != null;

    return Card(
      elevation: isActive ? 2 : 0,
      color: isActive
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _getAxisIcon(widget.axisIndex),
                  size: 20,
                  color: isActive ? colorScheme.primary : colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (isActive)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      ref.read(gridConfigProvider.notifier).clearAxis(widget.axisIndex);
                      _valuesController.clear();
                    },
                    tooltip: 'Remove axis',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Parameter selector
            DropdownButtonFormField<String>(
              value: widget.axis?.parameterName,
              decoration: const InputDecoration(
                labelText: 'Parameter',
                isDense: true,
              ),
              items: GridParameter.available.map((p) {
                return DropdownMenuItem(
                  value: p.name,
                  child: Text(p.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _setParameter(value, models);
                }
              },
            ),
            if (isActive) ...[
              const SizedBox(height: 12),
              // Values input
              _ValuesInput(
                controller: _valuesController,
                axis: widget.axis!,
                axisIndex: widget.axisIndex,
              ),
              if (widget.axis!.values.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${widget.axis!.values.length} values',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  IconData _getAxisIcon(int index) {
    switch (index) {
      case 0:
        return Icons.arrow_forward;
      case 1:
        return Icons.arrow_downward;
      case 2:
        return Icons.layers;
      default:
        return Icons.grid_view;
    }
  }

  void _setParameter(String paramName, ModelsState models) {
    final param = GridParameter.getByName(paramName);
    if (param == null) return;

    // Generate default values based on parameter type
    List<String> defaultValues;
    switch (param.type) {
      case GridParameterType.number:
        defaultValues = _generateNumberRange(
          param.min ?? 1.0,
          param.max ?? 10.0,
          4,
        );
        break;
      case GridParameterType.integer:
        defaultValues = _generateIntRange(
          (param.min ?? 1).toInt(),
          (param.max ?? 50).toInt(),
          4,
        );
        break;
      case GridParameterType.selection:
        defaultValues = param.options?.take(4).toList() ?? [];
        break;
      case GridParameterType.model:
        defaultValues = models.checkpoints.take(4).map((m) => m.name).toList();
        break;
      case GridParameterType.text:
        defaultValues = [];
        break;
    }

    final axis = GridAxis(
      parameterName: paramName,
      displayName: param.displayName,
      values: defaultValues,
    );

    _updateAxis(axis);
    _valuesController.text = defaultValues.join(', ');
  }

  List<String> _generateNumberRange(double min, double max, int count) {
    final step = (max - min) / (count - 1);
    return List.generate(count, (i) => (min + step * i).toStringAsFixed(1));
  }

  List<String> _generateIntRange(int min, int max, int count) {
    final step = ((max - min) / (count - 1)).round();
    return List.generate(count, (i) => (min + step * i).toString());
  }

  void _updateAxis(GridAxis axis) {
    final notifier = ref.read(gridConfigProvider.notifier);
    switch (widget.axisIndex) {
      case 0:
        notifier.setXAxis(axis);
        break;
      case 1:
        notifier.setYAxis(axis);
        break;
      case 2:
        notifier.setZAxis(axis);
        break;
    }
  }
}

/// Input for axis values with chips display
class _ValuesInput extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final GridAxis axis;
  final int axisIndex;

  const _ValuesInput({
    required this.controller,
    required this.axis,
    required this.axisIndex,
  });

  @override
  ConsumerState<_ValuesInput> createState() => _ValuesInputState();
}

class _ValuesInputState extends ConsumerState<_ValuesInput> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final param = GridParameter.getByName(widget.axis.parameterName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick value buttons for selection types
        if (param?.type == GridParameterType.selection &&
            param?.options != null) ...[
          Text(
            'Select values:',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: param!.options!.map((option) {
              final isSelected = widget.axis.values.contains(option);
              return FilterChip(
                label: Text(
                  _formatOptionName(option),
                  style: const TextStyle(fontSize: 11),
                ),
                selected: isSelected,
                onSelected: (selected) => _toggleOption(option, selected),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ] else ...[
          // Text input for numeric/text types
          TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              labelText: 'Values (comma-separated)',
              hintText: 'e.g., 1, 3, 5, 7',
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.check, size: 18),
                onPressed: _parseValues,
                tooltip: 'Apply values',
              ),
            ),
            onSubmitted: (_) => _parseValues(),
          ),
          // Quick range buttons for numeric types
          if (param?.type == GridParameterType.integer ||
              param?.type == GridParameterType.number) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                ActionChip(
                  label: const Text('4 values', style: TextStyle(fontSize: 11)),
                  onPressed: () => _generateRange(4),
                  visualDensity: VisualDensity.compact,
                ),
                ActionChip(
                  label: const Text('6 values', style: TextStyle(fontSize: 11)),
                  onPressed: () => _generateRange(6),
                  visualDensity: VisualDensity.compact,
                ),
                ActionChip(
                  label: const Text('8 values', style: TextStyle(fontSize: 11)),
                  onPressed: () => _generateRange(8),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ],
        // Display current values as chips
        if (widget.axis.values.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: widget.axis.values.asMap().entries.map((entry) {
              return Chip(
                label: Text(
                  entry.value,
                  style: const TextStyle(fontSize: 11),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => _removeValue(entry.key),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  String _formatOptionName(String name) {
    return name
        .replaceAll('_', ' ')
        .replaceAll('dpmpp', 'DPM++')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  void _toggleOption(String option, bool selected) {
    final values = List<String>.from(widget.axis.values);
    if (selected) {
      values.add(option);
    } else {
      values.remove(option);
    }
    _updateValues(values);
  }

  void _parseValues() {
    final text = widget.controller.text;
    final values = text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _updateValues(values);
  }

  void _generateRange(int count) {
    final param = GridParameter.getByName(widget.axis.parameterName);
    if (param == null) return;

    List<String> values;
    if (param.type == GridParameterType.integer) {
      final min = (param.min ?? 1).toInt();
      final max = (param.max ?? 50).toInt();
      final step = ((max - min) / (count - 1)).round();
      values = List.generate(count, (i) => (min + step * i).toString());
    } else {
      final min = param.min ?? 1.0;
      final max = param.max ?? 10.0;
      final step = (max - min) / (count - 1);
      values = List.generate(count, (i) => (min + step * i).toStringAsFixed(1));
    }

    widget.controller.text = values.join(', ');
    _updateValues(values);
  }

  void _removeValue(int index) {
    final values = List<String>.from(widget.axis.values);
    values.removeAt(index);
    widget.controller.text = values.join(', ');
    _updateValues(values);
  }

  void _updateValues(List<String> values) {
    final notifier = ref.read(gridConfigProvider.notifier);
    switch (widget.axisIndex) {
      case 0:
        notifier.setXAxisValues(values);
        break;
      case 1:
        notifier.setYAxisValues(values);
        break;
      case 2:
        notifier.setZAxisValues(values);
        break;
    }
  }
}

/// Output options configuration
class _OutputOptions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = ref.watch(gridConfigProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Output Options',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Combine as Grid Image'),
              subtitle: const Text('Create a single image with all results'),
              value: config.combineAsGrid,
              onChanged: (value) {
                ref.read(gridConfigProvider.notifier).setCombineAsGrid(value);
              },
              dense: true,
            ),
            SwitchListTile(
              title: const Text('Show Labels'),
              subtitle: const Text('Add parameter labels to grid'),
              value: config.showLabels,
              onChanged: config.combineAsGrid
                  ? (value) {
                      ref.read(gridConfigProvider.notifier).setShowLabels(value);
                    }
                  : null,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Generation control buttons
class _GenerationControls extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(gridGeneratorProvider);

    return Column(
      children: [
        // Progress indicator
        LinearProgressIndicator(
          value: state.progress,
          backgroundColor: colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 8),
        Text(
          '${state.completedCount} / ${state.totalItems} completed',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: state.isPaused
                  ? FilledButton.icon(
                      onPressed: () => ref.read(gridGeneratorProvider.notifier).resume(),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Resume'),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => ref.read(gridGeneratorProvider.notifier).pause(),
                      icon: const Icon(Icons.pause),
                      label: const Text('Pause'),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => ref.read(gridGeneratorProvider.notifier).cancel(),
                icon: const Icon(Icons.stop),
                label: const Text('Cancel'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Preview panel showing expected grid layout
class _PreviewPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = ref.watch(gridConfigProvider);

    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: Center(
        child: config.isValid
            ? _GridPreview(config: config)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.grid_view_outlined,
                    size: 64,
                    color: colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Configure axes to preview grid',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Visual grid preview
class _GridPreview extends StatelessWidget {
  final GridConfig config;

  const _GridPreview({required this.config});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xAxis = config.xAxis;
    final yAxis = config.yAxis;

    if (xAxis == null || !xAxis.isValid) {
      return const SizedBox.shrink();
    }

    final xCount = xAxis.values.length;
    final yCount = yAxis?.values.length ?? 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Preview: ${config.dimensionString} grid (${config.totalImages} images)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          // X axis label
          if (xAxis.isValid)
            Padding(
              padding: const EdgeInsets.only(left: 80),
              child: Row(
                children: xAxis.values.map((v) {
                  return SizedBox(
                    width: 80,
                    child: Center(
                      child: Text(
                        v,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 4),
          // Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Y axis labels
              if (yAxis != null && yAxis.isValid)
                Column(
                  children: yAxis.values.map((v) {
                    return SizedBox(
                      width: 80,
                      height: 80,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            v,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.secondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                const SizedBox(width: 80),
              // Grid cells
              Column(
                children: List.generate(yCount, (y) {
                  return Row(
                    children: List.generate(xCount, (x) {
                      return Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: colorScheme.outlineVariant,
                            size: 24,
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ],
          ),
          // Axis names
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            children: [
              if (xAxis.isValid)
                Text(
                  'X: ${xAxis.displayName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.primary,
                  ),
                ),
              if (yAxis != null && yAxis.isValid)
                Text(
                  'Y: ${yAxis.displayName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.secondary,
                  ),
                ),
              if (config.zAxis != null && config.zAxis!.isValid)
                Text(
                  'Z: ${config.zAxis!.displayName} (${config.zAxis!.values.length} layers)',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.tertiary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Results panel showing generated images
class _ResultsPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(gridGeneratorProvider);
    final config = state.config;

    if (config == null) {
      return const SizedBox.shrink();
    }

    final xCount = config.xAxis?.values.length ?? 1;
    final yCount = config.yAxis?.values.length ?? 1;

    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          // Header with progress
          Container(
            padding: const EdgeInsets.all(16),
            color: colorScheme.surfaceContainerHigh,
            child: Row(
              children: [
                if (state.isGenerating)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: state.progress,
                    ),
                  )
                else if (state.isCancelled)
                  Icon(Icons.cancel, color: colorScheme.error)
                else
                  Icon(Icons.check_circle, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.isGenerating
                            ? 'Generating...'
                            : state.isCancelled
                                ? 'Cancelled'
                                : 'Complete',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${state.completedCount}/${state.totalItems} images',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!state.isGenerating)
                  TextButton.icon(
                    onPressed: () => ref.read(gridGeneratorProvider.notifier).reset(),
                    icon: const Icon(Icons.add),
                    label: const Text('New Grid'),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          // Results grid
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // X axis labels
                  if (config.xAxis != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 100),
                      child: Row(
                        children: config.xAxis!.values.map((v) {
                          return SizedBox(
                            width: 120,
                            child: Center(
                              child: Text(
                                v,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Grid with results
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Y axis labels
                      if (config.yAxis != null)
                        Column(
                          children: config.yAxis!.values.map((v) {
                            return SizedBox(
                              width: 100,
                              height: 120,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    v,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      else
                        const SizedBox(width: 100),
                      // Result images
                      Column(
                        children: List.generate(yCount, (y) {
                          return Row(
                            children: List.generate(xCount, (x) {
                              final itemIndex = y * xCount + x;
                              if (itemIndex >= state.items.length) {
                                return const SizedBox(width: 120, height: 120);
                              }
                              final item = state.items[itemIndex];
                              return _ResultCell(item: item);
                            }),
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single cell in the results grid
class _ResultCell extends StatelessWidget {
  final GridGenerationItem item;

  const _ResultCell({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _getBorderColor(colorScheme),
          width: item.status == GridItemStatus.generating ? 2 : 1,
        ),
      ),
      child: _buildContent(context, colorScheme),
    );
  }

  Color _getBorderColor(ColorScheme colorScheme) {
    switch (item.status) {
      case GridItemStatus.generating:
        return colorScheme.primary;
      case GridItemStatus.completed:
        return colorScheme.outline;
      case GridItemStatus.failed:
        return colorScheme.error;
      case GridItemStatus.cancelled:
        return colorScheme.outline;
      case GridItemStatus.pending:
        return colorScheme.outlineVariant;
    }
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    switch (item.status) {
      case GridItemStatus.pending:
        return Center(
          child: Icon(
            Icons.hourglass_empty,
            color: colorScheme.outlineVariant,
            size: 24,
          ),
        );
      case GridItemStatus.generating:
        return const Center(
          child: CircularProgressIndicator(),
        );
      case GridItemStatus.completed:
        if (item.imageUrl != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: GestureDetector(
              onTap: () => ImageViewerDialog.show(context, imageUrl: item.imageUrl!),
              child: Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stack) => Center(
                  child: Icon(
                    Icons.broken_image,
                    color: colorScheme.error,
                  ),
                ),
              ),
            ),
          );
        }
        return Center(
          child: Icon(
            Icons.check,
            color: colorScheme.primary,
          ),
        );
      case GridItemStatus.failed:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error),
              if (item.error != null)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    item.error!,
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      case GridItemStatus.cancelled:
        return Center(
          child: Icon(
            Icons.cancel_outlined,
            color: colorScheme.outline,
          ),
        );
    }
  }
}
