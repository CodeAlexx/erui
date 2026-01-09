import 'dart:ui';
import 'editor_models.dart';

/// Interpolation type between keyframes
enum KeyframeType {
  /// Linear interpolation
  linear,

  /// Bezier curve interpolation
  bezier,

  /// Step/hold (no interpolation)
  hold,

  /// Ease in
  easeIn,

  /// Ease out
  easeOut,

  /// Ease in and out
  easeInOut,
}

/// Bezier handle for curve control
class BezierHandle {
  final double x; // Time offset
  final double y; // Value offset

  const BezierHandle(this.x, this.y);
  const BezierHandle.zero() : x = 0.0, y = 0.0;

  BezierHandle copyWith({double? x, double? y}) {
    return BezierHandle(x ?? this.x, y ?? this.y);
  }

  Offset toOffset() => Offset(x, y);

  factory BezierHandle.fromOffset(Offset offset) {
    return BezierHandle(offset.dx, offset.dy);
  }
}

/// A single keyframe in an animation track
class Keyframe {
  final EditorId id;

  /// Time position of this keyframe
  final EditorTime time;

  /// Value at this keyframe
  final double value;

  /// Interpolation type to next keyframe
  final KeyframeType type;

  /// Incoming bezier handle (for bezier type)
  final BezierHandle? handleIn;

  /// Outgoing bezier handle (for bezier type)
  final BezierHandle? handleOut;

  /// Whether keyframe is selected in UI
  final bool isSelected;

  const Keyframe({
    required this.id,
    required this.time,
    required this.value,
    this.type = KeyframeType.linear,
    this.handleIn,
    this.handleOut,
    this.isSelected = false,
  });

  factory Keyframe.create({
    required EditorTime time,
    required double value,
    KeyframeType type = KeyframeType.linear,
  }) {
    return Keyframe(
      id: generateId(),
      time: time,
      value: value,
      type: type,
      handleIn:
          type == KeyframeType.bezier ? const BezierHandle(-0.25, 0) : null,
      handleOut:
          type == KeyframeType.bezier ? const BezierHandle(0.25, 0) : null,
    );
  }

