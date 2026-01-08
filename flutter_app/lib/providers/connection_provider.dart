import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Connection state provider
final connectionStateProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionInfo>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return ConnectionNotifier(apiService);
});

/// Connection information
class ConnectionInfo {
  final String host;
  final int port;
  final ApiConnectionState state;
  final String? errorMessage;

  const ConnectionInfo({
    this.host = 'localhost',
    this.port = 7803,
    this.state = ApiConnectionState.disconnected,
    this.errorMessage,
  });

  ConnectionInfo copyWith({
    String? host,
    int? port,
    ApiConnectionState? state,
    String? errorMessage,
  }) {
    return ConnectionInfo(
      host: host ?? this.host,
      port: port ?? this.port,
      state: state ?? this.state,
      errorMessage: errorMessage,
    );
  }

  bool get isConnected => state == ApiConnectionState.connected;
  bool get isConnecting => state == ApiConnectionState.connecting;
  bool get hasError => state == ApiConnectionState.error;

  String get statusText {
    switch (state) {
      case ApiConnectionState.disconnected:
        return 'Disconnected';
      case ApiConnectionState.connecting:
        return 'Connecting...';
      case ApiConnectionState.connected:
        return 'Connected';
      case ApiConnectionState.error:
        return errorMessage ?? 'Error';
    }
  }
}

/// Connection state notifier
class ConnectionNotifier extends StateNotifier<ConnectionInfo> {
  final ApiService _apiService;

  ConnectionNotifier(this._apiService) : super(const ConnectionInfo()) {
    _loadSavedConnection();
    _listenToConnectionState();
    // Auto-connect on startup
    Future.delayed(const Duration(milliseconds: 500), () => connect());
  }

  /// Load saved connection settings
  Future<void> _loadSavedConnection() async {
    final host = StorageService.getStringStatic('backend_host') ?? 'localhost';
    final port = StorageService.getInt('backend_port') ?? 7803;

    state = state.copyWith(host: host, port: port);
    _apiService.configure(host: host, port: port);
  }

  /// Listen to connection state changes
  void _listenToConnectionState() {
    _apiService.connectionState.listen((connectionState) {
      state = state.copyWith(state: connectionState);
    });
  }

  /// Update connection settings
  Future<void> updateSettings({required String host, required int port}) async {
    state = state.copyWith(host: host, port: port);

    await StorageService.setStringStatic('backend_host', host);
    await StorageService.setInt('backend_port', port);

    _apiService.configure(host: host, port: port);
  }

  /// Connect to backend
  Future<bool> connect() async {
    state = state.copyWith(
      state: ApiConnectionState.connecting,
      errorMessage: null,
    );

    try {
      final success = await _apiService.connect();
      if (success) {
        state = state.copyWith(state: ApiConnectionState.connected);
        return true;
      } else {
        state = state.copyWith(
          state: ApiConnectionState.error,
          errorMessage: 'Failed to connect',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        state: ApiConnectionState.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Disconnect from backend
  Future<void> disconnect() async {
    await _apiService.disconnect();
    state = state.copyWith(state: ApiConnectionState.disconnected);
  }
}
