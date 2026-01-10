import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workflow_models.dart';
import '../services/comfyui_service.dart';
import 'workflow_provider.dart';

/// Workflow execution state provider
final workflowExecutionProvider =
    StateNotifierProvider<WorkflowExecutionNotifier, WorkflowExecutionState>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  return WorkflowExecutionNotifier(comfyService, ref);
});

/// Provider for the current workflow's parameters (merged defaults + user values)
final workflowCurrentParamsProvider = Provider<Map<String, dynamic>>((ref) {
  final executionState = ref.watch(workflowExecutionProvider);
  final selectedWorkflow = ref.watch(selectedWorkflowProvider);

  if (selectedWorkflow == null) {
    return {};
  }

  // Start with workflow defaults
  final defaults = selectedWorkflow.defaultValues;

  // Override with current parameter values
  return {...defaults, ...executionState.currentParams};
});

/// Provider for the current workflow's parameter definitions
final workflowParametersProvider = Provider<List<EriWorkflowParam>>((ref) {
  final selectedWorkflow = ref.watch(selectedWorkflowProvider);
  return selectedWorkflow?.parameters ?? [];
});

/// Provider for grouped workflow parameters (by group name)
final workflowGroupedParamsProvider = Provider<Map<String, List<EriWorkflowParam>>>((ref) {
  final params = ref.watch(workflowParametersProvider);

  final grouped = <String, List<EriWorkflowParam>>{};
  for (final param in params) {
    final group = param.group ?? 'General';
    grouped.putIfAbsent(group, () => []);
    grouped[group]!.add(param);
  }

  // Sort parameters within each group by priority
  for (final group in grouped.values) {
    group.sort((a, b) => a.priority.compareTo(b.priority));
  }

  return grouped;
});

/// Workflow execution state
class WorkflowExecutionState {
  /// Current parameter values (user-modified)
  final Map<String, dynamic> currentParams;

  /// Whether a workflow is currently executing
  final bool isExecuting;

  /// Execution progress (0.0 to 1.0)
  final double progress;

  /// Current step number
  final int currentStep;

  /// Total steps
  final int totalSteps;

  /// Current ComfyUI prompt ID
  final String? promptId;

  /// Preview image URL (if available during generation)
  final String? previewImage;

  /// List of output image URLs
  final List<String> outputImages;

  /// Error message (if any)
  final String? error;

  /// Execution start time
  final DateTime? startTime;

  /// Last execution result
  final WorkflowExecutionResult? lastResult;

  const WorkflowExecutionState({
    this.currentParams = const {},
    this.isExecuting = false,
    this.progress = 0.0,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.promptId,
    this.previewImage,
    this.outputImages = const [],
    this.error,
    this.startTime,
    this.lastResult,
  });

  WorkflowExecutionState copyWith({
    Map<String, dynamic>? currentParams,
    bool? isExecuting,
    double? progress,
    int? currentStep,
    int? totalSteps,
    String? promptId,
    String? previewImage,
    List<String>? outputImages,
    String? error,
    DateTime? startTime,
    WorkflowExecutionResult? lastResult,
  }) {
    return WorkflowExecutionState(
      currentParams: currentParams ?? this.currentParams,
      isExecuting: isExecuting ?? this.isExecuting,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      promptId: promptId ?? this.promptId,
      previewImage: previewImage ?? this.previewImage,
      outputImages: outputImages ?? this.outputImages,
      error: error,
      startTime: startTime ?? this.startTime,
      lastResult: lastResult ?? this.lastResult,
    );
  }

  /// Get the elapsed execution time
  Duration get elapsedTime {
    if (startTime == null) return Duration.zero;
    return DateTime.now().difference(startTime!);
  }
}

/// Workflow execution notifier
class WorkflowExecutionNotifier extends StateNotifier<WorkflowExecutionState> {
  final ComfyUIService _comfyService;
  final Ref _ref;

  StreamSubscription<ComfyProgressUpdate>? _progressSubscription;
  StreamSubscription<ComfyExecutionError>? _errorSubscription;

  WorkflowExecutionNotifier(this._comfyService, this._ref)
      : super(const WorkflowExecutionState()) {
    _setupListeners();
  }

  /// Set up WebSocket listeners for progress and errors
  void _setupListeners() {
    _progressSubscription = _comfyService.progressStream.listen(_handleProgress);
    _errorSubscription = _comfyService.errorStream.listen(_handleError);
  }

