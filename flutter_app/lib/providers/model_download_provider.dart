import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Model download provider for tracking download state
/// Note: ComfyUI does not have built-in model download capabilities.
/// This provider maintains the interface for future external download solutions.
final modelDownloadProvider =
    StateNotifierProvider<ModelDownloadNotifier, ModelDownloadState>((ref) {
  return ModelDownloadNotifier();
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
  notSupported,
}

/// Model download state
class ModelDownloadState {
  final List<DownloadItem> downloads;
  final bool isProcessing;
  final String? currentDownloadId;
  final bool isSupported;
  final String? notSupportedMessage;

  const ModelDownloadState({
    this.downloads = const [],
    this.isProcessing = false,
    this.currentDownloadId,
    this.isSupported = false,
    this.notSupportedMessage = 'Model downloading is not available with direct ComfyUI connection. '
        'Please download models manually and place them in the appropriate ComfyUI folders.',
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
    bool? isSupported,
    String? notSupportedMessage,
  }) {
    return ModelDownloadState(
      downloads: downloads ?? this.downloads,
      isProcessing: isProcessing ?? this.isProcessing,
      currentDownloadId: currentDownloadId ?? this.currentDownloadId,
      isSupported: isSupported ?? this.isSupported,
      notSupportedMessage: notSupportedMessage ?? this.notSupportedMessage,
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
        return 'checkpoints';
      case 'lora':
        return 'loras';
      case 'textualinversion':
      case 'embedding':
        return 'embeddings';
      case 'vae':
        return 'vae';
      case 'controlnet':
        return 'controlnet';
      case 'hypernetwork':
        return 'hypernetworks';
      case 'locon':
        return 'loras';
      case 'upscaler':
        return 'upscale_models';
      default:
        return 'other';
    }
  }
}

/// Model download notifier
/// Note: ComfyUI does not have built-in model download capabilities.
/// This notifier maintains the interface but returns "not supported" for all operations.
class ModelDownloadNotifier extends StateNotifier<ModelDownloadState> {
  final Dio _dio;

  ModelDownloadNotifier()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(hours: 2),
        )),
        super(const ModelDownloadState());

  /// Parse CivitAI URL to get model info
  /// This can still be used to get model information even if downloading is not supported
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
  /// Note: This always fails with ComfyUI as it doesn't support model downloads
  Future<String?> addDownload({
    required String url,
    required String name,
    required String modelType,
    required String targetFolder,
    int? totalBytes,
  }) async {
    // ComfyUI doesn't support model downloads
    // Return error immediately
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final download = DownloadItem(
      id: id,
      url: url,
      name: name,
      modelType: modelType,
      targetFolder: targetFolder,
      status: DownloadStatus.notSupported,
      totalBytes: totalBytes,
      createdAt: DateTime.now(),
      error: 'Model downloading is not available with direct ComfyUI connection. '
          'Please download this model manually from: $url\n'
          'Place the downloaded file in: ComfyUI/models/$targetFolder/',
    );

    state = state.copyWith(
      downloads: [...state.downloads, download],
    );

    return null; // Return null to indicate failure
  }

  /// Add download from CivitAI URL
  /// Note: This always fails with ComfyUI as it doesn't support model downloads
  Future<String?> addDownloadFromCivitAI(String input) async {
    final info = await parseCivitAIUrl(input);
    if (info == null) {
      return null;
    }

    // Even if we get model info, downloading is not supported
    return addDownload(
      url: info.downloadUrl ?? 'https://civitai.com/models/${info.modelId}',
      name: info.fileName ?? '${info.name}.safetensors',
      modelType: info.type,
      targetFolder: info.targetFolder,
      totalBytes: info.fileSize,
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

  /// Retry a failed download (still won't work with ComfyUI)
  void retryDownload(String id) {
    _updateDownload(id,
      status: DownloadStatus.notSupported,
      error: 'Model downloading is not available with direct ComfyUI connection.',
      progress: 0.0,
    );
  }
}
