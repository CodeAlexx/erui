import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';

import '../models/editor_models.dart';

/// Native implementation using FFmpeg for desktop/mobile platforms
Future<List<Uint8List>> extractThumbnails({
  required EditorClip clip,
  required int thumbnailCount,
  required int thumbnailHeight,
}) async {
  final sourcePath = clip.sourcePath;
  if (sourcePath == null || sourcePath.isEmpty) {
    return [];
  }

  final tempDir = await getTemporaryDirectory();
  final outputDir = Directory('${tempDir.path}/clip_thumbnails/${clip.id}');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // Calculate timestamps for thumbnails
  final duration = clip.duration.inSeconds;
  final interval = duration / thumbnailCount;

  final thumbnails = <Uint8List>[];

  for (int i = 0; i < thumbnailCount; i++) {
    final timestamp = clip.sourceStart.inSeconds + (interval * i);
    final outputPath = '${outputDir.path}/thumb_$i.jpg';

    // Extract frame using FFmpeg
    final command = '-y -ss $timestamp -i "$sourcePath" '
        '-vframes 1 -vf "scale=-1:$thumbnailHeight" '
        '-q:v 3 "$outputPath"';

    try {
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (returnCode?.isValueSuccess() == true) {
        final file = File(outputPath);
        if (file.existsSync()) {
          thumbnails.add(await file.readAsBytes());
          // Clean up temp file
          await file.delete();
        }
      }
    } catch (e) {
      // Skip failed frame
      print('Failed to extract thumbnail at $timestamp: $e');
    }
  }

  // Clean up temp directory
  try {
    if (outputDir.existsSync()) {
      await outputDir.delete(recursive: true);
    }
  } catch (_) {}

  return thumbnails;
}
