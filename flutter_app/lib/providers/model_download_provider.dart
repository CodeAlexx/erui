import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

/// Model download provider for tracking download state
final modelDownloadProvider =
    StateNotifierProvider<ModelDownloadNotifier, ModelDownloadState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ModelDownloadNotifier(apiService);
});

/// Download item representing a single model download
class DownloadItem {
  final String id;
  final String url;
  final String name;
  final String modelType;
  final String targetFolder;
  final DownloadStatus status;
  final double progress;
  final int? totalBytes;
  final int? downloadedBytes;
  final String? error;
  final DateTime createdAt;
  final CancelToken? cancelToken;

  const DownloadItem({
    required this.id,
    required this.url,
    required this.name,
    required this.modelType,
    required this.targetFolder,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.totalBytes,
    this.downloadedBytes,
    this.error,
    required this.createdAt,
    this.cancelToken,
  });

  DownloadItem copyWith({
    String? id,
    String? url,
    String? name,
    String? modelType,
    String? targetFolder,
    DownloadStatus? status,
    double? progress,
    int? totalBytes,
    int? downloadedBytes,
    String? error,
    DateTime? createdAt,
    CancelToken? cancelToken,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      url: url ?? this.url,
      name: name ?? this.name,
      modelType: modelType ?? this.modelType,
      targetFolder: targetFolder ?? this.targetFolder,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      cancelToken: cancelToken ?? this.cancelToken,
    );
  }

  /// Get formatted download speed
  String get formattedProgress {
    if (totalBytes == null || totalBytes == 0) return '${(progress * 100).toStringAsFixed(0)}%';
    if (downloadedBytes == null) return '${(progress * 100).toStringAsFixed(0)}%';

    final downloaded = _formatBytes(downloadedBytes!);
    final total = _formatBytes(totalBytes!);
    return '$downloaded / $total';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Download status enum
enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// Model download state
class ModelDownloadState {
  final List<DownloadItem> downloads;
  final bool isProcessing;
  final String? currentDownloadId;

  const ModelDownloadState({
    this.downloads = const [],
    this.isProcessing = false,
    this.currentDownloadId,
  });

  /// Get active downloads
  List<DownloadItem> get activeDownloads =>
      downloads.where((d) => d.status == DownloadStatus.downloading || d.status == DownloadStatus.queued).toList();

  /// Get completed downloads
  List<DownloadItem> get completedDownloads =>
      downloads.where((d) => d.status == DownloadStatus.completed).toList();

  /// Get failed downloads
  List<DownloadItem> get failedDownloads =>
      downloads.where((d) => d.status == DownloadStatus.failed || d.status == DownloadStatus.cancelled).toList();

  /// Get current download
  DownloadItem? get currentDownload =>
      currentDownloadId != null ? downloads.firstWhere((d) => d.id == currentDownloadId, orElse: () => downloads.first) : null;

  ModelDownloadState copyWith({
    List<DownloadItem>? downloads,
    bool? isProcessing,
    String? currentDownloadId,
  }) {
    return ModelDownloadState(
      downloads: downloads ?? this.downloads,
      isProcessing: isProcessing ?? this.isProcessing,
      currentDownloadId: currentDownloadId ?? this.currentDownloadId,
    );
  }
}

/// Model type detection result
class CivitAIModelInfo {
  final int modelId;
  final int? versionId;
  final String name;
  final String type;
  final String? downloadUrl;
  final int? fileSize;
  final String? fileName;
  final String? previewUrl;

  const CivitAIModelInfo({
    required this.modelId,
    this.versionId,
    required this.name,
    required this.type,
    this.downloadUrl,
    this.fileSize,
    this.fileName,
    this.previewUrl,
  });

  /// Get the target folder based on model type
  String get targetFolder {
    switch (type.toLowerCase()) {
      case 'checkpoint':
        return 'Stable-Diffusion';
      case 'lora':
        return 'Lora';
      case 'textualinversion':
      case 'embedding':
        return 'Embedding';
      case 'vae':
        return 'VAE';
      case 'controlnet':
        return 'ControlNet';
      case 'hypernetwork':
        return 'hypernetwork';
      case 'aestheticgradient':
        return 'aesthetic_embeddings';
      case 'poses':
        return 'poses';
      case 'wildcards':
        return 'wildcards';
      case 'locon':
        return 'Lora';
      default:
        return 'other';
    }
  }
}

/// Model download notifier
class ModelDownloadNotifier extends StateNotifier<ModelDownloadState> {
  final ApiService _apiService;
  final Dio _dio;

  ModelDownloadNotifier(this._apiService)
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(hours: 2),
        )),
        super(const ModelDownloadState());

