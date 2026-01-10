import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/comfyui_service.dart';
import '../models/eri_workflow_models.dart';

/// State for workflow execution
class WorkflowExecutionState {
  final Map<String, dynamic> currentParams;
  final bool isExecuting;
  final double progress;
  final String? currentPromptId;
  final String? error;
  final List<String> outputImages;
  final EriWorkflow? activeWorkflow;

  const WorkflowExecutionState({
    this.currentParams = const {},
    this.isExecuting = false,
    this.progress = 0.0,
    this.currentPromptId,
    this.error,
    this.outputImages = const [],
    this.activeWorkflow,
  });

  WorkflowExecutionState copyWith({
    Map<String, dynamic>? currentParams,
    bool? isExecuting,
    double? progress,
    String? currentPromptId,
    String? error,
    List<String>? outputImages,
    EriWorkflow? activeWorkflow,
    bool clearError = false,
    bool clearPromptId = false,
  }) {
    return WorkflowExecutionState(
      currentParams: currentParams ?? this.currentParams,
      isExecuting: isExecuting ?? this.isExecuting,
      progress: progress ?? this.progress,
      currentPromptId: clearPromptId ? null : (currentPromptId ?? this.currentPromptId),
      error: clearError ? null : (error ?? this.error),
      outputImages: outputImages ?? this.outputImages,
      activeWorkflow: activeWorkflow ?? this.activeWorkflow,
    );
  }
}

/// Notifier for workflow execution state
class WorkflowExecutionNotifier extends StateNotifier<WorkflowExecutionState> {
  final ComfyUIService _comfyService;
  StreamSubscription<ComfyProgressUpdate>? _progressSubscription;
  StreamSubscription<ComfyExecutionError>? _errorSubscription;

  WorkflowExecutionNotifier(this._comfyService) : super(const WorkflowExecutionState()) {
    _setupListeners();
  }

  void _setupListeners() {
    _progressSubscription = _comfyService.progressStream.listen(_handleProgress);
    _errorSubscription = _comfyService.errorStream.listen(_handleError);
  }

  void _handleProgress(ComfyProgressUpdate update) {
    if (state.currentPromptId != null && update.promptId != state.currentPromptId) {
      return;
    }

    state = state.copyWith(
      progress: update.totalSteps > 0 ? update.currentStep / update.totalSteps : 0,
    );

    if (update.isComplete && update.outputImages != null && update.outputImages!.isNotEmpty) {
      state = state.copyWith(
        isExecuting: false,
        progress: 1.0,
        outputImages: update.outputImages,
        clearPromptId: true,
      );
    }
  }

  void _handleError(ComfyExecutionError error) {
    if (state.currentPromptId != null && error.promptId != state.currentPromptId) {
      return;
    }

    state = state.copyWith(
      isExecuting: false,
      error: 'Workflow execution failed: ${error.message}',
      clearPromptId: true,
    );
  }

  /// Load a workflow and initialize its default parameters
  void loadWorkflow(EriWorkflow workflow) {
    final defaultValues = workflow.defaultValues;

    // Start with defaults from the workflow
    final params = Map<String, dynamic>.from(defaultValues);

    // Ensure core params are present
    params.putIfAbsent('prompt', () => '');
    params.putIfAbsent('negative_prompt', () => '');
    params.putIfAbsent('negativePrompt', () => params['negative_prompt'] ?? '');
    params.putIfAbsent('seed', () => -1);
    params.putIfAbsent('steps', () => 20);
    params.putIfAbsent('width', () => 1024);
    params.putIfAbsent('height', () => 1024);
    params.putIfAbsent('cfgScale', () => 7.0);
    params.putIfAbsent('cfg_scale', () => 7.0);

    state = state.copyWith(
      activeWorkflow: workflow,
      currentParams: params,
      clearError: true,
    );
  }

  /// Update a single parameter value
  void updateParam(String key, dynamic value) {
    final newParams = Map<String, dynamic>.from(state.currentParams);
    newParams[key] = value;

    // Keep prompt and negativePrompt in sync with their underscore versions
    if (key == 'prompt') {
      newParams['prompt'] = value;
    } else if (key == 'negativePrompt' || key == 'negative_prompt') {
      newParams['negativePrompt'] = value;
      newParams['negative_prompt'] = value;
    } else if (key == 'cfgScale' || key == 'cfg_scale') {
      newParams['cfgScale'] = value;
      newParams['cfg_scale'] = value;
    }

    state = state.copyWith(currentParams: newParams);
  }

  /// Update multiple parameters at once
  void updateParams(Map<String, dynamic> params) {
    final newParams = Map<String, dynamic>.from(state.currentParams);
    newParams.addAll(params);
    state = state.copyWith(currentParams: newParams);
  }

  /// Reset parameters to workflow defaults
  void resetToDefaults() {
    if (state.activeWorkflow == null) return;

    final defaultValues = state.activeWorkflow!.defaultValues;
    final params = Map<String, dynamic>.from(defaultValues);

    params.putIfAbsent('prompt', () => '');
    params.putIfAbsent('negative_prompt', () => '');
    params.putIfAbsent('negativePrompt', () => '');
    params.putIfAbsent('seed', () => -1);

    state = state.copyWith(currentParams: params);
  }

  /// Execute the active workflow with current parameters
  Future<WorkflowExecutionResult?> executeWorkflow() async {
    if (state.activeWorkflow == null) {
      state = state.copyWith(error: 'No workflow loaded');
      return null;
    }

    // Check connection
    if (_comfyService.currentConnectionState != ComfyConnectionState.connected) {
      final connected = await _comfyService.connect();
      if (!connected) {
        state = state.copyWith(error: 'Not connected to ComfyUI');
        return null;
      }
    }

    state = state.copyWith(
      isExecuting: true,
      progress: 0.0,
      clearError: true,
      outputImages: [],
    );

    try {
      // Fill template with current parameters
      final filledPrompt = state.activeWorkflow!.fillTemplate(state.currentParams);

      // Parse the filled prompt
      final promptJson = jsonDecode(filledPrompt) as Map<String, dynamic>;

      // Queue to ComfyUI
      final promptId = await _comfyService.queuePrompt(promptJson);

      if (promptId == null) {
        state = state.copyWith(
          isExecuting: false,
          error: 'Failed to queue workflow',
        );
        return null;
      }

      state = state.copyWith(currentPromptId: promptId);

      // Wait for completion (handled via stream subscription)
      // Return immediately - result will come via stream
      return null;
    } catch (e) {
      state = state.copyWith(
        isExecuting: false,
        error: 'Workflow execution error: $e',
      );
      return null;
    }
  }

  /// Execute a specific workflow with provided parameters (one-shot)
  Future<WorkflowExecutionResult?> executeWorkflowOnce(
    EriWorkflow workflow,
    Map<String, dynamic> paramOverrides,
  ) async {
    loadWorkflow(workflow);
    updateParams(paramOverrides);
    return executeWorkflow();
  }

  /// Cancel current execution
  Future<void> cancelExecution() async {
    if (!state.isExecuting) return;

    try {
      await _comfyService.interrupt();
      state = state.copyWith(
        isExecuting: false,
        error: 'Execution cancelled',
        clearPromptId: true,
      );
    } catch (e) {
      // Ignore cancel errors
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Get current value for a parameter
  dynamic getParamValue(String key) {
    return state.currentParams[key];
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _errorSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for workflow execution
final workflowExecutionProvider =
    StateNotifierProvider<WorkflowExecutionNotifier, WorkflowExecutionState>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  return WorkflowExecutionNotifier(comfyService);
});