  /// Handle progress updates from ComfyUI WebSocket
  void _handleProgress(ComfyProgressUpdate update) {
    // Only handle updates for our current execution
    if (state.promptId != null && update.promptId != state.promptId) {
      return;
    }

    state = state.copyWith(
      currentStep: update.currentStep,
      totalSteps: update.totalSteps,
      progress: update.totalSteps > 0 ? update.currentStep / update.totalSteps : 0,
      previewImage: update.previewImage ?? state.previewImage,
    );

    if (update.isComplete && update.outputImages != null && update.outputImages!.isNotEmpty) {
      _handleCompletion(update.outputImages!);
    } else if (update.status == 'complete' && update.outputImages == null) {
      // Execution complete but no images from WebSocket, fetch from history
      _fetchOutputsFromHistory(update.promptId);
    }
  }

  /// Handle completion with output images
  void _handleCompletion(List<String> images) {
    final result = WorkflowExecutionResult.success(
      promptId: state.promptId ?? '',
      outputImages: images,
      executionTime: state.elapsedTime,
    );

    state = state.copyWith(
      isExecuting: false,
      progress: 1.0,
      outputImages: images,
      lastResult: result,
    );
  }

  /// Handle execution errors from ComfyUI WebSocket
  void _handleError(ComfyExecutionError error) {
    if (state.promptId != null && error.promptId != state.promptId) {
      return;
    }

    final result = WorkflowExecutionResult.failure(
      promptId: state.promptId ?? '',
      error: 'Execution failed: ${error.message} (node: ${error.nodeType})',
      executionTime: state.elapsedTime,
    );

    state = state.copyWith(
      isExecuting: false,
      error: result.error,
      lastResult: result,
    );
  }

