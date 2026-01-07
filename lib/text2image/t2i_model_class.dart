/// Model classification helper
/// Detects model class from file structure/header
class T2IModelClassSorter {
  /// All registered model classes
  static final Map<String, ModelClassInfo> _classes = {};

  /// Initialize default model classes
  static void init() {
    _classes.clear();

    // SD 1.x
    registerClass(ModelClassInfo(
      id: 'sd-v1',
      name: 'Stable Diffusion v1',
      compatClass: 'sd-v1',
      resolution: 512,
      detectionPatterns: ['sd1', 'v1-5', '1.5'],
    ));

    // SD 2.x
    registerClass(ModelClassInfo(
      id: 'sd-v2',
      name: 'Stable Diffusion v2',
      compatClass: 'sd-v2',
      resolution: 768,
      detectionPatterns: ['sd2', 'v2-1', '2.1'],
    ));

    // SDXL
    registerClass(ModelClassInfo(
      id: 'sdxl',
      name: 'SDXL',
      compatClass: 'sdxl',
      resolution: 1024,
      detectionPatterns: ['sdxl', 'xl'],
    ));

    // SDXL Turbo
    registerClass(ModelClassInfo(
      id: 'sdxl-turbo',
      name: 'SDXL Turbo',
      compatClass: 'sdxl',
      resolution: 1024,
      detectionPatterns: ['turbo'],
    ));

    // SD3
    registerClass(ModelClassInfo(
      id: 'sd3',
      name: 'Stable Diffusion 3',
      compatClass: 'sd3',
      resolution: 1024,
      detectionPatterns: ['sd3', 'stable-diffusion-3'],
    ));

    // Flux
    registerClass(ModelClassInfo(
      id: 'flux-dev',
      name: 'Flux Dev',
      compatClass: 'flux',
      resolution: 1024,
      detectionPatterns: ['flux-dev', 'flux.1-dev'],
    ));

    registerClass(ModelClassInfo(
      id: 'flux-schnell',
      name: 'Flux Schnell',
      compatClass: 'flux',
      resolution: 1024,
      detectionPatterns: ['flux-schnell', 'flux.1-schnell'],
    ));

    // Pixart
    registerClass(ModelClassInfo(
      id: 'pixart-alpha',
      name: 'PixArt Alpha',
      compatClass: 'pixart',
      resolution: 1024,
      detectionPatterns: ['pixart-alpha'],
    ));

    registerClass(ModelClassInfo(
      id: 'pixart-sigma',
      name: 'PixArt Sigma',
      compatClass: 'pixart',
      resolution: 1024,
      detectionPatterns: ['pixart-sigma'],
    ));

    // Video models
    registerClass(ModelClassInfo(
      id: 'svd',
      name: 'Stable Video Diffusion',
      compatClass: 'svd',
      resolution: 576,
      isVideo: true,
      detectionPatterns: ['svd', 'stable-video'],
    ));

    registerClass(ModelClassInfo(
      id: 'wan',
      name: 'Wan',
      compatClass: 'wan',
      resolution: 1024,
      isVideo: true,
      detectionPatterns: ['wan', 'wanvideo'],
    ));

    registerClass(ModelClassInfo(
      id: 'hunyuan-video',
      name: 'Hunyuan Video',
      compatClass: 'hunyuan-video',
      resolution: 1024,
      isVideo: true,
      detectionPatterns: ['hunyuan-video', 'hunyuanvideo'],
    ));

    registerClass(ModelClassInfo(
      id: 'mochi',
      name: 'Mochi',
      compatClass: 'mochi',
      resolution: 1024,
      isVideo: true,
      detectionPatterns: ['mochi'],
    ));
  }

  /// Register a model class
  static void registerClass(ModelClassInfo info) {
    _classes[info.id] = info;
  }

  /// Get model class info by ID
  static ModelClassInfo? getClass(String id) {
    return _classes[id.toLowerCase()];
  }

  /// Get all registered classes
  static List<ModelClassInfo> get allClasses => _classes.values.toList();

  /// Detect model class from safetensors header
  static String? detectFromHeader(Map<String, dynamic> header) {
    // Check for explicit metadata
    final metadata = header['__metadata__'] as Map<String, dynamic>?;
    if (metadata != null) {
      // ModelSpec architecture ID
      final arch = metadata['modelspec.architecture'] as String?;
      if (arch != null) {
        final detected = _matchArchitecture(arch);
        if (detected != null) return detected;
      }

      // Base model version
      final baseModel = metadata['ss_base_model_version'] as String?;
      if (baseModel != null) {
        final detected = _matchPattern(baseModel);
        if (detected != null) return detected;
      }
    }

    // Try to detect from tensor shapes
    final detected = _detectFromTensorShapes(header);
    if (detected != null) return detected;

    return null;
  }

