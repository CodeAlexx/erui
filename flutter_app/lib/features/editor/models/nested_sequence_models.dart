import 'dart:ui';
import 'editor_models.dart';

/// A nested sequence (compound clip) that contains other clips
class NestedSequence extends EditorClip {
  /// The tracks contained within this nested sequence
  final List<Track> innerTracks;

  /// Inner sequence settings (resolution, frame rate)
  final ProjectSettings innerSettings;

  /// Whether this sequence is expanded in timeline for editing
  final bool isExpanded;

  /// Color tint for nested sequence clips
  final Color tint;

  /// Original project this was created from (if opened from main timeline)
  final EditorId? sourceProjectId;

  /// Whether changes are synced back to source clips
  final bool syncWithSource;

  NestedSequence({
    super.id,
    required String name,
    required super.timelineStart,
    required super.duration,
    required this.innerTracks,
    ProjectSettings? innerSettings,
    this.isExpanded = false,
    Color? tint,
    this.sourceProjectId,
    this.syncWithSource = true,
    super.trackIndex = 0,
    super.isSelected = false,
    super.isLocked = false,
    super.opacity = 1.0,
  })  : innerSettings = innerSettings ?? const ProjectSettings(),
        tint = tint ?? const Color(0xFF9C27B0),
        super(
          type: ClipType.video,
          name: name,
          color: tint ?? const Color(0xFF9C27B0),
        );

  @override
  NestedSequence copyWith({
    EditorId? id,
    ClipType? type,
    String? name,
    EditorTime? timelineStart,
    EditorTime? duration,
    String? sourcePath,
    EditorTime? sourceStart,
    EditorTime? sourceDuration,
    int? trackIndex,
    bool? isSelected,
    bool? isLocked,
    double? opacity,
    Color? color,
    List<Track>? innerTracks,
    ProjectSettings? innerSettings,
    bool? isExpanded,
    Color? tint,
    EditorId? sourceProjectId,
    bool? syncWithSource,
  }) {
    return NestedSequence(
      id: id ?? this.id,
      name: name ?? this.name,
      timelineStart: timelineStart ?? this.timelineStart,
      duration: duration ?? this.duration,
      innerTracks: innerTracks ?? List.from(this.innerTracks),
      innerSettings: innerSettings ?? this.innerSettings,
      isExpanded: isExpanded ?? this.isExpanded,
      tint: tint ?? this.tint,
      sourceProjectId: sourceProjectId ?? this.sourceProjectId,
      syncWithSource: syncWithSource ?? this.syncWithSource,
      trackIndex: trackIndex ?? this.trackIndex,
      isSelected: isSelected ?? this.isSelected,
      isLocked: isLocked ?? this.isLocked,
      opacity: opacity ?? this.opacity,
    );
  }

  /// Calculate duration from inner clips
  EditorTime calculateInnerDuration() {
    EditorTime maxEnd = const EditorTime.zero();
    for (final track in innerTracks) {
      for (final clip in track.clips) {
        if (clip.timelineEnd > maxEnd) {
          maxEnd = clip.timelineEnd;
        }
      }
    }
    return maxEnd;
  }

  /// Get all clips at a specific time within the nested sequence
  List<EditorClip> innerClipsAt(EditorTime time) {
    final result = <EditorClip>[];
    for (final track in innerTracks) {
      for (final clip in track.clips) {
        if (clip.timelineRange.contains(time)) {
          result.add(clip);
        }
      }
    }
    return result;
  }

  /// Flatten nested sequence back to individual clips
  List<EditorClip> flatten(EditorTime startOffset) {
    final result = <EditorClip>[];
    for (final track in innerTracks) {
      for (final clip in track.clips) {
        result.add(clip.copyWith(
          timelineStart: clip.timelineStart + startOffset,
        ));
      }
    }
    return result;
  }

  /// Get inner video tracks
  List<Track> get innerVideoTracks =>
      innerTracks.where((t) => t.type == TrackType.video).toList();

  /// Get inner audio tracks
  List<Track> get innerAudioTracks =>
      innerTracks.where((t) => t.type == TrackType.audio).toList();

  /// Check if this sequence contains a specific clip
  bool containsClip(EditorId clipId) {
    for (final track in innerTracks) {
      if (track.clips.any((c) => c.id == clipId)) {
        return true;
      }
    }
    return false;
  }
}

/// Compound clip - a simplified nested sequence from selected clips
class CompoundClip extends NestedSequence {
  /// IDs of original clips that make up this compound
  final List<EditorId> sourceClipIds;

  CompoundClip({
    super.id,
    required super.name,
    required super.timelineStart,
    required super.duration,
    required super.innerTracks,
    required this.sourceClipIds,
    super.innerSettings,
    super.isExpanded,
    super.tint,
    super.syncWithSource = true,
    super.trackIndex,
    super.isSelected,
    super.isLocked,
    super.opacity,
  });

