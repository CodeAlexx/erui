import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';

import '../../utils/logging.dart';
import '../../core/events.dart';

/// HTTP client for communicating with ComfyUI backend
/// Implements the ComfyUI REST API
class ComfyUIClient {
  /// Base URL for the ComfyUI instance
  final String baseUrl;

  /// HTTP client
  late final Dio _dio;

  /// Connection timeout
  final Duration connectionTimeout;

  /// Request timeout
  final Duration requestTimeout;

  /// Client ID for this connection
  String? _clientId;
  String? get clientId => _clientId;

  /// Whether client is connected
  bool _connected = false;
  bool get isConnected => _connected;

  /// Last known status
  ComfyUIStatus? _status;
  ComfyUIStatus? get status => _status;

  ComfyUIClient({
    required this.baseUrl,
    this.connectionTimeout = const Duration(seconds: 30),
    this.requestTimeout = const Duration(minutes: 10),
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectionTimeout,
      receiveTimeout: requestTimeout,
      validateStatus: (status) => status != null && status < 500,
    ));
  }

  /// Test connection to ComfyUI
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/system_stats');
      _connected = response.statusCode == 200;
      return _connected;
    } catch (e) {
      _connected = false;
      return false;
    }
  }

  /// Get system stats
  Future<Map<String, dynamic>> getSystemStats() async {
    final response = await _dio.get('/system_stats');
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to get system stats: ${response.statusCode}');
    }
    return response.data as Map<String, dynamic>;
  }

  /// Get object info (node definitions)
  Future<Map<String, dynamic>> getObjectInfo() async {
    final response = await _dio.get('/object_info');
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to get object info: ${response.statusCode}');
    }
    return response.data as Map<String, dynamic>;
  }

  /// Get object info for a specific node
  Future<Map<String, dynamic>> getObjectInfoForNode(String nodeClass) async {
    final response = await _dio.get('/object_info/$nodeClass');
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to get object info for $nodeClass');
    }
    return response.data as Map<String, dynamic>;
  }

  /// Get queue status
  Future<ComfyUIQueueStatus> getQueueStatus() async {
    final response = await _dio.get('/queue');
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to get queue status');
    }

    final data = response.data as Map<String, dynamic>;
    return ComfyUIQueueStatus.fromJson(data);
  }

  /// Get history
  Future<Map<String, dynamic>> getHistory({int? maxItems}) async {
    String url = '/history';
    if (maxItems != null) {
      url += '?max_items=$maxItems';
    }
    final response = await _dio.get(url);
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to get history');
    }
    return response.data as Map<String, dynamic>;
  }

  /// Get specific prompt result
  Future<Map<String, dynamic>> getPromptResult(String promptId) async {
    final response = await _dio.get('/history/$promptId');
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to get prompt result: $promptId');
    }
    return response.data as Map<String, dynamic>;
  }

  /// Queue a workflow prompt
  Future<ComfyUIPromptResponse> queuePrompt({
    required Map<String, dynamic> workflow,
    String? clientId,
    Map<String, dynamic>? extraData,
  }) async {
    clientId ??= _clientId;

    final payload = {
      'prompt': workflow,
      if (clientId != null) 'client_id': clientId,
      if (extraData != null) 'extra_data': extraData,
    };

    final response = await _dio.post('/prompt', data: payload);

    if (response.statusCode != 200) {
      final error = response.data is Map
          ? response.data['error'] ?? response.data
          : response.data;
      throw ComfyUIException('Failed to queue prompt: $error');
    }

    final data = response.data as Map<String, dynamic>;
    return ComfyUIPromptResponse.fromJson(data);
  }

  /// Interrupt current generation
  Future<void> interrupt() async {
    final response = await _dio.post('/interrupt');
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to interrupt');
    }
  }

  /// Clear queue
  Future<void> clearQueue({bool clearPending = true, bool clearRunning = false}) async {
    final payload = {
      'clear': clearPending,
    };

    final response = await _dio.post('/queue', data: payload);
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to clear queue');
    }
  }

  /// Delete specific item from queue
  Future<void> deleteFromQueue(String promptId) async {
    final payload = {
      'delete': [promptId],
    };

    final response = await _dio.post('/queue', data: payload);
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to delete from queue');
    }
  }

  /// Delete history items
  Future<void> deleteHistory(List<String> promptIds) async {
    final payload = {
      'delete': promptIds,
    };

    final response = await _dio.post('/history', data: payload);
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to delete history');
    }
  }

  /// Clear all history
  Future<void> clearHistory() async {
    final payload = {
      'clear': true,
    };

    final response = await _dio.post('/history', data: payload);
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to clear history');
    }
  }

  /// Upload an image to ComfyUI
  Future<ComfyUIUploadResponse> uploadImage({
    required Uint8List imageData,
    required String filename,
    String type = 'input',
    String? subfolder,
    bool overwrite = true,
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        imageData,
        filename: filename,
      ),
      'type': type,
      if (subfolder != null) 'subfolder': subfolder,
      'overwrite': overwrite.toString(),
    });

    final response = await _dio.post('/upload/image', data: formData);
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to upload image');
    }

    return ComfyUIUploadResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Upload a mask image
  Future<ComfyUIUploadResponse> uploadMask({
    required Uint8List imageData,
    required String filename,
    required String originalRef,
    String type = 'input',
    String? subfolder,
    bool overwrite = true,
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        imageData,
        filename: filename,
      ),
      'original_ref': originalRef,
      'type': type,
      if (subfolder != null) 'subfolder': subfolder,
      'overwrite': overwrite.toString(),
    });

    final response = await _dio.post('/upload/mask', data: formData);
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to upload mask');
    }

    return ComfyUIUploadResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get an image/output from ComfyUI
  Future<Uint8List> getImage({
    required String filename,
    String type = 'output',
    String? subfolder,
  }) async {
    final params = {
      'filename': filename,
      'type': type,
      if (subfolder != null) 'subfolder': subfolder,
    };

    final response = await _dio.get(
      '/view',
      queryParameters: params,
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to get image: $filename');
    }

    return Uint8List.fromList(response.data as List<int>);
  }

  /// Get embeddings list
  Future<List<String>> getEmbeddings() async {
    final response = await _dio.get('/embeddings');
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to get embeddings');
    }

    final data = response.data;
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// Get extensions list
  Future<List<String>> getExtensions() async {
    final response = await _dio.get('/extensions');
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to get extensions');
    }

    final data = response.data;
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// Free memory on the backend
  Future<void> freeMemory({bool unloadModels = false, bool freeMemory = true}) async {
    final payload = {
      'unload_models': unloadModels,
      'free_memory': freeMemory,
    };

    final response = await _dio.post('/free', data: payload);
    if (response.statusCode != 200) {
      throw ComfyUIException('Failed to free memory');
    }
  }

  /// Get user config
  Future<Map<String, dynamic>> getUserConfig() async {
    final response = await _dio.get('/users');
    if (response.statusCode != 200) {
      return {};
    }
    return response.data as Map<String, dynamic>? ?? {};
  }

  /// Get models for a specific model type
  Future<List<String>> getModels(String modelType) async {
    try {
      final objectInfo = await getObjectInfo();

      // Find nodes that load this model type
      for (final entry in objectInfo.entries) {
        final nodeInfo = entry.value as Map<String, dynamic>?;
        if (nodeInfo == null) continue;

        final input = nodeInfo['input'] as Map<String, dynamic>?;
        if (input == null) continue;

        final required = input['required'] as Map<String, dynamic>?;
        if (required == null) continue;

        for (final inputEntry in required.entries) {
          final inputDef = inputEntry.value;
          if (inputDef is List && inputDef.isNotEmpty) {
            final first = inputDef[0];
            if (first is List) {
              // This is a model list
              return first.map((e) => e.toString()).toList();
            }
          }
        }
      }

      return [];
    } catch (e) {
      Logs.warning('Failed to get models for $modelType: $e');
      return [];
    }
  }

  /// Get all available samplers
  Future<List<String>> getSamplers() async {
    try {
      final objectInfo = await getObjectInfo();
      final kSampler = objectInfo['KSampler'] as Map<String, dynamic>?;
      if (kSampler == null) return [];

      final input = kSampler['input'] as Map<String, dynamic>?;
      final required = input?['required'] as Map<String, dynamic>?;
      final samplerInput = required?['sampler_name'];

      if (samplerInput is List && samplerInput.isNotEmpty) {
        final samplers = samplerInput[0];
        if (samplers is List) {
          return samplers.map((e) => e.toString()).toList();
        }
      }

      return [];
    } catch (e) {
      Logs.warning('Failed to get samplers: $e');
      return [];
    }
  }

  /// Get all available schedulers
  Future<List<String>> getSchedulers() async {
    try {
      final objectInfo = await getObjectInfo();
      final kSampler = objectInfo['KSampler'] as Map<String, dynamic>?;
      if (kSampler == null) return [];

      final input = kSampler['input'] as Map<String, dynamic>?;
      final required = input?['required'] as Map<String, dynamic>?;
      final schedulerInput = required?['scheduler'];

      if (schedulerInput is List && schedulerInput.isNotEmpty) {
        final schedulers = schedulerInput[0];
        if (schedulers is List) {
          return schedulers.map((e) => e.toString()).toList();
        }
      }

      return [];
    } catch (e) {
      Logs.warning('Failed to get schedulers: $e');
      return [];
    }
  }

  /// Set client ID for this connection
  void setClientId(String id) {
    _clientId = id;
  }

  /// Close the client
  void close() {
    _dio.close();
    _connected = false;
  }
}