  Keyframe copyWith({
    EditorId? id,
    EditorTime? time,
    double? value,
    KeyframeType? type,
    BezierHandle? handleIn,
    BezierHandle? handleOut,
    bool? isSelected,
  }) {
    return Keyframe(
      id: id ?? this.id,
      time: time ?? this.time,
      value: value ?? this.value,
      type: type ?? this.type,
      handleIn: handleIn ?? this.handleIn,
      handleOut: handleOut ?? this.handleOut,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Keyframe && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Animatable property types
enum AnimatableProperty {
  opacity,
  positionX,
  positionY,
  scaleX,
  scaleY,
  rotation,
  volume,
  brightness,
  contrast,
  saturation,
  blur,
}

/// A track of keyframes for animating a property
class KeyframeTrack {
  final EditorId id;

  /// ID of the clip this track animates
  final EditorId clipId;

  /// Property being animated
  final AnimatableProperty property;

  /// Display name for the track
  final String name;

  /// List of keyframes sorted by time
  final List<Keyframe> keyframes;

  /// Whether track is enabled
  final bool enabled;

  /// Whether track is expanded in UI
  final bool isExpanded;

  /// Min value for this property
  final double minValue;

  /// Max value for this property
  final double maxValue;

  /// Default value when no keyframes exist
  final double defaultValue;

  const KeyframeTrack({
    required this.id,
    required this.clipId,
    required this.property,
    required this.name,
    this.keyframes = const [],
    this.enabled = true,
    this.isExpanded = false,
    required this.minValue,
    required this.maxValue,
    required this.defaultValue,
  });

  factory KeyframeTrack.forProperty({
    required EditorId clipId,
    required AnimatableProperty property,
  }) {
    final range = _rangeForProperty(property);
    return KeyframeTrack(
      id: generateId(),
      clipId: clipId,
      property: property,
      name: property.displayName,
      minValue: range.$1,
      maxValue: range.$2,
      defaultValue: range.$3,
    );
  }

  static (double, double, double) _rangeForProperty(AnimatableProperty prop) {
    switch (prop) {
      case AnimatableProperty.opacity:
      case AnimatableProperty.volume:
        return (0.0, 1.0, 1.0);
      case AnimatableProperty.positionX:
      case AnimatableProperty.positionY:
        return (-1000.0, 1000.0, 0.0);
      case AnimatableProperty.scaleX:
      case AnimatableProperty.scaleY:
        return (0.0, 4.0, 1.0);
      case AnimatableProperty.rotation:
        return (-360.0, 360.0, 0.0);
      case AnimatableProperty.brightness:
        return (-100.0, 100.0, 0.0);
      case AnimatableProperty.contrast:
      case AnimatableProperty.saturation:
        return (0.0, 200.0, 100.0);
      case AnimatableProperty.blur:
        return (0.0, 100.0, 0.0);
    }
  }

  /// Get sorted keyframes
  List<Keyframe> get sortedKeyframes => List.from(keyframes)
    ..sort((a, b) => a.time.microseconds.compareTo(b.time.microseconds));

  /// Get value at a specific time
  double valueAt(EditorTime time) {
    if (keyframes.isEmpty) return defaultValue;

    final sorted = sortedKeyframes;

    // Before first keyframe
    if (time <= sorted.first.time) return sorted.first.value;

    // After last keyframe
    if (time >= sorted.last.time) return sorted.last.value;

    // Find surrounding keyframes
    for (int i = 0; i < sorted.length - 1; i++) {
      final kf1 = sorted[i];
      final kf2 = sorted[i + 1];

      if (time >= kf1.time && time <= kf2.time) {
        return _interpolate(kf1, kf2, time);
      }
    }

    return defaultValue;
  }

  double _interpolate(Keyframe kf1, Keyframe kf2, EditorTime time) {
    final t1 = kf1.time.microseconds;
    final t2 = kf2.time.microseconds;
    final t = time.microseconds;

    if (t2 == t1) return kf1.value;

    final progress = (t - t1) / (t2 - t1);

    switch (kf1.type) {
      case KeyframeType.hold:
        return kf1.value;
      case KeyframeType.linear:
        return kf1.value + (kf2.value - kf1.value) * progress;
      case KeyframeType.easeIn:
        return kf1.value + (kf2.value - kf1.value) * (progress * progress);
      case KeyframeType.easeOut:
        return kf1.value +
            (kf2.value - kf1.value) *
                (1 - (1 - progress) * (1 - progress));
      case KeyframeType.easeInOut:
        final ease = progress < 0.5
            ? 2 * progress * progress
            : 1 - (-2 * progress + 2) * (-2 * progress + 2) / 2;
        return kf1.value + (kf2.value - kf1.value) * ease;
      case KeyframeType.bezier:
        // Simplified bezier - full implementation would use handle points
        final ease = progress < 0.5
            ? 2 * progress * progress
            : 1 - (-2 * progress + 2) * (-2 * progress + 2) / 2;
        return kf1.value + (kf2.value - kf1.value) * ease;
    }
  }

  KeyframeTrack copyWith({
    EditorId? id,
    EditorId? clipId,
    AnimatableProperty? property,
    String? name,
    List<Keyframe>? keyframes,
    bool? enabled,
    bool? isExpanded,
    double? minValue,
    double? maxValue,
    double? defaultValue,
  }) {
    return KeyframeTrack(
      id: id ?? this.id,
      clipId: clipId ?? this.clipId,
      property: property ?? this.property,
      name: name ?? this.name,
      keyframes: keyframes ?? List.from(this.keyframes),
      enabled: enabled ?? this.enabled,
      isExpanded: isExpanded ?? this.isExpanded,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      defaultValue: defaultValue ?? this.defaultValue,
    );
  }

  /// Add a keyframe
  KeyframeTrack addKeyframe(Keyframe keyframe) {
    return copyWith(keyframes: [...keyframes, keyframe]);
  }

  /// Remove a keyframe by ID
  KeyframeTrack removeKeyframe(EditorId keyframeId) {
    return copyWith(
      keyframes: keyframes.where((k) => k.id != keyframeId).toList(),
    );
  }

  /// Update a keyframe
  KeyframeTrack updateKeyframe(Keyframe updated) {
    return copyWith(
      keyframes:
          keyframes.map((k) => k.id == updated.id ? updated : k).toList(),
    );
  }

  /// Check if there are any keyframes
  bool get hasKeyframes => keyframes.isNotEmpty;

  /// Get keyframe at or near a specific time
  Keyframe? keyframeAt(EditorTime time, {int toleranceMicroseconds = 50000}) {
    for (final kf in keyframes) {
      if ((kf.time.microseconds - time.microseconds).abs() <=
          toleranceMicroseconds) {
        return kf;
      }
    }
    return null;
  }
}

/// Extension for AnimatableProperty utilities
extension AnimatablePropertyExtension on AnimatableProperty {
  String get displayName {
    switch (this) {
      case AnimatableProperty.opacity:
        return 'Opacity';
      case AnimatableProperty.positionX:
        return 'Position X';
      case AnimatableProperty.positionY:
        return 'Position Y';
      case AnimatableProperty.scaleX:
        return 'Scale X';
      case AnimatableProperty.scaleY:
        return 'Scale Y';
      case AnimatableProperty.rotation:
        return 'Rotation';
      case AnimatableProperty.volume:
        return 'Volume';
      case AnimatableProperty.brightness:
        return 'Brightness';
      case AnimatableProperty.contrast:
        return 'Contrast';
      case AnimatableProperty.saturation:
        return 'Saturation';
      case AnimatableProperty.blur:
        return 'Blur';
    }
  }

  String get category {
    switch (this) {
      case AnimatableProperty.opacity:
      case AnimatableProperty.positionX:
      case AnimatableProperty.positionY:
      case AnimatableProperty.scaleX:
      case AnimatableProperty.scaleY:
      case AnimatableProperty.rotation:
        return 'Transform';
      case AnimatableProperty.volume:
        return 'Audio';
      case AnimatableProperty.brightness:
      case AnimatableProperty.contrast:
      case AnimatableProperty.saturation:
      case AnimatableProperty.blur:
        return 'Effects';
    }
  }

  String get unit {
    switch (this) {
      case AnimatableProperty.opacity:
      case AnimatableProperty.volume:
        return '%';
      case AnimatableProperty.positionX:
      case AnimatableProperty.positionY:
        return 'px';
      case AnimatableProperty.scaleX:
      case AnimatableProperty.scaleY:
        return 'x';
      case AnimatableProperty.rotation:
        return '\u00B0'; // Degree symbol
      case AnimatableProperty.brightness:
      case AnimatableProperty.contrast:
      case AnimatableProperty.saturation:
      case AnimatableProperty.blur:
        return '';
    }
  }
}

/// Extension for KeyframeType utilities
extension KeyframeTypeExtension on KeyframeType {
  String get displayName {
    switch (this) {
      case KeyframeType.linear:
        return 'Linear';
      case KeyframeType.bezier:
        return 'Bezier';
      case KeyframeType.hold:
        return 'Hold';
      case KeyframeType.easeIn:
        return 'Ease In';
      case KeyframeType.easeOut:
        return 'Ease Out';
      case KeyframeType.easeInOut:
        return 'Ease In/Out';
    }
  }

  String get iconName {
    switch (this) {
      case KeyframeType.linear:
        return 'timeline';
      case KeyframeType.bezier:
        return 'show_chart';
      case KeyframeType.hold:
        return 'square';
      case KeyframeType.easeIn:
        return 'keyboard_tab';
      case KeyframeType.easeOut:
        return 'keyboard_tab_rtl';
      case KeyframeType.easeInOut:
        return 'sync_alt';
    }
  }
}