  /// Detect model class from file size
  static String? detectFromSize(int sizeBytes) {
    final sizeGB = sizeBytes / (1024 * 1024 * 1024);

    // Rough size-based detection
    if (sizeGB < 1.0) {
      return null; // Too small, might be LoRA or partial
    } else if (sizeGB < 2.5) {
      return 'sd-v1'; // SD 1.x models are ~2GB
    } else if (sizeGB < 5.0) {
      return 'sd-v2'; // SD 2.x models are ~2-5GB
    } else if (sizeGB < 8.0) {
      return 'sdxl'; // SDXL models are ~6-7GB
    } else {
      return null; // Larger models could be various things
    }
  }

  /// Match architecture string to model class
  static String? _matchArchitecture(String arch) {
    final lower = arch.toLowerCase();

    if (lower.contains('stable-diffusion-xl') || lower.contains('sdxl')) {
      return 'sdxl';
    }
    if (lower.contains('stable-diffusion-3') || lower.contains('sd3')) {
      return 'sd3';
    }
    if (lower.contains('stable-diffusion-v2') || lower.contains('sd-v2')) {
      return 'sd-v2';
    }
    if (lower.contains('stable-diffusion') || lower.contains('sd-v1')) {
      return 'sd-v1';
    }
    if (lower.contains('flux')) {
      if (lower.contains('schnell')) return 'flux-schnell';
      return 'flux-dev';
    }
    if (lower.contains('pixart')) {
      if (lower.contains('sigma')) return 'pixart-sigma';
      return 'pixart-alpha';
    }
    if (lower.contains('svd') || lower.contains('stable-video')) {
      return 'svd';
    }
    if (lower.contains('hunyuan-video')) {
      return 'hunyuan-video';
    }
    if (lower.contains('mochi')) {
      return 'mochi';
    }

    return null;
  }

  /// Match a string against detection patterns
  static String? _matchPattern(String text) {
    final lower = text.toLowerCase();

    for (final classInfo in _classes.values) {
      for (final pattern in classInfo.detectionPatterns) {
        if (lower.contains(pattern.toLowerCase())) {
          return classInfo.id;
        }
      }
    }

    return null;
  }

  /// Detect from tensor shapes in header
  static String? _detectFromTensorShapes(Map<String, dynamic> header) {
    // Look for key tensors that indicate model type
    final keys = header.keys.toList();

    // Check for SDXL-specific tensors
    if (keys.any((k) => k.contains('conditioner.embedders.1'))) {
      return 'sdxl';
    }

    // Check for Flux-specific tensors
    if (keys.any((k) => k.contains('double_blocks') || k.contains('single_blocks'))) {
      return 'flux-dev';
    }

    // Check for SD3-specific tensors
    if (keys.any((k) => k.contains('joint_blocks'))) {
      return 'sd3';
    }

    // Check for video model tensors
    if (keys.any((k) => k.contains('temporal_transformer'))) {
      return 'svd';
    }

    // Default to SD 1.x if we see standard UNet structure
    if (keys.any((k) => k.startsWith('model.diffusion_model'))) {
      // Check embedding size to distinguish v1 vs v2
      final embedKey = keys.firstWhere(
        (k) => k.contains('transformer') && k.contains('proj_in'),
        orElse: () => '',
      );
      if (embedKey.isNotEmpty) {
        final shape = header[embedKey] as Map<String, dynamic>?;
        if (shape != null) {
          final dtype = shape['dtype'] as String?;
          // Additional shape analysis could go here
        }
      }
      return 'sd-v1';
    }

    return null;
  }

  /// Get compatible classes for a model class
  static List<String> getCompatibleClasses(String modelClass) {
    final info = _classes[modelClass.toLowerCase()];
    if (info == null) return [modelClass];

    return _classes.values
        .where((c) => c.compatClass == info.compatClass)
        .map((c) => c.id)
        .toList();
  }
}

/// Information about a model class
class ModelClassInfo {
  /// Unique identifier
  final String id;

  /// Display name
  final String name;

  /// Compatibility class (for LoRA matching)
  final String compatClass;

  /// Standard resolution
  final int resolution;

  /// Is this a video model?
  final bool isVideo;

  /// Patterns to detect this class
  final List<String> detectionPatterns;

  /// Default CFG scale
  final double defaultCfg;

  /// Default steps
  final int defaultSteps;

  ModelClassInfo({
    required this.id,
    required this.name,
    required this.compatClass,
    required this.resolution,
    this.isVideo = false,
    this.detectionPatterns = const [],
    this.defaultCfg = 7.0,
    this.defaultSteps = 20,
  });
}
