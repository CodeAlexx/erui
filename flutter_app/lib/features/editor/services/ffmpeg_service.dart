import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_full/statistics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

/// FFmpeg service provider
final ffmpegServiceProvider = Provider<FFmpegService>((ref) {
  return FFmpegService();
});

/// Media information extracted from a file
class MediaInfo {
  /// Path to the media file
  final String path;

  /// Duration of the media
  final Duration duration;

  /// Video width in pixels (null for audio-only)
  final int? width;

  /// Video height in pixels (null for audio-only)
  final int? height;

  /// Frames per second (null for audio-only)
  final double? fps;

  /// Video codec name (null for audio-only)
  final String? codec;

  /// Audio codec name (null for video-only without audio)
  final String? audioCodec;

  /// Number of audio channels (null if no audio)
  final int? audioChannels;

  /// Audio sample rate in Hz (null if no audio)
  final int? sampleRate;

  /// Video bitrate in bits per second (null for audio-only)
  final int? videoBitrate;

  /// Audio bitrate in bits per second (null if no audio)
  final int? audioBitrate;

  /// Total file size in bytes
  final int? fileSize;

  /// Whether the file has video stream
  bool get hasVideo => width != null && height != null;

  /// Whether the file has audio stream
  bool get hasAudio => audioCodec != null;

  const MediaInfo({
    required this.path,
    required this.duration,
    this.width,
    this.height,
    this.fps,
    this.codec,
    this.audioCodec,
    this.audioChannels,
    this.sampleRate,
    this.videoBitrate,
    this.audioBitrate,
    this.fileSize,
  });

  @override
  String toString() {
    return 'MediaInfo(path: $path, duration: $duration, '
        'resolution: ${width}x$height, fps: $fps, codec: $codec, '
        'audioCodec: $audioCodec, audioChannels: $audioChannels, sampleRate: $sampleRate)';
  }
}

/// Clip information for export operations
class ExportClip {
  /// Path to the source media file
  final String sourcePath;

  /// Start time within the source file
  final Duration sourceStart;

  /// Duration to use from source
  final Duration duration;

  /// Position on the timeline
  final Duration timelineStart;

  /// Track index (0 = bottom track)
  final int trackIndex;

  /// Volume multiplier (1.0 = original volume)
  final double volume;

  /// Speed multiplier (1.0 = original speed)
  final double speed;

  const ExportClip({
    required this.sourcePath,
    required this.sourceStart,
    required this.duration,
    required this.timelineStart,
    this.trackIndex = 0,
    this.volume = 1.0,
    this.speed = 1.0,
  });
}

/// FFmpeg service for video/audio processing
class FFmpegService {
  static const String _tag = 'FFmpegService';

  /// Check if running on desktop (where ffmpeg_kit doesn't work)
  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  /// Log a debug message
  void _log(String message) {
    print('[$_tag] $message');
  }

  /// Log an error message
  void _logError(String message, [Object? error]) {
    print('[$_tag] ERROR: $message${error != null ? ' - $error' : ''}');
  }

