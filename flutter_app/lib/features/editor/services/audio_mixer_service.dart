import 'dart:io';

import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_full/statistics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../models/audio_track_models.dart';
import '../models/editor_models.dart';
import 'ffmpeg_service.dart';

/// Provider for the audio mixer service
final audioMixerServiceProvider = Provider<AudioMixerService>((ref) {
  final ffmpegService = ref.watch(ffmpegServiceProvider);
  return AudioMixerService(ffmpegService);
});

/// Audio clip for mixing operations
class AudioMixClip {
  /// Path to the audio/video file
  final String sourcePath;

  /// Start time within the source
  final Duration sourceStart;

  /// Duration to use
  final Duration duration;

  /// Position on the timeline
  final Duration timelineStart;

  /// Volume level (0.0 to 2.0)
  final double volume;

  /// Pan position (-1.0 to 1.0)
  final double pan;

  /// Whether this clip is muted
  final bool muted;

  const AudioMixClip({
    required this.sourcePath,
    required this.sourceStart,
    required this.duration,
    required this.timelineStart,
    this.volume = 1.0,
    this.pan = 0.0,
    this.muted = false,
  });
}

/// Result of audio analysis
class AudioAnalysisResult {
  /// Peak level (0.0 to 1.0)
  final double peakLevel;

  /// Average RMS level (0.0 to 1.0)
  final double rmsLevel;

  /// Duration of the audio
  final Duration duration;

  /// Sample rate
  final int sampleRate;

  /// Number of channels
  final int channels;

  const AudioAnalysisResult({
    required this.peakLevel,
    required this.rmsLevel,
    required this.duration,
    required this.sampleRate,
    required this.channels,
  });
}

/// Service for mixing and processing audio using FFmpeg
class AudioMixerService {
  static const String _tag = 'AudioMixerService';
  final FFmpegService _ffmpegService;

  AudioMixerService(this._ffmpegService);

  /// Log a debug message
  void _log(String message) {
    print('[$_tag] $message');
  }

  /// Log an error message
  void _logError(String message, [Object? error]) {
    print('[$_tag] ERROR: $message${error != null ? ' - $error' : ''}');
  }

