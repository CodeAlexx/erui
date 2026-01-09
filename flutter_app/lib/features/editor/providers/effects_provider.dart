import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/effect_models.dart';

/// State containing all clip effects in the project
class EffectsState {
  /// Map of clip ID to their effects
  final Map<EditorId, ClipEffects> clipEffects;

  const EffectsState({
    this.clipEffects = const {},
  });

  EffectsState copyWith({
    Map<EditorId, ClipEffects>? clipEffects,
  }) {
    return EffectsState(
      clipEffects: clipEffects ?? Map.from(this.clipEffects),
    );
  }

  /// Get effects for a specific clip
  ClipEffects? getEffectsForClip(EditorId clipId) => clipEffects[clipId];

  /// Check if a clip has any effects
  bool hasEffects(EditorId clipId) {
    final effects = clipEffects[clipId];
    return effects != null && effects.effects.isNotEmpty;
  }

  /// Check if a clip has any enabled effects
  bool hasEnabledEffects(EditorId clipId) {
    final effects = clipEffects[clipId];
    return effects != null && effects.effects.any((e) => e.enabled);
  }
}

/// State notifier for managing video effects across all clips
class EffectsNotifier extends StateNotifier<EffectsState> {
  EffectsNotifier() : super(const EffectsState());

  /// Add an effect to a clip
  void addEffect(EditorId clipId, VideoEffect effect) {
    final currentEffects = state.clipEffects[clipId] ??
        ClipEffects(clipId: clipId);

    final updatedEffects = currentEffects.addEffect(effect);

    final newClipEffects = Map<EditorId, ClipEffects>.from(state.clipEffects);
    newClipEffects[clipId] = updatedEffects;

    state = state.copyWith(clipEffects: newClipEffects);
  }

  /// Remove an effect from a clip
  void removeEffect(EditorId clipId, EditorId effectId) {
    final currentEffects = state.clipEffects[clipId];
    if (currentEffects == null) return;

    final updatedEffects = currentEffects.removeEffect(effectId);

    final newClipEffects = Map<EditorId, ClipEffects>.from(state.clipEffects);

    if (updatedEffects.effects.isEmpty) {
      newClipEffects.remove(clipId);
    } else {
      newClipEffects[clipId] = updatedEffects;
    }

    state = state.copyWith(clipEffects: newClipEffects);
  }

  /// Update an effect's parameters
  void updateEffect(EditorId clipId, VideoEffect updatedEffect) {
    final currentEffects = state.clipEffects[clipId];
    if (currentEffects == null) return;

    final updatedEffects = currentEffects.updateEffect(updatedEffect);

    final newClipEffects = Map<EditorId, ClipEffects>.from(state.clipEffects);
    newClipEffects[clipId] = updatedEffects;

    state = state.copyWith(clipEffects: newClipEffects);
  }

  /// Toggle an effect's enabled state
  void toggleEffect(EditorId clipId, EditorId effectId) {
    final currentEffects = state.clipEffects[clipId];
    if (currentEffects == null) return;

    final effect = currentEffects.effects.firstWhere(
      (e) => e.id == effectId,
      orElse: () => throw StateError('Effect not found'),
    );

    updateEffect(clipId, effect.copyWith(enabled: !effect.enabled));
  }

  /// Reorder effects for a clip
  void reorderEffect(EditorId clipId, int oldIndex, int newIndex) {
    final currentEffects = state.clipEffects[clipId];
    if (currentEffects == null) return;

    final updatedEffects = currentEffects.reorderEffects(oldIndex, newIndex);

    final newClipEffects = Map<EditorId, ClipEffects>.from(state.clipEffects);
    newClipEffects[clipId] = updatedEffects;

    state = state.copyWith(clipEffects: newClipEffects);
  }

  /// Clear all effects for a clip
  void clearEffects(EditorId clipId) {
    final newClipEffects = Map<EditorId, ClipEffects>.from(state.clipEffects);
    newClipEffects.remove(clipId);

    state = state.copyWith(clipEffects: newClipEffects);
  }

  /// Copy effects from one clip to another
  void copyEffects(EditorId sourceClipId, EditorId targetClipId) {
    final sourceEffects = state.clipEffects[sourceClipId];
    if (sourceEffects == null) return;

    // Create new effect instances with new IDs
    final copiedEffects = sourceEffects.effects.map((effect) {
      return VideoEffect(
        id: generateId(),
        type: effect.type,
        parameters: Map.from(effect.parameters),
        enabled: effect.enabled,
        name: effect.name,
      );
    }).toList();

    final newClipEffects = Map<EditorId, ClipEffects>.from(state.clipEffects);
    newClipEffects[targetClipId] = ClipEffects(
      clipId: targetClipId,
      effects: copiedEffects,
    );

    state = state.copyWith(clipEffects: newClipEffects);
  }

