import 'dart:math';

import 'editor_models.dart';

/// Extended audio track with mixer controls
class AudioTrack extends Track {
  /// Output routing (for multi-channel mixing)
  final int outputBus;

  /// Current audio level (for metering, 0.0 to 1.0)
  double currentLevel;

  /// Peak level (for peak hold display)
  double peakLevel;

  AudioTrack({
    super.id,
    required super.name,
    super.clips,
    super.height = 60.0,
    super.isVisible = true,
    super.isLocked = false,
    super.volume = 1.0,
    super.pan = 0.0,
    super.isMuted = false,
    super.isSolo = false,
    this.outputBus = 0,
    this.currentLevel = 0.0,
    this.peakLevel = 0.0,
  }) : super(type: TrackType.audio);

  @override
  AudioTrack copyWith({
    EditorId? id,
    TrackType? type,
    String? name,
    List<EditorClip>? clips,
    double? height,
    bool? isVisible,
    bool? isLocked,
    bool? isMuted,
    bool? isSolo,
    double? volume,
    double? pan,
    int? outputBus,
    double? currentLevel,
    double? peakLevel,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      name: name ?? this.name,
      clips: clips ?? List.from(this.clips),
      height: height ?? this.height,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
      outputBus: outputBus ?? this.outputBus,
      currentLevel: currentLevel ?? this.currentLevel,
      peakLevel: peakLevel ?? this.peakLevel,
    );
  }

  /// Convert volume to dB for display
  double get volumeDb {
    if (volume <= 0) return double.negativeInfinity;
    return 20 * _log10(volume);
  }

  /// Set volume from dB value
  void setVolumeFromDb(double db) {
    if (db == double.negativeInfinity) {
      volume = 0;
    } else {
      volume = _pow10(db / 20);
    }
  }

  /// Convert level to dB for metering display
  double get levelDb {
    if (currentLevel <= 0) return double.negativeInfinity;
    return 20 * _log10(currentLevel);
  }

  /// Convert peak level to dB
  double get peakDb {
    if (peakLevel <= 0) return double.negativeInfinity;
    return 20 * _log10(peakLevel);
  }

  /// Helper for log base 10
  static double _log10(double x) => log(x) / ln10;
  static double _pow10(double x) => pow(10, x).toDouble();

  /// Reset peak level
  void resetPeak() {
    peakLevel = 0.0;
  }

  /// Update current level and track peak
  void updateLevel(double level) {
    currentLevel = level.clamp(0.0, 1.0);
    if (currentLevel > peakLevel) {
      peakLevel = currentLevel;
    }
  }
}

/// Audio mixer state for the entire project
class AudioMixerState {
  /// Master volume (0.0 to 2.0)
  final double masterVolume;

  /// Master mute state
  final bool masterMuted;

  /// Current master level (for metering)
  final double masterLevel;

  /// Master peak level
  final double masterPeakLevel;

  /// Audio track states by ID
  final Map<EditorId, AudioTrackState> trackStates;

  const AudioMixerState({
    this.masterVolume = 1.0,
    this.masterMuted = false,
    this.masterLevel = 0.0,
    this.masterPeakLevel = 0.0,
    this.trackStates = const {},
  });

  /// Create a copy with optional parameter overrides
  AudioMixerState copyWith({
    double? masterVolume,
    bool? masterMuted,
    double? masterLevel,
    double? masterPeakLevel,
    Map<EditorId, AudioTrackState>? trackStates,
  }) {
    return AudioMixerState(
      masterVolume: masterVolume ?? this.masterVolume,
      masterMuted: masterMuted ?? this.masterMuted,
      masterLevel: masterLevel ?? this.masterLevel,
      masterPeakLevel: masterPeakLevel ?? this.masterPeakLevel,
      trackStates: trackStates ?? Map.from(this.trackStates),
    );
  }

  /// Get master volume in dB
  double get masterVolumeDb {
    if (masterVolume <= 0) return double.negativeInfinity;
    return 20 * AudioTrack._log10(masterVolume);
  }

  /// Get master level in dB
  double get masterLevelDb {
    if (masterLevel <= 0) return double.negativeInfinity;
    return 20 * AudioTrack._log10(masterLevel);
  }

  /// Check if any track is soloed
  bool get hasSoloedTracks =>
      trackStates.values.any((state) => state.solo);

  /// Get effective mute state for a track (considering solo)
  bool isTrackAudible(EditorId trackId) {
    final state = trackStates[trackId];
    if (state == null) return true;
    if (state.muted) return false;
    if (hasSoloedTracks && !state.solo) return false;
    return true;
  }

