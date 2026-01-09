import 'dart:ui';
import 'editor_models.dart';
import 'keyframe_models.dart';

/// A keyframe for speed/time remapping
class SpeedKeyframe {
  final EditorId id;

  /// Position in source time (microseconds)
  final EditorTime sourceTime;

  /// Position in output time (microseconds)
  final EditorTime outputTime;

  /// Speed multiplier at this point (1.0 = normal, 2.0 = 2x, 0.5 = half speed)
  final double speed;

  /// Interpolation type to next keyframe
  final KeyframeType interpolation;

  /// Bezier handle for curve control (time offset relative to keyframe)
  final BezierHandle? handleIn;
  final BezierHandle? handleOut;

  /// Whether this keyframe is selected in UI
  final bool isSelected;

  const SpeedKeyframe({
    required this.id,
    required this.sourceTime,
    required this.outputTime,
    this.speed = 1.0,
    this.interpolation = KeyframeType.linear,
    this.handleIn,
    this.handleOut,
    this.isSelected = false,
  });

  factory SpeedKeyframe.create({
    required EditorTime sourceTime,
    required EditorTime outputTime,
    double speed = 1.0,
    KeyframeType interpolation = KeyframeType.linear,
  }) {
    return SpeedKeyframe(
      id: generateId(),
      sourceTime: sourceTime,
      outputTime: outputTime,
      speed: speed,
      interpolation: interpolation,
      handleIn: interpolation == KeyframeType.bezier
          ? const BezierHandle(-0.25, 0)
          : null,
      handleOut: interpolation == KeyframeType.bezier
          ? const BezierHandle(0.25, 0)
          : null,
    );
  }

