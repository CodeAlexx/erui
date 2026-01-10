// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import '../models/editor_models.dart';

/// Web implementation using HTML5 video and canvas for thumbnail extraction
Future<List<Uint8List>> extractThumbnails({
  required EditorClip clip,
  required int thumbnailCount,
  required int thumbnailHeight,
}) async {
  final sourcePath = clip.sourcePath;
  if (sourcePath == null || sourcePath.isEmpty) {
    print('[WebThumbnail] No source path provided');
    return [];
  }

  print('[WebThumbnail] Extracting $thumbnailCount thumbnails from: $sourcePath');
  final thumbnails = <Uint8List>[];

  try {
    // Create video element
    final video = html.VideoElement()
      ..src = sourcePath
      ..crossOrigin = 'anonymous'
      ..muted = true
      ..preload = 'auto'; // Use 'auto' for better compatibility

    print('[WebThumbnail] Video element created, waiting for metadata...');

    // Wait for video to have enough data to seek
    await video.onCanPlay.first.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('Video canplay timeout'),
    );

    print('[WebThumbnail] Video ready - size: ${video.videoWidth}x${video.videoHeight}, duration: ${video.duration}s');

    // Calculate aspect ratio and canvas size
    final aspectRatio = video.videoWidth / video.videoHeight;
    final canvasWidth = (thumbnailHeight * aspectRatio).round();
    final canvasHeight = thumbnailHeight;

    print('[WebThumbnail] Canvas size: ${canvasWidth}x$canvasHeight');

    // Create canvas for frame capture
    final canvas = html.CanvasElement(width: canvasWidth, height: canvasHeight);
    final ctx = canvas.context2D;

    // Calculate timestamps for thumbnails
    final videoDuration = video.duration;
    final clipDuration = clip.duration.inSeconds;
    final interval = clipDuration / thumbnailCount;

    for (int i = 0; i < thumbnailCount; i++) {
      final timestamp = clip.sourceStart.inSeconds + (interval * i);

      // Clamp to actual video duration
      final seekTime = timestamp.clamp(0.0, videoDuration - 0.1);

      try {
        // Seek to timestamp
        video.currentTime = seekTime;

        // Wait for seek to complete
        await video.onSeeked.first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Video seek timeout at $seekTime'),
        );

        // Draw frame to canvas (scaled to canvas size)
        ctx.drawImageScaled(video, 0, 0, canvasWidth, canvasHeight);

        // Get JPEG data from canvas
        final dataUrl = canvas.toDataUrl('image/jpeg', 0.8);
        final base64Data = dataUrl.split(',')[1];
        final bytes = _base64ToBytes(base64Data);
        thumbnails.add(bytes);
        print('[WebThumbnail] Extracted frame $i at ${seekTime.toStringAsFixed(2)}s (${bytes.length} bytes)');
      } catch (e) {
        print('[WebThumbnail] Failed to extract frame $i at $timestamp: $e');
        // Continue with next frame
      }
    }

    // Clean up
    video.src = '';
    video.remove();
    
    print('[WebThumbnail] Extraction complete: ${thumbnails.length} thumbnails');
  } catch (e) {
    print('[WebThumbnail] FAILED: $e');
  }

  return thumbnails;
}

/// Convert base64 string to Uint8List
Uint8List _base64ToBytes(String base64) {
  final decoded = html.window.atob(base64);
  final bytes = Uint8List(decoded.length);
  for (int i = 0; i < decoded.length; i++) {
    bytes[i] = decoded.codeUnitAt(i);
  }
  return bytes;
}
