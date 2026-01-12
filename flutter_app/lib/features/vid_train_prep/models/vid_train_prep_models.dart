import 'dart:ui';
import 'package:uuid/uuid.dart';

/// Models for VidTrainPrep - Video Training Dataset Preparation
///
/// This feature allows users to load videos, define clip ranges with captions,
/// apply crop regions, and export datasets for AI video model training.

/// UUID generator for creating unique identifiers.
const _uuid = Uuid();

/// Unique identifier for VidTrainPrep objects
typedef VidTrainId = String;

/// Generate a unique ID using UUID v4
VidTrainId generateVidTrainId() => _uuid.v4();

/// Represents a video source file loaded into the project
class VideoSource {
  final VidTrainId id;
  final String filePath;
  final String fileName;
  final int width;
  final int height;
  final double fps;
  final int frameCount;
  final Duration duration;
  final int? fileSizeBytes;

  /// Path to the generated thumbnail image (optional).
  String? thumbnailPath;

  VideoSource({
    String? id,
    required this.filePath,
    required this.fileName,
    required this.width,
    required this.height,
    required this.fps,
    required this.frameCount,
    required this.duration,
    this.fileSizeBytes,
    this.thumbnailPath,
  }) : id = id ?? generateVidTrainId();

  /// Create from file path with metadata
  factory VideoSource.create({
    required String filePath,
    required String fileName,
    required int width,
    required int height,
    required double fps,
    required int frameCount,
    int? fileSizeBytes,
    String? thumbnailPath,
  }) {
    return VideoSource(
      filePath: filePath,
      fileName: fileName,
      width: width,
      height: height,
      fps: fps,
      frameCount: frameCount,
      duration: Duration(milliseconds: (frameCount / fps * 1000).round()),
      fileSizeBytes: fileSizeBytes,
      thumbnailPath: thumbnailPath,
    );
  }

  VideoSource copyWith({
    VidTrainId? id,
    String? filePath,
    String? fileName,
    int? width,
    int? height,
    double? fps,
    int? frameCount,
    Duration? duration,
    int? fileSizeBytes,
    String? thumbnailPath,
  }) {
    return VideoSource(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      frameCount: frameCount ?? this.frameCount,
      duration: duration ?? this.duration,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  /// Converts this VideoSource to a JSON map for persistence.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'fileName': fileName,
      'width': width,
      'height': height,
      'fps': fps,
      'frameCount': frameCount,
      'durationMicroseconds': duration.inMicroseconds,
      'fileSizeBytes': fileSizeBytes,
      'thumbnailPath': thumbnailPath,
    };
  }

