import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_full/statistics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../models/editor_models.dart';
import 'ffmpeg_service.dart';

/// Frame extractor provider
final frameExtractorProvider = Provider<FrameExtractor>((ref) {
  final ffmpegService = ref.watch(ffmpegServiceProvider);
  return FrameExtractor(ffmpegService: ffmpegService);
});

/// Extraction mode for frame extraction
enum ExtractionMode {
  /// Extract frames at regular time intervals
  interval,

  /// Extract keyframes based on scene changes
  keyframe,

  /// Extract a specific number of frames evenly distributed
  count,

  /// Manual extraction at specific timestamps
  manual,
}

/// Output format for extracted frames
enum FrameOutputFormat {
  /// PNG format (lossless, larger files)
  png,

  /// JPEG format (lossy, smaller files)
  jpg,
}

/// Output size presets for extracted frames
enum FrameOutputSize {
  /// Original video resolution
  original,

  /// 512x512 (or scaled to fit)
  size512,

  /// 768x768 (or scaled to fit)
  size768,

  /// 1024x1024 (or scaled to fit)
  size1024,
}

/// Settings for frame extraction operations
class FrameExtractionSettings {
  /// The extraction mode to use
  final ExtractionMode extractionMode;

  /// Interval between frames (for interval mode)
  final Duration interval;

  /// Total number of frames to extract (for count mode)
  final int frameCount;

  /// Output format for extracted frames
  final FrameOutputFormat outputFormat;

  /// Output size for extracted frames
  final FrameOutputSize outputSize;

  /// Custom output dimensions (overrides outputSize if both set)
  final int? customWidth;
  final int? customHeight;

  /// Output directory path for extracted frames
  final String outputPath;

  /// Prefix for output filenames
  final String filenamePrefix;

  /// Scene change threshold for keyframe extraction (0.0 to 1.0)
  final double sceneChangeThreshold;

  /// Quality setting for JPEG output (1-31, lower is better)
  final int jpegQuality;

  const FrameExtractionSettings({
    this.extractionMode = ExtractionMode.interval,
    this.interval = const Duration(seconds: 1),
    this.frameCount = 10,
    this.outputFormat = FrameOutputFormat.png,
    this.outputSize = FrameOutputSize.original,
    this.customWidth,
    this.customHeight,
    required this.outputPath,
    this.filenamePrefix = 'frame',
    this.sceneChangeThreshold = 0.3,
    this.jpegQuality = 2,
  });

  /// Get the file extension based on output format
  String get fileExtension =>
      outputFormat == FrameOutputFormat.png ? 'png' : 'jpg';

  /// Get the output dimensions based on size preset
  (int?, int?) getOutputDimensions() {
    if (customWidth != null && customHeight != null) {
      return (customWidth, customHeight);
    }

    switch (outputSize) {
      case FrameOutputSize.original:
        return (null, null);
      case FrameOutputSize.size512:
        return (512, 512);
      case FrameOutputSize.size768:
        return (768, 768);
      case FrameOutputSize.size1024:
        return (1024, 1024);
    }
  }

  /// Create a copy with modified properties
  FrameExtractionSettings copyWith({
    ExtractionMode? extractionMode,
    Duration? interval,
    int? frameCount,
    FrameOutputFormat? outputFormat,
    FrameOutputSize? outputSize,
    int? customWidth,
    int? customHeight,
    String? outputPath,
    String? filenamePrefix,
    double? sceneChangeThreshold,
    int? jpegQuality,
  }) {
    return FrameExtractionSettings(
      extractionMode: extractionMode ?? this.extractionMode,
      interval: interval ?? this.interval,
      frameCount: frameCount ?? this.frameCount,
      outputFormat: outputFormat ?? this.outputFormat,
      outputSize: outputSize ?? this.outputSize,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      outputPath: outputPath ?? this.outputPath,
      filenamePrefix: filenamePrefix ?? this.filenamePrefix,
      sceneChangeThreshold: sceneChangeThreshold ?? this.sceneChangeThreshold,
      jpegQuality: jpegQuality ?? this.jpegQuality,
    );
  }
}

/// Result of a frame extraction operation
class FrameExtractionResult {
  /// List of paths to extracted frame files
  final List<String> framePaths;

