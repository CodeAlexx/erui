import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'session_provider.dart';

/// Gallery state provider
final galleryProvider =
    StateNotifierProvider<GalleryNotifier, GalleryState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final session = ref.watch(sessionProvider);
  return GalleryNotifier(apiService, session);
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
  final ApiService _apiService;
  final SessionState _session;

  GalleryNotifier(this._apiService, this._session)
      : super(const GalleryState());

  /// Load images from folder (ERI history)
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

    final targetFolder = folder ?? state.currentFolder;

    try {
      // Use ListHistory endpoint which scans ERI output folder
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/ListHistory',
        data: {
          'path': targetFolder,
          'max': state.pageSize * (state.currentPage + 1),
          'depth': 5,
        },
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final files = (data['files'] as List<dynamic>?)
                ?.map((f) => GalleryImage.fromJson(f as Map<String, dynamic>))
                .toList() ??
            [];

        state = state.copyWith(
          images: files,
          folders: (data['folders'] as List<dynamic>?)
                  ?.map((f) => f as String)
                  .toList() ??
              [],
          currentFolder: targetFolder,
          totalCount: files.length,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Failed to load images',
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

  /// Navigate to folder
  Future<void> navigateToFolder(String folder) async {
    state = state.copyWith(
      currentFolder: folder,
      images: [],
      currentPage: 0,
    );
    await loadImages();
  }

  /// Delete image
  Future<bool> deleteImage(String id) async {
    try {
      final response = await _apiService.post('/api/DeleteImage', data: {
        'session_id': _session.sessionId,
        'image_id': id,
      });

      if (response.isSuccess) {
        state = state.copyWith(
          images: state.images.where((img) => img.id != id).toList(),
          totalCount: state.totalCount - 1,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Search images by prompt
  Future<void> search(String query) async {
    state = state.copyWith(isLoading: true, error: null, images: []);

    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/SearchImages',
        data: {
          'session_id': _session.sessionId,
          'query': query,
          'page': 0,
          'page_size': state.pageSize,
        },
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final files = (data['files'] as List<dynamic>?)
                ?.map((f) => GalleryImage.fromJson(f as Map<String, dynamic>))
                .toList() ??
            [];

        state = state.copyWith(
          images: files,
          totalCount: data['total_count'] as int? ?? files.length,
          currentPage: 0,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Search failed',
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
