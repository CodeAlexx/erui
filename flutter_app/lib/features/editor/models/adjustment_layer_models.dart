import 'dart:ui';
import 'editor_models.dart';
import 'effect_models.dart';

/// Adjustment layer that applies effects to all clips below it
class AdjustmentLayer extends EditorClip {
  /// Effects applied by this adjustment layer
  final List<VideoEffect> effects;

  /// Mask for selective adjustment (null = affects full frame)
  final AdjustmentMask? mask;

  /// Blend mode with clips below
  final AdjustmentBlendMode blendMode;

  /// Whether effects are enabled
  final bool effectsEnabled;

  AdjustmentLayer({
    super.id,
    required String name,
    required super.timelineStart,
    required super.duration,
    this.effects = const [],
    this.mask,
    this.blendMode = AdjustmentBlendMode.normal,
    this.effectsEnabled = true,
    super.trackIndex = 0,
    super.isSelected = false,
    super.isLocked = false,
    super.opacity = 1.0,
  }) : super(
          type: ClipType.effect,
          name: name,
          color: const Color(0xFFFF9800),
        );

  @override
  AdjustmentLayer copyWith({
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
    List<VideoEffect>? effects,
    AdjustmentMask? mask,
    AdjustmentBlendMode? blendMode,
    bool? effectsEnabled,
  }) {
    return AdjustmentLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      timelineStart: timelineStart ?? this.timelineStart,
      duration: duration ?? this.duration,
      effects: effects ?? List.from(this.effects),
      mask: mask ?? this.mask,
      blendMode: blendMode ?? this.blendMode,
      effectsEnabled: effectsEnabled ?? this.effectsEnabled,
      trackIndex: trackIndex ?? this.trackIndex,
      isSelected: isSelected ?? this.isSelected,
      isLocked: isLocked ?? this.isLocked,
      opacity: opacity ?? this.opacity,
    );
  }

  /// Add an effect to this adjustment layer
  AdjustmentLayer addEffect(VideoEffect effect) {
    return copyWith(effects: [...effects, effect]);
  }

  /// Remove an effect by ID
  AdjustmentLayer removeEffect(String effectId) {
    return copyWith(
      effects: effects.where((e) => e.id != effectId).toList(),
    );
  }

  /// Update an effect
  AdjustmentLayer updateEffect(VideoEffect effect) {
    return copyWith(
      effects: effects.map((e) => e.id == effect.id ? effect : e).toList(),
    );
  }

  /// Reorder effects
  AdjustmentLayer reorderEffects(int oldIndex, int newIndex) {
    final newEffects = List<VideoEffect>.from(effects);
    final effect = newEffects.removeAt(oldIndex);
    newEffects.insert(newIndex, effect);
    return copyWith(effects: newEffects);
  }

  /// Generate FFmpeg filter chain for this adjustment layer
  String toFFmpegFilterChain() {
    if (!effectsEnabled || effects.isEmpty) return '';

    final filters = effects
        .where((e) => e.enabled)
        .map((e) => e.toFFmpegFilter())
        .where((f) => f.isNotEmpty)
        .toList();

    if (filters.isEmpty) return '';

    String chain = filters.join(',');

    // Apply blend mode
    if (blendMode != AdjustmentBlendMode.normal) {
      chain = '[$chain]blend=all_mode=${blendMode.ffmpegName}';
    }

    // Apply opacity
    if (opacity < 1.0) {
      chain = '$chain,format=rgba,colorchannelmixer=aa=${opacity}';
    }

    return chain;
  }
}

/// Blend modes for adjustment layers
enum AdjustmentBlendMode {
  normal,
  multiply,
  screen,
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
  add,
  subtract,
}

extension AdjustmentBlendModeExtension on AdjustmentBlendMode {
  String get displayName {
    switch (this) {
      case AdjustmentBlendMode.normal:
        return 'Normal';
      case AdjustmentBlendMode.multiply:
        return 'Multiply';
      case AdjustmentBlendMode.screen:
        return 'Screen';
      case AdjustmentBlendMode.overlay:
        return 'Overlay';
      case AdjustmentBlendMode.darken:
        return 'Darken';
      case AdjustmentBlendMode.lighten:
        return 'Lighten';
      case AdjustmentBlendMode.colorDodge:
        return 'Color Dodge';
      case AdjustmentBlendMode.colorBurn:
        return 'Color Burn';
      case AdjustmentBlendMode.hardLight:
        return 'Hard Light';
      case AdjustmentBlendMode.softLight:
        return 'Soft Light';
      case AdjustmentBlendMode.difference:
        return 'Difference';
      case AdjustmentBlendMode.exclusion:
        return 'Exclusion';
      case AdjustmentBlendMode.add:
        return 'Add';
      case AdjustmentBlendMode.subtract:
        return 'Subtract';
    }
  }