  /// Total number of frames extracted
  final int frameCount;

  /// Duration of the extraction operation
  final Duration extractionTime;

  /// Whether the extraction was successful
  final bool success;

  /// Error message if extraction failed
  final String? errorMessage;

  const FrameExtractionResult({
    required this.framePaths,
    required this.frameCount,
    required this.extractionTime,
    required this.success,
    this.errorMessage,
  });

  /// Create a failed result
  factory FrameExtractionResult.failed(String error, Duration extractionTime) {
    return FrameExtractionResult(
      framePaths: [],
      frameCount: 0,
      extractionTime: extractionTime,
      success: false,
      errorMessage: error,
    );
  }

  /// Create a successful result
  factory FrameExtractionResult.success(
    List<String> paths,
    Duration extractionTime,
  ) {
    return FrameExtractionResult(
      framePaths: paths,
      frameCount: paths.length,
      extractionTime: extractionTime,
      success: true,
    );
  }
}

/// Progress callback for frame extraction
typedef FrameExtractionProgressCallback = void Function(
  int currentFrame,
  int totalFrames,
  double progress,
);

/// Service for extracting training frames from video clips
class FrameExtractor {
  static const String _tag = 'FrameExtractor';

  /// Reference to FFmpeg service for media info
  final FFmpegService ffmpegService;

  FrameExtractor({required this.ffmpegService});

  /// Log a debug message
  void _log(String message) {
    print('[$_tag] $message');
  }

  /// Log an error message
  void _logError(String message, [Object? error]) {
    print('[$_tag] ERROR: $message${error != null ? ' - $error' : ''}');
  }

  /// Extract frames from a video clip based on settings
  ///
  /// Returns a [FrameExtractionResult] containing paths to extracted frames.
  /// Progress can be tracked via the optional [onProgress] callback.
  Future<FrameExtractionResult> extractFrames(
    EditorClip clip,
    FrameExtractionSettings settings, {
    FrameExtractionProgressCallback? onProgress,
  }) async {
    final startTime = DateTime.now();
    _log('Starting frame extraction for clip: ${clip.name}');

    if (clip.sourcePath == null) {
      return FrameExtractionResult.failed(
        'Clip has no source path',
        DateTime.now().difference(startTime),
      );
    }

    // Ensure output directory exists
    final outputDir = Directory(settings.outputPath);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    try {
      switch (settings.extractionMode) {
        case ExtractionMode.interval:
          return await _extractAtIntervals(
            clip,
            settings,
            onProgress: onProgress,
          );
        case ExtractionMode.keyframe:
          return await _extractKeyframes(
            clip,
            settings,
            onProgress: onProgress,
          );
        case ExtractionMode.count:
          return await _extractByCount(
            clip,
            settings,
            onProgress: onProgress,
          );
        case ExtractionMode.manual:
          // Manual mode requires explicit timestamps, return empty result
          return FrameExtractionResult.failed(
            'Manual mode requires explicit timestamps via extractAtTimestamps()',
            DateTime.now().difference(startTime),
          );
      }
    } catch (e) {
      _logError('Frame extraction failed', e);
      return FrameExtractionResult.failed(
        e.toString(),
        DateTime.now().difference(startTime),
      );
    }
  }

  /// Extract keyframes based on scene changes
  ///
  /// Uses FFmpeg's scene detection to find frames with significant visual changes.
  Future<FrameExtractionResult> extractKeyframes(
    EditorClip clip, {
    double sceneChangeThreshold = 0.3,
    String? outputPath,
    FrameOutputFormat outputFormat = FrameOutputFormat.png,
    FrameOutputSize outputSize = FrameOutputSize.original,
    FrameExtractionProgressCallback? onProgress,
  }) async {
    final settings = FrameExtractionSettings(
      extractionMode: ExtractionMode.keyframe,
      sceneChangeThreshold: sceneChangeThreshold,
      outputPath: outputPath ?? Directory.systemTemp.path,
      outputFormat: outputFormat,
      outputSize: outputSize,
    );

    return _extractKeyframes(clip, settings, onProgress: onProgress);
  }

