import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../models/editor_models.dart';
import '../services/ffmpeg_service.dart';
import '../../../services/onetrainer_service.dart' as ot;

/// Workflow step enum for tracking the current phase of the training workflow
enum WorkflowStep {
  /// No workflow running
  idle,

  /// Extracting frames from video clip
  extracting,

  /// Generating captions for extracted frames
  captioning,

  /// Building dataset structure
  building,

  /// Running training on OneTrainer
  training,

  /// Workflow completed successfully
  complete,
}

/// Information about a training job
class TrainingJobInfo {
  /// Unique identifier for this job
  final String id;

  /// Display name for the job
  final String name;

  /// Path to the training config file
  final String configPath;

  /// Current training progress (0.0 - 1.0)
  final double progress;

  /// Current epoch number
  final int currentEpoch;

  /// Total number of epochs
  final int totalEpochs;

  /// Current step within epoch
  final int currentStep;

  /// Total steps in training
  final int totalSteps;

  /// Current loss value
  final double? loss;

  /// Elapsed time string
  final String? elapsedTime;

  /// Remaining time estimate
  final String? remainingTime;

  /// Whether training is currently running
  final bool isRunning;

  /// Error message if training failed
  final String? error;

  const TrainingJobInfo({
    required this.id,
    required this.name,
    required this.configPath,
    this.progress = 0.0,
    this.currentEpoch = 0,
    this.totalEpochs = 0,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.loss,
    this.elapsedTime,
    this.remainingTime,
    this.isRunning = false,
    this.error,
  });

  TrainingJobInfo copyWith({
    String? id,
    String? name,
    String? configPath,
    double? progress,
    int? currentEpoch,
    int? totalEpochs,
    int? currentStep,
    int? totalSteps,
    double? loss,
    String? elapsedTime,
    String? remainingTime,
    bool? isRunning,
    String? error,
  }) {
    return TrainingJobInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      configPath: configPath ?? this.configPath,
      progress: progress ?? this.progress,
      currentEpoch: currentEpoch ?? this.currentEpoch,
      totalEpochs: totalEpochs ?? this.totalEpochs,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      loss: loss ?? this.loss,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      remainingTime: remainingTime ?? this.remainingTime,
      isRunning: isRunning ?? this.isRunning,
      error: error,
    );
  }
}

/// An extracted frame from a video clip
class ExtractedFrame {
  /// Unique identifier
  final String id;

  /// Path to the extracted image file
  final String imagePath;

  /// Original source video path
  final String sourceVideoPath;

  /// Timestamp in the source video
  final Duration timestamp;

  /// Frame index in the extraction sequence
  final int frameIndex;

  /// Image width in pixels
  final int? width;

  /// Image height in pixels
  final int? height;

  const ExtractedFrame({
    required this.id,
    required this.imagePath,
    required this.sourceVideoPath,
    required this.timestamp,
    required this.frameIndex,
    this.width,
    this.height,
  });
}

/// Settings for frame extraction from video clips
class FrameExtractionSettings {
  /// Target frames per second for extraction
  final double fps;

  /// Start time offset within the clip
  final Duration startOffset;

  /// End time offset (null = use clip end)
  final Duration? endOffset;

  /// Target width for extracted frames (null = original)
  final int? targetWidth;

  /// Target height for extracted frames (null = original)
  final int? targetHeight;

  /// Output directory for extracted frames
  final String outputDirectory;

  /// Image format for extracted frames
  final String imageFormat;

  /// JPEG quality (1-100) if using JPEG format
  final int jpegQuality;

  const FrameExtractionSettings({
    this.fps = 1.0,
    this.startOffset = Duration.zero,
    this.endOffset,
    this.targetWidth,
    this.targetHeight,
    required this.outputDirectory,
    this.imageFormat = 'jpg',
    this.jpegQuality = 95,
  });

  FrameExtractionSettings copyWith({
    double? fps,
    Duration? startOffset,
    Duration? endOffset,
    int? targetWidth,
    int? targetHeight,
    String? outputDirectory,
    String? imageFormat,
    int? jpegQuality,
  }) {
    return FrameExtractionSettings(
      fps: fps ?? this.fps,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      imageFormat: imageFormat ?? this.imageFormat,
      jpegQuality: jpegQuality ?? this.jpegQuality,
    );
  }
}

