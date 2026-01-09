import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/comfyui_service.dart';

/// Gallery state provider
final galleryProvider =
    StateNotifierProvider<GalleryNotifier, GalleryState>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  return GalleryNotifier(comfyService);
});

/// Gallery state
class GalleryState {
  final List<GalleryImage> images;
  final List<String> folders;
  final String currentFolder;
  final bool isLoading;
  final String? error;
  final int totalCount;
  final int currentPage;
  final int pageSize;

  const GalleryState({
    this.images = const [],
    this.folders = const [],
    this.currentFolder = '',
    this.isLoading = false,
    this.error,
    this.totalCount = 0,
    this.currentPage = 0,
    this.pageSize = 50,
  });

  int get totalPages => (totalCount / pageSize).ceil();
  bool get hasMore => currentPage < totalPages - 1;

  GalleryState copyWith({
    List<GalleryImage>? images,
    List<String>? folders,
    String? currentFolder,
    bool? isLoading,
    String? error,
    int? totalCount,
    int? currentPage,
    int? pageSize,
  }) {
    return GalleryState(
      images: images ?? this.images,
      folders: folders ?? this.folders,
      currentFolder: currentFolder ?? this.currentFolder,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

/// Gallery image
class GalleryImage {
  final String id;
  final String filename;
  final String path;
  final String url;
  final String? thumbnailUrl;
  final int width;
  final int height;
  final int size;
  final DateTime createdAt;
  final String? prompt;
  final String? negativePrompt;
  final Map<String, dynamic>? metadata;

  const GalleryImage({
    required this.id,
    required this.filename,
    required this.path,
    required this.url,
    this.thumbnailUrl,
    required this.width,
    required this.height,
    required this.size,
    required this.createdAt,
    this.prompt,
    this.negativePrompt,
    this.metadata,
  });

  factory GalleryImage.fromJson(Map<String, dynamic> json) {
    // Extract metadata from ERI format
    final metadata = json['metadata'] as Map<String, dynamic>?;
    final suiParams = metadata?['sui_image_params'] as Map<String, dynamic>?;

    // Get prompt from various possible locations
    String? prompt = json['prompt'] as String?;
    String? negativePrompt = json['negative_prompt'] as String?;

    if (suiParams != null) {
      prompt ??= suiParams['prompt'] as String?;
      negativePrompt ??= suiParams['negativeprompt'] as String?;
    }

    // Parse date from various formats
    DateTime createdAt;
    if (json['date'] != null) {
      createdAt = DateTime.parse(json['date'] as String);
    } else if (json['created_at'] != null) {
      createdAt = DateTime.parse(json['created_at'] as String);
    } else {
      createdAt = DateTime.now();
    }

    return GalleryImage(
      id: json['id'] as String? ?? json['name'] as String? ?? json['filename'] as String? ?? '',
      filename: json['filename'] as String? ?? json['name'] as String? ?? '',
      path: json['path'] as String? ?? json['src'] as String? ?? '',
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      width: json['width'] as int? ?? suiParams?['width'] as int? ?? 0,
      height: json['height'] as int? ?? suiParams?['height'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      createdAt: createdAt,
      prompt: prompt,
      negativePrompt: negativePrompt,
      metadata: metadata,
    );
  }

  /// Create GalleryImage from ComfyUI history entry
  factory GalleryImage.fromComfyHistory(String promptId, Map<String, dynamic> historyEntry, ComfyUIService comfyService) {
    // Extract outputs from history entry
    final outputs = historyEntry['outputs'] as Map<String, dynamic>?;
    final prompt = historyEntry['prompt'] as List?;

    String? imageUrl;
    String filename = '';
    String subfolder = '';

    // Find first image in outputs
    if (outputs != null) {
      for (final nodeOutput in outputs.values) {
        if (nodeOutput is Map<String, dynamic>) {
          final images = nodeOutput['images'] as List?;
          if (images != null && images.isNotEmpty) {
            final img = images.first as Map<String, dynamic>;
            filename = img['filename'] as String? ?? '';
            subfolder = img['subfolder'] as String? ?? '';
            final type = img['type'] as String? ?? 'output';
            imageUrl = comfyService.getImageUrl(filename, subfolder: subfolder, type: type);
            break;
          }
        }
      }
    }

    // Try to extract prompt text from workflow
    String? promptText;
    if (prompt != null && prompt.isNotEmpty) {
      // prompt[0] is the workflow nodes
      final nodes = prompt[0] as Map<String, dynamic>?;
      if (nodes != null) {
        for (final node in nodes.values) {
          if (node is Map<String, dynamic>) {
            final classType = node['class_type'] as String?;
            if (classType == 'CLIPTextEncode') {
              final inputs = node['inputs'] as Map<String, dynamic>?;
              promptText ??= inputs?['text'] as String?;
            }
          }
        }
      }
    }

    return GalleryImage(
      id: promptId,
      filename: filename,
      path: '$subfolder/$filename',
      url: imageUrl ?? '',
      thumbnailUrl: imageUrl,
      width: 0, // ComfyUI history doesn't include dimensions
      height: 0,
      size: 0,
      createdAt: DateTime.now(), // ComfyUI history doesn't include timestamp
      prompt: promptText,
      negativePrompt: null,
      metadata: historyEntry,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'path': path,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'width': width,
      'height': height,
      'size': size,
      'created_at': createdAt.toIso8601String(),
      'prompt': prompt,
      'negative_prompt': negativePrompt,
      'metadata': metadata,
    };
  }

  /// Get formatted size
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get dimensions string
  String get dimensions => '${width}x$height';
}

/// Gallery notifier
class GalleryNotifier extends StateNotifier<GalleryState> {
  final ComfyUIService _comfyService;

  GalleryNotifier(this._comfyService)
      : super(const GalleryState());

  /// Load images from ComfyUI history
  Future<void> loadImages({String? folder, bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(
        images: [],
        currentPage: 0,
        isLoading: true,
        error: null,
      );
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      // Use ComfyUI history endpoint
      final history = await _comfyService.getAllHistory(maxItems: state.pageSize * (state.currentPage + 1));

      if (history != null) {
        final images = <GalleryImage>[];

        for (final entry in history.entries) {
          final promptId = entry.key;
          final historyEntry = entry.value as Map<String, dynamic>;

          // Skip entries without outputs
          final outputs = historyEntry['outputs'] as Map<String, dynamic>?;
          if (outputs == null || outputs.isEmpty) continue;

          // Check if any output has images
          bool hasImages = false;
          for (final nodeOutput in outputs.values) {
            if (nodeOutput is Map<String, dynamic>) {
              final nodeImages = nodeOutput['images'] as List?;
              if (nodeImages != null && nodeImages.isNotEmpty) {
                hasImages = true;
                break;
              }
            }
          }

          if (hasImages) {
            images.add(GalleryImage.fromComfyHistory(promptId, historyEntry, _comfyService));
          }
        }

        state = state.copyWith(
          images: images,
          folders: [], // ComfyUI doesn't have folder structure in history
          totalCount: images.length,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load history from ComfyUI',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load more images
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(currentPage: state.currentPage + 1);
    await loadImages();
  }

  /// Refresh images
  Future<void> refresh() async {
    await loadImages(refresh: true);
  }

  /// Navigate to folder (not applicable for ComfyUI history)
  Future<void> navigateToFolder(String folder) async {
    // ComfyUI history doesn't support folder navigation
    // This is a no-op but kept for API compatibility
  }

  /// Delete image by prompt ID (clears from ComfyUI history)
  Future<bool> deleteImage(String path) async {
    try {
      // For ComfyUI, we delete from history by prompt ID
      // The path might be the prompt ID
      await _comfyService.deleteHistory(promptIds: [path]);

      state = state.copyWith(
        images: state.images.where((img) => img.id != path && img.path != path).toList(),
        totalCount: state.totalCount - 1,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Search images by prompt (client-side filtering for ComfyUI)
  Future<void> search(String query) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load all history first
      final history = await _comfyService.getAllHistory(maxItems: 200);

      if (history != null) {
        final images = <GalleryImage>[];
        final lowerQuery = query.toLowerCase();

        for (final entry in history.entries) {
          final promptId = entry.key;
          final historyEntry = entry.value as Map<String, dynamic>;

          // Skip entries without outputs
          final outputs = historyEntry['outputs'] as Map<String, dynamic>?;
          if (outputs == null || outputs.isEmpty) continue;

          // Check if any output has images
          bool hasImages = false;
          for (final nodeOutput in outputs.values) {
            if (nodeOutput is Map<String, dynamic>) {
              final nodeImages = nodeOutput['images'] as List?;
              if (nodeImages != null && nodeImages.isNotEmpty) {
                hasImages = true;
                break;
              }
            }
          }

          if (!hasImages) continue;

          final galleryImage = GalleryImage.fromComfyHistory(promptId, historyEntry, _comfyService);

          // Search in prompt text
          if (galleryImage.prompt?.toLowerCase().contains(lowerQuery) == true ||
              galleryImage.filename.toLowerCase().contains(lowerQuery)) {
            images.add(galleryImage);
          }
        }

        state = state.copyWith(
          images: images,
          totalCount: images.length,
          currentPage: 0,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Search failed',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// Sort options for gallery
enum GallerySortOption {
  dateNewest,
  dateOldest,
  nameAsc,
  nameDesc,
  sizeSmallest,
  sizeLargest,
}

/// Gallery sort provider
final gallerySortProvider = StateProvider<GallerySortOption>((ref) {
  return GallerySortOption.dateNewest;
});

/// Gallery view mode provider
final galleryViewModeProvider = StateProvider<GalleryViewMode>((ref) {
  return GalleryViewMode.grid;
});

/// Gallery view modes
enum GalleryViewMode {
  grid,
  masonry,
  list,
}
