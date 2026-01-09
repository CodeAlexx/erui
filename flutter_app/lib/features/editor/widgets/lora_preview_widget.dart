import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/lora_provider.dart';
import '../../../providers/session_provider.dart';
import '../../../services/comfyui_service.dart';
import '../models/editor_models.dart';

// ============================================================
// Data Models
// ============================================================

/// Compare modes for LoRA preview
enum LoraCompareMode {
  /// Side-by-side comparison of original and LoRA-enhanced images
  sideBySide,

  /// Toggle between original and LoRA-enhanced images
  toggle,

  /// Slider to reveal LoRA-enhanced image over original
  slider,
}

/// Preview modes for LoRA preview generation
enum LoraPreviewMode {
  /// Quick single frame preview
  quick,

  /// Before/after comparison
  compare,

  /// Preview on multiple frames across the clip
  sequence,
}

/// Settings for LoRA preview
class LoraPreviewSettings {
  /// Path to the LoRA file
  final String loraPath;

  /// LoRA strength (0.0-2.0)
  final double strength;

  /// Which frame index to preview (relative to clip start)
  final int previewFrame;

  /// Optional prompt for generation
  final String? prompt;

  /// Comparison mode
  final LoraCompareMode compareMode;

  /// Preview mode
  final LoraPreviewMode previewMode;

  /// Number of frames to preview in sequence mode
  final int sequenceFrameCount;

  /// Clip strength for split weights mode
  final double clipStrength;

  /// Model strength for split weights mode
  final double modelStrength;

  /// Whether to use split weights (clip/model)
  final bool useSplitWeights;

  const LoraPreviewSettings({
    required this.loraPath,
    this.strength = 1.0,
    this.previewFrame = 0,
    this.prompt,
    this.compareMode = LoraCompareMode.sideBySide,
    this.previewMode = LoraPreviewMode.quick,
    this.sequenceFrameCount = 5,
    this.clipStrength = 1.0,
    this.modelStrength = 1.0,
    this.useSplitWeights = false,
  });

  LoraPreviewSettings copyWith({
    String? loraPath,
    double? strength,
    int? previewFrame,
    String? prompt,
    LoraCompareMode? compareMode,
    LoraPreviewMode? previewMode,
    int? sequenceFrameCount,
    double? clipStrength,
    double? modelStrength,
    bool? useSplitWeights,
  }) {
    return LoraPreviewSettings(
      loraPath: loraPath ?? this.loraPath,
      strength: strength ?? this.strength,
      previewFrame: previewFrame ?? this.previewFrame,
      prompt: prompt ?? this.prompt,
      compareMode: compareMode ?? this.compareMode,
      previewMode: previewMode ?? this.previewMode,
      sequenceFrameCount: sequenceFrameCount ?? this.sequenceFrameCount,
      clipStrength: clipStrength ?? this.clipStrength,
      modelStrength: modelStrength ?? this.modelStrength,
      useSplitWeights: useSplitWeights ?? this.useSplitWeights,
    );
  }

  /// Get effective clip strength (uses strength if not split)
  double get effectiveClipStrength => useSplitWeights ? clipStrength : strength;

  /// Get effective model strength (uses strength if not split)
  double get effectiveModelStrength =>
      useSplitWeights ? modelStrength : strength;
}

/// LoRA effect applied to a timeline clip
class LoraClipEffect {
  /// Path to the LoRA file
  final String loraPath;

  /// LoRA strength (0.0-2.0)
  final double strength;

  /// Optional trigger word for the LoRA
  final String? triggerWord;

  /// Clip strength for split weights mode
  final double clipStrength;

  /// Model strength for split weights mode
  final double modelStrength;

  /// Whether to use split weights
  final bool useSplitWeights;

  /// Display name for UI
  final String? displayName;

  const LoraClipEffect({
    required this.loraPath,
    this.strength = 1.0,
    this.triggerWord,
    this.clipStrength = 1.0,
    this.modelStrength = 1.0,
    this.useSplitWeights = false,
    this.displayName,
  });