/// Settings for caption generation
class CaptionSettings {
  /// Caption model to use (e.g., 'blip', 'florence', 'custom')
  final String model;

  /// Prompt prefix for caption generation
  final String promptPrefix;

  /// Prompt suffix for caption generation
  final String promptSuffix;

  /// Maximum caption length in tokens
  final int maxLength;

  /// Whether to include trigger word
  final bool includeTrigger;

  /// Trigger word to prepend to captions
  final String triggerWord;

  /// Whether to save captions as .txt files alongside images
  final bool saveCaptionFiles;

  const CaptionSettings({
    this.model = 'blip',
    this.promptPrefix = '',
    this.promptSuffix = '',
    this.maxLength = 77,
    this.includeTrigger = true,
    this.triggerWord = 'sks',
    this.saveCaptionFiles = true,
  });

  CaptionSettings copyWith({
    String? model,
    String? promptPrefix,
    String? promptSuffix,
    int? maxLength,
    bool? includeTrigger,
    String? triggerWord,
    bool? saveCaptionFiles,
  }) {
    return CaptionSettings(
      model: model ?? this.model,
      promptPrefix: promptPrefix ?? this.promptPrefix,
      promptSuffix: promptSuffix ?? this.promptSuffix,
      maxLength: maxLength ?? this.maxLength,
      includeTrigger: includeTrigger ?? this.includeTrigger,
      triggerWord: triggerWord ?? this.triggerWord,
      saveCaptionFiles: saveCaptionFiles ?? this.saveCaptionFiles,
    );
  }
}

/// Configuration for dataset creation
class DatasetConfig {
  /// Name of the dataset/concept
  final String name;

  /// Path to the image directory
  final String imagePath;

  /// Concept type (STANDARD, PRIOR_PRESERVATION, etc.)
  final String conceptType;

  /// Number of repeats for this concept
  final int repeats;

  /// Whether this is a regularization/class dataset
  final bool isRegularization;

  /// Class prompt for prior preservation
  final String? classPrompt;

  const DatasetConfig({
    required this.name,
    required this.imagePath,
    this.conceptType = 'STANDARD',
    this.repeats = 1,
    this.isRegularization = false,
    this.classPrompt,
  });

  DatasetConfig copyWith({
    String? name,
    String? imagePath,
    String? conceptType,
    int? repeats,
    bool? isRegularization,
    String? classPrompt,
  }) {
    return DatasetConfig(
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      conceptType: conceptType ?? this.conceptType,
      repeats: repeats ?? this.repeats,
      isRegularization: isRegularization ?? this.isRegularization,
      classPrompt: classPrompt ?? this.classPrompt,
    );
  }

  /// Convert to OneTrainer concept format
  Map<String, dynamic> toConceptMap() {
    return {
      'name': name,
      'path': imagePath,
      'concept_type': conceptType,
      'repeats': repeats,
      'is_regularization_concept': isRegularization,
      if (classPrompt != null) 'class_prompt': classPrompt,
    };
  }
}

/// Information about a created dataset
class DatasetInfo {
  /// Unique identifier
  final String id;

  /// Dataset name
  final String name;

  /// Path to the dataset directory
  final String path;

  /// Number of images in the dataset
  final int imageCount;

  /// Total file size in bytes
  final int totalSize;

  /// List of concept configurations
  final List<DatasetConfig> concepts;

  /// Creation timestamp
  final DateTime createdAt;

  const DatasetInfo({
    required this.id,
    required this.name,
    required this.path,
    this.imageCount = 0,
    this.totalSize = 0,
    this.concepts = const [],
    required this.createdAt,
  });
}

/// Complete workflow configuration for video-to-training pipeline
class TrainingWorkflowConfig {
  /// Frame extraction settings
  final FrameExtractionSettings frameSettings;

  /// Caption generation settings
  final CaptionSettings captionSettings;

  /// Dataset configuration
  final DatasetConfig datasetConfig;

  /// Name of the OneTrainer preset to use
  final String trainingPresetName;

  /// Path to the OneTrainer config file (if not using preset)
  final String? trainingConfigPath;

  /// Whether to automatically start training after dataset creation
  final bool autoStart;

  /// Custom training overrides to apply to the config
  final Map<String, dynamic>? trainingOverrides;