  /// Extract frames at regular time intervals
  ///
  /// Extracts a frame every [interval] duration throughout the clip.
  Future<FrameExtractionResult> extractAtIntervals(
    EditorClip clip,
    Duration interval, {
    String? outputPath,
    FrameOutputFormat outputFormat = FrameOutputFormat.png,
    FrameOutputSize outputSize = FrameOutputSize.original,
    FrameExtractionProgressCallback? onProgress,
  }) async {
    final settings = FrameExtractionSettings(
      extractionMode: ExtractionMode.interval,
      interval: interval,
      outputPath: outputPath ?? Directory.systemTemp.path,
      outputFormat: outputFormat,
      outputSize: outputSize,
    );

    return _extractAtIntervals(clip, settings, onProgress: onProgress);
  }

  /// Extract N frames evenly distributed within a specified range
  ///
  /// Extracts [count] frames between [inPoint] and [outPoint].
  Future<FrameExtractionResult> extractInOutRange(
    EditorClip clip,
    EditorTime inPoint,
    EditorTime outPoint,
    int count, {
    String? outputPath,
    FrameOutputFormat outputFormat = FrameOutputFormat.png,
    FrameOutputSize outputSize = FrameOutputSize.original,
    FrameExtractionProgressCallback? onProgress,
  }) async {
    final startTime = DateTime.now();
    _log(
        'Extracting $count frames from range ${inPoint.inSeconds}s to ${outPoint.inSeconds}s');

    if (clip.sourcePath == null) {
      return FrameExtractionResult.failed(
        'Clip has no source path',
        DateTime.now().difference(startTime),
      );
    }

    if (count <= 0) {
      return FrameExtractionResult.failed(
        'Frame count must be positive',
        DateTime.now().difference(startTime),
      );
    }

    if (inPoint >= outPoint) {
      return FrameExtractionResult.failed(
        'In point must be before out point',
        DateTime.now().difference(startTime),
      );
    }

    final outDir = outputPath ?? Directory.systemTemp.path;
    final outputDir = Directory(outDir);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final rangeDuration = outPoint - inPoint;
    final intervalMicros =
        count > 1 ? rangeDuration.microseconds ~/ (count - 1) : 0;

    final extractedPaths = <String>[];
    final (targetWidth, targetHeight) =
        _getOutputDimensions(outputSize, null, null);

    for (int i = 0; i < count; i++) {
      // Calculate timestamp within range
      EditorTime timestamp;
      if (count == 1) {
        timestamp = inPoint;
      } else {
        timestamp = EditorTime(inPoint.microseconds + (intervalMicros * i));
      }

      // Generate unique filename
      final filename = _generateFilename(
        prefix: 'range',
        index: i,
        timestamp: timestamp,
        format: outputFormat,
      );
      final outputFilePath = path.join(outDir, filename);

      // Extract the frame
      final success = await _extractSingleFrame(
        clip.sourcePath!,
        timestamp,
        outputFilePath,
        format: outputFormat,
        width: targetWidth,
        height: targetHeight,
      );

      if (success) {
        extractedPaths.add(outputFilePath);
      }

      onProgress?.call(i + 1, count, (i + 1) / count);
    }

    final extractionTime = DateTime.now().difference(startTime);
    _log('Extracted ${extractedPaths.length} frames in ${extractionTime.inMilliseconds}ms');

    if (extractedPaths.isEmpty) {
      return FrameExtractionResult.failed(
        'No frames could be extracted',
        extractionTime,
      );
    }

    return FrameExtractionResult.success(extractedPaths, extractionTime);
  }

