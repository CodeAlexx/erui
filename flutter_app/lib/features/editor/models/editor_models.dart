import 'dart:ui';

/// Unique identifier for editor objects
typedef EditorId = String;

/// Generate a unique ID
EditorId generateId() => DateTime.now().microsecondsSinceEpoch.toString();

/// Time representation in the editor (in microseconds for precision)
class EditorTime {
  final int microseconds;

  const EditorTime(this.microseconds);
  const EditorTime.zero() : microseconds = 0;

  factory EditorTime.fromSeconds(double seconds) =>
      EditorTime((seconds * 1000000).round());

  factory EditorTime.fromMilliseconds(int ms) => EditorTime(ms * 1000);

  factory EditorTime.fromFrames(int frames, double fps) =>
      EditorTime.fromSeconds(frames / fps);

  double get inSeconds => microseconds / 1000000.0;
  int get inMilliseconds => microseconds ~/ 1000;
  int toFrames(double fps) => (inSeconds * fps).round();

  EditorTime operator +(EditorTime other) =>
      EditorTime(microseconds + other.microseconds);

  EditorTime operator -(EditorTime other) =>
      EditorTime(microseconds - other.microseconds);

  bool operator <(EditorTime other) => microseconds < other.microseconds;
  bool operator <=(EditorTime other) => microseconds <= other.microseconds;
  bool operator >(EditorTime other) => microseconds > other.microseconds;
  bool operator >=(EditorTime other) => microseconds >= other.microseconds;

  @override
  bool operator ==(Object other) =>
      other is EditorTime && microseconds == other.microseconds;

  @override
  int get hashCode => microseconds.hashCode;

  @override
  String toString() {
    final totalSeconds = inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final frames = (seconds % 1 * 30).round(); // Assuming 30fps for display

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.floor().toString().padLeft(2, '0')}:${frames.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.floor().toString().padLeft(2, '0')}:${frames.toString().padLeft(2, '0')}';
  }
}

/// Time range in the editor
class EditorTimeRange {
  final EditorTime start;
  final EditorTime end;

  const EditorTimeRange(this.start, this.end);

  EditorTime get duration => end - start;

  bool contains(EditorTime time) => time >= start && time < end;

  bool overlaps(EditorTimeRange other) =>
      start < other.end && end > other.start;

  EditorTimeRange shift(EditorTime offset) =>
      EditorTimeRange(start + offset, end + offset);

  @override
  String toString() => 'EditorTimeRange($start - $end)';
}

/// Types of clips supported
enum ClipType {
  video,
  audio,
  image,
  text,
  effect,
  transition,
}

/// Base clip class
class Clip {
  final EditorId id;
  final ClipType type;
  final String name;

  /// Position on timeline
  EditorTime timelineStart;

  /// Duration on timeline (can be different from source duration)
  EditorTime duration;

  /// Source file path (for media clips)
  final String? sourcePath;

  /// Start offset within source (for trimming)
  EditorTime sourceStart;

  /// Original source duration
  final EditorTime sourceDuration;

  /// Track index this clip belongs to
  int trackIndex;

  /// Whether clip is selected
  bool isSelected;

  /// Whether clip is locked
  bool isLocked;

  /// Opacity (0.0 - 1.0)
  double opacity;

  /// Clip color for UI
  Color color;

  Clip({
    EditorId? id,
    required this.type,
    required this.name,
    required this.timelineStart,
    required this.duration,
    this.sourcePath,
    EditorTime? sourceStart,
    EditorTime? sourceDuration,
    this.trackIndex = 0,
    this.isSelected = false,
    this.isLocked = false,
    this.opacity = 1.0,
    Color? color,
  })  : id = id ?? generateId(),
        sourceStart = sourceStart ?? const EditorTime.zero(),
        sourceDuration = sourceDuration ?? duration,
        color = color ?? _defaultColorForType(type);

