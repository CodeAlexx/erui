import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/speed_ramp_models.dart';
import '../models/keyframe_models.dart';
import '../services/speed_ramp_service.dart';

/// State for speed ramping
class SpeedRampState {
  /// Map of clip ID to time remap curve
  final Map<EditorId, TimeRemapCurve> curves;

  /// Currently selected keyframe ID
  final EditorId? selectedKeyframeId;

  /// Whether speed graph is expanded
  final bool graphExpanded;

  const SpeedRampState({
    this.curves = const {},
    this.selectedKeyframeId,
    this.graphExpanded = false,
  });

  SpeedRampState copyWith({
    Map<EditorId, TimeRemapCurve>? curves,
    EditorId? selectedKeyframeId,
    bool? graphExpanded,
  }) {
    return SpeedRampState(
      curves: curves ?? this.curves,
      selectedKeyframeId: selectedKeyframeId ?? this.selectedKeyframeId,
      graphExpanded: graphExpanded ?? this.graphExpanded,
    );
  }
}

/// Provider for speed ramp service
final speedRampServiceProvider = Provider<SpeedRampService>((ref) {
  return SpeedRampService();
});

/// Provider for speed ramp state
final speedRampProvider =
    StateNotifierProvider<SpeedRampNotifier, SpeedRampState>((ref) {
  final service = ref.watch(speedRampServiceProvider);
  return SpeedRampNotifier(service);
});

/// Notifier for speed ramp state
class SpeedRampNotifier extends StateNotifier<SpeedRampState> {
  final SpeedRampService _service;

  SpeedRampNotifier(this._service) : super(const SpeedRampState());

  /// Get curve for a clip
  TimeRemapCurve? getCurve(EditorId clipId) {
    return state.curves[clipId];
  }

  /// Create or get curve for clip
  TimeRemapCurve getOrCreateCurve(EditorId clipId) {
    if (state.curves.containsKey(clipId)) {
      return state.curves[clipId]!;
    }

    final curve = TimeRemapCurve(clipId: clipId);
    state = state.copyWith(
      curves: {...state.curves, clipId: curve},
    );
    return curve;
  }

  /// Set constant speed for clip
  void setConstantSpeed(EditorId clipId, double speed) {
    final curve = _service.createConstantSpeed(clipId, speed);
    state = state.copyWith(
      curves: {...state.curves, clipId: curve},
    );
  }

  /// Apply preset to clip
  void applyPreset(EditorId clipId, SpeedRampPreset preset, EditorTime duration) {
    final curve = _service.createFromPreset(clipId, preset, duration);
    state = state.copyWith(
      curves: {...state.curves, clipId: curve},
    );
  }

  /// Create smooth ramp
  void createSmoothRamp(
    EditorId clipId,
    EditorTime duration,
    double startSpeed,
    double endSpeed, {
    double rampStartPercent = 0.25,
    double rampEndPercent = 0.75,
  }) {
    final curve = _service.createSmoothRamp(
      clipId,
      duration,
      startSpeed,
      endSpeed,
      rampStartPercent: rampStartPercent,
      rampEndPercent: rampEndPercent,
    );
    state = state.copyWith(
      curves: {...state.curves, clipId: curve},
    );
  }

  /// Add keyframe to curve
  void addKeyframe(
    EditorId clipId,
    EditorTime time,
    double speed, {
    KeyframeType interpolation = KeyframeType.linear,
  }) {
    final curve = getOrCreateCurve(clipId);
    final keyframe = SpeedKeyframe.create(
      sourceTime: time,
      outputTime: time,
      speed: speed,
      interpolation: interpolation,
    );
    final updated = curve.addKeyframe(keyframe);
    state = state.copyWith(
      curves: {...state.curves, clipId: updated},
      selectedKeyframeId: keyframe.id,
    );
  }

  /// Update keyframe
  void updateKeyframe(EditorId clipId, SpeedKeyframe keyframe) {
    final curve = state.curves[clipId];
    if (curve == null) return;

    final updated = curve.updateKeyframe(keyframe);
    state = state.copyWith(
      curves: {...state.curves, clipId: updated},
    );
  }

