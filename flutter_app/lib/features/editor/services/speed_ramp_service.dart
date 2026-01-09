import 'dart:async';
import 'dart:math' as math;

import '../models/editor_models.dart';
import '../models/speed_ramp_models.dart';
import '../models/keyframe_models.dart';
import 'ffmpeg_service.dart';

/// Service for applying speed ramping/time remapping
class SpeedRampService {
  final FFmpegService _ffmpeg;

  SpeedRampService({FFmpegService? ffmpeg}) : _ffmpeg = ffmpeg ?? FFmpegService();

  /// Apply speed ramp to a video file
  Future<String> applySpeedRamp(
    String inputPath,
    String outputPath,
    TimeRemapCurve curve, {
    Function(double progress)? onProgress,
  }) async {
    if (!curve.enabled || curve.keyframes.isEmpty) {
      // No speed changes - just copy
      await _ffmpeg.executeCommand([
        '-i', inputPath,
        '-c', 'copy',
        '-y',
        outputPath,
      ]);
      return outputPath;
    }

    // Build filter chain
    final videoFilter = curve.toFfmpegSetpts();
    final audioFilter = curve.toFfmpegAtempo();

    final command = <String>[
      '-i', inputPath,
      '-vf', videoFilter,
    ];

    // Add audio filter if present
    if (audioFilter.isNotEmpty) {
      if (curve.maintainPitch) {
        // Use rubberband for pitch correction
        command.addAll(['-af', 'rubberband=pitch=$audioFilter']);
      } else {
        command.addAll(['-af', audioFilter]);
      }
    } else {
      // Drop audio if no speed filter
      command.addAll(['-an']);
    }

    // Add motion blur if enabled
    if (curve.motionBlur > 0) {
      final blurStrength = (curve.motionBlur * 0.1).toStringAsFixed(2);
      command[command.indexOf('-vf') + 1] += ',minterpolate=fps=60:mi_mode=blend:mc_mode=aobmc:vsbmc=1:scd=none,tmix=frames=5:weights=$blurStrength';
    }

    // Add optical flow for slow motion
    if (curve.opticalFlow) {
      final hasSlowMo = curve.keyframes.any((k) => k.speed < 1.0);
      if (hasSlowMo) {
        command[command.indexOf('-vf') + 1] += ',minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1';
      }
    }

    command.addAll(['-y', outputPath]);

    await _ffmpeg.executeCommand(command, onProgress: onProgress);
    return outputPath;
  }

  /// Generate preview with speed ramp at specific frame
  Future<String> generateSpeedPreview(
    String inputPath,
    String outputPath,
    TimeRemapCurve curve,
    EditorTime previewTime,
  ) async {
    // Calculate what source frame corresponds to the preview time
    final sourceTime = curve.enabled
        ? _calculateSourceTime(curve, previewTime)
        : previewTime;

    final command = [
      '-ss', sourceTime.inSeconds.toString(),
      '-i', inputPath,
      '-frames:v', '1',
      '-y',
      outputPath,
    ];

    await _ffmpeg.executeCommand(command);
    return outputPath;
  }

  /// Calculate source time from output time given speed curve
  EditorTime _calculateSourceTime(TimeRemapCurve curve, EditorTime outputTime) {
    if (curve.keyframes.isEmpty) return outputTime;

    final sorted = curve.sortedKeyframes;

    // Simple linear search through keyframes
    for (int i = 0; i < sorted.length - 1; i++) {
      final kf1 = sorted[i];
      final kf2 = sorted[i + 1];

      if (outputTime >= kf1.outputTime && outputTime <= kf2.outputTime) {
        // Interpolate source time based on output time position
        final outputProgress = (outputTime.microseconds - kf1.outputTime.microseconds) /
            (kf2.outputTime.microseconds - kf1.outputTime.microseconds);

        final sourceProgress = outputProgress; // Simplified - would need integral for accurate mapping
        final sourceTime = kf1.sourceTime.microseconds +
            (kf2.sourceTime.microseconds - kf1.sourceTime.microseconds) * sourceProgress;

        return EditorTime(sourceTime.round());
      }
    }

    return outputTime;
  }

  /// Create a constant speed change
  TimeRemapCurve createConstantSpeed(EditorId clipId, double speed) {
    return TimeRemapCurve(
      clipId: clipId,
      enabled: speed != 1.0,
      keyframes: [
        SpeedKeyframe.create(
          sourceTime: const EditorTime.zero(),
          outputTime: const EditorTime.zero(),
          speed: speed,
        ),
      ],
    );
  }

  /// Create speed ramp from preset
  TimeRemapCurve createFromPreset(
    EditorId clipId,
    SpeedRampPreset preset,
    EditorTime duration,
  ) {
    return TimeRemapCurve(
      clipId: clipId,
      enabled: true,
      keyframes: preset.createKeyframes(duration),
    );
  }

