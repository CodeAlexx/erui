import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';

/// Model Merger Screen
///
/// Tool for merging two checkpoint models with configurable ratio and method.
/// Note: This feature is not available with the ComfyUI backend.
/// Model merging requires SwarmUI's native API which is not accessible through ComfyUI.
class ModelMergerScreen extends ConsumerStatefulWidget {
  const ModelMergerScreen({super.key});

  @override
  ConsumerState<ModelMergerScreen> createState() => _ModelMergerScreenState();
}

class _ModelMergerScreenState extends ConsumerState<ModelMergerScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Merger'),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.merge_type_outlined,
                size: 80,
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(height: 24),
              Text(
                'Not Available with ComfyUI Backend',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Model merging is not supported when using the ComfyUI backend. '
                'This feature requires direct access to the model files which is not '
                'available through the ComfyUI API.',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                color: colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Alternatives',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildAlternative(
                        colorScheme,
                        'Use ComfyUI directly',
                        'ComfyUI has custom nodes for model merging that can be installed separately.',
                      ),
                      _buildAlternative(
                        colorScheme,
                        'Use sd-webui-model-merger',
                        'A dedicated tool for merging Stable Diffusion models.',
                      ),
                      _buildAlternative(
                        colorScheme,
                        'Use sd-meh',
                        'Model merging tool that supports various merge methods.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlternative(ColorScheme colorScheme, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.arrow_right,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// State Management (kept for potential future use with ComfyUI merge nodes)
// ============================================================================

/// Model merger state provider (placeholder - not currently used)
final modelMergerProvider =
    StateNotifierProvider<ModelMergerNotifier, ModelMergerState>((ref) {
  return ModelMergerNotifier();
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

/// Model merger state notifier (placeholder - merge not available with ComfyUI)
class ModelMergerNotifier extends StateNotifier<ModelMergerState> {
  ModelMergerNotifier() : super(const ModelMergerState());

  void setModelA(String? model) {
    state = state.copyWith(modelA: model);
  }

  void setModelB(String? model) {
    state = state.copyWith(modelB: model);
  }

  void setMergeRatio(double ratio) {
    state = state.copyWith(mergeRatio: ratio.clamp(0.0, 1.0));
  }

  void setMergeMethod(String method) {
    state = state.copyWith(mergeMethod: method);
  }

  void setOutputName(String name) {
    state = state.copyWith(outputName: name);
  }

  void generateOutputName() {
    // Not implemented - feature not available with ComfyUI
  }

  void reset() {
    state = const ModelMergerState();
  }

  void cancel() {
    state = state.copyWith(
      isMerging: false,
      statusMessage: 'Cancelled',
    );
  }

  Future<void> merge() async {
    // Not implemented - feature not available with ComfyUI
    state = state.copyWith(
      error: 'Model merging is not available with the ComfyUI backend',
    );
  }
}