  const TrainingWorkflowConfig({
    required this.frameSettings,
    required this.captionSettings,
    required this.datasetConfig,
    required this.trainingPresetName,
    this.trainingConfigPath,
    this.autoStart = false,
    this.trainingOverrides,
  });
}

/// State for the trainer bridge
class TrainerBridgeState {
  /// Whether connected to OneTrainer backend
  final bool isConnected;

  /// Current training job information
  final TrainingJobInfo? currentTrainingJob;

  /// Available training configuration presets
  final List<ot.PresetInfo> availableConfigs;

  /// Frames extracted from the current workflow
  final List<ExtractedFrame> extractedFrames;

  /// Generated captions mapped by image path
  final Map<String, String> generatedCaptions;

  /// Information about the created dataset
  final DatasetInfo? createdDataset;

  /// Current workflow step
  final WorkflowStep workflowStep;

  /// Overall workflow progress (0.0 - 1.0)
  final double workflowProgress;

  /// Error message if workflow failed
  final String? error;

  /// Status message for current operation
  final String? statusMessage;

  /// Currently selected clip for training
  final EditorClip? selectedClip;

  /// Whether a workflow is currently running
  bool get isWorkflowRunning =>
      workflowStep != WorkflowStep.idle &&
      workflowStep != WorkflowStep.complete;

  const TrainerBridgeState({
    this.isConnected = false,
    this.currentTrainingJob,
    this.availableConfigs = const [],
    this.extractedFrames = const [],
    this.generatedCaptions = const {},
    this.createdDataset,
    this.workflowStep = WorkflowStep.idle,
    this.workflowProgress = 0.0,
    this.error,
    this.statusMessage,
    this.selectedClip,
  });

  TrainerBridgeState copyWith({
    bool? isConnected,
    TrainingJobInfo? currentTrainingJob,
    List<ot.PresetInfo>? availableConfigs,
    List<ExtractedFrame>? extractedFrames,
    Map<String, String>? generatedCaptions,
    DatasetInfo? createdDataset,
    WorkflowStep? workflowStep,
    double? workflowProgress,
    String? error,
    String? statusMessage,
    EditorClip? selectedClip,
  }) {
    return TrainerBridgeState(
      isConnected: isConnected ?? this.isConnected,
      currentTrainingJob: currentTrainingJob ?? this.currentTrainingJob,
      availableConfigs: availableConfigs ?? this.availableConfigs,
      extractedFrames: extractedFrames ?? this.extractedFrames,
      generatedCaptions: generatedCaptions ?? this.generatedCaptions,
      createdDataset: createdDataset ?? this.createdDataset,
      workflowStep: workflowStep ?? this.workflowStep,
      workflowProgress: workflowProgress ?? this.workflowProgress,
      error: error,
      statusMessage: statusMessage,
      selectedClip: selectedClip ?? this.selectedClip,
    );
  }
}

/// Notifier for managing trainer bridge state
class TrainerBridgeNotifier extends StateNotifier<TrainerBridgeState> {
  // ignore: unused_field - kept for potential future use with other providers
  final Ref _ref;
  final FFmpegService _ffmpegService;
  final ot.OneTrainerService _trainerService;

  StreamSubscription? _trainingUpdateSub;
  StreamSubscription? _connectionSub;

  TrainerBridgeNotifier(this._ref)
      : _ffmpegService = FFmpegService(),
        _trainerService = ot.OneTrainerService(),
        super(const TrainerBridgeState()) {
    _initialize();
  }

  /// Select a clip for training workflow
  void selectClipForTraining(EditorClip clip) {
    state = state.copyWith(
      selectedClip: clip,
      workflowStep: WorkflowStep.idle,
    );
  }

  Future<void> _initialize() async {
    // Subscribe to connection state changes
    _connectionSub = _trainerService.connectionState.listen((connState) {
      state = state.copyWith(
        isConnected: connState == ot.OneTrainerConnectionState.connected,
      );
    });

    // Subscribe to training updates
    _trainingUpdateSub = _trainerService.trainingUpdates.listen(_handleTrainingUpdate);

    // Try to connect
    await connect();
  }

