import 'dart:math';

import 'editor_models.dart';

/// Types of video effects
enum EffectType {
  /// Brightness adjustment (-100 to 100)
  brightness,

  /// Contrast adjustment (0 to 200, 100 = normal)
  contrast,

  /// Saturation adjustment (0 to 200, 100 = normal)
  saturation,

  /// Blur effect (0 to 100)
  blur,

  /// Sharpen effect (0 to 100)
  sharpen,

  /// Color correction (hue, brightness, saturation combined)
  colorCorrect,
}

/// A video effect applied to a clip
class VideoEffect {
  /// Unique identifier for this effect
  final EditorId id;

  /// Type of effect
  final EffectType type;

  /// Effect parameters (varies by type)
  final Map<String, double> parameters;

  /// Whether effect is currently enabled
  final bool enabled;

  /// Display name override (null uses default)
  final String? name;

  const VideoEffect({
    required this.id,
    required this.type,
    required this.parameters,
    this.enabled = true,
    this.name,
  });

  /// Create with default parameters for effect type
  factory VideoEffect.defaultFor(EffectType type, {EditorId? id}) {
    return VideoEffect(
      id: id ?? generateId(),
      type: type,
      parameters: _defaultParameters(type),
      enabled: true,
    );
  }

  static Map<String, double> _defaultParameters(EffectType type) {
    switch (type) {
      case EffectType.brightness:
        return {'value': 0.0}; // -100 to 100
      case EffectType.contrast:
        return {'value': 100.0}; // 0 to 200
      case EffectType.saturation:
        return {'value': 100.0}; // 0 to 200
      case EffectType.blur:
        return {'radius': 0.0}; // 0 to 100
      case EffectType.sharpen:
        return {'amount': 0.0}; // 0 to 100
      case EffectType.colorCorrect:
        return {
          'hue': 0.0, // -180 to 180
          'brightness': 0.0, // -100 to 100
          'saturation': 100.0, // 0 to 200
        };
    }
  }

  /// Get parameter names for this effect type
  static List<String> getParameterNames(EffectType type) {
    switch (type) {
      case EffectType.brightness:
        return ['value'];
      case EffectType.contrast:
        return ['value'];
      case EffectType.saturation:
        return ['value'];
      case EffectType.blur:
        return ['radius'];
      case EffectType.sharpen:
        return ['amount'];
      case EffectType.colorCorrect:
        return ['hue', 'brightness', 'saturation'];
    }
  }

  /// Get parameter range for UI sliders
  static ({double min, double max, double defaultVal}) getParameterRange(
    EffectType type,
    String paramName,
  ) {
    switch (type) {
      case EffectType.brightness:
        return (min: -100.0, max: 100.0, defaultVal: 0.0);
      case EffectType.contrast:
        return (min: 0.0, max: 200.0, defaultVal: 100.0);
      case EffectType.saturation:
        return (min: 0.0, max: 200.0, defaultVal: 100.0);
      case EffectType.blur:
        return (min: 0.0, max: 100.0, defaultVal: 0.0);
      case EffectType.sharpen:
        return (min: 0.0, max: 100.0, defaultVal: 0.0);
      case EffectType.colorCorrect:
        switch (paramName) {
          case 'hue':
            return (min: -180.0, max: 180.0, defaultVal: 0.0);
          case 'brightness':
            return (min: -100.0, max: 100.0, defaultVal: 0.0);
          case 'saturation':
            return (min: 0.0, max: 200.0, defaultVal: 100.0);
          default:
            return (min: 0.0, max: 100.0, defaultVal: 0.0);
        }
    }
  }

  /// Get display label for a parameter
  static String getParameterLabel(EffectType type, String paramName) {
    switch (type) {
      case EffectType.brightness:
        return 'Brightness';
      case EffectType.contrast:
        return 'Contrast';
      case EffectType.saturation:
        return 'Saturation';
      case EffectType.blur:
        return 'Blur Radius';
      case EffectType.sharpen:
        return 'Sharpen Amount';
      case EffectType.colorCorrect:
        switch (paramName) {
          case 'hue':
            return 'Hue';
          case 'brightness':
            return 'Brightness';
          case 'saturation':
            return 'Saturation';
          default:
            return paramName;
        }
    }
  }

  /// Create a copy with optional parameter overrides
  VideoEffect copyWith({
    EditorId? id,
    EffectType? type,
    Map<String, double>? parameters,
    bool? enabled,
    String? name,
  }) {
    return VideoEffect(
      id: id ?? this.id,
      type: type ?? this.type,
      parameters: parameters ?? Map.from(this.parameters),
      enabled: enabled ?? this.enabled,
      name: name ?? this.name,
    );
  }

  /// Update a single parameter value
  VideoEffect withParameter(String key, double value) {
    final newParams = Map<String, double>.from(parameters);
    newParams[key] = value;
    return copyWith(parameters: newParams);
  }

  /// Display name for UI
  String get displayName {
    if (name != null) return name!;
    switch (type) {
      case EffectType.brightness:
        return 'Brightness';
      case EffectType.contrast:
        return 'Contrast';
      case EffectType.saturation:
        return 'Saturation';
      case EffectType.blur:
        return 'Blur';
      case EffectType.sharpen:
        return 'Sharpen';
      case EffectType.colorCorrect:
        return 'Color Correction';
    }
  }

