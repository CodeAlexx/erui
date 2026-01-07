import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

/// ControlNet configuration
class ControlNetConfig {
  final String? model;
  final String? preprocessor;
  final Uint8List? image;
  final double strength;
  final double startPercent;
  final double endPercent;

  const ControlNetConfig({
    this.model,
    this.preprocessor,
    this.image,
    this.strength = 1.0,
    this.startPercent = 0.0,
    this.endPercent = 1.0,
  });

  ControlNetConfig copyWith({
    String? model,
    String? preprocessor,
    Uint8List? image,
    double? strength,
    double? startPercent,
    double? endPercent,
  }) {
    return ControlNetConfig(
      model: model ?? this.model,
      preprocessor: preprocessor ?? this.preprocessor,
      image: image ?? this.image,
      strength: strength ?? this.strength,
      startPercent: startPercent ?? this.startPercent,
      endPercent: endPercent ?? this.endPercent,
    );
  }

  bool get isEnabled => model != null && model!.isNotEmpty && image != null;
}

/// Img2Img configuration
class Img2ImgConfig {
  final Uint8List? initImage;
  final double creativity;
  final String resizeMode;

  const Img2ImgConfig({
    this.initImage,
    this.creativity = 0.6,
    this.resizeMode = 'resize',
  });

  Img2ImgConfig copyWith({
    Uint8List? initImage,
    double? creativity,
    String? resizeMode,
  }) {
    return Img2ImgConfig(
      initImage: initImage ?? this.initImage,
      creativity: creativity ?? this.creativity,
      resizeMode: resizeMode ?? this.resizeMode,
    );
  }

  bool get isEnabled => initImage != null;
}

/// Inpainting configuration
class InpaintConfig {
  final Uint8List? initImage;
  final Uint8List? maskImage;
  final double creativity;
  final int maskBlur;
  final int maskExpand;
  final String fillMode;

  const InpaintConfig({
    this.initImage,
    this.maskImage,
    this.creativity = 1.0,
    this.maskBlur = 4,
    this.maskExpand = 0,
    this.fillMode = 'original',
  });

  InpaintConfig copyWith({
    Uint8List? initImage,
    Uint8List? maskImage,
    double? creativity,
    int? maskBlur,
    int? maskExpand,
    String? fillMode,
  }) {
    return InpaintConfig(
      initImage: initImage ?? this.initImage,
      maskImage: maskImage ?? this.maskImage,
      creativity: creativity ?? this.creativity,
      maskBlur: maskBlur ?? this.maskBlur,
      maskExpand: maskExpand ?? this.maskExpand,
      fillMode: fillMode ?? this.fillMode,
    );
  }

  bool get isEnabled => initImage != null && maskImage != null;
}

/// Upscale configuration
class UpscaleConfig {
  final String? upscaler;
  final double scale;
  final int tileSize;
  final int overlap;

  const UpscaleConfig({
    this.upscaler,
    this.scale = 2.0,
    this.tileSize = 512,
    this.overlap = 32,
  });

  UpscaleConfig copyWith({
    String? upscaler,
    double? scale,
    int? tileSize,
    int? overlap,
  }) {
    return UpscaleConfig(
      upscaler: upscaler ?? this.upscaler,
      scale: scale ?? this.scale,
      tileSize: tileSize ?? this.tileSize,
      overlap: overlap ?? this.overlap,
    );
  }

  bool get isEnabled => upscaler != null && upscaler!.isNotEmpty;
}

/// Refiner configuration
class RefinerConfig {
  final String? model;
  final double switchAt;

  const RefinerConfig({
    this.model,
    this.switchAt = 0.8,
  });

  RefinerConfig copyWith({
    String? model,
    double? switchAt,
  }) {
    return RefinerConfig(
      model: model ?? this.model,
      switchAt: switchAt ?? this.switchAt,
    );
  }

  bool get isEnabled => model != null && model!.isNotEmpty;
}