  /// Parse CivitAI URL to get model info
  Future<CivitAIModelInfo?> parseCivitAIUrl(String input) async {
    // Support formats:
    // - https://civitai.com/models/12345
    // - https://civitai.com/models/12345/model-name
    // - https://civitai.com/models/12345?modelVersionId=67890
    // - https://civitai.com/api/download/models/67890
    // - 12345 (just model ID)
    // - 12345@67890 (model ID @ version ID)

    int? modelId;
    int? versionId;

    // Check if it's a direct API download URL
    final apiDownloadRegex = RegExp(r'civitai\.com/api/download/models/(\d+)');
    final apiMatch = apiDownloadRegex.firstMatch(input);
    if (apiMatch != null) {
      versionId = int.parse(apiMatch.group(1)!);
      // Fetch version info to get model ID
      final versionInfo = await _fetchVersionInfo(versionId);
      if (versionInfo != null) {
        return versionInfo;
      }
    }

    // Check standard model URL
    final modelRegex = RegExp(r'civitai\.com/models/(\d+)(?:/[^?]*)?(?:\?.*modelVersionId=(\d+))?');
    final modelMatch = modelRegex.firstMatch(input);
    if (modelMatch != null) {
      modelId = int.parse(modelMatch.group(1)!);
      if (modelMatch.group(2) != null) {
        versionId = int.parse(modelMatch.group(2)!);
      }
    }

    // Check for simple ID format
    if (modelId == null) {
      final simpleRegex = RegExp(r'^(\d+)(?:@(\d+))?$');
      final simpleMatch = simpleRegex.firstMatch(input.trim());
      if (simpleMatch != null) {
        modelId = int.parse(simpleMatch.group(1)!);
        if (simpleMatch.group(2) != null) {
          versionId = int.parse(simpleMatch.group(2)!);
        }
      }
    }

    if (modelId == null) {
      return null;
    }

    // Fetch model info from CivitAI API
    return await _fetchModelInfo(modelId, versionId);
  }

