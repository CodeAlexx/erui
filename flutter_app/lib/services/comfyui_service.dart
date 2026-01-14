import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:convert';

/// ComfyUI service provider
final comfyUIServiceProvider = Provider<ComfyUIService>((ref) {
  return ComfyUIService();
});

/// Connection state for ComfyUI
enum ComfyConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Progress update from ComfyUI WebSocket
class ComfyProgressUpdate {
  final String promptId;
  final int currentStep;
  final int totalSteps;
  final String? previewImage;
  final bool isComplete;
  final List<String>? outputImages;
  final String? currentNode;
  final String? status;

  const ComfyProgressUpdate({
    required this.promptId,
    required this.currentStep,
    required this.totalSteps,
    this.previewImage,
    this.isComplete = false,
    this.outputImages,
    this.currentNode,
    this.status,
  });

  double get progress => totalSteps > 0 ? currentStep / totalSteps : 0;

  ComfyProgressUpdate copyWith({
    String? promptId,
    int? currentStep,
    int? totalSteps,
    String? previewImage,
    bool? isComplete,
    List<String>? outputImages,
    String? currentNode,
    String? status,
  }) {
    return ComfyProgressUpdate(
      promptId: promptId ?? this.promptId,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      previewImage: previewImage ?? this.previewImage,
      isComplete: isComplete ?? this.isComplete,
      outputImages: outputImages ?? this.outputImages,
      currentNode: currentNode ?? this.currentNode,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'ComfyProgressUpdate(promptId: $promptId, step: $currentStep/$totalSteps, complete: $isComplete)';
  }
}

/// ComfyUI execution error
class ComfyExecutionError {
  final String promptId;
  final String nodeId;
  final String nodeType;
  final String message;
  final Map<String, dynamic>? details;

  const ComfyExecutionError({
    required this.promptId,
    required this.nodeId,
    required this.nodeType,
    required this.message,
    this.details,
  });

  @override
  String toString() {
    return 'ComfyExecutionError(node: $nodeType[$nodeId], message: $message)';
  }
}

/// ComfyUI API Service for direct communication with ComfyUI backend
class ComfyUIService {
  late Dio _dio;
  WebSocketChannel? _wsChannel;
  String _host = 'localhost';
  int _port = 8199;
  String _clientId = '';

  String get _baseUrl => 'http://$_host:$_port';
  String get _wsUrl => 'ws://$_host:$_port/ws';
  String get host => _host;
  int get port => _port;
  String get clientId => _clientId;

  final _connectionStateController = StreamController<ComfyConnectionState>.broadcast();
  Stream<ComfyConnectionState> get connectionState => _connectionStateController.stream;
  ComfyConnectionState _currentState = ComfyConnectionState.disconnected;
  ComfyConnectionState get currentConnectionState => _currentState;

  final _progressController = StreamController<ComfyProgressUpdate>.broadcast();
  Stream<ComfyProgressUpdate> get progressStream => _progressController.stream;

  final _errorController = StreamController<ComfyExecutionError>.broadcast();
  Stream<ComfyExecutionError> get errorStream => _errorController.stream;

  final _rawMessageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get rawMessages => _rawMessageController.stream;

  // Track current execution state
  final Map<String, ComfyProgressUpdate> _activeExecutions = {};
  StreamSubscription? _wsSubscription;
  Timer? _reconnectTimer;
  bool _isDisposed = false;

  ComfyUIService() {
    _clientId = _generateClientId();
    _initDio();
  }