  void _handleTrainingUpdate(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final updateData = data['data'] as Map<String, dynamic>? ?? data;

    if (state.currentTrainingJob == null) return;

    switch (type) {
      case 'progress':
      case 'training_progress':
        final progress = ot.TrainingProgress.fromJson(updateData);
        final totalProgress = progress.totalSteps > 0
            ? progress.currentStep / progress.totalSteps
            : 0.0;

        state = state.copyWith(
          currentTrainingJob: state.currentTrainingJob!.copyWith(
            progress: totalProgress,
            currentEpoch: progress.currentEpoch,
            totalEpochs: progress.totalEpochs,
            currentStep: progress.currentStep,
            totalSteps: progress.totalSteps,
            loss: progress.loss,
            elapsedTime: progress.elapsedTime,
            remainingTime: progress.remainingTime,
          ),
        );

        // Update workflow progress if in training step
        if (state.workflowStep == WorkflowStep.training) {
          // Training is the last 40% of workflow (60-100%)
          final workflowProgress = 0.6 + (totalProgress * 0.4);
          state = state.copyWith(
            workflowProgress: workflowProgress,
            statusMessage:
                'Training: Epoch ${progress.currentEpoch}/${progress.totalEpochs}, '
                'Step ${progress.currentStep}/${progress.totalSteps}',
          );
        }
        break;

      case 'training_state':
      case 'training_status':
        final isTraining =
            updateData['is_training'] as bool? ?? updateData['status'] == 'training';
        final error = updateData['error'] as String?;

        state = state.copyWith(
          currentTrainingJob: state.currentTrainingJob!.copyWith(
            isRunning: isTraining,
            error: error,
          ),
        );

        // Handle training completion
        if (!isTraining && state.workflowStep == WorkflowStep.training) {
          state = state.copyWith(
            workflowStep: WorkflowStep.complete,
            workflowProgress: 1.0,
            statusMessage: 'Training completed!',
          );
        }
        break;
    }
  }

  /// Connect to the OneTrainer backend
  Future<bool> connect() async {
    final connected = await _trainerService.connect();
    if (connected) {
      await loadAvailableConfigs();
    }
    state = state.copyWith(isConnected: connected);
    return connected;
  }

  /// Load available training configuration presets
  Future<void> loadAvailableConfigs() async {
    final presets = await _trainerService.getPresets();
    state = state.copyWith(availableConfigs: presets);
  }

  /// Start the full video-to-training workflow
  Future<bool> startWorkflow(EditorClip clip, TrainingWorkflowConfig config) async {
    if (state.isWorkflowRunning) {
      state = state.copyWith(error: 'A workflow is already running');
      return false;
    }

    // Reset state for new workflow
    state = state.copyWith(
      workflowStep: WorkflowStep.extracting,
      workflowProgress: 0.0,
      extractedFrames: [],
      generatedCaptions: {},
      createdDataset: null,
      error: null,
      statusMessage: 'Starting workflow...',
    );

    try {
      // Step 1: Extract frames (0-30%)
      final extractionSuccess = await extractFramesFromClip(
        clip,
        config.frameSettings,
      );

      if (!extractionSuccess || state.extractedFrames.isEmpty) {
        state = state.copyWith(
          workflowStep: WorkflowStep.idle,
          error: 'Frame extraction failed',
        );
        return false;
      }

      // Step 2: Generate captions (30-50%)
      state = state.copyWith(
        workflowStep: WorkflowStep.captioning,
        statusMessage: 'Generating captions...',
      );

      final captioningSuccess = await captionExtractedFrames(config.captionSettings);

      if (!captioningSuccess) {
        state = state.copyWith(
          workflowStep: WorkflowStep.idle,
          error: 'Caption generation failed',
        );
        return false;
      }

      // Step 3: Build dataset (50-60%)
      state = state.copyWith(
        workflowStep: WorkflowStep.building,
        statusMessage: 'Building dataset...',
      );

      final buildSuccess = await buildDataset(config.datasetConfig);

      if (!buildSuccess) {
        state = state.copyWith(
          workflowStep: WorkflowStep.idle,
          error: 'Dataset creation failed',
        );
        return false;
      }

      // Step 4: Launch training if autoStart (60-100%)
      if (config.autoStart) {
        state = state.copyWith(
          workflowStep: WorkflowStep.training,
          statusMessage: 'Starting training...',
        );

        // Create training config with dataset
        final trainingSuccess = await launchTraining(
          config.trainingPresetName,
          configPath: config.trainingConfigPath,
          overrides: config.trainingOverrides,
        );

        if (!trainingSuccess) {
          state = state.copyWith(
            error: 'Failed to launch training',
          );
          return false;
        }
      } else {
        // Workflow complete without training
        state = state.copyWith(
          workflowStep: WorkflowStep.complete,
          workflowProgress: 1.0,
          statusMessage: 'Dataset ready for training',
        );
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        workflowStep: WorkflowStep.idle,
        error: 'Workflow failed: $e',
      );
      return false;
    }
  }

