import 'dart:convert';

/// Preset model for saving and loading generation parameters
class Preset {
  /// Unique identifier for the preset
  final String id;

  /// Display name for the preset
  final String name;

  /// Optional folder for organization
  final String? folder;

  /// Optional prompt text
  final String? prompt;

  /// Optional negative prompt text
  final String? negativePrompt;

  /// Optional model name
  final String? model;

  /// Optional number of steps
  final int? steps;

  /// Optional CFG scale
  final double? cfgScale;

  /// Optional width
  final int? width;

  /// Optional height
  final int? height;

  /// Optional sampler name
  final String? sampler;

  /// Optional scheduler name
  final String? scheduler;

  /// Optional batch size
  final int? batchSize;

  /// Optional seed value (-1 for random)
  final int? seed;

  /// Video mode enabled
  final bool? videoMode;

  /// Video model name
  final String? videoModel;

  /// Number of frames for video
  final int? frames;

  /// Frames per second for video
  final int? fps;

  /// Video format (mp4, webp, etc.)
  final String? videoFormat;

  /// Optional additional parameters
  final Map<String, dynamic>? extraParams;

  /// When the preset was created
  final DateTime createdAt;

  /// When the preset was last modified
  final DateTime? updatedAt;

  /// Optional description for the preset
  final String? description;

  /// Optional thumbnail/preview image path or URL
  final String? thumbnail;

  const Preset({
    required this.id,
    required this.name,
    this.folder,
    this.prompt,
    this.negativePrompt,
    this.model,
    this.steps,
    this.cfgScale,
    this.width,
    this.height,
    this.sampler,
    this.scheduler,
    this.batchSize,
    this.seed,
    this.videoMode,
    this.videoModel,
    this.frames,
    this.fps,
    this.videoFormat,
    this.extraParams,
    required this.createdAt,
    this.updatedAt,
    this.description,
    this.thumbnail,
  });

  /// Create a copy with updated fields
  Preset copyWith({
    String? id,
    String? name,
    String? folder,
    String? prompt,
    String? negativePrompt,
    String? model,
    int? steps,
    double? cfgScale,
    int? width,
    int? height,
    String? sampler,
    String? scheduler,
    int? batchSize,
    int? seed,
    bool? videoMode,
    String? videoModel,
    int? frames,
    int? fps,
    String? videoFormat,
    Map<String, dynamic>? extraParams,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    String? thumbnail,
  }) {
    return Preset(
      id: id ?? this.id,
      name: name ?? this.name,
      folder: folder ?? this.folder,
      prompt: prompt ?? this.prompt,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      model: model ?? this.model,
      steps: steps ?? this.steps,
      cfgScale: cfgScale ?? this.cfgScale,
      width: width ?? this.width,
      height: height ?? this.height,
      sampler: sampler ?? this.sampler,
      scheduler: scheduler ?? this.scheduler,
      batchSize: batchSize ?? this.batchSize,
      seed: seed ?? this.seed,
      videoMode: videoMode ?? this.videoMode,
      videoModel: videoModel ?? this.videoModel,
      frames: frames ?? this.frames,
      fps: fps ?? this.fps,
      videoFormat: videoFormat ?? this.videoFormat,
      extraParams: extraParams ?? this.extraParams,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      thumbnail: thumbnail ?? this.thumbnail,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'folder': folder,
      'prompt': prompt,
      'negativePrompt': negativePrompt,
      'model': model,
      'steps': steps,
      'cfgScale': cfgScale,
      'width': width,
      'height': height,
      'sampler': sampler,
      'scheduler': scheduler,
      'batchSize': batchSize,
      'seed': seed,
      'videoMode': videoMode,
      'videoModel': videoModel,
      'frames': frames,
      'fps': fps,
      'videoFormat': videoFormat,
      'extraParams': extraParams,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'description': description,
      'thumbnail': thumbnail,
    };
  }

  /// Create from JSON map
  factory Preset.fromJson(Map<String, dynamic> json) {
    return Preset(
      id: json['id'] as String,
      name: json['name'] as String,
      folder: json['folder'] as String?,
      prompt: json['prompt'] as String?,
      negativePrompt: json['negativePrompt'] as String?,
      model: json['model'] as String?,
      steps: json['steps'] as int?,
      cfgScale: (json['cfgScale'] as num?)?.toDouble(),
      width: json['width'] as int?,
      height: json['height'] as int?,
      sampler: json['sampler'] as String?,
      scheduler: json['scheduler'] as String?,
      batchSize: json['batchSize'] as int?,
      seed: json['seed'] as int?,
      videoMode: json['videoMode'] as bool?,
      videoModel: json['videoModel'] as String?,
      frames: json['frames'] as int?,
      fps: json['fps'] as int?,
      videoFormat: json['videoFormat'] as String?,
      extraParams: json['extraParams'] != null
          ? Map<String, dynamic>.from(json['extraParams'] as Map)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      description: json['description'] as String?,
      thumbnail: json['thumbnail'] as String?,
    );
  }

  /// Encode to JSON string
  String encode() => jsonEncode(toJson());

  /// Decode from JSON string
  static Preset decode(String source) =>
      Preset.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() => 'Preset(id: $id, name: $name, folder: $folder)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Preset && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Represents a folder for organizing presets
class PresetFolder {
  final String name;
  final String? parentFolder;
  final int presetCount;

  const PresetFolder({
    required this.name,
    this.parentFolder,
    this.presetCount = 0,
  });

  /// Get the full path of the folder
  String get path => parentFolder != null ? '$parentFolder/$name' : name;

  @override
  String toString() => 'PresetFolder(name: $name, path: $path)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresetFolder && other.path == path;
  }

  @override
  int get hashCode => path.hashCode;
}
