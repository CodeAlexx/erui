import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/comfyui_service.dart';
import '../services/comfyui_workflow_builder.dart';
import 'lora_provider.dart';

/// Generation state provider
final generationProvider =
    StateNotifierProvider<GenerationNotifier, GenerationState>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  return GenerationNotifier(comfyService);
});

/// Generation parameters provider
final generationParamsProvider =
    StateNotifierProvider<GenerationParamsNotifier, GenerationParams>((ref) {
  return GenerationParamsNotifier();
});

/// Generation history provider
final generationHistoryProvider =
    StateNotifierProvider<GenerationHistoryNotifier, List<GeneratedImage>>(
        (ref) {
  return GenerationHistoryNotifier();
});

/// Generation state
class GenerationState {
  final bool isGenerating;
  final double progress;
  final int currentStep;
  final int totalSteps;
  final String? currentImage;
  final List<String> generatedImages;
  final String? error;
  final String? generationId;

  const GenerationState({
    this.isGenerating = false,
    this.progress = 0.0,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.currentImage,
    this.generatedImages = const [],
    this.error,
    this.generationId,
  });

  GenerationState copyWith({
    bool? isGenerating,
    double? progress,
    int? currentStep,
    int? totalSteps,
    String? currentImage,
    List<String>? generatedImages,
    String? error,
    String? generationId,
  }) {
    return GenerationState(
      isGenerating: isGenerating ?? this.isGenerating,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      currentImage: currentImage ?? this.currentImage,
      generatedImages: generatedImages ?? this.generatedImages,
      error: error,
      generationId: generationId ?? this.generationId,
    );
  }
}

/// Generation notifier - uses ComfyUI directly for generation
class GenerationNotifier extends StateNotifier<GenerationState> {
  final ComfyUIService _comfyService;
  StreamSubscription<ComfyProgressUpdate>? _progressSubscription;
  StreamSubscription<ComfyExecutionError>? _errorSubscription;
  String? _currentPromptId;

  GenerationNotifier(this._comfyService) : super(const GenerationState()) {
    _setupListeners();
  }

  /// Set up WebSocket listeners for progress and errors
  void _setupListeners() {
    _progressSubscription = _comfyService.progressStream.listen(_handleProgress);
    _errorSubscription = _comfyService.errorStream.listen(_handleError);
  }

  /// Handle progress updates from ComfyUI WebSocket
  void _handleProgress(ComfyProgressUpdate update) {
    // Only handle updates for our current generation
    if (_currentPromptId != null && update.promptId != _currentPromptId) {
      return;
    }

    state = state.copyWith(
      currentStep: update.currentStep,
      totalSteps: update.totalSteps,
      progress: update.totalSteps > 0 ? update.currentStep / update.totalSteps : 0,
      currentImage: update.previewImage ?? state.currentImage,
    );

    if (update.isComplete && update.outputImages != null && update.outputImages!.isNotEmpty) {
      state = state.copyWith(
        isGenerating: false,
        progress: 1.0,
        generatedImages: update.outputImages,
        currentImage: update.outputImages!.first,
      );
      _currentPromptId = null;
    } else if (update.status == 'complete' && update.outputImages == null) {
      // Execution complete but no images from WebSocket, fetch from history
      _fetchOutputsFromHistory(update.promptId);
    }
  }

  /// Handle execution errors from ComfyUI WebSocket
  void _handleError(ComfyExecutionError error) {
    if (_currentPromptId != null && error.promptId != _currentPromptId) {
      return;
    }

    state = state.copyWith(
      isGenerating: false,
      error: 'Generation failed: ${error.message} (node: ${error.nodeType})',
    );
    _currentPromptId = null;
  }

