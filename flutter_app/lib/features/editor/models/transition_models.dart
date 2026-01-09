import 'editor_models.dart';

/// Types of transitions between clips
enum TransitionType {
  /// Gradual crossfade between clips
  crossDissolve,

  /// Fade to/from black
  fade,

  /// Wipe effect with direction
  wipe,

  /// Slide from left
  slideLeft,

  /// Slide from right
  slideRight,

  /// Dissolve with pattern
  dissolve,
}

/// A transition between two adjacent clips
class Transition {
  /// Unique identifier for this transition
  final EditorId id;

  /// ID of the clip ending (first clip)
  final EditorId startClipId;

  /// ID of the clip beginning (second clip)
  final EditorId endClipId;

  /// Duration of the transition
  final EditorTime duration;

  /// Type of transition effect
  final TransitionType type;

  /// Progress curve (for easing)
  final String curve; // 'linear', 'easeIn', 'easeOut', 'easeInOut'

  /// Track index where transition occurs
  final int trackIndex;

  const Transition({
    required this.id,
    required this.startClipId,
    required this.endClipId,
    required this.duration,
    required this.type,
    this.curve = 'linear',
    this.trackIndex = 0,
  });

  /// Create a new transition with a generated ID
  factory Transition.create({
    required EditorId startClipId,
    required EditorId endClipId,
    required EditorTime duration,
    required TransitionType type,
    String curve = 'linear',
    int trackIndex = 0,
  }) {
    return Transition(
      id: generateId(),
      startClipId: startClipId,
      endClipId: endClipId,
      duration: duration,
      type: type,
      curve: curve,
      trackIndex: trackIndex,
    );
  }

  /// Create a copy with optional parameter overrides
  Transition copyWith({
    EditorId? id,
    EditorId? startClipId,
    EditorId? endClipId,
    EditorTime? duration,
    TransitionType? type,
    String? curve,
    int? trackIndex,
  }) {
    return Transition(
      id: id ?? this.id,
      startClipId: startClipId ?? this.startClipId,
      endClipId: endClipId ?? this.endClipId,
      duration: duration ?? this.duration,
      type: type ?? this.type,
      curve: curve ?? this.curve,
      trackIndex: trackIndex ?? this.trackIndex,
    );
  }

  /// Get FFmpeg xfade filter name for this transition type
  String get ffmpegTransitionName {
    switch (type) {
      case TransitionType.crossDissolve:
        return 'fade';
      case TransitionType.fade:
        return 'fade';
      case TransitionType.wipe:
        return 'wipeleft';
      case TransitionType.slideLeft:
        return 'slideleft';
      case TransitionType.slideRight:
        return 'slideright';
      case TransitionType.dissolve:
        return 'dissolve';
    }
  }

  /// Display name for UI
  String get displayName {
    switch (type) {
      case TransitionType.crossDissolve:
        return 'Cross Dissolve';
      case TransitionType.fade:
        return 'Fade';
      case TransitionType.wipe:
        return 'Wipe';
      case TransitionType.slideLeft:
        return 'Slide Left';
      case TransitionType.slideRight:
        return 'Slide Right';
      case TransitionType.dissolve:
        return 'Dissolve';
    }
  }

  /// Get icon for this transition type
  String get iconName {
    switch (type) {
      case TransitionType.crossDissolve:
        return 'blur_on';
      case TransitionType.fade:
        return 'gradient';
      case TransitionType.wipe:
        return 'swipe';
      case TransitionType.slideLeft:
        return 'arrow_back';
      case TransitionType.slideRight:
        return 'arrow_forward';
      case TransitionType.dissolve:
        return 'auto_awesome';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transition &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Transition(id: $id, type: $type, duration: $duration)';
  }
}

/// Extension to provide all transition types for UI pickers
extension TransitionTypeExtension on TransitionType {
  /// Get all available transition types
  static List<TransitionType> get all => TransitionType.values;

  /// Get display name for this type
  String get displayName {
    switch (this) {
      case TransitionType.crossDissolve:
        return 'Cross Dissolve';
      case TransitionType.fade:
        return 'Fade';
      case TransitionType.wipe:
        return 'Wipe';
      case TransitionType.slideLeft:
        return 'Slide Left';
      case TransitionType.slideRight:
        return 'Slide Right';
      case TransitionType.dissolve:
        return 'Dissolve';
    }
  }

  /// Get description for this transition type
  String get description {
    switch (this) {
      case TransitionType.crossDissolve:
        return 'Smoothly blend between clips';
      case TransitionType.fade:
        return 'Fade through black';
      case TransitionType.wipe:
        return 'Wipe from one side';
      case TransitionType.slideLeft:
        return 'Slide new clip from right';
      case TransitionType.slideRight:
        return 'Slide new clip from left';
      case TransitionType.dissolve:
        return 'Dissolve with pattern';
    }
  }
}