  /// Extract frames at specific timestamps
  ///
  /// Extracts frames at each timestamp in [timestamps].
  Future<FrameExtractionResult> extractAtTimestamps(
    EditorClip clip,
    List<EditorTime> timestamps, {
    String? outputPath,
    FrameOutputFormat outputFormat = FrameOutputFormat.png,
    FrameOutputSize outputSize = FrameOutputSize.original,
    FrameExtractionProgressCallback? onProgress,
  }) async {
    final startTime = DateTime.now();
    _log('Extracting ${timestamps.length} frames at specific timestamps');

    if (clip.sourcePath == null) {
      return FrameExtractionResult.failed(
        'Clip has no source path',
        DateTime.now().difference(startTime),
      );
    }

    if (timestamps.isEmpty) {
      return FrameExtractionResult.failed(
        'No timestamps provided',
        DateTime.now().difference(startTime),
      );
    }

    final outDir = outputPath ?? Directory.systemTemp.path;
    final outputDir = Directory(outDir);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final extractedPaths = <String>[];
    final (targetWidth, targetHeight) =
        _getOutputDimensions(outputSize, null, null);
    final totalFrames = timestamps.length;

    for (int i = 0; i < timestamps.length; i++) {
      final timestamp = timestamps[i];

      // Generate unique filename
      final filename = _generateFilename(
        prefix: 'manual',
        index: i,
        timestamp: timestamp,
        format: outputFormat,
      );
      final outputFilePath = path.join(outDir, filename);

      // Extract the frame
      final success = await _extractSingleFrame(
        clip.sourcePath!,
        timestamp,
        outputFilePath,
        format: outputFormat,
        width: targetWidth,
        height: targetHeight,
      );

      if (success) {
        extractedPaths.add(outputFilePath);
      }

      onProgress?.call(i + 1, totalFrames, (i + 1) / totalFrames);
    }

    final extractionTime = DateTime.now().difference(startTime);
    _log('Extracted ${extractedPaths.length} frames in ${extractionTime.inMilliseconds}ms');

    if (extractedPaths.isEmpty) {
      return FrameExtractionResult.failed(
        'No frames could be extracted',
        extractionTime,
      );
    }

    return FrameExtractionResult.success(extractedPaths, extractionTime);
  }

  // ============================================================
  // Private Implementation Methods
  // ============================================================

  /// Extract frames at regular intervals
  Future<FrameExtractionResult> _extractAtIntervals(
    EditorClip clip,
    FrameExtractionSettings settings, {
    FrameExtractionProgressCallback? onProgress,
  }) async {
    final startTime = DateTime.now();
    _log('Extracting frames at ${settings.interval.inMilliseconds}ms intervals');

    // Get clip duration
    final durationMicros = clip.duration.microseconds;
    final intervalMicros = settings.interval.inMicroseconds;

    if (intervalMicros <= 0) {
      return FrameExtractionResult.failed(
        'Interval must be positive',
        DateTime.now().difference(startTime),
      );
    }

    // Calculate number of frames to extract
    final totalFrames = (durationMicros / intervalMicros).ceil();

    final extractedPaths = <String>[];
    final (targetWidth, targetHeight) = settings.getOutputDimensions();

    for (int i = 0; i < totalFrames; i++) {
      final timestamp =
          EditorTime(clip.sourceStart.microseconds + (intervalMicros * i));

      // Check if we're still within the clip
      if (timestamp.microseconds >
          clip.sourceStart.microseconds + durationMicros) {
        break;
      }

      // Generate unique filename
      final filename = _generateFilename(
        prefix: settings.filenamePrefix,
        index: i,
        timestamp: timestamp,
        format: settings.outputFormat,
      );
      final outputFilePath = path.join(settings.outputPath, filename);

      // Extract the frame
      final success = await _extractSingleFrame(
        clip.sourcePath!,
        timestamp,
        outputFilePath,
        format: settings.outputFormat,
        width: targetWidth,
        height: targetHeight,
        quality: settings.jpegQuality,
      );

      if (success) {
        extractedPaths.add(outputFilePath);
      }

      onProgress?.call(i + 1, totalFrames, (i + 1) / totalFrames);
    }

    final extractionTime = DateTime.now().difference(startTime);
    _log('Extracted ${extractedPaths.length} frames in ${extractionTime.inMilliseconds}ms');

    if (extractedPaths.isEmpty) {
      return FrameExtractionResult.failed(
        'No frames could be extracted',
        extractionTime,
      );
    }

    return FrameExtractionResult.success(extractedPaths, extractionTime);
  }

