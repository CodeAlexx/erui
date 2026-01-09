import 'dart:ui' as ui;

/// Blend modes for video clips with FFmpeg filter mappings
enum VideoBlendMode {
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
  divide,
  average,
  negation,
  phoenix,
  reflect,
  glow,
  freeze,
  heat,
  linearLight,
  vividLight,
  pinLight,
  hardMix,
}

extension VideoBlendModeExtension on VideoBlendMode {
  String get displayName {
    switch (this) {
      case VideoBlendMode.normal:
        return 'Normal';
      case VideoBlendMode.multiply:
        return 'Multiply';
      case VideoBlendMode.screen:
        return 'Screen';
      case VideoBlendMode.overlay:
        return 'Overlay';
      case VideoBlendMode.darken:
        return 'Darken';
      case VideoBlendMode.lighten:
        return 'Lighten';
      case VideoBlendMode.colorDodge:
        return 'Color Dodge';
      case VideoBlendMode.colorBurn:
        return 'Color Burn';
      case VideoBlendMode.hardLight:
        return 'Hard Light';
      case VideoBlendMode.softLight:
        return 'Soft Light';
      case VideoBlendMode.difference:
        return 'Difference';
      case VideoBlendMode.exclusion:
        return 'Exclusion';
      case VideoBlendMode.add:
        return 'Add';
      case VideoBlendMode.subtract:
        return 'Subtract';
      case VideoBlendMode.divide:
        return 'Divide';
      case VideoBlendMode.average:
        return 'Average';
      case VideoBlendMode.negation:
        return 'Negation';
      case VideoBlendMode.phoenix:
        return 'Phoenix';
      case VideoBlendMode.reflect:
        return 'Reflect';
      case VideoBlendMode.glow:
        return 'Glow';
      case VideoBlendMode.freeze:
        return 'Freeze';
      case VideoBlendMode.heat:
        return 'Heat';
      case VideoBlendMode.linearLight:
        return 'Linear Light';
      case VideoBlendMode.vividLight:
        return 'Vivid Light';
      case VideoBlendMode.pinLight:
        return 'Pin Light';
      case VideoBlendMode.hardMix:
        return 'Hard Mix';
    }
  }

  String get category {
    switch (this) {
      case VideoBlendMode.normal:
        return 'Basic';
      case VideoBlendMode.multiply:
      case VideoBlendMode.darken:
      case VideoBlendMode.colorBurn:
        return 'Darken';
      case VideoBlendMode.screen:
      case VideoBlendMode.lighten:
      case VideoBlendMode.colorDodge:
        return 'Lighten';
      case VideoBlendMode.overlay:
      case VideoBlendMode.hardLight:
      case VideoBlendMode.softLight:
      case VideoBlendMode.vividLight:
      case VideoBlendMode.linearLight:
      case VideoBlendMode.pinLight:
      case VideoBlendMode.hardMix:
        return 'Contrast';
      case VideoBlendMode.difference:
      case VideoBlendMode.exclusion:
      case VideoBlendMode.subtract:
      case VideoBlendMode.divide:
      case VideoBlendMode.negation:
        return 'Inversion';
      case VideoBlendMode.add:
      case VideoBlendMode.average:
        return 'Component';
      case VideoBlendMode.phoenix:
      case VideoBlendMode.reflect:
      case VideoBlendMode.glow:
      case VideoBlendMode.freeze:
      case VideoBlendMode.heat:
        return 'Stylize';
    }
  }

  /// FFmpeg blend filter name
  String get ffmpegName {
    switch (this) {
      case VideoBlendMode.normal:
        return 'normal';
      case VideoBlendMode.multiply:
        return 'multiply';
      case VideoBlendMode.screen:
        return 'screen';
      case VideoBlendMode.overlay:
        return 'overlay';
      case VideoBlendMode.darken:
        return 'darken';
      case VideoBlendMode.lighten:
        return 'lighten';
      case VideoBlendMode.colorDodge:
        return 'dodge';
      case VideoBlendMode.colorBurn:
        return 'burn';
      case VideoBlendMode.hardLight:
        return 'hardlight';
      case VideoBlendMode.softLight:
        return 'softlight';
      case VideoBlendMode.difference:
        return 'difference';
      case VideoBlendMode.exclusion:
        return 'exclusion';
      case VideoBlendMode.add:
        return 'addition';
      case VideoBlendMode.subtract:
        return 'subtract';
      case VideoBlendMode.divide:
        return 'divide';
      case VideoBlendMode.average:
        return 'average';
      case VideoBlendMode.negation:
        return 'negation';
      case VideoBlendMode.phoenix:
        return 'phoenix';
      case VideoBlendMode.reflect:
        return 'reflect';
      case VideoBlendMode.glow:
        return 'glow';
      case VideoBlendMode.freeze:
        return 'freeze';
      case VideoBlendMode.heat:
        return 'heat';
      case VideoBlendMode.linearLight:
        return 'linearlight';
      case VideoBlendMode.vividLight:
        return 'vividlight';
      case VideoBlendMode.pinLight:
        return 'pinlight';
      case VideoBlendMode.hardMix:
        return 'hardmix';
    }
  }

