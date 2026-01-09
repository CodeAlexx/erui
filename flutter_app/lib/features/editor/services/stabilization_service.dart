import 'dart:async';
import 'dart:io';

import 'ffmpeg_service.dart';

/// Stabilization settings
class StabilizationSettings {
  /// Shakiness of the source video (1-10, higher = more shaky)
  final int shakiness;

  /// Accuracy of detection (1-15, higher = more accurate but slower)
  final int accuracy;

  /// Step size for detection (1-6, larger = faster but less precise)
  final int stepSize;

  /// Smoothing strength (0-100, higher = smoother but more cropping)
  final int smoothing;

  /// Maximum shift in pixels (0-disabled)
  final int maxShift;

  /// Maximum angle in degrees (0-disabled)
  final double maxAngle;

  /// Crop mode for handling borders
  final StabilizationCrop crop;

  /// Zoom amount to hide black borders (0-100%)
  final int zoom;

  /// Optimal zoom (0=off, 1=static, 2=adaptive)
  final int optZoom;

  /// Zoom speed for adaptive zoom (0-5)
  final double zoomSpeed;

  /// Interpolation type
  final StabilizationInterpolation interpolation;

  const StabilizationSettings({
    this.shakiness = 5,
    this.accuracy = 15,
    this.stepSize = 1,
    this.smoothing = 10,
    this.maxShift = 0,
    this.maxAngle = 0,
    this.crop = StabilizationCrop.black,
    this.zoom = 0,
    this.optZoom = 1,
    this.zoomSpeed = 0.25,
    this.interpolation = StabilizationInterpolation.bilinear,
  });

  StabilizationSettings copyWith({
    int? shakiness,
    int? accuracy,
    int? stepSize,
    int? smoothing,
    int? maxShift,
    double? maxAngle,
    StabilizationCrop? crop,
    int? zoom,
    int? optZoom,
    double? zoomSpeed,
    StabilizationInterpolation? interpolation,
  }) {
    return StabilizationSettings(
      shakiness: shakiness ?? this.shakiness,
      accuracy: accuracy ?? this.accuracy,
      stepSize: stepSize ?? this.stepSize,
      smoothing: smoothing ?? this.smoothing,
      maxShift: maxShift ?? this.maxShift,
      maxAngle: maxAngle ?? this.maxAngle,
      crop: crop ?? this.crop,
      zoom: zoom ?? this.zoom,
      optZoom: optZoom ?? this.optZoom,
      zoomSpeed: zoomSpeed ?? this.zoomSpeed,
      interpolation: interpolation ?? this.interpolation,
    );
  }
}

/// Crop modes for stabilization
enum StabilizationCrop {
  /// Fill with black
  black,

  /// Keep original size (some motion visible at edges)
  keep,
}

extension StabilizationCropExtension on StabilizationCrop {
  String get ffmpegValue {
    switch (this) {
      case StabilizationCrop.black:
        return 'black';
      case StabilizationCrop.keep:
        return 'keep';
    }
  }
}

/// Interpolation modes for stabilization
enum StabilizationInterpolation {
  nearest,
  bilinear,
  bicubic,
}

extension StabilizationInterpolationExtension on StabilizationInterpolation {
  String get displayName {
    switch (this) {
      case StabilizationInterpolation.nearest:
        return 'Nearest (Fast)';
      case StabilizationInterpolation.bilinear:
        return 'Bilinear';
      case StabilizationInterpolation.bicubic:
        return 'Bicubic (Best)';
    }
  }

  String get ffmpegValue {
    switch (this) {
      case StabilizationInterpolation.nearest:
        return 'no';
      case StabilizationInterpolation.bilinear:
        return 'bilinear';
      case StabilizationInterpolation.bicubic:
        return 'bicubic';
    }
  }
}

/// Result of stabilization analysis
class StabilizationAnalysis {
  final String transformFile;
  final double averageMotion;
  final double maxMotion;
  final Duration analyzeDuration;