  /// Remove keyframe
  void removeKeyframe(EditorId clipId, EditorId keyframeId) {
    final curve = state.curves[clipId];
    if (curve == null) return;

    final updated = curve.removeKeyframe(keyframeId);
    state = state.copyWith(
      curves: {...state.curves, clipId: updated},
      selectedKeyframeId:
          state.selectedKeyframeId == keyframeId ? null : state.selectedKeyframeId,
    );
  }

  /// Select keyframe
  void selectKeyframe(EditorId? keyframeId) {
    state = state.copyWith(selectedKeyframeId: keyframeId);
  }

  /// Enable/disable curve
  void setCurveEnabled(EditorId clipId, bool enabled) {
    final curve = state.curves[clipId];
    if (curve == null) return;

    state = state.copyWith(
      curves: {...state.curves, clipId: curve.copyWith(enabled: enabled)},
    );
  }

  /// Set maintain pitch option
  void setMaintainPitch(EditorId clipId, bool maintain) {
    final curve = state.curves[clipId];
    if (curve == null) return;

    state = state.copyWith(
      curves: {...state.curves, clipId: curve.copyWith(maintainPitch: maintain)},
    );
  }

  /// Set optical flow option
  void setOpticalFlow(EditorId clipId, bool enabled) {
    final curve = state.curves[clipId];
    if (curve == null) return;

    state = state.copyWith(
      curves: {...state.curves, clipId: curve.copyWith(opticalFlow: enabled)},
    );
  }

  /// Set motion blur amount
  void setMotionBlur(EditorId clipId, double amount) {
    final curve = state.curves[clipId];
    if (curve == null) return;

    state = state.copyWith(
      curves: {...state.curves, clipId: curve.copyWith(motionBlur: amount)},
    );
  }

  /// Toggle graph expanded
  void toggleGraphExpanded() {
    state = state.copyWith(graphExpanded: !state.graphExpanded);
  }

  /// Clear curve for clip
  void clearCurve(EditorId clipId) {
    final newCurves = Map<EditorId, TimeRemapCurve>.from(state.curves);
    newCurves.remove(clipId);
    state = state.copyWith(curves: newCurves);
  }

  /// Get speed at time for clip
  double getSpeedAt(EditorId clipId, EditorTime time) {
    final curve = state.curves[clipId];
    if (curve == null || !curve.enabled) return 1.0;
    return curve.speedAt(time);
  }

  /// Calculate output duration for clip
  EditorTime calculateOutputDuration(EditorId clipId, EditorTime sourceDuration) {
    final curve = state.curves[clipId];
    if (curve == null || !curve.enabled) return sourceDuration;
    return _service.calculateOutputDuration(curve, sourceDuration);
  }
}

/// Provider for curve of specific clip
final clipSpeedCurveProvider =
    Provider.family<TimeRemapCurve?, EditorId>((ref, clipId) {
  return ref.watch(speedRampProvider).curves[clipId];
});

/// Provider for whether clip has speed changes
final hasSpeedChangesProvider =
    Provider.family<bool, EditorId>((ref, clipId) {
  final curve = ref.watch(clipSpeedCurveProvider(clipId));
  return curve != null && curve.enabled && curve.keyframes.isNotEmpty;
});

/// Provider for speed ramp presets
final speedRampPresetsProvider = Provider<List<SpeedRampPreset>>((ref) {
  return SpeedRampPresets.builtIn;
});

/// Provider for graph data
final speedGraphDataProvider =
    Provider.family<List<SpeedGraphPoint>, (EditorId, EditorTime)>((ref, args) {
  final (clipId, duration) = args;
  final service = ref.watch(speedRampServiceProvider);
  final curve = ref.watch(clipSpeedCurveProvider(clipId));

  if (curve == null || !curve.enabled) {
    return [SpeedGraphPoint(const EditorTime.zero(), 1.0)];
  }

  return service.generateSpeedGraph(curve, duration);
});
