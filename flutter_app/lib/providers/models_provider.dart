import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/comfyui_service.dart';

/// Models state provider
final modelsProvider =
    StateNotifierProvider<ModelsNotifier, ModelsState>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  return ModelsNotifier(comfyService);
});

/// Selected model provider
final selectedModelProvider = StateProvider<ModelInfo?>((ref) => null);

/// Model filter text provider
final modelFilterProvider = StateProvider<String>((ref) => '');

/// VAE filter text provider
final vaeFilterProvider = StateProvider<String>((ref) => '');

/// Models state
class ModelsState {
  final List<ModelInfo> checkpoints;
  final List<ModelInfo> loras;
  final List<ModelInfo> vaes;
  final List<ModelInfo> controlnets;
  final List<ModelInfo> embeddings;
  final List<ModelInfo> textEncoders;
  final List<ModelInfo> diffusionModels;
  final List<String> samplers;
  final List<String> schedulers;
  final bool isLoading;
  final String? error;

  const ModelsState({
    this.checkpoints = const [],
    this.loras = const [],
    this.vaes = const [],
    this.controlnets = const [],
    this.embeddings = const [],
    this.textEncoders = const [],
    this.diffusionModels = const [],
    this.samplers = const [],
    this.schedulers = const [],
    this.isLoading = false,
    this.error,
  });

  /// Get all models
  List<ModelInfo> get all => [
        ...checkpoints,
        ...loras,
        ...vaes,
        ...controlnets,
        ...embeddings,
        ...textEncoders,
        ...diffusionModels,
      ];

  /// Get models by type
  List<ModelInfo> byType(String type) {
    switch (type.toLowerCase()) {
      case 'checkpoint':
      case 'checkpoints':
        return checkpoints;
      case 'lora':
      case 'loras':
        return loras;
      case 'vae':
      case 'vaes':
        return vaes;
      case 'controlnet':
      case 'controlnets':
        return controlnets;
      case 'embedding':
      case 'embeddings':
        return embeddings;
      case 'text_encoder':
      case 'text_encoders':
        return textEncoders;
      case 'diffusion_model':
      case 'diffusion_models':
      case 'unet':
        return diffusionModels;
      default:
        return all;
    }
  }