  LoraClipEffect copyWith({
    String? loraPath,
    double? strength,
    String? triggerWord,
    double? clipStrength,
    double? modelStrength,
    bool? useSplitWeights,
    String? displayName,
  }) {
    return LoraClipEffect(
      loraPath: loraPath ?? this.loraPath,
      strength: strength ?? this.strength,
      triggerWord: triggerWord ?? this.triggerWord,
      clipStrength: clipStrength ?? this.clipStrength,
      modelStrength: modelStrength ?? this.modelStrength,
      useSplitWeights: useSplitWeights ?? this.useSplitWeights,
      displayName: displayName ?? this.displayName,
    );
  }

  Map<String, dynamic> toJson() => {
        'loraPath': loraPath,
        'strength': strength,
        if (triggerWord != null) 'triggerWord': triggerWord,
        if (useSplitWeights) ...{
          'clipStrength': clipStrength,
          'modelStrength': modelStrength,
        },
        if (displayName != null) 'displayName': displayName,
      };

  factory LoraClipEffect.fromJson(Map<String, dynamic> json) {
    return LoraClipEffect(
      loraPath: json['loraPath'] as String,
      strength: (json['strength'] as num?)?.toDouble() ?? 1.0,
      triggerWord: json['triggerWord'] as String?,
      clipStrength: (json['clipStrength'] as num?)?.toDouble() ?? 1.0,
      modelStrength: (json['modelStrength'] as num?)?.toDouble() ?? 1.0,
      useSplitWeights: json['clipStrength'] != null,
      displayName: json['displayName'] as String?,
    );
  }

  /// Get effective clip strength
  double get effectiveClipStrength => useSplitWeights ? clipStrength : strength;

  /// Get effective model strength
  double get effectiveModelStrength =>
      useSplitWeights ? modelStrength : strength;
}

// ============================================================
// LoRA Preview State
// ============================================================

/// State for the LoRA preview system
class LoraPreviewState {
  /// Currently selected LoRA for preview
  final LoraModel? selectedLora;

  /// Current preview settings
  final LoraPreviewSettings? settings;

  /// Original frame image data (before LoRA)
  final Uint8List? originalFrame;

  /// Generated preview image data (with LoRA)
  final Uint8List? previewImage;

  /// Sequence of preview images for sequence mode
  final List<Uint8List> sequenceImages;

  /// Whether preview is currently generating
  final bool isGenerating;

  /// Generation progress (0.0-1.0)
  final double progress;

  /// Error message if any
  final String? error;

  /// Current slider position for slider compare mode (0.0-1.0)
  final double sliderPosition;

  /// Whether showing original (true) or preview (false) in toggle mode
  final bool showingOriginal;

  const LoraPreviewState({
    this.selectedLora,
    this.settings,
    this.originalFrame,
    this.previewImage,
    this.sequenceImages = const [],
    this.isGenerating = false,
    this.progress = 0.0,
    this.error,
    this.sliderPosition = 0.5,
    this.showingOriginal = false,
  });

  LoraPreviewState copyWith({
    LoraModel? selectedLora,
    LoraPreviewSettings? settings,
    Uint8List? originalFrame,
    Uint8List? previewImage,
    List<Uint8List>? sequenceImages,
    bool? isGenerating,
    double? progress,
    String? error,
    double? sliderPosition,
    bool? showingOriginal,
  }) {
    return LoraPreviewState(
      selectedLora: selectedLora ?? this.selectedLora,
      settings: settings ?? this.settings,
      originalFrame: originalFrame ?? this.originalFrame,
      previewImage: previewImage ?? this.previewImage,
      sequenceImages: sequenceImages ?? this.sequenceImages,
      isGenerating: isGenerating ?? this.isGenerating,
      progress: progress ?? this.progress,
      error: error,
      sliderPosition: sliderPosition ?? this.sliderPosition,
      showingOriginal: showingOriginal ?? this.showingOriginal,
    );
  }
}

// ============================================================
// Providers
// ============================================================

/// Provider for available LoRAs from ComfyUI
final availableLorasProvider = FutureProvider<List<LoraModel>>((ref) async {
  final comfyService = ref.watch(comfyUIServiceProvider);
  final allModels = <LoraModel>[];

  // Fetch LoRAs from ComfyUI backend
  final loraNames = await comfyService.getLoras();
  for (final name in loraNames) {
    allModels.add(LoraModel(
      name: name,
      path: name,
      title: name.replaceAll('.safetensors', '').replaceAll('_', ' '),
      type: name.toLowerCase().contains('lycoris') ||
             name.toLowerCase().contains('locon') ||
             name.toLowerCase().contains('loha')
          ? 'LyCORIS'
          : 'LoRA',
    ));
  }

  return allModels;
});

