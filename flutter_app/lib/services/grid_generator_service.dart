import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/grid_config.dart';
import '../providers/generation_provider.dart';
import 'comfyui_service.dart';
import 'comfyui_workflow_builder.dart';

/// Grid generator service provider
final gridGeneratorProvider =
    StateNotifierProvider<GridGeneratorNotifier, GridGenerationState>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  return GridGeneratorNotifier(comfyService, ref);
});

/// Grid configuration editor provider
final gridConfigProvider =
    StateNotifierProvider<GridConfigNotifier, GridConfig>((ref) {
  return GridConfigNotifier();
});

/// Grid generator service
///
/// Manages the generation queue for grid parameter exploration.
/// Handles calculating all parameter combinations and executing them sequentially.
class GridGeneratorNotifier extends StateNotifier<GridGenerationState> {
  final ComfyUIService _comfyService;
  final Ref _ref;
  final ComfyUIWorkflowBuilder _workflowBuilder = ComfyUIWorkflowBuilder();
  StreamSubscription<ComfyProgressUpdate>? _progressSubscription;
  String? _currentPromptId;
  bool _shouldCancel = false;

  GridGeneratorNotifier(this._comfyService, this._ref)
      : super(const GridGenerationState());

  /// Generate all combinations from the grid config
  List<GridGenerationItem> _generateCombinations(GridConfig config) {
    final items = <GridGenerationItem>[];
    final axes = config.activeAxes;

    if (axes.isEmpty) return items;

    // Calculate all combinations
    final xValues = config.xAxis?.values ?? [''];
    final yValues = config.yAxis?.values ?? [''];
    final zValues = config.zAxis?.values ?? [''];

    int itemIndex = 0;
    for (int z = 0; z < zValues.length; z++) {
      for (int y = 0; y < yValues.length; y++) {
        for (int x = 0; x < xValues.length; x++) {
          // Build params for this combination
          final params = Map<String, dynamic>.from(config.baseParams);

          // Apply axis values
          if (config.xAxis != null && config.xAxis!.isValid) {
            params[config.xAxis!.parameterName] =
                _parseValue(config.xAxis!.parameterName, xValues[x]);
          }
          if (config.yAxis != null && config.yAxis!.isValid) {
            params[config.yAxis!.parameterName] =
                _parseValue(config.yAxis!.parameterName, yValues[y]);
          }
          if (config.zAxis != null && config.zAxis!.isValid) {
            params[config.zAxis!.parameterName] =
                _parseValue(config.zAxis!.parameterName, zValues[z]);
          }

          items.add(GridGenerationItem(
            id: 'grid_${DateTime.now().millisecondsSinceEpoch}_$itemIndex',
            xIndex: x,
            yIndex: config.yAxis != null ? y : 0,
            zIndex: config.zAxis != null ? z : 0,
            params: params,
          ));

          itemIndex++;
        }
      }
    }

    return items;
  }

  /// Parse a string value to the appropriate type for the parameter
  dynamic _parseValue(String parameterName, String value) {
    final param = GridParameter.getByName(parameterName);
    if (param == null) return value;

    switch (param.type) {
      case GridParameterType.number:
        return double.tryParse(value) ?? param.defaultValue;
      case GridParameterType.integer:
        return int.tryParse(value) ?? param.defaultValue;
      case GridParameterType.selection:
      case GridParameterType.model:
      case GridParameterType.text:
        return value;
    }
  }

  /// Start grid generation
  Future<void> startGeneration(GridConfig config, GenerationParams baseParams) async {
    if (_comfyService.currentConnectionState != ComfyConnectionState.connected) {
      state = state.copyWith(error: 'Not connected to ComfyUI');
      return;
    }

    if (!config.isValid) {
      state = state.copyWith(error: 'Invalid grid configuration');
      return;
    }

    // Build base params from GenerationParams
    final baseParamsMap = <String, dynamic>{
      'prompt': baseParams.prompt,
      'negativeprompt': baseParams.negativePrompt,
      'model': baseParams.model,
      'width': baseParams.width,
      'height': baseParams.height,
      'steps': baseParams.steps,
      'cfgscale': baseParams.cfgScale,
      'seed': baseParams.seed,
      'sampler': baseParams.sampler,
      'scheduler': baseParams.scheduler,
      ...baseParams.extraParams,
    };

    // Merge with config base params
    final mergedParams = <String, dynamic>{
      ...baseParamsMap,
      ...config.baseParams,
    };

    // Create updated config with merged params
    final updatedConfig = config.copyWith(baseParams: mergedParams);

    // Generate all combinations
    final items = _generateCombinations(updatedConfig);

    if (items.isEmpty) {
      state = state.copyWith(error: 'No items to generate');
      return;
    }

    _shouldCancel = false;
    state = GridGenerationState(
      config: updatedConfig,
      items: items,
      currentIndex: 0,
      isGenerating: true,
      startTime: DateTime.now(),
    );

    // Start processing the queue
    await _processQueue();
  }