  /// Get media info using native ffprobe (for desktop platforms)
  Future<MediaInfo?> _getMediaInfoNative(String filePath) async {
    _log('Getting media info using native ffprobe for: $filePath');

    try {
      final result = await Process.run('ffprobe', [
        '-v',
        'quiet',
        '-print_format',
        'json',
        '-show_format',
        '-show_streams',
        filePath,
      ]);

      if (result.exitCode != 0) {
        _logError('ffprobe failed', result.stderr);
        return null;
      }

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;

      // Parse format info
      final format = json['format'] as Map<String, dynamic>?;
      final durationStr = format?['duration'] as String?;
      final durationMs =
          durationStr != null ? (double.tryParse(durationStr) ?? 0) * 1000 : 0.0;
      final fileSizeStr = format?['size'] as String?;
      final fileSize = fileSizeStr != null ? int.tryParse(fileSizeStr) : null;

      // Parse streams
      int? width;
      int? height;
      double? fps;
      String? videoCodec;
      int? videoBitrate;
      String? audioCodec;
      int? audioChannels;
      int? sampleRate;
      int? audioBitrate;

      final streams = json['streams'] as List<dynamic>?;
      if (streams != null) {
        for (final stream in streams) {
          final s = stream as Map<String, dynamic>;
          final codecType = s['codec_type'] as String?;

          if (codecType == 'video') {
            width = s['width'] as int?;
            height = s['height'] as int?;
            videoCodec = s['codec_name'] as String?;

            // Parse frame rate
            final fpsStr = s['r_frame_rate'] as String?;
            if (fpsStr != null && fpsStr.contains('/')) {
              final parts = fpsStr.split('/');
              if (parts.length == 2) {
                final num = double.tryParse(parts[0]) ?? 0;
                final den = double.tryParse(parts[1]) ?? 1;
                fps = den > 0 ? num / den : null;
              }
            }

            final bitrateStr = s['bit_rate'] as String?;
            videoBitrate = bitrateStr != null ? int.tryParse(bitrateStr) : null;
          } else if (codecType == 'audio') {
            audioCodec = s['codec_name'] as String?;
            audioChannels = s['channels'] as int?;
            final sampleRateStr = s['sample_rate'] as String?;
            sampleRate =
                sampleRateStr != null ? int.tryParse(sampleRateStr) : null;
            final bitrateStr = s['bit_rate'] as String?;
            audioBitrate = bitrateStr != null ? int.tryParse(bitrateStr) : null;
          }
        }
      }

      final result2 = MediaInfo(
        path: filePath,
        duration: Duration(milliseconds: durationMs.round()),
        width: width,
        height: height,
        fps: fps,
        codec: videoCodec,
        audioCodec: audioCodec,
        audioChannels: audioChannels,
        sampleRate: sampleRate,
        videoBitrate: videoBitrate,
        audioBitrate: audioBitrate,
        fileSize: fileSize,
      );

      _log('Media info retrieved (native): $result2');
      return result2;
    } catch (e) {
      _logError('Native ffprobe failed', e);
      return null;
    }
  }

