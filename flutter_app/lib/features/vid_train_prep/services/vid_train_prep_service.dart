import 'dart:io';
import 'dart:convert';

import '../models/vid_train_prep_models.dart';

/// Service for FFmpeg operations in VidTrainPrep.
///
/// Uses direct `Process.run` calls to `ffmpeg` and `ffprobe` binaries
/// for Linux desktop compatibility. FFmpegKit has issues on Linux,
/// so we use the native process approach.
class VidTrainPrepService {
  static const String _tag = 'VidTrainPrepService';

  /// Log a debug message
  void _log(String message) {
    print('[$_tag] $message');
  }

  /// Log an error message
  void _logError(String message, [Object? error]) {
    print('[$_tag] ERROR: $message${error != null ? ' - $error' : ''}');
  }

  /// Probe video file to get metadata using ffprobe.
  ///
  /// Returns a [VideoSource] with all metadata populated, or null if probing fails.
  /// The returned VideoSource will have an empty `id` field that should be set by the caller.
  Future<VideoSource?> probeVideo(String filePath) async {
    try {
      _log('Probing video: $filePath');

      final result = await Process.run('ffprobe', [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        filePath,
      ]);

      if (result.exitCode != 0) {
        _logError('ffprobe failed with exit code ${result.exitCode}', result.stderr);
        return null;
      }

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final streams = json['streams'] as List<dynamic>?;

      if (streams == null || streams.isEmpty) {
        _logError('No streams found in video');
        return null;
      }

      final videoStream = streams.firstWhere(
        (s) => s['codec_type'] == 'video',
        orElse: () => null,
      ) as Map<String, dynamic>?;

      if (videoStream == null) {
        _logError('No video stream found');
        return null;
      }

      final format = json['format'] as Map<String, dynamic>?;
      if (format == null) {
        _logError('No format information found');
        return null;
      }

      final duration = double.tryParse(format['duration']?.toString() ?? '0') ?? 0;

      // Parse frame rate (e.g., "30/1" or "30000/1001" or "30")
      final fpsStr = videoStream['r_frame_rate']?.toString() ?? '30/1';
      double fps;
      if (fpsStr.contains('/')) {
        final fpsParts = fpsStr.split('/');
        final numerator = double.tryParse(fpsParts[0]) ?? 30;
        final denominator = double.tryParse(fpsParts[1]) ?? 1;
        fps = denominator != 0 ? numerator / denominator : 30;
      } else {
        fps = double.tryParse(fpsStr) ?? 30;
      }

      final width = videoStream['width'] as int? ?? 0;
      final height = videoStream['height'] as int? ?? 0;
      final frameCount = (duration * fps).round();
      final fileSizeBytes = int.tryParse(format['size']?.toString() ?? '0') ?? 0;
      final fileName = filePath.split('/').last;

      _log('Probed video: ${width}x$height, ${fps.toStringAsFixed(2)} fps, '
          '$frameCount frames, ${duration.toStringAsFixed(2)}s');

      return VideoSource(
        id: '', // Will be set by caller
        filePath: filePath,
        fileName: fileName,
        duration: Duration(milliseconds: (duration * 1000).round()),
        fps: fps,
        width: width,
        height: height,
        frameCount: frameCount,
        fileSizeBytes: fileSizeBytes,
      );
    } catch (e, stack) {
      _logError('Error probing video', e);
      print('[$_tag] Stack trace: $stack');
      return null;
    }
  }

