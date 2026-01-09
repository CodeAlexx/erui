import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../providers/editor_provider.dart';

// ============================================================
// Workflow State & Models
// ============================================================

/// Training workflow step enumeration
enum TrainingWorkflowStep {
  selectRegion(0, 'Select Region', 'Selecting region'),
  extractFrames(1, 'Extract Frames', 'Extracting frames'),
  captionFrames(2, 'Caption Frames', 'Captioning frames'),
  buildDataset(3, 'Build Dataset', 'Building dataset'),
  startTraining(4, 'Start Training', 'Starting training');

  final int stepIndex;
  final String title;
  final String activeTitle;
  const TrainingWorkflowStep(this.stepIndex, this.title, this.activeTitle);
}

/// Step status for tracking progress
enum StepStatus {
  pending,
  inProgress,
  completed,
  error,
}

/// Represents an extracted frame
class ExtractedFrame {
  final String id;
  final String filePath;
  final Uint8List? thumbnail;
  final Duration timecode;
  final bool isIncluded;
  final bool isKeyframe;

  ExtractedFrame({
    required this.id,
    required this.filePath,
    this.thumbnail,
    required this.timecode,
    this.isIncluded = true,
    this.isKeyframe = false,
  });

  ExtractedFrame copyWith({
    String? id,
    String? filePath,
    Uint8List? thumbnail,
    Duration? timecode,
    bool? isIncluded,
    bool? isKeyframe,
  }) {
    return ExtractedFrame(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      thumbnail: thumbnail ?? this.thumbnail,
      timecode: timecode ?? this.timecode,
      isIncluded: isIncluded ?? this.isIncluded,
      isKeyframe: isKeyframe ?? this.isKeyframe,
    );
  }

  String get displayTimecode {
    final minutes = timecode.inMinutes;
    final seconds = timecode.inSeconds % 60;
    final frames = ((timecode.inMilliseconds % 1000) / 33.33).round();
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}:'
        '${frames.toString().padLeft(2, '0')}';
  }
}

/// Represents a frame with caption
class CaptionedFrame {
  final ExtractedFrame frame;
  final String caption;
  final bool isEdited;

  CaptionedFrame({
    required this.frame,
    required this.caption,
    this.isEdited = false,
  });

