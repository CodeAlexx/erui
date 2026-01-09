import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/caption_models.dart';
import '../services/caption_service.dart';

/// Provider for caption service
final captionServiceProvider = Provider<CaptionService>((ref) {
  return CaptionService();
});

/// Provider for caption state
final captionProvider =
    StateNotifierProvider<CaptionNotifier, CaptionState>((ref) {
  final service = ref.watch(captionServiceProvider);
  return CaptionNotifier(service);
});

/// Notifier for caption state
class CaptionNotifier extends StateNotifier<CaptionState> {
  final CaptionService _service;

  CaptionNotifier(this._service) : super(const CaptionState());

  /// Add a new caption track
  CaptionTrack addTrack({
    String? name,
    String language = 'en',
    CaptionStyle? style,
    CaptionPosition? position,
  }) {
    final track = CaptionTrack.create(
      name: name,
      language: language,
      style: style,
      position: position,
    );

    state = state.copyWith(
      tracks: [...state.tracks, track],
      activeTrackId: state.activeTrackId ?? track.id,
    );

    return track;
  }

  /// Remove a caption track
  void removeTrack(EditorId trackId) {
    state = state.copyWith(
      tracks: state.tracks.where((t) => t.id != trackId).toList(),
      activeTrackId:
          state.activeTrackId == trackId ? null : state.activeTrackId,
    );
  }

  /// Update a caption track
  void updateTrack(CaptionTrack track) {
    state = state.copyWith(
      tracks: state.tracks.map((t) => t.id == track.id ? track : t).toList(),
    );
  }

  /// Set active track
  void setActiveTrack(EditorId? trackId) {
    state = state.copyWith(activeTrackId: trackId);
  }

  /// Add caption to active track
  void addCaption({
    required EditorTime startTime,
    required EditorTime endTime,
    required String text,
    String? speaker,
  }) {
    final activeTrack = state.activeTrack;
    if (activeTrack == null) return;

    final caption = Caption.create(
      startTime: startTime,
      endTime: endTime,
      text: text,
      speaker: speaker,
    );

    final updated = activeTrack.addCaption(caption);
    updateTrack(updated);

    state = state.copyWith(
      selectedCaptionIds: {caption.id},
    );
  }

  /// Update a caption
  void updateCaption(Caption caption) {
    final activeTrack = state.activeTrack;
    if (activeTrack == null) return;

    final updated = activeTrack.updateCaption(caption);
    updateTrack(updated);
  }

  /// Remove a caption
  void removeCaption(EditorId captionId) {
    final activeTrack = state.activeTrack;
    if (activeTrack == null) return;

    final updated = activeTrack.removeCaption(captionId);
    updateTrack(updated);

    state = state.copyWith(
      selectedCaptionIds: state.selectedCaptionIds
          .where((id) => id != captionId)
          .toSet(),
    );
  }

  /// Select captions
  void selectCaptions(Set<EditorId> captionIds) {
    state = state.copyWith(selectedCaptionIds: captionIds);
  }

  /// Clear caption selection
  void clearSelection() {
    state = state.copyWith(selectedCaptionIds: {});
  }

  /// Toggle caption visibility in preview
  void setShowInPreview(bool show) {
    state = state.copyWith(showInPreview: show);
  }

  /// Import SRT file
  Future<void> importSrt(String content, {String language = 'en'}) async {
    final track = CaptionTrack.fromSrt(content, language: language);
    state = state.copyWith(
      tracks: [...state.tracks, track],
      activeTrackId: track.id,
    );
  }

  /// Export active track to SRT
  String? exportSrt() {
    return state.activeTrack?.toSrt();
  }

  /// Export active track to VTT
  String? exportVtt() {
    return state.activeTrack?.toVtt();
  }

  /// Transcribe audio using SwarmUI Whisper API
  Future<void> transcribeAudio(
    String audioPath, {
    String language = 'en',
    Function(double progress)? onProgress,
  }) async {
    final captions = await _service.transcribeAudio(
      audioPath,
      language: language,
      onProgress: onProgress,
    );

    // Create track with transcribed captions
    final track = CaptionTrack.create(
      name: 'Transcription ($language)',
      language: language,
    ).copyWith(captions: captions);

    state = state.copyWith(
      tracks: [...state.tracks, track],
      activeTrackId: track.id,
    );
  }

  /// Update track style
  void updateTrackStyle(EditorId trackId, CaptionStyle style) {
    final track = state.tracks.firstWhere((t) => t.id == trackId);
    updateTrack(track.copyWith(style: style));
  }

  /// Update track position
  void updateTrackPosition(EditorId trackId, CaptionPosition position) {
    final track = state.tracks.firstWhere((t) => t.id == trackId);
    updateTrack(track.copyWith(position: position));
  }

  /// Toggle track visibility
  void toggleTrackVisibility(EditorId trackId) {
    final track = state.tracks.firstWhere((t) => t.id == trackId);
    updateTrack(track.copyWith(isVisible: !track.isVisible));
  }

  /// Toggle track lock
  void toggleTrackLock(EditorId trackId) {
    final track = state.tracks.firstWhere((t) => t.id == trackId);
    updateTrack(track.copyWith(isLocked: !track.isLocked));
  }

  /// Shift all captions by offset
  void shiftCaptions(EditorId trackId, EditorTime offset) {
    final track = state.tracks.firstWhere((t) => t.id == trackId);
    final shifted = track.captions.map((c) {
      return c.copyWith(
        startTime: EditorTime(c.startTime.microseconds + offset.microseconds),
        endTime: EditorTime(c.endTime.microseconds + offset.microseconds),
      );
    }).toList();

    updateTrack(track.copyWith(captions: shifted));
  }
}

/// Provider for active caption track
final activeCaptionTrackProvider = Provider<CaptionTrack?>((ref) {
  return ref.watch(captionProvider).activeTrack;
});

/// Provider for caption at current time
final currentCaptionProvider =
    Provider.family<Caption?, EditorTime>((ref, time) {
  return ref.watch(captionProvider).captionAt(time);
});

/// Provider for selected captions
final selectedCaptionsProvider = Provider<List<Caption>>((ref) {
  final state = ref.watch(captionProvider);
  final track = state.activeTrack;
  if (track == null) return [];

  return track.captions
      .where((c) => state.selectedCaptionIds.contains(c.id))
      .toList();
});

/// Provider for caption tracks
final captionTracksProvider = Provider<List<CaptionTrack>>((ref) {
  return ref.watch(captionProvider).tracks;
});

/// Provider for caption visibility
final captionVisibilityProvider = Provider<bool>((ref) {
  return ref.watch(captionProvider).showInPreview;
});