  /// Process the generation queue
  Future<void> _processQueue() async {
    while (state.currentIndex < state.items.length && !_shouldCancel && !state.isPaused) {
      final item = state.items[state.currentIndex];

      // Update item status to generating
      _updateItemStatus(state.currentIndex, GridItemStatus.generating);

      try {
        final result = await _generateSingle(item.params);

        if (result != null) {
          // Update item with result
          _updateItem(state.currentIndex, (i) => i.copyWith(
            status: GridItemStatus.completed,
            imageUrl: result,
          ));
        } else if (_shouldCancel) {
          _updateItemStatus(state.currentIndex, GridItemStatus.cancelled);
        } else {
          _updateItem(state.currentIndex, (i) => i.copyWith(
            status: GridItemStatus.failed,
            error: 'Generation failed',
          ));
        }
      } catch (e) {
        _updateItem(state.currentIndex, (i) => i.copyWith(
          status: GridItemStatus.failed,
          error: e.toString(),
        ));
      }

      // Move to next item
      if (!_shouldCancel && !state.isPaused) {
        state = state.copyWith(currentIndex: state.currentIndex + 1);
      }
    }

    // Mark as complete
    if (!state.isPaused) {
      state = state.copyWith(
        isGenerating: false,
        endTime: DateTime.now(),
        isCancelled: _shouldCancel,
      );
    }
  }

  /// Generate a single image and wait for result
  Future<String?> _generateSingle(Map<String, dynamic> params) async {
    try {
      // Build workflow using ComfyUI workflow builder
      final workflow = _workflowBuilder.buildText2Image(
        model: params['model'] as String? ?? '',
        prompt: params['prompt'] as String? ?? '',
        negativePrompt: params['negativeprompt'] as String? ?? '',
        width: params['width'] as int? ?? 1024,
        height: params['height'] as int? ?? 1024,
        steps: params['steps'] as int? ?? 20,
        cfg: (params['cfgscale'] as num?)?.toDouble() ?? 7.0,
        seed: params['seed'] as int? ?? -1,
        sampler: params['sampler'] as String? ?? 'euler',
        scheduler: params['scheduler'] as String? ?? 'normal',
      );

      // Queue the workflow
      final promptId = await _comfyService.queuePrompt(workflow);
      if (promptId == null) {
        return null;
      }

      _currentPromptId = promptId;

      // Wait for completion via progress stream
      return await _waitForCompletion(promptId);
    } catch (e) {
      return null;
    }
  }

  /// Wait for generation completion via ComfyUI progress stream
  Future<String?> _waitForCompletion(String promptId) async {
    final completer = Completer<String?>();

    // Cancel any existing subscription
    await _progressSubscription?.cancel();

    // Listen to progress stream for this specific prompt
    _progressSubscription = _comfyService.progressStream.listen((update) {
      if (update.promptId != promptId) return;

      if (update.isComplete && update.outputImages != null && update.outputImages!.isNotEmpty) {
        if (!completer.isCompleted) {
          completer.complete(update.outputImages!.first);
        }
      } else if (update.status == 'error' || update.status == 'interrupted') {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    });

    // Also listen to error stream
    final errorSubscription = _comfyService.errorStream.listen((error) {
      if (error.promptId == promptId && !completer.isCompleted) {
        completer.complete(null);
      }
    });

    try {
      // Wait for completion with timeout
      final result = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => null,
      );
      return result;
    } finally {
      await _progressSubscription?.cancel();
      await errorSubscription.cancel();
    }
  }

  /// Update a single item's status
  void _updateItemStatus(int index, GridItemStatus status) {
    _updateItem(index, (item) => item.copyWith(status: status));
  }

  /// Update a single item with a transformer
  void _updateItem(int index, GridGenerationItem Function(GridGenerationItem) transform) {
    final items = List<GridGenerationItem>.from(state.items);
    if (index >= 0 && index < items.length) {
      items[index] = transform(items[index]);
      state = state.copyWith(items: items);
    }
  }