/// Regional prompt configuration
class RegionConfig {
  final String prompt;
  final int x;
  final int y;
  final int width;
  final int height;
  final double strength;

  const RegionConfig({
    this.prompt = '',
    this.x = 0,
    this.y = 0,
    this.width = 512,
    this.height = 512,
    this.strength = 1.0,
  });

  RegionConfig copyWith({
    String? prompt,
    int? x,
    int? y,
    int? width,
    int? height,
    double? strength,
  }) {
    return RegionConfig(
      prompt: prompt ?? this.prompt,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      strength: strength ?? this.strength,
    );
  }

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'strength': strength,
  };
}

/// Advanced generation state
class AdvancedGenerationState {
  final ControlNetConfig controlNet;
  final Img2ImgConfig img2img;
  final InpaintConfig inpaint;
  final UpscaleConfig upscale;
  final RefinerConfig refiner;
  final List<RegionConfig> regions;
  final String activeMode; // 'txt2img', 'img2img', 'inpaint', 'controlnet', 'regional'

  const AdvancedGenerationState({
    this.controlNet = const ControlNetConfig(),
    this.img2img = const Img2ImgConfig(),
    this.inpaint = const InpaintConfig(),
    this.upscale = const UpscaleConfig(),
    this.refiner = const RefinerConfig(),
    this.regions = const [],
    this.activeMode = 'txt2img',
  });

  AdvancedGenerationState copyWith({
    ControlNetConfig? controlNet,
    Img2ImgConfig? img2img,
    InpaintConfig? inpaint,
    UpscaleConfig? upscale,
    RefinerConfig? refiner,
    List<RegionConfig>? regions,
    String? activeMode,
  }) {
    return AdvancedGenerationState(
      controlNet: controlNet ?? this.controlNet,
      img2img: img2img ?? this.img2img,
      inpaint: inpaint ?? this.inpaint,
      upscale: upscale ?? this.upscale,
      refiner: refiner ?? this.refiner,
      regions: regions ?? this.regions,
      activeMode: activeMode ?? this.activeMode,
    );
  }
}

/// Advanced generation notifier
class AdvancedGenerationNotifier extends StateNotifier<AdvancedGenerationState> {
  final ApiService _apiService;

  AdvancedGenerationNotifier(this._apiService) : super(const AdvancedGenerationState());

  // ========== MODE ==========

  void setMode(String mode) {
    state = state.copyWith(activeMode: mode);
  }

  // ========== CONTROLNET ==========

  void setControlNetModel(String? model) {
    state = state.copyWith(
      controlNet: state.controlNet.copyWith(model: model),
    );
  }

  void setControlNetPreprocessor(String? preprocessor) {
    state = state.copyWith(
      controlNet: state.controlNet.copyWith(preprocessor: preprocessor),
    );
  }

  void setControlNetImage(Uint8List? image) {
    state = state.copyWith(
      controlNet: state.controlNet.copyWith(image: image),
    );
  }

  void setControlNetStrength(double strength) {
    state = state.copyWith(
      controlNet: state.controlNet.copyWith(strength: strength),
    );
  }

  void setControlNetStartPercent(double startPercent) {
    state = state.copyWith(
      controlNet: state.controlNet.copyWith(startPercent: startPercent),
    );
  }

  void setControlNetEndPercent(double endPercent) {
    state = state.copyWith(
      controlNet: state.controlNet.copyWith(endPercent: endPercent),
    );
  }

  void clearControlNet() {
    state = state.copyWith(controlNet: const ControlNetConfig());
  }

  // ========== IMG2IMG ==========

  void setInitImage(Uint8List? image) {
    state = state.copyWith(
      img2img: state.img2img.copyWith(initImage: image),
    );
  }

  void setCreativity(double creativity) {
    state = state.copyWith(
      img2img: state.img2img.copyWith(creativity: creativity),
    );
  }