  /// Extract a frame using native ffmpeg (for desktop platforms)
  Future<Uint8List?> _extractFrameNative(
    String filePath,
    Duration timestamp, {
    int? width,
    int? height,
  }) async {
    _log('Extracting frame at ${timestamp.inMilliseconds}ms using native ffmpeg from: $filePath');

    try {
      final tempDir = Directory.systemTemp;
      final outputPath = path.join(
        tempDir.path,
        'frame_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final timeStr = _formatTimestamp(timestamp);

      // Build ffmpeg arguments
      final args = <String>[
        '-ss',
        timeStr,
        '-i',
        filePath,
        '-vframes',
        '1',
        '-q:v',
        '2',
      ];

      // Add scale filter if dimensions specified
      if (width != null && height != null) {
        args.addAll(['-vf', 'scale=$width:$height']);
      }

      args.addAll(['-y', outputPath]);

      _log('Running native ffmpeg: ffmpeg ${args.join(' ')}');

      final result = await Process.run('ffmpeg', args);

      if (result.exitCode == 0) {
        final file = File(outputPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          await file.delete();
          _log('Frame extracted successfully (native): ${bytes.length} bytes');
          return bytes;
        }
      }

      _logError('Native ffmpeg frame extraction failed', result.stderr);
      return null;
    } catch (e) {
      _logError('Native frame extraction error', e);
      return null;
    }
  }

  /// Get media information from a file
  /// Returns null if the file cannot be probed or is not a valid media file
  Future<MediaInfo?> getMediaInfo(String filePath) async {
    _log('Getting media info for: $filePath');

    // Use native ffprobe on desktop platforms
    if (_isDesktop) {
      return _getMediaInfoNative(filePath);
    }

    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final mediaInfo = session.getMediaInformation();

      if (mediaInfo == null) {
        _logError('Failed to get media information for: $filePath');
        return null;
      }

      // Parse duration
      final durationStr = mediaInfo.getDuration();
      final durationMs = durationStr != null
          ? (double.tryParse(durationStr) ?? 0) * 1000
          : 0.0;

      // Parse file size
      final sizeStr = mediaInfo.getSize();
      final fileSize = sizeStr != null ? int.tryParse(sizeStr) : null;

      // Find video and audio streams
      int? width;
      int? height;
      double? fps;
      String? videoCodec;
      int? videoBitrate;
      String? audioCodec;
      int? audioChannels;
      int? sampleRate;
      int? audioBitrate;

      final streams = mediaInfo.getStreams();
      if (streams != null) {
        for (final stream in streams) {
          final type = stream.getType();

          if (type == 'video') {
            width = stream.getWidth();
            height = stream.getHeight();
            videoCodec = stream.getCodec();

            // Parse frame rate
            final fpsStr = stream.getRealFrameRate();
            if (fpsStr != null && fpsStr.contains('/')) {
              final parts = fpsStr.split('/');
              if (parts.length == 2) {
                final num = double.tryParse(parts[0]) ?? 0;
                final den = double.tryParse(parts[1]) ?? 1;
                fps = den > 0 ? num / den : null;
              }
            } else if (fpsStr != null) {
              fps = double.tryParse(fpsStr);
            }

            // Parse video bitrate
            final bitrateStr = stream.getBitrate();
            videoBitrate = bitrateStr != null ? int.tryParse(bitrateStr) : null;
          } else if (type == 'audio') {
            audioCodec = stream.getCodec();

            // Parse audio properties
            final props = stream.getAllProperties();
            if (props != null) {
              audioChannels = props['channels'] as int?;
              final sampleRateStr = props['sample_rate'];
              sampleRate = sampleRateStr is String
                  ? int.tryParse(sampleRateStr)
                  : sampleRateStr as int?;
            }

            // Parse audio bitrate
            final bitrateStr = stream.getBitrate();
            audioBitrate = bitrateStr != null ? int.tryParse(bitrateStr) : null;
          }
        }
      }

      final result = MediaInfo(
        path: filePath,
        duration: Duration(milliseconds: durationMs.round()),
        width: width,
        height: height,
        fps: fps,
        codec: videoCodec,
        audioCodec: audioCodec,
        audioChannels: audioChannels,
        sampleRate: sampleRate,
        videoBitrate: videoBitrate,
        audioBitrate: audioBitrate,
        fileSize: fileSize,
      );

      _log('Media info retrieved: $result');
      return result;
    } catch (e) {
      _logError('Failed to get media info', e);
      return null;
    }
  }

  /// Extract a single frame from a video at a specific timestamp
  /// Returns the frame as JPEG bytes, or null on failure
  Future<Uint8List?> extractFrame(
    String filePath,
    Duration timestamp, {
    int? width,
    int? height,
  }) async {
    _log('Extracting frame at ${timestamp.inMilliseconds}ms from: $filePath');

    // Use native ffmpeg on desktop platforms
    if (_isDesktop) {
      return _extractFrameNative(filePath, timestamp, width: width, height: height);
    }

    try {
      // Create a temporary file for the output
      final tempDir = Directory.systemTemp;
      final outputPath = path.join(
        tempDir.path,
        'frame_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Build FFmpeg command
      final timeStr = _formatTimestamp(timestamp);
      final scaleFilter = width != null && height != null
          ? ',scale=$width:$height'
          : '';

      final command = '-ss $timeStr -i "$filePath" '
          '-vframes 1 -q:v 2 '
          '-vf "select=eq(n\\,0)$scaleFilter" '
          '-y "$outputPath"';

      _log('Running FFmpeg command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(outputPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          await file.delete(); // Clean up temp file
          _log('Frame extracted successfully: ${bytes.length} bytes');
          return bytes;
        }
      }

      // Log failure details
      final logs = await session.getAllLogsAsString();
      _logError('Frame extraction failed', logs);
      return null;
    } catch (e) {
      _logError('Frame extraction error', e);
      return null;
    }
  }

