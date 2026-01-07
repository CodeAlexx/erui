import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

import '../../utils/logging.dart';
import '../../core/events.dart';

/// WebSocket client for real-time ComfyUI communication
class ComfyUIWebSocket {
  /// WebSocket URL (ws:// or wss://)
  final String wsUrl;

  /// Client ID for this connection
  final String clientId;

  /// Internal WebSocket channel
  WebSocketChannel? _channel;

  /// Connection state
  bool _connected = false;
  bool _connecting = false;

  /// Reconnection settings
  final Duration reconnectDelay;
  final int maxReconnectAttempts;
  int _reconnectAttempts = 0;

  /// Message stream controller
  final StreamController<ComfyUIMessage> _messageController =
      StreamController<ComfyUIMessage>.broadcast();

  /// Progress stream controller
  final StreamController<ComfyUIProgress> _progressController =
      StreamController<ComfyUIProgress>.broadcast();

  /// Status stream controller
  final StreamController<ComfyUIExecutionStatus> _statusController =
      StreamController<ComfyUIExecutionStatus>.broadcast();

  /// Preview image stream controller
  final StreamController<Uint8List> _previewController =
      StreamController<Uint8List>.broadcast();

  /// Completion events by prompt ID
  final Map<String, Completer<ComfyUIExecutionResult>> _completions = {};

  /// All messages stream
  Stream<ComfyUIMessage> get messages => _messageController.stream;

  /// Progress updates stream
  Stream<ComfyUIProgress> get progress => _progressController.stream;

  /// Status updates stream
  Stream<ComfyUIExecutionStatus> get status => _statusController.stream;

  /// Preview images stream
  Stream<Uint8List> get previews => _previewController.stream;

  /// Whether connected
  bool get isConnected => _connected;

  ComfyUIWebSocket({
    required String baseUrl,
    String? clientId,
    this.reconnectDelay = const Duration(seconds: 2),
    this.maxReconnectAttempts = 10,
  })  : clientId = clientId ?? const Uuid().v4(),
        wsUrl = _buildWsUrl(baseUrl, clientId ?? const Uuid().v4());

  static String _buildWsUrl(String baseUrl, String clientId) {
    // Convert http(s) to ws(s)
    var wsUrl = baseUrl;
    if (wsUrl.startsWith('http://')) {
      wsUrl = 'ws://${wsUrl.substring(7)}';
    } else if (wsUrl.startsWith('https://')) {
      wsUrl = 'wss://${wsUrl.substring(8)}';
    } else if (!wsUrl.startsWith('ws://') && !wsUrl.startsWith('wss://')) {
      wsUrl = 'ws://$wsUrl';
    }

    // Ensure trailing slash and add ws path
    if (!wsUrl.endsWith('/')) {
      wsUrl += '/';
    }
    return '${wsUrl}ws?clientId=$clientId';
  }

  /// Connect to WebSocket
  Future<void> connect() async {
    if (_connected || _connecting) return;

    _connecting = true;

    try {
      Logs.debug('Connecting to ComfyUI WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Wait for connection
      await _channel!.ready;

      _connected = true;
      _connecting = false;
      _reconnectAttempts = 0;

      // Start listening
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      Logs.info('Connected to ComfyUI WebSocket');
    } catch (e) {
      _connecting = false;
      _connected = false;
      Logs.error('Failed to connect to ComfyUI WebSocket: $e');
      _scheduleReconnect();
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _reconnectAttempts = maxReconnectAttempts; // Prevent reconnection
    _connected = false;
    _connecting = false;

    await _channel?.sink.close();
    _channel = null;
  }

  /// Handle incoming message
  void _handleMessage(dynamic data) {
    try {
      if (data is String) {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final message = ComfyUIMessage.fromJson(json);
        _messageController.add(message);
        _processMessage(message);
      } else if (data is List<int>) {
        // Binary data is a preview image
        // First 4 bytes are event type, rest is image data
        if (data.length > 8) {
          final imageData = Uint8List.fromList(data.sublist(8));
          _previewController.add(imageData);
        }
      }
    } catch (e) {
      Logs.warning('Error parsing WebSocket message: $e');
    }
  }

  /// Process a parsed message
  void _processMessage(ComfyUIMessage message) {
    switch (message.type) {
      case 'status':
        final statusData = message.data['status'] as Map<String, dynamic>?;
        if (statusData != null) {
          final execInfo = statusData['exec_info'] as Map<String, dynamic>?;
          final queueRemaining = execInfo?['queue_remaining'] as int? ?? 0;
          _statusController.add(ComfyUIExecutionStatus(
            queueRemaining: queueRemaining,
          ));
        }
        break;

      case 'progress':
        final progress = ComfyUIProgress(
          value: message.data['value'] as int? ?? 0,
          max: message.data['max'] as int? ?? 100,
          promptId: message.data['prompt_id'] as String?,
          nodeId: message.data['node'] as String?,
        );
        _progressController.add(progress);
        break;

      case 'executing':
        final nodeId = message.data['node'] as String?;
        final promptId = message.data['prompt_id'] as String?;

        if (nodeId == null && promptId != null) {
          // Execution complete
          final completer = _completions.remove(promptId);
          if (completer != null && !completer.isCompleted) {
            completer.complete(ComfyUIExecutionResult(
              promptId: promptId,
              success: true,
            ));
          }
        }
        break;

      case 'executed':
        final promptId = message.data['prompt_id'] as String?;
        final outputData = message.data['output'] as Map<String, dynamic>?;

        if (promptId != null) {
          final completer = _completions[promptId];
          if (completer != null && !completer.isCompleted) {
            completer.complete(ComfyUIExecutionResult(
              promptId: promptId,
              success: true,
              outputs: outputData,
            ));
          }
        }
        break;

      case 'execution_start':
        final promptId = message.data['prompt_id'] as String?;
        Logs.debug('Execution started: $promptId');
        break;

      case 'execution_cached':
        final promptId = message.data['prompt_id'] as String?;
        final nodes = message.data['nodes'] as List?;
        Logs.debug('Execution cached for prompt $promptId: ${nodes?.length ?? 0} nodes');
        break;

      case 'execution_error':
        final promptId = message.data['prompt_id'] as String?;
        final errorMessage = message.data['exception_message'] as String?;

        if (promptId != null) {
          final completer = _completions.remove(promptId);
          if (completer != null && !completer.isCompleted) {
            completer.complete(ComfyUIExecutionResult(
              promptId: promptId,
              success: false,
              error: errorMessage,
            ));
          }
        }
        break;

      case 'execution_interrupted':
        final promptId = message.data['prompt_id'] as String?;
        if (promptId != null) {
          final completer = _completions.remove(promptId);
          if (completer != null && !completer.isCompleted) {
            completer.complete(ComfyUIExecutionResult(
              promptId: promptId,
              success: false,
              error: 'Execution interrupted',
              interrupted: true,
            ));
          }
        }
        break;
    }
  }

  /// Handle WebSocket error
  void _handleError(dynamic error) {
    Logs.error('ComfyUI WebSocket error: $error');
    _connected = false;
    _scheduleReconnect();
  }

  /// Handle WebSocket disconnect
  void _handleDisconnect() {
    Logs.warning('ComfyUI WebSocket disconnected');
    _connected = false;
    _channel = null;
    _scheduleReconnect();
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      Logs.error('Max reconnection attempts reached');
      return;
    }

    _reconnectAttempts++;
    final delay = reconnectDelay * _reconnectAttempts;
    Logs.info('Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    Future.delayed(delay, () {
      if (!_connected && _reconnectAttempts < maxReconnectAttempts) {
        connect();
      }
    });
  }

