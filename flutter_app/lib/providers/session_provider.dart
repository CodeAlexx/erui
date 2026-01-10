import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/comfyui_service.dart';
import '../services/storage_service.dart';

/// Session state provider - manages ComfyUI connection
final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  return SessionNotifier(comfyService);
});

/// Session state - tracks ComfyUI connection
class SessionState {
  final String? sessionId;  // ComfyUI client_id (optional)
  final String host;
  final int port;
  final bool isConnected;
  final bool isLoading;
  final String? error;

  // For backwards compatibility with SwarmUI-style code
  final String? userId;
  final String? username;

  const SessionState({
    this.sessionId,
    this.host = 'localhost',
    this.port = 8199,
    this.isConnected = false,
    this.isLoading = false,
    this.error,
    this.userId,
    this.username,
  });

  SessionState copyWith({
    String? sessionId,
    String? host,
    int? port,
    bool? isConnected,
    bool? isLoading,
    String? error,
    String? userId,
    String? username,
  }) {
    return SessionState(
      sessionId: sessionId ?? this.sessionId,
      host: host ?? this.host,
      port: port ?? this.port,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      userId: userId ?? this.userId,
      username: username ?? this.username,
    );
  }

  /// For backwards compatibility
  bool get isAuthenticated => isConnected;
  List<String> get permissions => isConnected ? ['*'] : [];
  bool hasPermission(String permission) => isConnected;
}

/// Session notifier - manages ComfyUI connection
class SessionNotifier extends StateNotifier<SessionState> {
  final ComfyUIService _comfyService;

  SessionNotifier(this._comfyService) : super(const SessionState()) {
    _initConnection();
    _listenToConnectionState();
  }

  /// Initialize connection from saved settings
  Future<void> _initConnection() async {
    final savedHost = StorageService.getStringStatic('comfy_host') ?? 'localhost';
    final savedPort = StorageService.getIntStatic('comfy_port') ?? 8199;

    state = state.copyWith(host: savedHost, port: savedPort);
    _comfyService.configure(host: savedHost, port: savedPort);

    // Auto-connect on startup
    await connect();
  }

  /// Listen to connection state changes
  void _listenToConnectionState() {
    _comfyService.connectionState.listen((comfyState) {
      switch (comfyState) {
        case ComfyConnectionState.connected:
          state = state.copyWith(isConnected: true, isLoading: false, error: null);
          break;
        case ComfyConnectionState.disconnected:
          state = state.copyWith(isConnected: false, isLoading: false);
          break;
        case ComfyConnectionState.connecting:
          state = state.copyWith(isLoading: true, error: null);
          break;
        case ComfyConnectionState.error:
          state = state.copyWith(isConnected: false, isLoading: false);
          break;
      }
    });
  }

  /// Connect to ComfyUI
  Future<bool> connect() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _comfyService.connect();

      if (success) {
        state = state.copyWith(isConnected: true, isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isConnected: false,
          isLoading: false,
          error: 'Failed to connect to ComfyUI at ${state.host}:${state.port}',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isConnected: false,
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Configure and connect to a different ComfyUI instance
  Future<bool> configureAndConnect({required String host, required int port}) async {
    // Save settings
    await StorageService.setStringStatic('comfy_host', host);
    await StorageService.setIntStatic('comfy_port', port);

    state = state.copyWith(host: host, port: port);
    _comfyService.configure(host: host, port: port);

    return connect();
  }

  /// Disconnect
  Future<void> disconnect() async {
    await _comfyService.disconnect();
    state = state.copyWith(isConnected: false);
  }

  /// For backwards compatibility - createSession just connects
  Future<bool> createSession() async => connect();

  /// For backwards compatibility - login not needed for ComfyUI
  Future<bool> login(String username, String password) async => connect();

  /// For backwards compatibility - logout just disconnects
  Future<void> logout() async => disconnect();
}
