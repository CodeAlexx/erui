import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:convert';

/// API service provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

/// API Service for communicating with the EriUI backend
class ApiService {
  late Dio _dio;
  WebSocketChannel? _wsChannel;
  String _baseUrl = 'http://localhost:7802';
  String _wsUrl = 'ws://localhost:7802/ws';

  final _connectionStateController = StreamController<ApiConnectionState>.broadcast();
  Stream<ApiConnectionState> get connectionState => _connectionStateController.stream;

  final _wsMessageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get wsMessages => _wsMessageController.stream;

  ApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  /// Configure the API service with base URL
  void configure({required String host, required int port}) {
    _baseUrl = 'http://$host:$port';
    _wsUrl = 'ws://$host:$port/ws';
    _dio.options.baseUrl = _baseUrl;
  }

  /// Get base URL
  String get baseUrl => _baseUrl;

  /// Connect to the backend
  Future<bool> connect() async {
    try {
      _connectionStateController.add(ApiConnectionState.connecting);

      // Test HTTP connection
      final response = await _dio.get('$_baseUrl/API/GetServerInfo');
      if (response.statusCode != 200) {
        _connectionStateController.add(ApiConnectionState.disconnected);
        return false;
      }

      // WebSocket is optional - don't fail if it doesn't connect
      try {
        await _connectWebSocket();
      } catch (e) {
        // WebSocket failed but HTTP works, still connected
        print('WebSocket connection failed (optional): $e');
      }

      _connectionStateController.add(ApiConnectionState.connected);
      return true;
    } catch (e) {
      _connectionStateController.add(ApiConnectionState.error);
      return false;
    }
  }

  /// Disconnect from the backend
  Future<void> disconnect() async {
    await _wsChannel?.sink.close();
    _wsChannel = null;
    _connectionStateController.add(ApiConnectionState.disconnected);
  }

  /// Connect WebSocket
  Future<void> _connectWebSocket() async {
    _wsChannel = WebSocketChannel.connect(Uri.parse(_wsUrl));

    _wsChannel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          _wsMessageController.add(data);
        } catch (e) {
          // Ignore parse errors
        }
      },
      onError: (error) {
        // WebSocket is optional - don't change connection state
        print('WebSocket error (ignored): $error');
      },
      onDone: () {
        // WebSocket is optional - don't change connection state
        print('WebSocket closed (ignored)');
      },
    );
  }

  /// Send WebSocket message
  void sendWsMessage(Map<String, dynamic> message) {
    _wsChannel?.sink.add(jsonEncode(message));
  }

  /// Generic GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl$endpoint',
        queryParameters: queryParameters,
      );
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data as T,
        statusCode: response.statusCode ?? 200,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.message ?? 'Request failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Generic POST request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl$endpoint',
        data: data,
        queryParameters: queryParameters,
      );
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data as T,
        statusCode: response.statusCode ?? 200,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.message ?? 'Request failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Generic DELETE request
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl$endpoint',
        queryParameters: queryParameters,
      );
      return ApiResponse.success(
        data: fromJson != null ? fromJson(response.data) : response.data as T,
        statusCode: response.statusCode ?? 200,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.message ?? 'Request failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Simple GET that returns Map directly (for convenience)
  Future<Map<String, dynamic>?> getJson(String endpoint) async {
    final response = await get<Map<String, dynamic>>(endpoint);
    return response.isSuccess ? response.data : null;
  }

  /// Simple POST that returns Map directly (for convenience)
  Future<Map<String, dynamic>?> postJson(String endpoint, Map<String, dynamic> data) async {
    final response = await post<Map<String, dynamic>>(endpoint, data: data);
    return response.isSuccess ? response.data : null;
  }

  /// Simple DELETE that returns Map directly (for convenience)
  Future<Map<String, dynamic>?> deleteJson(String endpoint) async {
    final response = await delete<Map<String, dynamic>>(endpoint);
    return response.isSuccess ? response.data : null;
  }

  /// Dispose resources
  void dispose() {
    _wsChannel?.sink.close();
    _connectionStateController.close();
    _wsMessageController.close();
  }
}

/// Connection state enum (renamed to avoid Flutter conflict)
enum ApiConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Generic API response wrapper
class ApiResponse<T> {
  final T? data;
  final String? error;
  final int? statusCode;
  final bool isSuccess;

  ApiResponse._({
    this.data,
    this.error,
    this.statusCode,
    required this.isSuccess,
  });

  factory ApiResponse.success({
    required T data,
    int statusCode = 200,
  }) {
    return ApiResponse._(
      data: data,
      statusCode: statusCode,
      isSuccess: true,
    );
  }

  factory ApiResponse.error({
    required String message,
    int? statusCode,
  }) {
    return ApiResponse._(
      error: message,
      statusCode: statusCode,
      isSuccess: false,
    );
  }
}
