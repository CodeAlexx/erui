import 'dart:io';
import 'dart:typed_data';

import '../models/editor_models.dart';

/// Native implementation using system FFmpeg for desktop platforms.
/// Uses Process.run to call ffmpeg directly (works on Linux/macOS/Windows).
/// For HTTP URLs, downloads to temp file first since FFmpeg has issues with streaming.
Future<List<Uint8List>> extractThumbnails({
  required EditorClip clip,
  required int thumbnailCount,
  required int thumbnailHeight,
}) async {
  print('[Native] extractThumbnails called for ${clip.name}');

  final sourcePath = clip.sourcePath;
  if (sourcePath == null || sourcePath.isEmpty) {
    print('[Native] No source path for clip');
    return [];
  }

  // Check if it's a URL or local file
  final isUrl = sourcePath.startsWith('http://') || sourcePath.startsWith('https://');
  String localPath = sourcePath;

  // For HTTP URLs, download to temp file first
  if (isUrl) {
    print('[Native] Downloading video from URL: $sourcePath');
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(sourcePath));
      final response = await request.close();
      if (response.statusCode == 200) {
        final tempFile = File('${Directory.systemTemp.path}/eriui_video_${clip.id}.mp4');
        final bytes = await response.fold<List<int>>(
          <int>[],
          (previous, element) => previous..addAll(element),
        );
        await tempFile.writeAsBytes(bytes);
        localPath = tempFile.path;
        print('[Native] Downloaded to: $localPath (${bytes.length} bytes)');
      } else {
        print('[Native] Failed to download video: HTTP ${response.statusCode}');
        return [];
      }
      client.close();
    } catch (e) {
      print('[Native] Error downloading video: $e');
      return [];
    }
  } else {
    // For local files, verify they exist
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      print('[Native] Source file does not exist: $sourcePath');
      return [];
    }
  }

  print('[Native] Using local path: $localPath');

  // Create temp directory for thumbnails
  final tempDir = Directory.systemTemp;
  final outputDir = Directory('${tempDir.path}/eriui_thumbnails/${clip.id}');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // Calculate timestamps for thumbnails
  final duration = clip.duration.inSeconds;
  final interval = duration / thumbnailCount;

  print('[Native] Extracting $thumbnailCount thumbnails from $localPath');
  print('[Native] Duration: $duration seconds, interval: $interval seconds');

  final thumbnails = <Uint8List>[];

  for (int i = 0; i < thumbnailCount; i++) {
    final timestamp = clip.sourceStart.inSeconds + (interval * i);
    final outputPath = '${outputDir.path}/thumb_$i.jpg';

    // Build FFmpeg arguments
    final args = [
      '-y',  // Overwrite output
      '-ss', timestamp.toStringAsFixed(3),  // Seek to timestamp
      '-i', localPath,  // Input file (local path, downloaded if was URL)
      '-vframes', '1',  // Extract one frame
      '-vf', 'scale=-1:$thumbnailHeight',  // Scale to height
      '-q:v', '3',  // Quality level
      '-update', '1',  // Required for single image output
      outputPath,  // Output file
    ];

    try {
      print('[Native] Running: ffmpeg ${args.join(' ')}');
      final result = await Process.run('ffmpeg', args);

      if (result.exitCode == 0) {
        final file = File(outputPath);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          thumbnails.add(bytes);
          print('[Native] Extracted thumbnail $i: ${bytes.length} bytes');
          // Clean up temp file
          await file.delete();
        }
      } else {
        print('[Native] FFmpeg failed for thumbnail $i: ${result.stderr}');
      }
    } catch (e) {
      print('[Native] Failed to extract thumbnail at $timestamp: $e');
    }
  }

  // Clean up temp directory
  try {
    if (outputDir.existsSync()) {
      await outputDir.delete(recursive: true);
    }
    // Clean up downloaded video file if we downloaded from URL
    if (isUrl && localPath != sourcePath) {
      final tempVideo = File(localPath);
      if (tempVideo.existsSync()) {
        await tempVideo.delete();
        print('[Native] Cleaned up temp video: $localPath');
      }
    }
  } catch (_) {}

  print('[Native] Extracted ${thumbnails.length} thumbnails total');
  return thumbnails;
}