  /// Extract keyframes using scene change detection
  Future<FrameExtractionResult> _extractKeyframes(
    EditorClip clip,
    FrameExtractionSettings settings, {
    FrameExtractionProgressCallback? onProgress,
  }) async {
    final startTime = DateTime.now();
    _log('Extracting keyframes with threshold ${settings.sceneChangeThreshold}');

    if (clip.sourcePath == null) {
      return FrameExtractionResult.failed(
        'Clip has no source path',
        DateTime.now().difference(startTime),
      );
    }

    final (targetWidth, targetHeight) = settings.getOutputDimensions();

    // Build the scale filter
    String scaleFilter = '';
    if (targetWidth != null && targetHeight != null) {
      scaleFilter =
          ',scale=$targetWidth:$targetHeight:force_original_aspect_ratio=decrease';
    }

    // Use FFmpeg's scene detection to extract keyframes
    final outputPattern = path.join(
      settings.outputPath,
      '${settings.filenamePrefix}_%04d.${settings.fileExtension}',
    );

    // Build FFmpeg command for keyframe extraction
    final threshold = settings.sceneChangeThreshold;
    final startSec = clip.sourceStart.inSeconds;
    final durationSec = clip.duration.inSeconds;

    final formatOption = settings.outputFormat == FrameOutputFormat.png
        ? '-f image2'
        : '-q:v ${settings.jpegQuality}';

    final command = '-ss $startSec -t $durationSec '
        '-i "${clip.sourcePath}" '
        '-vf "select=\'gt(scene,$threshold)\'$scaleFilter" '
        '-vsync vfr $formatOption '
        '-y "$outputPattern"';

    _log('Running keyframe extraction: $command');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      _logError('Keyframe extraction failed', logs);
      return FrameExtractionResult.failed(
        'FFmpeg keyframe extraction failed',
        DateTime.now().difference(startTime),
      );
    }

    // Find all extracted frames
    final extractedPaths = await _findExtractedFrames(
      settings.outputPath,
      settings.filenamePrefix,
      settings.fileExtension,
    );

    final extractionTime = DateTime.now().difference(startTime);
    _log('Extracted ${extractedPaths.length} keyframes in ${extractionTime.inMilliseconds}ms');

    if (extractedPaths.isEmpty) {
      // If no keyframes found, try extracting at least the first frame
      _log('No keyframes detected, extracting first frame as fallback');
      final fallbackPath = path.join(
        settings.outputPath,
        '${settings.filenamePrefix}_0000.${settings.fileExtension}',
      );
      final success = await _extractSingleFrame(
        clip.sourcePath!,
        clip.sourceStart,
        fallbackPath,
        format: settings.outputFormat,
        width: targetWidth,
        height: targetHeight,
      );
      if (success) {
        return FrameExtractionResult.success([fallbackPath], extractionTime);
      }
      return FrameExtractionResult.failed(
        'No keyframes could be extracted',
        extractionTime,
      );
    }

    onProgress?.call(
        extractedPaths.length, extractedPaths.length, 1.0);

