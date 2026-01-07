/// Model representation for T2I
/// Equivalent to SwarmUI's T2IModel
class T2IModel {
  /// Model name (relative path from model root)
  final String name;

  /// Model type (Stable-Diffusion, LoRA, VAE, etc.)
  final String type;

  /// Full file path
  final String filePath;

  /// Display title
  String? title;

  /// Model author
  String? author;

  /// Model description
  String? description;

  /// Path to preview image
  String? previewImage;

  /// Detected model class (e.g., 'sd-v1', 'sdxl', 'flux')
  String? modelClass;

  /// Compatibility class for matching LoRAs
  String? compatClass;

  /// Model metadata
  T2IModelMetadata? metadata;

  /// Is this model loaded on any backend?
  bool anyBackendsHaveLoaded = false;

  /// Backend-specific data
  final Map<String, dynamic> backendData = {};

  T2IModel({
    required this.name,
    required this.type,
    required this.filePath,
    this.title,
    this.author,
    this.description,
    this.previewImage,
    this.modelClass,
    this.compatClass,
    this.metadata,
  });

  /// Get display name (title or filename)
  String get displayName {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    // Get filename without extension
    final parts = name.split('/');
    final filename = parts.last;
    final dotIndex = filename.lastIndexOf('.');
    return dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
  }

  /// Get simple name (without folder path)
  String get simpleName {
    final parts = name.split('/');
    return parts.last;
  }

  /// Get folder path
  String get folder {
    final parts = name.split('/');
    if (parts.length > 1) {
      return parts.sublist(0, parts.length - 1).join('/');
    }
    return '';
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'title': title,
        'author': author,
        'description': description,
        'previewImage': previewImage,
        'modelClass': modelClass,
        'compatClass': compatClass,
        'metadata': metadata?.toJson(),
      };

  /// Create from JSON
  factory T2IModel.fromJson(Map<String, dynamic> json, String filePath) =>
      T2IModel(
        name: json['name'] as String,
        type: json['type'] as String,
        filePath: filePath,
        title: json['title'] as String?,
        author: json['author'] as String?,
        description: json['description'] as String?,
        previewImage: json['previewImage'] as String?,
        modelClass: json['modelClass'] as String?,
        compatClass: json['compatClass'] as String?,
        metadata: json['metadata'] != null
            ? T2IModelMetadata.fromJson(
                Map<String, dynamic>.from(json['metadata'] as Map))
            : null,
      );

  @override
  String toString() => 'T2IModel($name, class: $modelClass)';
}

/// Model metadata extracted from file
class T2IModelMetadata {
  /// Standard resolution for this model
  int? standardWidth;
  int? standardHeight;

  /// Prediction type (epsilon, v_prediction, etc.)
  String? predictionType;

  /// Model license
  String? license;

  /// Trigger phrase for activation
  String? triggerPhrase;

  /// Tags/categories
  List<String>? tags;

  /// Base model info
  String? baseModel;

  /// Training info
  String? trainingComment;
  int? trainingSteps;
  double? trainingLearningRate;

  /// Hash for identification
  String? sha256Hash;
  String? autoV1Hash;
  String? autoV2Hash;

  T2IModelMetadata({
    this.standardWidth,
    this.standardHeight,
    this.predictionType,
    this.license,
    this.triggerPhrase,
    this.tags,
    this.baseModel,
    this.trainingComment,
    this.trainingSteps,
    this.trainingLearningRate,
    this.sha256Hash,
    this.autoV1Hash,
    this.autoV2Hash,
  });

  /// Create from safetensors metadata
  factory T2IModelMetadata.fromSafetensors(Map<String, dynamic> meta) {
    // Parse resolution
    int? width, height;
    final resolution = meta['modelspec.resolution'] as String?;
    if (resolution != null && resolution.contains('x')) {
      final parts = resolution.split('x');
      width = int.tryParse(parts[0]);
      height = int.tryParse(parts[1]);
    }

    // Parse tags
    List<String>? tags;
    final tagsStr = meta['modelspec.tags'] as String?;
    if (tagsStr != null && tagsStr.isNotEmpty) {
      tags = tagsStr.split(',').map((t) => t.trim()).toList();
    }

    return T2IModelMetadata(
      standardWidth: width,
      standardHeight: height,
      predictionType: meta['modelspec.prediction_type'] as String?,
      license: meta['modelspec.license'] as String?,
      triggerPhrase: meta['modelspec.trigger_phrase'] as String?,
      tags: tags,
      baseModel: meta['ss_base_model_version'] as String? ??
          meta['modelspec.architecture'] as String?,
      trainingComment: meta['ss_training_comment'] as String?,
      trainingSteps: int.tryParse(meta['ss_steps']?.toString() ?? ''),
      trainingLearningRate: double.tryParse(meta['ss_learning_rate']?.toString() ?? ''),
      sha256Hash: meta['modelspec.hash_sha256'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'standardWidth': standardWidth,
        'standardHeight': standardHeight,
        'predictionType': predictionType,
        'license': license,
        'triggerPhrase': triggerPhrase,
        'tags': tags,
        'baseModel': baseModel,
        'trainingComment': trainingComment,
        'trainingSteps': trainingSteps,
        'trainingLearningRate': trainingLearningRate,
        'sha256Hash': sha256Hash,
        'autoV1Hash': autoV1Hash,
        'autoV2Hash': autoV2Hash,
      };

  /// Create from JSON
  factory T2IModelMetadata.fromJson(Map<String, dynamic> json) =>
      T2IModelMetadata(
        standardWidth: json['standardWidth'] as int?,
        standardHeight: json['standardHeight'] as int?,
        predictionType: json['predictionType'] as String?,
        license: json['license'] as String?,
        triggerPhrase: json['triggerPhrase'] as String?,
        tags: (json['tags'] as List?)?.cast<String>(),
        baseModel: json['baseModel'] as String?,
        trainingComment: json['trainingComment'] as String?,
        trainingSteps: json['trainingSteps'] as int?,
        trainingLearningRate: (json['trainingLearningRate'] as num?)?.toDouble(),
        sha256Hash: json['sha256Hash'] as String?,
        autoV1Hash: json['autoV1Hash'] as String?,
        autoV2Hash: json['autoV2Hash'] as String?,
      );
}