  const StabilizationAnalysis({
    required this.transformFile,
    required this.averageMotion,
    required this.maxMotion,
    required this.analyzeDuration,
  });
}

/// Service for video stabilization using FFmpeg vidstab
class StabilizationService {
  final FFmpegService _ffmpeg;
  final String _tempDir;

  StabilizationService({
    FFmpegService? ffmpeg,
    String? tempDir,
  })  : _ffmpeg = ffmpeg ?? FFmpegService(),
        _tempDir = tempDir ?? Directory.systemTemp.path;

  /// Analyze video motion (first pass of vidstab)
  Future<StabilizationAnalysis> analyzeMotion(
    String inputPath,
    StabilizationSettings settings, {
    Function(double progress)? onProgress,
  }) async {
    final transformFile = '$_tempDir/transforms_${DateTime.now().millisecondsSinceEpoch}.trf';
    final startTime = DateTime.now();

    // Build vidstabdetect filter
    final detectFilter = _buildDetectFilter(settings, transformFile);

    final command = [
      '-i', inputPath,
      '-vf', detectFilter,
      '-f', 'null',
      '-',
    ];

    await _ffmpeg.executeCommand(
      command,
      onProgress: onProgress,
    );

    final duration = DateTime.now().difference(startTime);

    // Parse transform file for motion stats
    final stats = await _parseTransformFile(transformFile);

    return StabilizationAnalysis(
      transformFile: transformFile,
      averageMotion: stats['average'] ?? 0.0,
      maxMotion: stats['max'] ?? 0.0,
      analyzeDuration: duration,
    );
  }

  /// Apply stabilization (second pass of vidstab)
  Future<String> applyStabilization(
    String inputPath,
    String outputPath,
    StabilizationAnalysis analysis,
    StabilizationSettings settings, {
    Function(double progress)? onProgress,
  }) async {
    // Build vidstabtransform filter
    final transformFilter = _buildTransformFilter(settings, analysis.transformFile);

    final command = [
      '-i', inputPath,
      '-vf', transformFilter,
      '-c:a', 'copy',
      '-y',
      outputPath,
    ];

    await _ffmpeg.executeCommand(
      command,
      onProgress: onProgress,
    );

    return outputPath;
  }

  /// Perform full stabilization (analyze + apply)
  Future<String> stabilize(
    String inputPath,
    String outputPath,
    StabilizationSettings settings, {
    Function(String stage, double progress)? onProgress,
  }) async {
    // Pass 1: Analyze
    onProgress?.call('Analyzing motion', 0.0);
    final analysis = await analyzeMotion(
      inputPath,
      settings,
      onProgress: (p) => onProgress?.call('Analyzing motion', p * 0.5),
    );

    // Pass 2: Transform
    onProgress?.call('Applying stabilization', 0.5);
    final result = await applyStabilization(
      inputPath,
      outputPath,
      analysis,
      settings,
      onProgress: (p) => onProgress?.call('Applying stabilization', 0.5 + p * 0.5),
    );

    // Cleanup transform file
    try {
      await File(analysis.transformFile).delete();
    } catch (_) {}

    return result;
  }

  /// Generate preview of stabilization (shorter clip)
  Future<String> generatePreview(
    String inputPath,
    String outputPath,
    StabilizationSettings settings, {
    double startSeconds = 0,
    double durationSeconds = 5,
    Function(double progress)? onProgress,
  }) async {
    // Extract preview segment first
    final previewInput = '$_tempDir/stab_preview_input.mp4';

    final extractCommand = [
      '-ss', startSeconds.toString(),
      '-i', inputPath,
      '-t', durationSeconds.toString(),
      '-c', 'copy',
      '-y',
      previewInput,
    ];

    await _ffmpeg.executeCommand(extractCommand);

    // Stabilize the preview
    final result = await stabilize(
      previewInput,
      outputPath,
      settings,
      onProgress: (stage, p) => onProgress?.call(p),
    );

    // Cleanup
    try {
      await File(previewInput).delete();
    } catch (_) {}

    return result;
  }