  /// Extract frames from a video clip
  Future<bool> extractFramesFromClip(
    EditorClip clip,
    FrameExtractionSettings settings,
  ) async {
    if (clip.sourcePath == null) {
      state = state.copyWith(error: 'Clip has no source path');
      return false;
    }

    state = state.copyWith(
      workflowStep: WorkflowStep.extracting,
      statusMessage: 'Extracting frames...',
    );

    try {
      // Ensure output directory exists
      final outputDir = Directory(settings.outputDirectory);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Get media info for duration
      final mediaInfo = await _ffmpegService.getMediaInfo(clip.sourcePath!);
      if (mediaInfo == null) {
        state = state.copyWith(error: 'Could not read video file');
        return false;
      }

      // Calculate frame extraction parameters
      final startTime = clip.sourceStart.inSeconds + settings.startOffset.inMilliseconds / 1000.0;
      final endTime = settings.endOffset != null
          ? startTime + settings.endOffset!.inMilliseconds / 1000.0
          : startTime + clip.duration.inSeconds;

      final duration = endTime - startTime;
      final frameCount = (duration * settings.fps).ceil();

      final extractedFrames = <ExtractedFrame>[];

      for (int i = 0; i < frameCount; i++) {
        final timestamp = Duration(
          milliseconds: ((startTime + (i / settings.fps)) * 1000).round(),
        );

        final frameBytes = await _ffmpegService.extractFrame(
          clip.sourcePath!,
          timestamp,
          width: settings.targetWidth,
          height: settings.targetHeight,
        );

        if (frameBytes != null) {
          // Save frame to file
          final framePath = path.join(
            settings.outputDirectory,
            'frame_${i.toString().padLeft(5, '0')}.${settings.imageFormat}',
          );

          await File(framePath).writeAsBytes(frameBytes);

          extractedFrames.add(ExtractedFrame(
            id: 'frame_$i',
            imagePath: framePath,
            sourceVideoPath: clip.sourcePath!,
            timestamp: timestamp,
            frameIndex: i,
            width: settings.targetWidth,
            height: settings.targetHeight,
          ));
        }

        // Update progress (extracting is 0-30% of total workflow)
        final progress = (i + 1) / frameCount;
        state = state.copyWith(
          workflowProgress: progress * 0.3,
          statusMessage: 'Extracting frame ${i + 1}/$frameCount',
        );
      }

      state = state.copyWith(
        extractedFrames: extractedFrames,
        workflowProgress: 0.3,
        statusMessage: 'Extracted ${extractedFrames.length} frames',
      );

      return extractedFrames.isNotEmpty;
    } catch (e) {
      state = state.copyWith(error: 'Frame extraction failed: $e');
      return false;
    }
  }

  /// Generate captions for extracted frames
  Future<bool> captionExtractedFrames(CaptionSettings settings) async {
    if (state.extractedFrames.isEmpty) {
      state = state.copyWith(error: 'No frames to caption');
      return false;
    }

    state = state.copyWith(
      workflowStep: WorkflowStep.captioning,
      statusMessage: 'Generating captions...',
    );

    try {
      final captions = <String, String>{};
      final frameCount = state.extractedFrames.length;

      for (int i = 0; i < frameCount; i++) {
        final frame = state.extractedFrames[i];

        // Generate caption (placeholder - would connect to actual captioning service)
        String caption = settings.promptPrefix;

        if (settings.includeTrigger && settings.triggerWord.isNotEmpty) {
          caption = '${settings.triggerWord}, $caption';
        }

        // Add frame-specific description (placeholder)
        caption += 'frame ${frame.frameIndex}';
        caption += settings.promptSuffix;

        captions[frame.imagePath] = caption.trim();

        // Save caption file if requested
        if (settings.saveCaptionFiles) {
          final captionPath = frame.imagePath.replaceAll(
            RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false),
            '.txt',
          );
          await File(captionPath).writeAsString(caption);
        }

        // Update progress (captioning is 30-50% of total workflow)
        final progress = (i + 1) / frameCount;
        state = state.copyWith(
          workflowProgress: 0.3 + (progress * 0.2),
          statusMessage: 'Captioning ${i + 1}/$frameCount',
        );
      }

      state = state.copyWith(
        generatedCaptions: captions,
        workflowProgress: 0.5,
        statusMessage: 'Generated ${captions.length} captions',
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Caption generation failed: $e');
      return false;
    }
  }

