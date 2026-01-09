import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_full/statistics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../models/effect_models.dart';
import 'ffmpeg_service.dart';

/// Provider for the effect processor service
final effectProcessorProvider = Provider<EffectProcessor>((ref) {
  final ffmpegService = ref.watch(ffmpegServiceProvider);
  return EffectProcessor(ffmpegService);
});

/// Service for applying video effects using FFmpeg filters
class EffectProcessor {
  static const String _tag = 'EffectProcessor';
  final FFmpegService _ffmpegService;

  EffectProcessor(this._ffmpegService);

  /// Log a debug message
  void _log(String message) {
    print('[$_tag] $message');
  }

  /// Log an error message
  void _logError(String message, [Object? error]) {
    print('[$_tag] ERROR: $message${error != null ? ' - $error' : ''}');
  }

  /// Apply a list of effects to a video file
  ///
  /// [effects] - List of effects to apply in order
  /// [inputPath] - Source video file
  /// [outputPath] - Destination for processed video
  /// [onProgress] - Optional progress callback
  ///
  /// Returns the output path on success, null on failure
  Future<String?> applyEffects(
    List<VideoEffect> effects,
    String inputPath,
    String outputPath, {
    Function(double progress)? onProgress,
  }) async {
    _log('Applying ${effects.length} effects to: $inputPath');

    try {
      // Verify input file exists
      if (!await File(inputPath).exists()) {
        _logError('Input file not found: $inputPath');
        return null;
      }

      // Filter to only enabled effects
      final enabledEffects = effects.where((e) => e.enabled).toList();

      if (enabledEffects.isEmpty) {
        _log('No enabled effects, copying file directly');
        await File(inputPath).copy(outputPath);
        return outputPath;
      }

      // Get media info for progress tracking
      final mediaInfo = await _ffmpegService.getMediaInfo(inputPath);

      // Build the filter chain
      final filterChain = _buildFilterChain(enabledEffects);
      if (filterChain.isEmpty) {
        _log('No active filters, copying file directly');
        await File(inputPath).copy(outputPath);
        return outputPath;
      }

      _log('Filter chain: $filterChain');

      // Set up progress callback
      if (onProgress != null && mediaInfo != null) {
        FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
          final time = stats.getTime();
          if (time > 0 && mediaInfo.duration.inMilliseconds > 0) {
            final progress = time / mediaInfo.duration.inMilliseconds;
            onProgress(progress.clamp(0.0, 1.0));
          }
        });
      }

      // Build and execute FFmpeg command
      final command = '-i "$inputPath" '
          '-vf "$filterChain" '
          '-c:v libx264 -preset fast -crf 18 '
          '-c:a copy '
          '-y "$outputPath"';

      _log('Running FFmpeg command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clean up progress callback
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback(null);
        onProgress(1.0);
      }

      if (ReturnCode.isSuccess(returnCode)) {
        _log('Effects applied successfully');
        return outputPath;
      }

