import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/comfyui_service.dart';
import '../../../services/storage_service.dart';
import '../widgets/settings_section.dart';

/// ComfyUI connection state provider
final comfyConnectionStateProvider =
    StateNotifierProvider<ComfyConnectionNotifier, ComfyConnectionInfo>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  return ComfyConnectionNotifier(comfyService);
});

/// Connection information for ComfyUI
class ComfyConnectionInfo {
  final String host;
  final int port;
  final ComfyConnectionState state;
  final String? errorMessage;
  final bool autoConnect;
  final bool autoReconnect;

  const ComfyConnectionInfo({
    this.host = 'localhost',
    this.port = 8188,
    this.state = ComfyConnectionState.disconnected,
    this.errorMessage,
    this.autoConnect = true,
    this.autoReconnect = true,
  });

  ComfyConnectionInfo copyWith({
    String? host,
    int? port,
    ComfyConnectionState? state,
    String? errorMessage,
    bool? autoConnect,
    bool? autoReconnect,
  }) {
    return ComfyConnectionInfo(
      host: host ?? this.host,
      port: port ?? this.port,
      state: state ?? this.state,
      errorMessage: errorMessage,
      autoConnect: autoConnect ?? this.autoConnect,
      autoReconnect: autoReconnect ?? this.autoReconnect,
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

/// ComfyUI connection state notifier
class ComfyConnectionNotifier extends StateNotifier<ComfyConnectionInfo> {
  final ComfyUIService _comfyService;

  ComfyConnectionNotifier(this._comfyService) : super(const ComfyConnectionInfo()) {
    _loadSavedConnection();
    _listenToConnectionState();
  }

  /// Load saved connection settings
  Future<void> _loadSavedConnection() async {
    final host = StorageService.getStringStatic('comfy_host') ?? 'localhost';
    final port = StorageService.getInt('comfy_port') ?? 8188;
    final autoConnect = StorageService.getBool('comfy_auto_connect') ?? true;
    final autoReconnect = StorageService.getBool('comfy_auto_reconnect') ?? true;

    state = state.copyWith(
      host: host,
      port: port,
      autoConnect: autoConnect,
      autoReconnect: autoReconnect,
    );
    _comfyService.configure(host: host, port: port);

    // Auto-connect on startup if enabled
    if (autoConnect) {
      Future.delayed(const Duration(milliseconds: 500), () => connect());
    }
  }

  /// Listen to connection state changes
  void _listenToConnectionState() {
    _comfyService.connectionState.listen((connectionState) {
      state = state.copyWith(state: connectionState);
    });
  }

  /// Update connection settings
  Future<void> updateSettings({
    String? host,
    int? port,
    bool? autoConnect,
    bool? autoReconnect,
  }) async {
    if (host != null) {
      state = state.copyWith(host: host);
      await StorageService.setStringStatic('comfy_host', host);
    }
    if (port != null) {
      state = state.copyWith(port: port);
      await StorageService.setInt('comfy_port', port);
    }
    if (autoConnect != null) {
      state = state.copyWith(autoConnect: autoConnect);
      await StorageService.setBool('comfy_auto_connect', autoConnect);
    }
    if (autoReconnect != null) {
      state = state.copyWith(autoReconnect: autoReconnect);
      await StorageService.setBool('comfy_auto_reconnect', autoReconnect);
    }

    _comfyService.configure(host: state.host, port: state.port);
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

/// Backend settings page
class BackendSettingsPage extends ConsumerStatefulWidget {
  const BackendSettingsPage({super.key});

  @override
  ConsumerState<BackendSettingsPage> createState() => _BackendSettingsPageState();
}

class _BackendSettingsPageState extends ConsumerState<BackendSettingsPage> {
  late TextEditingController _hostController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _portController = TextEditingController();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionInfo = ref.watch(comfyConnectionStateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Initialize controllers from state
    if (_hostController.text.isEmpty) {
      _hostController.text = connectionInfo.host;
      _portController.text = connectionInfo.port.toString();
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'ComfyUI Backend',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Configure ComfyUI server connection',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
        ),
        const SizedBox(height: 24),
        // Connection status
        SettingsSection(
          title: 'Connection Status',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor(connectionInfo.state),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connectionInfo.statusText,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (connectionInfo.isConnected)
                          Text(
                            '${connectionInfo.host}:${connectionInfo.port}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                          ),
                      ],
                    ),
                  ),
                  if (connectionInfo.isConnecting)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Server configuration
        SettingsSection(
          title: 'ComfyUI Server',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: 'Host',
                            hintText: 'localhost',
                            helperText: 'ComfyUI server hostname or IP',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '8188',
                            helperText: 'Default: 8188',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (connectionInfo.isConnected)
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref.read(comfyConnectionStateProvider.notifier).disconnect();
                          },
                          icon: const Icon(Icons.power_off),
                          label: const Text('Disconnect'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: connectionInfo.isConnecting
                              ? null
                              : () async {
                                  final port = int.tryParse(_portController.text) ?? 8188;
                                  await ref.read(comfyConnectionStateProvider.notifier).updateSettings(
                                        host: _hostController.text,
                                        port: port,
                                      );
                                  await ref.read(comfyConnectionStateProvider.notifier).connect();
                                },
                          icon: connectionInfo.isConnecting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.power),
                          label: Text(connectionInfo.isConnecting ? 'Connecting...' : 'Connect'),
                        ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final comfyService = ref.read(comfyUIServiceProvider);
                          final stats = await comfyService.getSystemStats();
                          if (stats != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('ComfyUI is responding. System stats received.')),
                            );
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to get ComfyUI stats')),
                            );
                          }
                        },
                        icon: const Icon(Icons.speed),
                        label: const Text('Test'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Connection Settings
        SettingsSection(
          title: 'Connection Settings',
          children: [
            SwitchListTile(
              title: const Text('Auto-connect on startup'),
              subtitle: const Text('Automatically connect when app starts'),
              value: connectionInfo.autoConnect,
              onChanged: (value) async {
                await ref.read(comfyConnectionStateProvider.notifier).updateSettings(
                  autoConnect: value,
                );
              },
            ),
            SwitchListTile(
              title: const Text('Auto-reconnect'),
              subtitle: const Text('Automatically reconnect if connection is lost'),
              value: connectionInfo.autoReconnect,
              onChanged: (value) async {
                await ref.read(comfyConnectionStateProvider.notifier).updateSettings(
                  autoReconnect: value,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Info section
        SettingsSection(
          title: 'About ComfyUI',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EriUI connects directly to ComfyUI for image generation. '
                    'Make sure ComfyUI is running and accessible at the configured address.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Default ComfyUI port: 8188',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(ComfyConnectionState state) {
    switch (state) {
      case ComfyConnectionState.connected:
        return Colors.green;
      case ComfyConnectionState.connecting:
        return Colors.orange;
      case ComfyConnectionState.error:
        return Colors.red;
      case ComfyConnectionState.disconnected:
        return Colors.grey;
    }
  }
}