  static Color _defaultColorForType(ClipType type) {
    switch (type) {
      case ClipType.video:
        return const Color(0xFF4A90D9);
      case ClipType.audio:
        return const Color(0xFF50C878);
      case ClipType.image:
        return const Color(0xFFE6A23C);
      case ClipType.text:
        return const Color(0xFFAB68FF);
      case ClipType.effect:
        return const Color(0xFFFF6B6B);
      case ClipType.transition:
        return const Color(0xFF45B7D1);
    }
  }

  EditorTime get timelineEnd => timelineStart + duration;

  EditorTimeRange get timelineRange =>
      EditorTimeRange(timelineStart, timelineEnd);

  /// Check if this clip overlaps with another
  bool overlaps(Clip other) =>
      trackIndex == other.trackIndex && timelineRange.overlaps(other.timelineRange);

  /// Clone with modifications
  Clip copyWith({
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
  }) {
    return Clip(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      timelineStart: timelineStart ?? this.timelineStart,
      duration: duration ?? this.duration,
      sourcePath: sourcePath ?? this.sourcePath,
      sourceStart: sourceStart ?? this.sourceStart,
      sourceDuration: sourceDuration ?? this.sourceDuration,
      trackIndex: trackIndex ?? this.trackIndex,
      isSelected: isSelected ?? this.isSelected,
      isLocked: isLocked ?? this.isLocked,
      opacity: opacity ?? this.opacity,
      color: color ?? this.color,
    );
  }
}

/// Alias for Clip (used in providers)
typedef EditorClip = Clip;

/// Track types
enum TrackType {
  video,
  audio,
  text,
  effect,
}

/// A track in the timeline
class Track {
  final EditorId id;
  final TrackType type;
  String name;
  final List<Clip> clips;
  double height;
  bool isVisible;
  bool isLocked;
  bool isMuted;
  bool isSolo;

  /// Volume for audio tracks (0.0 - 2.0)
  double volume;

  /// Pan for audio tracks (-1.0 to 1.0)
  double pan;

  Track({
    EditorId? id,
    required this.type,
    required this.name,
    List<Clip>? clips,
    this.height = 60.0,
    this.isVisible = true,
    this.isLocked = false,
    this.isMuted = false,
    this.isSolo = false,
    this.volume = 1.0,
    this.pan = 0.0,
  })  : id = id ?? generateId(),
        clips = clips ?? [];

  /// Get all clips sorted by start time
  List<Clip> get sortedClips =>
      List.from(clips)..sort((a, b) => a.timelineStart.microseconds.compareTo(b.timelineStart.microseconds));

  /// Find clip at specific time
  Clip? clipAt(EditorTime time) {
    for (final clip in clips) {
      if (clip.timelineRange.contains(time)) {
        return clip;
      }
    }
    return null;
  }

  /// Add clip to track
  void addClip(Clip clip) {
    clips.add(clip);
  }

  /// Remove clip from track
  bool removeClip(EditorId clipId) {
    final lengthBefore = clips.length;
    clips.removeWhere((c) => c.id == clipId);
    return clips.length < lengthBefore;
  }

  Track copyWith({
    EditorId? id,
    TrackType? type,
    String? name,
    List<Clip>? clips,
    double? height,
    bool? isVisible,
    bool? isLocked,
    bool? isMuted,
    bool? isSolo,
    double? volume,
    double? pan,
  }) {
    return Track(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      clips: clips ?? List.from(this.clips),
      height: height ?? this.height,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
    );
  }
}

/// Project settings
class ProjectSettings {
  final int width;
  final int height;
  final double frameRate;
  final int sampleRate;
  final int audioBitDepth;
  final int audioChannels;

  const ProjectSettings({
    this.width = 1920,
    this.height = 1080,
    this.frameRate = 30.0,
    this.sampleRate = 48000,
    this.audioBitDepth = 16,
    this.audioChannels = 2,
  });

  double get aspectRatio => width / height;