  /// Fetch model info from CivitAI API
  Future<CivitAIModelInfo?> _fetchModelInfo(int modelId, int? versionId) async {
    try {
      final response = await _dio.get('https://civitai.com/api/v1/models/$modelId');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final name = data['name'] as String? ?? 'Unknown';
        final type = data['type'] as String? ?? 'Checkpoint';
        final versions = data['modelVersions'] as List<dynamic>?;

        if (versions == null || versions.isEmpty) {
          return CivitAIModelInfo(
            modelId: modelId,
            name: name,
            type: type,
          );
        }

        // Get specific version or latest
        Map<String, dynamic>? version;
        if (versionId != null) {
          version = versions.firstWhere(
            (v) => v['id'] == versionId,
            orElse: () => versions.first,
          ) as Map<String, dynamic>;
        } else {
          version = versions.first as Map<String, dynamic>;
        }

        final files = version['files'] as List<dynamic>?;
        if (files == null || files.isEmpty) {
          return CivitAIModelInfo(
            modelId: modelId,
            versionId: version['id'] as int?,
            name: name,
            type: type,
          );
        }

        // Get primary file (usually the model file)
        final primaryFile = files.firstWhere(
          (f) => f['primary'] == true,
          orElse: () => files.first,
        ) as Map<String, dynamic>;

        // Get preview image
        final images = version['images'] as List<dynamic>?;
        String? previewUrl;
        if (images != null && images.isNotEmpty) {
          previewUrl = images.first['url'] as String?;
        }

        return CivitAIModelInfo(
          modelId: modelId,
          versionId: version['id'] as int?,
          name: name,
          type: type,
          downloadUrl: primaryFile['downloadUrl'] as String?,
          fileSize: primaryFile['sizeKB'] != null
              ? ((primaryFile['sizeKB'] as num) * 1024).round()
              : null,
          fileName: primaryFile['name'] as String?,
          previewUrl: previewUrl,
        );
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  /// Fetch version info directly
  Future<CivitAIModelInfo?> _fetchVersionInfo(int versionId) async {
    try {
      final response = await _dio.get('https://civitai.com/api/v1/model-versions/$versionId');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final modelId = data['modelId'] as int;
        final name = data['model']?['name'] as String? ?? 'Unknown';
        final type = data['model']?['type'] as String? ?? 'Checkpoint';

        final files = data['files'] as List<dynamic>?;
        if (files == null || files.isEmpty) {
          return CivitAIModelInfo(
            modelId: modelId,
            versionId: versionId,
            name: name,
            type: type,
          );
        }

        final primaryFile = files.firstWhere(
          (f) => f['primary'] == true,
          orElse: () => files.first,
        ) as Map<String, dynamic>;

        // Get preview image
        final images = data['images'] as List<dynamic>?;
        String? previewUrl;
        if (images != null && images.isNotEmpty) {
          previewUrl = images.first['url'] as String?;
        }

        return CivitAIModelInfo(
          modelId: modelId,
          versionId: versionId,
          name: name,
          type: type,
          downloadUrl: primaryFile['downloadUrl'] as String?,
          fileSize: primaryFile['sizeKB'] != null
              ? ((primaryFile['sizeKB'] as num) * 1024).round()
              : null,
          fileName: primaryFile['name'] as String?,
          previewUrl: previewUrl,
        );
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  /// Add a download to the queue
  Future<String?> addDownload({
    required String url,
    required String name,
    required String modelType,
    required String targetFolder,
    int? totalBytes,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final cancelToken = CancelToken();

    final download = DownloadItem(
      id: id,
      url: url,
      name: name,
      modelType: modelType,
      targetFolder: targetFolder,
      status: DownloadStatus.queued,
      totalBytes: totalBytes,
      createdAt: DateTime.now(),
      cancelToken: cancelToken,
    );

    state = state.copyWith(
      downloads: [...state.downloads, download],
    );

    // Start processing queue if not already
    if (!state.isProcessing) {
      _processQueue();
    }

    return id;
  }

  /// Add download from CivitAI URL
  Future<String?> addDownloadFromCivitAI(String input) async {
    final info = await parseCivitAIUrl(input);
    if (info == null || info.downloadUrl == null) {
      return null;
    }

    return addDownload(
      url: info.downloadUrl!,
      name: info.fileName ?? '${info.name}.safetensors',
      modelType: info.type,
      targetFolder: info.targetFolder,
      totalBytes: info.fileSize,
    );
  }

  /// Process download queue
  Future<void> _processQueue() async {
    if (state.isProcessing) return;

    state = state.copyWith(isProcessing: true);

    while (true) {
      // Find next queued download
      final nextDownload = state.downloads.firstWhere(
        (d) => d.status == DownloadStatus.queued,
        orElse: () => DownloadItem(
          id: '',
          url: '',
          name: '',
          modelType: '',
          targetFolder: '',
          createdAt: DateTime.now(),
        ),
      );

      if (nextDownload.id.isEmpty) {
        break;
      }

      state = state.copyWith(currentDownloadId: nextDownload.id);

      // Update status to downloading
      _updateDownload(nextDownload.id, status: DownloadStatus.downloading);

      try {
        await _performDownload(nextDownload);
        _updateDownload(nextDownload.id,
          status: DownloadStatus.completed,
          progress: 1.0,
        );
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) {
          _updateDownload(nextDownload.id,
            status: DownloadStatus.cancelled,
            error: 'Download cancelled',
          );
        } else {
          _updateDownload(nextDownload.id,
            status: DownloadStatus.failed,
            error: e.toString(),
          );
        }
      }
    }

    state = state.copyWith(isProcessing: false, currentDownloadId: null);
  }

  /// Perform the actual download via backend proxy
  Future<void> _performDownload(DownloadItem download) async {
    // Use backend to proxy the download
    final response = await _apiService.post<Map<String, dynamic>>(
      '/API/DownloadModel',
      data: {
        'url': download.url,
        'name': download.name,
        'folder': download.targetFolder,
      },
    );

    if (!response.isSuccess) {
      throw Exception(response.error ?? 'Download failed');
    }

    // Poll for download progress
    final downloadId = response.data?['download_id'] as String?;
    if (downloadId == null) {
      throw Exception('No download ID returned');
    }

    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if cancelled
      if (download.cancelToken?.isCancelled ?? false) {
        // Cancel on backend too
        await _apiService.post<Map<String, dynamic>>(
          '/API/CancelDownload',
          data: {'download_id': downloadId},
        );
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.cancel,
        );
      }

      final statusResponse = await _apiService.post<Map<String, dynamic>>(
        '/API/GetDownloadStatus',
        data: {'download_id': downloadId},
      );

      if (!statusResponse.isSuccess) {
        throw Exception(statusResponse.error ?? 'Failed to get status');
      }

      final status = statusResponse.data!;
      final progressValue = status['progress'] as double? ?? 0.0;
      final downloadedBytes = status['downloaded_bytes'] as int?;
      final totalBytes = status['total_bytes'] as int?;
      final isDone = status['done'] as bool? ?? false;
      final errorMsg = status['error'] as String?;

      _updateDownload(download.id,
        progress: progressValue,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
      );

      if (errorMsg != null) {
        throw Exception(errorMsg);
      }

      if (isDone) {
        break;
      }
    }
  }

  /// Update download item
  void _updateDownload(String id, {
    DownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? error,
  }) {
    state = state.copyWith(
      downloads: state.downloads.map((d) {
        if (d.id == id) {
          return d.copyWith(
            status: status,
            progress: progress,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            error: error,
          );
        }
        return d;
      }).toList(),
    );
  }

  /// Cancel a download
  void cancelDownload(String id) {
    final download = state.downloads.firstWhere(
      (d) => d.id == id,
      orElse: () => DownloadItem(
        id: '',
        url: '',
        name: '',
        modelType: '',
        targetFolder: '',
        createdAt: DateTime.now(),
      ),
    );

    if (download.id.isNotEmpty) {
      download.cancelToken?.cancel();
      _updateDownload(id, status: DownloadStatus.cancelled, error: 'Cancelled by user');
    }
  }

  /// Remove a download from the list
  void removeDownload(String id) {
    state = state.copyWith(
      downloads: state.downloads.where((d) => d.id != id).toList(),
    );
  }

  /// Clear all completed/failed downloads
  void clearFinished() {
    state = state.copyWith(
      downloads: state.downloads.where((d) =>
        d.status == DownloadStatus.queued || d.status == DownloadStatus.downloading
      ).toList(),
    );
  }

  /// Retry a failed download
  void retryDownload(String id) {
    _updateDownload(id, status: DownloadStatus.queued, error: null, progress: 0.0);

    if (!state.isProcessing) {
      _processQueue();
    }
  }
}