    return FrameExtractionResult.success(extractedPaths, extractionTime);
  }

  /// Extract a specific number of frames evenly distributed
  Future<FrameExtractionResult> _extractByCount(
    EditorClip clip,
    FrameExtractionSettings settings, {
    FrameExtractionProgressCallback? onProgress,
  }) async {
    final startTime = DateTime.now();
    final count = settings.frameCount;
    _log('Extracting $count frames evenly distributed');

    if (count <= 0) {
      return FrameExtractionResult.failed(
        'Frame count must be positive',
        DateTime.now().difference(startTime),
      );
    }

    final durationMicros = clip.duration.microseconds;
    final intervalMicros = count > 1 ? durationMicros ~/ (count - 1) : 0;

    final extractedPaths = <String>[];
    final (targetWidth, targetHeight) = settings.getOutputDimensions();

    for (int i = 0; i < count; i++) {
      // Calculate timestamp
      EditorTime timestamp;
      if (count == 1) {
        // Single frame: take from the middle
        timestamp =
            EditorTime(clip.sourceStart.microseconds + (durationMicros ~/ 2));
      } else {
        timestamp =
            EditorTime(clip.sourceStart.microseconds + (intervalMicros * i));
      }

      // Generate unique filename
      final filename = _generateFilename(
        prefix: settings.filenamePrefix,
        index: i,
        timestamp: timestamp,
        format: settings.outputFormat,
      );
      final outputFilePath = path.join(settings.outputPath, filename);

      // Extract the frame
      final success = await _extractSingleFrame(
        clip.sourcePath!,
        timestamp,
        outputFilePath,
        format: settings.outputFormat,
        width: targetWidth,
        height: targetHeight,
        quality: settings.jpegQuality,
      );

      if (success) {
        extractedPaths.add(outputFilePath);
      }

      onProgress?.call(i + 1, count, (i + 1) / count);
    }

    final extractionTime = DateTime.now().difference(startTime);
    _log('Extracted ${extractedPaths.length} frames in ${extractionTime.inMilliseconds}ms');

    if (extractedPaths.isEmpty) {
      return FrameExtractionResult.failed(
        'No frames could be extracted',
        extractionTime,
      );
    }

    return FrameExtractionResult.success(extractedPaths, extractionTime);
  }

  /// Extract a single frame to a file
  Future<bool> _extractSingleFrame(
    String sourcePath,
    EditorTime timestamp,
    String outputPath, {
    FrameOutputFormat format = FrameOutputFormat.png,
    int? width,
    int? height,
    int quality = 2,
  }) async {
    // Build scale filter
    String scaleFilter = '';
    if (width != null && height != null) {
      scaleFilter =
          '-vf "scale=$width:$height:force_original_aspect_ratio=decrease" ';
    }

    // Build quality options
    String qualityOption;
    if (format == FrameOutputFormat.png) {
      qualityOption = '-f image2';
    } else {
      qualityOption = '-q:v $quality';
    }

    final timestampSec = timestamp.inSeconds;

    final command = '-ss $timestampSec '
        '-i "$sourcePath" '
        '-vframes 1 '
        '$scaleFilter'
        '$qualityOption '
        '-y "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      final file = File(outputPath);
      return await file.exists();
    }

    return false;
  }

  /// Generate a unique filename for an extracted frame
  String _generateFilename({
    required String prefix,
    required int index,
    required EditorTime timestamp,
    required FrameOutputFormat format,
  }) {
    final indexStr = index.toString().padLeft(5, '0');
    final timestampMs = timestamp.inMilliseconds.toString().padLeft(8, '0');
    final extension = format == FrameOutputFormat.png ? 'png' : 'jpg';
    final uniqueId = DateTime.now().microsecondsSinceEpoch.toString();

    return '${prefix}_${indexStr}_${timestampMs}ms_$uniqueId.$extension';
  }

  /// Find all extracted frame files in a directory
  Future<List<String>> _findExtractedFrames(
    String directory,
    String prefix,
    String extension,
  ) async {
    final dir = Directory(directory);
    if (!await dir.exists()) {
      return [];
    }

    final files = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final filename = path.basename(entity.path);
        if (filename.startsWith(prefix) && filename.endsWith('.$extension')) {
          files.add(entity.path);
        }
      }
    }

    // Sort by filename (which should sort by index)
    files.sort();
    return files;
  }

  /// Get output dimensions from size preset
  (int?, int?) _getOutputDimensions(
    FrameOutputSize size,
    int? customWidth,
    int? customHeight,
  ) {
    if (customWidth != null && customHeight != null) {
      return (customWidth, customHeight);
    }

    switch (size) {
      case FrameOutputSize.original:
        return (null, null);
      case FrameOutputSize.size512:
        return (512, 512);
      case FrameOutputSize.size768:
        return (768, 768);
      case FrameOutputSize.size1024:
        return (1024, 1024);
    }
  }

  /// Format duration to FFmpeg timestamp format (HH:MM:SS.mmm)
  String _formatTimestamp(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final milliseconds = duration.inMilliseconds.remainder(1000);

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${milliseconds.toString().padLeft(3, '0')}';
  }

  /// Cancel any ongoing extraction operations
  Future<void> cancelExtraction() async {
    _log('Cancelling frame extraction operations');
    await FFmpegKit.cancel();
  }

  /// Clean up extracted frames from a result
  Future<void> cleanupFrames(FrameExtractionResult result) async {
    _log('Cleaning up ${result.framePaths.length} extracted frames');
    for (final framePath in result.framePaths) {
      final file = File(framePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