  @override
  CompoundClip copyWith({
    EditorId? id,
    ClipType? type,
    String? name,
    EditorTime? timelineStart,
    EditorTime? duration,
    String? sourcePath,
    EditorTime? sourceStart,
    EditorTime? sourceDuration,
    int? trackIndex,
    bool? isSelected,
    bool? isLocked,
    double? opacity,
    Color? color,
    List<Track>? innerTracks,
    ProjectSettings? innerSettings,
    bool? isExpanded,
    Color? tint,
    EditorId? sourceProjectId,
    bool? syncWithSource,
    List<EditorId>? sourceClipIds,
  }) {
    return CompoundClip(
      id: id ?? this.id,
      name: name ?? this.name,
      timelineStart: timelineStart ?? this.timelineStart,
      duration: duration ?? this.duration,
      innerTracks: innerTracks ?? List.from(this.innerTracks),
      sourceClipIds: sourceClipIds ?? List.from(this.sourceClipIds),
      innerSettings: innerSettings ?? this.innerSettings,
      isExpanded: isExpanded ?? this.isExpanded,
      tint: tint ?? this.tint,
      syncWithSource: syncWithSource ?? this.syncWithSource,
      trackIndex: trackIndex ?? this.trackIndex,
      isSelected: isSelected ?? this.isSelected,
      isLocked: isLocked ?? this.isLocked,
      opacity: opacity ?? this.opacity,
    );
  }

  /// Create a compound clip from a list of clips
  factory CompoundClip.fromClips({
    required String name,
    required List<EditorClip> clips,
    ProjectSettings? settings,
  }) {
    if (clips.isEmpty) {
      throw ArgumentError('Cannot create compound clip from empty list');
    }

    // Find the time range of all clips
    EditorTime minStart = clips.first.timelineStart;
    EditorTime maxEnd = clips.first.timelineEnd;

    for (final clip in clips) {
      if (clip.timelineStart < minStart) minStart = clip.timelineStart;
      if (clip.timelineEnd > maxEnd) maxEnd = clip.timelineEnd;
    }

    // Group clips by track type
    final videoClips = clips.where((c) =>
        c.type == ClipType.video || c.type == ClipType.image).toList();
    final audioClips = clips.where((c) => c.type == ClipType.audio).toList();
    final textClips = clips.where((c) => c.type == ClipType.text).toList();

    // Create inner tracks
    final innerTracks = <Track>[];

    if (videoClips.isNotEmpty) {
      innerTracks.add(Track(
        type: TrackType.video,
        name: 'Video 1',
        clips: videoClips.map((c) => c.copyWith(
          timelineStart: EditorTime(c.timelineStart.microseconds - minStart.microseconds),
        )).toList(),
      ));
    }

    if (audioClips.isNotEmpty) {
      innerTracks.add(Track(
        type: TrackType.audio,
        name: 'Audio 1',
        clips: audioClips.map((c) => c.copyWith(
          timelineStart: EditorTime(c.timelineStart.microseconds - minStart.microseconds),
        )).toList(),
      ));
    }

    if (textClips.isNotEmpty) {
      innerTracks.add(Track(
        type: TrackType.text,
        name: 'Text 1',
        clips: textClips.map((c) => c.copyWith(
          timelineStart: EditorTime(c.timelineStart.microseconds - minStart.microseconds),
        )).toList(),
      ));
    }

    return CompoundClip(
      name: name,
      timelineStart: minStart,
      duration: maxEnd - minStart,
      innerTracks: innerTracks,
      sourceClipIds: clips.map((c) => c.id).toList(),
      innerSettings: settings,
    );
  }
}

/// State for nested sequence editing
class NestedSequenceState {
  /// Currently active nested sequence being edited (null = main timeline)
  final EditorId? activeSequenceId;

  /// Breadcrumb path of nested sequences (for nested within nested)
  final List<EditorId> navigationPath;

  /// Map of sequence ID to its state
  final Map<EditorId, NestedSequenceEditState> sequenceStates;

  const NestedSequenceState({
    this.activeSequenceId,
    this.navigationPath = const [],
    this.sequenceStates = const {},
  });

  NestedSequenceState copyWith({
    EditorId? activeSequenceId,
    List<EditorId>? navigationPath,
    Map<EditorId, NestedSequenceEditState>? sequenceStates,
  }) {
    return NestedSequenceState(
      activeSequenceId: activeSequenceId ?? this.activeSequenceId,
      navigationPath: navigationPath ?? List.from(this.navigationPath),
      sequenceStates: sequenceStates ?? Map.from(this.sequenceStates),
    );
  }

  /// Check if we're currently editing inside a nested sequence
  bool get isInNestedSequence => activeSequenceId != null;

  /// Get the depth of nesting
  int get nestingDepth => navigationPath.length;
}

/// Edit state for a specific nested sequence
class NestedSequenceEditState {
  final EditorTime playheadPosition;
  final EditorTime scrollOffset;
  final double zoomLevel;
  final Set<EditorId> selectedClipIds;

  const NestedSequenceEditState({
    this.playheadPosition = const EditorTime.zero(),
    this.scrollOffset = const EditorTime.zero(),
    this.zoomLevel = 100.0,
    this.selectedClipIds = const {},
  });

  NestedSequenceEditState copyWith({
    EditorTime? playheadPosition,
    EditorTime? scrollOffset,
    double? zoomLevel,
    Set<EditorId>? selectedClipIds,
  }) {
    return NestedSequenceEditState(
      playheadPosition: playheadPosition ?? this.playheadPosition,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      selectedClipIds: selectedClipIds ?? Set.from(this.selectedClipIds),
    );
  }
}