  /// Update a single track state
  AudioMixerState updateTrackState(AudioTrackState state) {
    final newStates = Map<EditorId, AudioTrackState>.from(trackStates);
    newStates[state.trackId] = state;
    return copyWith(trackStates: newStates);
  }

  /// Reset all peak levels
  AudioMixerState resetAllPeaks() {
    final newStates = trackStates.map(
      (id, state) => MapEntry(id, state.copyWith(peakLevel: 0.0)),
    );
    return copyWith(
      masterPeakLevel: 0.0,
      trackStates: newStates,
    );
  }

  @override
  String toString() {
    return 'AudioMixerState(masterVolume: $masterVolume, tracks: ${trackStates.length})';
  }
}

/// State for a single audio track in the mixer
class AudioTrackState {
  /// ID of the track this state belongs to
  final EditorId trackId;

  /// Volume level (0.0 to 2.0)
  final double volume;

  /// Pan position (-1.0 to 1.0)
  final double pan;

  /// Whether track is muted
  final bool muted;

  /// Whether track is soloed
  final bool solo;

  /// Current audio level (for metering)
  final double currentLevel;

  /// Peak level (for peak hold display)
  final double peakLevel;

  const AudioTrackState({
    required this.trackId,
    this.volume = 1.0,
    this.pan = 0.0,
    this.muted = false,
    this.solo = false,
    this.currentLevel = 0.0,
    this.peakLevel = 0.0,
  });

  /// Create a copy with optional parameter overrides
  AudioTrackState copyWith({
    EditorId? trackId,
    double? volume,
    double? pan,
    bool? muted,
    bool? solo,
    double? currentLevel,
    double? peakLevel,
  }) {
    return AudioTrackState(
      trackId: trackId ?? this.trackId,
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
      muted: muted ?? this.muted,
      solo: solo ?? this.solo,
      currentLevel: currentLevel ?? this.currentLevel,
      peakLevel: peakLevel ?? this.peakLevel,
    );
  }

  /// Get volume in dB
  double get volumeDb {
    if (volume <= 0) return double.negativeInfinity;
    return 20 * AudioTrack._log10(volume);
  }

  /// Get current level in dB
  double get levelDb {
    if (currentLevel <= 0) return double.negativeInfinity;
    return 20 * AudioTrack._log10(currentLevel);
  }

  /// Get peak level in dB
  double get peakDb {
    if (peakLevel <= 0) return double.negativeInfinity;
    return 20 * AudioTrack._log10(peakLevel);
  }

  /// Get pan display string (L100% to R100%)
  String get panDisplay {
    if (pan == 0) return 'C';
    if (pan < 0) return 'L${(-pan * 100).round()}';
    return 'R${(pan * 100).round()}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTrackState &&
          runtimeType == other.runtimeType &&
          trackId == other.trackId;

  @override
  int get hashCode => trackId.hashCode;

  @override
  String toString() {
    return 'AudioTrackState(trackId: $trackId, volume: $volume, pan: $pan)';
  }
}

/// Audio meter configuration
class AudioMeterConfig {
  /// Minimum dB level to display
  final double minDb;

  /// Maximum dB level to display
  final double maxDb;

  /// Warning threshold in dB (yellow zone)
  final double warningDb;

  /// Danger threshold in dB (red zone)
  final double dangerDb;

  /// Peak hold time in milliseconds
  final int peakHoldMs;

  /// Peak decay rate (dB per second)
  final double peakDecayRate;

  const AudioMeterConfig({
    this.minDb = -60.0,
    this.maxDb = 6.0,
    this.warningDb = -6.0,
    this.dangerDb = 0.0,
    this.peakHoldMs = 1500,
    this.peakDecayRate = 20.0,
  });

  /// Convert a dB value to a normalized position (0.0 to 1.0)
  double dbToPosition(double db) {
    if (db == double.negativeInfinity) return 0.0;
    return ((db - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
  }

  /// Get the color zone for a dB level
  MeterZone getZone(double db) {
    if (db >= dangerDb) return MeterZone.danger;
    if (db >= warningDb) return MeterZone.warning;
    return MeterZone.normal;
  }
}

/// Meter color zones
enum MeterZone {
  /// Normal operating level (green)
  normal,

  /// Warning level (yellow)
  warning,

  /// Danger/clipping level (red)
  danger,
}
