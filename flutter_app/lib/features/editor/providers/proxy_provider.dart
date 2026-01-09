import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/proxy_models.dart';
import '../services/proxy_service.dart';

/// Provider for proxy service instance
final proxyServiceProvider = Provider<ProxyService>((ref) {
  return ProxyService();
});

/// Provider for proxy workflow manager
final proxyWorkflowProvider =
    StateNotifierProvider<ProxyWorkflowNotifier, ProxyState>((ref) {
  final service = ref.watch(proxyServiceProvider);
  return ProxyWorkflowNotifier(service);
});

/// Notifier for proxy workflow state
class ProxyWorkflowNotifier extends StateNotifier<ProxyState> {
  final ProxyService _service;

  ProxyWorkflowNotifier(this._service) : super(const ProxyState()) {
    _service.initialize();
  }

  /// Update proxy settings
  void updateSettings(ProxySettings settings) {
    state = state.copyWith(settings: settings);
  }

  /// Toggle global proxy mode
  void setProxyMode(bool enabled) {
    state = state.copyWith(proxyModeEnabled: enabled);
  }

  /// Generate proxy for a clip
  Future<void> generateProxy(String sourcePath, EditorId clipId) async {
    // Mark as generating
    final initialProxy = ProxyFile(
      clipId: clipId,
      originalPath: sourcePath,
      status: ProxyStatus.generating,
      originalWidth: 0,
      originalHeight: 0,
    );

    state = state.copyWith(
      proxies: {...state.proxies, clipId: initialProxy},
    );

    // Generate proxy
    final result = await _service.generateProxy(
      sourcePath,
      clipId,
      state.settings,
      onProgress: (progress) {
        final updated = state.proxies[clipId]?.copyWith(progress: progress);
        if (updated != null) {
          state = state.copyWith(
            proxies: {...state.proxies, clipId: updated},
          );
        }
      },
    );

    // Update with result
    state = state.copyWith(
      proxies: {...state.proxies, clipId: result},
    );
  }

  /// Generate proxies for multiple clips
  Future<void> generateProxies(
      List<(String sourcePath, EditorId clipId)> clips) async {
    for (final (sourcePath, clipId) in clips) {
      await generateProxy(sourcePath, clipId);
    }
  }

  /// Toggle proxy usage for a clip
  void toggleProxyUsage(EditorId clipId, bool useProxy) {
    final current = state.proxies[clipId];
    if (current != null) {
      state = state.copyWith(
        proxies: {...state.proxies, clipId: current.copyWith(useProxy: useProxy)},
      );
    }
  }

  /// Delete proxy for a clip
  Future<void> deleteProxy(EditorId clipId) async {
    final proxy = state.proxies[clipId];
    if (proxy?.proxyPath != null) {
      await _service.deleteProxy(proxy!.proxyPath!);
    }

    final newProxies = Map<EditorId, ProxyFile>.from(state.proxies);
    newProxies.remove(clipId);
    state = state.copyWith(proxies: newProxies);
  }

  /// Clear all proxies
  Future<void> clearAllProxies() async {
    await _service.clearProxies();
    state = state.copyWith(proxies: {});
  }

  /// Get active path for a clip (proxy or original)
  String getActivePath(EditorId clipId, String originalPath) {
    if (!state.proxyModeEnabled) return originalPath;

    final proxy = state.proxies[clipId];
    if (proxy != null && proxy.isProxyActive) {
      return proxy.proxyPath!;
    }
    return originalPath;
  }
}

/// Provider for proxy status of a specific clip
final clipProxyStatusProvider =
    Provider.family<ProxyStatus, EditorId>((ref, clipId) {
  final proxyState = ref.watch(proxyWorkflowProvider);
  return proxyState.proxies[clipId]?.status ?? ProxyStatus.none;
});

/// Provider for whether proxy mode is enabled
final proxyModeEnabledProvider = Provider<bool>((ref) {
  return ref.watch(proxyWorkflowProvider).proxyModeEnabled;
});

/// Provider for proxy generation progress
final proxyProgressProvider =
    Provider.family<double, EditorId>((ref, clipId) {
  final proxyState = ref.watch(proxyWorkflowProvider);
  return proxyState.proxies[clipId]?.progress ?? 0.0;
});

/// Provider for whether any proxies are generating
final hasGeneratingProxiesProvider = Provider<bool>((ref) {
  return ref.watch(proxyWorkflowProvider).hasGeneratingProxies;
});

/// Provider for proxy cache size
final proxyCacheSizeProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(proxyServiceProvider);
  return service.getCacheSize();
});