  /// Fetch output images from history when WebSocket didn't provide them
  Future<void> _fetchOutputsFromHistory(String promptId) async {
    try {
      final images = await _comfyService.getOutputImages(promptId);
      if (images.isNotEmpty) {
        _handleCompletion(images);
      } else {
        // Wait a bit and retry - history might not be ready yet
        await Future.delayed(const Duration(milliseconds: 500));
        final retryImages = await _comfyService.getOutputImages(promptId);
        if (retryImages.isNotEmpty) {
          _handleCompletion(retryImages);
        } else {
          state = state.copyWith(
            isExecuting: false,
            error: 'Execution completed but no images found',
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        isExecuting: false,
        error: 'Failed to fetch output images: $e',
      );
    }
  }

  /// Execute a workflow with the given parameters
  ///
  /// Uses the selected workflow from the provider if workflow is null.
  Future<WorkflowExecutionResult?> executeWorkflow({
    EriWorkflow? workflow,
    Map<String, dynamic>? paramOverrides,
  }) async {
    // Get workflow from parameter or provider
    final workflowToExecute = workflow ?? _ref.read(selectedWorkflowProvider);
    if (workflowToExecute == null) {
      state = state.copyWith(error: 'No workflow selected');
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

    // Merge parameters: defaults -> current state -> overrides
    final params = {
      ...workflowToExecute.defaultValues,
      ...state.currentParams,
      ...?paramOverrides,
    };

    // Handle random seed
    if (params['seed'] == -1 || params['seed'] == null) {
      params['seed'] = Random().nextInt(1 << 31);
    }

    // Update state to executing
    state = state.copyWith(
      isExecuting: true,
      progress: 0.0,
      currentStep: 0,
      totalSteps: params['steps'] as int? ?? 20,
      previewImage: null,
      outputImages: [],
      error: null,
      startTime: DateTime.now(),
      promptId: null,
    );

    try {
      // Fill the workflow template with parameters
      final filledPrompt = workflowToExecute.fillTemplate(params);

      // Parse the filled prompt
      Map<String, dynamic> promptData;
      try {
        promptData = jsonDecode(filledPrompt) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Invalid workflow prompt format: $e');
      }

      // Queue the prompt
      final promptId = await _comfyService.queuePrompt(promptData);

      if (promptId == null) {
        state = state.copyWith(
          isExecuting: false,
          error: 'Failed to queue workflow - no prompt ID returned',
        );
        return WorkflowExecutionResult.failure(
          promptId: '',
          error: 'Failed to queue workflow',
        );
      }

      state = state.copyWith(promptId: promptId);

      print('Workflow execution queued: $promptId');

      // Wait for completion (the listeners will update state)
      // Return null here since result will be set asynchronously
      return null;
    } catch (e) {
      final result = WorkflowExecutionResult.failure(
        promptId: state.promptId ?? '',
        error: 'Workflow execution error: $e',
        executionTime: state.elapsedTime,
      );

      state = state.copyWith(
        isExecuting: false,
        error: result.error,
        lastResult: result,
      );

      return result;
    }
  }

  /// Update a single parameter value
  void updateParam(String key, dynamic value) {
    final params = Map<String, dynamic>.from(state.currentParams);
    params[key] = value;
    state = state.copyWith(currentParams: params);
  }

  /// Update multiple parameters at once
  void updateParams(Map<String, dynamic> updates) {
    final params = Map<String, dynamic>.from(state.currentParams);
    params.addAll(updates);
    state = state.copyWith(currentParams: params);
  }

  /// Reset parameters to workflow defaults
  void resetToDefaults([EriWorkflow? workflow]) {
    final workflowToUse = workflow ?? _ref.read(selectedWorkflowProvider);
    if (workflowToUse == null) {
      state = state.copyWith(currentParams: {});
      return;
    }

    state = state.copyWith(currentParams: workflowToUse.defaultValues);
  }

  /// Clear current parameters
  void clearParams() {
    state = state.copyWith(currentParams: {});
  }

  /// Randomize the seed
  void randomizeSeed() {
    updateParam('seed', Random().nextInt(1 << 31));
  }

  /// Cancel the current execution
  Future<void> cancel() async {
    if (!state.isExecuting) return;

    try {
      await _comfyService.interrupt();
      state = state.copyWith(
        isExecuting: false,
        error: 'Execution cancelled',
      );
    } catch (e) {
      print('Cancel error (ignored): $e');
    }
  }

  /// Clear the current error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Get the current value of a parameter
  dynamic getParam(String key) {
    return state.currentParams[key];
  }

  /// Check if a parameter has been modified from its default
  bool isParamModified(String key, EriWorkflow? workflow) {
    if (workflow == null) return false;

    final defaults = workflow.defaultValues;
    final currentValue = state.currentParams[key];
    final defaultValue = defaults[key];

    return currentValue != null && currentValue != defaultValue;
  }

  /// Load parameters from a workflow
  ///
  /// Called when a workflow is selected to populate the initial parameter values.
  void loadWorkflowParams(EriWorkflow workflow) {
    state = state.copyWith(
      currentParams: Map<String, dynamic>.from(workflow.defaultValues),
      error: null,
    );
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _errorSubscription?.cancel();
    super.dispose();
  }
}

/// Convenience extension for workflow execution via ref
extension WorkflowExecutionExtension on WidgetRef {
  /// Execute the currently selected workflow
  Future<WorkflowExecutionResult?> executeSelectedWorkflow({
    Map<String, dynamic>? paramOverrides,
  }) async {
    return read(workflowExecutionProvider.notifier).executeWorkflow(
      paramOverrides: paramOverrides,
    );
  }

  /// Execute a specific workflow
  Future<WorkflowExecutionResult?> executeWorkflow(
    EriWorkflow workflow, {
    Map<String, dynamic>? paramOverrides,
  }) async {
    return read(workflowExecutionProvider.notifier).executeWorkflow(
      workflow: workflow,
      paramOverrides: paramOverrides,
    );
  }

  /// Update a workflow parameter
  void updateWorkflowParam(String key, dynamic value) {
    read(workflowExecutionProvider.notifier).updateParam(key, value);
  }

  /// Reset workflow parameters to defaults
  void resetWorkflowParams([EriWorkflow? workflow]) {
    read(workflowExecutionProvider.notifier).resetToDefaults(workflow);
  }

  /// Cancel the current workflow execution
  Future<void> cancelWorkflowExecution() async {
    await read(workflowExecutionProvider.notifier).cancel();
  }

  /// Get the current execution progress
  double get workflowProgress => watch(workflowExecutionProvider).progress;

  /// Check if a workflow is currently executing
  bool get isWorkflowExecuting => watch(workflowExecutionProvider).isExecuting;

  /// Get the current workflow error
  String? get workflowError => watch(workflowExecutionProvider).error;
}