  /// Extract audio waveform data from a media file
  /// Returns normalized amplitude values (0.0 to 1.0), or null on failure
  Future<List<double>?> extractWaveform(
    String filePath, {
    int samples = 1000,
  }) async {
    _log('Extracting waveform ($samples samples) from: $filePath');

    try {
      // Create a temporary file for the raw audio data
      final tempDir = Directory.systemTemp;
      final outputPath = path.join(
        tempDir.path,
        'waveform_${DateTime.now().millisecondsSinceEpoch}.raw',
      );

      // Get media duration first
      final info = await getMediaInfo(filePath);
      if (info == null || !info.hasAudio) {
        _logError('No audio stream found in file');
        return null;
      }

      // Calculate samples per second to get desired total samples
      final durationSecs = info.duration.inMilliseconds / 1000.0;
      final samplesPerSecond = (samples / durationSecs).ceil();

      // Extract audio as raw 16-bit signed PCM, downsampled
      final command = '-i "$filePath" '
          '-ac 1 -ar $samplesPerSecond '
          '-f s16le -acodec pcm_s16le '
          '-y "$outputPath"';

      _log('Running FFmpeg command for waveform: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getAllLogsAsString();
        _logError('Waveform extraction failed', logs);
        return null;
      }

      // Read raw audio data
      final file = File(outputPath);
      if (!await file.exists()) {
        _logError('Output file not created');
        return null;
      }

      final bytes = await file.readAsBytes();
      await file.delete(); // Clean up

      if (bytes.isEmpty) {
        _logError('Empty audio data');
        return null;
      }

      // Convert bytes to amplitude values
      final waveform = <double>[];
      final byteData = bytes.buffer.asByteData();

      // Each sample is 2 bytes (16-bit signed)
      final totalSamples = bytes.length ~/ 2;
      final samplesPerBucket = totalSamples ~/ samples;

      if (samplesPerBucket < 1) {
        // Not enough samples, use what we have
        for (int i = 0; i < bytes.length - 1; i += 2) {
          final sample = byteData.getInt16(i, Endian.little);
          waveform.add(sample.abs() / 32768.0);
        }
      } else {
        // Average samples into buckets
        for (int bucket = 0; bucket < samples; bucket++) {
          double sum = 0;
          int count = 0;
          final startIdx = bucket * samplesPerBucket * 2;
          final endIdx = (startIdx + samplesPerBucket * 2).clamp(0, bytes.length - 1);

          for (int i = startIdx; i < endIdx - 1; i += 2) {
            final sample = byteData.getInt16(i, Endian.little);
            sum += sample.abs();
            count++;
          }

          waveform.add(count > 0 ? (sum / count) / 32768.0 : 0.0);
        }
      }

      _log('Waveform extracted: ${waveform.length} samples');
      return waveform;
    } catch (e) {
      _logError('Waveform extraction error', e);
      return null;
    }
  }

  /// Decode video frames for preview playback
  /// Yields frame data as JPEG bytes at the specified frame rate
  Stream<Uint8List> decodeVideoFrames(
    String filePath, {
    Duration startTime = Duration.zero,
    Duration? endTime,
    int? width,
    int? height,
    double? frameRate,
  }) async* {
    _log('Decoding video frames from: $filePath');

    try {
      // Get media info if frame rate not specified
      double fps = frameRate ?? 30.0;
      if (frameRate == null) {
        final info = await getMediaInfo(filePath);
        if (info?.fps != null) {
          fps = info!.fps!;
        }
      }

      // Calculate frame timing
      final frameDuration = Duration(milliseconds: (1000 / fps).round());
      Duration currentTime = startTime;
      final end = endTime ?? Duration(hours: 24); // Large default

      while (currentTime < end) {
        final frame = await extractFrame(
          filePath,
          currentTime,
          width: width,
          height: height,
        );

        if (frame == null) {
          // End of video or error
          break;
        }

        yield frame;
        currentTime += frameDuration;
      }
    } catch (e) {
      _logError('Video frame decoding error', e);
    }
  }