/// State notifier for LoRA preview
class LoraPreviewNotifier extends StateNotifier<LoraPreviewState> {
  final ComfyUIService _comfyService;
  final SessionState _session;
  Timer? _pollTimer;
  StreamSubscription? _progressSubscription;

  LoraPreviewNotifier(this._comfyService, this._session)
      : super(const LoraPreviewState()) {
    // Listen to ComfyUI progress updates
    _progressSubscription = _comfyService.progressStream.listen(_handleProgress);
  }

  void _handleProgress(ComfyProgressUpdate update) {
    if (state.isGenerating) {
      state = state.copyWith(
        progress: update.progress,
      );

      if (update.isComplete && update.outputImages != null && update.outputImages!.isNotEmpty) {
        _loadPreviewImage(update.outputImages!.first);
      }
    }
  }

  /// Select a LoRA for preview
  void selectLora(LoraModel? lora) {
    if (lora == null) {
      state = const LoraPreviewState();
      return;
    }

    state = state.copyWith(
      selectedLora: lora,
      settings: LoraPreviewSettings(
        loraPath: lora.path,
        prompt: lora.triggerPhrase,
      ),
      previewImage: null,
      error: null,
    );
  }

  /// Update preview settings
  void updateSettings(LoraPreviewSettings settings) {
    state = state.copyWith(settings: settings);
  }

  /// Update strength with live preview
  void updateStrength(double strength) {
    if (state.settings == null) return;
    state = state.copyWith(
      settings: state.settings!.copyWith(strength: strength),
    );
  }

  /// Update compare mode
  void setCompareMode(LoraCompareMode mode) {
    if (state.settings == null) return;
    state = state.copyWith(
      settings: state.settings!.copyWith(compareMode: mode),
    );
  }

  /// Update preview mode
  void setPreviewMode(LoraPreviewMode mode) {
    if (state.settings == null) return;
    state = state.copyWith(
      settings: state.settings!.copyWith(previewMode: mode),
    );
  }

  /// Set slider position for slider compare mode
  void setSliderPosition(double position) {
    state = state.copyWith(sliderPosition: position.clamp(0.0, 1.0));
  }

  /// Toggle between original and preview in toggle mode
  void toggleOriginal() {
    state = state.copyWith(showingOriginal: !state.showingOriginal);
  }

  /// Set the original frame image data
  void setOriginalFrame(Uint8List? frameData) {
    state = state.copyWith(originalFrame: frameData);
  }

