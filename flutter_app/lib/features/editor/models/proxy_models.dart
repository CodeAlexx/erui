import 'editor_models.dart';

/// Proxy workflow settings for low-res editing
class ProxySettings {
  /// Target width for proxy files (height calculated from aspect ratio)
  final int targetWidth;

  /// Codec for proxy files
  final ProxyCodec codec;

  /// Quality level (0-100)
  final int quality;

  /// Whether to auto-generate proxies on import
  final bool autoGenerate;

  /// Minimum source width to trigger proxy generation
  final int minSourceWidth;

  const ProxySettings({
    this.targetWidth = 640,
    this.codec = ProxyCodec.h264,
    this.quality = 50,
    this.autoGenerate = true,
    this.minSourceWidth = 1920,
  });

  ProxySettings copyWith({
    int? targetWidth,
    ProxyCodec? codec,
    int? quality,
    bool? autoGenerate,
    int? minSourceWidth,
  }) {
    return ProxySettings(
      targetWidth: targetWidth ?? this.targetWidth,
      codec: codec ?? this.codec,
      quality: quality ?? this.quality,
      autoGenerate: autoGenerate ?? this.autoGenerate,
      minSourceWidth: minSourceWidth ?? this.minSourceWidth,
    );
  }

  /// Get FFmpeg scale filter for proxy generation
  String get ffmpegScaleFilter => 'scale=$targetWidth:-2';

  /// Get FFmpeg codec options
  String get ffmpegCodecOptions {
    switch (codec) {
      case ProxyCodec.h264:
        return '-c:v libx264 -preset ultrafast -crf ${100 - quality}';
      case ProxyCodec.prores:
        return '-c:v prores_ks -profile:v 0';
      case ProxyCodec.dnxhd:
        return '-c:v dnxhd -profile:v dnxhr_lb';
    }
  }
}

/// Proxy codec options
enum ProxyCodec {
  h264,
  prores,
  dnxhd,
}

extension ProxyCodecExtension on ProxyCodec {
  String get displayName {
    switch (this) {
      case ProxyCodec.h264:
        return 'H.264 (Fast)';
      case ProxyCodec.prores:
        return 'ProRes Proxy';
      case ProxyCodec.dnxhd:
        return 'DNxHR LB';
    }
  }

  String get fileExtension {
    switch (this) {
      case ProxyCodec.h264:
        return 'mp4';
      case ProxyCodec.prores:
        return 'mov';
      case ProxyCodec.dnxhd:
        return 'mxf';
    }
  }
}

/// Status of proxy generation for a clip
enum ProxyStatus {
  /// No proxy exists
  none,

  /// Proxy is being generated
  generating,

  /// Proxy is ready
  ready,

  /// Proxy generation failed
  failed,

  /// Original file is already low-res, no proxy needed
  notNeeded,
}

/// Proxy file information for a media clip
class ProxyFile {
  final EditorId clipId;

  /// Path to original high-res file
  final String originalPath;

  /// Path to proxy file (null if not generated)
  final String? proxyPath;

  /// Current proxy status
  final ProxyStatus status;

  /// Generation progress (0.0 - 1.0)
  final double progress;

  /// Error message if generation failed
  final String? errorMessage;

  /// Original file dimensions
  final int originalWidth;
  final int originalHeight;

  /// Proxy file dimensions
  final int? proxyWidth;
  final int? proxyHeight;

  /// Whether to use proxy during editing (vs original)
  final bool useProxy;

  const ProxyFile({
    required this.clipId,
    required this.originalPath,
    this.proxyPath,
    this.status = ProxyStatus.none,
    this.progress = 0.0,
    this.errorMessage,
    required this.originalWidth,
    required this.originalHeight,
    this.proxyWidth,
    this.proxyHeight,
    this.useProxy = true,
  });

  ProxyFile copyWith({
    EditorId? clipId,
    String? originalPath,
    String? proxyPath,
    ProxyStatus? status,
    double? progress,
    String? errorMessage,
    int? originalWidth,
    int? originalHeight,
    int? proxyWidth,
    int? proxyHeight,
    bool? useProxy,
  }) {
    return ProxyFile(
      clipId: clipId ?? this.clipId,
      originalPath: originalPath ?? this.originalPath,
      proxyPath: proxyPath ?? this.proxyPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      originalWidth: originalWidth ?? this.originalWidth,
      originalHeight: originalHeight ?? this.originalHeight,
      proxyWidth: proxyWidth ?? this.proxyWidth,
      proxyHeight: proxyHeight ?? this.proxyHeight,
      useProxy: useProxy ?? this.useProxy,
    );
  }

  /// Get the path to use for playback/editing
  String get activePath => useProxy && proxyPath != null ? proxyPath! : originalPath;

  /// Check if proxy is available and being used
  bool get isProxyActive => useProxy && status == ProxyStatus.ready && proxyPath != null;

  /// Check if this clip needs a proxy based on resolution
  bool needsProxy(int minSourceWidth) => originalWidth >= minSourceWidth;
}

/// Global proxy state for the project
class ProxyState {
  final ProxySettings settings;

  /// Map of clip ID to proxy file info
  final Map<EditorId, ProxyFile> proxies;

  /// Whether proxy mode is enabled globally
  final bool proxyModeEnabled;

  const ProxyState({
    this.settings = const ProxySettings(),
    this.proxies = const {},
    this.proxyModeEnabled = true,
  });

  ProxyState copyWith({
    ProxySettings? settings,
    Map<EditorId, ProxyFile>? proxies,
    bool? proxyModeEnabled,
  }) {
    return ProxyState(
      settings: settings ?? this.settings,
      proxies: proxies ?? this.proxies,
      proxyModeEnabled: proxyModeEnabled ?? this.proxyModeEnabled,
    );
  }

  /// Get proxy file for a clip
  ProxyFile? getProxy(EditorId clipId) => proxies[clipId];

  /// Check if any proxies are currently generating
  bool get hasGeneratingProxies =>
    proxies.values.any((p) => p.status == ProxyStatus.generating);

  /// Get count of proxies by status
  Map<ProxyStatus, int> get statusCounts {
    final counts = <ProxyStatus, int>{};
    for (final status in ProxyStatus.values) {
      counts[status] = proxies.values.where((p) => p.status == status).length;
    }
    return counts;
  }
}