  /// Export timeline clips to a video file
  /// Handles multiple clips with proper sequencing and audio mixing
  Future<bool> exportVideo({
    required String outputPath,
    required List<ExportClip> clips,
    required int width,
    required int height,
    required double frameRate,
    String codec = 'libx264',
    String preset = 'medium',
    int crf = 23,
    String? audioCodec,
    int? audioBitrate,
    Function(double progress)? onProgress,
  }) async {
    _log('Exporting video to: $outputPath');
    _log('Clips: ${clips.length}, Resolution: ${width}x$height, FPS: $frameRate');

    if (clips.isEmpty) {
      _logError('No clips to export');
      return false;
    }

    try {
      // Calculate total duration for progress tracking
      Duration totalDuration = Duration.zero;
      for (final clip in clips) {
        final clipEnd = clip.timelineStart + clip.duration;
        if (clipEnd > totalDuration) {
          totalDuration = clipEnd;
        }
      }

      // Set up progress callback
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
          final time = stats.getTime();
          if (time > 0 && totalDuration.inMilliseconds > 0) {
            final progress = time / totalDuration.inMilliseconds;
            onProgress(progress.clamp(0.0, 1.0));
          }
        });
      }

      // Build complex filter for multiple clips
      final command = _buildExportCommand(
        clips: clips,
        outputPath: outputPath,
        width: width,
        height: height,
        frameRate: frameRate,
        codec: codec,
        preset: preset,
        crf: crf,
        audioCodec: audioCodec ?? 'aac',
        audioBitrate: audioBitrate ?? 128000,
        totalDuration: totalDuration,
      );

      _log('Running export command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clean up callback
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback(null);
        onProgress(1.0);
      }

      if (ReturnCode.isSuccess(returnCode)) {
        _log('Export completed successfully');
        return true;
      }

      final logs = await session.getAllLogsAsString();
      _logError('Export failed', logs);
      return false;
    } catch (e) {
      _logError('Export error', e);
      return false;
    }
  }

  /// Build FFmpeg command for exporting multiple clips
  String _buildExportCommand({
    required List<ExportClip> clips,
    required String outputPath,
    required int width,
    required int height,
    required double frameRate,
    required String codec,
    required String preset,
    required int crf,
    required String audioCodec,
    required int audioBitrate,
    required Duration totalDuration,
  }) {
    final buffer = StringBuffer();

    // Input files
    for (int i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final ss = _formatTimestamp(clip.sourceStart);
      final t = _formatTimestamp(clip.duration);
      buffer.write('-ss $ss -t $t -i "${clip.sourcePath}" ');
    }

    // Complex filter for compositing
    final filterBuffer = StringBuffer();

    // Video processing
    for (int i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final delay = clip.timelineStart.inMilliseconds;

      // Scale and pad each clip
      filterBuffer.write(
        '[$i:v]scale=$width:$height:force_original_aspect_ratio=decrease,'
        'pad=$width:$height:(ow-iw)/2:(oh-ih)/2,'
        'setpts=PTS-STARTPTS+${delay / 1000}/TB[v$i];',
      );
    }

    // Audio processing
    for (int i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final delay = clip.timelineStart.inMilliseconds;

      filterBuffer.write(
        '[$i:a]volume=${clip.volume},'
        'adelay=$delay|$delay,'
        'asetpts=PTS-STARTPTS[a$i];',
      );
    }

    // Concatenate or overlay videos
    if (clips.length == 1) {
      filterBuffer.write('[v0][a0]concat=n=1:v=1:a=1[outv][outa]');
    } else {
      // Overlay all video streams
      String currentVideo = 'v0';
      for (int i = 1; i < clips.length; i++) {
        final nextLabel = 'tmp$i';
        filterBuffer.write(
          '[$currentVideo][v$i]overlay=shortest=0[${i == clips.length - 1 ? 'outv' : nextLabel}];',
        );
        currentVideo = nextLabel;
      }

      // Mix all audio streams
      final audioInputs = List.generate(clips.length, (i) => '[a$i]').join();
      filterBuffer.write(
        '${audioInputs}amix=inputs=${clips.length}:normalize=0[outa]',
      );
    }

    buffer.write('-filter_complex "${filterBuffer.toString()}" ');
    buffer.write('-map "[outv]" -map "[outa]" ');

    // Output settings
    buffer.write('-c:v $codec -preset $preset -crf $crf ');
    buffer.write('-c:a $audioCodec -b:a ${audioBitrate ~/ 1000}k ');
    buffer.write('-r $frameRate ');
    buffer.write('-y "$outputPath"');

    return buffer.toString();
  }

  /// Transcode media to ProRes format for editing
  /// ProRes is an intermediate codec optimized for editing performance
  Future<String?> transcodeToProRes(
    String inputPath,
    String outputPath, {
    String profile = 'proxy', // proxy, lt, standard, hq
    Function(double progress)? onProgress,
  }) async {
    _log('Transcoding to ProRes ($profile): $inputPath -> $outputPath');

    try {
      // Get input media info for progress tracking
      final info = await getMediaInfo(inputPath);
      if (info == null) {
        _logError('Could not get media info for transcoding');
        return null;
      }

      // Map profile names to FFmpeg values
      final profileMap = {
        'proxy': '0',
        'lt': '1',
        'standard': '2',
        'hq': '3',
      };
      final profileValue = profileMap[profile] ?? '0';

      // Set up progress callback
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
          final time = stats.getTime();
          if (time > 0 && info.duration.inMilliseconds > 0) {
            final progress = time / info.duration.inMilliseconds;
            onProgress(progress.clamp(0.0, 1.0));
          }
        });
      }

      // Build command
      final command = '-i "$inputPath" '
          '-c:v prores_ks -profile:v $profileValue '
          '-c:a pcm_s16le '
          '-y "$outputPath"';

      _log('Running transcode command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clean up callback
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback(null);
        onProgress(1.0);
      }

      if (ReturnCode.isSuccess(returnCode)) {
        _log('Transcode completed successfully');
        return outputPath;
      }

      final logs = await session.getAllLogsAsString();
      _logError('Transcode failed', logs);
      return null;
    } catch (e) {
      _logError('Transcode error', e);
      return null;
    }
  }

  /// Transcode media to an editor-friendly format
  /// Uses H.264 with fast decode settings for preview performance
  Future<String?> transcodeForEditing(
    String inputPath,
    String outputPath, {
    int? maxWidth,
    int? maxHeight,
    double? frameRate,
    Function(double progress)? onProgress,
  }) async {
    _log('Transcoding for editing: $inputPath -> $outputPath');

    try {
      final info = await getMediaInfo(inputPath);
      if (info == null) {
        _logError('Could not get media info for transcoding');
        return null;
      }

      // Set up progress callback
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
          final time = stats.getTime();
          if (time > 0 && info.duration.inMilliseconds > 0) {
            final progress = time / info.duration.inMilliseconds;
            onProgress(progress.clamp(0.0, 1.0));
          }
        });
      }

      // Build scale filter if needed
      String scaleFilter = '';
      if (maxWidth != null || maxHeight != null) {
        final w = maxWidth ?? -2;
        final h = maxHeight ?? -2;
        scaleFilter = '-vf "scale=$w:$h:force_original_aspect_ratio=decrease" ';
      }

      // Build frame rate option
      String fpsOption = '';
      if (frameRate != null) {
        fpsOption = '-r $frameRate ';
      }

      // Use fast decode preset for editing
      final command = '-i "$inputPath" '
          '-c:v libx264 -preset ultrafast -crf 18 '
          '-tune fastdecode '
          '$scaleFilter$fpsOption'
          '-c:a aac -b:a 192k '
          '-movflags +faststart '
          '-y "$outputPath"';

      _log('Running transcode command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clean up callback
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback(null);
        onProgress(1.0);
      }

      if (ReturnCode.isSuccess(returnCode)) {
        _log('Transcode completed successfully');
        return outputPath;
      }

      final logs = await session.getAllLogsAsString();
      _logError('Transcode failed', logs);
      return null;
    } catch (e) {
      _logError('Transcode error', e);
      return null;
    }
  }

  /// Extract audio track from a video file
  Future<String?> extractAudio(
    String inputPath,
    String outputPath, {
    String codec = 'aac',
    int bitrate = 192000,
    Function(double progress)? onProgress,
  }) async {
    _log('Extracting audio: $inputPath -> $outputPath');

    try {
      final info = await getMediaInfo(inputPath);
      if (info == null || !info.hasAudio) {
        _logError('No audio stream found');
        return null;
      }

      // Set up progress callback
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
          final time = stats.getTime();
          if (time > 0 && info.duration.inMilliseconds > 0) {
            final progress = time / info.duration.inMilliseconds;
            onProgress(progress.clamp(0.0, 1.0));
          }
        });
      }

      final command = '-i "$inputPath" '
          '-vn '
          '-c:a $codec -b:a ${bitrate ~/ 1000}k '
          '-y "$outputPath"';

      _log('Running audio extraction: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clean up callback
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback(null);
        onProgress(1.0);
      }

      if (ReturnCode.isSuccess(returnCode)) {
        _log('Audio extraction completed');
        return outputPath;
      }

      final logs = await session.getAllLogsAsString();
      _logError('Audio extraction failed', logs);
      return null;
    } catch (e) {
      _logError('Audio extraction error', e);
      return null;
    }
  }

  /// Generate thumbnail strip from video (multiple frames)
  /// Useful for timeline preview
  Future<List<Uint8List>?> generateThumbnailStrip(
    String filePath, {
    int count = 10,
    int? width,
    int? height,
  }) async {
    _log('Generating $count thumbnails from: $filePath');

    try {
      final info = await getMediaInfo(filePath);
      if (info == null || !info.hasVideo) {
        _logError('No video stream found');
        return null;
      }

      final thumbnails = <Uint8List>[];
      final interval = info.duration.inMilliseconds / (count + 1);

      for (int i = 1; i <= count; i++) {
        final timestamp = Duration(milliseconds: (interval * i).round());
        final frame = await extractFrame(
          filePath,
          timestamp,
          width: width,
          height: height,
        );

        if (frame != null) {
          thumbnails.add(frame);
        }
      }

      if (thumbnails.isEmpty) {
        _logError('No thumbnails generated');
        return null;
      }

      _log('Generated ${thumbnails.length} thumbnails');
      return thumbnails;
    } catch (e) {
      _logError('Thumbnail generation error', e);
      return null;
    }
  }

  /// Cancel all running FFmpeg operations
  Future<void> cancelAll() async {
    _log('Cancelling all FFmpeg operations');
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

  /// Execute an FFmpeg command and return the output
  /// Used for commands that produce text output (like silencedetect)
  Future<String> executeCommandWithOutput(List<String> args) async {
    final command = args.join(' ');
    _log('Executing FFmpeg command: $command');

    final session = await FFmpegKit.execute(command);
    final output = await session.getAllLogsAsString() ?? '';
    return output;
  }

  /// Execute an FFmpeg command with optional progress callback
  Future<bool> executeCommand(
    List<String> args, {
    Function(double progress)? onProgress,
    Duration? totalDuration,
  }) async {
    final command = args.join(' ');
    _log('Executing FFmpeg command: $command');

    try {
      // Set up progress callback
      if (onProgress != null && totalDuration != null) {
        FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
          final time = stats.getTime();
          if (time > 0 && totalDuration.inMilliseconds > 0) {
            final progress = time / totalDuration.inMilliseconds;
            onProgress(progress.clamp(0.0, 1.0));
          }
        });
      }

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clean up callback
      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback(null);
        onProgress(1.0);
      }

      if (ReturnCode.isSuccess(returnCode)) {
        _log('Command completed successfully');
        return true;
      }

      final logs = await session.getAllLogsAsString();
      _logError('Command failed', logs);
      return false;
    } catch (e) {
      _logError('Command execution error', e);
      return false;
    }
  }
}
