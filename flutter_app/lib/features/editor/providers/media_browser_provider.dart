import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../services/ffmpeg_service.dart';

// Helper for file existence check (no-op on web)
bool _checkFileExists(String path) {
  if (kIsWeb) return true;
  // On non-web, we'd use dart:io but for now return true
  // Real desktop builds would import dart:io conditionally
  return true;
}

/// Supported media file extensions
const supportedVideoExtensions = ['.mp4', '.webm', '.mov', '.mkv', '.avi', '.gif'];
const supportedImageExtensions = ['.png', '.jpg', '.jpeg', '.webp', '.bmp', '.tiff'];
const supportedMediaExtensions = [
  ...supportedVideoExtensions,
  ...supportedImageExtensions
];

/// File type classification for imported media
enum MediaFileType {
  video,
  image,
}

/// Represents an imported media file in the project
class ImportedMedia {
  /// Unique identifier for this media item
  final String id;

  /// Absolute path to the media file
  final String filePath;

  /// File name without directory
  final String fileName;

  /// Media type (video or image)
  final MediaFileType type;

  /// Media information (duration, resolution, etc.)
  final MediaInfo? mediaInfo;

  /// Thumbnail bytes for preview
  final Uint8List? thumbnail;

  /// Whether the media info is still being loaded
  final bool isLoading;

  /// Error message if loading failed
  final String? error;

  const ImportedMedia({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.type,
    this.mediaInfo,
    this.thumbnail,
    this.isLoading = false,
    this.error,
    this.bytes,
  });

  /// Get display duration for videos
  String get displayDuration {
    if (type != MediaFileType.video || mediaInfo == null) {
      return '';
    }
    final duration = mediaInfo!.duration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get display resolution
  String get displayResolution {
    if (mediaInfo?.width == null || mediaInfo?.height == null) {
      return '';
    }
    return '${mediaInfo!.width}x${mediaInfo!.height}';
  }

  /// Check if file still exists on disk (always true on web since we have bytes)
  bool get exists => kIsWeb ? true : _checkFileExists(filePath);

  /// Bytes data for web platform
  final Uint8List? bytes;

  ImportedMedia copyWith({
    String? id,
    String? filePath,
    String? fileName,
    MediaFileType? type,
    MediaInfo? mediaInfo,
    Uint8List? thumbnail,
    bool? isLoading,
    String? error,
    Uint8List? bytes,
  }) {
    return ImportedMedia(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      type: type ?? this.type,
      mediaInfo: mediaInfo ?? this.mediaInfo,
      thumbnail: thumbnail ?? this.thumbnail,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      bytes: bytes ?? this.bytes,
    );
  }
}

/// State container for the media browser
class MediaBrowserState {
  /// List of imported media files
  final List<ImportedMedia> media;

  /// Currently selected media ID (for multi-select, use a Set instead)
  final String? selectedId;

  /// Whether import is in progress
  final bool isImporting;

  const MediaBrowserState({
    this.media = const [],
    this.selectedId,
    this.isImporting = false,
  });

  MediaBrowserState copyWith({
    List<ImportedMedia>? media,
    String? selectedId,
    bool? isImporting,
    bool clearSelection = false,
  }) {
    return MediaBrowserState(
      media: media ?? this.media,
      selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
      isImporting: isImporting ?? this.isImporting,
    );
  }

  /// Get currently selected media item
  ImportedMedia? get selectedMedia {
    if (selectedId == null) return null;
    try {
      return media.firstWhere((m) => m.id == selectedId);
    } catch (_) {
      return null;
    }
  }
}

/// State notifier for managing imported media
class MediaBrowserNotifier extends StateNotifier<MediaBrowserState> {
  final FFmpegService _ffmpegService;

  MediaBrowserNotifier(this._ffmpegService) : super(const MediaBrowserState());

  /// Generate unique ID for media items
  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Determine media type from file extension
  MediaFileType _getMediaType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    if (supportedVideoExtensions.contains(ext)) {
      return MediaFileType.video;
    }
    return MediaFileType.image;
  }

