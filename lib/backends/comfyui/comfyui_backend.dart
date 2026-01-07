import 'dart:async';
import 'dart:typed_data';

import '../../utils/logging.dart';
import '../abstract_backend.dart';
import 'comfyui_client.dart';
import 'comfyui_websocket.dart';
import 'workflow_generator.dart';

/// ComfyUI API backend implementation
class ComfyUIBackend extends AbstractBackend {
  /// HTTP client
  late ComfyUIClient _client;

  /// WebSocket client
  ComfyUIWebSocket? _webSocket;

  /// Cached object info
  Map<String, dynamic>? _cachedObjectInfo;

  /// Last object info refresh time
  DateTime? _lastObjectInfoRefresh;

  /// Currently loaded model
  String? _currentModel;

  ComfyUIBackend(super.settings);

  /// Get the base URL (EriUI ComfyUI on 8199, not SwarmUI's 8188)
  String get baseUrl => settings['address'] as String? ?? 'http://127.0.0.1:8199';

  @override
  Future<void> init() async {
    status = BackendStatus.initializing;

    try {
      _client = ComfyUIClient(baseUrl: baseUrl);

      // Test connection
      final connected = await _client.testConnection();
      if (!connected) {
        throw Exception('Failed to connect to ComfyUI at $baseUrl');
      }

      // Connect WebSocket
      _webSocket = ComfyUIWebSocket(baseUrl: baseUrl);
      await _webSocket!.connect();

      // Update client ID
      _client.setClientId(_webSocket!.clientId);

      // Cache object info
      await _refreshObjectInfo();

      status = BackendStatus.idle;
      Logs.info('ComfyUI backend connected to $baseUrl');
    } catch (e) {
      status = BackendStatus.errored;
      errorMessage = e.toString();
      rethrow;
    }
  }

  @override
  Future<void> shutdown() async {
    status = BackendStatus.shuttingDown;

    await _webSocket?.close();
    _client.close();

    status = BackendStatus.disabled;
  }

  @override
  Future<void> loadModel(String modelName) async {
    status = BackendStatus.loading;

    try {
      // Build a minimal workflow to load the model
      final workflow = {
        '1': {
          'class_type': 'CheckpointLoaderSimple',
          'inputs': {
            'ckpt_name': modelName,
          },
        },
      };

      // Queue the workflow
      final response = await _client.queuePrompt(workflow: workflow);

      // Wait for completion
      if (_webSocket != null) {
        await _webSocket!.waitForCompletion(
          response.promptId,
          timeout: const Duration(minutes: 5),
        );
      }

      _currentModel = modelName;
      status = BackendStatus.idle;
    } catch (e) {
      status = BackendStatus.errored;
      errorMessage = e.toString();
      rethrow;
    }
  }

  @override
  Future<void> unloadModel() async {
    try {
      await _client.freeMemory(unloadModels: true, freeMemory: true);
      _currentModel = null;
    } catch (e) {
      Logs.warning('Failed to unload model: $e');
    }
  }

  @override
  Future<void> interrupt() async {
    try {
      await _client.interrupt();
    } catch (e) {
      Logs.warning('Failed to interrupt: $e');
    }
  }