  String get ffmpegName {
    switch (this) {
      case AdjustmentBlendMode.normal:
        return 'normal';
      case AdjustmentBlendMode.multiply:
        return 'multiply';
      case AdjustmentBlendMode.screen:
        return 'screen';
      case AdjustmentBlendMode.overlay:
        return 'overlay';
      case AdjustmentBlendMode.darken:
        return 'darken';
      case AdjustmentBlendMode.lighten:
        return 'lighten';
      case AdjustmentBlendMode.colorDodge:
        return 'dodge';
      case AdjustmentBlendMode.colorBurn:
        return 'burn';
      case AdjustmentBlendMode.hardLight:
        return 'hardlight';
      case AdjustmentBlendMode.softLight:
        return 'softlight';
      case AdjustmentBlendMode.difference:
        return 'difference';
      case AdjustmentBlendMode.exclusion:
        return 'exclusion';
      case AdjustmentBlendMode.add:
        return 'addition';
      case AdjustmentBlendMode.subtract:
        return 'subtract';
    }
  }
}

/// Mask for adjustment layer
class AdjustmentMask {
  final AdjustmentMaskType type;

  /// Mask shape parameters (interpretation depends on type)
  final Map<String, double> parameters;

  /// Feather amount (0-100)
  final double feather;

  /// Invert the mask
  final bool inverted;

  /// Mask expansion/contraction (-100 to 100)
  final double expansion;

  const AdjustmentMask({
    this.type = AdjustmentMaskType.rectangle,
    this.parameters = const {},
    this.feather = 0.0,
    this.inverted = false,
    this.expansion = 0.0,
  });

  AdjustmentMask copyWith({
    AdjustmentMaskType? type,
    Map<String, double>? parameters,
    double? feather,
    bool? inverted,
    double? expansion,
  }) {
    return AdjustmentMask(
      type: type ?? this.type,
      parameters: parameters ?? Map.from(this.parameters),
      feather: feather ?? this.feather,
      inverted: inverted ?? this.inverted,
      expansion: expansion ?? this.expansion,
    );
  }

  /// Create rectangle mask
  factory AdjustmentMask.rectangle({
    required double x,
    required double y,
    required double width,
    required double height,
    double feather = 0.0,
    bool inverted = false,
  }) {
    return AdjustmentMask(
      type: AdjustmentMaskType.rectangle,
      parameters: {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      },
      feather: feather,
      inverted: inverted,
    );
  }

  /// Create ellipse mask
  factory AdjustmentMask.ellipse({
    required double centerX,
    required double centerY,
    required double radiusX,
    required double radiusY,
    double feather = 0.0,
    bool inverted = false,
  }) {
    return AdjustmentMask(
      type: AdjustmentMaskType.ellipse,
      parameters: {
        'centerX': centerX,
        'centerY': centerY,
        'radiusX': radiusX,
        'radiusY': radiusY,
      },
      feather: feather,
      inverted: inverted,
    );
  }

  /// Create linear gradient mask
  factory AdjustmentMask.linearGradient({
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    double feather = 0.0,
    bool inverted = false,
  }) {
    return AdjustmentMask(
      type: AdjustmentMaskType.linearGradient,
      parameters: {
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
      },
      feather: feather,
      inverted: inverted,
    );
  }
}

/// Types of adjustment masks
enum AdjustmentMaskType {
  rectangle,
  ellipse,
  linearGradient,
  radialGradient,
  bezierPath,
  luminosity,
}

extension AdjustmentMaskTypeExtension on AdjustmentMaskType {
  String get displayName {
    switch (this) {
      case AdjustmentMaskType.rectangle:
        return 'Rectangle';
      case AdjustmentMaskType.ellipse:
        return 'Ellipse';
      case AdjustmentMaskType.linearGradient:
        return 'Linear Gradient';
      case AdjustmentMaskType.radialGradient:
        return 'Radial Gradient';
      case AdjustmentMaskType.bezierPath:
        return 'Bezier Path';
      case AdjustmentMaskType.luminosity:
        return 'Luminosity';
    }
  }
}

/// Preset adjustment layers
class AdjustmentLayerPreset {
  final String id;
  final String name;
  final String category;
  final String description;
  final List<VideoEffect> effects;

  const AdjustmentLayerPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.effects,
  });

  /// Create an adjustment layer from this preset
  AdjustmentLayer createLayer({
    required EditorTime timelineStart,
    required EditorTime duration,
  }) {
    return AdjustmentLayer(
      name: name,
      timelineStart: timelineStart,
      duration: duration,
      effects: effects,
    );
  }
}