  /// Build vidstabdetect filter string
  String _buildDetectFilter(StabilizationSettings settings, String resultPath) {
    final parts = <String>[
      'vidstabdetect=',
      'shakiness=${settings.shakiness}',
      ':accuracy=${settings.accuracy}',
      ':stepsize=${settings.stepSize}',
      ':result=$resultPath',
    ];

    if (settings.maxShift > 0) {
      parts.add(':mincontrast=0.3');
    }

    return parts.join('');
  }

  /// Build vidstabtransform filter string
  String _buildTransformFilter(StabilizationSettings settings, String inputPath) {
    final parts = <String>[
      'vidstabtransform=',
      'input=$inputPath',
      ':smoothing=${settings.smoothing}',
      ':crop=${settings.crop.ffmpegValue}',
      ':zoom=${settings.zoom}',
      ':optzoom=${settings.optZoom}',
      ':zoomspeed=${settings.zoomSpeed}',
      ':interpol=${settings.interpolation.ffmpegValue}',
    ];

    if (settings.maxShift > 0) {
      parts.add(':maxshift=${settings.maxShift}');
    }

    if (settings.maxAngle > 0) {
      parts.add(':maxangle=${settings.maxAngle}');
    }

    return parts.join('');
  }

  /// Parse transform file for motion statistics
  Future<Map<String, double>> _parseTransformFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return {'average': 0.0, 'max': 0.0};
      }

      final content = await file.readAsString();
      final lines = content.split('\n').where((l) => !l.startsWith('#')).toList();

      if (lines.isEmpty) {
        return {'average': 0.0, 'max': 0.0};
      }

      double totalMotion = 0;
      double maxMotion = 0;
      int count = 0;

      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          final dx = double.tryParse(parts[1]) ?? 0;
          final dy = double.tryParse(parts[2]) ?? 0;
          final motion = (dx * dx + dy * dy).abs();

          totalMotion += motion;
          if (motion > maxMotion) maxMotion = motion;
          count++;
        }
      }

      return {
        'average': count > 0 ? totalMotion / count : 0.0,
        'max': maxMotion,
      };
    } catch (e) {
      return {'average': 0.0, 'max': 0.0};
    }
  }
}

/// Preset stabilization configurations
class StabilizationPreset {
  final String id;
  final String name;
  final String description;
  final StabilizationSettings settings;

  const StabilizationPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.settings,
  });

  static const List<StabilizationPreset> presets = [
    StabilizationPreset(
      id: 'light',
      name: 'Light Stabilization',
      description: 'For slightly shaky footage, minimal cropping',
      settings: StabilizationSettings(
        shakiness: 3,
        smoothing: 5,
        zoom: 0,
        optZoom: 1,
      ),
    ),
    StabilizationPreset(
      id: 'standard',
      name: 'Standard',
      description: 'Balanced stabilization for handheld footage',
      settings: StabilizationSettings(
        shakiness: 5,
        smoothing: 10,
        zoom: 0,
        optZoom: 1,
      ),
    ),
    StabilizationPreset(
      id: 'strong',
      name: 'Strong',
      description: 'For very shaky footage, more cropping',
      settings: StabilizationSettings(
        shakiness: 8,
        smoothing: 20,
        zoom: 5,
        optZoom: 2,
      ),
    ),
    StabilizationPreset(
      id: 'tripod',
      name: 'Tripod Lock',
      description: 'Makes footage appear tripod-mounted',
      settings: StabilizationSettings(
        shakiness: 10,
        smoothing: 50,
        zoom: 10,
        optZoom: 2,
        zoomSpeed: 0.1,
      ),
    ),
    StabilizationPreset(
      id: 'action',
      name: 'Action Cam',
      description: 'For GoPro and action camera footage',
      settings: StabilizationSettings(
        shakiness: 7,
        smoothing: 15,
        zoom: 5,
        optZoom: 2,
        interpolation: StabilizationInterpolation.bicubic,
      ),
    ),
  ];
}
