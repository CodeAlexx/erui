import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

/// Models state provider
final modelsProvider =
    StateNotifierProvider<ModelsNotifier, ModelsState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ModelsNotifier(apiService);
});

/// Selected model provider
final selectedModelProvider = StateProvider<ModelInfo?>((ref) => null);

/// Models state
class ModelsState {
  final List<ModelInfo> checkpoints;
  final List<ModelInfo> loras;
  final List<ModelInfo> vaes;
  final List<ModelInfo> controlnets;
  final List<ModelInfo> embeddings;
  final List<ModelInfo> textEncoders;
  final List<ModelInfo> diffusionModels;
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

/// Models notifier
class ModelsNotifier extends StateNotifier<ModelsState> {
  final ApiService _apiService;

  ModelsNotifier(this._apiService) : super(const ModelsState());

  /// Load all models
  Future<void> loadModels() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load all model types in parallel
      final results = await Future.wait([
        _loadModelType('Stable-Diffusion'),
        _loadModelType('Lora'),
        _loadModelType('VAE'),
        _loadModelType('ControlNet'),
        _loadModelType('Embedding'),
        _loadModelType('clip'),
        _loadDiffusionModels(),
      ]);

      state = state.copyWith(
        checkpoints: results[0],
        loras: results[1],
        vaes: results[2],
        controlnets: results[3],
        embeddings: results[4],
        textEncoders: results[5],
        diffusionModels: results[6],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load diffusion models (video models, z_image, etc.)
  Future<List<ModelInfo>> _loadDiffusionModels() async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/ListDiffusionModels',
        data: {},
      );

      if (response.isSuccess && response.data != null) {
        final files = response.data!['files'] as List<dynamic>?;
        if (files != null) {
          return files
              .map((f) => ModelInfo.fromJson({
                    ...f as Map<String, dynamic>,
                    'type': 'diffusion_model',
                  }))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Load specific model type
  Future<List<ModelInfo>> _loadModelType(String type) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/ListModels',
        data: {'path': '', 'depth': 10, 'subtype': type},
      );

      if (response.isSuccess && response.data != null) {
        final files = response.data!['files'] as List<dynamic>?;
        if (files != null) {
          return files
              .map((f) => ModelInfo.fromJson({
                    ...f as Map<String, dynamic>,
                    'type': type,
                  }))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Refresh models
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