  /// Fetch output images from history when WebSocket didn't provide them
  Future<void> _fetchOutputsFromHistory(String promptId) async {
    try {
      final images = await _comfyService.getOutputImages(promptId);
      if (images.isNotEmpty) {
        state = state.copyWith(
          isGenerating: false,
          progress: 1.0,
          generatedImages: images,
          currentImage: images.first,
        );
      } else {
        // Wait a bit and retry - history might not be ready yet
        await Future.delayed(const Duration(milliseconds: 500));
        final retryImages = await _comfyService.getOutputImages(promptId);
        if (retryImages.isNotEmpty) {
          state = state.copyWith(
            isGenerating: false,
            progress: 1.0,
            generatedImages: retryImages,
            currentImage: retryImages.first,
          );
        } else {
          state = state.copyWith(
            isGenerating: false,
            error: 'Generation completed but no images found',
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: 'Failed to fetch output images: $e',
      );
    }
    _currentPromptId = null;
  }

  /// Start generation
  Future<void> generate(GenerationParams params, {List<SelectedLora>? loras}) async {
    // Check connection
    if (_comfyService.currentConnectionState != ComfyConnectionState.connected) {
      // Try to connect
      final connected = await _comfyService.connect();
      if (!connected) {
        state = state.copyWith(error: 'Not connected to ComfyUI');
        return;
      }
    }

    // Cancel any previous tracking
    _currentPromptId = null;

    state = state.copyWith(
      isGenerating: true,
      progress: 0.0,
      currentStep: 0,
      totalSteps: params.steps,
      currentImage: null,
      generatedImages: [],
      error: null,
    );

    try {
      // Build the appropriate workflow based on parameters
      final workflow = _buildWorkflow(params, loras: loras);

      // Queue the prompt
      final promptId = await _comfyService.queuePrompt(workflow);

      if (promptId == null) {
        state = state.copyWith(
          isGenerating: false,
          error: 'Failed to queue generation - no prompt ID returned',
        );
        return;
      }

      _currentPromptId = promptId;
      state = state.copyWith(generationId: promptId);

      print('ComfyUI generation queued: $promptId');

    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: 'Generation error: $e',
      );
    }
  }

  /// Build ComfyUI workflow from generation parameters
  Map<String, dynamic> _buildWorkflow(GenerationParams params, {List<SelectedLora>? loras}) {
    final builder = ComfyUIWorkflowBuilder();

    // Convert SelectedLora to LoraConfig
    List<LoraConfig>? loraConfigs;
    if (loras != null && loras.isNotEmpty) {
      loraConfigs = loras.map((l) => LoraConfig(
        name: l.lora.name,
        modelStrength: l.strength,
        clipStrength: l.strength,
      )).toList();
    }

    // Build FreeU config from extraParams if present
    FreeUConfig? freeUConfig;
    if (params.extraParams.containsKey('freeu_b1') ||
        params.extraParams.containsKey('freeub1')) {
      freeUConfig = FreeUConfig(
        b1: (params.extraParams['freeu_b1'] ?? params.extraParams['freeub1'] ?? 1.3) as double,
        b2: (params.extraParams['freeu_b2'] ?? params.extraParams['freeub2'] ?? 1.4) as double,
        s1: (params.extraParams['freeu_s1'] ?? params.extraParams['freeus1'] ?? 0.9) as double,
        s2: (params.extraParams['freeu_s2'] ?? params.extraParams['freeus2'] ?? 0.2) as double,
      );
    }

    // Build ControlNet config if present
    ControlNetConfig? controlNetConfig;
    if (params.controlNetImage != null &&
        params.controlNetModel != null &&
        params.controlNetModel != 'None') {
      controlNetConfig = ControlNetConfig(
        model: params.controlNetModel!,
        imageBase64: params.controlNetImage!,
        strength: params.controlNetStrength,
      );
    }

    // Get the model to use
    final modelToUse = params.videoMode
        ? (params.videoModel ?? params.model ?? '')
        : (params.model ?? '');

    if (modelToUse.isEmpty) {
      throw Exception('No model selected');
    }

    // Choose workflow type based on parameters
    if (params.videoMode) {
      // Convert simple format name to VHS format string
      String vhsFormat;
      switch (params.videoFormat) {
        case 'mp4':
          vhsFormat = 'video/h264-mp4';
          break;
        case 'webp':
          vhsFormat = 'image/webp';
          break;
        case 'gif':
          vhsFormat = 'image/gif';
          break;
        case 'webm':
          vhsFormat = 'video/webm';
          break;
        default:
          // If already in VHS format, use as-is
          vhsFormat = params.videoFormat.contains('/')
              ? params.videoFormat
              : 'video/h264-mp4';
      }

      // Video generation workflow - auto-detect model type
      return builder.buildVideoAuto(
        model: modelToUse,
        prompt: params.prompt,
        negativePrompt: params.negativePrompt,
        width: params.width,
        height: params.height,
        frames: params.frames,
        fps: params.fps,
        steps: params.steps,
        cfg: params.cfgScale,
        seed: params.seed,
        initImageBase64: params.initImage,
        highNoiseModel: params.highNoiseModel,
        lowNoiseModel: params.lowNoiseModel,
        videoAugmentationLevel: params.videoAugmentationLevel,
        outputFormat: vhsFormat,
        loras: loraConfigs,
      );
    } else if (params.refinerModel != null &&
               params.refinerModel != 'None' &&
               params.refinerModel!.isNotEmpty) {
      // SDXL with refiner workflow
      return builder.buildSDXLWithRefiner(
        baseModel: modelToUse,
        refinerModel: params.refinerModel!,
        prompt: params.prompt,
        negativePrompt: params.negativePrompt,
        width: params.width,
        height: params.height,
        baseSteps: params.steps,
        refinerSteps: params.refinerSteps,
        baseCfg: params.cfgScale,
        refinerCfg: params.cfgScale,
        seed: params.seed,
        sampler: params.sampler,
        scheduler: params.scheduler,
        vae: params.vae,
        loras: loraConfigs,
        filenamePrefix: 'ERI_refiner',
      );
    } else if (params.upscaleFactor > 1.0 && params.initImage != null) {
      // Hires fix / upscale workflow
      return builder.buildHiresFix(
        model: modelToUse,
        prompt: params.prompt,
        negativePrompt: params.negativePrompt,
        width: params.width,
        height: params.height,
        steps: params.steps,
        cfg: params.cfgScale,
        seed: params.seed,
        sampler: params.sampler,
        scheduler: params.scheduler,
        vae: params.vae,
        loras: loraConfigs,
        upscaleBy: params.upscaleFactor,
        hiresSteps: params.refinerSteps,
        hiresDenoise: params.initImageCreativity,
        freeU: freeUConfig,
        filenamePrefix: 'ERI_hires',
      );
    } else {
      // Detect model type for specialized workflows
      final modelLower = modelToUse.toLowerCase();

      // Flux models - need UNETLoader + DualCLIP + FluxGuidance + ModelSamplingFlux
      if (modelLower.contains('flux')) {
        return builder.buildFlux(
          model: modelToUse,
          prompt: params.prompt,
          negativePrompt: params.negativePrompt,
          width: params.width,
          height: params.height,
          steps: params.steps,
          guidance: 3.5,  // Flux guidance is fixed at 3.5 via FluxGuidance node
          seed: params.seed,
          sampler: params.sampler,
          scheduler: params.scheduler,
          batchSize: params.batchSize,
          vae: params.vae,
          initImageBase64: params.initImage,
          denoise: params.initImage != null ? params.initImageCreativity : 1.0,
          filenamePrefix: 'ERI_flux',
          loras: loraConfigs,
        );
      }

      // Chroma models - Flux-like but with CFG and negative prompts
      if (modelLower.contains('chroma')) {
        return builder.buildChroma(
          model: modelToUse,
          prompt: params.prompt,
          negativePrompt: params.negativePrompt,
          width: params.width,
          height: params.height,
          steps: params.steps,
          cfg: params.cfgScale,
          seed: params.seed,
          sampler: params.sampler,
          scheduler: params.scheduler,
          batchSize: params.batchSize,
          vae: params.vae,
          initImageBase64: params.initImage,
          denoise: params.initImage != null ? params.initImageCreativity : 1.0,
          filenamePrefix: 'ERI_chroma',
          loras: loraConfigs,
        );
      }

      // HiDream models - uses QuadrupleCLIPLoader with llama
      if (modelLower.contains('hidream')) {
        // Auto-detect HiDream variant for optimal settings
        double shift = 3.0;
        int steps = params.steps;
        double cfg = params.cfgScale;
        String sampler = params.sampler;

        if (modelLower.contains('dev')) {
          shift = 6.0;
          if (steps == 20) steps = 28;  // Default for dev
          cfg = 1.0;  // Dev uses CFG=1
          sampler = 'lcm';
        } else if (modelLower.contains('fast')) {
          shift = 3.0;
          if (steps == 20) steps = 16;  // Default for fast
          cfg = 1.0;
          sampler = 'lcm';
        } else {
          // Full variant
          if (steps == 20) steps = 50;  // Default for full
          sampler = 'uni_pc';
        }

        return builder.buildHiDream(
          model: modelToUse,
          prompt: params.prompt,
          negativePrompt: params.negativePrompt,
          width: params.width,
          height: params.height,
          steps: steps,
          cfg: cfg,
          seed: params.seed,
          sampler: sampler,
          scheduler: params.scheduler,
          batchSize: params.batchSize,
          vae: params.vae,
          initImageBase64: params.initImage,
          denoise: params.initImage != null ? params.initImageCreativity : 1.0,
          filenamePrefix: 'ERI_hidream',
          loras: loraConfigs,
          shift: shift,
        );
      }

      // OmniGen2 models - uses Qwen VL encoder
      if (modelLower.contains('omnigen')) {
        return builder.buildOmniGen2(
          model: modelToUse,
          prompt: params.prompt,
          negativePrompt: params.negativePrompt,
          width: params.width,
          height: params.height,
          steps: params.steps,
          cfg: params.cfgScale,
          seed: params.seed,
          sampler: params.sampler,
          scheduler: params.scheduler,
          batchSize: params.batchSize,
          vae: params.vae,
          initImageBase64: params.initImage,
          denoise: params.initImage != null ? params.initImageCreativity : 1.0,
          filenamePrefix: 'ERI_omnigen2',
          loras: loraConfigs,
        );
      }

      // SD3.5 models - need UNETLoader + TripleCLIP + CLIPTextEncodeSD3
      if (modelLower.contains('sd3') || modelLower.contains('sd_3') ||
          modelLower.contains('stable-diffusion-3') || modelLower.contains('stablediffusion3')) {
        return builder.buildSD35(
          model: modelToUse,
          prompt: params.prompt,
          negativePrompt: params.negativePrompt,
          width: params.width,
          height: params.height,
          steps: params.steps,
          cfg: params.cfgScale,
          seed: params.seed,
          sampler: params.sampler,
          scheduler: params.scheduler,
          batchSize: params.batchSize,
          vae: params.vae,
          initImageBase64: params.initImage,
          denoise: params.initImage != null ? params.initImageCreativity : 1.0,
          filenamePrefix: 'ERI_sd35',
          loras: loraConfigs,
        );
      }

      // Standard text2image workflow (also handles img2img)
      // Works for SDXL, SD1.5, and other checkpoint-based models
      return builder.buildText2Image(
        model: modelToUse,
        prompt: params.prompt,
        negativePrompt: params.negativePrompt,
        width: params.width,
        height: params.height,
        steps: params.steps,
        cfg: params.cfgScale,
        seed: params.seed,
        sampler: params.sampler,
        scheduler: params.scheduler,
        batchSize: params.batchSize,
        vae: params.vae,
        loras: loraConfigs,
        initImageBase64: params.initImage,
        denoise: params.initImage != null ? params.initImageCreativity : 1.0,
        controlNet: controlNetConfig,
        freeU: freeUConfig,
        filenamePrefix: 'ERI',
      );
    }
  }

  /// Cancel current generation
  Future<void> cancel() async {
    if (!state.isGenerating) return;

    try {
      await _comfyService.interrupt();
      state = state.copyWith(
        isGenerating: false,
        error: 'Generation cancelled',
      );
      _currentPromptId = null;
    } catch (e) {
      // Ignore cancel errors
      print('Cancel error (ignored): $e');
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _errorSubscription?.cancel();
    super.dispose();
  }
}

/// Generation parameters
class GenerationParams {
  final String prompt;
  final String negativePrompt;
  final String? model;
  final int width;
  final int height;
  final int steps;
  final double cfgScale;
  final int seed;
  final String sampler;
  final String scheduler;
  final int batchSize;
  final Map<String, dynamic> extraParams;

  // Video parameters
  final bool videoMode;
  final String? videoModel;
  final String? highNoiseModel;  // For Wan2.2 dual-model
  final String? lowNoiseModel;   // For Wan2.2 dual-model
  final int frames;
  final int fps;
  final String videoFormat;

  // Image-to-Video (I2V) parameters
  final double videoAugmentationLevel;  // Noise level for I2V (LTX default: 0.15, SVD default: 0)

  // Variation seed parameters
  final int? variationSeed;
  final double variationStrength;

  // Init image (img2img) parameters
  final String? initImage;  // Base64 or URL
  final double initImageCreativity;  // Denoising strength

  // Refine/Upscale parameters
  final String? refinerModel;
  final double upscaleFactor;
  final int refinerSteps;

  // ControlNet parameters
  final String? controlNetImage;  // Base64 or URL
  final String? controlNetModel;
  final double controlNetStrength;

  // Advanced model addons
  final String? vae;
  final String? textEncoder;
  final String? precision;

  const GenerationParams({
    this.prompt = '',
    this.negativePrompt = '',
    this.model,
    this.width = 1024,
    this.height = 1024,
    this.steps = 20,
    this.cfgScale = 7.0,
    this.seed = -1,
    this.sampler = 'euler',
    this.scheduler = 'normal',
    this.batchSize = 1,
    this.extraParams = const {},
    // Video defaults
    this.videoMode = false,
    this.videoModel,
    this.highNoiseModel,
    this.lowNoiseModel,
    this.frames = 81,
    this.fps = 24,
    this.videoFormat = 'webp',
    // I2V defaults
    this.videoAugmentationLevel = 0.15,  // LTX default
    // Variation seed defaults
    this.variationSeed,
    this.variationStrength = 0.0,
    // Init image defaults
    this.initImage,
    this.initImageCreativity = 0.6,
    // Refine/Upscale defaults
    this.refinerModel,
    this.upscaleFactor = 1.0,
    this.refinerSteps = 20,
    // ControlNet defaults
    this.controlNetImage,
    this.controlNetModel,
    this.controlNetStrength = 1.0,
    // Advanced model addons defaults
    this.vae,
    this.textEncoder,
    this.precision,
  });

  GenerationParams copyWith({
    String? prompt,
    String? negativePrompt,
    String? model,
    int? width,
    int? height,
    int? steps,
    double? cfgScale,
    int? seed,
    String? sampler,
    String? scheduler,
    int? batchSize,
    Map<String, dynamic>? extraParams,
    // Video params
    bool? videoMode,
    String? videoModel,
    String? highNoiseModel,
    String? lowNoiseModel,
    int? frames,
    int? fps,
    String? videoFormat,
    // I2V params
    double? videoAugmentationLevel,
    // Variation seed params
    int? variationSeed,
    double? variationStrength,
    // Init image params
    String? initImage,
    double? initImageCreativity,
    // Refine/Upscale params
    String? refinerModel,
    double? upscaleFactor,
    int? refinerSteps,
    // ControlNet params
    String? controlNetImage,
    String? controlNetModel,
    double? controlNetStrength,
    // Advanced model addons
    String? vae,
    String? textEncoder,
    String? precision,
  }) {
    return GenerationParams(
      prompt: prompt ?? this.prompt,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      model: model ?? this.model,
      width: width ?? this.width,
      height: height ?? this.height,
      steps: steps ?? this.steps,
      cfgScale: cfgScale ?? this.cfgScale,
      seed: seed ?? this.seed,
      sampler: sampler ?? this.sampler,
      scheduler: scheduler ?? this.scheduler,
      batchSize: batchSize ?? this.batchSize,
      extraParams: extraParams ?? this.extraParams,
      // Video
      videoMode: videoMode ?? this.videoMode,
      videoModel: videoModel ?? this.videoModel,
      highNoiseModel: highNoiseModel ?? this.highNoiseModel,
      lowNoiseModel: lowNoiseModel ?? this.lowNoiseModel,
      frames: frames ?? this.frames,
      fps: fps ?? this.fps,
      videoFormat: videoFormat ?? this.videoFormat,
      // I2V
      videoAugmentationLevel: videoAugmentationLevel ?? this.videoAugmentationLevel,
      // Variation seed
      variationSeed: variationSeed ?? this.variationSeed,
      variationStrength: variationStrength ?? this.variationStrength,
      // Init image
      initImage: initImage ?? this.initImage,
      initImageCreativity: initImageCreativity ?? this.initImageCreativity,
      // Refine/Upscale
      refinerModel: refinerModel ?? this.refinerModel,
      upscaleFactor: upscaleFactor ?? this.upscaleFactor,
      refinerSteps: refinerSteps ?? this.refinerSteps,
      // ControlNet
      controlNetImage: controlNetImage ?? this.controlNetImage,
      controlNetModel: controlNetModel ?? this.controlNetModel,
      controlNetStrength: controlNetStrength ?? this.controlNetStrength,
      // Advanced model addons
      vae: vae ?? this.vae,
      textEncoder: textEncoder ?? this.textEncoder,
      precision: precision ?? this.precision,
    );
  }
}

/// Generation parameters notifier
class GenerationParamsNotifier extends StateNotifier<GenerationParams> {
  GenerationParamsNotifier() : super(const GenerationParams());

  void setPrompt(String value) {
    state = state.copyWith(prompt: value);
  }

  void setNegativePrompt(String value) {
    state = state.copyWith(negativePrompt: value);
  }

  void setModel(String? value) {
    state = state.copyWith(model: value);
  }

  void setWidth(int value) {
    state = state.copyWith(width: value);
  }

  void setHeight(int value) {
    state = state.copyWith(height: value);
  }

  void setSteps(int value) {
    state = state.copyWith(steps: value);
  }

  void setCfgScale(double value) {
    state = state.copyWith(cfgScale: value);
  }

  void setSeed(int value) {
    state = state.copyWith(seed: value);
  }

  void setSampler(String value) {
    state = state.copyWith(sampler: value);
  }

  void setScheduler(String value) {
    state = state.copyWith(scheduler: value);
  }

  void setBatchSize(int value) {
    state = state.copyWith(batchSize: value);
  }

  void setExtraParam(String key, dynamic value) {
    final newParams = Map<String, dynamic>.from(state.extraParams);
    newParams[key] = value;
    state = state.copyWith(extraParams: newParams);
  }

  // Video parameter setters
  void setVideoMode(bool value) {
    state = state.copyWith(videoMode: value);
  }

  void setVideoModel(String? value) {
    state = state.copyWith(videoModel: value);
  }

  void setHighNoiseModel(String? value) {
    state = state.copyWith(highNoiseModel: value);
  }

  void setLowNoiseModel(String? value) {
    state = state.copyWith(lowNoiseModel: value);
  }

  void setFrames(int value) {
    state = state.copyWith(frames: value);
  }

  void setFps(int value) {
    state = state.copyWith(fps: value);
  }

  void setVideoFormat(String value) {
    state = state.copyWith(videoFormat: value);
  }

  // I2V parameter setters
  void setVideoAugmentationLevel(double value) {
    state = state.copyWith(videoAugmentationLevel: value);
  }

  // Variation seed setters
  void setVariationSeed(int? value) {
    state = state.copyWith(variationSeed: value);
  }

  void setVariationStrength(double value) {
    state = state.copyWith(variationStrength: value);
  }

  // Init image setters
  void setInitImage(String? value) {
    state = state.copyWith(initImage: value);
  }

  void setInitImageCreativity(double value) {
    state = state.copyWith(initImageCreativity: value);
  }

  // Refine/Upscale setters
  void setRefinerModel(String? value) {
    state = state.copyWith(refinerModel: value);
  }

  void setUpscaleFactor(double value) {
    state = state.copyWith(upscaleFactor: value);
  }

  void setRefinerSteps(int value) {
    state = state.copyWith(refinerSteps: value);
  }

  // ControlNet setters
  void setControlNetImage(String? value) {
    state = state.copyWith(controlNetImage: value);
  }

  void setControlNetModel(String? value) {
    state = state.copyWith(controlNetModel: value);
  }

  void setControlNetStrength(double value) {
    state = state.copyWith(controlNetStrength: value);
  }

  // Advanced model addon setters
  void setVae(String? value) {
    state = state.copyWith(vae: value);
  }

  void setTextEncoder(String? value) {
    state = state.copyWith(textEncoder: value);
  }

  void setPrecision(String? value) {
    state = state.copyWith(precision: value);
  }

  /// Apply LTX-2 optimized defaults
  void applyLTX2Defaults() {
    state = state.copyWith(
      width: 768,
      height: 512,
      cfgScale: 3.0,
      steps: 20,
      frames: 121,
      fps: 24,
      videoMode: true,
      videoFormat: 'mp4',
      sampler: 'euler_ancestral',
    );
  }

  /// Apply defaults based on selected model
  void applyModelDefaults(String? modelName) {
    if (modelName == null) return;
    print('DEBUG applyModelDefaults: modelName=$modelName');

    final name = modelName.toLowerCase();
    if (name.contains('ltx2')) {
      // LTX-2: steps=25, cfg=3, frames=121, fps=24
      print('DEBUG: Applying LTX-2 defaults');
      state = state.copyWith(
        width: 768,
        height: 512,
        cfgScale: 3.0,
        steps: 25,
        frames: 121,
        fps: 24,
        videoMode: true,
        videoModel: modelName,
        videoFormat: 'mp4',
        sampler: 'euler_ancestral',
      );
    } else if (name.contains('ltx')) {
      // LTX/LTX2: steps=25, cfg=3, frames=97, fps=24
      print('DEBUG: Applying LTX defaults');
      state = state.copyWith(
        width: 768,
        height: 512,
        cfgScale: 3.0,
        steps: 25,
        frames: 97,
        fps: 24,
        videoMode: true,
        videoModel: modelName,
        videoFormat: 'mp4',
        sampler: 'euler_ancestral',
      );
    } else if (name.contains('fvlv') || name.contains('frameshift')) {
      print('DEBUG: Applying FVLV/Frameshift defaults');
      state = state.copyWith(
        width: 848,
        height: 480,
        cfgScale: 5.0,
        steps: 30,
        frames: 49,
        fps: 24,
        videoMode: true,
        videoModel: modelName,
        videoFormat: 'mp4',
      );
    } else if (name.contains('wan')) {
      // Wan: steps=20, cfg=5, frames=81, fps=16
      print('DEBUG: Applying Wan defaults');
      state = state.copyWith(
        width: 832,
        height: 480,
        cfgScale: 5.0,
        steps: 20,
        frames: 81,
        fps: 16,
        videoMode: true,
        videoModel: modelName,
        videoFormat: 'webp',
      );
    } else if (name.contains('hunyuan') && name.contains('video')) {
      // Hunyuan Video: steps=30, cfg=6, frames=49, fps=24
      print('DEBUG: Applying Hunyuan Video defaults');
      state = state.copyWith(
        width: 848,
        height: 480,
        cfgScale: 6.0,
        steps: 30,
        frames: 49,
        fps: 24,
        videoMode: true,
        videoModel: modelName,
        videoFormat: 'mp4',
      );
    } else if (name.contains('mochi')) {
      // Mochi: steps=30, cfg=4.5, frames=84, fps=24
      print('DEBUG: Applying Mochi defaults');
      state = state.copyWith(
        width: 848,
        height: 480,
        cfgScale: 4.5,
        steps: 30,
        frames: 84,
        fps: 24,
        videoMode: true,
        videoModel: modelName,
        videoFormat: 'mp4',
        sampler: 'euler',
      );
    } else if (name.contains('cogvideo')) {
      print('DEBUG: Applying CogVideoX defaults');
      state = state.copyWith(
        width: 720,
        height: 480,
        cfgScale: 6.0,
        steps: 50,
        frames: 49,
        fps: 8,
        videoMode: true,
        videoModel: modelName,
        videoFormat: 'mp4',
      );
    } else if (name.contains('svd') || name.contains('stable-video')) {
      print('DEBUG: Applying SVD defaults');
      state = state.copyWith(
        width: 1024,
        height: 576,
        cfgScale: 2.5,
        steps: 25,
        frames: 25,
        fps: 6,
        videoMode: true,
        videoModel: modelName,
        videoFormat: 'webp',
      );
    } else if (name.contains('hidream')) {
      // HiDream: steps=28, cfg=5, resolution=1024x1024
      print('DEBUG: Applying HiDream defaults');
      state = state.copyWith(
        videoMode: false,
        videoModel: null,
        width: 1024,
        height: 1024,
        cfgScale: 5.0,
        steps: 28,
      );
    } else if (name.contains('chroma')) {
      // Chroma: steps=25, cfg=4, resolution=1024x1024
      print('DEBUG: Applying Chroma defaults');
      state = state.copyWith(
        videoMode: false,
        videoModel: null,
        width: 1024,
        height: 1024,
        cfgScale: 4.0,
        steps: 25,
      );
    } else if (name.contains('flux')) {
      // Flux: steps=20, cfg=1.0, resolution=1024x1024
      print('DEBUG: Applying Flux defaults');
      state = state.copyWith(
        videoMode: false,
        videoModel: null,
        width: 1024,
        height: 1024,
        cfgScale: 1.0,
        steps: 20,
      );
    } else if (name.contains('sdxl') || name.contains('sd_xl') || name.contains('stable-diffusion-xl')) {
      // SDXL: steps=25, cfg=7, resolution=1024x1024
      print('DEBUG: Applying SDXL defaults');
      state = state.copyWith(
        videoMode: false,
        videoModel: null,
        width: 1024,
        height: 1024,
        cfgScale: 7.0,
        steps: 25,
      );
    } else if (name.contains('sd15') || name.contains('sd_15') || name.contains('sd1.5') || name.contains('v1-5') || name.contains('1.5')) {
      // SD 1.5: steps=20, cfg=7, resolution=512x512
      print('DEBUG: Applying SD 1.5 defaults');
      state = state.copyWith(
        videoMode: false,
        videoModel: null,
        width: 512,
        height: 512,
        cfgScale: 7.0,
        steps: 20,
      );
    } else {
      // Default fallback for unknown image models (SDXL-like defaults)
      print('DEBUG: Applying default image model settings');
      state = state.copyWith(
        videoMode: false,
        videoModel: null,
        width: 1024,
        height: 1024,
        cfgScale: 7.0,
        steps: 25,
      );
    }
    print('DEBUG: New state - videoMode=${state.videoMode}, videoModel=${state.videoModel}, cfgScale=${state.cfgScale}, width=${state.width}, steps=${state.steps}');
  }

  /// Apply parameters from image metadata (for reuse functionality)
  void applyFromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return;

    // Try SwarmUI format first
    final suiParams = metadata['sui_image_params'] as Map<String, dynamic>?;
    final params = suiParams ?? metadata;

    state = state.copyWith(
      prompt: params['prompt'] as String? ?? state.prompt,
      negativePrompt: params['negativeprompt'] as String? ?? params['negative_prompt'] as String? ?? state.negativePrompt,
      model: params['model'] as String? ?? state.model,
      width: (params['width'] as num?)?.toInt() ?? state.width,
      height: (params['height'] as num?)?.toInt() ?? state.height,
      steps: (params['steps'] as num?)?.toInt() ?? state.steps,
      cfgScale: (params['cfgscale'] as num?)?.toDouble() ?? (params['cfg_scale'] as num?)?.toDouble() ?? state.cfgScale,
      seed: (params['seed'] as num?)?.toInt() ?? state.seed,
      sampler: params['sampler'] as String? ?? state.sampler,
      scheduler: params['scheduler'] as String? ?? state.scheduler,
      batchSize: (params['images'] as num?)?.toInt() ?? (params['batch_size'] as num?)?.toInt() ?? state.batchSize,
      // Video params
      videoMode: params['video_mode'] as bool? ?? state.videoMode,
      frames: (params['frames'] as num?)?.toInt() ?? state.frames,
      fps: (params['fps'] as num?)?.toInt() ?? state.fps,
    );
  }

  void reset() {
    state = const GenerationParams();
  }
}

/// Generated image
class GeneratedImage {
  final String url;
  final String? localPath;
  final String prompt;
  final String? negativePrompt;
  final GenerationParams params;
  final DateTime createdAt;
  final String? id;

