import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_track_models.dart';
import '../models/editor_models.dart';

/// State notifier for managing the audio mixer
class AudioMixerNotifier extends StateNotifier<AudioMixerState> {
  AudioMixerNotifier() : super(const AudioMixerState());

  /// Initialize track states from project tracks
  void initializeFromTracks(List<Track> tracks) {
    final audioTracks = tracks.where((t) => t.type == TrackType.audio);
    final newStates = <EditorId, AudioTrackState>{};

    for (final track in audioTracks) {
      // Preserve existing state if available
      final existing = state.trackStates[track.id];
      newStates[track.id] = existing ?? AudioTrackState(
        trackId: track.id,
        volume: track.volume,
        pan: track.pan,
        muted: track.isMuted,
        solo: track.isSolo,
      );
    }

    state = state.copyWith(trackStates: newStates);
  }

  /// Set master volume (0.0 to 2.0)
  void setMasterVolume(double volume) {
    state = state.copyWith(masterVolume: volume.clamp(0.0, 2.0));
  }

  /// Toggle master mute
  void toggleMasterMute() {
    state = state.copyWith(masterMuted: !state.masterMuted);
  }

  /// Set track volume
  void setTrackVolume(EditorId trackId, double volume) {
    final currentState = state.trackStates[trackId];
    if (currentState == null) return;

    state = state.updateTrackState(
      currentState.copyWith(volume: volume.clamp(0.0, 2.0)),
    );
  }

  /// Set track pan
  void setTrackPan(EditorId trackId, double pan) {
    final currentState = state.trackStates[trackId];
    if (currentState == null) return;

    state = state.updateTrackState(
      currentState.copyWith(pan: pan.clamp(-1.0, 1.0)),
    );
  }

  /// Toggle track mute
  void toggleTrackMute(EditorId trackId) {
    final currentState = state.trackStates[trackId];
    if (currentState == null) return;

    state = state.updateTrackState(
      currentState.copyWith(muted: !currentState.muted),
    );
  }

  /// Toggle track solo
  void toggleTrackSolo(EditorId trackId) {
    final currentState = state.trackStates[trackId];
    if (currentState == null) return;

    state = state.updateTrackState(
      currentState.copyWith(solo: !currentState.solo),
    );
  }

  /// Set track mute state
  void setTrackMute(EditorId trackId, bool muted) {
    final currentState = state.trackStates[trackId];
    if (currentState == null) return;

    state = state.updateTrackState(
      currentState.copyWith(muted: muted),
    );
  }

  /// Set track solo state
  void setTrackSolo(EditorId trackId, bool solo) {
    final currentState = state.trackStates[trackId];
    if (currentState == null) return;

    state = state.updateTrackState(
      currentState.copyWith(solo: solo),
    );
  }

  /// Clear all solo states
  void clearAllSolo() {
    final newStates = state.trackStates.map(
      (id, trackState) => MapEntry(id, trackState.copyWith(solo: false)),
    );
    state = state.copyWith(trackStates: newStates);
  }

  /// Clear all mute states
  void clearAllMute() {
    final newStates = state.trackStates.map(
      (id, trackState) => MapEntry(id, trackState.copyWith(muted: false)),
    );
    state = state.copyWith(trackStates: newStates);
  }

  /// Update audio levels (for metering display)
  void updateLevels({
    required double masterLevel,
    required Map<EditorId, double> trackLevels,
  }) {
    // Update master level
    var newMasterPeak = state.masterPeakLevel;
    if (masterLevel > newMasterPeak) {
      newMasterPeak = masterLevel;
    }

    // Update track levels
    final newStates = <EditorId, AudioTrackState>{};
    for (final entry in state.trackStates.entries) {
      final trackLevel = trackLevels[entry.key] ?? 0.0;
      var peakLevel = entry.value.peakLevel;
      if (trackLevel > peakLevel) {
        peakLevel = trackLevel;
      }

      newStates[entry.key] = entry.value.copyWith(
        currentLevel: trackLevel,
        peakLevel: peakLevel,
      );
    }

    state = state.copyWith(
      masterLevel: masterLevel,
      masterPeakLevel: newMasterPeak,
      trackStates: newStates,
    );
  }

