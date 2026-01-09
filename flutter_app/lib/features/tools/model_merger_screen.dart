import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../services/api_service.dart';

/// Model Merger Screen
///
/// Tool for merging two checkpoint models with configurable ratio and method.
/// Supports weighted_sum, add_difference, and sigmoid merge methods.
class ModelMergerScreen extends ConsumerStatefulWidget {
  const ModelMergerScreen({super.key});

  @override
  ConsumerState<ModelMergerScreen> createState() => _ModelMergerScreenState();
}

class _ModelMergerScreenState extends ConsumerState<ModelMergerScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(modelMergerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Merger'),
        actions: [
          // Reset button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Configuration',
            onPressed: () => ref.read(modelMergerProvider.notifier).reset(),
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
          // Right side - Status/Results
          Expanded(
            child: _ResultsPanel(),
          ),
        ],
      ),
    );
  }
}

/// Configuration panel for model merge settings
class _ConfigurationPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(modelMergerProvider);

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Summary header
          _MergerSummary(state: state),
          Divider(height: 1, color: colorScheme.outlineVariant),
          // Controls
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Model A selector
                _ModelSelectorCard(
                  title: 'Model A (Primary)',
                  selectedModel: state.modelA,
                  onChanged: (model) =>
                      ref.read(modelMergerProvider.notifier).setModelA(model),
                  icon: Icons.looks_one,
                  description: 'The primary model to merge from',
                ),
                const SizedBox(height: 16),
                // Model B selector
                _ModelSelectorCard(
                  title: 'Model B (Secondary)',
                  selectedModel: state.modelB,
                  onChanged: (model) =>
                      ref.read(modelMergerProvider.notifier).setModelB(model),
                  icon: Icons.looks_two,
                  description: 'The secondary model to merge into Model A',
                ),
                const SizedBox(height: 16),
                // Merge ratio slider
                _MergeRatioCard(),
                const SizedBox(height: 16),
                // Merge method selector
                _MergeMethodCard(),
                const SizedBox(height: 16),
                // Output name
                _OutputNameCard(),
              ],
            ),
          ),
          // Merge button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: state.isMerging
                  ? _MergeProgress()
                  : FilledButton.icon(
                      onPressed: state.isValid
                          ? () => ref.read(modelMergerProvider.notifier).merge()
                          : null,
                      icon: const Icon(Icons.merge_type),
                      label: Text(
                        state.isValid
                            ? 'Merge Models'
                            : 'Select both models to merge',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary header showing merge configuration
class _MergerSummary extends StatelessWidget {
  final ModelMergerState state;

  const _MergerSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        children: [
          Icon(Icons.merge_type, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Model Merger',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  state.modelA != null && state.modelB != null
                      ? '${state.mergeRatio.toStringAsFixed(2)} ratio using ${_formatMethodName(state.mergeMethod)}'
                      : 'Select two models to merge',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (state.isValid)
            Chip(
              label: Text(
                '${(state.mergeRatio * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11),
              ),
              avatar: const Icon(Icons.tune, size: 16),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  String _formatMethodName(String method) {
    switch (method) {
      case 'weighted_sum':
        return 'Weighted Sum';
      case 'add_difference':
        return 'Add Difference';
      case 'sigmoid':
        return 'Sigmoid';
      default:
        return method;
    }
  }
}

/// Model selector card
class _ModelSelectorCard extends ConsumerWidget {
  final String title;
  final String? selectedModel;
  final ValueChanged<String?> onChanged;
  final IconData icon;
  final String description;

  const _ModelSelectorCard({
    required this.title,
    required this.selectedModel,
    required this.onChanged,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final models = ref.watch(modelsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedModel,
              decoration: const InputDecoration(
                labelText: 'Select Model',
                isDense: true,
              ),
              isExpanded: true,
              items: models.checkpoints.map((model) {
                return DropdownMenuItem(
                  value: model.name,
                  child: Text(
                    model.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// Merge ratio slider card
class _MergeRatioCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(modelMergerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Merge Ratio',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    state.mergeRatio.toStringAsFixed(2),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Controls the blend between models. 0.0 = 100% Model A, 1.0 = 100% Model B',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'A',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: state.mergeRatio,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    onChanged: (value) =>
                        ref.read(modelMergerProvider.notifier).setMergeRatio(value),
                  ),
                ),
                Text(
                  'B',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ),
            // Quick ratio buttons
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickRatioButton(ratio: 0.25, label: '25%'),
                _QuickRatioButton(ratio: 0.5, label: '50%'),
                _QuickRatioButton(ratio: 0.75, label: '75%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick ratio button
class _QuickRatioButton extends ConsumerWidget {
  final double ratio;
  final String label;

  const _QuickRatioButton({required this.ratio, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelMergerProvider);
    final isSelected = (state.mergeRatio - ratio).abs() < 0.001;

    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (selected) {
        ref.read(modelMergerProvider.notifier).setMergeRatio(ratio);
      },
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Merge method selector card
class _MergeMethodCard extends ConsumerWidget {
  static const List<Map<String, String>> _methods = [
    {
      'value': 'weighted_sum',
      'name': 'Weighted Sum',
      'description': 'Simple linear interpolation between models',
    },
    {
      'value': 'add_difference',
      'name': 'Add Difference',
      'description': 'Adds the difference of Model B to Model A',
    },
    {
      'value': 'sigmoid',
      'name': 'Sigmoid',
      'description': 'Uses sigmoid function for smoother blending',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(modelMergerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Merge Method',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: state.mergeMethod,
              decoration: const InputDecoration(
                labelText: 'Method',
                isDense: true,
              ),
              items: _methods.map((method) {
                return DropdownMenuItem(
                  value: method['value'],
                  child: Text(method['name']!),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(modelMergerProvider.notifier).setMergeMethod(value);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              _methods.firstWhere(
                (m) => m['value'] == state.mergeMethod,
                orElse: () => _methods.first,
              )['description']!,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Output name input card
class _OutputNameCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_OutputNameCard> createState() => _OutputNameCardState();
}

class _OutputNameCardState extends ConsumerState<_OutputNameCard> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(modelMergerProvider).outputName;
    _controller.addListener(_updateOutputName);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateOutputName);
    _controller.dispose();
    super.dispose();
  }

  void _updateOutputName() {
    ref.read(modelMergerProvider.notifier).setOutputName(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(modelMergerProvider);

    // Update controller if output name changed externally (e.g., auto-generated)
    if (_controller.text != state.outputName && !_controller.text.contains(state.outputName)) {
      _controller.text = state.outputName;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.label, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Output Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Name for the merged model file',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Output Filename',
                hintText: 'merged_model',
                isDense: true,
                suffixText: '.safetensors',
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                ref.read(modelMergerProvider.notifier).generateOutputName();
                _controller.text = ref.read(modelMergerProvider).outputName;
              },
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('Auto-generate name', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Merge progress indicator
class _MergeProgress extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(modelMergerProvider);

    return Column(
      children: [
        LinearProgressIndicator(
          value: state.progress > 0 ? state.progress : null,
          backgroundColor: colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 8),
        Text(
          state.statusMessage ?? 'Merging models...',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => ref.read(modelMergerProvider.notifier).cancel(),
          icon: const Icon(Icons.stop),
          label: const Text('Cancel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.error,
            side: BorderSide(color: colorScheme.error),
          ),
        ),
      ],
    );
  }
}

/// Results panel showing merge status and history
class _ResultsPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(modelMergerProvider);

    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: state.result != null || state.error != null
          ? _buildResult(context, colorScheme, state)
          : _buildEmptyState(context, colorScheme),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.merge_type_outlined,
            size: 64,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Configure and merge models',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Results will appear here',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildInstructions(colorScheme),
        ],
      ),
    );
  }

  Widget _buildInstructions(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to merge models:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _buildStep(colorScheme, '1', 'Select Model A (primary)'),
          _buildStep(colorScheme, '2', 'Select Model B (secondary)'),
          _buildStep(colorScheme, '3', 'Adjust merge ratio'),
          _buildStep(colorScheme, '4', 'Choose merge method'),
          _buildStep(colorScheme, '5', 'Set output name and merge'),
        ],
      ),
    );
  }

  Widget _buildStep(ColorScheme colorScheme, String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, ColorScheme colorScheme, ModelMergerState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          Card(
            color: state.error != null
                ? colorScheme.errorContainer
                : colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    state.error != null ? Icons.error : Icons.check_circle,
                    color: state.error != null
                        ? colorScheme.onErrorContainer
                        : colorScheme.onPrimaryContainer,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.error != null ? 'Merge Failed' : 'Merge Complete',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: state.error != null
                                ? colorScheme.onErrorContainer
                                : colorScheme.onPrimaryContainer,
                          ),
                        ),
                        if (state.error != null)
                          Text(
                            state.error!,
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                            ),
                          )
                        else if (state.result != null)
                          Text(
                            'Model saved successfully',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Result details
          if (state.result != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merged Model Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(colorScheme, 'Output File', state.result!),
                    _buildDetailRow(colorScheme, 'Model A', state.modelA ?? 'Unknown'),
                    _buildDetailRow(colorScheme, 'Model B', state.modelB ?? 'Unknown'),
                    _buildDetailRow(colorScheme, 'Merge Ratio', state.mergeRatio.toStringAsFixed(2)),
                    _buildDetailRow(colorScheme, 'Method', state.mergeMethod),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () {
                    // Refresh models list
                    final notifier = ProviderScope.containerOf(context).read(modelsProvider.notifier);
                    notifier.loadModels();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Refreshing models list...')),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Models'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    ProviderScope.containerOf(context).read(modelMergerProvider.notifier).reset();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Merge'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(ColorScheme colorScheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// State Management
// ============================================================================

/// Model merger state provider
final modelMergerProvider =
    StateNotifierProvider<ModelMergerNotifier, ModelMergerState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final session = ref.watch(sessionProvider);
  return ModelMergerNotifier(apiService, session);
});

/// Model merger state
class ModelMergerState {
  final String? modelA;
  final String? modelB;
  final double mergeRatio;
  final String mergeMethod;
  final String outputName;
  final bool isMerging;
  final double progress;
  final String? statusMessage;
  final String? result;
  final String? error;

  const ModelMergerState({
    this.modelA,
    this.modelB,
    this.mergeRatio = 0.5,
    this.mergeMethod = 'weighted_sum',
    this.outputName = 'merged_model',
    this.isMerging = false,
    this.progress = 0.0,
    this.statusMessage,
    this.result,
    this.error,
  });

  bool get isValid =>
      modelA != null &&
      modelB != null &&
      modelA != modelB &&
      outputName.isNotEmpty;

  ModelMergerState copyWith({
    String? modelA,
    String? modelB,
    double? mergeRatio,
    String? mergeMethod,
    String? outputName,
    bool? isMerging,
    double? progress,
    String? statusMessage,
    String? result,
    String? error,
  }) {
    return ModelMergerState(
      modelA: modelA ?? this.modelA,
      modelB: modelB ?? this.modelB,
      mergeRatio: mergeRatio ?? this.mergeRatio,
      mergeMethod: mergeMethod ?? this.mergeMethod,
      outputName: outputName ?? this.outputName,
      isMerging: isMerging ?? this.isMerging,
      progress: progress ?? this.progress,
      statusMessage: statusMessage,
      result: result,
      error: error,
    );
  }
}

/// Model merger state notifier
class ModelMergerNotifier extends StateNotifier<ModelMergerState> {
  final ApiService _apiService;
  final SessionState _session;
  bool _shouldCancel = false;

  ModelMergerNotifier(this._apiService, this._session)
      : super(const ModelMergerState());

  /// Set Model A
  void setModelA(String? model) {
    state = state.copyWith(modelA: model);
    _autoGenerateOutputName();
  }

  /// Set Model B
  void setModelB(String? model) {
    state = state.copyWith(modelB: model);
    _autoGenerateOutputName();
  }

  /// Set merge ratio
  void setMergeRatio(double ratio) {
    state = state.copyWith(mergeRatio: ratio.clamp(0.0, 1.0));
  }

  /// Set merge method
  void setMergeMethod(String method) {
    state = state.copyWith(mergeMethod: method);
  }

  /// Set output name
  void setOutputName(String name) {
    state = state.copyWith(outputName: name);
  }

  /// Generate output name from selected models
  void generateOutputName() {
    _autoGenerateOutputName();
  }

  void _autoGenerateOutputName() {
    if (state.modelA == null || state.modelB == null) return;

    final nameA = _extractModelShortName(state.modelA!);
    final nameB = _extractModelShortName(state.modelB!);
    final ratio = (state.mergeRatio * 100).toStringAsFixed(0);

    state = state.copyWith(
      outputName: '${nameA}_${nameB}_merge$ratio',
    );
  }

  String _extractModelShortName(String fullName) {
    // Get filename without path
    final parts = fullName.split('/');
    var name = parts.last;

    // Remove extension
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex > 0) {
      name = name.substring(0, dotIndex);
    }

    // Take first 15 chars max
    if (name.length > 15) {
      name = name.substring(0, 15);
    }

    // Replace spaces and special chars
    name = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    return name;
  }

  /// Reset to initial state
  void reset() {
    _shouldCancel = true;
    state = const ModelMergerState();
  }

  /// Cancel merge operation
  void cancel() {
    _shouldCancel = true;
    state = state.copyWith(
      isMerging: false,
      statusMessage: 'Cancelled',
    );
  }

  /// Perform the merge operation
  Future<void> merge() async {
    if (!state.isValid) return;
    if (_session.sessionId == null) {
      state = state.copyWith(error: 'Not connected');
      return;
    }

    _shouldCancel = false;
    state = state.copyWith(
      isMerging: true,
      progress: 0.0,
      statusMessage: 'Starting merge...',
      result: null,
      error: null,
    );

    try {
      state = state.copyWith(
        progress: 0.1,
        statusMessage: 'Loading Model A...',
      );

      if (_shouldCancel) return;

      state = state.copyWith(
        progress: 0.3,
        statusMessage: 'Loading Model B...',
      );

      if (_shouldCancel) return;

      state = state.copyWith(
        progress: 0.5,
        statusMessage: 'Merging models...',
      );

      // Call the API to merge models
      final response = await _apiService.post<Map<String, dynamic>>(
        '/API/MergeModels',
        data: {
          'session_id': _session.sessionId,
          'model_a': state.modelA,
          'model_b': state.modelB,
          'ratio': state.mergeRatio,
          'method': state.mergeMethod,
          'output_name': state.outputName,
        },
      );

      if (_shouldCancel) return;

      if (!response.isSuccess) {
        state = state.copyWith(
          isMerging: false,
          error: response.error ?? 'Merge failed',
        );
        return;
      }

      state = state.copyWith(
        progress: 0.9,
        statusMessage: 'Saving merged model...',
      );

      final data = response.data;
      String? resultPath;

      if (data != null) {
        resultPath = data['output_path'] as String? ??
            data['path'] as String? ??
            data['result'] as String? ??
            '${state.outputName}.safetensors';
      } else {
        resultPath = '${state.outputName}.safetensors';
      }

      state = state.copyWith(
        isMerging: false,
        progress: 1.0,
        statusMessage: 'Complete',
        result: resultPath,
      );
    } catch (e) {
      state = state.copyWith(
        isMerging: false,
        error: e.toString(),
      );
    }
  }
}