  ProjectSettings copyWith({
    int? width,
    int? height,
    double? frameRate,
    int? sampleRate,
    int? audioBitDepth,
    int? audioChannels,
  }) {
    return ProjectSettings(
      width: width ?? this.width,
      height: height ?? this.height,
      frameRate: frameRate ?? this.frameRate,
      sampleRate: sampleRate ?? this.sampleRate,
      audioBitDepth: audioBitDepth ?? this.audioBitDepth,
      audioChannels: audioChannels ?? this.audioChannels,
    );
  }
}

/// The main project/timeline container
class EditorProject {
  final EditorId id;
  String name;
  final List<Track> tracks;
  ProjectSettings settings;
  EditorTime duration;

  /// Current playhead position
  EditorTime playheadPosition;

  /// In/out points for playback region
  EditorTime? inPoint;
  EditorTime? outPoint;

  /// Zoom level (pixels per second)
  double zoomLevel;

  /// Scroll offset (in time)
  EditorTime scrollOffset;

  EditorProject({
    EditorId? id,
    this.name = 'Untitled Project',
    List<Track>? tracks,
    ProjectSettings? settings,
    EditorTime? duration,
    EditorTime? playheadPosition,
    this.inPoint,
    this.outPoint,
    this.zoomLevel = 100.0,
    EditorTime? scrollOffset,
  })  : id = id ?? generateId(),
        tracks = tracks ?? [],
        settings = settings ?? const ProjectSettings(),
        duration = duration ?? EditorTime.fromSeconds(60),
        playheadPosition = playheadPosition ?? const EditorTime.zero(),
        scrollOffset = scrollOffset ?? const EditorTime.zero();

  /// Calculate total duration based on clips
  EditorTime calculateDuration() {
    EditorTime maxEnd = const EditorTime.zero();
    for (final track in tracks) {
      for (final clip in track.clips) {
        if (clip.timelineEnd > maxEnd) {
          maxEnd = clip.timelineEnd;
        }
      }
    }
    // Add some padding
    return EditorTime(maxEnd.microseconds + EditorTime.fromSeconds(5).microseconds);
  }

  /// Find all clips at a specific time across all tracks
  List<Clip> clipsAt(EditorTime time) {
    final result = <Clip>[];
    for (final track in tracks) {
      final clip = track.clipAt(time);
      if (clip != null) {
        result.add(clip);
      }
    }
    return result;
  }

  /// Find clip by ID
  Clip? findClip(EditorId clipId) {
    for (final track in tracks) {
      for (final clip in track.clips) {
        if (clip.id == clipId) {
          return clip;
        }
      }
    }
    return null;
  }

  /// Find track by ID
  Track? findTrack(EditorId trackId) {
    for (final track in tracks) {
      if (track.id == trackId) {
        return track;
      }
    }
    return null;
  }

  /// Get all selected clips
  List<Clip> get selectedClips {
    final result = <Clip>[];
    for (final track in tracks) {
      result.addAll(track.clips.where((c) => c.isSelected));
    }
    return result;
  }

  /// Clear all selections
  void clearSelection() {
    for (final track in tracks) {
      for (final clip in track.clips) {
        clip.isSelected = false;
      }
    }
  }

  /// Add a new video track
  Track addVideoTrack({String? name}) {
    final trackNum = tracks.where((t) => t.type == TrackType.video).length + 1;
    final track = Track(
      type: TrackType.video,
      name: name ?? 'Video $trackNum',
    );
    tracks.insert(0, track); // Video tracks at top
    return track;
  }

  /// Add a new audio track
  Track addAudioTrack({String? name}) {
    final trackNum = tracks.where((t) => t.type == TrackType.audio).length + 1;
    final track = Track(
      type: TrackType.audio,
      name: name ?? 'Audio $trackNum',
    );
    tracks.add(track); // Audio tracks at bottom
    return track;
  }
}