  /// Get icon name for this effect type
  String get iconName {
    switch (type) {
      case EffectType.brightness:
        return 'brightness_6';
      case EffectType.contrast:
        return 'contrast';
      case EffectType.saturation:
        return 'palette';
      case EffectType.blur:
        return 'blur_on';
      case EffectType.sharpen:
        return 'deblur';
      case EffectType.colorCorrect:
        return 'color_lens';
    }
  }

  /// Build FFmpeg filter string for this effect
  String toFFmpegFilter() {
    switch (type) {
      case EffectType.brightness:
        final val = (parameters['value'] ?? 0) / 100;
        return 'eq=brightness=$val';
      case EffectType.contrast:
        final val = (parameters['value'] ?? 100) / 100;
        return 'eq=contrast=$val';
      case EffectType.saturation:
        final val = (parameters['value'] ?? 100) / 100;
        return 'eq=saturation=$val';
      case EffectType.blur:
        final radius = (parameters['radius'] ?? 0).round();
        if (radius <= 0) return '';
        return 'boxblur=$radius:$radius';
      case EffectType.sharpen:
        final amount = (parameters['amount'] ?? 0) / 100;
        if (amount <= 0) return '';
        return 'unsharp=5:5:$amount:5:5:0';
      case EffectType.colorCorrect:
        final hue = parameters['hue'] ?? 0;
        final brightness = (parameters['brightness'] ?? 0) / 100;
        final saturation = (parameters['saturation'] ?? 100) / 100;
        return 'hue=h=$hue:s=$saturation:b=$brightness';
    }
  }

  /// Check if this effect has any non-default values
  bool get hasChanges {
    final defaults = _defaultParameters(type);
    for (final entry in parameters.entries) {
      final defaultVal = defaults[entry.key] ?? 0;
      if ((entry.value - defaultVal).abs() > 0.01) {
        return true;
      }
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoEffect &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'VideoEffect(id: $id, type: $type, enabled: $enabled)';
  }
}

/// Collection of effects applied to a clip
class ClipEffects {
  /// ID of the clip these effects are applied to
  final EditorId clipId;

  /// List of effects in application order
  final List<VideoEffect> effects;

  const ClipEffects({
    required this.clipId,
    this.effects = const [],
  });

  /// Create a copy with optional parameter overrides
  ClipEffects copyWith({
    EditorId? clipId,
    List<VideoEffect>? effects,
  }) {
    return ClipEffects(
      clipId: clipId ?? this.clipId,
      effects: effects ?? List.from(this.effects),
    );
  }

  /// Get all enabled effects
  List<VideoEffect> get enabledEffects =>
      effects.where((e) => e.enabled).toList();

  /// Add an effect to the list
  ClipEffects addEffect(VideoEffect effect) {
    return copyWith(effects: [...effects, effect]);
  }

  /// Remove an effect by ID
  ClipEffects removeEffect(EditorId effectId) {
    return copyWith(
      effects: effects.where((e) => e.id != effectId).toList(),
    );
  }

  /// Update an effect
  ClipEffects updateEffect(VideoEffect updatedEffect) {
    return copyWith(
      effects: effects.map((e) {
        return e.id == updatedEffect.id ? updatedEffect : e;
      }).toList(),
    );
  }

  /// Reorder effects
  ClipEffects reorderEffects(int oldIndex, int newIndex) {
    final newEffects = List<VideoEffect>.from(effects);
    final effect = newEffects.removeAt(oldIndex);
    newEffects.insert(newIndex, effect);
    return copyWith(effects: newEffects);
  }

  /// Build combined FFmpeg filter string
  String toFFmpegFilterChain() {
    final filters = enabledEffects
        .map((e) => e.toFFmpegFilter())
        .where((f) => f.isNotEmpty)
        .toList();
    return filters.join(',');
  }

  /// Check if any effects have changes
  bool get hasChanges => effects.any((e) => e.enabled && e.hasChanges);

  @override
  String toString() {
    return 'ClipEffects(clipId: $clipId, effects: ${effects.length})';
  }
}

/// Extension for EffectType utilities
extension EffectTypeExtension on EffectType {
  /// Get all available effect types
  static List<EffectType> get all => EffectType.values;

  /// Get display name for this type
  String get displayName {
    switch (this) {
      case EffectType.brightness:
        return 'Brightness';
      case EffectType.contrast:
        return 'Contrast';
      case EffectType.saturation:
        return 'Saturation';
      case EffectType.blur:
        return 'Blur';
      case EffectType.sharpen:
        return 'Sharpen';
      case EffectType.colorCorrect:
        return 'Color Correction';
    }
  }

  /// Get category for grouping in UI
  String get category {
    switch (this) {
      case EffectType.brightness:
      case EffectType.contrast:
      case EffectType.saturation:
      case EffectType.colorCorrect:
        return 'Color';
      case EffectType.blur:
      case EffectType.sharpen:
        return 'Stylize';
    }
  }
}