  /// Generate preview image using ComfyUI API
  Future<void> generatePreview({
    required String model,
    required int width,
    required int height,
    String? initImage,
  }) async {
    if (state.settings == null) {
      state = state.copyWith(error: 'No settings');
      return;
    }

    state = state.copyWith(
      isGenerating: true,
      progress: 0.0,
      error: null,
    );

    try {
      final settings = state.settings!;

      // Build a simple ComfyUI workflow with LoRA for preview
      final workflow = _buildLoraPreviewWorkflow(
        model: model,
        loraName: settings.loraPath,
        loraStrength: settings.useSplitWeights ? settings.modelStrength : settings.strength,
        clipStrength: settings.useSplitWeights ? settings.clipStrength : settings.strength,
        prompt: settings.prompt ?? '',
        width: width,
        height: height,
      );

      final promptId = await _comfyService.queuePrompt(workflow);
      if (promptId == null) {
        state = state.copyWith(
          isGenerating: false,
          error: 'Failed to queue preview generation',
        );
        return;
      }

      // Progress updates are handled via WebSocket stream
      // Wait for completion using the stream or polling
      _startPolling(promptId);
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: e.toString(),
      );
    }
  }

  /// Build a ComfyUI workflow for LoRA preview
  Map<String, dynamic> _buildLoraPreviewWorkflow({
    required String model,
    required String loraName,
    required double loraStrength,
    required double clipStrength,
    required String prompt,
    required int width,
    required int height,
  }) {
    return {
      '1': {
        'class_type': 'CheckpointLoaderSimple',
        'inputs': {'ckpt_name': model},
      },
      '2': {
        'class_type': 'LoraLoader',
        'inputs': {
          'model': ['1', 0],
          'clip': ['1', 1],
          'lora_name': loraName,
          'strength_model': loraStrength,
          'strength_clip': clipStrength,
        },
      },
      '3': {
        'class_type': 'CLIPTextEncode',
        'inputs': {
          'clip': ['2', 1],
          'text': prompt,
        },
      },
      '4': {
        'class_type': 'CLIPTextEncode',
        'inputs': {
          'clip': ['2', 1],
          'text': '',
        },
      },
      '5': {
        'class_type': 'EmptyLatentImage',
        'inputs': {
          'width': width,
          'height': height,
          'batch_size': 1,
        },
      },
      '6': {
        'class_type': 'KSampler',
        'inputs': {
          'model': ['2', 0],
          'positive': ['3', 0],
          'negative': ['4', 0],
          'latent_image': ['5', 0],
          'seed': DateTime.now().millisecondsSinceEpoch % 1000000000,
          'steps': 20,
          'cfg': 7.0,
          'sampler_name': 'euler',
          'scheduler': 'normal',
          'denoise': 1.0,
        },
      },
      '7': {
        'class_type': 'VAEDecode',
        'inputs': {
          'samples': ['6', 0],
          'vae': ['1', 2],
        },
      },
      '8': {
        'class_type': 'SaveImage',
        'inputs': {
          'images': ['7', 0],
          'filename_prefix': 'lora_preview',
        },
      },
    };
  }

  /// Start polling for generation progress
  void _startPolling(String promptId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (timer) async {
        if (!state.isGenerating) {
          timer.cancel();
          return;
        }

        try {
          final history = await _comfyService.getHistory(promptId);
          if (history != null) {
            // Check for outputs
            final outputs = history['outputs'] as Map<String, dynamic>?;
            if (outputs != null && outputs.isNotEmpty) {
              timer.cancel();
              // Find image outputs
              for (final nodeOutput in outputs.values) {
                if (nodeOutput is Map<String, dynamic>) {
                  final images = nodeOutput['images'] as List?;
                  if (images != null && images.isNotEmpty) {
                    final img = images.first as Map<String, dynamic>;
                    final filename = img['filename'] as String?;
                    final subfolder = img['subfolder'] as String? ?? '';
                    final type = img['type'] as String? ?? 'output';
                    if (filename != null) {
                      final imageUrl = _comfyService.getImageUrl(
                        filename,
                        subfolder: subfolder,
                        type: type,
                      );
                      await _loadPreviewImage(imageUrl);
                      return;
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          // Ignore poll errors, will retry
        }
      },
    );
  }

  /// Load preview image from URL
  Future<void> _loadPreviewImage(String imageUrl) async {
    try {
      // The image URL is already complete from ComfyUI
      // For now, just mark as complete - the UI can display the URL directly
      state = state.copyWith(
        isGenerating: false,
        progress: 1.0,
        // Note: For proper implementation, we'd fetch the image bytes here
        // For now we store the URL as a string in error field (hack)
        // A better approach would be to add an imageUrl field to the state
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: 'Failed to load preview: $e',
      );
    }
  }

  /// Generate sequence preview on multiple frames
  Future<void> generateSequencePreview({
    required String model,
    required int width,
    required int height,
    required List<String> frameImages,
  }) async {
    if (state.settings == null) {
      state = state.copyWith(error: 'No settings');
      return;
    }

    state = state.copyWith(
      isGenerating: true,
      progress: 0.0,
      error: null,
      sequenceImages: [],
    );

    final settings = state.settings!;

    try {
      // For sequence preview, we just generate the first frame for now
      // Full sequence generation would require more complex workflow handling
      await generatePreview(
        model: model,
        width: width,
        height: height,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: e.toString(),
      );
    }
  }

  /// Cancel current generation
  void cancelGeneration() {
    _pollTimer?.cancel();
    _comfyService.interrupt();
    state = state.copyWith(
      isGenerating: false,
      progress: 0.0,
    );
  }

  /// Clear preview state
  void clear() {
    _pollTimer?.cancel();
    state = const LoraPreviewState();
  }

  /// Create LoraClipEffect from current settings
  LoraClipEffect? createClipEffect() {
    if (state.selectedLora == null || state.settings == null) return null;

    return LoraClipEffect(
      loraPath: state.settings!.loraPath,
      strength: state.settings!.strength,
      triggerWord: state.selectedLora!.triggerPhrase,
      clipStrength: state.settings!.clipStrength,
      modelStrength: state.settings!.modelStrength,
      useSplitWeights: state.settings!.useSplitWeights,
      displayName: state.selectedLora!.title,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for LoRA preview state
final loraPreviewStateProvider =
    StateNotifierProvider<LoraPreviewNotifier, LoraPreviewState>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  final session = ref.watch(sessionProvider);
  return LoraPreviewNotifier(comfyService, session);
});

// ============================================================
// Main Widget
// ============================================================

/// Widget for previewing trained LoRA effects on timeline clips
class LoraPreviewWidget extends ConsumerStatefulWidget {
  /// The clip to preview LoRA on
  final EditorClip? clip;

  /// Callback when LoRA is applied to clip
  final Function(LoraClipEffect)? onApplyToClip;

  /// Current frame image data for preview
  final Uint8List? currentFrame;

  /// Project settings for generation parameters
  final ProjectSettings? projectSettings;

  /// Callback to close the preview overlay
  final VoidCallback? onClose;

  const LoraPreviewWidget({
    super.key,
    this.clip,
    this.onApplyToClip,
    this.currentFrame,
    this.projectSettings,
    this.onClose,
  });

  @override
  ConsumerState<LoraPreviewWidget> createState() => _LoraPreviewWidgetState();
}

class _LoraPreviewWidgetState extends ConsumerState<LoraPreviewWidget> {
  @override
  void didUpdateWidget(LoraPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentFrame != oldWidget.currentFrame) {
      ref.read(loraPreviewStateProvider.notifier).setOriginalFrame(
            widget.currentFrame,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewState = ref.watch(loraPreviewStateProvider);
    final lorasAsync = ref.watch(availableLorasProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(context, previewState),

          // LoRA Selector
          _buildLoraSelector(context, lorasAsync),

          // Strength Controls
          if (previewState.selectedLora != null)
            _buildStrengthControls(context, previewState),

          // Compare Mode Selector
          if (previewState.selectedLora != null)
            _buildCompareModeSelector(context, previewState),

          // Preview Area
          Expanded(
            child: _buildPreviewArea(context, previewState),
          ),

          // Action Buttons
          if (previewState.selectedLora != null)
            _buildActionButtons(context, previewState),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, LoraPreviewState previewState) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_fix_high, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          const Text(
            'LoRA Preview',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (previewState.isGenerating)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: previewState.progress > 0 ? previewState.progress : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoraSelector(
    BuildContext context,
    AsyncValue<List<LoraModel>> lorasAsync,
  ) {
    final previewState = ref.watch(loraPreviewStateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: lorasAsync.when(
        data: (loras) {
          return DropdownButtonFormField<LoraModel>(
            value: previewState.selectedLora,
            decoration: InputDecoration(
              labelText: 'Select LoRA',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: [
              const DropdownMenuItem<LoraModel>(
                value: null,
                child: Text('None'),
              ),
              ...loras.map((lora) {
                return DropdownMenuItem<LoraModel>(
                  value: lora,
                  child: Row(
                    children: [
                      if (lora.previewImage != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            lora.previewImage!,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 32,
                              height: 32,
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image,
                                size: 16,
                                color: colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              lora.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (lora.baseModel != null)
                              Text(
                                lora.baseModel!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colorScheme.outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (lora.isLycoris)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'LyCORIS',
                            style: TextStyle(
                              fontSize: 9,
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (lora) {
              ref.read(loraPreviewStateProvider.notifier).selectLora(lora);
            },
          );
        },
        loading: () => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, _) => Text(
          'Failed to load LoRAs: $error',
          style: TextStyle(color: colorScheme.error),
        ),
      ),
    );
  }

  Widget _buildStrengthControls(
    BuildContext context,
    LoraPreviewState previewState,
  ) {
    final settings = previewState.settings;
    if (settings == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Strength'),
              const Spacer(),
              Text(
                settings.strength.toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: settings.strength,
            min: 0.0,
            max: 2.0,
            divisions: 40,
            onChanged: (value) {
              ref.read(loraPreviewStateProvider.notifier).updateStrength(value);
            },
          ),
          // Toggle for split weights
          CheckboxListTile(
            title: const Text('Split Weights'),
            subtitle: const Text('Separate clip/model strength'),
            value: settings.useSplitWeights,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              ref.read(loraPreviewStateProvider.notifier).updateSettings(
                    settings.copyWith(useSplitWeights: value ?? false),
                  );
            },
          ),
          if (settings.useSplitWeights) ...[
            Row(
              children: [
                const Text('Clip'),
                const Spacer(),
                Text(settings.clipStrength.toStringAsFixed(2)),
              ],
            ),
            Slider(
              value: settings.clipStrength,
              min: 0.0,
              max: 2.0,
              divisions: 40,
              onChanged: (value) {
                ref.read(loraPreviewStateProvider.notifier).updateSettings(
                      settings.copyWith(clipStrength: value),
                    );
              },
            ),
            Row(
              children: [
                const Text('Model'),
                const Spacer(),
                Text(settings.modelStrength.toStringAsFixed(2)),
              ],
            ),
            Slider(
              value: settings.modelStrength,
              min: 0.0,
              max: 2.0,
              divisions: 40,
              onChanged: (value) {
                ref.read(loraPreviewStateProvider.notifier).updateSettings(
                      settings.copyWith(modelStrength: value),
                    );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompareModeSelector(
    BuildContext context,
    LoraPreviewState previewState,
  ) {
    final settings = previewState.settings;
    if (settings == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Text('Compare: '),
          const SizedBox(width: 8),
          Expanded(
            child: SegmentedButton<LoraCompareMode>(
              segments: const [
                ButtonSegment(
                  value: LoraCompareMode.sideBySide,
                  label: Text('Side by Side'),
                  icon: Icon(Icons.view_column),
                ),
                ButtonSegment(
                  value: LoraCompareMode.toggle,
                  label: Text('Toggle'),
                  icon: Icon(Icons.compare),
                ),
                ButtonSegment(
                  value: LoraCompareMode.slider,
                  label: Text('Slider'),
                  icon: Icon(Icons.swipe),
                ),
              ],
              selected: {settings.compareMode},
              onSelectionChanged: (modes) {
                if (modes.isNotEmpty) {
                  ref
                      .read(loraPreviewStateProvider.notifier)
                      .setCompareMode(modes.first);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea(
    BuildContext context,
    LoraPreviewState previewState,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = previewState.settings;

    if (previewState.selectedLora == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_fix_high,
              size: 64,
              color: colorScheme.outline.withOpacity( 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a LoRA to preview',
              style: TextStyle(color: colorScheme.outline),
            ),
          ],
        ),
      );
    }

    if (previewState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 8),
            Text(
              previewState.error!,
              style: TextStyle(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final originalImage = previewState.originalFrame;
    final previewImage = previewState.previewImage;

    // Show loading state
    if (previewState.isGenerating) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value:
                  previewState.progress > 0 ? previewState.progress : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Generating preview... ${(previewState.progress * 100).toInt()}%',
            ),
          ],
        ),
      );
    }

    // Show placeholder if no images
    if (originalImage == null && previewImage == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image,
              size: 64,
              color: colorScheme.outline.withOpacity( 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Generate a preview to see LoRA effect',
              style: TextStyle(color: colorScheme.outline),
            ),
          ],
        ),
      );
    }

    // Show comparison based on mode
    switch (settings?.compareMode ?? LoraCompareMode.sideBySide) {
      case LoraCompareMode.sideBySide:
        return _buildSideBySideComparison(
          context,
          originalImage,
          previewImage,
        );
      case LoraCompareMode.toggle:
        return _buildToggleComparison(
          context,
          originalImage,
          previewImage,
          previewState,
        );
      case LoraCompareMode.slider:
        return _buildSliderComparison(
          context,
          originalImage,
          previewImage,
          previewState,
        );
    }
  }

  Widget _buildSideBySideComparison(
    BuildContext context,
    Uint8List? original,
    Uint8List? preview,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text('Original', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: original != null
                        ? Image.memory(original, fit: BoxFit.contain)
                        : const Center(child: Text('No frame')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                const Text('With LoRA', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: preview != null
                        ? Image.memory(preview, fit: BoxFit.contain)
                        : const Center(child: Text('Generate preview')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleComparison(
    BuildContext context,
    Uint8List? original,
    Uint8List? preview,
    LoraPreviewState previewState,
  ) {
    final imageToShow = previewState.showingOriginal ? original : preview;
    final label = previewState.showingOriginal ? 'Original' : 'With LoRA';

    return GestureDetector(
      onTap: () {
        ref.read(loraPreviewStateProvider.notifier).toggleOriginal();
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                const Text(
                  '(tap to toggle)',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: previewState.showingOriginal
                        ? Theme.of(context).colorScheme.outline
                        : Theme.of(context).colorScheme.primary,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: imageToShow != null
                    ? Image.memory(imageToShow, fit: BoxFit.contain)
                    : const Center(child: Text('No image')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderComparison(
    BuildContext context,
    Uint8List? original,
    Uint8List? preview,
    LoraPreviewState previewState,
  ) {
    if (original == null || preview == null) {
      return Center(
        child: Text(
          'Both original and preview needed for slider mode',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Text('Drag slider to compare', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final newPosition =
                        details.localPosition.dx / constraints.maxWidth;
                    ref
                        .read(loraPreviewStateProvider.notifier)
                        .setSliderPosition(newPosition);
                  },
                  child: Stack(
                    children: [
                      // Full preview image
                      Positioned.fill(
                        child: Image.memory(preview, fit: BoxFit.contain),
                      ),
                      // Clipped original image
                      Positioned.fill(
                        child: ClipRect(
                          clipper: _SliderClipper(
                            previewState.sliderPosition,
                          ),
                          child: Image.memory(original, fit: BoxFit.contain),
                        ),
                      ),
                      // Slider line
                      Positioned(
                        left: constraints.maxWidth *
                                previewState.sliderPosition -
                            2,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 4,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      // Labels
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          color: Colors.black54,
                          child: const Text(
                            'Original',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          color: Colors.black54,
                          child: const Text(
                            'LoRA',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    LoraPreviewState previewState,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Row(
        children: [
          // Generate Preview Button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: previewState.isGenerating
                  ? null
                  : () => _generatePreview(context),
              icon: const Icon(Icons.refresh),
              label: const Text('Generate Preview'),
            ),
          ),
          const SizedBox(width: 8),
          // Apply to Clip Button
          Expanded(
            child: FilledButton.icon(
              onPressed: previewState.isGenerating
                  ? null
                  : () => _applyToClip(context, previewState),
              icon: const Icon(Icons.check),
              label: const Text('Apply to Clip'),
            ),
          ),
        ],
      ),
    );
  }

  void _generatePreview(BuildContext context) {
    final settings = widget.projectSettings;
    final width = settings?.width ?? 512;
    final height = settings?.height ?? 512;

    // Convert current frame to base64 if available
    String? initImage;
    if (widget.currentFrame != null) {
      // In a real implementation, you'd convert the frame data to base64
      // For now, we'll generate without init image
    }

    ref.read(loraPreviewStateProvider.notifier).generatePreview(
          model: 'auto', // Use auto-detected model
          width: width,
          height: height,
          initImage: initImage,
        );
  }

  void _applyToClip(BuildContext context, LoraPreviewState previewState) {
    final effect = ref.read(loraPreviewStateProvider.notifier).createClipEffect();
    if (effect != null && widget.onApplyToClip != null) {
      widget.onApplyToClip!(effect);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applied ${effect.displayName ?? effect.loraPath} to clip',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Custom clipper for slider comparison mode
class _SliderClipper extends CustomClipper<Rect> {
  final double position;

  _SliderClipper(this.position);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * position, size.height);
  }

  @override
  bool shouldReclip(_SliderClipper oldClipper) {
    return oldClipper.position != position;
  }
}