  /// Build dataset structure for training
  Future<bool> buildDataset(DatasetConfig config) async {
    if (state.extractedFrames.isEmpty) {
      state = state.copyWith(error: 'No frames for dataset');
      return false;
    }

    state = state.copyWith(
      workflowStep: WorkflowStep.building,
      statusMessage: 'Building dataset...',
    );

    try {
      // Ensure the dataset directory exists
      final datasetDir = Directory(config.imagePath);
      if (!await datasetDir.exists()) {
        await datasetDir.create(recursive: true);
      }

      // Copy/move frames to dataset directory if needed
      int imageCount = 0;
      int totalSize = 0;

      for (final frame in state.extractedFrames) {
        final sourceFile = File(frame.imagePath);
        if (await sourceFile.exists()) {
          // If frame is already in the dataset directory, skip copy
          if (!frame.imagePath.startsWith(config.imagePath)) {
            final destPath = path.join(
              config.imagePath,
              path.basename(frame.imagePath),
            );
            await sourceFile.copy(destPath);

            // Also copy caption file if exists
            final captionPath = frame.imagePath.replaceAll(
              RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false),
              '.txt',
            );
            final captionFile = File(captionPath);
            if (await captionFile.exists()) {
              await captionFile.copy(
                path.join(config.imagePath, path.basename(captionPath)),
              );
            }
          }

          imageCount++;
          totalSize += await sourceFile.length();
        }
      }

      final datasetInfo = DatasetInfo(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: config.name,
        path: config.imagePath,
        imageCount: imageCount,
        totalSize: totalSize,
        concepts: [config],
        createdAt: DateTime.now(),
      );

      // Update progress (building is 50-60% of total workflow)
      state = state.copyWith(
        createdDataset: datasetInfo,
        workflowProgress: 0.6,
        statusMessage: 'Dataset created: $imageCount images',
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Dataset creation failed: $e');
      return false;
    }
  }