  /// Extract cropped clip from source video.
  ///
  /// Applies the following FFmpeg operations:
  /// 1. Seek to start position (-ss)
  /// 2. Crop to specified region
  /// 3. Scale to fit within maxLongestEdge while preserving aspect ratio
  /// 4. Convert to target FPS
  /// 5. Limit to maxFrames
  /// 6. Encode with libx264 (fast preset, CRF 18)
  ///
  /// Returns true if extraction succeeded.
  Future<bool> extractCroppedClip({
    required String inputPath,
    required String outputPath,
    required Duration start,
    required Duration duration,
    required CropRegion crop,
    required int sourceWidth,
    required int sourceHeight,
    required int targetFps,
    required int maxFrames,
    required int maxLongestEdge,
    bool includeAudio = false,
  }) async {
    try {
      final cropRect = crop.toPixelRect(sourceWidth, sourceHeight);
      final cropX = cropRect.left.round();
      final cropY = cropRect.top.round();
      final cropW = cropRect.width.round();
      final cropH = cropRect.height.round();

      // Ensure crop dimensions are even (required by libx264)
      final evenCropW = (cropW ~/ 2) * 2;
      final evenCropH = (cropH ~/ 2) * 2;

      // Build filter chain:
      // 1. crop=w:h:x:y - Crop the video
      // 2. scale=maxEdge:-2:force_original_aspect_ratio=decrease - Scale down to fit
      // 3. fps=targetFps - Convert frame rate
      final filters = <String>[
        'crop=$evenCropW:$evenCropH:$cropX:$cropY',
        'scale=$maxLongestEdge:-2:force_original_aspect_ratio=decrease',
        'fps=$targetFps',
      ];

      final args = <String>[
        '-y', // Overwrite output
        '-ss', _formatTimestamp(start), // Seek to start (before input for fast seek)
        '-i', inputPath,
        '-t', _formatTimestamp(duration), // Duration to extract
        '-vf', filters.join(','),
        '-frames:v', maxFrames.toString(),
        '-c:v', 'libx264',
        '-preset', 'fast',
        '-crf', '18',
        if (!includeAudio) '-an', // Remove audio
        outputPath,
      ];

      return await _runFFmpeg(args);
    } catch (e) {
      _logError('Error extracting cropped clip', e);
      return false;
    }
  }

  /// Extract uncropped clip (just trim, scale, and fps convert).
  ///
  /// Similar to [extractCroppedClip] but without the crop operation.
  /// Useful for exporting the original frame without cropping.
  ///
  /// Returns true if extraction succeeded.
  Future<bool> extractUncroppedClip({
    required String inputPath,
    required String outputPath,
    required Duration start,
    required Duration duration,
    required int targetFps,
    required int maxFrames,
    required int maxLongestEdge,
    bool includeAudio = false,
  }) async {
    try {
      // Build filter chain (without crop):
      // 1. scale=maxEdge:-2:force_original_aspect_ratio=decrease - Scale down to fit
      // 2. fps=targetFps - Convert frame rate
      final filters = <String>[
        'scale=$maxLongestEdge:-2:force_original_aspect_ratio=decrease',
        'fps=$targetFps',
      ];

      final args = <String>[
        '-y', // Overwrite output
        '-ss', _formatTimestamp(start), // Seek to start
        '-i', inputPath,
        '-t', _formatTimestamp(duration), // Duration to extract
        '-vf', filters.join(','),
        '-frames:v', maxFrames.toString(),
        '-c:v', 'libx264',
        '-preset', 'fast',
        '-crf', '18',
        if (!includeAudio) '-an', // Remove audio
        outputPath,
      ];

      return await _runFFmpeg(args);
    } catch (e) {
      _logError('Error extracting uncropped clip', e);
      return false;
    }
  }

  /// Extract a single frame as an image file.
  ///
  /// Extracts the frame at [timestamp] and optionally applies cropping
  /// and scaling. Supports output formats based on file extension (jpg, png).
  ///
  /// Returns true if extraction succeeded.
  Future<bool> extractFirstFrame({
    required String inputPath,
    required String outputPath,
    required Duration timestamp,
    CropRegion? crop,
    int? sourceWidth,
    int? sourceHeight,
    int? maxLongestEdge,
  }) async {
    try {
      final filters = <String>[];

      // Add crop filter if specified
      if (crop != null && sourceWidth != null && sourceHeight != null) {
        final cropRect = crop.toPixelRect(sourceWidth, sourceHeight);
        final cropX = cropRect.left.round();
        final cropY = cropRect.top.round();
        final cropW = (cropRect.width.round() ~/ 2) * 2; // Ensure even
        final cropH = (cropRect.height.round() ~/ 2) * 2; // Ensure even
        filters.add('crop=$cropW:$cropH:$cropX:$cropY');
      }

      // Add scale filter if specified
      if (maxLongestEdge != null) {
        filters.add('scale=$maxLongestEdge:-2:force_original_aspect_ratio=decrease');
      }

      final args = <String>[
        '-y', // Overwrite output
        '-ss', _formatTimestamp(timestamp), // Seek to timestamp
        '-i', inputPath,
        '-vframes', '1', // Extract single frame
        if (filters.isNotEmpty) ...['-vf', filters.join(',')],
        outputPath,
      ];

      return await _runFFmpeg(args);
    } catch (e) {
      _logError('Error extracting first frame', e);
      return false;
    }
  }