  /// Reset all peak levels
  void resetAllPeaks() {
    state = state.resetAllPeaks();
  }

  /// Reset a single track's peak level
  void resetTrackPeak(EditorId trackId) {
    final currentState = state.trackStates[trackId];
    if (currentState == null) return;

    state = state.updateTrackState(
      currentState.copyWith(peakLevel: 0.0),
    );
  }

  /// Reset all mixer settings to defaults
  void resetToDefaults() {
    final newStates = state.trackStates.map(
      (id, trackState) => MapEntry(
        id,
        AudioTrackState(
          trackId: id,
          volume: 1.0,
          pan: 0.0,
          muted: false,
          solo: false,
        ),
      ),
    );

    state = AudioMixerState(
      masterVolume: 1.0,
      masterMuted: false,
      trackStates: newStates,
    );
  }

  /// Add a new track to the mixer
  void addTrack(EditorId trackId, {double volume = 1.0, double pan = 0.0}) {
    state = state.updateTrackState(
      AudioTrackState(
        trackId: trackId,
        volume: volume,
        pan: pan,
      ),
    );
  }

  /// Remove a track from the mixer
  void removeTrack(EditorId trackId) {
    final newStates = Map<EditorId, AudioTrackState>.from(state.trackStates);
    newStates.remove(trackId);
    state = state.copyWith(trackStates: newStates);
  }
}

/// Main provider for audio mixer state
final audioMixerProvider =
    StateNotifierProvider<AudioMixerNotifier, AudioMixerState>(
  (ref) => AudioMixerNotifier(),
);

/// Provider for master volume
final masterVolumeProvider = Provider<double>(
  (ref) => ref.watch(audioMixerProvider).masterVolume,
);

/// Provider for master mute state
final masterMutedProvider = Provider<bool>(
  (ref) => ref.watch(audioMixerProvider).masterMuted,
);

/// Provider for master level (metering)
final masterLevelProvider = Provider<double>(
  (ref) => ref.watch(audioMixerProvider).masterLevel,
);

/// Provider for a specific track's mixer state
final trackMixerStateProvider = Provider.family<AudioTrackState?, EditorId>(
  (ref, trackId) {
    final state = ref.watch(audioMixerProvider);
    return state.trackStates[trackId];
  },
);

/// Provider to check if a track is audible (not muted, or is soloed)
final isTrackAudibleProvider = Provider.family<bool, EditorId>(
  (ref, trackId) {
    final state = ref.watch(audioMixerProvider);
    return state.isTrackAudible(trackId);
  },
);

/// Provider for whether any track is soloed
final hasSoloedTracksProvider = Provider<bool>(
  (ref) => ref.watch(audioMixerProvider).hasSoloedTracks,
);

/// Provider for track volume
final trackVolumeProvider = Provider.family<double, EditorId>(
  (ref, trackId) {
    final state = ref.watch(trackMixerStateProvider(trackId));
    return state?.volume ?? 1.0;
  },
);

/// Provider for track pan
final trackPanProvider = Provider.family<double, EditorId>(
  (ref, trackId) {
    final state = ref.watch(trackMixerStateProvider(trackId));
    return state?.pan ?? 0.0;
  },
);

/// Provider for track mute state
final trackMutedProvider = Provider.family<bool, EditorId>(
  (ref, trackId) {
    final state = ref.watch(trackMixerStateProvider(trackId));
    return state?.muted ?? false;
  },
);

/// Provider for track solo state
final trackSoloProvider = Provider.family<bool, EditorId>(
  (ref, trackId) {
    final state = ref.watch(trackMixerStateProvider(trackId));
    return state?.solo ?? false;
  },
);

/// Provider for track level (metering)
final trackLevelProvider = Provider.family<double, EditorId>(
  (ref, trackId) {
    final state = ref.watch(trackMixerStateProvider(trackId));
    return state?.currentLevel ?? 0.0;
  },
);

/// Provider for track peak level
final trackPeakLevelProvider = Provider.family<double, EditorId>(
  (ref, trackId) {
    final state = ref.watch(trackMixerStateProvider(trackId));
    return state?.peakLevel ?? 0.0;
  },
);
