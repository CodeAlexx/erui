import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';

/// Playback state enum for the video editor
enum PlaybackState {
  stopped,
  playing,
  paused,
}

/// Available editor tools
enum EditorTool {
  /// Selection/pointer tool for selecting and moving clips
  select,

  /// Cut/razor tool for splitting clips
  cut,

  /// Ripple edit tool for moving clips and closing gaps
  ripple,
}

/// Immutable state container for the editor project
class EditorProjectState {
  final EditorProject project;
  final Set<EditorId> selectedClipIds;
  final PlaybackState playbackState;
  final bool isDirty;

  const EditorProjectState({
    required this.project,
    this.selectedClipIds = const {},
    this.playbackState = PlaybackState.stopped,
    this.isDirty = false,
  });

  EditorProjectState copyWith({
    EditorProject? project,
    Set<EditorId>? selectedClipIds,
    PlaybackState? playbackState,
    bool? isDirty,
  }) {
    return EditorProjectState(
      project: project ?? this.project,
      selectedClipIds: selectedClipIds ?? this.selectedClipIds,
      playbackState: playbackState ?? this.playbackState,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  /// Get currently selected clips
  List<EditorClip> get selectedClips {
    final result = <EditorClip>[];
    for (final track in project.tracks) {
      for (final clip in track.clips) {
        if (selectedClipIds.contains(clip.id)) {
          result.add(clip);
        }
      }
    }
    return result;
  }
}

/// State notifier for managing the editor project state
class EditorProjectNotifier extends StateNotifier<EditorProjectState> {
  EditorProjectNotifier()
      : super(EditorProjectState(
          project: EditorProject(
            name: 'Test Project',
            tracks: [
              Track(
                type: TrackType.video,
                name: 'Video 1',
                clips: [
                  EditorClip(
                    type: ClipType.video,
                    name: 'Test Video Clip',
                    timelineStart: const EditorTime.zero(),
                    duration: const EditorTime(5000000), // 5 seconds
                    sourcePath: 'http://localhost:8899/2c1ed5408882479b06681f7cf372916a.mp4',
                    sourceDuration: const EditorTime(5000000),
                  ),
                ],
              ),
              Track(type: TrackType.video, name: 'Video 2'),
              Track(type: TrackType.audio, name: 'Audio 1'),
              Track(type: TrackType.audio, name: 'Audio 2'),
            ],
          ),
        ));

  /// Load an existing project
  void loadProject(EditorProject project) {
    state = EditorProjectState(
      project: project,
      selectedClipIds: {},
      playbackState: PlaybackState.stopped,
      isDirty: false,
    );
  }

  /// Create a new empty project with 2 video and 2 audio tracks
  void newProject({
    String name = 'Untitled Project',
    ProjectSettings? settings,
  }) {
    state = EditorProjectState(
      project: EditorProject(
        name: name,
        settings: settings,
        tracks: [
          Track(type: TrackType.video, name: 'Video 1'),
          Track(type: TrackType.video, name: 'Video 2'),
          Track(type: TrackType.audio, name: 'Audio 1'),
          Track(type: TrackType.audio, name: 'Audio 2'),
        ],
      ),
      selectedClipIds: {},
      playbackState: PlaybackState.stopped,
      isDirty: false,
    );
  }

  // ============================================================
  // Track Operations
  // ============================================================

  /// Add a new track of the specified type
  Track addTrack(TrackType type) {
    final project = _cloneProject();
    final Track track;

    switch (type) {
      case TrackType.video:
        final count =
            project.tracks.where((t) => t.type == TrackType.video).length + 1;
        track = Track(type: type, name: 'Video $count');
        // Insert video tracks at the top
        final lastVideoIndex = project.tracks
            .lastIndexWhere((t) => t.type == TrackType.video);
        project.tracks.insert(lastVideoIndex + 1, track);
        break;

      case TrackType.audio:
        final count =
            project.tracks.where((t) => t.type == TrackType.audio).length + 1;
        track = Track(type: type, name: 'Audio $count');
        // Insert audio tracks at the bottom
        project.tracks.add(track);
        break;

      case TrackType.text:
        final count =
            project.tracks.where((t) => t.type == TrackType.text).length + 1;
        track = Track(type: type, name: 'Text $count');
        // Insert text tracks after video tracks
        final lastVideoIdx = project.tracks
            .lastIndexWhere((t) => t.type == TrackType.video);
        project.tracks.insert(lastVideoIdx + 1, track);
        break;

      case TrackType.effect:
        final count =
            project.tracks.where((t) => t.type == TrackType.effect).length + 1;
        track = Track(type: type, name: 'Effect $count');
        // Insert effect tracks after video tracks
        final lastVidIdx = project.tracks
            .lastIndexWhere((t) => t.type == TrackType.video);
        project.tracks.insert(lastVidIdx + 1, track);
        break;
    }

    // Update track indices for all clips
    _updateTrackIndices(project);

    state = state.copyWith(project: project, isDirty: true);
    return track;
  }

  /// Remove a track by ID
  bool removeTrack(EditorId trackId) {
    final project = _cloneProject();
    final trackIndex = project.tracks.indexWhere((t) => t.id == trackId);

    if (trackIndex == -1) return false;

    // Remove any selected clips from this track
    final track = project.tracks[trackIndex];
    final clipIdsToRemove = track.clips.map((c) => c.id).toSet();
    final newSelectedIds =
        state.selectedClipIds.difference(clipIdsToRemove);

    project.tracks.removeAt(trackIndex);

    // Update track indices for all clips
    _updateTrackIndices(project);

    state = state.copyWith(
      project: project,
      selectedClipIds: newSelectedIds,
      isDirty: true,
    );
    return true;
  }

  // ============================================================
  // Clip Operations
  // ============================================================

  /// Add a clip to a specific track
  bool addClip(EditorId trackId, EditorClip clip) {
    final project = _cloneProject();
    final track = project.findTrack(trackId);

    if (track == null) return false;

    // Set the correct track index
    final trackIndex = project.tracks.indexOf(track);
    final newClip = clip.copyWith(trackIndex: trackIndex);

    // Check for overlaps
    if (_wouldOverlap(track, newClip, excludeClipId: null)) {
      return false;
    }

    track.clips.add(newClip);

    // Update project duration
    project.duration = project.calculateDuration();

    state = state.copyWith(project: project, isDirty: true);
    return true;
  }

  /// Remove a clip by ID
  bool removeClip(EditorId clipId) {
    final project = _cloneProject();
    var removed = false;

    for (final track in project.tracks) {
      final clipIndex = track.clips.indexWhere((c) => c.id == clipId);
      if (clipIndex != -1) {
        track.clips.removeAt(clipIndex);
        removed = true;
        break;
      }
    }

    if (!removed) return false;

    // Remove from selection
    final newSelectedIds = Set<EditorId>.from(state.selectedClipIds)
      ..remove(clipId);

    // Update project duration
    project.duration = project.calculateDuration();

    state = state.copyWith(
      project: project,
      selectedClipIds: newSelectedIds,
      isDirty: true,
    );
    return true;
  }

  /// Move a clip to a new position and optionally a new track
  bool moveClip(EditorId clipId, EditorTime newStart, int? newTrackIndex) {
    final project = _cloneProject();

    // Find the clip and its current track
    Track? sourceTrack;
    EditorClip? clip;
    for (final track in project.tracks) {
      final idx = track.clips.indexWhere((c) => c.id == clipId);
      if (idx != -1) {
        sourceTrack = track;
        clip = track.clips[idx];
        break;
      }
    }

    if (sourceTrack == null || clip == null) return false;

    // Determine target track
    final targetTrackIndex = newTrackIndex ?? clip.trackIndex;
    if (targetTrackIndex < 0 || targetTrackIndex >= project.tracks.length) {
      return false;
    }

    final targetTrack = project.tracks[targetTrackIndex];

    // Don't allow negative start time
    final clampedStart = EditorTime(
      newStart.microseconds < 0 ? 0 : newStart.microseconds,
    );

    // Create the moved clip
    final movedClip = clip.copyWith(
      timelineStart: clampedStart,
      trackIndex: targetTrackIndex,
    );

    // Check for overlaps (excluding the clip itself)
    if (_wouldOverlap(targetTrack, movedClip, excludeClipId: clipId)) {
      return false;
    }

    // Remove from source track
    sourceTrack.clips.removeWhere((c) => c.id == clipId);

    // Add to target track
    targetTrack.clips.add(movedClip);

    // Update project duration
    project.duration = project.calculateDuration();

    state = state.copyWith(project: project, isDirty: true);
    return true;
  }

  /// Resize a clip's duration
  bool resizeClip(
    EditorId clipId,
    EditorTime newDuration, {
    bool fromStart = false,
  }) {
    final project = _cloneProject();

    // Find the clip
    Track? track;
    int? clipIndex;
    for (final t in project.tracks) {
      final idx = t.clips.indexWhere((c) => c.id == clipId);
      if (idx != -1) {
        track = t;
        clipIndex = idx;
        break;
      }
    }

    if (track == null || clipIndex == null) return false;

    final clip = track.clips[clipIndex];

    // Ensure minimum duration (1 frame at 30fps ~= 33ms)
    final minDuration = EditorTime.fromMilliseconds(33);
    if (newDuration < minDuration) return false;

    // Ensure we don't exceed source duration
    final maxDuration = clip.sourceDuration;
    final clampedDuration = EditorTime(
      newDuration.microseconds > maxDuration.microseconds
          ? maxDuration.microseconds
          : newDuration.microseconds,
    );

    EditorClip resizedClip;
    if (fromStart) {
      // Resizing from the start changes both start position and source offset
      final delta = clip.duration - clampedDuration;
      final newTimelineStart = clip.timelineStart + delta;

      // Don't allow negative start time
      if (newTimelineStart.microseconds < 0) return false;

      final newSourceStart = clip.sourceStart + delta;

      // Don't allow negative source offset
      if (newSourceStart.microseconds < 0) return false;

      resizedClip = clip.copyWith(
        timelineStart: newTimelineStart,
        duration: clampedDuration,
        sourceStart: newSourceStart,
      );
    } else {
      // Resizing from the end only changes duration
      resizedClip = clip.copyWith(duration: clampedDuration);
    }

    // Check for overlaps
    if (_wouldOverlap(track, resizedClip, excludeClipId: clipId)) {
      return false;
    }

    track.clips[clipIndex] = resizedClip;

    // Update project duration
    project.duration = project.calculateDuration();

    state = state.copyWith(project: project, isDirty: true);
    return true;
  }

  // ============================================================
  // Selection Operations
  // ============================================================

  /// Select a clip, optionally adding to existing selection
  void selectClip(EditorId clipId, {bool addToSelection = false}) {
    Set<EditorId> newSelectedIds;

    if (addToSelection) {
      newSelectedIds = Set<EditorId>.from(state.selectedClipIds);
      if (newSelectedIds.contains(clipId)) {
        newSelectedIds.remove(clipId);
      } else {
        newSelectedIds.add(clipId);
      }
    } else {
      newSelectedIds = {clipId};
    }

    state = state.copyWith(selectedClipIds: newSelectedIds);
  }

  /// Clear all clip selections
  void clearSelection() {
    if (state.selectedClipIds.isEmpty) return;
    state = state.copyWith(selectedClipIds: {});
  }

  /// Select multiple clips
  void selectClips(Iterable<EditorId> clipIds) {
    state = state.copyWith(selectedClipIds: clipIds.toSet());
  }

  /// Select all clips in a time range
  void selectClipsInRange(EditorTimeRange range, {bool addToSelection = false}) {
    final clips = <EditorId>{};

    for (final track in state.project.tracks) {
      for (final clip in track.clips) {
        if (clip.timelineRange.overlaps(range)) {
          clips.add(clip.id);
        }
      }
    }

    if (addToSelection) {
      state = state.copyWith(
        selectedClipIds: state.selectedClipIds.union(clips),
      );
    } else {
      state = state.copyWith(selectedClipIds: clips);
    }
  }

  // ============================================================
  // Playhead & Navigation
  // ============================================================

  /// Set the playhead position
  void setPlayhead(EditorTime time) {
    final project = _cloneProject();

    // Clamp to valid range
    final clampedTime = EditorTime(
      time.microseconds < 0
          ? 0
          : (time.microseconds > project.duration.microseconds
              ? project.duration.microseconds
              : time.microseconds),
    );

    project.playheadPosition = clampedTime;
    state = state.copyWith(project: project);
  }

  /// Move playhead by a delta amount
  void movePlayhead(EditorTime delta) {
    setPlayhead(state.project.playheadPosition + delta);
  }

  /// Jump to the next clip boundary
  void jumpToNextClip() {
    final currentTime = state.project.playheadPosition;
    EditorTime? nextBoundary;

    for (final track in state.project.tracks) {
      for (final clip in track.clips) {
        // Check clip start
        if (clip.timelineStart > currentTime) {
          if (nextBoundary == null || clip.timelineStart < nextBoundary) {
            nextBoundary = clip.timelineStart;
          }
        }
        // Check clip end
        if (clip.timelineEnd > currentTime) {
          if (nextBoundary == null || clip.timelineEnd < nextBoundary) {
            nextBoundary = clip.timelineEnd;
          }
        }
      }
    }

    if (nextBoundary != null) {
      setPlayhead(nextBoundary);
    }
  }

  /// Jump to the previous clip boundary
  void jumpToPreviousClip() {
    final currentTime = state.project.playheadPosition;
    EditorTime? prevBoundary;

    for (final track in state.project.tracks) {
      for (final clip in track.clips) {
        // Check clip start
        if (clip.timelineStart < currentTime) {
          if (prevBoundary == null || clip.timelineStart > prevBoundary) {
            prevBoundary = clip.timelineStart;
          }
        }
        // Check clip end
        if (clip.timelineEnd < currentTime) {
          if (prevBoundary == null || clip.timelineEnd > prevBoundary) {
            prevBoundary = clip.timelineEnd;
          }
        }
      }
    }

    if (prevBoundary != null) {
      setPlayhead(prevBoundary);
    }
  }

  // ============================================================
  // Zoom & Scroll
  // ============================================================

  /// Set the zoom level (pixels per second)
  void setZoom(double pixelsPerSecond) {
    final project = _cloneProject();

    // Clamp zoom to reasonable range
    final clampedZoom = pixelsPerSecond.clamp(10.0, 1000.0);
    project.zoomLevel = clampedZoom;

    state = state.copyWith(project: project);
  }

  /// Set the scroll offset
  void setScroll(EditorTime offset) {
    final project = _cloneProject();

    // Clamp to valid range
    final clampedOffset = EditorTime(
      offset.microseconds < 0 ? 0 : offset.microseconds,
    );

    project.scrollOffset = clampedOffset;
    state = state.copyWith(project: project);
  }

  /// Zoom in by a factor
  void zoomIn({double factor = 1.2}) {
    setZoom(state.project.zoomLevel * factor);
  }

  /// Zoom out by a factor
  void zoomOut({double factor = 1.2}) {
    setZoom(state.project.zoomLevel / factor);
  }

  /// Fit the timeline to show all content
  void zoomToFit(double availableWidth) {
    final duration = state.project.calculateDuration();
    if (duration.microseconds > 0) {
      final pixelsPerSecond = availableWidth / duration.inSeconds;
      setZoom(pixelsPerSecond);
      setScroll(const EditorTime.zero());
    }
  }

  // ============================================================
  // Playback Control
  // ============================================================

  /// Start playback
  void play() {
    if (state.playbackState == PlaybackState.playing) return;
    state = state.copyWith(playbackState: PlaybackState.playing);
  }

  /// Pause playback
  void pause() {
    if (state.playbackState != PlaybackState.playing) return;
    state = state.copyWith(playbackState: PlaybackState.paused);
  }

  /// Stop playback and return to start
  void stop() {
    final project = _cloneProject();
    project.playheadPosition = state.project.inPoint ?? const EditorTime.zero();

    state = state.copyWith(
      project: project,
      playbackState: PlaybackState.stopped,
    );
  }

  /// Toggle play/pause
  void togglePlayback() {
    if (state.playbackState == PlaybackState.playing) {
      pause();
    } else {
      play();
    }
  }

  // ============================================================
  // In/Out Points
  // ============================================================

  /// Set the in point
  void setInPoint(EditorTime? time) {
    final project = _cloneProject();
    project.inPoint = time;
    state = state.copyWith(project: project, isDirty: true);
  }

  /// Set the out point
  void setOutPoint(EditorTime? time) {
    final project = _cloneProject();
    project.outPoint = time;
    state = state.copyWith(project: project, isDirty: true);
  }

  /// Clear in/out points
  void clearInOutPoints() {
    final project = _cloneProject();
    project.inPoint = null;
    project.outPoint = null;
    state = state.copyWith(project: project, isDirty: true);
  }

  /// Mark current playhead as in point
  void markIn() {
    setInPoint(state.project.playheadPosition);
  }

  /// Mark current playhead as out point
  void markOut() {
    setOutPoint(state.project.playheadPosition);
  }

  // ============================================================
  // Project Settings
  // ============================================================

  /// Update project settings
  void updateSettings(ProjectSettings settings) {
    final project = _cloneProject();
    project.settings = settings;
    state = state.copyWith(project: project, isDirty: true);
  }

  /// Update project name
  void setProjectName(String name) {
    final project = _cloneProject();
    project.name = name;
    state = state.copyWith(project: project, isDirty: true);
  }

  /// Mark project as saved (not dirty)
  void markSaved() {
    state = state.copyWith(isDirty: false);
  }

  // ============================================================
  // Helper Methods
  // ============================================================

  /// Clone the project for immutable updates
  EditorProject _cloneProject() {
    final original = state.project;
    return EditorProject(
      id: original.id,
      name: original.name,
      tracks: original.tracks.map((t) => t.copyWith()).toList(),
      settings: original.settings.copyWith(),
      duration: original.duration,
      playheadPosition: original.playheadPosition,
      inPoint: original.inPoint,
      outPoint: original.outPoint,
      zoomLevel: original.zoomLevel,
      scrollOffset: original.scrollOffset,
    );
  }

  /// Check if a clip would overlap with existing clips on a track
  bool _wouldOverlap(Track track, EditorClip clip, {EditorId? excludeClipId}) {
    for (final existingClip in track.clips) {
      if (excludeClipId != null && existingClip.id == excludeClipId) {
        continue;
      }
      if (clip.timelineRange.overlaps(existingClip.timelineRange)) {
        return true;
      }
    }
    return false;
  }

  /// Update track indices for all clips after track reordering
  void _updateTrackIndices(EditorProject project) {
    for (var i = 0; i < project.tracks.length; i++) {
      for (final clip in project.tracks[i].clips) {
        clip.trackIndex = i;
      }
    }
  }
}

// ============================================================
// Providers
// ============================================================

/// Main provider for the editor project state
final editorProjectProvider =
    StateNotifierProvider<EditorProjectNotifier, EditorProjectState>(
  (ref) => EditorProjectNotifier(),
);

/// Provider for the current playback state
final playbackStateProvider = Provider<PlaybackState>(
  (ref) => ref.watch(editorProjectProvider).playbackState,
);

/// Provider for the current editor tool
final currentToolProvider = StateProvider<EditorTool>(
  (ref) => EditorTool.select,
);

/// Derived provider for selected clips
final selectedClipsProvider = Provider<List<EditorClip>>(
  (ref) {
    final state = ref.watch(editorProjectProvider);
    return state.selectedClips;
  },
);

/// Provider for the current playhead position
final playheadPositionProvider = Provider<EditorTime>(
  (ref) => ref.watch(editorProjectProvider).project.playheadPosition,
);

/// Provider for the current zoom level
final zoomLevelProvider = Provider<double>(
  (ref) => ref.watch(editorProjectProvider).project.zoomLevel,
);

/// Provider for the current scroll offset
final scrollOffsetProvider = Provider<EditorTime>(
  (ref) => ref.watch(editorProjectProvider).project.scrollOffset,
);

/// Provider for the project tracks
final tracksProvider = Provider<List<Track>>(
  (ref) => ref.watch(editorProjectProvider).project.tracks,
);

/// Provider for the project settings
final projectSettingsProvider = Provider<ProjectSettings>(
  (ref) => ref.watch(editorProjectProvider).project.settings,
);

/// Provider for whether the project has unsaved changes
final isDirtyProvider = Provider<bool>(
  (ref) => ref.watch(editorProjectProvider).isDirty,
);

/// Provider for the project duration
final projectDurationProvider = Provider<EditorTime>(
  (ref) => ref.watch(editorProjectProvider).project.duration,
);

/// Provider for selected clip IDs
final selectedClipIdsProvider = Provider<Set<EditorId>>(
  (ref) => ref.watch(editorProjectProvider).selectedClipIds,
);

/// Provider to check if a specific clip is selected
final isClipSelectedProvider = Provider.family<bool, EditorId>(
  (ref, clipId) => ref.watch(selectedClipIdsProvider).contains(clipId),
);

/// Provider for clips at the current playhead position
final clipsAtPlayheadProvider = Provider<List<EditorClip>>(
  (ref) {
    final state = ref.watch(editorProjectProvider);
    return state.project.clipsAt(state.project.playheadPosition);
  },
);

/// Provider for in/out point range
final inOutRangeProvider = Provider<EditorTimeRange?>(
  (ref) {
    final project = ref.watch(editorProjectProvider).project;
    if (project.inPoint != null && project.outPoint != null) {
      return EditorTimeRange(project.inPoint!, project.outPoint!);
    }
    return null;
  },
);
