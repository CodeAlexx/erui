import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../core/program.dart';
import '../../utils/logging.dart';
import '../api.dart';
import '../api_call.dart';
import '../api_context.dart';

/// Download API endpoints for model downloading
class DownloadAPI {
  /// Active downloads
  static final Map<String, _ActiveDownload> _activeDownloads = {};
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(hours: 2),
  ));

  /// Register all download API endpoints
  static void register() {
    Api.registerCall(ApiCall(
      name: 'DownloadModel',
      description: 'Start downloading a model from URL',
      requiredPermissions: {'edit_models'},
      handler: _downloadModel,
    ));

    Api.registerCall(ApiCall(
      name: 'GetDownloadStatus',
      description: 'Get status of an active download',
      requiredPermissions: {'view_models'},
      handler: _getDownloadStatus,
    ));

    Api.registerCall(ApiCall(
      name: 'CancelDownload',
      description: 'Cancel an active download',
      requiredPermissions: {'edit_models'},
      handler: _cancelDownload,
    ));

    Api.registerCall(ApiCall(
      name: 'ListActiveDownloads',
      description: 'List all active downloads',
      requiredPermissions: {'view_models'},
      allowGet: true,
      handler: _listActiveDownloads,
    ));

    Api.registerCall(ApiCall(
      name: 'ParseCivitAIUrl',
      description: 'Parse CivitAI URL and get model info',
      requiredPermissions: {'view_models'},
      handler: _parseCivitAIUrl,
    ));
  }

  /// Start downloading a model
  static Future<Map<String, dynamic>> _downloadModel(ApiContext ctx) async {
    final url = ctx.require<String>('url');
    final name = ctx.require<String>('name');
    final folder = ctx.require<String>('folder');

    // Generate download ID
    final downloadId = DateTime.now().millisecondsSinceEpoch.toString();

    // Determine target path
    final modelRoot = Program.instance.serverSettings.paths.modelRoot;
    final targetDir = p.join(modelRoot, folder);
    final targetPath = p.join(targetDir, name);

    // Ensure target directory exists
    await Directory(targetDir).create(recursive: true);

    // Check if file already exists
    if (await File(targetPath).exists()) {
      throw ApiException('File already exists: $name');
    }

    // Create active download
    final download = _ActiveDownload(
      id: downloadId,
      url: url,
      name: name,
      folder: folder,
      targetPath: targetPath,
    );

    _activeDownloads[downloadId] = download;

    // Start download in background
    _startDownload(download);

    return {
      'download_id': downloadId,
      'name': name,
      'folder': folder,
      'target_path': targetPath,
    };
  }

  /// Start the actual download
  static Future<void> _startDownload(_ActiveDownload download) async {
    try {
      Logs.info('Starting download: ${download.name} from ${download.url}');

      final cancelToken = CancelToken();
      download.cancelToken = cancelToken;

      // Download with progress tracking
      await _dio.download(
        download.url,
        download.targetPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          download.downloadedBytes = received;
          if (total > 0) {
            download.totalBytes = total;
            download.progress = received / total;
          }
        },
        options: Options(
          headers: download.url.contains('civitai.com')
              ? {'Authorization': 'Bearer ${_getCivitaiKey()}'}
              : null,
        ),
      );

      download.isDone = true;
      download.progress = 1.0;
      Logs.info('Download completed: ${download.name}');

      // Refresh models
      await _refreshModelsForFolder(download.folder);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        download.error = 'Download cancelled';
        download.isCancelled = true;
        Logs.info('Download cancelled: ${download.name}');
      } else {
        download.error = e.message ?? 'Download failed';
        Logs.error('Download failed: ${download.name} - ${e.message}');
      }
      download.isDone = true;

      // Clean up partial file
      try {
        final file = File(download.targetPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    } catch (e) {
      download.error = e.toString();
      download.isDone = true;
      Logs.error('Download failed: ${download.name} - $e');

      // Clean up partial file
      try {
        final file = File(download.targetPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  /// Get CivitAI API key from settings (if configured)
  static String? _getCivitaiKey() {
    // CivitAI key is optional - downloads work without it but with rate limits
    return null;
  }

  /// Refresh models for a specific folder type
  static Future<void> _refreshModelsForFolder(String folder) async {
    // Map folder to model type
    String? modelType;
    switch (folder.toLowerCase()) {
      case 'stable-diffusion':
        modelType = 'Stable-Diffusion';
        break;
      case 'lora':
        modelType = 'LoRA';
        break;
      case 'vae':
        modelType = 'VAE';
        break;
      case 'embedding':
        modelType = 'Embedding';
        break;
      case 'controlnet':
        modelType = 'ControlNet';
        break;
      case 'clip':
        modelType = 'Clip';
        break;
    }

    if (modelType != null) {
      final handler = Program.instance.t2iModelSets[modelType];
      if (handler != null) {
        await handler.refresh();
      }
    }
  }

  /// Get download status
  static Future<Map<String, dynamic>> _getDownloadStatus(ApiContext ctx) async {
    final downloadId = ctx.require<String>('download_id');

    final download = _activeDownloads[downloadId];
    if (download == null) {
      throw ApiException('Download not found: $downloadId');
    }

    return {
      'download_id': download.id,
      'name': download.name,
      'folder': download.folder,
      'progress': download.progress,
      'downloaded_bytes': download.downloadedBytes,
      'total_bytes': download.totalBytes,
      'done': download.isDone,
      'cancelled': download.isCancelled,
      'error': download.error,
    };
  }

  /// Cancel a download
  static Future<Map<String, dynamic>> _cancelDownload(ApiContext ctx) async {
    final downloadId = ctx.require<String>('download_id');

    final download = _activeDownloads[downloadId];
    if (download == null) {
      throw ApiException('Download not found: $downloadId');
    }

    download.cancelToken?.cancel();
    download.isCancelled = true;

    return {'success': true, 'download_id': downloadId};
  }

  /// List all active downloads
  static Future<Map<String, dynamic>> _listActiveDownloads(ApiContext ctx) async {
    final downloads = _activeDownloads.values.map((d) => {
      'download_id': d.id,
      'name': d.name,
      'folder': d.folder,
      'progress': d.progress,
      'downloaded_bytes': d.downloadedBytes,
      'total_bytes': d.totalBytes,
      'done': d.isDone,
      'cancelled': d.isCancelled,
      'error': d.error,
    }).toList();

    return {'downloads': downloads};
  }

  /// Parse CivitAI URL and get model info
  static Future<Map<String, dynamic>> _parseCivitAIUrl(ApiContext ctx) async {
    final input = ctx.require<String>('url');

    // Parse URL to get model ID and version ID
    int? modelId;
    int? versionId;

    // Check if it's a direct API download URL
    final apiDownloadRegex = RegExp(r'civitai\.com/api/download/models/(\d+)');
    final apiMatch = apiDownloadRegex.firstMatch(input);
    if (apiMatch != null) {
      versionId = int.parse(apiMatch.group(1)!);
    }

    // Check standard model URL
    if (versionId == null) {
      final modelRegex = RegExp(r'civitai\.com/models/(\d+)(?:/[^?]*)?(?:\?.*modelVersionId=(\d+))?');
      final modelMatch = modelRegex.firstMatch(input);
      if (modelMatch != null) {
        modelId = int.parse(modelMatch.group(1)!);
        if (modelMatch.group(2) != null) {
          versionId = int.parse(modelMatch.group(2)!);
        }
      }
    }

    // Check for simple ID format
    if (modelId == null && versionId == null) {
      final simpleRegex = RegExp(r'^(\d+)(?:@(\d+))?$');
      final simpleMatch = simpleRegex.firstMatch(input.trim());
      if (simpleMatch != null) {
        modelId = int.parse(simpleMatch.group(1)!);
        if (simpleMatch.group(2) != null) {
          versionId = int.parse(simpleMatch.group(2)!);
        }
      }
    }

    if (modelId == null && versionId == null) {
      throw ApiException('Could not parse CivitAI URL: $input');
    }

    // Fetch model info
    try {
      if (versionId != null && modelId == null) {
        // Fetch version info
        final response = await _dio.get(
          'https://civitai.com/api/v1/model-versions/$versionId',
        );

        if (response.statusCode != 200) {
          throw ApiException('Failed to fetch version info');
        }

        return _parseVersionResponse(response.data as Map<String, dynamic>, versionId);
      } else {
        // Fetch model info
        final response = await _dio.get(
          'https://civitai.com/api/v1/models/$modelId',
        );

        if (response.statusCode != 200) {
          throw ApiException('Failed to fetch model info');
        }

        return _parseModelResponse(response.data as Map<String, dynamic>, modelId!, versionId);
      }
    } on DioException catch (e) {
      throw ApiException('Failed to fetch model info: ${e.message}');
    }
  }

  static Map<String, dynamic> _parseModelResponse(
    Map<String, dynamic> data,
    int modelId,
    int? versionId,
  ) {
    final name = data['name'] as String? ?? 'Unknown';
    final type = data['type'] as String? ?? 'Checkpoint';
    final versions = data['modelVersions'] as List<dynamic>?;

    if (versions == null || versions.isEmpty) {
      return {
        'model_id': modelId,
        'name': name,
        'type': type,
      };
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

    return _extractVersionInfo(name, type, modelId, version);
  }

  static Map<String, dynamic> _parseVersionResponse(
    Map<String, dynamic> data,
    int versionId,
  ) {
    final modelId = data['modelId'] as int;
    final name = data['model']?['name'] as String? ?? 'Unknown';
    final type = data['model']?['type'] as String? ?? 'Checkpoint';

    return _extractVersionInfo(name, type, modelId, data);
  }

  static Map<String, dynamic> _extractVersionInfo(
    String name,
    String type,
    int modelId,
    Map<String, dynamic> version,
  ) {
    final files = version['files'] as List<dynamic>?;
    Map<String, dynamic>? primaryFile;

    if (files != null && files.isNotEmpty) {
      primaryFile = files.firstWhere(
        (f) => f['primary'] == true,
        orElse: () => files.first,
      ) as Map<String, dynamic>;
    }

    // Get preview image
    final images = version['images'] as List<dynamic>?;
    String? previewUrl;
    if (images != null && images.isNotEmpty) {
      previewUrl = images.first['url'] as String?;
    }

    // Determine target folder
    String targetFolder;
    switch (type.toLowerCase()) {
      case 'checkpoint':
        targetFolder = 'Stable-Diffusion';
        break;
      case 'lora':
      case 'locon':
        targetFolder = 'Lora';
        break;
      case 'textualinversion':
      case 'embedding':
        targetFolder = 'Embedding';
        break;
      case 'vae':
        targetFolder = 'VAE';
        break;
      case 'controlnet':
        targetFolder = 'ControlNet';
        break;
      default:
        targetFolder = 'other';
    }

    int? fileSize;
    if (primaryFile?['sizeKB'] != null) {
      final sizeKB = primaryFile!['sizeKB'];
      if (sizeKB is num) {
        fileSize = (sizeKB * 1024).toInt();
      }
    }

    return {
      'model_id': modelId,
      'version_id': version['id'],
      'name': name,
      'type': type,
      'target_folder': targetFolder,
      'download_url': primaryFile?['downloadUrl'],
      'file_name': primaryFile?['name'],
      'file_size': fileSize,
      'preview_url': previewUrl,
    };
  }
}

/// Active download state
class _ActiveDownload {
  final String id;
  final String url;
  final String name;
  final String folder;
  final String targetPath;

  double progress = 0.0;
  int downloadedBytes = 0;
  int? totalBytes;
  bool isDone = false;
  bool isCancelled = false;
  String? error;

  CancelToken? cancelToken;

  _ActiveDownload({
    required this.id,
    required this.url,
    required this.name,
    required this.folder,
    required this.targetPath,
  });
}