/// ComfyUI exception
class ComfyUIException implements Exception {
  final String message;
  final dynamic details;

  ComfyUIException(this.message, [this.details]);

  @override
  String toString() {
    if (details != null) {
      return 'ComfyUIException: $message ($details)';
    }
    return 'ComfyUIException: $message';
  }
}

/// Queue status response
class ComfyUIQueueStatus {
  final int queuePending;
  final int queueRunning;

  ComfyUIQueueStatus({
    required this.queuePending,
    required this.queueRunning,
  });

  factory ComfyUIQueueStatus.fromJson(Map<String, dynamic> json) {
    final pending = json['queue_pending'] as List? ?? [];
    final running = json['queue_running'] as List? ?? [];

    return ComfyUIQueueStatus(
      queuePending: pending.length,
      queueRunning: running.length,
    );
  }

  int get total => queuePending + queueRunning;
  bool get isEmpty => total == 0;
}

/// Prompt queue response
class ComfyUIPromptResponse {
  final String promptId;
  final int number;
  final Map<String, dynamic>? nodeErrors;

  ComfyUIPromptResponse({
    required this.promptId,
    required this.number,
    this.nodeErrors,
  });

  factory ComfyUIPromptResponse.fromJson(Map<String, dynamic> json) {
    return ComfyUIPromptResponse(
      promptId: json['prompt_id'] as String,
      number: json['number'] as int? ?? 0,
      nodeErrors: json['node_errors'] as Map<String, dynamic>?,
    );
  }