  CaptionedFrame copyWith({
    ExtractedFrame? frame,
    String? caption,
    bool? isEdited,
  }) {
    return CaptionedFrame(
      frame: frame ?? this.frame,
      caption: caption ?? this.caption,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}

/// Frame extraction settings
class ExtractionSettings {
  final ExtractionMethod method;
  final double intervalSeconds;
  final int frameCount;
  final bool includeKeyframes;

  const ExtractionSettings({
    this.method = ExtractionMethod.interval,
    this.intervalSeconds = 1.0,
    this.frameCount = 50,
    this.includeKeyframes = true,
  });

  ExtractionSettings copyWith({
    ExtractionMethod? method,
    double? intervalSeconds,
    int? frameCount,
    bool? includeKeyframes,
  }) {
    return ExtractionSettings(
      method: method ?? this.method,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      frameCount: frameCount ?? this.frameCount,
      includeKeyframes: includeKeyframes ?? this.includeKeyframes,
    );
  }
}

enum ExtractionMethod {
  interval('Fixed Interval'),
  keyframe('Keyframes Only'),
  count('Fixed Count');

  final String label;
  const ExtractionMethod(this.label);
}

/// Dataset build settings
class DatasetSettings {
  final String name;
  final String format;
  final int resolution;
  final int repeats;
  final bool centerCrop;
  final bool flipAugment;

  const DatasetSettings({
    this.name = 'my_dataset',
    this.format = 'kohya',
    this.resolution = 512,
    this.repeats = 10,
    this.centerCrop = true,
    this.flipAugment = false,
  });

  DatasetSettings copyWith({
    String? name,
    String? format,
    int? resolution,
    int? repeats,
    bool? centerCrop,
    bool? flipAugment,
  }) {
    return DatasetSettings(
      name: name ?? this.name,
      format: format ?? this.format,
      resolution: resolution ?? this.resolution,
      repeats: repeats ?? this.repeats,
      centerCrop: centerCrop ?? this.centerCrop,
      flipAugment: flipAugment ?? this.flipAugment,
    );
  }
}

/// Training config reference
class TrainingConfig {
  final String name;
  final String path;
  final String modelType;
  final String trainingMethod;
  final int estimatedMinutes;

  const TrainingConfig({
    required this.name,
    required this.path,
    this.modelType = 'Unknown',
    this.trainingMethod = 'LoRA',
    this.estimatedMinutes = 60,
  });
}

/// Complete workflow state
class TrainingWorkflowState {
  final TrainingWorkflowStep currentStep;
  final Map<TrainingWorkflowStep, StepStatus> stepStatuses;
  final bool isPanelExpanded;

  // Step 1: Region selection
  final bool useFullClip;
  final EditorTime? regionStart;
  final EditorTime? regionEnd;
  final String? sourceClipId;

  // Step 2: Frame extraction
  final ExtractionSettings extractionSettings;
  final List<ExtractedFrame> extractedFrames;
  final double extractionProgress;

  // Step 3: Caption frames
  final List<CaptionedFrame> captionedFrames;
  final double captionProgress;
  final String captionPrefix;
  final String captionSuffix;

  // Step 4: Dataset build
  final DatasetSettings datasetSettings;
  final bool datasetValid;
  final String? datasetPath;

  // Step 5: Training
  final List<TrainingConfig> availableConfigs;
  final TrainingConfig? selectedConfig;
  final bool isTrainingRunning;
  final double trainingProgress;

  // General
  final String? errorMessage;

  const TrainingWorkflowState({
    this.currentStep = TrainingWorkflowStep.selectRegion,
    this.stepStatuses = const {},
    this.isPanelExpanded = true,
    this.useFullClip = true,
    this.regionStart,
    this.regionEnd,
    this.sourceClipId,
    this.extractionSettings = const ExtractionSettings(),
    this.extractedFrames = const [],
    this.extractionProgress = 0.0,
    this.captionedFrames = const [],
    this.captionProgress = 0.0,
    this.captionPrefix = '',
    this.captionSuffix = '',
    this.datasetSettings = const DatasetSettings(),
    this.datasetValid = false,
    this.datasetPath,
    this.availableConfigs = const [],
    this.selectedConfig,
    this.isTrainingRunning = false,
    this.trainingProgress = 0.0,
    this.errorMessage,
  });

  TrainingWorkflowState copyWith({
    TrainingWorkflowStep? currentStep,
    Map<TrainingWorkflowStep, StepStatus>? stepStatuses,
    bool? isPanelExpanded,
    bool? useFullClip,
    EditorTime? regionStart,
    EditorTime? regionEnd,
    String? sourceClipId,
    ExtractionSettings? extractionSettings,
    List<ExtractedFrame>? extractedFrames,
    double? extractionProgress,
    List<CaptionedFrame>? captionedFrames,
    double? captionProgress,
    String? captionPrefix,
    String? captionSuffix,
    DatasetSettings? datasetSettings,
    bool? datasetValid,
    String? datasetPath,
    List<TrainingConfig>? availableConfigs,
    TrainingConfig? selectedConfig,
    bool? isTrainingRunning,
    double? trainingProgress,
    String? errorMessage,
  }) {
    return TrainingWorkflowState(
      currentStep: currentStep ?? this.currentStep,
      stepStatuses: stepStatuses ?? this.stepStatuses,
      isPanelExpanded: isPanelExpanded ?? this.isPanelExpanded,
      useFullClip: useFullClip ?? this.useFullClip,
      regionStart: regionStart ?? this.regionStart,
      regionEnd: regionEnd ?? this.regionEnd,
      sourceClipId: sourceClipId ?? this.sourceClipId,
      extractionSettings: extractionSettings ?? this.extractionSettings,
      extractedFrames: extractedFrames ?? this.extractedFrames,
      extractionProgress: extractionProgress ?? this.extractionProgress,
      captionedFrames: captionedFrames ?? this.captionedFrames,
      captionProgress: captionProgress ?? this.captionProgress,
      captionPrefix: captionPrefix ?? this.captionPrefix,
      captionSuffix: captionSuffix ?? this.captionSuffix,
      datasetSettings: datasetSettings ?? this.datasetSettings,
      datasetValid: datasetValid ?? this.datasetValid,
      datasetPath: datasetPath ?? this.datasetPath,
      availableConfigs: availableConfigs ?? this.availableConfigs,
      selectedConfig: selectedConfig ?? this.selectedConfig,
      isTrainingRunning: isTrainingRunning ?? this.isTrainingRunning,
      trainingProgress: trainingProgress ?? this.trainingProgress,
      errorMessage: errorMessage,
    );
  }

  /// Get total included frames count
  int get includedFrameCount =>
      extractedFrames.where((f) => f.isIncluded).length;

  /// Get estimated training steps
  int get estimatedTrainingSteps {
    final images = includedFrameCount;
    final repeats = datasetSettings.repeats;
    return images * repeats;
  }
}

// ============================================================
// State Notifier
// ============================================================

/// State notifier for managing training workflow
class TrainingWorkflowNotifier extends StateNotifier<TrainingWorkflowState> {
  TrainingWorkflowNotifier() : super(const TrainingWorkflowState()) {
    _loadAvailableConfigs();
  }

  /// Toggle panel expansion
  void togglePanel() {
    state = state.copyWith(isPanelExpanded: !state.isPanelExpanded);
  }

  /// Set current step
  void setStep(TrainingWorkflowStep step) {
    state = state.copyWith(currentStep: step);
  }

  /// Update step status
  void setStepStatus(TrainingWorkflowStep step, StepStatus status) {
    final newStatuses = Map<TrainingWorkflowStep, StepStatus>.from(state.stepStatuses);
    newStatuses[step] = status;
    state = state.copyWith(stepStatuses: newStatuses);
  }

  // ============================================================
  // Step 1: Region Selection
  // ============================================================

  /// Set whether to use full clip or I/O points
  void setUseFullClip(bool useFullClip) {
    state = state.copyWith(useFullClip: useFullClip);
  }

  /// Set region from I/O points
  void setRegion(EditorTime? start, EditorTime? end) {
    state = state.copyWith(regionStart: start, regionEnd: end);
  }

  /// Set source clip ID
  void setSourceClip(String? clipId) {
    state = state.copyWith(sourceClipId: clipId);
  }

  /// Complete region selection step
  void completeRegionSelection() {
    setStepStatus(TrainingWorkflowStep.selectRegion, StepStatus.completed);
    setStep(TrainingWorkflowStep.extractFrames);
  }

  // ============================================================
  // Step 2: Frame Extraction
  // ============================================================

  /// Update extraction settings
  void updateExtractionSettings(ExtractionSettings settings) {
    state = state.copyWith(extractionSettings: settings);
  }

  /// Start frame extraction
  Future<void> startFrameExtraction() async {
    setStepStatus(TrainingWorkflowStep.extractFrames, StepStatus.inProgress);
    state = state.copyWith(extractionProgress: 0.0, extractedFrames: []);

    try {
      // Simulate extraction progress
      // In real implementation, this would call FFmpeg to extract frames
      final frames = <ExtractedFrame>[];
      final totalFrames = state.extractionSettings.method == ExtractionMethod.count
          ? state.extractionSettings.frameCount
          : 50; // Estimated based on duration/interval

      for (int i = 0; i < totalFrames; i++) {
        await Future.delayed(const Duration(milliseconds: 50));

        frames.add(ExtractedFrame(
          id: 'frame_$i',
          filePath: '/tmp/frames/frame_${i.toString().padLeft(4, '0')}.png',
          timecode: Duration(milliseconds: (i * 1000 * state.extractionSettings.intervalSeconds).round()),
          isKeyframe: i % 10 == 0,
        ));

        state = state.copyWith(
          extractionProgress: (i + 1) / totalFrames,
          extractedFrames: List.from(frames),
        );
      }

      setStepStatus(TrainingWorkflowStep.extractFrames, StepStatus.completed);
    } catch (e) {
      setStepStatus(TrainingWorkflowStep.extractFrames, StepStatus.error);
      state = state.copyWith(errorMessage: 'Frame extraction failed: $e');
    }
  }

  /// Toggle frame inclusion
  void toggleFrameInclusion(String frameId) {
    final newFrames = state.extractedFrames.map((f) {
      if (f.id == frameId) {
        return f.copyWith(isIncluded: !f.isIncluded);
      }
      return f;
    }).toList();
    state = state.copyWith(extractedFrames: newFrames);
  }

  /// Set all frames inclusion
  void setAllFramesInclusion(bool included) {
    final newFrames = state.extractedFrames.map((f) => f.copyWith(isIncluded: included)).toList();
    state = state.copyWith(extractedFrames: newFrames);
  }

  /// Complete frame extraction step
  void completeFrameExtraction() {
    setStepStatus(TrainingWorkflowStep.extractFrames, StepStatus.completed);
    setStep(TrainingWorkflowStep.captionFrames);

    // Initialize captioned frames from extracted frames
    final captionedFrames = state.extractedFrames
        .where((f) => f.isIncluded)
        .map((f) => CaptionedFrame(frame: f, caption: ''))
        .toList();
    state = state.copyWith(captionedFrames: captionedFrames);
  }

  // ============================================================
  // Step 3: Caption Frames
  // ============================================================

  /// Start auto-captioning
  Future<void> startAutoCaptioning() async {
    setStepStatus(TrainingWorkflowStep.captionFrames, StepStatus.inProgress);
    state = state.copyWith(captionProgress: 0.0);

    try {
      // Simulate captioning progress
      // In real implementation, this would call a captioning model
      final newCaptionedFrames = <CaptionedFrame>[];

      for (int i = 0; i < state.captionedFrames.length; i++) {
        await Future.delayed(const Duration(milliseconds: 100));

        final frame = state.captionedFrames[i];
        newCaptionedFrames.add(frame.copyWith(
          caption: 'A photo of a subject doing an action, detailed description',
        ));

        state = state.copyWith(
          captionProgress: (i + 1) / state.captionedFrames.length,
          captionedFrames: List.from(newCaptionedFrames)
            ..addAll(state.captionedFrames.skip(i + 1)),
        );
      }

      setStepStatus(TrainingWorkflowStep.captionFrames, StepStatus.completed);
    } catch (e) {
      setStepStatus(TrainingWorkflowStep.captionFrames, StepStatus.error);
      state = state.copyWith(errorMessage: 'Auto-captioning failed: $e');
    }
  }

  /// Update individual caption
  void updateCaption(int index, String caption) {
    if (index >= 0 && index < state.captionedFrames.length) {
      final newCaptionedFrames = List<CaptionedFrame>.from(state.captionedFrames);
      newCaptionedFrames[index] = state.captionedFrames[index].copyWith(
        caption: caption,
        isEdited: true,
      );
      state = state.copyWith(captionedFrames: newCaptionedFrames);
    }
  }

  /// Set caption prefix
  void setCaptionPrefix(String prefix) {
    state = state.copyWith(captionPrefix: prefix);
  }

  /// Set caption suffix
  void setCaptionSuffix(String suffix) {
    state = state.copyWith(captionSuffix: suffix);
  }

  /// Apply prefix/suffix to all captions
  void applyPrefixSuffix() {
    final newCaptionedFrames = state.captionedFrames.map((cf) {
      String newCaption = cf.caption;
      if (state.captionPrefix.isNotEmpty) {
        newCaption = '${state.captionPrefix} $newCaption';
      }
      if (state.captionSuffix.isNotEmpty) {
        newCaption = '$newCaption ${state.captionSuffix}';
      }
      return cf.copyWith(caption: newCaption.trim());
    }).toList();
    state = state.copyWith(captionedFrames: newCaptionedFrames);
  }

  /// Complete captioning step
  void completeCaptioning() {
    setStepStatus(TrainingWorkflowStep.captionFrames, StepStatus.completed);
    setStep(TrainingWorkflowStep.buildDataset);
  }

  // ============================================================
  // Step 4: Build Dataset
  // ============================================================

  /// Update dataset settings
  void updateDatasetSettings(DatasetSettings settings) {
    state = state.copyWith(datasetSettings: settings);
    _validateDataset();
  }

  /// Validate dataset configuration
  void _validateDataset() {
    final isValid = state.datasetSettings.name.isNotEmpty &&
        state.captionedFrames.isNotEmpty &&
        state.captionedFrames.every((cf) => cf.caption.isNotEmpty);
    state = state.copyWith(datasetValid: isValid);
  }

  /// Build the dataset
  Future<void> buildDataset() async {
    setStepStatus(TrainingWorkflowStep.buildDataset, StepStatus.inProgress);

    try {
      // Simulate dataset building
      // In real implementation, this would create the dataset folder structure
      await Future.delayed(const Duration(seconds: 2));

      final datasetPath = '/tmp/datasets/${state.datasetSettings.name}';
      state = state.copyWith(datasetPath: datasetPath);

      setStepStatus(TrainingWorkflowStep.buildDataset, StepStatus.completed);
      setStep(TrainingWorkflowStep.startTraining);
    } catch (e) {
      setStepStatus(TrainingWorkflowStep.buildDataset, StepStatus.error);
      state = state.copyWith(errorMessage: 'Dataset build failed: $e');
    }
  }

  // ============================================================
  // Step 5: Start Training
  // ============================================================

  /// Load available training configs
  Future<void> _loadAvailableConfigs() async {
    // In real implementation, this would scan for .json config files
    final configs = [
      const TrainingConfig(
        name: 'Flux LoRA Default',
        path: '/configs/flux_lora.json',
        modelType: 'Flux',
        trainingMethod: 'LoRA',
        estimatedMinutes: 45,
      ),
      const TrainingConfig(
        name: 'SDXL LoRA Default',
        path: '/configs/sdxl_lora.json',
        modelType: 'SDXL',
        trainingMethod: 'LoRA',
        estimatedMinutes: 30,
      ),
      const TrainingConfig(
        name: 'SD1.5 Fine-tune',
        path: '/configs/sd15_finetune.json',
        modelType: 'SD 1.5',
        trainingMethod: 'Fine-tune',
        estimatedMinutes: 120,
      ),
    ];
    state = state.copyWith(availableConfigs: configs);
  }

  /// Select training config
  void selectConfig(TrainingConfig config) {
    state = state.copyWith(selectedConfig: config);
  }

  /// Start training
  Future<void> startTraining({bool runInBackground = false}) async {
    if (state.selectedConfig == null) {
      state = state.copyWith(errorMessage: 'Please select a training config');
      return;
    }

    setStepStatus(TrainingWorkflowStep.startTraining, StepStatus.inProgress);
    state = state.copyWith(isTrainingRunning: true, trainingProgress: 0.0);

    // In real implementation, this would launch the trainer
    // For now, simulate progress
    if (!runInBackground) {
      try {
        for (int i = 0; i <= 100; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          state = state.copyWith(trainingProgress: i / 100);
        }

        state = state.copyWith(isTrainingRunning: false);
        setStepStatus(TrainingWorkflowStep.startTraining, StepStatus.completed);
      } catch (e) {
        state = state.copyWith(
          isTrainingRunning: false,
          errorMessage: 'Training failed: $e',
        );
        setStepStatus(TrainingWorkflowStep.startTraining, StepStatus.error);
      }
    }
  }

  /// Reset workflow
  void reset() {
    state = const TrainingWorkflowState();
    _loadAvailableConfigs();
  }
}

// ============================================================
// Providers
// ============================================================

/// Provider for training workflow state
final trainingWorkflowProvider =
    StateNotifierProvider<TrainingWorkflowNotifier, TrainingWorkflowState>(
  (ref) => TrainingWorkflowNotifier(),
);

// ============================================================
// Main Panel Widget
// ============================================================

/// A collapsible panel for the video-to-LoRA training workflow.
///
/// Features:
/// - 5-step workflow with stepper UI
/// - Frame extraction with thumbnail grid
/// - Caption editing with bulk operations
/// - Dataset configuration and validation
/// - Training config selection and launch
class TrainingWorkflowPanel extends ConsumerWidget {
  /// Callback when training is launched in a new tab
  final VoidCallback? onOpenTrainerTab;

  /// Callback to close the panel
  final VoidCallback? onClose;

  const TrainingWorkflowPanel({
    super.key,
    this.onOpenTrainerTab,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(trainingWorkflowProvider);
    final notifier = ref.read(trainingWorkflowProvider.notifier);

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
          // Header with collapse button
          _PanelHeader(
            isExpanded: state.isPanelExpanded,
            onToggle: notifier.togglePanel,
          ),

          // Collapsible content
          if (state.isPanelExpanded) ...[
            // Stepper
            Expanded(
              child: _WorkflowStepper(
                currentStep: state.currentStep,
                stepStatuses: state.stepStatuses,
                onStepTapped: notifier.setStep,
                state: state,
                notifier: notifier,
                onOpenTrainerTab: onOpenTrainerTab,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Panel header with title and collapse toggle
class _PanelHeader extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;

  const _PanelHeader({
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            Icon(
              Icons.model_training,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Training Workflow',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Workflow stepper widget
class _WorkflowStepper extends StatelessWidget {
  final TrainingWorkflowStep currentStep;
  final Map<TrainingWorkflowStep, StepStatus> stepStatuses;
  final Function(TrainingWorkflowStep) onStepTapped;
  final TrainingWorkflowState state;
  final TrainingWorkflowNotifier notifier;
  final VoidCallback? onOpenTrainerTab;

  const _WorkflowStepper({
    required this.currentStep,
    required this.stepStatuses,
    required this.onStepTapped,
    required this.state,
    required this.notifier,
    this.onOpenTrainerTab,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicators
          _StepIndicators(
            currentStep: currentStep,
            stepStatuses: stepStatuses,
            onStepTapped: onStepTapped,
          ),

          const SizedBox(height: 16),

          // Current step content
          _buildStepContent(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, ColorScheme colorScheme) {
    switch (currentStep) {
      case TrainingWorkflowStep.selectRegion:
        return _SelectRegionStep(
          state: state,
          notifier: notifier,
        );
      case TrainingWorkflowStep.extractFrames:
        return _ExtractFramesStep(
          state: state,
          notifier: notifier,
        );
      case TrainingWorkflowStep.captionFrames:
        return _CaptionFramesStep(
          state: state,
          notifier: notifier,
        );
      case TrainingWorkflowStep.buildDataset:
        return _BuildDatasetStep(
          state: state,
          notifier: notifier,
        );
      case TrainingWorkflowStep.startTraining:
        return _StartTrainingStep(
          state: state,
          notifier: notifier,
          onOpenTrainerTab: onOpenTrainerTab,
        );
    }
  }
}

/// Step indicators showing workflow progress
class _StepIndicators extends StatelessWidget {
  final TrainingWorkflowStep currentStep;
  final Map<TrainingWorkflowStep, StepStatus> stepStatuses;
  final Function(TrainingWorkflowStep) onStepTapped;

  const _StepIndicators({
    required this.currentStep,
    required this.stepStatuses,
    required this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 4,
      runSpacing: 8,
      children: TrainingWorkflowStep.values.map((step) {
        final status = stepStatuses[step] ?? StepStatus.pending;
        final isCurrent = step == currentStep;

        return InkWell(
          onTap: () => onStepTapped(step),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCurrent
                  ? colorScheme.primaryContainer
                  : status == StepStatus.completed
                      ? colorScheme.tertiaryContainer.withOpacity(0.5)
                      : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrent
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepIcon(status: status, isCurrent: isCurrent),
                const SizedBox(width: 4),
                Text(
                  '${step.stepIndex + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Step status icon
class _StepIcon extends StatelessWidget {
  final StepStatus status;
  final bool isCurrent;

  const _StepIcon({required this.status, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (status) {
      case StepStatus.completed:
        return Icon(Icons.check_circle, size: 14, color: Colors.green);
      case StepStatus.inProgress:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        );
      case StepStatus.error:
        return Icon(Icons.error, size: 14, color: colorScheme.error);
      case StepStatus.pending:
      default:
        return Icon(
          isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          size: 14,
          color: isCurrent ? colorScheme.primary : colorScheme.onSurfaceVariant,
        );
    }
  }
}

// ============================================================
// Step 1: Select Region
// ============================================================

class _SelectRegionStep extends ConsumerWidget {
  final TrainingWorkflowState state;
  final TrainingWorkflowNotifier notifier;

  const _SelectRegionStep({
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final editorState = ref.watch(editorProjectProvider);
    final project = editorState.project;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Select Region'),
        const SizedBox(height: 8),

        // Region selection mode
        RadioListTile<bool>(
          title: const Text('Use full clip', style: TextStyle(fontSize: 13)),
          subtitle: const Text('Extract frames from entire video', style: TextStyle(fontSize: 11)),
          value: true,
          groupValue: state.useFullClip,
          onChanged: (v) => notifier.setUseFullClip(v ?? true),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<bool>(
          title: const Text('Use I/O points', style: TextStyle(fontSize: 13)),
          subtitle: Text(
            project.inPoint != null && project.outPoint != null
                ? '${project.inPoint} - ${project.outPoint}'
                : 'Set In/Out points in the timeline',
            style: TextStyle(
              fontSize: 11,
              color: project.inPoint == null ? colorScheme.error : null,
            ),
          ),
          value: false,
          groupValue: state.useFullClip,
          onChanged: project.inPoint != null ? (v) => notifier.setUseFullClip(v ?? true) : null,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),

        const SizedBox(height: 16),

        // Source clip selection
        _SectionTitle(title: 'Source Clip'),
        const SizedBox(height: 8),

        if (editorState.selectedClips.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select a video clip in the timeline',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...editorState.selectedClips.map((clip) => _ClipCard(
                clip: clip,
                isSelected: state.sourceClipId == clip.id,
                onTap: () => notifier.setSourceClip(clip.id),
              )),

        const SizedBox(height: 16),

        // Continue button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: state.sourceClipId != null || editorState.selectedClips.isNotEmpty
                ? () {
                    if (state.sourceClipId == null && editorState.selectedClips.isNotEmpty) {
                      notifier.setSourceClip(editorState.selectedClips.first.id);
                    }
                    if (!state.useFullClip) {
                      notifier.setRegion(project.inPoint, project.outPoint);
                    }
                    notifier.completeRegionSelection();
                  }
                : null,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Continue'),
          ),
        ),
      ],
    );
  }
}

/// Card showing a clip summary
class _ClipCard extends StatelessWidget {
  final EditorClip clip;
  final bool isSelected;
  final VoidCallback onTap;

  const _ClipCard({
    required this.clip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                clip.type == ClipType.video ? Icons.videocam : Icons.image,
                size: 24,
                color: clip.color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clip.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Duration: ${clip.duration}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Step 2: Extract Frames
// ============================================================

class _ExtractFramesStep extends StatelessWidget {
  final TrainingWorkflowState state;
  final TrainingWorkflowNotifier notifier;

  const _ExtractFramesStep({
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final isExtracting = state.stepStatuses[TrainingWorkflowStep.extractFrames] == StepStatus.inProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Extraction Settings'),
        const SizedBox(height: 8),

        // Method selection
        DropdownButtonFormField<ExtractionMethod>(
          value: state.extractionSettings.method,
          decoration: const InputDecoration(
            labelText: 'Extraction Method',
            isDense: true,
          ),
          items: ExtractionMethod.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
              .toList(),
          onChanged: isExtracting
              ? null
              : (m) => notifier.updateExtractionSettings(
                    state.extractionSettings.copyWith(method: m),
                  ),
        ),

        const SizedBox(height: 12),

        // Method-specific settings
        if (state.extractionSettings.method == ExtractionMethod.interval)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: state.extractionSettings.intervalSeconds.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Interval (seconds)',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !isExtracting,
                  onChanged: (v) {
                    final interval = double.tryParse(v);
                    if (interval != null && interval > 0) {
                      notifier.updateExtractionSettings(
                        state.extractionSettings.copyWith(intervalSeconds: interval),
                      );
                    }
                  },
                ),
              ),
            ],
          ),

        if (state.extractionSettings.method == ExtractionMethod.count)
          TextFormField(
            initialValue: state.extractionSettings.frameCount.toString(),
            decoration: const InputDecoration(
              labelText: 'Frame Count',
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            enabled: !isExtracting,
            onChanged: (v) {
              final count = int.tryParse(v);
              if (count != null && count > 0) {
                notifier.updateExtractionSettings(
                  state.extractionSettings.copyWith(frameCount: count),
                );
              }
            },
          ),

        const SizedBox(height: 12),

        // Include keyframes option
        CheckboxListTile(
          title: const Text('Include keyframes', style: TextStyle(fontSize: 13)),
          value: state.extractionSettings.includeKeyframes,
          onChanged: isExtracting
              ? null
              : (v) => notifier.updateExtractionSettings(
                    state.extractionSettings.copyWith(includeKeyframes: v),
                  ),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),

        const SizedBox(height: 16),

        // Extract button or progress
        if (isExtracting)
          _ProgressIndicator(
            label: 'Extracting frames...',
            progress: state.extractionProgress,
          )
        else if (state.extractedFrames.isEmpty)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => notifier.startFrameExtraction(),
              icon: const Icon(Icons.photo_library, size: 18),
              label: const Text('Extract Frames'),
            ),
          ),

        // Frame grid preview
        if (state.extractedFrames.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle(title: 'Extracted Frames (${state.includedFrameCount}/${state.extractedFrames.length})'),
          const SizedBox(height: 8),

          // Bulk actions
          Row(
            children: [
              TextButton(
                onPressed: () => notifier.setAllFramesInclusion(true),
                child: const Text('Include All'),
              ),
              TextButton(
                onPressed: () => notifier.setAllFramesInclusion(false),
                child: const Text('Exclude All'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Frame grid
          _FrameGrid(
            frames: state.extractedFrames,
            onToggleFrame: notifier.toggleFrameInclusion,
          ),

          const SizedBox(height: 16),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.includedFrameCount > 0
                  ? () => notifier.completeFrameExtraction()
                  : null,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Continue'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Grid of extracted frame thumbnails
class _FrameGrid extends StatelessWidget {
  final List<ExtractedFrame> frames;
  final Function(String) onToggleFrame;

  const _FrameGrid({
    required this.frames,
    required this.onToggleFrame,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.0,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: frames.length,
        itemBuilder: (context, index) {
          final frame = frames[index];
          return _FrameThumbnail(
            frame: frame,
            onTap: () => onToggleFrame(frame.id),
          );
        },
      ),
    );
  }
}

/// Individual frame thumbnail
class _FrameThumbnail extends StatelessWidget {
  final ExtractedFrame frame;
  final VoidCallback onTap;

  const _FrameThumbnail({
    required this.frame,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: frame.isIncluded
                ? colorScheme.primary
                : colorScheme.outlineVariant.withOpacity(0.5),
            width: frame.isIncluded ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Placeholder for thumbnail
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Icon(
                  Icons.image,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ),
            ),

            // Excluded overlay
            if (!frame.isIncluded)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Icon(Icons.close, color: Colors.white),
                ),
              ),

            // Keyframe indicator
            if (frame.isKeyframe)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.key, size: 12, color: Colors.black),
                ),
              ),

            // Timecode
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  frame.displayTimecode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Step 3: Caption Frames
// ============================================================

class _CaptionFramesStep extends StatelessWidget {
  final TrainingWorkflowState state;
  final TrainingWorkflowNotifier notifier;

  const _CaptionFramesStep({
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final isCaptioning = state.stepStatuses[TrainingWorkflowStep.captionFrames] == StepStatus.inProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Auto-Caption'),
        const SizedBox(height: 8),

        // Caption progress or start button
        if (isCaptioning)
          _ProgressIndicator(
            label: 'Captioning frames...',
            progress: state.captionProgress,
          )
        else if (state.captionedFrames.every((cf) => cf.caption.isEmpty))
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => notifier.startAutoCaptioning(),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Auto-Caption Frames'),
            ),
          ),

        // Bulk edit options
        if (state.captionedFrames.any((cf) => cf.caption.isNotEmpty)) ...[
          const SizedBox(height: 16),
          _SectionTitle(title: 'Bulk Edit'),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: state.captionPrefix,
                  decoration: const InputDecoration(
                    labelText: 'Prefix',
                    isDense: true,
                    hintText: 'e.g., "A photo of"',
                  ),
                  onChanged: notifier.setCaptionPrefix,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: state.captionSuffix,
                  decoration: const InputDecoration(
                    labelText: 'Suffix',
                    isDense: true,
                    hintText: 'e.g., ", high quality"',
                  ),
                  onChanged: notifier.setCaptionSuffix,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (state.captionPrefix.isNotEmpty || state.captionSuffix.isNotEmpty)
                  ? () => notifier.applyPrefixSuffix()
                  : null,
              icon: const Icon(Icons.playlist_add, size: 18),
              label: const Text('Apply to All'),
            ),
          ),

          const SizedBox(height: 16),
          _SectionTitle(title: 'Caption Preview (${state.captionedFrames.length})'),
          const SizedBox(height: 8),

          // Caption list
          _CaptionList(
            captionedFrames: state.captionedFrames,
            onUpdateCaption: notifier.updateCaption,
          ),

          const SizedBox(height: 16),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.captionedFrames.every((cf) => cf.caption.isNotEmpty)
                  ? () => notifier.completeCaptioning()
                  : null,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Continue'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Scrollable list of captioned frames
class _CaptionList extends StatelessWidget {
  final List<CaptionedFrame> captionedFrames;
  final Function(int, String) onUpdateCaption;

  const _CaptionList({
    required this.captionedFrames,
    required this.onUpdateCaption,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 300,
      child: ListView.builder(
        itemCount: captionedFrames.length,
        itemBuilder: (context, index) {
          final cf = captionedFrames[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Frame thumbnail placeholder
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                            size: 20,
                          ),
                          Text(
                            cf.frame.displayTimecode,
                            style: TextStyle(
                              fontSize: 8,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Caption text field
                  Expanded(
                    child: TextFormField(
                      initialValue: cf.caption,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Enter caption...',
                        suffixIcon: cf.isEdited
                            ? Icon(Icons.edit, size: 16, color: colorScheme.primary)
                            : null,
                      ),
                      maxLines: 3,
                      minLines: 2,
                      style: const TextStyle(fontSize: 12),
                      onChanged: (v) => onUpdateCaption(index, v),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// Step 4: Build Dataset
// ============================================================

class _BuildDatasetStep extends StatelessWidget {
  final TrainingWorkflowState state;
  final TrainingWorkflowNotifier notifier;

  const _BuildDatasetStep({
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final isBuilding = state.stepStatuses[TrainingWorkflowStep.buildDataset] == StepStatus.inProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Dataset Configuration'),
        const SizedBox(height: 8),

        // Dataset name
        TextFormField(
          initialValue: state.datasetSettings.name,
          decoration: const InputDecoration(
            labelText: 'Dataset Name',
            isDense: true,
          ),
          enabled: !isBuilding,
          onChanged: (v) => notifier.updateDatasetSettings(
            state.datasetSettings.copyWith(name: v),
          ),
        ),

        const SizedBox(height: 12),

        // Format selection
        DropdownButtonFormField<String>(
          value: state.datasetSettings.format,
          decoration: const InputDecoration(
            labelText: 'Format',
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: 'kohya', child: Text('Kohya (Standard)')),
            DropdownMenuItem(value: 'dreambooth', child: Text('DreamBooth')),
            DropdownMenuItem(value: 'raw', child: Text('Raw (Images + Captions)')),
          ],
          onChanged: isBuilding
              ? null
              : (v) => notifier.updateDatasetSettings(
                    state.datasetSettings.copyWith(format: v),
                  ),
        ),

        const SizedBox(height: 12),

        // Resolution
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: state.datasetSettings.resolution.toString(),
                decoration: const InputDecoration(
                  labelText: 'Resolution',
                  isDense: true,
                  suffixText: 'px',
                ),
                keyboardType: TextInputType.number,
                enabled: !isBuilding,
                onChanged: (v) {
                  final res = int.tryParse(v);
                  if (res != null && res > 0) {
                    notifier.updateDatasetSettings(
                      state.datasetSettings.copyWith(resolution: res),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: state.datasetSettings.repeats.toString(),
                decoration: const InputDecoration(
                  labelText: 'Repeats',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                enabled: !isBuilding,
                onChanged: (v) {
                  final repeats = int.tryParse(v);
                  if (repeats != null && repeats > 0) {
                    notifier.updateDatasetSettings(
                      state.datasetSettings.copyWith(repeats: repeats),
                    );
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Augmentation options
        CheckboxListTile(
          title: const Text('Center crop', style: TextStyle(fontSize: 13)),
          value: state.datasetSettings.centerCrop,
          onChanged: isBuilding
              ? null
              : (v) => notifier.updateDatasetSettings(
                    state.datasetSettings.copyWith(centerCrop: v),
                  ),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('Horizontal flip augmentation', style: TextStyle(fontSize: 13)),
          value: state.datasetSettings.flipAugment,
          onChanged: isBuilding
              ? null
              : (v) => notifier.updateDatasetSettings(
                    state.datasetSettings.copyWith(flipAugment: v),
                  ),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),

        const SizedBox(height: 16),

        // Dataset summary
        _DatasetSummary(
          imageCount: state.captionedFrames.length,
          repeats: state.datasetSettings.repeats,
          estimatedSteps: state.estimatedTrainingSteps,
          isValid: state.datasetValid,
        ),

        const SizedBox(height: 16),

        // Build button or progress
        if (isBuilding)
          _ProgressIndicator(
            label: 'Building dataset...',
            progress: null,
          )
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.datasetSettings.name.isNotEmpty
                  ? () => notifier.buildDataset()
                  : null,
              icon: const Icon(Icons.folder_special, size: 18),
              label: const Text('Build Dataset'),
            ),
          ),
      ],
    );
  }
}

/// Dataset summary card
class _DatasetSummary extends StatelessWidget {
  final int imageCount;
  final int repeats;
  final int estimatedSteps;
  final bool isValid;

  const _DatasetSummary({
    required this.imageCount,
    required this.repeats,
    required this.estimatedSteps,
    required this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid
              ? colorScheme.primary.withOpacity(0.5)
              : colorScheme.error.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.check_circle : Icons.warning,
                size: 16,
                color: isValid ? Colors.green : colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Dataset Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Total Images', value: imageCount.toString()),
          _SummaryRow(label: 'Repeats', value: repeats.toString()),
          _SummaryRow(label: 'Est. Training Steps', value: estimatedSteps.toString()),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ============================================================
// Step 5: Start Training
// ============================================================

class _StartTrainingStep extends StatelessWidget {
  final TrainingWorkflowState state;
  final TrainingWorkflowNotifier notifier;
  final VoidCallback? onOpenTrainerTab;

  const _StartTrainingStep({
    required this.state,
    required this.notifier,
    this.onOpenTrainerTab,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Training Configuration'),
        const SizedBox(height: 8),

        // Config selection
        if (state.availableConfigs.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No training configs found. Create one in the Trainer tab.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          ...state.availableConfigs.map((config) => _ConfigCard(
                config: config,
                isSelected: state.selectedConfig?.name == config.name,
                onTap: () => notifier.selectConfig(config),
              )),

        const SizedBox(height: 16),

        // Training progress or launch buttons
        if (state.isTrainingRunning)
          _ProgressIndicator(
            label: 'Training in progress...',
            progress: state.trainingProgress,
          )
        else ...[
          // Estimated time
          if (state.selectedConfig != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated time: ~${state.selectedConfig!.estimatedMinutes} minutes',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

          // Launch buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.selectedConfig != null && onOpenTrainerTab != null
                      ? onOpenTrainerTab
                      : null,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open Trainer'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.selectedConfig != null
                      ? () => notifier.startTraining(runInBackground: true)
                      : null,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Start'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Training config card
class _ConfigCard extends StatelessWidget {
  final TrainingConfig config;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConfigCard({
    required this.config,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.settings,
                size: 24,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${config.modelType} - ${config.trainingMethod}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Shared Widgets
// ============================================================

/// Section title widget
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

/// Progress indicator with label
class _ProgressIndicator extends StatelessWidget {
  final String label;
  final double? progress;

  const _ProgressIndicator({
    required this.label,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = progress != null ? '${(progress! * 100).toStringAsFixed(0)}%' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress,
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
            if (percentage.isNotEmpty) ...[
              const Spacer(),
              Text(
                percentage,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (progress != null)
          LinearProgressIndicator(
            value: progress,
            backgroundColor: colorScheme.surfaceContainerHighest,
          )
        else
          LinearProgressIndicator(
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
      ],
    );
  }
}