  /// Mix multiple audio tracks into a single output
  ///
  /// [clips] - List of audio clips to mix
  /// [outputPath] - Destination for mixed audio
  /// [masterVolume] - Master volume level (0.0 to 2.0)
  /// [onProgress] - Optional progress callback
  ///
  /// Returns the output path on success, null on failure
  Future<String?> mixAudioTracks(
    List<AudioMixClip> clips,
    String outputPath, {
    double masterVolume = 1.0,
    Duration? totalDuration,
    Function(double progress)? onProgress,
  }) async {
    _log('Mixing ${clips.length} audio clips');

    if (clips.isEmpty) {
      _logError('No clips to mix');
      return null;
    }

    try {
      // Filter out muted clips
      final activeClips = clips.where((c) => !c.muted).toList();

      if (activeClips.isEmpty) {
        _log('All clips muted, generating silence');
        return await _generateSilence(
          outputPath,
          totalDuration ?? const Duration(seconds: 1),
        );
      }

      // Calculate total duration if not provided
      final Duration duration;
      if (totalDuration != null) {
        duration = totalDuration;
      } else {
        duration = activeClips.fold<Duration>(
          Duration.zero,
          (maxDur, clip) {
            final clipEnd = clip.timelineStart + clip.duration;
            return clipEnd > maxDur ? clipEnd : maxDur;
          },
        );
      }

      // Build the complex filter for mixing
      final command = _buildMixCommand(
        activeClips,
        outputPath,
        masterVolume,
        duration,
      );

      _log('Running mix command: $command');

      // Set up progress callback
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
        _log('Audio mix completed successfully');
        return outputPath;
      }

      final logs = await session.getAllLogsAsString();
      _logError('Audio mix failed', logs);
      return null;
    } catch (e) {
      _logError('Audio mix error', e);
      return null;
    }
  }

  /// Build FFmpeg command for mixing audio clips
  String _buildMixCommand(
    List<AudioMixClip> clips,
    String outputPath,
    double masterVolume,
    Duration totalDuration,
  ) {
    final buffer = StringBuffer();

    // Input files with seek and duration
    for (int i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final ss = _formatTimestamp(clip.sourceStart);
      final t = _formatTimestamp(clip.duration);
      buffer.write('-ss $ss -t $t -i "${clip.sourcePath}" ');
    }

    // Build complex filter
    buffer.write('-filter_complex "');

    // Process each clip: volume, pan, delay
    for (int i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final delayMs = clip.timelineStart.inMilliseconds;

      // Volume adjustment
      buffer.write('[$i:a]volume=${clip.volume}');

      // Pan adjustment (using stereo balance)
      if (clip.pan != 0) {
        // pan filter: pan=stereo|c0=c0*leftGain|c1=c1*rightGain
        final leftGain = clip.pan < 0 ? 1.0 : 1.0 - clip.pan;
        final rightGain = clip.pan > 0 ? 1.0 : 1.0 + clip.pan;
        buffer.write(',pan=stereo|c0=${leftGain}*c0|c1=${rightGain}*c1');
      }

      // Delay to position on timeline
      if (delayMs > 0) {
        buffer.write(',adelay=$delayMs|$delayMs');
      }

      // Pad to total duration
      final padDuration = totalDuration.inMilliseconds;
      buffer.write(',apad=whole_dur=${padDuration}ms');

      buffer.write('[a$i];');
    }

    // Mix all processed audio streams
    final inputLabels = List.generate(clips.length, (i) => '[a$i]').join();
    buffer.write('${inputLabels}amix=inputs=${clips.length}');
    buffer.write(':duration=longest');
    buffer.write(':normalize=0'); // Don't auto-normalize

    // Apply master volume
    if (masterVolume != 1.0) {
      buffer.write(',volume=$masterVolume');
    }

    buffer.write('[out]');
    buffer.write('" ');

    // Output settings
    buffer.write('-map "[out]" ');
    buffer.write('-c:a aac -b:a 192k ');
    buffer.write('-y "$outputPath"');

    return buffer.toString();
  }

  /// Mix audio and video together
  ///
  /// [videoPath] - Source video file
  /// [audioClips] - Audio clips to mix
  /// [outputPath] - Destination for output
  /// [replaceAudio] - If true, replaces video audio; if false, mixes with it
  Future<String?> mixAudioWithVideo(
    String videoPath,
    List<AudioMixClip> audioClips,
    String outputPath, {
    bool replaceAudio = false,
    double masterVolume = 1.0,
    Function(double progress)? onProgress,
  }) async {
    _log('Mixing audio with video: $videoPath');

    try {
      // Verify video file exists
      if (!await File(videoPath).exists()) {
        _logError('Video file not found: $videoPath');
        return null;
      }

      // Get video info for duration
      final mediaInfo = await _ffmpegService.getMediaInfo(videoPath);
      if (mediaInfo == null) {
        _logError('Could not get video info');
        return null;
      }

      // First, mix the audio clips
      final tempDir = Directory.systemTemp;
      final tempAudioPath = path.join(
        tempDir.path,
        'mixed_audio_${DateTime.now().millisecondsSinceEpoch}.aac',
      );

      final mixedAudio = await mixAudioTracks(
        audioClips,
        tempAudioPath,
        masterVolume: masterVolume,
        totalDuration: mediaInfo.duration,
        onProgress: onProgress != null
            ? (p) => onProgress(p * 0.5) // First half of progress
            : null,
      );

      if (mixedAudio == null) {
        return null;
      }

      // Combine with video
      String command;
      if (replaceAudio) {
        // Replace original audio
        command = '-i "$videoPath" -i "$tempAudioPath" '
            '-map 0:v -map 1:a '
            '-c:v copy -c:a aac '
            '-shortest '
            '-y "$outputPath"';
      } else {
        // Mix with original audio
        command = '-i "$videoPath" -i "$tempAudioPath" '
            '-filter_complex "[0:a][1:a]amix=inputs=2:duration=first[a]" '
            '-map 0:v -map "[a]" '
            '-c:v copy -c:a aac '
            '-y "$outputPath"';
      }

      _log('Running video mix command: $command');

      // Set up progress for second half
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
          final time = stats.getTime();
          if (time > 0 && mediaInfo.duration.inMilliseconds > 0) {
            final progress = 0.5 + (time / mediaInfo.duration.inMilliseconds) * 0.5;
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

      // Delete temp file
      try {
        await File(tempAudioPath).delete();
      } catch (_) {}

      if (ReturnCode.isSuccess(returnCode)) {
        _log('Video audio mix completed');
        return outputPath;
      }

      final logs = await session.getAllLogsAsString();
      _logError('Video audio mix failed', logs);
      return null;
    } catch (e) {
      _logError('Video audio mix error', e);
      return null;
    }
  }

  /// Adjust volume of an audio/video file
  Future<String?> adjustVolume(
    String inputPath,
    String outputPath,
    double volume, {
    Function(double progress)? onProgress,
  }) async {
    _log('Adjusting volume to $volume for: $inputPath');

    try {
      final mediaInfo = await _ffmpegService.getMediaInfo(inputPath);
      if (mediaInfo == null) {
        _logError('Could not get media info');
        return null;
      }

      // Set up progress
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
          final time = stats.getTime();
          if (time > 0 && mediaInfo.duration.inMilliseconds > 0) {
            final progress = time / mediaInfo.duration.inMilliseconds;
            onProgress(progress.clamp(0.0, 1.0));
          }
        });
      }

      final command = '-i "$inputPath" '
          '-af "volume=$volume" '
          '-c:v copy -c:a aac '
          '-y "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback(null);
        onProgress(1.0);
      }

      if (ReturnCode.isSuccess(returnCode)) {
        return outputPath;
      }

      return null;
    } catch (e) {
      _logError('Volume adjustment error', e);
      return null;
    }
  }

  /// Generate a silent audio file
  Future<String?> _generateSilence(String outputPath, Duration duration) async {
    _log('Generating ${duration.inSeconds}s of silence');

    final durationSec = duration.inSeconds;
    final command = '-f lavfi -i anullsrc=r=48000:cl=stereo '
        '-t $durationSec '
        '-c:a aac -b:a 128k '
        '-y "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    }

    return null;
  }

  /// Analyze audio levels in a file
  Future<AudioAnalysisResult?> analyzeAudio(String inputPath) async {
    _log('Analyzing audio: $inputPath');

    try {
      final mediaInfo = await _ffmpegService.getMediaInfo(inputPath);
      if (mediaInfo == null || !mediaInfo.hasAudio) {
        _logError('No audio stream found');
        return null;
      }

      // Use ffprobe to get audio statistics
      // Note: This is a simplified analysis
      return AudioAnalysisResult(
        peakLevel: 0.9, // Would need actual analysis
        rmsLevel: 0.6,
        duration: mediaInfo.duration,
        sampleRate: mediaInfo.sampleRate ?? 48000,
        channels: mediaInfo.audioChannels ?? 2,
      );
    } catch (e) {
      _logError('Audio analysis error', e);
      return null;
    }
  }

  /// Cancel any ongoing audio processing
  Future<void> cancelProcessing() async {
    _log('Cancelling audio processing');
    await FFmpegKit.cancel();
  }

  /// Format duration to FFmpeg timestamp format
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