      final logs = await session.getAllLogsAsString();
      _logError('Effect processing failed', logs);
      return null;
    } catch (e) {
      _logError('Effect processing error', e);
      return null;
    }
  }

  /// Build the FFmpeg filter chain from a list of effects
  String _buildFilterChain(List<VideoEffect> effects) {
    final filters = <String>[];

    for (final effect in effects) {
      if (!effect.enabled) continue;

      final filter = effect.toFFmpegFilter();
      if (filter.isNotEmpty) {
        filters.add(filter);
      }
    }

    return filters.join(',');
  }

  /// Generate a preview frame with effects applied
  ///
  /// [effects] - Effects to apply
  /// [inputPath] - Source video file
  /// [timestamp] - Time position to extract frame from
  /// [width] - Optional output width (maintains aspect ratio if only one dimension specified)
  /// [height] - Optional output height
  ///
  /// Returns JPEG bytes for the preview frame
  Future<Uint8List?> generatePreviewFrame(
    List<VideoEffect> effects,
    String inputPath,
    Duration timestamp, {
    int? width,
    int? height,
  }) async {
    _log('Generating effect preview at ${timestamp.inMilliseconds}ms');

    try {
      final tempDir = Directory.systemTemp;
      final outputPath = path.join(
        tempDir.path,
        'effect_preview_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Build filter chain
      final enabledEffects = effects.where((e) => e.enabled).toList();
      final filterChain = _buildFilterChain(enabledEffects);

      // Add scale filter if dimensions specified
      String scaleFilter = '';
      if (width != null || height != null) {
        final w = width ?? -1;
        final h = height ?? -1;
        scaleFilter = 'scale=$w:$h';
      }

      // Combine filters
      String combinedFilters;
      if (filterChain.isNotEmpty && scaleFilter.isNotEmpty) {
        combinedFilters = '$filterChain,$scaleFilter';
      } else if (filterChain.isNotEmpty) {
        combinedFilters = filterChain;
      } else if (scaleFilter.isNotEmpty) {
        combinedFilters = scaleFilter;
      } else {
        combinedFilters = '';
      }

      // Format timestamp
      final timeStr = _formatTimestamp(timestamp);

      // Build command
      String command;
      if (combinedFilters.isNotEmpty) {
        command = '-ss $timeStr -i "$inputPath" '
            '-vf "$combinedFilters" '
            '-frames:v 1 -q:v 2 '
            '-y "$outputPath"';
      } else {
        command = '-ss $timeStr -i "$inputPath" '
            '-frames:v 1 -q:v 2 '
            '-y "$outputPath"';
      }

      _log('Running preview command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          await file.delete();
          _log('Preview generated: ${bytes.length} bytes');
          return bytes;
        }
      }

      final logs = await session.getAllLogsAsString();
      _logError('Preview generation failed', logs);
      return null;
    } catch (e) {
      _logError('Preview generation error', e);
      return null;
    }
  }

  /// Apply effects to a specific clip portion
  ///
  /// This method handles extracting a portion of a clip, applying effects,
  /// and saving the result
  Future<String?> applyEffectsToClipPortion({
    required List<VideoEffect> effects,
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration duration,
    Function(double progress)? onProgress,
  }) async {
    _log('Applying effects to clip portion: $startTime - ${startTime + duration}');

    try {
      // Verify input file exists
      if (!await File(inputPath).exists()) {
        _logError('Input file not found: $inputPath');
        return null;
      }

      // Build filter chain
      final enabledEffects = effects.where((e) => e.enabled).toList();
      final filterChain = _buildFilterChain(enabledEffects);

      // Format times
      final startStr = _formatTimestamp(startTime);
      final durationStr = _formatTimestamp(duration);

      // Build command with time selection
      String command;
      if (filterChain.isNotEmpty) {
        command = '-ss $startStr -t $durationStr -i "$inputPath" '
            '-vf "$filterChain" '
            '-c:v libx264 -preset fast -crf 18 '
            '-c:a aac -b:a 192k '
            '-y "$outputPath"';
      } else {
        command = '-ss $startStr -t $durationStr -i "$inputPath" '
            '-c:v libx264 -preset fast -crf 18 '
            '-c:a aac -b:a 192k '
            '-y "$outputPath"';
      }

      _log('Running command: $command');

      // Set up progress
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
          final time = stats.getTime();
          if (time > 0 && duration.inMilliseconds > 0) {
            final progress = time / duration.inMilliseconds;
            onProgress(progress.clamp(0.0, 1.0));
          }
        });
      }

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clean up
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback(null);
        onProgress(1.0);
      }

      if (ReturnCode.isSuccess(returnCode)) {
        _log('Clip portion processed successfully');
        return outputPath;
      }

      final logs = await session.getAllLogsAsString();
      _logError('Clip portion processing failed', logs);
      return null;
    } catch (e) {
      _logError('Clip portion processing error', e);
      return null;
    }
  }

  /// Validate that all effects in the list are properly configured
  List<String> validateEffects(List<VideoEffect> effects) {
    final errors = <String>[];

    for (final effect in effects) {
      final paramNames = VideoEffect.getParameterNames(effect.type);

      for (final paramName in paramNames) {
        final value = effect.parameters[paramName];
        if (value == null) {
          errors.add('${effect.displayName}: Missing parameter "$paramName"');
          continue;
        }

        final range = VideoEffect.getParameterRange(effect.type, paramName);
        if (value < range.min || value > range.max) {
          errors.add(
            '${effect.displayName}: Parameter "$paramName" out of range '
            '(${range.min} - ${range.max})',
          );
        }
      }
    }

    return errors;
  }

  /// Get a list of all supported effect types
  List<EffectType> get supportedEffects => EffectType.values;

  /// Cancel any ongoing effect processing
  Future<void> cancelProcessing() async {
    _log('Cancelling effect processing');
    await FFmpegKit.cancel();
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
}