  /// Convert to Flutter BlendMode (for preview)
  ui.BlendMode? get flutterBlendMode {
    switch (this) {
      case VideoBlendMode.normal:
        return null;
      case VideoBlendMode.multiply:
        return ui.BlendMode.multiply;
      case VideoBlendMode.screen:
        return ui.BlendMode.screen;
      case VideoBlendMode.overlay:
        return ui.BlendMode.overlay;
      case VideoBlendMode.darken:
        return ui.BlendMode.darken;
      case VideoBlendMode.lighten:
        return ui.BlendMode.lighten;
      case VideoBlendMode.colorDodge:
        return ui.BlendMode.colorDodge;
      case VideoBlendMode.colorBurn:
        return ui.BlendMode.colorBurn;
      case VideoBlendMode.hardLight:
        return ui.BlendMode.hardLight;
      case VideoBlendMode.softLight:
        return ui.BlendMode.softLight;
      case VideoBlendMode.difference:
        return ui.BlendMode.difference;
      case VideoBlendMode.exclusion:
        return ui.BlendMode.exclusion;
      case VideoBlendMode.add:
        return ui.BlendMode.plus;
      default:
        return null; // Not directly supported in Flutter
    }
  }

  /// Description of what this blend mode does
  String get description {
    switch (this) {
      case VideoBlendMode.normal:
        return 'No blending, shows top layer only';
      case VideoBlendMode.multiply:
        return 'Darkens by multiplying colors';
      case VideoBlendMode.screen:
        return 'Lightens by inverting, multiplying, and inverting again';
      case VideoBlendMode.overlay:
        return 'Combines multiply and screen';
      case VideoBlendMode.darken:
        return 'Keeps darker pixels from each layer';
      case VideoBlendMode.lighten:
        return 'Keeps lighter pixels from each layer';
      case VideoBlendMode.colorDodge:
        return 'Brightens base to reflect blend color';
      case VideoBlendMode.colorBurn:
        return 'Darkens base to reflect blend color';
      case VideoBlendMode.hardLight:
        return 'Multiply or screen based on blend color';
      case VideoBlendMode.softLight:
        return 'Dodge or burn based on blend color';
      case VideoBlendMode.difference:
        return 'Subtracts darker from lighter';
      case VideoBlendMode.exclusion:
        return 'Similar to difference but lower contrast';
      case VideoBlendMode.add:
        return 'Adds colors together';
      case VideoBlendMode.subtract:
        return 'Subtracts blend from base';
      case VideoBlendMode.divide:
        return 'Divides base by blend';
      case VideoBlendMode.average:
        return 'Averages the two layers';
      case VideoBlendMode.negation:
        return 'Inverts difference';
      case VideoBlendMode.phoenix:
        return 'Creates ethereal effect';
      case VideoBlendMode.reflect:
        return 'Creates reflected light effect';
      case VideoBlendMode.glow:
        return 'Creates glowing effect';
      case VideoBlendMode.freeze:
        return 'Creates frozen/cold effect';
      case VideoBlendMode.heat:
        return 'Creates heated/warm effect';
      case VideoBlendMode.linearLight:
        return 'Linear dodge or burn';
      case VideoBlendMode.vividLight:
        return 'Color dodge or burn';
      case VideoBlendMode.pinLight:
        return 'Replaces colors based on blend';
      case VideoBlendMode.hardMix:
        return 'Adds channels and thresholds';
    }
  }
}