  SpeedKeyframe copyWith({
    EditorId? id,
    EditorTime? sourceTime,
    EditorTime? outputTime,
    double? speed,
    KeyframeType? interpolation,
    BezierHandle? handleIn,
    BezierHandle? handleOut,
    bool? isSelected,
  }) {
    return SpeedKeyframe(
      id: id ?? this.id,
      sourceTime: sourceTime ?? this.sourceTime,
      outputTime: outputTime ?? this.outputTime,
      speed: speed ?? this.speed,
      interpolation: interpolation ?? this.interpolation,
      handleIn: handleIn ?? this.handleIn,
      handleOut: handleOut ?? this.handleOut,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Time remapping curve for a clip
class TimeRemapCurve {
  final EditorId clipId;

  /// List of speed keyframes
  final List<SpeedKeyframe> keyframes;

  /// Whether time remapping is enabled
  final bool enabled;

  /// Whether to maintain audio pitch when speed changes
  final bool maintainPitch;

  /// Audio time stretching quality (0-1)
  final double audioQuality;

  /// Motion blur amount for speed changes (0-1)
  final double motionBlur;

  /// Optical flow interpolation for slow motion
  final bool opticalFlow;

  const TimeRemapCurve({
    required this.clipId,
    this.keyframes = const [],
    this.enabled = false,
    this.maintainPitch = true,
    this.audioQuality = 0.8,
    this.motionBlur = 0.0,
    this.opticalFlow = false,
  });

  TimeRemapCurve copyWith({
    EditorId? clipId,
    List<SpeedKeyframe>? keyframes,
    bool? enabled,
    bool? maintainPitch,
    double? audioQuality,
    double? motionBlur,
    bool? opticalFlow,
  }) {
    return TimeRemapCurve(
      clipId: clipId ?? this.clipId,
      keyframes: keyframes ?? List.from(this.keyframes),
      enabled: enabled ?? this.enabled,
      maintainPitch: maintainPitch ?? this.maintainPitch,
      audioQuality: audioQuality ?? this.audioQuality,
      motionBlur: motionBlur ?? this.motionBlur,
      opticalFlow: opticalFlow ?? this.opticalFlow,
    );
  }

  /// Get sorted keyframes by source time
  List<SpeedKeyframe> get sortedKeyframes => List.from(keyframes)
    ..sort((a, b) => a.sourceTime.microseconds.compareTo(b.sourceTime.microseconds));

  /// Add a keyframe
  TimeRemapCurve addKeyframe(SpeedKeyframe keyframe) {
    return copyWith(keyframes: [...keyframes, keyframe], enabled: true);
  }

  /// Remove a keyframe
  TimeRemapCurve removeKeyframe(EditorId keyframeId) {
    return copyWith(
      keyframes: keyframes.where((k) => k.id != keyframeId).toList(),
    );
  }

  /// Update a keyframe
  TimeRemapCurve updateKeyframe(SpeedKeyframe updated) {
    return copyWith(
      keyframes: keyframes.map((k) => k.id == updated.id ? updated : k).toList(),
    );
  }

  /// Get speed at a specific source time
  double speedAt(EditorTime sourceTime) {
    if (keyframes.isEmpty) return 1.0;

    final sorted = sortedKeyframes;

    // Before first keyframe
    if (sourceTime <= sorted.first.sourceTime) return sorted.first.speed;

    // After last keyframe
    if (sourceTime >= sorted.last.sourceTime) return sorted.last.speed;

    // Find surrounding keyframes
    for (int i = 0; i < sorted.length - 1; i++) {
      final kf1 = sorted[i];
      final kf2 = sorted[i + 1];

      if (sourceTime >= kf1.sourceTime && sourceTime <= kf2.sourceTime) {
        return _interpolateSpeed(kf1, kf2, sourceTime);
      }
    }

    return 1.0;
  }

  double _interpolateSpeed(
    SpeedKeyframe kf1,
    SpeedKeyframe kf2,
    EditorTime sourceTime,
  ) {
    final t1 = kf1.sourceTime.microseconds;
    final t2 = kf2.sourceTime.microseconds;
    final t = sourceTime.microseconds;

    if (t2 == t1) return kf1.speed;

    final progress = (t - t1) / (t2 - t1);

    switch (kf1.interpolation) {
      case KeyframeType.hold:
        return kf1.speed;
      case KeyframeType.linear:
        return kf1.speed + (kf2.speed - kf1.speed) * progress;
      case KeyframeType.bezier:
      case KeyframeType.easeInOut:
        final ease = progress < 0.5
            ? 2 * progress * progress
            : 1 - (-2 * progress + 2) * (-2 * progress + 2) / 2;
        return kf1.speed + (kf2.speed - kf1.speed) * ease;
      case KeyframeType.easeIn:
        return kf1.speed + (kf2.speed - kf1.speed) * (progress * progress);
      case KeyframeType.easeOut:
        return kf1.speed +
            (kf2.speed - kf1.speed) * (1 - (1 - progress) * (1 - progress));
    }
  }

  /// Calculate output duration based on speed changes
  EditorTime calculateOutputDuration(EditorTime sourceDuration) {
    if (!enabled || keyframes.isEmpty) return sourceDuration;

    // Integrate speed over source duration to get output duration
    double totalOutputTime = 0;
    const steps = 100;
    final stepSize = sourceDuration.microseconds / steps;

    for (int i = 0; i < steps; i++) {
      final sourceTime = EditorTime((i * stepSize).round());
      final speed = speedAt(sourceTime);
      if (speed > 0) {
        totalOutputTime += stepSize / speed;
      }
    }

    return EditorTime(totalOutputTime.round());
  }

  /// Generate FFmpeg setpts expression for speed ramping
  String toFfmpegSetpts() {
    if (!enabled || keyframes.isEmpty) {
      return 'PTS-STARTPTS';
    }

    final sorted = sortedKeyframes;

    // For simple constant speed, use simple expression
    if (sorted.length == 1) {
      return 'PTS/${sorted.first.speed}';
    }

    // For complex speed ramping, use expression with conditionals
    final parts = <String>[];

    for (int i = 0; i < sorted.length - 1; i++) {
      final kf1 = sorted[i];
      final kf2 = sorted[i + 1];

      final t1Sec = kf1.sourceTime.inSeconds;
      final t2Sec = kf2.sourceTime.inSeconds;

      if (kf1.interpolation == KeyframeType.hold ||
          kf1.interpolation == KeyframeType.linear) {
        // Linear interpolation
        final speedChange = (kf2.speed - kf1.speed) / (t2Sec - t1Sec);
        parts.add(
          "if(between(T,$t1Sec,$t2Sec),"
          "PTS/(${kf1.speed}+$speedChange*(T-$t1Sec)),"
        );
      } else {
        // Bezier/easing - approximate with linear
        parts.add(
          "if(between(T,$t1Sec,$t2Sec),"
          "PTS/${(kf1.speed + kf2.speed) / 2},"
        );
      }
    }

    // Add final speed
    final lastSpeed = sorted.last.speed;
    parts.add('PTS/$lastSpeed');

    // Close all conditionals
    parts.add(')' * (sorted.length - 1));

    return parts.join('');
  }

  /// Generate FFmpeg atempo filter chain for audio
  String toFfmpegAtempo() {
    if (!enabled || keyframes.isEmpty) return '';

    // FFmpeg atempo filter only supports 0.5 to 2.0
    // For speeds outside this range, chain multiple filters
    final avgSpeed = keyframes.map((k) => k.speed).reduce((a, b) => a + b) /
        keyframes.length;

    if (avgSpeed >= 0.5 && avgSpeed <= 2.0) {
      return 'atempo=$avgSpeed';
    }

    // Chain filters for extreme speeds
    final filters = <String>[];
    var remaining = avgSpeed;

    while (remaining > 2.0) {
      filters.add('atempo=2.0');
      remaining /= 2.0;
    }
    while (remaining < 0.5) {
      filters.add('atempo=0.5');
      remaining *= 2.0;
    }
    if (remaining != 1.0) {
      filters.add('atempo=$remaining');
    }

    return filters.join(',');
  }
}

/// Preset speed ramp curves
class SpeedRampPreset {
  final String id;
  final String name;
  final String category;
  final String description;
  final List<SpeedKeyframe> Function(EditorTime duration) createKeyframes;

  const SpeedRampPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.createKeyframes,
  });
}

/// Built-in speed ramp presets
class SpeedRampPresets {
  static final List<SpeedRampPreset> builtIn = [
    SpeedRampPreset(
      id: 'smooth_slow',
      name: 'Smooth Slow Motion',
      category: 'Slow Motion',
      description: 'Gradually slow down to 50% then back to normal',
      createKeyframes: (duration) {
        final quarter = EditorTime(duration.microseconds ~/ 4);
        final half = EditorTime(duration.microseconds ~/ 2);
        final threeQuarter = EditorTime((duration.microseconds * 3) ~/ 4);
        return [
          SpeedKeyframe.create(
            sourceTime: const EditorTime.zero(),
            outputTime: const EditorTime.zero(),
            speed: 1.0,
            interpolation: KeyframeType.easeOut,
          ),
          SpeedKeyframe.create(
            sourceTime: quarter,
            outputTime: quarter,
            speed: 0.5,
            interpolation: KeyframeType.linear,
          ),
          SpeedKeyframe.create(
            sourceTime: threeQuarter,
            outputTime: threeQuarter,
            speed: 0.5,
            interpolation: KeyframeType.easeIn,
          ),
          SpeedKeyframe.create(
            sourceTime: duration,
            outputTime: duration,
            speed: 1.0,
          ),
        ];
      },
    ),
    SpeedRampPreset(
      id: 'freeze_frame',
      name: 'Freeze Frame',
      category: 'Freeze',
      description: 'Pause in the middle then continue',
      createKeyframes: (duration) {
        final third = EditorTime(duration.microseconds ~/ 3);
        final twoThird = EditorTime((duration.microseconds * 2) ~/ 3);
        return [
          SpeedKeyframe.create(
            sourceTime: const EditorTime.zero(),
            outputTime: const EditorTime.zero(),
            speed: 1.0,
          ),
          SpeedKeyframe.create(
            sourceTime: third,
            outputTime: third,
            speed: 0.0,
            interpolation: KeyframeType.hold,
          ),
          SpeedKeyframe.create(
            sourceTime: twoThird,
            outputTime: twoThird,
            speed: 1.0,
          ),
        ];
      },
    ),
    SpeedRampPreset(
      id: 'speed_ramp_up',
      name: 'Speed Ramp Up',
      category: 'Speed Up',
      description: 'Gradually speed up to 4x',
      createKeyframes: (duration) {
        return [
          SpeedKeyframe.create(
            sourceTime: const EditorTime.zero(),
            outputTime: const EditorTime.zero(),
            speed: 1.0,
            interpolation: KeyframeType.easeIn,
          ),
          SpeedKeyframe.create(
            sourceTime: duration,
            outputTime: duration,
            speed: 4.0,
          ),
        ];
      },
    ),
  ];
}