  /// Pause generation
  void pause() {
    state = state.copyWith(isPaused: true);
  }

  /// Resume generation
  Future<void> resume() async {
    if (!state.isPaused) return;

    state = state.copyWith(isPaused: false, isGenerating: true);
    await _processQueue();
  }

  /// Cancel generation
  Future<void> cancel() async {
    _shouldCancel = true;
    await _progressSubscription?.cancel();

    // Try to cancel current generation via ComfyUI interrupt
    try {
      await _comfyService.interrupt();
    } catch (_) {
      // Ignore cancel errors
    }

    // Mark remaining items as cancelled
    final items = List<GridGenerationItem>.from(state.items);
    for (int i = state.currentIndex; i < items.length; i++) {
      if (items[i].status == GridItemStatus.pending ||
          items[i].status == GridItemStatus.generating) {
        items[i] = items[i].copyWith(status: GridItemStatus.cancelled);
      }
    }

    state = state.copyWith(
      items: items,
      isGenerating: false,
      isCancelled: true,
      endTime: DateTime.now(),
    );
  }

  /// Reset state for new grid
  void reset() {
    _shouldCancel = false;
    _progressSubscription?.cancel();
    _currentPromptId = null;
    state = const GridGenerationState();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }
}

/// Grid configuration editor notifier
class GridConfigNotifier extends StateNotifier<GridConfig> {
  GridConfigNotifier() : super(const GridConfig());

  /// Set X axis
  void setXAxis(GridAxis? axis) {
    state = state.copyWith(xAxis: axis);
  }

  /// Set Y axis
  void setYAxis(GridAxis? axis) {
    state = state.copyWith(yAxis: axis);
  }

  /// Set Z axis
  void setZAxis(GridAxis? axis) {
    state = state.copyWith(zAxis: axis);
  }

  /// Update X axis values
  void setXAxisValues(List<String> values) {
    if (state.xAxis != null) {
      state = state.copyWith(
        xAxis: state.xAxis!.copyWith(values: values),
      );
    }
  }

  /// Update Y axis values
  void setYAxisValues(List<String> values) {
    if (state.yAxis != null) {
      state = state.copyWith(
        yAxis: state.yAxis!.copyWith(values: values),
      );
    }
  }

  /// Update Z axis values
  void setZAxisValues(List<String> values) {
    if (state.zAxis != null) {
      state = state.copyWith(
        zAxis: state.zAxis!.copyWith(values: values),
      );
    }
  }

  /// Clear a specific axis
  void clearAxis(int index) {
    state = state.clearAxis(index);
  }

  /// Set output mode
  void setCombineAsGrid(bool value) {
    state = state.copyWith(combineAsGrid: value);
  }

  /// Set show labels
  void setShowLabels(bool value) {
    state = state.copyWith(showLabels: value);
  }

  /// Set base parameter
  void setBaseParam(String key, dynamic value) {
    final newParams = Map<String, dynamic>.from(state.baseParams);
    newParams[key] = value;
    state = state.copyWith(baseParams: newParams);
  }

  /// Reset configuration
  void reset() {
    state = const GridConfig();
  }

  /// Load a preset configuration
  void loadPreset(GridConfig preset) {
    state = preset;
  }

  /// Create common presets
  static GridConfig cfgStepsPreset() {
    return const GridConfig(
      name: 'CFG vs Steps',
      xAxis: GridAxis(
        parameterName: 'cfgScale',
        displayName: 'CFG Scale',
        values: ['3', '5', '7', '9'],
      ),
      yAxis: GridAxis(
        parameterName: 'steps',
        displayName: 'Steps',
        values: ['10', '20', '30', '40'],
      ),
    );
  }

  static GridConfig samplerPreset() {
    return const GridConfig(
      name: 'Sampler Comparison',
      xAxis: GridAxis(
        parameterName: 'sampler',
        displayName: 'Sampler',
        values: ['euler', 'euler_ancestral', 'dpmpp_2m', 'dpmpp_2m_sde'],
      ),
      yAxis: GridAxis(
        parameterName: 'scheduler',
        displayName: 'Scheduler',
        values: ['normal', 'karras'],
      ),
    );
  }

  static GridConfig seedExplorationPreset() {
    return GridConfig(
      name: 'Seed Exploration',
      xAxis: GridAxis(
        parameterName: 'seed',
        displayName: 'Seed',
        values: List.generate(9, (i) => '${1000 + i * 111}'),
      ),
    );
  }
}