  /// Generate a thumbnail for a video at approximately 10% into the video.
  ///
  /// Creates a small thumbnail image (160px longest edge) for preview purposes.
  /// Returns the path to the generated thumbnail, or null if generation failed.
  Future<String?> generateThumbnail(String videoPath, String outputDir) async {
    try {
      // Probe first to get duration
      final info = await probeVideo(videoPath);
      if (info == null) {
        _logError('Could not probe video for thumbnail generation');
        return null;
      }

      // Calculate timestamp at 10% into the video
      final timestamp = Duration(
        milliseconds: (info.duration.inMilliseconds * 0.1).round(),
      );

      // Generate output filename
      final baseName = info.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final outputPath = '$outputDir/${baseName}_thumb.jpg';

      // Ensure output directory exists
      final dir = Directory(outputDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final success = await extractFirstFrame(
        inputPath: videoPath,
        outputPath: outputPath,
        timestamp: timestamp,
        maxLongestEdge: 160,
      );

      if (success) {
        _log('Generated thumbnail: $outputPath');
        return outputPath;
      }

      _logError('Failed to generate thumbnail');
      return null;
    } catch (e) {
      _logError('Error generating thumbnail', e);
      return null;
    }
  }

  /// Get detailed video stream information.
  ///
  /// Returns additional stream details not included in [probeVideo],
  /// such as codec name, pixel format, bit rate, etc.
  Future<Map<String, dynamic>?> getVideoStreamInfo(String filePath) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_streams',
        '-select_streams', 'v:0', // Only video stream
        filePath,
      ]);

      if (result.exitCode != 0) {
        _logError('ffprobe stream info failed', result.stderr);
        return null;
      }

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final streams = json['streams'] as List<dynamic>?;

      if (streams == null || streams.isEmpty) {
        return null;
      }

      return streams.first as Map<String, dynamic>;
    } catch (e) {
      _logError('Error getting video stream info', e);
      return null;
    }
  }

  /// Check if FFmpeg is available on the system.
  Future<bool> isFFmpegAvailable() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Check if FFprobe is available on the system.
  Future<bool> isFFprobeAvailable() async {
    try {
      final result = await Process.run('ffprobe', ['-version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Get FFmpeg version string.
  Future<String?> getFFmpegVersion() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        // Extract first line which contains version info
        final firstLine = output.split('\n').first;
        return firstLine;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Run an FFmpeg command with the given arguments.
  ///
  /// Logs the command and result for debugging purposes.
  /// Returns true if FFmpeg exited with code 0.
  Future<bool> _runFFmpeg(List<String> args) async {
    try {
      _log('Running: ffmpeg ${args.join(' ')}');

      final result = await Process.run('ffmpeg', args);

      if (result.exitCode != 0) {
        _logError('FFmpeg failed with exit code ${result.exitCode}');
        final stderr = result.stderr as String;
        if (stderr.isNotEmpty) {
          // Log last few lines of stderr for debugging
          final lines = stderr.split('\n');
          final lastLines = lines.length > 10
              ? lines.sublist(lines.length - 10)
              : lines;
          for (final line in lastLines) {
            if (line.trim().isNotEmpty) {
              print('[$_tag] stderr: $line');
            }
          }
        }
        return false;
      }

      return true;
    } catch (e) {
      _logError('Error running FFmpeg', e);
      return false;
    }
  }

  /// Format a Duration as an FFmpeg timestamp (HH:MM:SS.mmm).
  String _formatTimestamp(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    final millis = d.inMilliseconds % 1000;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}';
  }
}