  void setResizeMode(String mode) {
    state = state.copyWith(
      img2img: state.img2img.copyWith(resizeMode: mode),
    );
  }

  void clearImg2Img() {
    state = state.copyWith(img2img: const Img2ImgConfig());
  }

  // ========== INPAINT ==========

  void setInpaintInitImage(Uint8List? image) {
    state = state.copyWith(
      inpaint: state.inpaint.copyWith(initImage: image),
    );
  }

  void setMaskImage(Uint8List? image) {
    state = state.copyWith(
      inpaint: state.inpaint.copyWith(maskImage: image),
    );
  }

  void setInpaintCreativity(double creativity) {
    state = state.copyWith(
      inpaint: state.inpaint.copyWith(creativity: creativity),
    );
  }

  void setMaskBlur(int blur) {
    state = state.copyWith(
      inpaint: state.inpaint.copyWith(maskBlur: blur),
    );
  }

  void setMaskExpand(int expand) {
    state = state.copyWith(
      inpaint: state.inpaint.copyWith(maskExpand: expand),
    );
  }

  void setFillMode(String mode) {
    state = state.copyWith(
      inpaint: state.inpaint.copyWith(fillMode: mode),
    );
  }

  void clearInpaint() {
    state = state.copyWith(inpaint: const InpaintConfig());
  }

  // ========== UPSCALE ==========

  void setUpscaler(String? upscaler) {
    state = state.copyWith(
      upscale: state.upscale.copyWith(upscaler: upscaler),
    );
  }

  void setUpscaleScale(double scale) {
    state = state.copyWith(
      upscale: state.upscale.copyWith(scale: scale),
    );
  }

  void setUpscaleTileSize(int tileSize) {
    state = state.copyWith(
      upscale: state.upscale.copyWith(tileSize: tileSize),
    );
  }

  void clearUpscale() {
    state = state.copyWith(upscale: const UpscaleConfig());
  }

  // ========== REFINER ==========

  void setRefinerModel(String? model) {
    state = state.copyWith(
      refiner: state.refiner.copyWith(model: model),
    );
  }

  void setRefinerSwitchAt(double switchAt) {
    state = state.copyWith(
      refiner: state.refiner.copyWith(switchAt: switchAt),
    );
  }

  void clearRefiner() {
    state = state.copyWith(refiner: const RefinerConfig());
  }

  // ========== REGIONS ==========

  void addRegion(RegionConfig region) {
    state = state.copyWith(regions: [...state.regions, region]);
  }

  void updateRegion(int index, RegionConfig region) {
    if (index < 0 || index >= state.regions.length) return;
    final regions = List<RegionConfig>.from(state.regions);
    regions[index] = region;
    state = state.copyWith(regions: regions);
  }

  void removeRegion(int index) {
    if (index < 0 || index >= state.regions.length) return;
    final regions = List<RegionConfig>.from(state.regions);
    regions.removeAt(index);
    state = state.copyWith(regions: regions);
  }

  void clearRegions() {
    state = state.copyWith(regions: []);
  }

  // ========== RESET ==========

  void reset() {
    state = const AdvancedGenerationState();
  }
}

/// Provider for advanced generation state
final advancedGenerationProvider = StateNotifierProvider<AdvancedGenerationNotifier, AdvancedGenerationState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AdvancedGenerationNotifier(apiService);
});

/// Queue item
class QueueItem {
  final String id;
  final String type;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? batchId;
  final Map<String, dynamic>? params;
  final double? progress;
  final String? previewUrl;

  const QueueItem({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.batchId,
    this.params,
    this.progress,
    this.previewUrl,
  });

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      batchId: json['batch_id'] as String?,
      params: json['params'] as Map<String, dynamic>?,
      progress: json['progress'] as double?,
      previewUrl: json['preview_url'] as String?,
    );
  }
}

/// Queue state
class QueueState {
  final List<QueueItem> items;
  final int pending;
  final int running;
  final bool isLoading;
  final String? error;