  const GeneratedImage({
    required this.url,
    this.localPath,
    required this.prompt,
    this.negativePrompt,
    required this.params,
    required this.createdAt,
    this.id,
  });

  factory GeneratedImage.fromJson(Map<String, dynamic> json) {
    return GeneratedImage(
      url: json['url'] as String,
      localPath: json['local_path'] as String?,
      prompt: json['prompt'] as String? ?? '',
      negativePrompt: json['negative_prompt'] as String?,
      params: GenerationParams(
        prompt: json['prompt'] as String? ?? '',
        negativePrompt: json['negative_prompt'] as String? ?? '',
        model: json['model'] as String?,
        width: json['width'] as int? ?? 1024,
        height: json['height'] as int? ?? 1024,
        steps: json['steps'] as int? ?? 20,
        cfgScale: (json['cfg_scale'] as num?)?.toDouble() ?? 7.0,
        seed: json['seed'] as int? ?? -1,
        sampler: json['sampler'] as String? ?? 'euler',
        scheduler: json['scheduler'] as String? ?? 'normal',
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      id: json['id'] as String?,
    );
  }
}

/// Generation history notifier
class GenerationHistoryNotifier extends StateNotifier<List<GeneratedImage>> {
  GenerationHistoryNotifier() : super([]);

  void addImage(GeneratedImage image) {
    state = [image, ...state];
  }

  void addImages(List<GeneratedImage> images) {
    state = [...images, ...state];
  }

  void removeImage(String id) {
    state = state.where((img) => img.id != id).toList();
  }

  void clear() {
    state = [];
  }
}
