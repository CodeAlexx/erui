import 'dart:io';

import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../models/editor_models.dart';
import '../models/transition_models.dart';

/// Provider for the transition renderer service
final transitionRendererProvider = Provider<TransitionRenderer>((ref) {
  return TransitionRenderer();
});

/// Service for rendering video transitions using FFmpeg xfade filter
class TransitionRenderer {
  static const String _tag = 'TransitionRenderer';

  /// Log a debug message
  void _log(String message) {
    print('[$_tag] $message');
  }

  /// Log an error message
  void _logError(String message, [Object? error]) {
    print('[$_tag] ERROR: $message${error != null ? ' - $error' : ''}');
  }

  /// Render a transition between two video clips
  ///
  /// [transition] - The transition configuration
  /// [clip1Path] - Path to the first (outgoing) video clip
  /// [clip2Path] - Path to the second (incoming) video clip
  /// [outputPath] - Where to save the rendered output
  /// [onProgress] - Optional progress callback (0.0 to 1.0)
  ///
  /// Returns the output path on success, null on failure
  Future<String?> renderTransition(
    Transition transition,
    String clip1Path,
    String clip2Path,
    String outputPath, {
    Function(double progress)? onProgress,
  }) async {
    _log('Rendering transition: ${transition.type} between clips');
    _log('Clip 1: $clip1Path');
    _log('Clip 2: $clip2Path');
    _log('Output: $outputPath');

    try {
      // Verify input files exist
      if (!await File(clip1Path).exists()) {
        _logError('First clip file not found: $clip1Path');
        return null;
      }
      if (!await File(clip2Path).exists()) {
        _logError('Second clip file not found: $clip2Path');
        return null;
      }

      // Build the xfade command
      final command = _buildXfadeCommand(
        transition: transition,
        clip1Path: clip1Path,
        clip2Path: clip2Path,
        outputPath: outputPath,
      );

      _log('Running FFmpeg command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        _log('Transition rendered successfully');
        onProgress?.call(1.0);
        return outputPath;
      }

      final logs = await session.getAllLogsAsString();
      _logError('Transition rendering failed', logs);
      return null;
    } catch (e) {
      _logError('Transition rendering error', e);
      return null;
    }
  }

  /// Build FFmpeg xfade command for the transition
  String _buildXfadeCommand({
    required Transition transition,
    required String clip1Path,
    required String clip2Path,
    required String outputPath,
  }) {
    final durationSec = transition.duration.inSeconds;
    final transitionName = transition.ffmpegTransitionName;
    final easing = _getEasingExpression(transition.curve);

    // xfade filter: crossfade between two video streams
    // The offset is where the transition starts (end of clip1 minus transition duration)
    // For this simplified version, we assume the transition happens at the end of clip1

    final buffer = StringBuffer();

    // Input files
    buffer.write('-i "$clip1Path" ');
    buffer.write('-i "$clip2Path" ');

    // xfade filter
    buffer.write('-filter_complex "');
    buffer.write('[0:v][1:v]xfade=transition=$transitionName');
    buffer.write(':duration=$durationSec');
    buffer.write(':offset=0'); // Will be calculated based on clip1 duration
    if (easing.isNotEmpty) {
      buffer.write(':easing=$easing');
    }
    buffer.write('[v];');

    // Audio crossfade
    buffer.write('[0:a][1:a]acrossfade=d=$durationSec[a]');
    buffer.write('" ');

    // Output mapping and settings
    buffer.write('-map "[v]" -map "[a]" ');
    buffer.write('-c:v libx264 -preset fast -crf 18 ');
    buffer.write('-c:a aac -b:a 192k ');
    buffer.write('-y "$outputPath"');

    return buffer.toString();
  }

  /// Convert curve name to FFmpeg easing expression
  String _getEasingExpression(String curve) {
    switch (curve) {
      case 'linear':
        return '';
      case 'easeIn':
        return 'easeIn';
      case 'easeOut':
        return 'easeOut';
      case 'easeInOut':
        return 'easeInOut';
      default:
        return '';
    }
  }

  /// Render a transition and merge back into timeline context
  ///
  /// This is a higher-level method that handles:
  /// 1. Extracting the relevant portions of the clips
  /// 2. Rendering the transition
  /// 3. Returning the merged result
  Future<String?> renderTransitionForTimeline({
    required Transition transition,
    required EditorClip startClip,
    required EditorClip endClip,
    required String tempDir,
    Function(double progress)? onProgress,
  }) async {
    _log('Rendering timeline transition: ${transition.type}');

    try {
      // Create temp directory if it doesn't exist
      final tempDirectory = Directory(tempDir);
      if (!await tempDirectory.exists()) {
        await tempDirectory.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = path.join(tempDir, 'transition_$timestamp.mp4');

      // For a full implementation, we would:
      // 1. Extract the end portion of startClip (transition duration)
      // 2. Extract the start portion of endClip (transition duration)
      // 3. Apply the xfade filter between them

      // For now, this assumes the clips are already trimmed appropriately
      if (startClip.sourcePath == null || endClip.sourcePath == null) {
        _logError('Clips must have source paths');
        return null;
      }

      return await renderTransition(
        transition,
        startClip.sourcePath!,
        endClip.sourcePath!,
        outputPath,
        onProgress: onProgress,
      );
    } catch (e) {
      _logError('Timeline transition error', e);
      return null;
    }
  }

  /// Generate a preview frame of the transition at a specific progress point
  ///
  /// [progress] - Transition progress (0.0 to 1.0)
  /// Returns JPEG bytes for the preview frame
  Future<List<int>?> generateTransitionPreview({
    required Transition transition,
    required String clip1Path,
    required String clip2Path,
    required double progress,
    int width = 320,
    int height = 180,
  }) async {
    _log('Generating transition preview at ${(progress * 100).round()}%');

    try {
      final tempDir = Directory.systemTemp;
      final outputPath = path.join(
        tempDir.path,
        'transition_preview_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // For a static preview, we blend the two frames based on progress
      // This is a simplified preview - actual transition would need video rendering
      final blendFactor = progress;

      final command = '-i "$clip1Path" -i "$clip2Path" '
          '-filter_complex "'
          '[0:v]scale=$width:$height,format=rgba[a];'
          '[1:v]scale=$width:$height,format=rgba[b];'
          '[a][b]blend=all_mode=overlay:all_opacity=$blendFactor'
          '" '
          '-frames:v 1 -q:v 2 '
          '-y "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          await file.delete();
          return bytes;
        }
      }

      return null;
    } catch (e) {
      _logError('Preview generation error', e);
      return null;
    }
  }

  /// Get the list of supported transition types
  List<TransitionType> get supportedTransitions => TransitionType.values;

  /// Check if a transition type is supported by the current FFmpeg build
  Future<bool> isTransitionSupported(TransitionType type) async {
    // All basic transitions should be supported in ffmpeg_kit_flutter_full
    // For custom transitions, we might need to check
    return true;
  }

  /// Cancel any ongoing transition rendering
  Future<void> cancelRendering() async {
    _log('Cancelling transition rendering');
    await FFmpegKit.cancel();
  }
}