  /// Creates a VideoSource from a JSON map.
  factory VideoSource.fromJson(Map<String, dynamic> json) {
    return VideoSource(
      id: json['id'] as String?,
      filePath: json['filePath'] as String? ?? json['path'] as String? ?? '',
      fileName: json['fileName'] as String? ?? json['filename'] as String? ?? '',
      width: json['width'] as int,
      height: json['height'] as int,
      fps: (json['fps'] as num).toDouble(),
      frameCount: json['frameCount'] as int,
      duration: json['durationMicroseconds'] != null
          ? Duration(microseconds: json['durationMicroseconds'] as int)
          : Duration(milliseconds: ((json['frameCount'] as int) / (json['fps'] as num) * 1000).round()),
      fileSizeBytes: json['fileSizeBytes'] as int?,
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  /// Video aspect ratio (width / height).
  double get aspectRatio => width / height;

  /// Duration formatted as HH:MM:SS or MM:SS.
  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() => 'VideoSource($fileName, ${width}x$height, $frameCount frames)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoSource && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Crop region in normalized coordinates (0.0-1.0).
///
/// Uses normalized coordinates to be resolution-independent.
/// All values are in the range 0.0 to 1.0 relative to video dimensions.
class CropRegion {
  /// Left edge position (0.0 = left edge, 1.0 = right edge).
  final double x;

  /// Top edge position (0.0 = top edge, 1.0 = bottom edge).
  final double y;

  /// Width of crop region (0.0 to 1.0-x).
  final double width;

  /// Height of crop region (0.0 to 1.0-y).
  final double height;

  const CropRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Full frame (no crop)
  const CropRegion.full()
      : x = 0,
        y = 0,
        width = 1,
        height = 1;

  /// Create centered crop with specific aspect ratio
  factory CropRegion.centered({
    required double aspectRatio,
    required double sourceAspectRatio,
  }) {
    if (aspectRatio > sourceAspectRatio) {
      // Crop top/bottom
      final height = sourceAspectRatio / aspectRatio;
      return CropRegion(
        x: 0,
        y: (1 - height) / 2,
        width: 1,
        height: height,
      );
    } else {
      // Crop left/right
      final width = aspectRatio / sourceAspectRatio;
      return CropRegion(
        x: (1 - width) / 2,
        y: 0,
        width: width,
        height: 1,
      );
    }
  }

  /// Creates a CropRegion from pixel coordinates.
  factory CropRegion.fromPixels(Rect rect, int videoWidth, int videoHeight) {
    return CropRegion(
      x: rect.left / videoWidth,
      y: rect.top / videoHeight,
      width: rect.width / videoWidth,
      height: rect.height / videoHeight,
    );
  }

  double get right => x + width;
  double get bottom => y + height;
  double get aspectRatio => width / height;

  /// Whether this represents the full frame (no cropping).
  bool get isFullFrame =>
      x == 0.0 && y == 0.0 && width == 1.0 && height == 1.0;

  /// Converts normalized coordinates to pixel coordinates as Rect.
  Rect toPixelRect(int videoWidth, int videoHeight) {
    return Rect.fromLTWH(
      x * videoWidth,
      y * videoHeight,
      width * videoWidth,
      height * videoHeight,
    );
  }

  /// Convert to pixel coordinates as tuple (x, y, width, height).
  (int, int, int, int) toPixels(int sourceWidth, int sourceHeight) {
    return (
      (x * sourceWidth).round(),
      (y * sourceHeight).round(),
      (width * sourceWidth).round(),
      (height * sourceHeight).round(),
    );
  }

  CropRegion copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return CropRegion(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  /// Converts this CropRegion to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  /// Creates a CropRegion from a JSON map.
  factory CropRegion.fromJson(Map<String, dynamic> json) {
    return CropRegion(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'CropRegion(x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, '
      'w: ${width.toStringAsFixed(3)}, h: ${height.toStringAsFixed(3)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CropRegion &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(x, y, width, height);
}

/// A clip range within a video.
///
/// Represents a segment of a video defined by start and end frames,
/// with optional caption and crop region. Multiple ClipRanges can
/// be created from a single video source.
class ClipRange {
  final VidTrainId id;
  final VidTrainId videoId;

  /// Start frame (0-indexed, inclusive)
  int startFrame;

  /// End frame (exclusive)
  int endFrame;

  /// Caption/prompt for this clip
  String caption;

  /// Optional crop region for this clip
  CropRegion? crop;

  /// Whether to use crop (allows toggling without losing crop data)
  bool useCrop;

  /// Order index for sorting ranges within a video
  final int orderIndex;

  ClipRange({
    String? id,
    required this.videoId,
    required this.startFrame,
    required this.endFrame,
    this.caption = '',
    this.crop,
    this.useCrop = false,
    this.orderIndex = 0,
  }) : id = id ?? generateVidTrainId();

  factory ClipRange.create({
    required VidTrainId videoId,
    required int startFrame,
    required int endFrame,
    String caption = '',
    CropRegion? crop,
    bool useCrop = false,
    int orderIndex = 0,
  }) {
    return ClipRange(
      videoId: videoId,
      startFrame: startFrame,
      endFrame: endFrame,
      caption: caption,
      crop: crop,
      useCrop: useCrop,
      orderIndex: orderIndex,
    );
  }

  /// Number of frames in this clip range.
  int get frameCount => endFrame - startFrame;

  /// Calculates the start time in seconds based on fps.
  double startTime(double fps) => startFrame / fps;

  /// Calculates the end time in seconds based on fps.
  double endTime(double fps) => endFrame / fps;

  /// Calculates the start time as Duration based on fps.
  Duration startDuration(double fps) =>
      Duration(microseconds: (startFrame / fps * 1000000).round());

  /// Calculates the end time as Duration based on fps.
  Duration endDuration(double fps) =>
      Duration(microseconds: (endFrame / fps * 1000000).round());

  /// Duration of this clip range based on fps.
  Duration durationAt(double fps) =>
      Duration(microseconds: ((endFrame - startFrame) / fps * 1000000).round());

  ClipRange copyWith({
    VidTrainId? id,
    VidTrainId? videoId,
    int? startFrame,
    int? endFrame,
    String? caption,
    CropRegion? crop,
    bool? useCrop,
    int? orderIndex,
  }) {
    return ClipRange(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      startFrame: startFrame ?? this.startFrame,
      endFrame: endFrame ?? this.endFrame,
      caption: caption ?? this.caption,
      crop: crop ?? this.crop,
      useCrop: useCrop ?? this.useCrop,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  /// Converts this ClipRange to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoId': videoId,
      'startFrame': startFrame,
      'endFrame': endFrame,
      'caption': caption,
      'crop': crop?.toJson(),
      'useCrop': useCrop,
      'orderIndex': orderIndex,
    };
  }

  /// Creates a ClipRange from a JSON map.
  factory ClipRange.fromJson(Map<String, dynamic> json) {
    return ClipRange(
      id: json['id'] as String?,
      videoId: json['videoId'] as String,
      startFrame: json['startFrame'] as int,
      endFrame: json['endFrame'] as int,
      caption: json['caption'] as String? ?? '',
      crop: json['crop'] != null
          ? CropRegion.fromJson(json['crop'] as Map<String, dynamic>)
          : null,
      useCrop: json['useCrop'] as bool? ?? false,
      orderIndex: json['orderIndex'] as int? ?? 0,
    );
  }

  /// Formats the frame range as a string (e.g., "0-100").
  String get frameRangeFormatted => '$startFrame-$endFrame';

  /// Formats the time range as a string based on fps (e.g., "00:00 - 00:10").
  String timeRangeFormatted(double fps) {
    final start = startDuration(fps);
    final end = endDuration(fps);
    return '${_formatDuration(start)} - ${_formatDuration(end)}';
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() => 'ClipRange($startFrame-$endFrame, "${caption.length > 20 ? '${caption.substring(0, 20)}...' : caption}")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipRange && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Model preset for training (defines resolution requirements)
class ModelPreset {
  final String id;
  final String name;
  final String description;

  /// Available resolution options for this model
  final List<ResolutionOption> resolutions;

  /// Default resolution index
  final int defaultResolutionIndex;

  /// Recommended frame count range
  final int? minFrames;
  final int? maxFrames;

  /// Recommended FPS
  final double? recommendedFps;

  const ModelPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.resolutions,
    this.defaultResolutionIndex = 0,
    this.minFrames,
    this.maxFrames,
    this.recommendedFps,
  });

  ResolutionOption get defaultResolution => resolutions[defaultResolutionIndex];

  /// Converts this ModelPreset to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'resolutions': resolutions.map((r) => r.toJson()).toList(),
      'defaultResolutionIndex': defaultResolutionIndex,
      'minFrames': minFrames,
      'maxFrames': maxFrames,
      'recommendedFps': recommendedFps,
    };
  }

  /// Creates a ModelPreset from a JSON map.
  factory ModelPreset.fromJson(Map<String, dynamic> json) {
    return ModelPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      resolutions: (json['resolutions'] as List<dynamic>)
          .map((r) => ResolutionOption.fromJson(r as Map<String, dynamic>))
          .toList(),
      defaultResolutionIndex: json['defaultResolutionIndex'] as int? ?? 0,
      minFrames: json['minFrames'] as int?,
      maxFrames: json['maxFrames'] as int?,
      recommendedFps: (json['recommendedFps'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() => 'ModelPreset($name)';
}

/// Resolution option within a model preset
class ResolutionOption {
  final int width;
  final int height;
  final String label;

  const ResolutionOption({
    required this.width,
    required this.height,
    required this.label,
  });

  double get aspectRatio => width / height;

  /// Converts this ResolutionOption to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
      'label': label,
    };
  }

  /// Creates a ResolutionOption from a JSON map.
  factory ResolutionOption.fromJson(Map<String, dynamic> json) {
    return ResolutionOption(
      width: json['width'] as int,
      height: json['height'] as int,
      label: json['label'] as String,
    );
  }

  @override
  String toString() => '$label (${width}x$height)';
}

/// Built-in model presets
class ModelPresets {
  static const hunyuan = ModelPreset(
    id: 'hunyuan',
    name: 'HunyuanVideo',
    description: 'Tencent HunyuanVideo model',
    resolutions: [
      ResolutionOption(width: 848, height: 480, label: '848x480'),
      ResolutionOption(width: 720, height: 480, label: '720x480'),
      ResolutionOption(width: 544, height: 960, label: '544x960 (Portrait)'),
      ResolutionOption(width: 960, height: 544, label: '960x544 (Landscape)'),
    ],
    defaultResolutionIndex: 0,
    minFrames: 45,
    maxFrames: 129,
    recommendedFps: 24,
  );

  static const ltxv = ModelPreset(
    id: 'ltxv',
    name: 'LTX-Video',
    description: 'Lightricks LTX-Video model',
    resolutions: [
      ResolutionOption(width: 768, height: 512, label: '768x512'),
      ResolutionOption(width: 512, height: 768, label: '512x768 (Portrait)'),
      ResolutionOption(width: 704, height: 480, label: '704x480'),
      ResolutionOption(width: 480, height: 704, label: '480x704 (Portrait)'),
    ],
    defaultResolutionIndex: 0,
    minFrames: 25,
    maxFrames: 97,
    recommendedFps: 24,
  );

  static const wan = ModelPreset(
    id: 'wan',
    name: 'Wan 2.1',
    description: 'Alibaba Wan video model',
    resolutions: [
      ResolutionOption(width: 832, height: 480, label: '832x480'),
      ResolutionOption(width: 480, height: 832, label: '480x832 (Portrait)'),
      ResolutionOption(width: 624, height: 624, label: '624x624 (Square)'),
    ],
    defaultResolutionIndex: 0,
    minFrames: 17,
    maxFrames: 81,
    recommendedFps: 16,
  );

  static const cogvideox = ModelPreset(
    id: 'cogvideox',
    name: 'CogVideoX',
    description: 'THUDM CogVideoX model',
    resolutions: [
      ResolutionOption(width: 720, height: 480, label: '720x480'),
      ResolutionOption(width: 480, height: 720, label: '480x720 (Portrait)'),
    ],
    defaultResolutionIndex: 0,
    minFrames: 49,
    maxFrames: 49,
    recommendedFps: 8,
  );

  static const custom = ModelPreset(
    id: 'custom',
    name: 'Custom',
    description: 'Custom resolution settings',
    resolutions: [
      ResolutionOption(width: 512, height: 512, label: '512x512'),
      ResolutionOption(width: 768, height: 768, label: '768x768'),
      ResolutionOption(width: 1024, height: 1024, label: '1024x1024'),
    ],
    defaultResolutionIndex: 0,
  );

  static const List<ModelPreset> all = [
    hunyuan,
    ltxv,
    wan,
    cogvideox,
    custom,
  ];

  static ModelPreset? byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}

/// Export settings for the dataset
class VidTrainExportSettings {
  /// Output directory path
  final String outputDirectory;

  /// Selected model preset ID
  final String modelPresetId;

  /// Selected resolution index within the preset
  final int resolutionIndex;

  /// Target frames per second for exported videos.
  final int targetFps;

  /// Target number of frames per clip (e.g., 21 for video training).
  final int targetFrames;

  /// Maximum size for the longest edge (width or height).
  final int maxLongestEdge;

  /// Whether to export cropped versions of clips.
  final bool exportCropped;

  /// Whether to export uncropped (original) versions.
  final bool exportUncropped;

  /// Whether to export the first frame as a still image.
  final bool exportFirstFrame;

  /// Whether to include audio in exported videos.
  final bool includeAudio;

  /// Output video format (e.g., "mp4", "webm").
  final String outputFormat;

  /// Video codec
  final String videoCodec;

  /// Video quality (CRF for x264/x265, 0-51, lower = better)
  final int videoQuality;

  /// Whether to generate caption files
  final bool generateCaptions;

  /// Caption file extension (.txt, .caption, etc)
  final String captionExtension;

  /// Trigger word for training (prepended to captions).
  final String triggerWord;

  /// Number of repeats for training weight.
  final int numRepeats;

  /// File naming pattern
  final String namingPattern;

  const VidTrainExportSettings({
    this.outputDirectory = '',
    this.modelPresetId = 'hunyuan',
    this.resolutionIndex = 0,
    this.targetFps = 24,
    this.targetFrames = 21,
    this.maxLongestEdge = 512,
    this.exportCropped = true,
    this.exportUncropped = false,
    this.exportFirstFrame = true,
    this.includeAudio = false,
    this.outputFormat = 'mp4',
    this.videoCodec = 'libx264',
    this.videoQuality = 18,
    this.generateCaptions = true,
    this.captionExtension = '.txt',
    this.triggerWord = '',
    this.numRepeats = 1,
    this.namingPattern = '{video}_{index:04d}',
  });

  /// Creates default export settings with sensible defaults.
  factory VidTrainExportSettings.defaults() {
    return const VidTrainExportSettings();
  }

  ModelPreset? get modelPreset => ModelPresets.byId(modelPresetId);

  ResolutionOption? get resolution {
    final preset = modelPreset;
    if (preset == null || resolutionIndex >= preset.resolutions.length) {
      return null;
    }
    return preset.resolutions[resolutionIndex];
  }

  /// Duration per clip based on target fps and frames.
  Duration get clipDuration =>
      Duration(milliseconds: (targetFrames / targetFps * 1000).round());

  VidTrainExportSettings copyWith({
    String? outputDirectory,
    String? modelPresetId,
    int? resolutionIndex,
    int? targetFps,
    int? targetFrames,
    int? maxLongestEdge,
    bool? exportCropped,
    bool? exportUncropped,
    bool? exportFirstFrame,
    bool? includeAudio,
    String? outputFormat,
    String? videoCodec,
    int? videoQuality,
    bool? generateCaptions,
    String? captionExtension,
    String? triggerWord,
    int? numRepeats,
    String? namingPattern,
  }) {
    return VidTrainExportSettings(
      outputDirectory: outputDirectory ?? this.outputDirectory,
      modelPresetId: modelPresetId ?? this.modelPresetId,
      resolutionIndex: resolutionIndex ?? this.resolutionIndex,
      targetFps: targetFps ?? this.targetFps,
      targetFrames: targetFrames ?? this.targetFrames,
      maxLongestEdge: maxLongestEdge ?? this.maxLongestEdge,
      exportCropped: exportCropped ?? this.exportCropped,
      exportUncropped: exportUncropped ?? this.exportUncropped,
      exportFirstFrame: exportFirstFrame ?? this.exportFirstFrame,
      includeAudio: includeAudio ?? this.includeAudio,
      outputFormat: outputFormat ?? this.outputFormat,
      videoCodec: videoCodec ?? this.videoCodec,
      videoQuality: videoQuality ?? this.videoQuality,
      generateCaptions: generateCaptions ?? this.generateCaptions,
      captionExtension: captionExtension ?? this.captionExtension,
      triggerWord: triggerWord ?? this.triggerWord,
      numRepeats: numRepeats ?? this.numRepeats,
      namingPattern: namingPattern ?? this.namingPattern,
    );
  }

  /// Converts this settings object to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'outputDirectory': outputDirectory,
      'modelPresetId': modelPresetId,
      'resolutionIndex': resolutionIndex,
      'targetFps': targetFps,
      'targetFrames': targetFrames,
      'maxLongestEdge': maxLongestEdge,
      'exportCropped': exportCropped,
      'exportUncropped': exportUncropped,
      'exportFirstFrame': exportFirstFrame,
      'includeAudio': includeAudio,
      'outputFormat': outputFormat,
      'videoCodec': videoCodec,
      'videoQuality': videoQuality,
      'generateCaptions': generateCaptions,
      'captionExtension': captionExtension,
      'triggerWord': triggerWord,
      'numRepeats': numRepeats,
      'namingPattern': namingPattern,
    };
  }

  /// Creates export settings from a JSON map.
  factory VidTrainExportSettings.fromJson(Map<String, dynamic> json) {
    return VidTrainExportSettings(
      outputDirectory: json['outputDirectory'] as String? ?? json['outputPath'] as String? ?? '',
      modelPresetId: json['modelPresetId'] as String? ?? 'hunyuan',
      resolutionIndex: json['resolutionIndex'] as int? ?? 0,
      targetFps: json['targetFps'] as int? ?? 24,
      targetFrames: json['targetFrames'] as int? ?? 21,
      maxLongestEdge: json['maxLongestEdge'] as int? ?? 512,
      exportCropped: json['exportCropped'] as bool? ?? true,
      exportUncropped: json['exportUncropped'] as bool? ?? false,
      exportFirstFrame: json['exportFirstFrame'] as bool? ?? true,
      includeAudio: json['includeAudio'] as bool? ?? false,
      outputFormat: json['outputFormat'] as String? ?? 'mp4',
      videoCodec: json['videoCodec'] as String? ?? 'libx264',
      videoQuality: json['videoQuality'] as int? ?? 18,
      generateCaptions: json['generateCaptions'] as bool? ?? true,
      captionExtension: json['captionExtension'] as String? ?? '.txt',
      triggerWord: json['triggerWord'] as String? ?? '',
      numRepeats: json['numRepeats'] as int? ?? 1,
      namingPattern: json['namingPattern'] as String? ?? '{video}_{index:04d}',
    );
  }

  @override
  String toString() => 'VidTrainExportSettings(outputDirectory: $outputDirectory, '
      'targetFps: $targetFps, targetFrames: $targetFrames, format: $outputFormat)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VidTrainExportSettings &&
          runtimeType == other.runtimeType &&
          outputDirectory == other.outputDirectory &&
          modelPresetId == other.modelPresetId &&
          resolutionIndex == other.resolutionIndex &&
          targetFps == other.targetFps &&
          targetFrames == other.targetFrames &&
          maxLongestEdge == other.maxLongestEdge &&
          exportCropped == other.exportCropped &&
          exportUncropped == other.exportUncropped &&
          exportFirstFrame == other.exportFirstFrame &&
          includeAudio == other.includeAudio &&
          outputFormat == other.outputFormat &&
          videoCodec == other.videoCodec &&
          videoQuality == other.videoQuality &&
          generateCaptions == other.generateCaptions &&
          captionExtension == other.captionExtension &&
          triggerWord == other.triggerWord &&
          numRepeats == other.numRepeats &&
          namingPattern == other.namingPattern;

  @override
  int get hashCode => Object.hash(
        outputDirectory,
        modelPresetId,
        resolutionIndex,
        targetFps,
        targetFrames,
        maxLongestEdge,
        exportCropped,
        exportUncropped,
        exportFirstFrame,
        includeAudio,
        outputFormat,
        videoCodec,
        videoQuality,
        generateCaptions,
        captionExtension,
        triggerWord,
        numRepeats,
        namingPattern,
      );
}

/// Complete project state for video training preparation.
///
/// Contains all videos, clip ranges, settings, and metadata for
/// a video training preparation project. Supports full JSON
/// serialization for persistence.
class VidTrainProject {
  final VidTrainId id;
  String name;
  final List<VideoSource> videos;

  /// Map of video ID -> list of clip ranges
  final Map<VidTrainId, List<ClipRange>> rangesByVideo;

  /// Currently selected model preset name (optional).
  String? selectedModelPreset;

  /// Index of the selected resolution option.
  int selectedResolutionIndex;

  /// Export settings
  VidTrainExportSettings exportSettings;

  /// Project creation timestamp
  final DateTime createdAt;

  /// Last modified timestamp
  DateTime lastModified;

  VidTrainProject({
    String? id,
    this.name = 'Untitled Project',
    List<VideoSource>? videos,
    Map<VidTrainId, List<ClipRange>>? rangesByVideo,
    this.selectedModelPreset,
    this.selectedResolutionIndex = 0,
    VidTrainExportSettings? exportSettings,
    DateTime? createdAt,
    DateTime? lastModified,
  })  : id = id ?? generateVidTrainId(),
        videos = videos ?? [],
        rangesByVideo = rangesByVideo ?? {},
        exportSettings = exportSettings ?? const VidTrainExportSettings(),
        createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now();

  factory VidTrainProject.create({String name = 'New Project'}) {
    final now = DateTime.now();
    return VidTrainProject(
      name: name,
      createdAt: now,
      lastModified: now,
    );
  }

  /// Creates an empty project with default settings.
  factory VidTrainProject.empty() {
    return VidTrainProject();
  }

  /// Get all ranges for a video
  List<ClipRange> rangesFor(VidTrainId videoId) => rangesByVideo[videoId] ?? [];

  /// Alias for rangesFor for API compatibility
  List<ClipRange> getRangesForVideo(String videoId) => rangesFor(videoId);

  /// Get total clip count across all videos
  int get totalRangeCount {
    int count = 0;
    for (final ranges in rangesByVideo.values) {
      count += ranges.length;
    }
    return count;
  }

  /// Alias for totalRangeCount
  int get totalClipRanges => totalRangeCount;

  /// Total number of videos.
  int get videoCount => videos.length;

  /// Get video by ID
  VideoSource? videoById(VidTrainId id) {
    for (final video in videos) {
      if (video.id == id) return video;
    }
    return null;
  }

  /// Alias for videoById
  VideoSource? getVideoById(String videoId) => videoById(videoId);

  VidTrainProject copyWith({
    VidTrainId? id,
    String? name,
    List<VideoSource>? videos,
    Map<VidTrainId, List<ClipRange>>? rangesByVideo,
    String? selectedModelPreset,
    int? selectedResolutionIndex,
    VidTrainExportSettings? exportSettings,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return VidTrainProject(
      id: id ?? this.id,
      name: name ?? this.name,
      videos: videos ?? List.from(this.videos),
      rangesByVideo: rangesByVideo ??
          Map.fromEntries(
            this.rangesByVideo.entries.map(
              (e) => MapEntry(e.key, List<ClipRange>.from(e.value)),
            ),
          ),
      selectedModelPreset: selectedModelPreset ?? this.selectedModelPreset,
      selectedResolutionIndex: selectedResolutionIndex ?? this.selectedResolutionIndex,
      exportSettings: exportSettings ?? this.exportSettings,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? DateTime.now(),
    );
  }

  /// Converts this project to a JSON map for persistence.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'videos': videos.map((v) => v.toJson()).toList(),
      'rangesByVideo': rangesByVideo.map(
        (key, value) => MapEntry(key, value.map((r) => r.toJson()).toList()),
      ),
      'selectedModelPreset': selectedModelPreset,
      'selectedResolutionIndex': selectedResolutionIndex,
      'exportSettings': exportSettings.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
    };
  }

  /// Creates a VidTrainProject from a JSON map.
  factory VidTrainProject.fromJson(Map<String, dynamic> json) {
    final rangesMap = json['rangesByVideo'] as Map<String, dynamic>? ?? {};
    return VidTrainProject(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Untitled Project',
      videos: (json['videos'] as List<dynamic>?)
              ?.map((v) => VideoSource.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      rangesByVideo: rangesMap.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>)
              .map((r) => ClipRange.fromJson(r as Map<String, dynamic>))
              .toList(),
        ),
      ),
      selectedModelPreset: json['selectedModelPreset'] as String?,
      selectedResolutionIndex: json['selectedResolutionIndex'] as int? ?? 0,
      exportSettings: json['exportSettings'] != null
          ? VidTrainExportSettings.fromJson(
              json['exportSettings'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : json['modifiedAt'] != null
              ? DateTime.parse(json['modifiedAt'] as String)
              : null,
    );
  }

  @override
  String toString() => 'VidTrainProject($name, ${videos.length} videos, $totalRangeCount ranges)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VidTrainProject && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