  /// Reset all effects to default values for a clip
  void resetEffects(EditorId clipId) {
    final currentEffects = state.clipEffects[clipId];
    if (currentEffects == null) return;

    final resetEffects = currentEffects.effects.map((effect) {
      return VideoEffect.defaultFor(effect.type, id: effect.id);
    }).toList();

    final newClipEffects = Map<EditorId, ClipEffects>.from(state.clipEffects);
    newClipEffects[clipId] = ClipEffects(
      clipId: clipId,
      effects: resetEffects,
    );

    state = state.copyWith(clipEffects: newClipEffects);
  }

  /// Apply a preset (predefined set of effects) to a clip
  void applyPreset(EditorId clipId, EffectPreset preset) {
    final effects = preset.createEffects();

    final newClipEffects = Map<EditorId, ClipEffects>.from(state.clipEffects);
    newClipEffects[clipId] = ClipEffects(
      clipId: clipId,
      effects: effects,
    );

    state = state.copyWith(clipEffects: newClipEffects);
  }
}

/// Main provider for effects state
final effectsNotifierProvider =
    StateNotifierProvider<EffectsNotifier, EffectsState>(
  (ref) => EffectsNotifier(),
);

/// Provider for effects of a specific clip
final clipEffectsProvider = Provider.family<ClipEffects?, EditorId>(
  (ref, clipId) {
    final state = ref.watch(effectsNotifierProvider);
    return state.clipEffects[clipId];
  },
);

/// Provider to check if a clip has any effects
final hasEffectsProvider = Provider.family<bool, EditorId>(
  (ref, clipId) {
    final state = ref.watch(effectsNotifierProvider);
    return state.hasEffects(clipId);
  },
);

/// Provider to check if a clip has enabled effects
final hasEnabledEffectsProvider = Provider.family<bool, EditorId>(
  (ref, clipId) {
    final state = ref.watch(effectsNotifierProvider);
    return state.hasEnabledEffects(clipId);
  },
);

/// Predefined effect presets
enum EffectPreset {
  /// Warm, golden tones
  warm,

  /// Cool, blue tones
  cool,

  /// High contrast black and white
  blackAndWhite,

  /// Vintage film look
  vintage,

  /// Vibrant, saturated colors
  vibrant,

  /// Soft, dreamy look
  dreamy,
}

extension EffectPresetExtension on EffectPreset {
  String get displayName {
    switch (this) {
      case EffectPreset.warm:
        return 'Warm';
      case EffectPreset.cool:
        return 'Cool';
      case EffectPreset.blackAndWhite:
        return 'Black & White';
      case EffectPreset.vintage:
        return 'Vintage';
      case EffectPreset.vibrant:
        return 'Vibrant';
      case EffectPreset.dreamy:
        return 'Dreamy';
    }
  }

  List<VideoEffect> createEffects() {
    switch (this) {
      case EffectPreset.warm:
        return [
          VideoEffect(
            id: generateId(),
            type: EffectType.colorCorrect,
            parameters: {'hue': 15.0, 'brightness': 5.0, 'saturation': 110.0},
          ),
        ];
      case EffectPreset.cool:
        return [
          VideoEffect(
            id: generateId(),
            type: EffectType.colorCorrect,
            parameters: {'hue': -15.0, 'brightness': 0.0, 'saturation': 95.0},
          ),
        ];
      case EffectPreset.blackAndWhite:
        return [
          VideoEffect(
            id: generateId(),
            type: EffectType.saturation,
            parameters: {'value': 0.0},
          ),
          VideoEffect(
            id: generateId(),
            type: EffectType.contrast,
            parameters: {'value': 120.0},
          ),
        ];
      case EffectPreset.vintage:
        return [
          VideoEffect(
            id: generateId(),
            type: EffectType.saturation,
            parameters: {'value': 80.0},
          ),
          VideoEffect(
            id: generateId(),
            type: EffectType.contrast,
            parameters: {'value': 90.0},
          ),
          VideoEffect(
            id: generateId(),
            type: EffectType.colorCorrect,
            parameters: {'hue': 10.0, 'brightness': -5.0, 'saturation': 90.0},
          ),
        ];
      case EffectPreset.vibrant:
        return [
          VideoEffect(
            id: generateId(),
            type: EffectType.saturation,
            parameters: {'value': 150.0},
          ),
          VideoEffect(
            id: generateId(),
            type: EffectType.contrast,
            parameters: {'value': 110.0},
          ),
        ];
      case EffectPreset.dreamy:
        return [
          VideoEffect(
            id: generateId(),
            type: EffectType.blur,
            parameters: {'radius': 5.0},
          ),
          VideoEffect(
            id: generateId(),
            type: EffectType.brightness,
            parameters: {'value': 10.0},
          ),
          VideoEffect(
            id: generateId(),
            type: EffectType.saturation,
            parameters: {'value': 90.0},
          ),
        ];
    }
  }
}