  /// Wait for a specific prompt to complete
  Future<ComfyUIExecutionResult> waitForCompletion(
    String promptId, {
    Duration? timeout,
    CancellationToken? cancel,
  }) async {
    final completer = Completer<ComfyUIExecutionResult>();
    _completions[promptId] = completer;

    try {
      if (timeout != null) {
        return await completer.future.timeout(timeout);
      }

      if (cancel != null) {
        return await Future.any([
          completer.future,
          cancel.whenCancelled.then((_) {
            throw CancelledException('Wait cancelled');
          }),
        ]);
      }

      return await completer.future;
    } catch (e) {
      _completions.remove(promptId);
      rethrow;
    }
  }

  /// Send a message through WebSocket
  void send(Map<String, dynamic> message) {
    if (!_connected || _channel == null) {
      throw StateError('WebSocket not connected');
    }
    _channel!.sink.add(jsonEncode(message));
  }

  /// Close and cleanup
  Future<void> close() async {
    await disconnect();
    await _messageController.close();
    await _progressController.close();
    await _statusController.close();
    await _previewController.close();
  }
}

/// Parsed WebSocket message
class ComfyUIMessage {
  final String type;
  final Map<String, dynamic> data;

  ComfyUIMessage({
    required this.type,
    required this.data,
  });

  factory ComfyUIMessage.fromJson(Map<String, dynamic> json) {
    return ComfyUIMessage(
      type: json['type'] as String? ?? 'unknown',
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  String toString() => 'ComfyUIMessage($type)';
}

/// Progress update
class ComfyUIProgress {
  final int value;
  final int max;
  final String? promptId;
  final String? nodeId;

  ComfyUIProgress({
    required this.value,
    required this.max,
    this.promptId,
    this.nodeId,
  });

  double get percent => max > 0 ? value / max : 0;

  @override
  String toString() => 'Progress($value/$max)';
}

/// Execution status
class ComfyUIExecutionStatus {
  final int queueRemaining;

  ComfyUIExecutionStatus({
    required this.queueRemaining,
  });
}

/// Execution result
class ComfyUIExecutionResult {
  final String promptId;
  final bool success;
  final String? error;
  final bool interrupted;
  final Map<String, dynamic>? outputs;

  ComfyUIExecutionResult({
    required this.promptId,
    required this.success,
    this.error,
    this.interrupted = false,
    this.outputs,
  });

  /// Get output images from a specific node
  List<ComfyUIOutputImage> getImages(String nodeId) {
    if (outputs == null) return [];

    final nodeOutput = outputs![nodeId] as Map<String, dynamic>?;
    if (nodeOutput == null) return [];

    final images = nodeOutput['images'] as List?;
    if (images == null) return [];

    return images.map((img) {
      final imgMap = img as Map<String, dynamic>;
      return ComfyUIOutputImage(
        filename: imgMap['filename'] as String,
        subfolder: imgMap['subfolder'] as String? ?? '',
        type: imgMap['type'] as String? ?? 'output',
      );
    }).toList();
  }

  @override
  String toString() => 'ExecutionResult($promptId, success: $success)';
}

/// Output image reference
class ComfyUIOutputImage {
  final String filename;
  final String subfolder;
  final String type;

  ComfyUIOutputImage({
    required this.filename,
    required this.subfolder,
    required this.type,
  });

  /// Get the full path for fetching
  String get fullPath {
    if (subfolder.isNotEmpty) {
      return '$subfolder/$filename';
    }
    return filename;
  }
}
