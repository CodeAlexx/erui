import 'dart:async';
import 'dart:io';

import '../models/editor_models.dart';
import '../models/proxy_models.dart';
import 'ffmpeg_service.dart';

/// Service for generating and managing proxy files
class ProxyService {
  final FFmpegService _ffmpeg;

  /// Proxy cache directory
  final String _cacheDir;

  ProxyService({
    FFmpegService? ffmpeg,
    String? cacheDir,
  })  : _ffmpeg = ffmpeg ?? FFmpegService(),
        _cacheDir = cacheDir ?? _getDefaultCacheDir();

  static String _getDefaultCacheDir() {
    // Use system temp directory for proxies
    return '${Directory.systemTemp.path}/flutter_editor_proxies';
  }

  /// Initialize proxy service and create cache directory
  Future<void> initialize() async {
    final dir = Directory(_cacheDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Generate proxy file for a clip
  Future<ProxyFile> generateProxy(
    String sourcePath,
    EditorId clipId,
    ProxySettings settings, {
    Function(double progress)? onProgress,
  }) async {
    // Get source video info
    final info = await _ffmpeg.getMediaInfo(sourcePath);
    if (info == null) {
      return ProxyFile(
        clipId: clipId,
        originalPath: sourcePath,
        status: ProxyStatus.failed,
        errorMessage: 'Could not read source file',
        originalWidth: 0,
        originalHeight: 0,
      );
    }

    final originalWidth = info.width ?? 0;
    final originalHeight = info.height ?? 0;

    // Check if proxy is needed
    if (originalWidth < settings.minSourceWidth) {
      return ProxyFile(
        clipId: clipId,
        originalPath: sourcePath,
        status: ProxyStatus.notNeeded,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
    }

    // Generate proxy path
    final proxyPath = _getProxyPath(sourcePath, settings);

    // Check if proxy already exists
    if (await File(proxyPath).exists()) {
      // Get proxy dimensions
      final proxyInfo = await _ffmpeg.getMediaInfo(proxyPath);
      return ProxyFile(
        clipId: clipId,
        originalPath: sourcePath,
        proxyPath: proxyPath,
        status: ProxyStatus.ready,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        proxyWidth: proxyInfo?.width,
        proxyHeight: proxyInfo?.height,
      );
    }

    // Generate proxy
    try {
      final command = _buildProxyCommand(sourcePath, proxyPath, settings);

      await _ffmpeg.executeCommand(
        command,
        onProgress: (progress) {
          onProgress?.call(progress);
        },
      );

      // Verify proxy was created
      if (!await File(proxyPath).exists()) {
        return ProxyFile(
          clipId: clipId,
          originalPath: sourcePath,
          status: ProxyStatus.failed,
          errorMessage: 'Proxy file was not created',
          originalWidth: originalWidth,
          originalHeight: originalHeight,
        );
      }

      // Get proxy dimensions
      final proxyInfo = await _ffmpeg.getMediaInfo(proxyPath);

      return ProxyFile(
        clipId: clipId,
        originalPath: sourcePath,
        proxyPath: proxyPath,
        status: ProxyStatus.ready,
        progress: 1.0,
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        proxyWidth: proxyInfo?.width,
        proxyHeight: proxyInfo?.height,
      );
    } catch (e) {
      return ProxyFile(
        clipId: clipId,
        originalPath: sourcePath,
        status: ProxyStatus.failed,
        errorMessage: e.toString(),
        originalWidth: originalWidth,
        originalHeight: originalHeight,
      );
    }
  }

  /// Generate proxies for multiple clips
  Stream<ProxyFile> generateProxies(
    List<(String sourcePath, EditorId clipId)> clips,
    ProxySettings settings,
  ) async* {
    for (final (sourcePath, clipId) in clips) {
      yield ProxyFile(
        clipId: clipId,
        originalPath: sourcePath,
        status: ProxyStatus.generating,
        originalWidth: 0,
        originalHeight: 0,
      );

      final result = await generateProxy(sourcePath, clipId, settings);
      yield result;
    }
  }

  /// Delete proxy file
  Future<bool> deleteProxy(String proxyPath) async {
    try {
      final file = File(proxyPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Delete all proxies for a project
  Future<void> clearProxies() async {
    try {
      final dir = Directory(_cacheDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Get total size of proxy cache
  Future<int> getCacheSize() async {
    try {
      final dir = Directory(_cacheDir);
      if (!await dir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Check if source file needs a proxy
  Future<bool> needsProxy(String sourcePath, ProxySettings settings) async {
    final info = await _ffmpeg.getMediaInfo(sourcePath);
    if (info == null) return false;

    final width = info.width ?? 0;
    return width >= settings.minSourceWidth;
  }

  /// Get the path where proxy should be stored
  String _getProxyPath(String sourcePath, ProxySettings settings) {
    final sourceFile = File(sourcePath);
    final baseName = sourceFile.uri.pathSegments.last;
    final nameWithoutExt = baseName.contains('.')
        ? baseName.substring(0, baseName.lastIndexOf('.'))
        : baseName;

    return '$_cacheDir/${nameWithoutExt}_proxy_${settings.targetWidth}.${settings.codec.fileExtension}';
  }

  /// Build FFmpeg command for proxy generation
  List<String> _buildProxyCommand(
    String input,
    String output,
    ProxySettings settings,
  ) {
    final args = <String>[
      '-i', input,
      '-vf', settings.ffmpegScaleFilter,
    ];

    // Add codec-specific options
    switch (settings.codec) {
      case ProxyCodec.h264:
        args.addAll([
          '-c:v', 'libx264',
          '-preset', 'ultrafast',
          '-crf', '${(100 - settings.quality) * 0.51}', // 0-51 scale
        ]);
        break;
      case ProxyCodec.prores:
        args.addAll([
          '-c:v', 'prores_ks',
          '-profile:v', '0', // Proxy profile
        ]);
        break;
      case ProxyCodec.dnxhd:
        args.addAll([
          '-c:v', 'dnxhd',
          '-profile:v', 'dnxhr_lb',
        ]);
        break;
    }

    // Copy audio without re-encoding
    args.addAll([
      '-c:a', 'copy',
      '-y', // Overwrite output
      output,
    ]);

    return args;
  }
}

/// State manager for proxy workflow
class ProxyWorkflowManager {
  final ProxyService _service;
  final StreamController<ProxyState> _stateController =
      StreamController<ProxyState>.broadcast();

  ProxyState _state = const ProxyState();

  ProxyWorkflowManager({ProxyService? service})
      : _service = service ?? ProxyService();

  /// Current proxy state
  ProxyState get state => _state;

  /// Stream of state changes
  Stream<ProxyState> get stateStream => _stateController.stream;

  /// Initialize the workflow manager
  Future<void> initialize() async {
    await _service.initialize();
  }

  /// Update settings
  void updateSettings(ProxySettings settings) {
    _state = _state.copyWith(settings: settings);
    _stateController.add(_state);
  }

  /// Toggle proxy mode
  void setProxyMode(bool enabled) {
    _state = _state.copyWith(proxyModeEnabled: enabled);
    _stateController.add(_state);
  }

  /// Generate proxy for a single clip
  Future<void> generateProxy(String sourcePath, EditorId clipId) async {
    // Mark as generating
    final initialProxy = ProxyFile(
      clipId: clipId,
      originalPath: sourcePath,
      status: ProxyStatus.generating,
      originalWidth: 0,
      originalHeight: 0,
    );

    _state = _state.copyWith(
      proxies: {..._state.proxies, clipId: initialProxy},
    );
    _stateController.add(_state);

    // Generate proxy
    final result = await _service.generateProxy(
      sourcePath,
      clipId,
      _state.settings,
      onProgress: (progress) {
        final updated = _state.proxies[clipId]?.copyWith(progress: progress);
        if (updated != null) {
          _state = _state.copyWith(
            proxies: {..._state.proxies, clipId: updated},
          );
          _stateController.add(_state);
        }
      },
    );

    // Update with result
    _state = _state.copyWith(
      proxies: {..._state.proxies, clipId: result},
    );
    _stateController.add(_state);
  }

  /// Toggle proxy usage for a clip
  void toggleProxyUsage(EditorId clipId, bool useProxy) {
    final current = _state.proxies[clipId];
    if (current != null) {
      _state = _state.copyWith(
        proxies: {..._state.proxies, clipId: current.copyWith(useProxy: useProxy)},
      );
      _stateController.add(_state);
    }
  }

  /// Get path to use for a clip (proxy or original)
  String getActivePath(EditorId clipId, String originalPath) {
    if (!_state.proxyModeEnabled) return originalPath;

    final proxy = _state.proxies[clipId];
    if (proxy != null && proxy.isProxyActive) {
      return proxy.proxyPath!;
    }
    return originalPath;
  }

  /// Clear all proxies
  Future<void> clearAllProxies() async {
    await _service.clearProxies();
    _state = _state.copyWith(proxies: {});
    _stateController.add(_state);
  }

  /// Dispose
  void dispose() {
    _stateController.close();
  }
}