  const QueueState({
    this.items = const [],
    this.pending = 0,
    this.running = 0,
    this.isLoading = false,
    this.error,
  });

  QueueState copyWith({
    List<QueueItem>? items,
    int? pending,
    int? running,
    bool? isLoading,
    String? error,
  }) {
    return QueueState(
      items: items ?? this.items,
      pending: pending ?? this.pending,
      running: running ?? this.running,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Queue notifier
class QueueNotifier extends StateNotifier<QueueState> {
  final ApiService _apiService;

  QueueNotifier(this._apiService) : super(const QueueState());

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.get('/api/GetQueueStatus');
      if (!response.isSuccess || response.data == null) {
        state = state.copyWith(isLoading: false, error: 'Failed to fetch queue');
        return;
      }
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List? ?? [])
          .map((e) => QueueItem.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        items: items,
        pending: data['pending'] as int? ?? 0,
        running: data['running'] as int? ?? 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> cancelItem(String id) async {
    try {
      await _apiService.post('/api/CancelQueueItem', data: {'id': id});
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearQueue() async {
    try {
      await _apiService.post('/api/ClearQueue', data: {});
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> reorderQueue(List<String> order) async {
    try {
      await _apiService.post('/api/ReorderQueue', data: {'order': order});
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Provider for queue state
final queueProvider = StateNotifierProvider<QueueNotifier, QueueState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return QueueNotifier(apiService);
});

/// ControlNet model info
class ControlNetModel {
  final String name;
  final String path;
  final String? type;

  const ControlNetModel({
    required this.name,
    required this.path,
    this.type,
  });

  factory ControlNetModel.fromJson(Map<String, dynamic> json) {
    return ControlNetModel(
      name: json['name'] as String,
      path: json['path'] as String,
      type: json['type'] as String?,
    );
  }
}

/// Preprocessor info
class Preprocessor {
  final String id;
  final String name;
  final String description;

  const Preprocessor({
    required this.id,
    required this.name,
    required this.description,
  });

  factory Preprocessor.fromJson(Map<String, dynamic> json) {
    return Preprocessor(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
    );
  }
}

/// Upscaler info
class UpscalerModel {
  final String name;
  final String path;
  final String scale;

  const UpscalerModel({
    required this.name,
    required this.path,
    required this.scale,
  });

  factory UpscalerModel.fromJson(Map<String, dynamic> json) {
    return UpscalerModel(
      name: json['name'] as String,
      path: json['path'] as String,
      scale: json['scale'] as String,
    );
  }
}

/// Provider for ControlNet models
final controlNetModelsProvider = FutureProvider<List<ControlNetModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final response = await apiService.get('/api/ListControlNetModels');
  if (!response.isSuccess || response.data == null) return [];
  final data = response.data as Map<String, dynamic>;
  final models = (data['models'] as List? ?? [])
      .map((e) => ControlNetModel.fromJson(e as Map<String, dynamic>))
      .toList();
  return models;
});

/// Provider for preprocessors
final preprocessorsProvider = FutureProvider<List<Preprocessor>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final response = await apiService.get('/api/ListControlNetPreprocessors');
  if (!response.isSuccess || response.data == null) return [];
  final data = response.data as Map<String, dynamic>;
  final preprocessors = (data['preprocessors'] as List? ?? [])
      .map((e) => Preprocessor.fromJson(e as Map<String, dynamic>))
      .toList();
  return preprocessors;
});

/// Provider for upscalers
final upscalersProvider = FutureProvider<List<UpscalerModel>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final response = await apiService.get('/api/ListUpscalers');
  if (!response.isSuccess || response.data == null) return [];
  final data = response.data as Map<String, dynamic>;
  final upscalers = (data['upscalers'] as List? ?? [])
      .map((e) => UpscalerModel.fromJson(e as Map<String, dynamic>))
      .toList();
  return upscalers;
});