  /// Launch training on OneTrainer
  Future<bool> launchTraining(
    String presetName, {
    String? configPath,
    Map<String, dynamic>? overrides,
  }) async {
    if (!state.isConnected) {
      final connected = await connect();
      if (!connected) {
        state = state.copyWith(error: 'Not connected to OneTrainer');
        return false;
      }
    }

    state = state.copyWith(
      workflowStep: WorkflowStep.training,
      statusMessage: 'Preparing training...',
    );

    try {
      // Load the preset config
      Map<String, dynamic>? config;

      if (configPath != null) {
        // Use provided config file path directly
        final configFile = File(configPath);
        if (!await configFile.exists()) {
          state = state.copyWith(error: 'Config file not found: $configPath');
          return false;
        }
      } else {
        // Load preset and modify with dataset
        config = await _trainerService.loadPreset(presetName);
        if (config == null) {
          state = state.copyWith(error: 'Failed to load preset: $presetName');
          return false;
        }
      }

      // Add dataset concept to config
      if (config != null && state.createdDataset != null) {
        final concepts = (config['concepts'] as List<dynamic>?) ?? [];
        for (final concept in state.createdDataset!.concepts) {
          concepts.add(concept.toConceptMap());
        }
        config['concepts'] = concepts;
      }

      // Apply any overrides
      if (overrides != null && config != null) {
        config.addAll(overrides);
      }

      // Save config to temp file and start training
      String? trainingConfigPath = configPath;
      if (config != null) {
        trainingConfigPath = await _trainerService.saveTempConfig(config);
        if (trainingConfigPath == null) {
          state = state.copyWith(error: 'Failed to save training config');
          return false;
        }
      }

      // Create training job info
      final jobId = DateTime.now().microsecondsSinceEpoch.toString();
      final jobInfo = TrainingJobInfo(
        id: jobId,
        name: presetName,
        configPath: trainingConfigPath!,
        isRunning: true,
      );

      state = state.copyWith(
        currentTrainingJob: jobInfo,
        workflowProgress: 0.6,
        statusMessage: 'Starting training...',
      );

      // Start training
      final result = await _trainerService.startTraining(trainingConfigPath);

      if (!result.success) {
        state = state.copyWith(
          currentTrainingJob: jobInfo.copyWith(
            isRunning: false,
            error: result.message,
          ),
          error: 'Training failed to start: ${result.message}',
        );
        return false;
      }

      state = state.copyWith(
        statusMessage: 'Training started',
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to launch training: $e');
      return false;
    }
  }

  /// Cancel the current workflow
  Future<void> cancelWorkflow() async {
    // Cancel any FFmpeg operations
    await _ffmpegService.cancelAll();

    // Stop training if running
    if (state.currentTrainingJob?.isRunning == true) {
      await _trainerService.stopTraining();
    }

    state = state.copyWith(
      workflowStep: WorkflowStep.idle,
      workflowProgress: 0.0,
      currentTrainingJob: state.currentTrainingJob?.copyWith(isRunning: false),
      statusMessage: 'Workflow cancelled',
    );
  }

  /// Get current training progress from OneTrainer
  Future<Map<String, dynamic>?> getTrainingProgress() async {
    if (!state.isConnected) return null;
    return await _trainerService.getProgress();
  }

  /// Trigger a sample generation during training
  Future<bool> triggerSample() async {
    if (!state.isConnected || state.currentTrainingJob?.isRunning != true) {
      return false;
    }

    final result = await _trainerService.triggerSample();
    return result.success;
  }

  /// Trigger a checkpoint save during training
  Future<bool> triggerSave() async {
    if (!state.isConnected || state.currentTrainingJob?.isRunning != true) {
      return false;
    }

    final result = await _trainerService.triggerSave();
    return result.success;
  }

  @override
  void dispose() {
    _trainingUpdateSub?.cancel();
    _connectionSub?.cancel();
    _trainerService.dispose();
    super.dispose();
  }
}

// ============================================================
// Providers
// ============================================================

/// Main provider for the trainer bridge state
final trainerBridgeProvider =
    StateNotifierProvider<TrainerBridgeNotifier, TrainerBridgeState>(
  (ref) => TrainerBridgeNotifier(ref),
);

/// Provider for the current workflow step
final workflowStepProvider = Provider<WorkflowStep>(
  (ref) => ref.watch(trainerBridgeProvider).workflowStep,
);

/// Provider for the overall workflow progress (0.0 - 1.0)
final workflowProgressProvider = Provider<double>(
  (ref) => ref.watch(trainerBridgeProvider).workflowProgress,
);

/// Provider for whether a workflow is currently running
final isWorkflowRunningProvider = Provider<bool>(
  (ref) => ref.watch(trainerBridgeProvider).isWorkflowRunning,
);

/// Provider for the current training job info
final currentTrainingJobProvider = Provider<TrainingJobInfo?>(
  (ref) => ref.watch(trainerBridgeProvider).currentTrainingJob,
);

/// Provider for available training configs
final availableTrainingConfigsProvider = Provider<List<ot.PresetInfo>>(
  (ref) => ref.watch(trainerBridgeProvider).availableConfigs,
);

/// Provider for extracted frames
final extractedFramesProvider = Provider<List<ExtractedFrame>>(
  (ref) => ref.watch(trainerBridgeProvider).extractedFrames,
);

/// Provider for generated captions
final generatedCaptionsProvider = Provider<Map<String, String>>(
  (ref) => ref.watch(trainerBridgeProvider).generatedCaptions,
);

/// Provider for the created dataset info
final createdDatasetProvider = Provider<DatasetInfo?>(
  (ref) => ref.watch(trainerBridgeProvider).createdDataset,
);

/// Provider for connection status
final trainerConnectionProvider = Provider<bool>(
  (ref) => ref.watch(trainerBridgeProvider).isConnected,
);

/// Provider for workflow status message
final workflowStatusMessageProvider = Provider<String?>(
  (ref) => ref.watch(trainerBridgeProvider).statusMessage,
);

/// Provider for workflow error
final workflowErrorProvider = Provider<String?>(
  (ref) => ref.watch(trainerBridgeProvider).error,
);
