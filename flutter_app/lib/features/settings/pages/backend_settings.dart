import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/providers.dart';
import '../../../services/api_service.dart';
import '../widgets/settings_section.dart';

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
    final connectionInfo = ref.watch(connectionStateProvider);
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
          'Backend',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Configure backend server connection',
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
          title: 'Server Configuration',
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '7802',
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
                            await ref.read(connectionStateProvider.notifier).disconnect();
                          },
                          icon: const Icon(Icons.power_off),
                          label: const Text('Disconnect'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: connectionInfo.isConnecting
                              ? null
                              : () async {
                                  final port = int.tryParse(_portController.text) ?? 7802;
                                  await ref.read(connectionStateProvider.notifier).updateSettings(
                                        host: _hostController.text,
                                        port: port,
                                      );
                                  await ref.read(connectionStateProvider.notifier).connect();
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
                        onPressed: () {
                          // TODO: Test connection
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
        // Backend type
        SettingsSection(
          title: 'Backend Type',
          children: [
            RadioListTile<String>(
              title: const Text('ComfyUI'),
              subtitle: const Text('Node-based workflow backend (recommended)'),
              value: 'comfyui',
              groupValue: 'comfyui',
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            RadioListTile<String>(
              title: const Text('Auto1111'),
              subtitle: const Text('Automatic1111 Stable Diffusion WebUI'),
              value: 'auto1111',
              groupValue: 'comfyui',
              onChanged: (value) {
                // TODO: Implement
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Auto-connect
        SettingsSection(
          title: 'Connection Settings',
          children: [
            SwitchListTile(
              title: const Text('Auto-connect on startup'),
              subtitle: const Text('Automatically connect when app starts'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            SwitchListTile(
              title: const Text('Auto-reconnect'),
              subtitle: const Text('Automatically reconnect if connection is lost'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(ApiConnectionState state) {
    switch (state) {
      case ApiConnectionState.connected:
        return Colors.green;
      case ApiConnectionState.connecting:
        return Colors.orange;
      case ApiConnectionState.error:
        return Colors.red;
      case ApiConnectionState.disconnected:
        return Colors.grey;
    }
  }
}
