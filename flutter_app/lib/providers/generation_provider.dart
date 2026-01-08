import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'session_provider.dart';
import 'models_provider.dart';
import 'lora_provider.dart';

/// Generation state provider
final generationProvider =
    StateNotifierProvider<GenerationNotifier, GenerationState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final session = ref.watch(sessionProvider);
  return GenerationNotifier(apiService, session);
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

/// Generation notifier
class GenerationNotifier extends StateNotifier<GenerationState> {
  final ApiService _apiService;
  final SessionState _session;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  Timer? _pollTimer;

  GenerationNotifier(this._apiService, this._session)
      : super(const GenerationState()) {
    _listenToWebSocket();
  }

  void _listenToWebSocket() {
    _wsSubscription = _apiService.wsMessages.listen((message) {
      final type = message['type'] as String?;

      if (type == 'generation_progress') {
        final genId = message['generation_id'] as String?;
        if (genId == state.generationId) {
          state = state.copyWith(
            currentStep: message['step'] as int? ?? state.currentStep,
            totalSteps: message['total_steps'] as int? ?? state.totalSteps,
            progress: (message['progress'] as num?)?.toDouble() ?? state.progress,
            currentImage: message['preview'] as String?,
          );
        }
      } else if (type == 'generation_complete') {
        final genId = message['generation_id'] as String?;
        if (genId == state.generationId) {
          final images = (message['images'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [];
          state = state.copyWith(
            isGenerating: false,
            progress: 1.0,
            generatedImages: images,
          );
        }
      } else if (type == 'generation_error') {
        final genId = message['generation_id'] as String?;
        if (genId == state.generationId) {
          state = state.copyWith(
            isGenerating: false,
            error: message['error'] as String? ?? 'Generation failed',
          );
        }
      }
    });
  }

  /// Poll progress for a generation
  void _startPolling(String generationId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) async {
      if (!state.isGenerating || state.generationId != generationId) {
        timer.cancel();
        return;
      }

      try {
        final response = await _apiService.post<Map<String, dynamic>>(
          '/api/GetProgress',
          data: {'prompt_id': generationId},
        );

        if (response.isSuccess && response.data != null) {
          final data = response.data!;
          final status = data['status'] as String?;
          print('Poll response: status=$status, data=$data');

          if (status == 'completed') {
            timer.cancel();
            final imagesList = data['images'] as List? ?? [];
            final fullUrls = imagesList.map((path) => '${_apiService.baseUrl}$path').cast<String>().toList();
            print('Generation completed! Images: $fullUrls');
            state = state.copyWith(
              isGenerating: false,
              progress: 1.0,
              currentStep: state.totalSteps,
              generatedImages: fullUrls,
              currentImage: fullUrls.isNotEmpty ? fullUrls.first : null,
            );
          } else if (status == 'error') {
            timer.cancel();
            state = state.copyWith(
              isGenerating: false,
              error: data['error'] as String? ?? 'Generation failed',
            );
          } else if (status == 'generating' || status == 'queued') {
            final step = data['step'] as int? ?? state.currentStep;
            final total = data['total'] as int? ?? state.totalSteps;
            state = state.copyWith(
              currentStep: step,
              totalSteps: total,
              progress: total > 0 ? step / total : 0.0,
            );
          }
        }
      } catch (e) {
        print('Poll error: $e');
        // Ignore poll errors, will retry
      }
    });
  }

  /// Start generation
  Future<void> generate(GenerationParams params, {List<SelectedLora>? loras}) async {
    if (_session.sessionId == null) {
      state = state.copyWith(error: 'Not connected');
      return;
    }

    // Cancel any existing polling
    _pollTimer?.cancel();

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
      // Use video model if in video mode, otherwise regular model
      final modelToUse = params.videoMode ? (params.videoModel ?? params.model) : params.model;

      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/GenerateText2ImageWS',
        data: {
          'session_id': _session.sessionId,
          'prompt': params.prompt,
          'negativeprompt': params.negativePrompt,
          'model': modelToUse,
          'width': params.width,
          'height': params.height,
          'steps': params.steps,
          'cfgscale': params.cfgScale,
          'seed': params.seed,
          'sampler': params.sampler,
          'scheduler': params.scheduler,
          'images': params.batchSize,
          if (loras != null && loras.isNotEmpty) 'loras': loras.map((l) => l.toJson()).toList(),
          // Video parameters
          if (params.videoMode) 'video_mode': true,
          if (params.videoMode) 'frames': params.frames,
          if (params.videoMode) 'fps': params.fps,
          if (params.videoMode) 'video_format': params.videoFormat,
          if (params.videoMode && params.highNoiseModel != null) 'high_noise_model': params.highNoiseModel,
          if (params.videoMode && params.lowNoiseModel != null) 'low_noise_model': params.lowNoiseModel,
          ...params.extraParams,
        },
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final generationId = data['generation_id'] as String?;

        // Handle async generation (status='generating') - start polling
        if (data['status'] == 'generating' && generationId != null) {
          state = state.copyWith(generationId: generationId);
          _startPolling(generationId);
        }
        // Handle synchronous completion (status='completed')
        else if (data['status'] == 'completed' && data['images'] != null) {
          final images = (data['images'] as List).cast<String>();
          final fullUrls = images.map((path) => '${_apiService.baseUrl}$path').toList();
          state = state.copyWith(
            isGenerating: false,
            progress: 1.0,
            currentStep: params.steps,
            generatedImages: fullUrls,
            currentImage: fullUrls.isNotEmpty ? fullUrls.first : null,
            generationId: generationId,
          );
        } else {
          state = state.copyWith(generationId: generationId);
        }
      } else {
        state = state.copyWith(
          isGenerating: false,
          error: response.error ?? 'Failed to start generation',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: e.toString(),
      );
    }
  }

  /// Cancel current generation
  Future<void> cancel() async {
    _pollTimer?.cancel();
    if (state.generationId == null) return;

    try {
      await _apiService.post('/api/InterruptGeneration', data: {
        'session_id': _session.sessionId,
        'generation_id': state.generationId,
      });
      state = state.copyWith(
        isGenerating: false,
        error: 'Generation cancelled',
      );
    } catch (e) {
      // Ignore cancel errors
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _pollTimer?.cancel();
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
    if (name.contains('ltx')) {
      print('DEBUG: Applying LTX-2 defaults');
      state = state.copyWith(
        width: 768,
        height: 512,
        cfgScale: 3.0,
        steps: 20,
        frames: 121,
        fps: 24,
        videoMode: true,
        videoModel: modelName,  // Set videoModel to the selected model
        videoFormat: 'mp4',
        sampler: 'euler_ancestral',
      );
    } else if (name.contains('wan')) {
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
      print('DEBUG: Applying Hunyuan Video defaults');
      state = state.copyWith(
        width: 848,
        height: 480,
        cfgScale: 6.0,
        steps: 30,
        frames: 45,
        fps: 24,
        videoMode: true,
        videoModel: modelName,
        videoFormat: 'mp4',
      );
    } else if (name.contains('mochi')) {
      print('DEBUG: Applying Mochi defaults');
      state = state.copyWith(
        width: 848,
        height: 480,
        cfgScale: 4.5,
        steps: 50,
        frames: 37,
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
    } else {
      print('DEBUG: Applying image model defaults');
      state = state.copyWith(
        videoMode: false,
        videoModel: null,
        width: 1024,
        height: 1024,
        cfgScale: 7.0,
      );
    }
    print('DEBUG: New state - videoMode=${state.videoMode}, videoModel=${state.videoModel}, cfgScale=${state.cfgScale}, width=${state.width}');
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