  /// Generate smooth bezier speed ramp between two speeds
  TimeRemapCurve createSmoothRamp(
    EditorId clipId,
    EditorTime duration,
    double startSpeed,
    double endSpeed, {
    double rampStartPercent = 0.25,
    double rampEndPercent = 0.75,
  }) {
    final rampStart = EditorTime((duration.microseconds * rampStartPercent).round());
    final rampEnd = EditorTime((duration.microseconds * rampEndPercent).round());

    return TimeRemapCurve(
      clipId: clipId,
      enabled: true,
      keyframes: [
        SpeedKeyframe.create(
          sourceTime: const EditorTime.zero(),
          outputTime: const EditorTime.zero(),
          speed: startSpeed,
          interpolation: KeyframeType.linear,
        ),
        SpeedKeyframe.create(
          sourceTime: rampStart,
          outputTime: rampStart,
          speed: startSpeed,
          interpolation: KeyframeType.bezier,
        ),
        SpeedKeyframe.create(
          sourceTime: rampEnd,
          outputTime: rampEnd,
          speed: endSpeed,
          interpolation: KeyframeType.bezier,
        ),
        SpeedKeyframe.create(
          sourceTime: duration,
          outputTime: duration,
          speed: endSpeed,
        ),
      ],
    );
  }

  /// Calculate the actual output duration after speed changes
  EditorTime calculateOutputDuration(TimeRemapCurve curve, EditorTime sourceDuration) {
    return curve.calculateOutputDuration(sourceDuration);
  }

  /// Generate speed graph data for visualization
  List<SpeedGraphPoint> generateSpeedGraph(
    TimeRemapCurve curve,
    EditorTime duration, {
    int samples = 100,
  }) {
    final points = <SpeedGraphPoint>[];
    final stepSize = duration.microseconds / samples;

    for (int i = 0; i <= samples; i++) {
      final sourceTime = EditorTime((i * stepSize).round());
      final speed = curve.speedAt(sourceTime);
      points.add(SpeedGraphPoint(sourceTime, speed));
    }

    return points;
  }
}

/// Data point for speed graph visualization
class SpeedGraphPoint {
  final EditorTime time;
  final double speed;

  const SpeedGraphPoint(this.time, this.speed);
}

/// Builder for creating complex speed ramp curves
class SpeedRampBuilder {
  final EditorId _clipId;
  final List<SpeedKeyframe> _keyframes = [];
  bool _maintainPitch = true;
  double _motionBlur = 0.0;
  bool _opticalFlow = false;

  SpeedRampBuilder(this._clipId);

  /// Add a keyframe
  SpeedRampBuilder addKeyframe({
    required EditorTime time,
    required double speed,
    KeyframeType interpolation = KeyframeType.linear,
  }) {
    _keyframes.add(SpeedKeyframe.create(
      sourceTime: time,
      outputTime: time, // Will be recalculated
      speed: speed,
      interpolation: interpolation,
    ));
    return this;
  }

  /// Add a hold section (constant speed)
  SpeedRampBuilder addHold({
    required EditorTime startTime,
    required EditorTime endTime,
    required double speed,
  }) {
    _keyframes.addAll([
      SpeedKeyframe.create(
        sourceTime: startTime,
        outputTime: startTime,
        speed: speed,
        interpolation: KeyframeType.hold,
      ),
      SpeedKeyframe.create(
        sourceTime: endTime,
        outputTime: endTime,
        speed: speed,
      ),
    ]);
    return this;
  }

  /// Add a smooth ramp between two speeds
  SpeedRampBuilder addRamp({
    required EditorTime startTime,
    required EditorTime endTime,
    required double startSpeed,
    required double endSpeed,
  }) {
    _keyframes.addAll([
      SpeedKeyframe.create(
        sourceTime: startTime,
        outputTime: startTime,
        speed: startSpeed,
        interpolation: KeyframeType.bezier,
      ),
      SpeedKeyframe.create(
        sourceTime: endTime,
        outputTime: endTime,
        speed: endSpeed,
      ),
    ]);
    return this;
  }

  /// Set whether to maintain audio pitch
  SpeedRampBuilder maintainPitch(bool value) {
    _maintainPitch = value;
    return this;
  }

  /// Set motion blur amount (0-1)
  SpeedRampBuilder motionBlur(double amount) {
    _motionBlur = amount.clamp(0.0, 1.0);
    return this;
  }

  /// Enable optical flow interpolation
  SpeedRampBuilder opticalFlow(bool value) {
    _opticalFlow = value;
    return this;
  }

  /// Build the time remap curve
  TimeRemapCurve build() {
    // Sort keyframes by time
    _keyframes.sort((a, b) => a.sourceTime.microseconds.compareTo(b.sourceTime.microseconds));

    return TimeRemapCurve(
      clipId: _clipId,
      enabled: _keyframes.isNotEmpty,
      keyframes: _keyframes,
      maintainPitch: _maintainPitch,
      motionBlur: _motionBlur,
      opticalFlow: _opticalFlow,
    );
  }
}
