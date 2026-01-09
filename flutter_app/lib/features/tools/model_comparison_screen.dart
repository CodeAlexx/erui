import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/generation_provider.dart';
import '../../providers/models_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/image_viewer_dialog.dart';

/// Model Comparison Screen
///
/// Allows users to compare outputs from different models using the same prompt.
/// Select 2-4 models, use same seed, and generate to see side-by-side results.
class ModelComparisonScreen extends ConsumerStatefulWidget {
  const ModelComparisonScreen({super.key});

  @override
  ConsumerState<ModelComparisonScreen> createState() => _ModelComparisonScreenState();
}

class _ModelComparisonScreenState extends ConsumerState<ModelComparisonScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final comparisonState = ref.watch(modelComparisonProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Comparison'),
        actions: [
          // Reset button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: () => ref.read(modelComparisonProvider.notifier).reset(),
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
            child: comparisonState.isGenerating || comparisonState.results.isNotEmpty
                ? _ResultsPanel()
                : _PreviewPanel(),
          ),
        ],
      ),
    );
  }
}

/// Configuration panel for model selection and parameters
class _ConfigurationPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final comparisonState = ref.watch(modelComparisonProvider);
    final baseParams = ref.watch(generationParamsProvider);

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Summary
          _ComparisonSummary(state: comparisonState),
          Divider(height: 1, color: colorScheme.outlineVariant),
          // Configuration
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Model selection
                _ModelSelectionCard(),
                const SizedBox(height: 16),
                // Seed options
                _SeedOptionsCard(),
                const SizedBox(height: 16),
                // Prompt display
                _PromptPreviewCard(prompt: baseParams.prompt),
              ],
            ),
          ),
          // Generate button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: comparisonState.isGenerating
                  ? _GenerationControls()
                  : FilledButton.icon(
                      onPressed: comparisonState.selectedModels.length >= 2
                          ? () => ref.read(modelComparisonProvider.notifier)
                              .startComparison(baseParams)
                          : null,
                      icon: const Icon(Icons.compare),
                      label: Text(
                        comparisonState.selectedModels.length >= 2
                            ? 'Compare ${comparisonState.selectedModels.length} Models'
                            : 'Select at least 2 models',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary showing selected models count
class _ComparisonSummary extends StatelessWidget {
  final ModelComparisonState state;

  const _ComparisonSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        children: [
          Icon(Icons.compare_arrows, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.selectedModels.length} Models Selected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  state.selectedModels.length >= 2
                      ? 'Ready to compare (min 2, max 4)'
                      : 'Select 2-4 models to compare',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (state.useSameSeed)
            Chip(
              label: Text(
                'Seed: ${state.seed == -1 ? "Random" : state.seed}',
                style: const TextStyle(fontSize: 11),
              ),
              avatar: const Icon(Icons.casino, size: 16),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// Card for selecting models to compare
class _ModelSelectionCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final models = ref.watch(modelsProvider);
    final comparisonState = ref.watch(modelComparisonProvider);
    final selectedModels = comparisonState.selectedModels;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.view_module, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Select Models',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${selectedModels.length}/4',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Model dropdown to add
            if (selectedModels.length < 4)
              DropdownButtonFormField<String>(
                value: null,
                decoration: const InputDecoration(
                  labelText: 'Add Model',
                  isDense: true,
                ),
                items: models.checkpoints
                    .where((m) => !selectedModels.contains(m.name))
                    .map((m) {
                  return DropdownMenuItem(
                    value: m.name,
                    child: Text(
                      m.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(modelComparisonProvider.notifier).addModel(value);
                  }
                },
              ),
            const SizedBox(height: 12),
            // Selected models list
            if (selectedModels.isNotEmpty) ...[
              Text(
                'Selected:',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedModels.asMap().entries.map((entry) {
                  final index = entry.key;
                  final modelName = entry.value;
                  final displayName = _getDisplayName(modelName);
                  final color = _getModelColor(index, colorScheme);

                  return Chip(
                    label: Text(
                      displayName,
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () =>
                        ref.read(modelComparisonProvider.notifier).removeModel(modelName),
                    side: BorderSide(color: color),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getDisplayName(String modelName) {
    final parts = modelName.split('/');
    final filename = parts.last;
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
  }

  Color _getModelColor(int index, ColorScheme colorScheme) {
    final colors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
    return colors[index % colors.length];
  }
}

/// Card for seed configuration options
class _SeedOptionsCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SeedOptionsCard> createState() => _SeedOptionsCardState();
}

class _SeedOptionsCardState extends ConsumerState<_SeedOptionsCard> {
  final TextEditingController _seedController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final seed = ref.read(modelComparisonProvider).seed;
    _seedController.text = seed == -1 ? '' : seed.toString();
  }

  @override
  void dispose() {
    _seedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final comparisonState = ref.watch(modelComparisonProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.casino, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Seed Options',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Use Same Seed for All'),
              subtitle: const Text('Ensures consistent comparison'),
              value: comparisonState.useSameSeed,
              onChanged: (value) {
                ref.read(modelComparisonProvider.notifier).setUseSameSeed(value);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            if (comparisonState.useSameSeed) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _seedController,
                      decoration: const InputDecoration(
                        labelText: 'Seed',
                        hintText: 'Leave empty for random',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final seed = int.tryParse(value) ?? -1;
                        ref.read(modelComparisonProvider.notifier).setSeed(seed);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.shuffle),
                    tooltip: 'Generate random seed',
                    onPressed: () {
                      final random = DateTime.now().millisecondsSinceEpoch % 2147483647;
                      _seedController.text = random.toString();
                      ref.read(modelComparisonProvider.notifier).setSeed(random);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card showing the current prompt that will be used
class _PromptPreviewCard extends StatelessWidget {
  final String prompt;

  const _PromptPreviewCard({required this.prompt});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Prompt',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                prompt.isEmpty ? 'No prompt set (use Generate tab)' : prompt,
                style: TextStyle(
                  fontSize: 13,
                  color: prompt.isEmpty
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This prompt will be used for all model comparisons',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generation control buttons during comparison
class _GenerationControls extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(modelComparisonProvider);

    return Column(
      children: [
        LinearProgressIndicator(
          value: state.progress,
          backgroundColor: colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 8),
        Text(
          '${state.completedCount} / ${state.totalCount} models completed',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: state.isPaused
                  ? FilledButton.icon(
                      onPressed: () =>
                          ref.read(modelComparisonProvider.notifier).resume(),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Resume'),
                    )
                  : OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(modelComparisonProvider.notifier).pause(),
                      icon: const Icon(Icons.pause),
                      label: const Text('Pause'),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    ref.read(modelComparisonProvider.notifier).cancel(),
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

/// Preview panel before generation
class _PreviewPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final comparisonState = ref.watch(modelComparisonProvider);
    final selectedModels = comparisonState.selectedModels;

    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: Center(
        child: selectedModels.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.compare_arrows_outlined,
                    size: 64,
                    color: colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select models to compare',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Results will be shown side by side',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : _PreviewGrid(models: selectedModels),
      ),
    );
  }
}

/// Grid preview of selected models
class _PreviewGrid extends StatelessWidget {
  final List<String> models;

  const _PreviewGrid({required this.models});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Preview: ${models.length} model comparison',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: models.asMap().entries.map((entry) {
              final index = entry.key;
              final modelName = entry.value;
              final displayName = _getDisplayName(modelName);
              final color = _getModelColor(index, colorScheme);

              return Container(
                width: 160,
                height: 200,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      color: colorScheme.outlineVariant,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getDisplayName(String modelName) {
    final parts = modelName.split('/');
    final filename = parts.last;
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
  }

  Color _getModelColor(int index, ColorScheme colorScheme) {
    final colors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
    return colors[index % colors.length];
  }
}

/// Results panel showing generated images
class _ResultsPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(modelComparisonProvider);

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
                        '${state.completedCount}/${state.totalCount} models',
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
                    onPressed: () =>
                        ref.read(modelComparisonProvider.notifier).reset(),
                    icon: const Icon(Icons.add),
                    label: const Text('New Comparison'),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          // Results grid
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: state.results.asMap().entries.map((entry) {
                  final index = entry.key;
                  final result = entry.value;
                  return _ResultCard(
                    result: result,
                    index: index,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single result card with model label
class _ResultCard extends StatelessWidget {
  final ModelComparisonResult result;
  final int index;

  const _ResultCard({
    required this.result,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _getModelColor(index, colorScheme);
    final displayName = _getDisplayName(result.modelName);

    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.status == ComparisonItemStatus.generating
              ? colorScheme.primary
              : color,
          width: result.status == ComparisonItemStatus.generating ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Model label header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Image area
          SizedBox(
            height: 256,
            child: _buildContent(context, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    switch (result.status) {
      case ComparisonItemStatus.pending:
        return Center(
          child: Icon(
            Icons.hourglass_empty,
            color: colorScheme.outlineVariant,
            size: 32,
          ),
        );
      case ComparisonItemStatus.generating:
        return const Center(
          child: CircularProgressIndicator(),
        );
      case ComparisonItemStatus.completed:
        if (result.imageUrl != null) {
          return ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(7),
              bottomRight: Radius.circular(7),
            ),
            child: GestureDetector(
              onTap: () => ImageViewerDialog.show(context, imageUrl: result.imageUrl!),
              child: Image.network(
                result.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stack) => Center(
                  child: Icon(
                    Icons.broken_image,
                    color: colorScheme.error,
                    size: 32,
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
            size: 32,
          ),
        );
      case ComparisonItemStatus.failed:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 32),
              if (result.error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    result.error!,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      case ComparisonItemStatus.cancelled:
        return Center(
          child: Icon(
            Icons.cancel_outlined,
            color: colorScheme.outline,
            size: 32,
          ),
        );
    }
  }

  String _getDisplayName(String modelName) {
    final parts = modelName.split('/');
    final filename = parts.last;
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
  }

  Color _getModelColor(int index, ColorScheme colorScheme) {
    final colors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
    return colors[index % colors.length];
  }
}

// ============================================================================
// State Management
// ============================================================================

/// Model comparison state provider
final modelComparisonProvider =
    StateNotifierProvider<ModelComparisonNotifier, ModelComparisonState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final session = ref.watch(sessionProvider);
  return ModelComparisonNotifier(apiService, session);
});

/// Status of a comparison result
enum ComparisonItemStatus {
  pending,
  generating,
  completed,
  failed,
  cancelled,
}

/// Result for a single model comparison
class ModelComparisonResult {
  final String modelName;
  final ComparisonItemStatus status;
  final String? imageUrl;
  final String? error;
  final int? seed;

  const ModelComparisonResult({
    required this.modelName,
    this.status = ComparisonItemStatus.pending,
    this.imageUrl,
    this.error,
    this.seed,
  });

  ModelComparisonResult copyWith({
    String? modelName,
    ComparisonItemStatus? status,
    String? imageUrl,
    String? error,
    int? seed,
  }) {
    return ModelComparisonResult(
      modelName: modelName ?? this.modelName,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      error: error ?? this.error,
      seed: seed ?? this.seed,
    );
  }
}

/// State for model comparison
class ModelComparisonState {
  final List<String> selectedModels;
  final bool useSameSeed;
  final int seed;
  final List<ModelComparisonResult> results;
  final int currentIndex;
  final bool isGenerating;
  final bool isPaused;
  final bool isCancelled;
  final String? error;

  const ModelComparisonState({
    this.selectedModels = const [],
    this.useSameSeed = true,
    this.seed = -1,
    this.results = const [],
    this.currentIndex = 0,
    this.isGenerating = false,
    this.isPaused = false,
    this.isCancelled = false,
    this.error,
  });

  ModelComparisonState copyWith({
    List<String>? selectedModels,
    bool? useSameSeed,
    int? seed,
    List<ModelComparisonResult>? results,
    int? currentIndex,
    bool? isGenerating,
    bool? isPaused,
    bool? isCancelled,
    String? error,
  }) {
    return ModelComparisonState(
      selectedModels: selectedModels ?? this.selectedModels,
      useSameSeed: useSameSeed ?? this.useSameSeed,
      seed: seed ?? this.seed,
      results: results ?? this.results,
      currentIndex: currentIndex ?? this.currentIndex,
      isGenerating: isGenerating ?? this.isGenerating,
      isPaused: isPaused ?? this.isPaused,
      isCancelled: isCancelled ?? this.isCancelled,
      error: error,
    );
  }

  int get totalCount => selectedModels.length;

  int get completedCount =>
      results.where((r) => r.status == ComparisonItemStatus.completed).length;

  double get progress => totalCount > 0 ? completedCount / totalCount : 0.0;
}

/// Model comparison state notifier
class ModelComparisonNotifier extends StateNotifier<ModelComparisonState> {
  final ApiService _apiService;
  final SessionState _session;
  bool _shouldCancel = false;
  String? _currentGenerationId;

  ModelComparisonNotifier(this._apiService, this._session)
      : super(const ModelComparisonState());

  /// Add a model to comparison
  void addModel(String modelName) {
    if (state.selectedModels.length >= 4) return;
    if (state.selectedModels.contains(modelName)) return;

    state = state.copyWith(
      selectedModels: [...state.selectedModels, modelName],
    );
  }

  /// Remove a model from comparison
  void removeModel(String modelName) {
    state = state.copyWith(
      selectedModels: state.selectedModels.where((m) => m != modelName).toList(),
    );
  }

  /// Set whether to use same seed for all
  void setUseSameSeed(bool value) {
    state = state.copyWith(useSameSeed: value);
  }

  /// Set the seed value
  void setSeed(int value) {
    state = state.copyWith(seed: value);
  }

  /// Start the comparison
  Future<void> startComparison(GenerationParams baseParams) async {
    if (_session.sessionId == null) {
      state = state.copyWith(error: 'Not connected');
      return;
    }

    if (state.selectedModels.length < 2) {
      state = state.copyWith(error: 'Select at least 2 models');
      return;
    }

    _shouldCancel = false;

    // Generate seed if needed
    int seed = state.seed;
    if (state.useSameSeed && seed == -1) {
      seed = DateTime.now().millisecondsSinceEpoch % 2147483647;
    }

    // Create results list
    final results = state.selectedModels.map((modelName) {
      return ModelComparisonResult(
        modelName: modelName,
        status: ComparisonItemStatus.pending,
        seed: state.useSameSeed ? seed : null,
      );
    }).toList();

    state = state.copyWith(
      seed: seed,
      results: results,
      currentIndex: 0,
      isGenerating: true,
      isPaused: false,
      isCancelled: false,
      error: null,
    );

    // Process each model
    await _processQueue(baseParams);
  }

  /// Process the generation queue
  Future<void> _processQueue(GenerationParams baseParams) async {
    while (state.currentIndex < state.results.length &&
        !_shouldCancel &&
        !state.isPaused) {
      final result = state.results[state.currentIndex];

      // Update status to generating
      _updateResultStatus(state.currentIndex, ComparisonItemStatus.generating);

      try {
        final imageUrl = await _generateSingle(baseParams, result.modelName);

        if (imageUrl != null) {
          _updateResult(
            state.currentIndex,
            (r) => r.copyWith(
              status: ComparisonItemStatus.completed,
              imageUrl: imageUrl,
            ),
          );
        } else if (_shouldCancel) {
          _updateResultStatus(state.currentIndex, ComparisonItemStatus.cancelled);
        } else {
          _updateResult(
            state.currentIndex,
            (r) => r.copyWith(
              status: ComparisonItemStatus.failed,
              error: 'Generation failed',
            ),
          );
        }
      } catch (e) {
        _updateResult(
          state.currentIndex,
          (r) => r.copyWith(
            status: ComparisonItemStatus.failed,
            error: e.toString(),
          ),
        );
      }

      // Move to next
      if (!_shouldCancel && !state.isPaused) {
        state = state.copyWith(currentIndex: state.currentIndex + 1);
      }
    }

    // Mark as complete
    if (!state.isPaused) {
      state = state.copyWith(
        isGenerating: false,
        isCancelled: _shouldCancel,
      );
    }
  }

  /// Generate a single image
  Future<String?> _generateSingle(
      GenerationParams baseParams, String modelName) async {
    try {
      final apiParams = <String, dynamic>{
        'session_id': _session.sessionId,
        'prompt': baseParams.prompt,
        'negativeprompt': baseParams.negativePrompt,
        'model': modelName,
        'width': baseParams.width,
        'height': baseParams.height,
        'steps': baseParams.steps,
        'cfgscale': baseParams.cfgScale,
        'seed': state.useSameSeed ? state.seed : baseParams.seed,
        'sampler': baseParams.sampler,
        'scheduler': baseParams.scheduler,
        'images': 1,
      };

      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/GenerateText2ImageWS',
        data: apiParams,
      );

      if (!response.isSuccess || response.data == null) {
        return null;
      }

      final data = response.data!;
      final generationId = data['generation_id'] as String?;

      // Handle async generation
      if (data['status'] == 'generating' && generationId != null) {
        _currentGenerationId = generationId;
        return await _pollForResult(generationId);
      }

      // Handle sync completion
      if (data['status'] == 'completed' && data['images'] != null) {
        final images = (data['images'] as List).cast<String>();
        if (images.isNotEmpty) {
          return '${_apiService.baseUrl}${images.first}';
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Poll for generation result
  Future<String?> _pollForResult(String generationId) async {
    final completer = Completer<String?>();
    const pollInterval = Duration(milliseconds: 500);
    const maxPolls = 600; // 5 minutes max
    int pollCount = 0;

    Timer.periodic(pollInterval, (timer) async {
      if (_shouldCancel || pollCount >= maxPolls) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        return;
      }

      pollCount++;

      try {
        final response = await _apiService.post<Map<String, dynamic>>(
          '/api/GetProgress',
          data: {'prompt_id': generationId},
        );

        if (response.isSuccess && response.data != null) {
          final data = response.data!;
          final status = data['status'] as String?;

          if (status == 'completed') {
            timer.cancel();
            final images = data['images'] as List? ?? [];
            if (images.isNotEmpty && !completer.isCompleted) {
              completer.complete('${_apiService.baseUrl}${images.first}');
            } else if (!completer.isCompleted) {
              completer.complete(null);
            }
          } else if (status == 'error') {
            timer.cancel();
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          }
        }
      } catch (e) {
        // Continue polling on error
      }
    });

    return completer.future;
  }

  /// Update result status
  void _updateResultStatus(int index, ComparisonItemStatus status) {
    _updateResult(index, (r) => r.copyWith(status: status));
  }

  /// Update result with transformer
  void _updateResult(
      int index, ModelComparisonResult Function(ModelComparisonResult) transform) {
    final results = List<ModelComparisonResult>.from(state.results);
    if (index >= 0 && index < results.length) {
      results[index] = transform(results[index]);
      state = state.copyWith(results: results);
    }
  }

  /// Pause comparison
  void pause() {
    state = state.copyWith(isPaused: true);
  }

  /// Resume comparison
  Future<void> resume() async {
    if (!state.isPaused) return;

    state = state.copyWith(isPaused: false, isGenerating: true);
    // Note: We'd need to pass baseParams here - for simplicity,
    // we'd need to store it in state or handle differently
  }

  /// Cancel comparison
  Future<void> cancel() async {
    _shouldCancel = true;

    // Try to cancel current generation
    if (_currentGenerationId != null) {
      try {
        await _apiService.post('/api/InterruptGeneration', data: {
          'session_id': _session.sessionId,
          'generation_id': _currentGenerationId,
        });
      } catch (_) {
        // Ignore cancel errors
      }
    }

    // Mark remaining as cancelled
    final results = List<ModelComparisonResult>.from(state.results);
    for (int i = state.currentIndex; i < results.length; i++) {
      if (results[i].status == ComparisonItemStatus.pending ||
          results[i].status == ComparisonItemStatus.generating) {
        results[i] = results[i].copyWith(status: ComparisonItemStatus.cancelled);
      }
    }

    state = state.copyWith(
      results: results,
      isGenerating: false,
      isCancelled: true,
    );
  }

  /// Reset state
  void reset() {
    _shouldCancel = false;
    _currentGenerationId = null;
    state = const ModelComparisonState();
  }
}