  void _initDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(seconds: 30),
    ));
  }

  /// Generate a unique client ID for WebSocket session
  String _generateClientId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = now.toString().hashCode.abs();
    return 'flutter_$random';
  }

  /// Configure the ComfyUI service with host and port
  void configure({required String host, required int port}) {
    _host = host;
    _port = port;
  }

  /// Connect to ComfyUI backend
  Future<bool> connect() async {
    if (_isDisposed) return false;

    try {
      _updateConnectionState(ComfyConnectionState.connecting);

      // Test HTTP connection with system_stats
      final response = await _dio.get('$_baseUrl/system_stats');
      if (response.statusCode != 200) {
        _updateConnectionState(ComfyConnectionState.error);
        return false;
      }

      // Connect WebSocket
      await _connectWebSocket();

      _updateConnectionState(ComfyConnectionState.connected);
      return true;
    } catch (e) {
      print('ComfyUI connection error: $e');
      _updateConnectionState(ComfyConnectionState.error);
      return false;
    }
  }

  /// Disconnect from ComfyUI backend
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
    _activeExecutions.clear();
    _updateConnectionState(ComfyConnectionState.disconnected);
  }

  void _updateConnectionState(ComfyConnectionState state) {
    _currentState = state;
    if (!_isDisposed) {
      _connectionStateController.add(state);
    }
  }

  /// Connect to ComfyUI WebSocket
  Future<void> _connectWebSocket() async {
    await _wsSubscription?.cancel();
    await _wsChannel?.sink.close();

    final wsUri = Uri.parse('$_wsUrl?clientId=$_clientId');
    _wsChannel = WebSocketChannel.connect(wsUri);

    _wsSubscription = _wsChannel!.stream.listen(
      _handleWsMessage,
      onError: (error) {
        print('ComfyUI WebSocket error: $error');
        _scheduleReconnect();
      },
      onDone: () {
        print('ComfyUI WebSocket closed');
        if (_currentState == ComfyConnectionState.connected) {
          _scheduleReconnect();
        }
      },
    );
  }

  void _scheduleReconnect() {
    if (_isDisposed || _reconnectTimer != null) return;

    _updateConnectionState(ComfyConnectionState.disconnected);
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      if (!_isDisposed && _currentState != ComfyConnectionState.connected) {
        connect();
      }
    });
  }

  /// Handle incoming WebSocket messages
  void _handleWsMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      _rawMessageController.add(data);

      final type = data['type'] as String?;
      final msgData = data['data'] as Map<String, dynamic>?;

      if (type == null) return;

      switch (type) {
        case 'status':
          _handleStatus(msgData);
          break;
        case 'execution_start':
          _handleExecutionStart(msgData);
          break;
        case 'execution_cached':
          _handleExecutionCached(msgData);
          break;
        case 'executing':
          _handleExecuting(msgData);
          break;
        case 'progress':
          _handleProgress(msgData);
          break;
        case 'executed':
          _handleExecuted(msgData);
          break;
        case 'execution_error':
          _handleExecutionError(msgData);
          break;
        case 'execution_interrupted':
          _handleExecutionInterrupted(msgData);
          break;
      }
    } catch (e) {
      print('Error parsing ComfyUI message: $e');
    }
  }

  void _handleStatus(Map<String, dynamic>? data) {
    // Status messages contain queue info
    // {"type": "status", "data": {"status": {"exec_info": {"queue_remaining": 0}}}}
    // We can use this to track queue state if needed
  }

  void _handleExecutionStart(Map<String, dynamic>? data) {
    if (data == null) return;
    final promptId = data['prompt_id'] as String?;
    if (promptId == null) return;

    _activeExecutions[promptId] = ComfyProgressUpdate(
      promptId: promptId,
      currentStep: 0,
      totalSteps: 0,
      status: 'started',
    );
    _progressController.add(_activeExecutions[promptId]!);
  }

  void _handleExecutionCached(Map<String, dynamic>? data) {
    if (data == null) return;
    final promptId = data['prompt_id'] as String?;
    // Cached nodes don't need execution, just note it
    if (promptId != null && _activeExecutions.containsKey(promptId)) {
      final current = _activeExecutions[promptId]!;
      _activeExecutions[promptId] = current.copyWith(status: 'cached');
    }
  }

  void _handleExecuting(Map<String, dynamic>? data) {
    if (data == null) return;
    final promptId = data['prompt_id'] as String?;
    final node = data['node'] as String?;

    if (promptId == null) return;

    // When node is null, execution is complete
    if (node == null) {
      final current = _activeExecutions[promptId];
      if (current != null) {
        _activeExecutions[promptId] = current.copyWith(
          isComplete: true,
          status: 'complete',
        );
        _progressController.add(_activeExecutions[promptId]!);
      }
      return;
    }

    final current = _activeExecutions[promptId];
    if (current != null) {
      _activeExecutions[promptId] = current.copyWith(
        currentNode: node,
        status: 'executing',
      );
      _progressController.add(_activeExecutions[promptId]!);
    }
  }

  void _handleProgress(Map<String, dynamic>? data) {
    if (data == null) return;
    final value = data['value'] as int? ?? 0;
    final max = data['max'] as int? ?? 0;
    final promptId = data['prompt_id'] as String?;

    // Find the active execution - progress might not include prompt_id
    String? targetPromptId = promptId;
    if (targetPromptId == null && _activeExecutions.isNotEmpty) {
      // Use the most recent execution
      targetPromptId = _activeExecutions.keys.last;
    }

    if (targetPromptId != null) {
      final current = _activeExecutions[targetPromptId];
      if (current != null) {
        _activeExecutions[targetPromptId] = current.copyWith(
          currentStep: value,
          totalSteps: max,
          status: 'generating',
        );
        _progressController.add(_activeExecutions[targetPromptId]!);
      }
    }
  }

  void _handleExecuted(Map<String, dynamic>? data) {
    if (data == null) return;
    final promptId = data['prompt_id'] as String?;
    final node = data['node'] as String?;
    final output = data['output'] as Map<String, dynamic>?;

    if (promptId == null || output == null) return;

    final outputUrls = <String>[];

    // Check if output contains images
    final images = output['images'] as List?;
    if (images != null && images.isNotEmpty) {
      for (final img in images) {
        final filename = img['filename'] as String?;
        final subfolder = img['subfolder'] as String? ?? '';
        final imgType = img['type'] as String? ?? 'output';
        if (filename != null) {
          outputUrls.add(getImageUrl(filename, subfolder: subfolder, type: imgType));
        }
      }
    }

    // Check for gifs (video output from VHS_VideoCombine etc)
    final gifs = output['gifs'] as List?;
    if (gifs != null && gifs.isNotEmpty) {
      for (final gif in gifs) {
        final filename = gif['filename'] as String?;
        final subfolder = gif['subfolder'] as String? ?? '';
        final gifType = gif['type'] as String? ?? 'output';
        if (filename != null) {
          outputUrls.add(getImageUrl(filename, subfolder: subfolder, type: gifType));
        }
      }
    }

    // Check for video output
    final videos = output['video'] as List?;
    if (videos != null && videos.isNotEmpty) {
      for (final video in videos) {
        final filename = video['filename'] as String?;
        final subfolder = video['subfolder'] as String? ?? '';
        final videoType = video['type'] as String? ?? 'output';
        if (filename != null) {
          outputUrls.add(getImageUrl(filename, subfolder: subfolder, type: videoType));
        }
      }
    }

    if (outputUrls.isNotEmpty) {
      final current = _activeExecutions[promptId];
      if (current != null) {
        final existingImages = current.outputImages ?? [];
        _activeExecutions[promptId] = current.copyWith(
          outputImages: [...existingImages, ...outputUrls],
          status: 'executed',
        );
        _progressController.add(_activeExecutions[promptId]!);
      }
    }
  }

  void _handleExecutionError(Map<String, dynamic>? data) {
    if (data == null) return;
    final promptId = data['prompt_id'] as String? ?? '';
    final nodeId = data['node_id'] as String? ?? '';
    final nodeType = data['node_type'] as String? ?? '';
    final exception = data['exception_message'] as String? ?? 'Unknown error';

    _errorController.add(ComfyExecutionError(
      promptId: promptId,
      nodeId: nodeId,
      nodeType: nodeType,
      message: exception,
      details: data,
    ));

    // Mark execution as failed
    if (_activeExecutions.containsKey(promptId)) {
      final current = _activeExecutions[promptId]!;
      _activeExecutions[promptId] = current.copyWith(
        isComplete: true,
        status: 'error',
      );
      _progressController.add(_activeExecutions[promptId]!);
    }
  }

  void _handleExecutionInterrupted(Map<String, dynamic>? data) {
    final promptId = data?['prompt_id'] as String?;
    if (promptId != null && _activeExecutions.containsKey(promptId)) {
      final current = _activeExecutions[promptId]!;
      _activeExecutions[promptId] = current.copyWith(
        isComplete: true,
        status: 'interrupted',
      );
      _progressController.add(_activeExecutions[promptId]!);
    }
  }

  // ============================================================
  // HTTP API Methods
  // ============================================================

  /// Queue a prompt/workflow for execution
  /// Returns the prompt_id on success, null on failure
  Future<String?> queuePrompt(Map<String, dynamic> workflow) async {
    try {
      final payload = {
        'prompt': workflow,
        'client_id': _clientId,
      };

      final response = await _dio.post(
        '$_baseUrl/prompt',
        data: jsonEncode(payload),
        options: Options(
          contentType: 'application/json',
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final promptId = data['prompt_id'] as String?;

        // Initialize tracking for this execution
        if (promptId != null) {
          _activeExecutions[promptId] = ComfyProgressUpdate(
            promptId: promptId,
            currentStep: 0,
            totalSteps: 0,
            status: 'queued',
          );
        }

        return promptId;
      }
      return null;
    } catch (e) {
      print('Error queueing prompt: $e');
      return null;
    }
  }

  /// Get generation history for a specific prompt
  Future<Map<String, dynamic>?> getHistory(String promptId) async {
    try {
      final response = await _dio.get('$_baseUrl/history/$promptId');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data[promptId] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting history: $e');
      return null;
    }
  }

  /// Get all history (limited)
  Future<Map<String, dynamic>?> getAllHistory({int? maxItems}) async {
    try {
      String url = '$_baseUrl/history';
      if (maxItems != null) {
        url += '?max_items=$maxItems';
      }
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting all history: $e');
      return null;
    }
  }

  /// Interrupt current generation
  Future<void> interrupt() async {
    try {
      await _dio.post('$_baseUrl/interrupt');
    } catch (e) {
      print('Error interrupting: $e');
    }
  }

  /// Clear the queue
  Future<void> clearQueue() async {
    try {
      await _dio.post('$_baseUrl/queue', data: {'clear': true});
    } catch (e) {
      print('Error clearing queue: $e');
    }
  }

  /// Delete history items
  Future<void> deleteHistory({List<String>? promptIds, bool clear = false}) async {
    try {
      final data = <String, dynamic>{};
      if (clear) {
        data['clear'] = true;
      } else if (promptIds != null) {
        data['delete'] = promptIds;
      }
      await _dio.post('$_baseUrl/history', data: data);
    } catch (e) {
      print('Error deleting history: $e');
    }
  }

  /// Get queue status
  Future<Map<String, dynamic>?> getQueue() async {
    try {
      final response = await _dio.get('$_baseUrl/queue');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting queue: $e');
      return null;
    }
  }

  /// Get system stats
  Future<Map<String, dynamic>?> getSystemStats() async {
    try {
      final response = await _dio.get('$_baseUrl/system_stats');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting system stats: $e');
      return null;
    }
  }

  /// Get object info (all available nodes and their inputs)
  Future<Map<String, dynamic>?> getObjectInfo() async {
    try {
      final response = await _dio.get('$_baseUrl/object_info');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting object info: $e');
      return null;
    }
  }

  /// Get object info for a specific node type
  Future<Map<String, dynamic>?> getNodeInfo(String nodeType) async {
    try {
      final response = await _dio.get('$_baseUrl/object_info/$nodeType');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting node info: $e');
      return null;
    }
  }

  /// Get embeddings list
  Future<List<String>> getEmbeddings() async {
    try {
      final response = await _dio.get('$_baseUrl/embeddings');
      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.cast<String>();
      }
      return [];
    } catch (e) {
      print('Error getting embeddings: $e');
      return [];
    }
  }

  /// Get extensions list
  Future<List<String>> getExtensions() async {
    try {
      final response = await _dio.get('$_baseUrl/extensions');
      if (response.statusCode == 200) {
        final data = response.data as List;
        return data.cast<String>();
      }
      return [];
    } catch (e) {
      print('Error getting extensions: $e');
      return [];
    }
  }

  // ============================================================
  // Model and Resource Helpers
  // ============================================================

  /// Get available checkpoints (SD models)
  Future<List<String>> getCheckpoints() async {
    return _getModelList('CheckpointLoaderSimple', 'ckpt_name');
  }

  /// Get available VAE models
  Future<List<String>> getVAEs() async {
    return _getModelList('VAELoader', 'vae_name');
  }

  /// Get available LoRA models
  Future<List<String>> getLoras() async {
    return _getModelList('LoraLoader', 'lora_name');
  }

  /// Get available ControlNet models
  Future<List<String>> getControlNets() async {
    return _getModelList('ControlNetLoader', 'control_net_name');
  }

  /// Get available upscale models
  Future<List<String>> getUpscaleModels() async {
    return _getModelList('UpscaleModelLoader', 'model_name');
  }

  /// Get available CLIP models
  Future<List<String>> getCLIPModels() async {
    return _getModelList('CLIPLoader', 'clip_name');
  }

  /// Get available samplers
  Future<List<String>> getSamplers() async {
    return _getModelList('KSampler', 'sampler_name');
  }

  /// Get available schedulers
  Future<List<String>> getSchedulers() async {
    return _getModelList('KSampler', 'scheduler');
  }

  /// Get CLIP vision models
  Future<List<String>> getCLIPVisionModels() async {
    return _getModelList('CLIPVisionLoader', 'clip_name');
  }

  /// Get style models (for IP-Adapter, etc)
  Future<List<String>> getStyleModels() async {
    return _getModelList('StyleModelLoader', 'style_model_name');
  }

  /// Get GLIGEN models
  Future<List<String>> getGLIGENModels() async {
    return _getModelList('GLIGENLoader', 'gligen_name');
  }

  /// Get hypernetwork models
  Future<List<String>> getHypernetworks() async {
    return _getModelList('HypernetworkLoader', 'hypernetwork_name');
  }

  /// Generic method to get model lists from object_info
  Future<List<String>> _getModelList(String nodeType, String inputName) async {
    try {
      final objectInfo = await getObjectInfo();
      if (objectInfo == null) return [];

      final nodeInfo = objectInfo[nodeType] as Map<String, dynamic>?;
      if (nodeInfo == null) return [];

      final input = nodeInfo['input'] as Map<String, dynamic>?;
      if (input == null) return [];

      final required = input['required'] as Map<String, dynamic>?;
      if (required == null) return [];

      final inputDef = required[inputName] as List?;
      if (inputDef == null || inputDef.isEmpty) return [];

      // First element is the list of options
      final options = inputDef[0];
      if (options is List) {
        return options.cast<String>();
      }

      return [];
    } catch (e) {
      print('Error getting model list for $nodeType.$inputName: $e');
      return [];
    }
  }

  // ============================================================
  // Image URL Helpers
  // ============================================================

  /// Get URL for viewing an image from ComfyUI output
  String getImageUrl(
    String filename, {
    String subfolder = '',
    String type = 'output',
    String? format,
    int? quality,
  }) {
    final params = <String, String>{
      'filename': filename,
      'subfolder': subfolder,
      'type': type,
    };

    if (format != null) params['format'] = format;
    if (quality != null) params['quality'] = quality.toString();

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$_baseUrl/view?$queryString';
  }

  /// Upload an image to ComfyUI
  Future<Map<String, dynamic>?> uploadImage(
    List<int> imageBytes,
    String filename, {
    String type = 'input',
    String subfolder = '',
    bool overwrite = false,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          imageBytes,
          filename: filename,
        ),
        'type': type,
        'subfolder': subfolder,
        'overwrite': overwrite.toString(),
      });

      final response = await _dio.post(
        '$_baseUrl/upload/image',
        data: formData,
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Upload a mask image to ComfyUI
  Future<Map<String, dynamic>?> uploadMask(
    List<int> imageBytes,
    String filename,
    String originalRef, {
    String type = 'input',
    String subfolder = '',
    bool overwrite = false,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          imageBytes,
          filename: filename,
        ),
        'original_ref': originalRef,
        'type': type,
        'subfolder': subfolder,
        'overwrite': overwrite.toString(),
      });

      final response = await _dio.post(
        '$_baseUrl/upload/mask',
        data: formData,
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error uploading mask: $e');
      return null;
    }
  }

  // ============================================================
  // Utility Methods
  // ============================================================

  /// Free memory
  Future<void> freeMemory({bool unloadModels = false, bool freeMemory = true}) async {
    try {
      await _dio.post('$_baseUrl/free', data: {
        'unload_models': unloadModels,
        'free_memory': freeMemory,
      });
    } catch (e) {
      print('Error freeing memory: $e');
    }
  }

  /// Get outputs for a completed prompt from history
  /// Handles both images and video/gif outputs
  Future<List<String>> getOutputImages(String promptId) async {
    final history = await getHistory(promptId);
    if (history == null) return [];

    final outputs = history['outputs'] as Map<String, dynamic>?;
    if (outputs == null) return [];

    final images = <String>[];
    for (final nodeOutput in outputs.values) {
      if (nodeOutput is Map<String, dynamic>) {
        // Check for standard images output
        final nodeImages = nodeOutput['images'] as List?;
        if (nodeImages != null) {
          for (final img in nodeImages) {
            if (img is Map<String, dynamic>) {
              final filename = img['filename'] as String?;
              final subfolder = img['subfolder'] as String? ?? '';
              final type = img['type'] as String? ?? 'output';
              if (filename != null) {
                images.add(getImageUrl(filename, subfolder: subfolder, type: type));
              }
            }
          }
        }

        // Check for gifs output (VHS_VideoCombine and similar nodes)
        final nodeGifs = nodeOutput['gifs'] as List?;
        if (nodeGifs != null) {
          for (final gif in nodeGifs) {
            if (gif is Map<String, dynamic>) {
              final filename = gif['filename'] as String?;
              final subfolder = gif['subfolder'] as String? ?? '';
              final type = gif['type'] as String? ?? 'output';
              if (filename != null) {
                images.add(getImageUrl(filename, subfolder: subfolder, type: type));
              }
            }
          }
        }

        // Check for video output (some nodes use 'video' key)
        final nodeVideos = nodeOutput['video'] as List?;
        if (nodeVideos != null) {
          for (final video in nodeVideos) {
            if (video is Map<String, dynamic>) {
              final filename = video['filename'] as String?;
              final subfolder = video['subfolder'] as String? ?? '';
              final type = video['type'] as String? ?? 'output';
              if (filename != null) {
                images.add(getImageUrl(filename, subfolder: subfolder, type: type));
              }
            }
          }
        }

        // Check for videos output (plural, SaveVideo uses this)
        final nodeVideosList = nodeOutput['videos'] as List?;
        if (nodeVideosList != null) {
          for (final video in nodeVideosList) {
            if (video is Map<String, dynamic>) {
              final filename = video['filename'] as String?;
              final subfolder = video['subfolder'] as String? ?? '';
              final type = video['type'] as String? ?? 'output';
              if (filename != null) {
                images.add(getImageUrl(filename, subfolder: subfolder, type: type));
              }
            }
          }
        }

        // Check for files output (generic file output)
        final nodeFiles = nodeOutput['files'] as List?;
        if (nodeFiles != null) {
          for (final file in nodeFiles) {
            if (file is Map<String, dynamic>) {
              final filename = file['filename'] as String?;
              final subfolder = file['subfolder'] as String? ?? '';
              final type = file['type'] as String? ?? 'output';
              if (filename != null) {
                images.add(getImageUrl(filename, subfolder: subfolder, type: type));
              }
            }
          }
        }
      }
    }

    return images;
  }

  /// Wait for a prompt to complete (polling fallback)
  Future<Map<String, dynamic>?> waitForCompletion(
    String promptId, {
    Duration timeout = const Duration(minutes: 10),
    Duration pollInterval = const Duration(seconds: 1),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      final history = await getHistory(promptId);
      if (history != null) {
        // Check if execution completed
        final status = history['status'] as Map<String, dynamic>?;
        if (status != null) {
          final completed = status['completed'] as bool?;
          if (completed == true) {
            return history;
          }
        }
        // Alternatively check if outputs exist
        final outputs = history['outputs'] as Map<String, dynamic>?;
        if (outputs != null && outputs.isNotEmpty) {
          return history;
        }
      }
      await Future.delayed(pollInterval);
    }

    return null;
  }

  /// Dispose resources
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _connectionStateController.close();
    _progressController.close();
    _errorController.close();
    _rawMessageController.close();
  }
}
