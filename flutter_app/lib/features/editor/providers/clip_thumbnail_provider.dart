import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';

// Conditional imports for platform-specific code
import 'clip_thumbnail_stub.dart'
    if (dart.library.io) 'clip_thumbnail_native.dart'
    if (dart.library.html) 'clip_thumbnail_web.dart' as platform_thumbnail;

// Debug: print platform at startup
final _platformInit = () {
  print('[ThumbnailProvider] Platform: ${Platform.operatingSystem}');
  print('[ThumbnailProvider] Using native implementation: dart.library.io available');
  return true;
}();

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
  /// Use 64px for better quality and visibility
  static const int thumbnailHeight = 64;

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
    print('[ThumbnailCache] extractThumbnails called for clip: ${clip.name}, id: $clipId, count: $thumbnailCount');

    // Return cached thumbnails if available
    if (_thumbnailCache.containsKey(clipId)) {
      print('[ThumbnailCache] Returning cached thumbnails for $clipId');
      return _thumbnailCache[clipId]!;
    }

    // Wait for pending extraction
    if (_pendingExtractions.containsKey(clipId)) {
      print('[ThumbnailCache] Waiting for pending extraction for $clipId');
      return _pendingExtractions[clipId]!.future;
    }

    // Start new extraction
    print('[ThumbnailCache] Starting new extraction for $clipId');
    final completer = Completer<List<Uint8List>>();
    _pendingExtractions[clipId] = completer;

    try {
      print('[ThumbnailCache] Calling platform_thumbnail.extractThumbnails...');
      final thumbnails = await platform_thumbnail.extractThumbnails(
        clip: clip,
        thumbnailCount: thumbnailCount,
        thumbnailHeight: thumbnailHeight,
      );
      print('[ThumbnailCache] Extraction complete: ${thumbnails.length} thumbnails');
      _thumbnailCache[clipId] = thumbnails;
      completer.complete(thumbnails);
    } catch (e) {
      print('[ThumbnailCache] Extraction FAILED: $e');
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
/// Uses clipId as key (not the whole clip object) to prevent cache invalidation on rebuild
final clipThumbnailsProvider = FutureProvider.family<List<Uint8List>, ({EditorClip clip, int count})>(
  (ref, params) async {
    final cache = ref.watch(clipThumbnailCacheProvider);
    print('[Provider] clipThumbnailsProvider called for ${params.clip.id}');
    final result = await cache.extractThumbnails(
      clip: params.clip,
      thumbnailCount: params.count,
    );
    print('[Provider] Returning ${result.length} thumbnails for ${params.clip.id}');
    return result;
  },
);

/// Alternative provider keyed by clip ID string for stable caching
final clipThumbnailsByIdProvider = FutureProvider.family<List<Uint8List>, String>(
  (ref, clipId) async {
    final cache = ref.watch(clipThumbnailCacheProvider);
    // Return cached thumbnails directly if available
    final cached = cache.getThumbnails(clipId);
    if (cached != null) {
      print('[Provider] Returning cached thumbnails for $clipId');
      return cached;
    }
    // If not cached, return empty - extraction must be triggered separately
    print('[Provider] No cached thumbnails for $clipId');
    return [];
  },
);