  bool get hasErrors => nodeErrors != null && nodeErrors!.isNotEmpty;
}

/// Upload response
class ComfyUIUploadResponse {
  final String name;
  final String? subfolder;
  final String type;

  ComfyUIUploadResponse({
    required this.name,
    this.subfolder,
    required this.type,
  });

  factory ComfyUIUploadResponse.fromJson(Map<String, dynamic> json) {
    return ComfyUIUploadResponse(
      name: json['name'] as String,
      subfolder: json['subfolder'] as String?,
      type: json['type'] as String? ?? 'input',
    );
  }

  /// Get the full reference path for use in workflows
  String get reference {
    if (subfolder != null && subfolder!.isNotEmpty) {
      return '$subfolder/$name';
    }
    return name;
  }
}

/// System status
class ComfyUIStatus {
  final Map<String, ComfyUIDeviceStats> devices;
  final int cpuUtilization;

  ComfyUIStatus({
    required this.devices,
    required this.cpuUtilization,
  });

  factory ComfyUIStatus.fromJson(Map<String, dynamic> json) {
    final devices = <String, ComfyUIDeviceStats>{};

    final devicesJson = json['devices'] as List?;
    if (devicesJson != null) {
      for (var i = 0; i < devicesJson.length; i++) {
        final device = devicesJson[i] as Map<String, dynamic>;
        devices['device_$i'] = ComfyUIDeviceStats.fromJson(device);
      }
    }

    return ComfyUIStatus(
      devices: devices,
      cpuUtilization: json['cpu_utilization'] as int? ?? 0,
    );
  }
}

/// Device statistics
class ComfyUIDeviceStats {
  final String name;
  final String type;
  final int vramTotal;
  final int vramFree;
  final int torchVramTotal;
  final int torchVramFree;

  ComfyUIDeviceStats({
    required this.name,
    required this.type,
    required this.vramTotal,
    required this.vramFree,
    required this.torchVramTotal,
    required this.torchVramFree,
  });

  factory ComfyUIDeviceStats.fromJson(Map<String, dynamic> json) {
    return ComfyUIDeviceStats(
      name: json['name'] as String? ?? 'Unknown',
      type: json['type'] as String? ?? 'cuda',
      vramTotal: json['vram_total'] as int? ?? 0,
      vramFree: json['vram_free'] as int? ?? 0,
      torchVramTotal: json['torch_vram_total'] as int? ?? 0,
      torchVramFree: json['torch_vram_free'] as int? ?? 0,
    );
  }

  int get vramUsed => vramTotal - vramFree;
  double get vramUsagePercent =>
      vramTotal > 0 ? (vramUsed / vramTotal * 100) : 0;
}