  /// Generate images with the given parameters
  Future<List<GenerationResult>> generate({
    required Map<String, dynamic> params,
    void Function(int, int)? onProgress,
    void Function(Uint8List)? onPreview,
  }) async {
    status = BackendStatus.running;

    try {
      // Build workflow from params
      final generator = WorkflowGenerator(userInput: params);
      final workflow = generator.buildBasicTxt2Img();

      // Subscribe to progress updates
      StreamSubscription? progressSub;
      StreamSubscription? previewSub;

      if (onProgress != null && _webSocket != null) {
        progressSub = _webSocket!.progress.listen((p) {
          onProgress(p.value, p.max);
        });
      }

      if (onPreview != null && _webSocket != null) {
        previewSub = _webSocket!.previews.listen((data) {
          onPreview(data);
        });
      }

      try {
        // Queue the workflow
        final response = await _client.queuePrompt(
          workflow: workflow['prompt'] as Map<String, dynamic>,
        );

        if (response.hasErrors) {
          throw Exception('Workflow errors: ${response.nodeErrors}');
        }

        // Wait for completion
        ComfyUIExecutionResult? result;
        if (_webSocket != null) {
          result = await _webSocket!.waitForCompletion(response.promptId);

          if (!result.success) {
            throw Exception(result.error ?? 'Generation failed');
          }
        } else {
          // Poll for completion
          await Future.delayed(const Duration(seconds: 1));
          // TODO: Implement polling
        }

        // Get output images
        final results = <GenerationResult>[];

        if (result != null && result.outputs != null) {
          for (final nodeOutput in result.outputs!.entries) {
            final images = result.getImages(nodeOutput.key);
            for (final image in images) {
              final imageData = await _client.getImage(
                filename: image.filename,
                subfolder: image.subfolder,
                type: image.type,
              );

              results.add(GenerationResult(
                imageData: imageData,
                filename: image.filename,
                seed: params['seed'] as int? ?? 0,
              ));
            }
          }
        }

        status = BackendStatus.idle;
        return results;
      } finally {
        await progressSub?.cancel();
        await previewSub?.cancel();
      }
    } catch (e) {
      status = BackendStatus.idle;
      rethrow;
    }
  }

  /// Upload an image
  Future<String> uploadImage(Uint8List imageData, String filename) async {
    final result = await _client.uploadImage(
      imageData: imageData,
      filename: filename,
    );
    return result.reference;
  }

  /// Get available samplers
  Future<List<String>> getSamplers() async {
    await _ensureObjectInfo();
    return _client.getSamplers();
  }

  /// Get available schedulers
  Future<List<String>> getSchedulers() async {
    await _ensureObjectInfo();
    return _client.getSchedulers();
  }

  /// Get system stats
  Future<Map<String, dynamic>> getSystemStats() async {
    return _client.getSystemStats();
  }

  /// Get queue status
  Future<ComfyUIQueueStatus> getQueueStatus() async {
    return _client.getQueueStatus();
  }

  /// Refresh object info cache
  Future<void> _refreshObjectInfo() async {
    _cachedObjectInfo = await _client.getObjectInfo();
    _lastObjectInfoRefresh = DateTime.now();
  }

  /// Ensure object info is cached
  Future<void> _ensureObjectInfo() async {
    final now = DateTime.now();
    if (_cachedObjectInfo == null ||
        _lastObjectInfoRefresh == null ||
        now.difference(_lastObjectInfoRefresh!) > const Duration(minutes: 5)) {
      await _refreshObjectInfo();
    }
  }

  /// Get cached object info
  Map<String, dynamic>? get objectInfo => _cachedObjectInfo;

  /// Current model name
  String? get currentModel => _currentModel;
}

/// Settings for ComfyUI backend
/// Default port 8199 = EriUI's standalone ComfyUI (not SwarmUI's 8188)
class ComfyUIBackendSettings {
  String address;
  bool enablePreviews;
  int previewMethod;

  ComfyUIBackendSettings({
    this.address = 'http://127.0.0.1:8199',
    this.enablePreviews = true,
    this.previewMethod = 0,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        'enable_previews': enablePreviews,
        'preview_method': previewMethod,
      };

  factory ComfyUIBackendSettings.fromJson(Map<String, dynamic> json) {
    return ComfyUIBackendSettings(
      address: json['address'] as String? ?? 'http://127.0.0.1:8199',
      enablePreviews: json['enable_previews'] as bool? ?? true,
      previewMethod: json['preview_method'] as int? ?? 0,
    );
  }
}

/// Result of a generation
class GenerationResult {
  final Uint8List imageData;
  final String filename;
  final int seed;
  final Map<String, dynamic>? metadata;

  GenerationResult({
    required this.imageData,
    required this.filename,
    required this.seed,
    this.metadata,
  });
}
