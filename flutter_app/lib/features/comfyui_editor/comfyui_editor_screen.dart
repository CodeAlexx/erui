import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ComfyUI Editor Screen - Launches ComfyUI in app-mode browser
class ComfyUIEditorScreen extends ConsumerStatefulWidget {
  const ComfyUIEditorScreen({super.key});

  @override
  ConsumerState<ComfyUIEditorScreen> createState() => _ComfyUIEditorScreenState();
}

class _ComfyUIEditorScreenState extends ConsumerState<ComfyUIEditorScreen> {
  final String _comfyUrl = 'http://127.0.0.1:8199';
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isLaunched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() => _isLoading = true);
    try {
      final socket = await Socket.connect('127.0.0.1', 8199, timeout: const Duration(seconds: 3));
      socket.destroy();
      setState(() {
        _isConnected = true;
        _isLoading = false;
      });
      if (!_isLaunched) _launchComfyUI();
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isLoading = false;
        _error = 'ComfyUI not running on port 8199';
      });
    }
  }

  Future<void> _launchComfyUI() async {
    if (_isLaunched) return;
    try {
      final browsers = [
        ['chromium', '--app=$_comfyUrl', '--window-size=1600,1000'],
        ['chromium-browser', '--app=$_comfyUrl', '--window-size=1600,1000'],
        ['google-chrome', '--app=$_comfyUrl', '--window-size=1600,1000'],
        ['firefox', '--new-window', _comfyUrl],
      ];
      for (final browser in browsers) {
        try {
          await Process.start(browser[0], browser.sublist(1));
          setState(() => _isLaunched = true);
          return;
        } catch (_) {
          continue;
        }
      }
      await Process.start('xdg-open', [_comfyUrl]);
      setState(() => _isLaunched = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isConnected ? Icons.check_circle : Icons.cloud_off,
                      size: 64, color: _isConnected ? Colors.green : Colors.red),
                  const SizedBox(height: 16),
                  Text(_isConnected ? 'ComfyUI Launched' : 'ComfyUI Not Running',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 8),
                  Text(_isConnected ? 'Opened in separate window' : (_error ?? ''),
                      style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isConnected ? () { setState(() => _isLaunched = false); _launchComfyUI(); } : _checkConnection,
                    icon: Icon(_isConnected ? Icons.open_in_new : Icons.refresh),
                    label: Text(_isConnected ? 'Open Again' : 'Retry'),
                  ),
                ],
              ),
      ),
    );
  }
}