  /// Import media from bytes (for web platform)
  Future<void> importFromBytes(List<({String name, Uint8List bytes})> files) async {
    if (files.isEmpty) return;

    state = state.copyWith(isImporting: true);

    final newMedia = <ImportedMedia>[];

    for (final file in files) {
      // Check file extension
      final ext = path.extension(file.name).toLowerCase();
      if (!supportedMediaExtensions.contains(ext)) {
        continue;
      }

      final id = _generateId();
      final type = _getMediaType(file.name);

      // For web, use bytes as thumbnail for images
      Uint8List? thumbnail;
      if (type == MediaFileType.image) {
        thumbnail = file.bytes;
      }

      newMedia.add(ImportedMedia(
        id: id,
        filePath: 'web://${file.name}', // Virtual path for web
        fileName: file.name,
        type: type,
        bytes: file.bytes,
        thumbnail: thumbnail,
        isLoading: type == MediaFileType.video, // Videos need processing
      ));
    }

    state = state.copyWith(
      media: [...state.media, ...newMedia],
      isImporting: false,
    );

    // For videos on web, we'd need to process bytes for thumbnails
    // For now, mark them as loaded
    for (final media in newMedia) {
      if (media.type == MediaFileType.video) {
        _markVideoLoaded(media.id);
      }
    }
  }

  /// Import media from Object URLs (for web platform - memory efficient)
  /// Uses blob: URLs instead of loading all bytes into memory
  Future<void> importFromUrls(List<dynamic> files) async {
    if (files.isEmpty) return;

    state = state.copyWith(isImporting: true);

    final newMedia = <ImportedMedia>[];

    for (final file in files) {
      final name = file.name as String;
      final blobUrl = file.blobUrl as String;
      
      // Check file extension
      final ext = path.extension(name).toLowerCase();
      if (!supportedMediaExtensions.contains(ext)) {
        continue;
      }

      final id = _generateId();
      final type = _getMediaType(name);

      print('DEBUG: Importing $name with blob URL: $blobUrl');

      newMedia.add(ImportedMedia(
        id: id,
        filePath: blobUrl, // Use blob URL as the file path for web
        fileName: name,
        type: type,
        thumbnail: null, // Will be generated asynchronously
        isLoading: true,
      ));
    }

    state = state.copyWith(
      media: [...state.media, ...newMedia],
      isImporting: false,
    );

    // Mark videos as loaded (thumbnails generated separately by clip widget)
    for (final media in newMedia) {
      if (media.type == MediaFileType.video) {
        // Delay slightly to allow UI to update
        Future.delayed(const Duration(milliseconds: 100), () {
          _markVideoLoaded(media.id);
        });
      } else {
        // For images, we could fetch the blob and store as thumbnail
        _markVideoLoaded(media.id);
      }
    }
  }

  /// Mark video as loaded (web fallback)
  void _markVideoLoaded(String mediaId) {
    final updatedMedia = state.media.map((m) {
      if (m.id == mediaId) {
        return m.copyWith(isLoading: false);
      }
      return m;
    }).toList();
    state = state.copyWith(media: updatedMedia);
  }

  /// Import media files from paths (desktop/mobile only - use importFromBytes on web)
  Future<void> importFiles(List<String> filePaths) async {
    if (filePaths.isEmpty || kIsWeb) return;

    state = state.copyWith(isImporting: true);

    final newMedia = <ImportedMedia>[];

    for (final filePath in filePaths) {
      // Check if already imported
      if (state.media.any((m) => m.filePath == filePath)) {
        continue;
      }

      // Check file extension
      final ext = path.extension(filePath).toLowerCase();
      if (!supportedMediaExtensions.contains(ext)) {
        continue;
      }

      final id = _generateId();
      final fileName = path.basename(filePath);
      final type = _getMediaType(filePath);

      // Add with loading state
      newMedia.add(ImportedMedia(
        id: id,
        filePath: filePath,
        fileName: fileName,
        type: type,
        isLoading: true,
      ));
    }

    // Add all new media to state
    state = state.copyWith(
      media: [...state.media, ...newMedia],
      isImporting: false,
    );

    // Load media info for each file asynchronously
    for (final media in newMedia) {
      _loadMediaInfo(media.id);
    }
  }

