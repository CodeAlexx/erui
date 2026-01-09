import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/scope_analyzer.dart';
import '../widgets/histogram_widget.dart';

/// State for video scopes display
class ScopesState {
  /// Whether scopes panel is visible
  final bool isVisible;

  /// Whether scopes are updating live
  final bool isLive;

  /// Waveform display mode
  final WaveformMode waveformMode;

  /// Histogram display mode
  final HistogramMode histogramMode;

  /// Vectorscope zoom level
  final double vectorscopeZoom;

  /// Current frame being analyzed
  final Uint8List? currentFrame;

  /// Cached waveform data
  final WaveformData? waveformData;

  /// Cached histogram data
  final HistogramData? histogramData;

  /// Cached vectorscope data
  final VectorscopeData? vectorscopeData;

  /// Whether analysis is in progress
  final bool isAnalyzing;

  const ScopesState({
    this.isVisible = false,
    this.isLive = true,
    this.waveformMode = WaveformMode.luma,
    this.histogramMode = HistogramMode.overlay,
    this.vectorscopeZoom = 1.0,
    this.currentFrame,
    this.waveformData,
    this.histogramData,
    this.vectorscopeData,
    this.isAnalyzing = false,
  });

  ScopesState copyWith({
    bool? isVisible,
    bool? isLive,
    WaveformMode? waveformMode,
    HistogramMode? histogramMode,
    double? vectorscopeZoom,
    Uint8List? currentFrame,
    WaveformData? waveformData,
    HistogramData? histogramData,
    VectorscopeData? vectorscopeData,
    bool? isAnalyzing,
  }) {
    return ScopesState(
      isVisible: isVisible ?? this.isVisible,
      isLive: isLive ?? this.isLive,
      waveformMode: waveformMode ?? this.waveformMode,
      histogramMode: histogramMode ?? this.histogramMode,
      vectorscopeZoom: vectorscopeZoom ?? this.vectorscopeZoom,
      currentFrame: currentFrame ?? this.currentFrame,
      waveformData: waveformData ?? this.waveformData,
      histogramData: histogramData ?? this.histogramData,
      vectorscopeData: vectorscopeData ?? this.vectorscopeData,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
    );
  }
}

/// Notifier for scopes state
class ScopesNotifier extends StateNotifier<ScopesState> {
  final ScopeAnalyzer _analyzer;

  ScopesNotifier({ScopeAnalyzer? analyzer})
      : _analyzer = analyzer ?? ScopeAnalyzer(),
        super(const ScopesState());

  /// Toggle scopes panel visibility
  void toggleVisibility() {
    state = state.copyWith(isVisible: !state.isVisible);
  }

  /// Set scopes panel visibility
  void setVisible(bool visible) {
    state = state.copyWith(isVisible: visible);
  }

  /// Toggle live update mode
  void toggleLive() {
    state = state.copyWith(isLive: !state.isLive);
  }

  /// Set waveform display mode
  void setWaveformMode(WaveformMode mode) {
    state = state.copyWith(waveformMode: mode);
    if (state.currentFrame != null) {
      _analyzeWaveform(state.currentFrame!);
    }
  }

  /// Set histogram display mode
  void setHistogramMode(HistogramMode mode) {
    state = state.copyWith(histogramMode: mode);
  }

  /// Set vectorscope zoom level
  void setVectorscopeZoom(double zoom) {
    state = state.copyWith(vectorscopeZoom: zoom.clamp(0.5, 4.0));
  }

  /// Update with new frame data
  Future<void> updateFrame(Uint8List frameData) async {
    if (!state.isLive && state.currentFrame != null) return;

    state = state.copyWith(currentFrame: frameData, isAnalyzing: true);

    // Run all analyses in parallel
    await Future.wait([
      _analyzeWaveform(frameData),
      _analyzeHistogram(frameData),
      _analyzeVectorscope(frameData),
    ]);

    state = state.copyWith(isAnalyzing: false);
  }

  Future<void> _analyzeWaveform(Uint8List frameData) async {
    try {
      final data = await _analyzer.analyzeWaveform(
        frameData,
        mode: state.waveformMode,
      );
      state = state.copyWith(waveformData: data);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _analyzeHistogram(Uint8List frameData) async {
    try {
      final data = await _analyzer.analyzeHistogram(frameData);
      state = state.copyWith(histogramData: data);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _analyzeVectorscope(Uint8List frameData) async {
    try {
      final data = await _analyzer.analyzeVectorscope(frameData);
      state = state.copyWith(vectorscopeData: data);
    } catch (e) {
      // Handle error silently
    }
  }

  /// Force refresh all scopes
  Future<void> refresh() async {
    if (state.currentFrame != null) {
      state = state.copyWith(isAnalyzing: true);
      await Future.wait([
        _analyzeWaveform(state.currentFrame!),
        _analyzeHistogram(state.currentFrame!),
        _analyzeVectorscope(state.currentFrame!),
      ]);
      state = state.copyWith(isAnalyzing: false);
    }
  }

  /// Clear all scope data
  void clear() {
    state = state.copyWith(
      currentFrame: null,
      waveformData: null,
      histogramData: null,
      vectorscopeData: null,
    );
  }
}

/// Provider for scopes state
final scopesNotifierProvider =
    StateNotifierProvider<ScopesNotifier, ScopesState>((ref) {
  return ScopesNotifier();
});

/// Provider for scopes visibility
final scopesVisibleProvider = Provider<bool>((ref) {
  return ref.watch(scopesNotifierProvider).isVisible;
});

/// Provider for waveform data
final waveformDataProvider = FutureProvider<WaveformData?>((ref) async {
  final state = ref.watch(scopesNotifierProvider);
  return state.waveformData;
});

/// Provider for histogram data
final histogramDataProvider = FutureProvider<HistogramData?>((ref) async {
  final state = ref.watch(scopesNotifierProvider);
  return state.histogramData;
});

/// Provider for vectorscope data
final vectorscopeDataProvider = FutureProvider<VectorscopeData?>((ref) async {
  final state = ref.watch(scopesNotifierProvider);
  return state.vectorscopeData;
});

/// Provider for waveform mode
final waveformModeProvider = Provider<WaveformMode>((ref) {
  return ref.watch(scopesNotifierProvider).waveformMode;
});

/// Provider for histogram mode
final histogramModeProvider = Provider<HistogramMode>((ref) {
  return ref.watch(scopesNotifierProvider).histogramMode;
});

/// Provider for vectorscope zoom
final vectorscopeZoomProvider = Provider<double>((ref) {
  return ref.watch(scopesNotifierProvider).vectorscopeZoom;
});