  ModelsState copyWith({
    List<ModelInfo>? checkpoints,
    List<ModelInfo>? loras,
    List<ModelInfo>? vaes,
    List<ModelInfo>? controlnets,
    List<ModelInfo>? embeddings,
    List<ModelInfo>? textEncoders,
    List<ModelInfo>? diffusionModels,
    List<String>? samplers,
    List<String>? schedulers,
    bool? isLoading,
    String? error,
  }) {
    return ModelsState(
      checkpoints: checkpoints ?? this.checkpoints,
      loras: loras ?? this.loras,
      vaes: vaes ?? this.vaes,
      controlnets: controlnets ?? this.controlnets,
      embeddings: embeddings ?? this.embeddings,
      textEncoders: textEncoders ?? this.textEncoders,
      diffusionModels: diffusionModels ?? this.diffusionModels,
      samplers: samplers ?? this.samplers,
      schedulers: schedulers ?? this.schedulers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Model information
class ModelInfo {
  final String name;
  final String path;
  final String type;
  final String? title;
  final String? modelClass;
  final String? hash;
  final int? size;
  final String? previewImage;
  final Map<String, dynamic>? metadata;

  const ModelInfo({
    required this.name,
    required this.path,
    required this.type,
    this.title,
    this.modelClass,
    this.hash,
    this.size,
    this.previewImage,
    this.metadata,
  });

  /// Create ModelInfo from a simple model name string
  factory ModelInfo.fromName(String name, String type) {
    return ModelInfo(
      name: name,
      path: name,
      type: type,
    );
  }

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      name: json['name'] as String,
      path: json['path'] as String? ?? json['name'] as String,
      type: json['type'] as String? ?? 'checkpoint',
      title: json['title'] as String?,
      modelClass: json['model_class'] as String?,
      hash: json['hash'] as String?,
      size: json['size'] as int?,
      previewImage: json['preview_image'] as String? ?? json['preview_url'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Alias for backwards compatibility
  String? get previewUrl => previewImage;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'type': type,
      if (modelClass != null) 'model_class': modelClass,
      if (hash != null) 'hash': hash,
      if (size != null) 'size': size,
      if (previewUrl != null) 'preview_url': previewUrl,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Get display name (filename without extension)
  String get displayName {
    final parts = name.split('/');
    final filename = parts.last;
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
  }

  /// Get formatted size
  String get formattedSize {
    if (size == null) return 'Unknown';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    if (size! < 1024 * 1024 * 1024) {
      return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size! / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Video model name patterns for filtering checkpoints
const _videoModelPatterns = [
  'ltx',
  'wan',
  'hunyuan',
  'mochi',
  'cogvideo',
  'animatediff',
  'svd',
  'stable-video',
  'stablevideo',
  'video',
  'i2v',
  't2v',
];

/// Check if a model name matches video model patterns
bool _isVideoModel(String name) {
  final lowerName = name.toLowerCase();
  return _videoModelPatterns.any((pattern) => lowerName.contains(pattern));
}

/// Models notifier
class ModelsNotifier extends StateNotifier<ModelsState> {
  final ComfyUIService _comfyService;

  ModelsNotifier(this._comfyService) : super(const ModelsState());

  /// Load all models from ComfyUI
  Future<void> loadModels() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load all model types in parallel from ComfyUI
      final results = await Future.wait([
        _comfyService.getCheckpoints(),    // 0: checkpoints
        _comfyService.getLoras(),          // 1: loras
        _comfyService.getVAEs(),           // 2: vaes
        _comfyService.getControlNets(),    // 3: controlnets
        _comfyService.getEmbeddings(),     // 4: embeddings
        _comfyService.getCLIPModels(),     // 5: text encoders (CLIP models)
        _comfyService.getSamplers(),       // 6: samplers
        _comfyService.getSchedulers(),     // 7: schedulers
      ]);

      final checkpointNames = results[0] as List<String>;
      final loraNames = results[1] as List<String>;
      final vaeNames = results[2] as List<String>;
      final controlnetNames = results[3] as List<String>;
      final embeddingNames = results[4] as List<String>;
      final clipNames = results[5] as List<String>;
      final samplerNames = results[6] as List<String>;
      final schedulerNames = results[7] as List<String>;

      // Separate video models from regular checkpoints
      final sdCheckpoints = <ModelInfo>[];
      final videoModels = <ModelInfo>[];

      for (final name in checkpointNames) {
        if (_isVideoModel(name)) {
          videoModels.add(ModelInfo.fromName(name, 'diffusion_model'));
        } else {
          sdCheckpoints.add(ModelInfo.fromName(name, 'checkpoint'));
        }
      }

      state = state.copyWith(
        checkpoints: sdCheckpoints,
        loras: loraNames.map((n) => ModelInfo.fromName(n, 'lora')).toList(),
        vaes: vaeNames.map((n) => ModelInfo.fromName(n, 'vae')).toList(),
        controlnets: controlnetNames.map((n) => ModelInfo.fromName(n, 'controlnet')).toList(),
        embeddings: embeddingNames.map((n) => ModelInfo.fromName(n, 'embedding')).toList(),
        textEncoders: clipNames.map((n) => ModelInfo.fromName(n, 'text_encoder')).toList(),
        diffusionModels: videoModels,
        samplers: samplerNames,
        schedulers: schedulerNames,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh all models (alias for loadModels)
  Future<void> refresh() async {
    await loadModels();
  }

  /// Search models
  List<ModelInfo> search(String query, {String? type}) {
    final lowercaseQuery = query.toLowerCase();
    final models = type != null ? state.byType(type) : state.all;

    return models.where((model) {
      return model.name.toLowerCase().contains(lowercaseQuery) ||
          model.displayName.toLowerCase().contains(lowercaseQuery) ||
          (model.modelClass?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }
}
