import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/comfyui_service.dart';
import '../services/storage_service.dart';

/// Connection state provider
final connectionStateProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionInfo>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  return ConnectionNotifier(comfyService);
});

/// Connection information
class ConnectionInfo {
  final String host;
  final int port;
  final ComfyConnectionState state;
  final String? errorMessage;

  const ConnectionInfo({
    this.host = 'localhost',
    this.port = 8188,
    this.state = ComfyConnectionState.disconnected,
    this.errorMessage,
  });

  ConnectionInfo copyWith({
    String? host,
    int? port,
    ComfyConnectionState? state,
    String? errorMessage,
  }) {
    return ConnectionInfo(
      host: host ?? this.host,
      port: port ?? this.port,
      state: state ?? this.state,
      errorMessage: errorMessage,
    );
  }

  bool get isConnected => state == ComfyConnectionState.connected;
  bool get isConnecting => state == ComfyConnectionState.connecting;
  bool get hasError => state == ComfyConnectionState.error;

  String get statusText {
    switch (state) {
      case ComfyConnectionState.disconnected:
        return 'Disconnected';
      case ComfyConnectionState.connecting:
        return 'Connecting...';
      case ComfyConnectionState.connected:
        return 'Connected';
      case ComfyConnectionState.error:
        return errorMessage ?? 'Error';
    }
  }
}

/// Connection state notifier
class ConnectionNotifier extends StateNotifier<ConnectionInfo> {
  final ComfyUIService _comfyService;

  ConnectionNotifier(this._comfyService) : super(const ConnectionInfo()) {
    _loadSavedConnection();
    _listenToConnectionState();
    // Auto-connect on startup
    Future.delayed(const Duration(milliseconds: 500), () => connect());
  }

  /// Load saved connection settings
  Future<void> _loadSavedConnection() async {
    final host = StorageService.getStringStatic('comfyui_host') ?? 'localhost';
    final port = StorageService.getInt('comfyui_port') ?? 8188;

    state = state.copyWith(host: host, port: port);
    _comfyService.configure(host: host, port: port);
  }

  /// Listen to connection state changes
  void _listenToConnectionState() {
    _comfyService.connectionState.listen((connectionState) {
      state = state.copyWith(state: connectionState);
    });
  }

  /// Update connection settings
  Future<void> updateSettings({required String host, required int port}) async {
    state = state.copyWith(host: host, port: port);

    await StorageService.setStringStatic('comfyui_host', host);
    await StorageService.setInt('comfyui_port', port);

    _comfyService.configure(host: host, port: port);
  }

  /// Connect to ComfyUI backend
  Future<bool> connect() async {
    state = state.copyWith(
      state: ComfyConnectionState.connecting,
      errorMessage: null,
    );

    try {
      final success = await _comfyService.connect();
      if (success) {
        state = state.copyWith(state: ComfyConnectionState.connected);
        return true;
      } else {
        state = state.copyWith(
          state: ComfyConnectionState.error,
          errorMessage: 'Failed to connect to ComfyUI',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        state: ComfyConnectionState.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Disconnect from ComfyUI backend
  Future<void> disconnect() async {
    await _comfyService.disconnect();
    state = state.copyWith(state: ComfyConnectionState.disconnected);
  }
}
