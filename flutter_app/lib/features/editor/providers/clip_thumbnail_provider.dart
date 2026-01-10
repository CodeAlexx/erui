import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';

// Conditional imports for platform-specific code
import 'clip_thumbnail_stub.dart'
    if (dart.library.io) 'clip_thumbnail_native.dart'
    if (dart.library.html) 'clip_thumbnail_web.dart' as platform_thumbnail;

// =============================================================================
// AI TESTING NOTES:
// - Web testing: flutter run -d chrome --web-port=3333
// - Desktop testing: flutter run -d linux  
// - Web uses HTML5 video + canvas for thumbnails
// - Desktop uses FFmpeg for thumbnails
// =============================================================================

/// Thumbnail cache for video clips on the timeline.
/// Uses platform-adaptive extraction: HTML5 video for web, FFmpeg for desktop.
class ClipThumbnailCache {
  /// Cache of thumbnails: clipId -> list of frame thumbnails
  final Map<String, List<Uint8List>> _thumbnailCache = {};

  /// Pending extraction tasks
  final Map<String, Completer<List<Uint8List>>> _pendingExtractions = {};

  /// Thumbnail height (width is calculated from aspect ratio)
  static const int thumbnailHeight = 48;

  /// Number of thumbnails to extract per clip (based on clip width)
  static int getThumbnailCount(double clipWidthPixels) {
    // One thumbnail per ~60 pixels of clip width
    return (clipWidthPixels / 60).ceil().clamp(1, 20);
  }

  /// Get cached thumbnails for a clip, or null if not yet extracted
  List<Uint8List>? getThumbnails(String clipId) {
    return _thumbnailCache[clipId];
  }

  /// Check if thumbnails are being extracted for a clip
  bool isExtracting(String clipId) {
    return _pendingExtractions.containsKey(clipId);
  }

  /// Extract thumbnails for a video clip (platform-adaptive)
  Future<List<Uint8List>> extractThumbnails({
    required EditorClip clip,
    required int thumbnailCount,
  }) async {
    final clipId = clip.id;

    // Return cached thumbnails if available
    if (_thumbnailCache.containsKey(clipId)) {
      return _thumbnailCache[clipId]!;
    }

    // Wait for pending extraction
    if (_pendingExtractions.containsKey(clipId)) {
      return _pendingExtractions[clipId]!.future;
    }

    // Start new extraction
    final completer = Completer<List<Uint8List>>();
    _pendingExtractions[clipId] = completer;

    try {
      final thumbnails = await platform_thumbnail.extractThumbnails(
        clip: clip,
        thumbnailCount: thumbnailCount,
        thumbnailHeight: thumbnailHeight,
      );
      _thumbnailCache[clipId] = thumbnails;
      completer.complete(thumbnails);
    } catch (e) {
      print('Thumbnail extraction failed: $e');
      completer.complete([]); // Return empty list on error
    } finally {
      _pendingExtractions.remove(clipId);
    }

    return completer.future;
  }

  /// Clear cache for a specific clip
  void clearClip(String clipId) {
    _thumbnailCache.remove(clipId);
  }

  /// Clear all cached thumbnails
  void clearAll() {
    _thumbnailCache.clear();
  }
}

/// Provider for the thumbnail cache
final clipThumbnailCacheProvider = Provider<ClipThumbnailCache>((ref) {
  return ClipThumbnailCache();
});

/// Provider to get thumbnails for a specific clip
final clipThumbnailsProvider = FutureProvider.family<List<Uint8List>, ({EditorClip clip, int count})>(
  (ref, params) async {
    final cache = ref.watch(clipThumbnailCacheProvider);
    return cache.extractThumbnails(
      clip: params.clip,
      thumbnailCount: params.count,
    );
  },
);