/// Blend mode categories for UI organization
class BlendModeCategory {
  final String name;
  final List<VideoBlendMode> modes;

  const BlendModeCategory(this.name, this.modes);

  static const List<BlendModeCategory> all = [
    BlendModeCategory('Basic', [VideoBlendMode.normal]),
    BlendModeCategory('Darken', [
      VideoBlendMode.multiply,
      VideoBlendMode.darken,
      VideoBlendMode.colorBurn,
    ]),
    BlendModeCategory('Lighten', [
      VideoBlendMode.screen,
      VideoBlendMode.lighten,
      VideoBlendMode.colorDodge,
      VideoBlendMode.add,
    ]),
    BlendModeCategory('Contrast', [
      VideoBlendMode.overlay,
      VideoBlendMode.hardLight,
      VideoBlendMode.softLight,
      VideoBlendMode.vividLight,
      VideoBlendMode.linearLight,
      VideoBlendMode.pinLight,
      VideoBlendMode.hardMix,
    ]),
    BlendModeCategory('Inversion', [
      VideoBlendMode.difference,
      VideoBlendMode.exclusion,
      VideoBlendMode.subtract,
      VideoBlendMode.divide,
      VideoBlendMode.negation,
    ]),
    BlendModeCategory('Component', [
      VideoBlendMode.average,
    ]),
    BlendModeCategory('Stylize', [
      VideoBlendMode.phoenix,
      VideoBlendMode.reflect,
      VideoBlendMode.glow,
      VideoBlendMode.freeze,
      VideoBlendMode.heat,
    ]),
  ];
}

/// Blend settings for a clip
class ClipBlendSettings {
  /// Blend mode
  final VideoBlendMode mode;

  /// Blend opacity (0-1)
  final double opacity;

  /// Whether blend is enabled
  final bool enabled;

  const ClipBlendSettings({
    this.mode = VideoBlendMode.normal,
    this.opacity = 1.0,
    this.enabled = true,
  });

  ClipBlendSettings copyWith({
    VideoBlendMode? mode,
    double? opacity,
    bool? enabled,
  }) {
    return ClipBlendSettings(
      mode: mode ?? this.mode,
      opacity: opacity ?? this.opacity,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Generate FFmpeg blend filter
  String toFfmpegFilter() {
    if (!enabled || mode == VideoBlendMode.normal) return '';

    String filter = 'blend=all_mode=${mode.ffmpegName}';

    if (opacity < 1.0) {
      filter += ':all_opacity=$opacity';
    }

    return filter;
  }

  /// Check if this has any effect
  bool get hasEffect => enabled && mode != VideoBlendMode.normal;
}

/// Preset blend configurations
class BlendPreset {
  final String id;
  final String name;
  final String description;
  final ClipBlendSettings settings;

  const BlendPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.settings,
  });

  static const List<BlendPreset> presets = [
    BlendPreset(
      id: 'film_burn',
      name: 'Film Burn',
      description: 'Classic film burn effect',
      settings: ClipBlendSettings(
        mode: VideoBlendMode.screen,
        opacity: 0.6,
      ),
    ),
    BlendPreset(
      id: 'double_exposure',
      name: 'Double Exposure',
      description: 'Photographic double exposure',
      settings: ClipBlendSettings(
        mode: VideoBlendMode.multiply,
        opacity: 0.8,
      ),
    ),
    BlendPreset(
      id: 'dreamy',
      name: 'Dreamy',
      description: 'Soft dreamy overlay',
      settings: ClipBlendSettings(
        mode: VideoBlendMode.softLight,
        opacity: 0.5,
      ),
    ),
    BlendPreset(
      id: 'high_contrast',
      name: 'High Contrast',
      description: 'Bold contrast enhancement',
      settings: ClipBlendSettings(
        mode: VideoBlendMode.overlay,
        opacity: 0.7,
      ),
    ),
    BlendPreset(
      id: 'invert_colors',
      name: 'Invert Colors',
      description: 'Color inversion effect',
      settings: ClipBlendSettings(
        mode: VideoBlendMode.difference,
        opacity: 1.0,
      ),
    ),
    BlendPreset(
      id: 'glow_effect',
      name: 'Glow',
      description: 'Ethereal glow effect',
      settings: ClipBlendSettings(
        mode: VideoBlendMode.glow,
        opacity: 0.5,
      ),
    ),
  ];
}