  /// Load media info and thumbnail for a media item (desktop only)
  Future<void> _loadMediaInfo(String mediaId) async {
    // This only runs on desktop (web uses importFromBytes which sets data directly)
    if (kIsWeb) return;

    final index = state.media.indexWhere((m) => m.id == mediaId);
    if (index == -1) return;

    final media = state.media[index];

    try {
      MediaInfo? info;
      Uint8List? thumbnail;

      if (media.type == MediaFileType.video) {
        // Get video info via FFmpeg
        info = await _ffmpegService.getMediaInfo(media.filePath);

        // Extract frame at 1 second (more likely to hit a keyframe than 0)
        // Add timeout to prevent blocking on large/problematic videos
        if (info != null && info.hasVideo) {
          try {
            thumbnail = await _ffmpegService.extractFrame(
              media.filePath,
              const Duration(seconds: 1),
              width: 160,
              height: 90,
            ).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print('DEBUG: Thumbnail extraction timed out for ${media.filePath}');
                return null;
              },
            );
          } catch (e) {
            print('DEBUG: Thumbnail extraction failed: $e');
            thumbnail = null;
          }
        }
      } else {
        // For images, use bytes if available, otherwise probe for info
        if (media.bytes != null) {
          thumbnail = media.bytes;
        }
        // Get image dimensions by probing
        info = await _ffmpegService.getMediaInfo(media.filePath);
      }

      // Update state with loaded info
      final updatedMedia = state.media.map((m) {
        if (m.id == mediaId) {
          return m.copyWith(
            mediaInfo: info,
            thumbnail: thumbnail,
            isLoading: false,
          );
        }
        return m;
      }).toList();

      state = state.copyWith(media: updatedMedia);
    } catch (e) {
      // Update with error state
      final updatedMedia = state.media.map((m) {
        if (m.id == mediaId) {
          return m.copyWith(
            isLoading: false,
            error: 'Failed to load media info: $e',
          );
        }
        return m;
      }).toList();

      state = state.copyWith(media: updatedMedia);
    }
  }

  /// Select a media item
  void selectMedia(String? mediaId) {
    state = state.copyWith(selectedId: mediaId, clearSelection: mediaId == null);
  }

  /// Remove a media item from the project
  void removeMedia(String mediaId) {
    final updatedMedia = state.media.where((m) => m.id != mediaId).toList();
    final newSelectedId = state.selectedId == mediaId ? null : state.selectedId;

    state = MediaBrowserState(
      media: updatedMedia,
      selectedId: newSelectedId,
      isImporting: state.isImporting,
    );
  }

  /// Remove all media items
  void clearAll() {
    state = const MediaBrowserState();
  }

  /// Refresh media info for a specific item
  Future<void> refreshMedia(String mediaId) async {
    final index = state.media.indexWhere((m) => m.id == mediaId);
    if (index == -1) return;

    // Set loading state
    final updatedMedia = state.media.map((m) {
      if (m.id == mediaId) {
        return m.copyWith(isLoading: true, error: null);
      }
      return m;
    }).toList();

    state = state.copyWith(media: updatedMedia);

    // Reload info
    await _loadMediaInfo(mediaId);
  }

  /// Get media item by ID
  ImportedMedia? getMedia(String mediaId) {
    try {
      return state.media.firstWhere((m) => m.id == mediaId);
    } catch (_) {
      return null;
    }
  }
}

/// Provider for the media browser state
final mediaBrowserProvider =
    StateNotifierProvider<MediaBrowserNotifier, MediaBrowserState>((ref) {
  final ffmpegService = ref.watch(ffmpegServiceProvider);
  return MediaBrowserNotifier(ffmpegService);
});

/// Provider for the list of imported media
final importedMediaProvider = Provider<List<ImportedMedia>>((ref) {
  return ref.watch(mediaBrowserProvider).media;
});

/// Provider for the currently selected media
final selectedMediaProvider = Provider<ImportedMedia?>((ref) {
  return ref.watch(mediaBrowserProvider).selectedMedia;
});

/// Provider for checking if import is in progress
final isImportingProvider = Provider<bool>((ref) {
  return ref.watch(mediaBrowserProvider).isImporting;
});
