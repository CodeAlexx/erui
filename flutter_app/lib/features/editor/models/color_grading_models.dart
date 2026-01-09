import 'dart:ui';
import 'editor_models.dart';

/// Represents a color wheel value for lift/gamma/gain adjustments
class ColorWheel {
  /// Red channel adjustment (-1.0 to 1.0)
  final double red;

  /// Green channel adjustment (-1.0 to 1.0)
  final double green;

  /// Blue channel adjustment (-1.0 to 1.0)
  final double blue;

  /// Master adjustment (-1.0 to 1.0)
  final double master;

  const ColorWheel({
    this.red = 0.0,
    this.green = 0.0,
    this.blue = 0.0,
    this.master = 0.0,
  });

  const ColorWheel.neutral() : this();

  ColorWheel copyWith({
    double? red,
    double? green,
    double? blue,
    double? master,
  }) {
    return ColorWheel(
      red: red ?? this.red,
      green: green ?? this.green,
      blue: blue ?? this.blue,
      master: master ?? this.master,
    );
  }

  bool get isNeutral =>
      red == 0.0 && green == 0.0 && blue == 0.0 && master == 0.0;

  /// Convert to offset from center for UI display
  Offset toOffset() => Offset(red, green);

  /// Create from UI offset
  factory ColorWheel.fromOffset(Offset offset, {double? master}) {
    return ColorWheel(
      red: offset.dx.clamp(-1.0, 1.0),
      green: offset.dy.clamp(-1.0, 1.0),
      master: master ?? 0.0,
    );
  }
}

/// Complete color grade settings for a clip
class ColorGrade {
  final EditorId id;

  /// Shadows adjustment
  final ColorWheel lift;

  /// Midtones adjustment
  final ColorWheel gamma;

  /// Highlights adjustment
  final ColorWheel gain;

  /// Overall saturation (0.0 to 2.0, 1.0 = normal)
  final double saturation;

  /// Overall exposure (-2.0 to 2.0)
  final double exposure;

  /// Contrast (0.0 to 2.0, 1.0 = normal)
  final double contrast;

  /// Temperature shift (-100 to 100)
  final double temperature;

  /// Tint shift (-100 to 100)
  final double tint;

  /// Whether grading is enabled
  final bool enabled;

  const ColorGrade({
    required this.id,
    this.lift = const ColorWheel.neutral(),
    this.gamma = const ColorWheel.neutral(),
    this.gain = const ColorWheel.neutral(),
    this.saturation = 1.0,
    this.exposure = 0.0,
    this.contrast = 1.0,
    this.temperature = 0.0,
    this.tint = 0.0,
    this.enabled = true,
  });

  factory ColorGrade.defaults({EditorId? id}) {
    return ColorGrade(id: id ?? generateId());
  }

  ColorGrade copyWith({
    EditorId? id,
    ColorWheel? lift,
    ColorWheel? gamma,
    ColorWheel? gain,
    double? saturation,
    double? exposure,
    double? contrast,
    double? temperature,
    double? tint,
    bool? enabled,
  }) {
    return ColorGrade(
      id: id ?? this.id,
      lift: lift ?? this.lift,
      gamma: gamma ?? this.gamma,
      gain: gain ?? this.gain,
      saturation: saturation ?? this.saturation,
      exposure: exposure ?? this.exposure,
      contrast: contrast ?? this.contrast,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      enabled: enabled ?? this.enabled,
    );
  }

  bool get hasChanges {
    return !lift.isNeutral ||
        !gamma.isNeutral ||
        !gain.isNeutral ||
        saturation != 1.0 ||
        exposure != 0.0 ||
        contrast != 1.0 ||
        temperature != 0.0 ||
        tint != 0.0;
  }

  /// Build FFmpeg colorbalance filter
  String toFFmpegFilter() {
    if (!enabled || !hasChanges) return '';

    final filters = <String>[];

    // Color balance for lift/gamma/gain
    if (!lift.isNeutral || !gamma.isNeutral || !gain.isNeutral) {
      filters.add('colorbalance='
          'rs=${lift.red}:gs=${lift.green}:bs=${lift.blue}:'
          'rm=${gamma.red}:gm=${gamma.green}:bm=${gamma.blue}:'
          'rh=${gain.red}:gh=${gain.green}:bh=${gain.blue}');
    }

    // Exposure and contrast via eq filter
    if (exposure != 0.0 || contrast != 1.0 || saturation != 1.0) {
      filters.add(
          'eq=brightness=$exposure:contrast=$contrast:saturation=$saturation');
    }

    // Temperature/tint via colortemperature filter
    if (temperature != 0.0) {
      final kelvin = 6500 + (temperature * 35); // Map -100..100 to ~3000K..10000K
      filters.add('colortemperature=temperature=${kelvin.round()}');
    }

    return filters.join(',');
  }
}

/// Reference to a LUT file (.cube format)
class LUTFile {
  final EditorId id;
  final String name;
  final String path;
  final String? thumbnailPath;
  final bool isFavorite;
  final DateTime? lastUsed;

  const LUTFile({
    required this.id,
    required this.name,
    required this.path,
    this.thumbnailPath,
    this.isFavorite = false,
    this.lastUsed,
  });

  LUTFile copyWith({
    EditorId? id,
    String? name,
    String? path,
    String? thumbnailPath,
    bool? isFavorite,
    DateTime? lastUsed,
  }) {
    return LUTFile(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isFavorite: isFavorite ?? this.isFavorite,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  /// Build FFmpeg lut3d filter
  String toFFmpegFilter() => 'lut3d=$path';
}

/// HSL color range for selective color adjustments
enum ColorRange {
  reds,
  oranges,
  yellows,
  greens,
  cyans,
  blues,
  magentas,
  all,
}

/// HSL adjustment for a specific color range
class HSLAdjustment {
  final ColorRange range;
  final double hue; // -180 to 180
  final double saturation; // -100 to 100
  final double luminance; // -100 to 100

  const HSLAdjustment({
    required this.range,
    this.hue = 0.0,
    this.saturation = 0.0,
    this.luminance = 0.0,
  });

  HSLAdjustment copyWith({
    ColorRange? range,
    double? hue,
    double? saturation,
    double? luminance,
  }) {
    return HSLAdjustment(
      range: range ?? this.range,
      hue: hue ?? this.hue,
      saturation: saturation ?? this.saturation,
      luminance: luminance ?? this.luminance,
    );
  }

  bool get isNeutral => hue == 0.0 && saturation == 0.0 && luminance == 0.0;

  /// Build FFmpeg selectivecolor filter string
  String toFFmpegFilter() {
    if (isNeutral) return '';

    final colorName = range.name.toLowerCase();
    return 'selectivecolor=$colorName=${hue / 180} ${saturation / 100} ${luminance / 100}';
  }
}

/// A point on a color curve
class CurvePoint {
  final double x; // 0.0 to 1.0 (input)
  final double y; // 0.0 to 1.0 (output)

  const CurvePoint(this.x, this.y);

  CurvePoint copyWith({double? x, double? y}) {
    return CurvePoint(x ?? this.x, y ?? this.y);
  }
}

/// RGB curve channel
enum CurveChannel { master, red, green, blue }

/// Color curve for RGB adjustments
class ColorCurve {
  final CurveChannel channel;
  final List<CurvePoint> points;

  const ColorCurve({
    required this.channel,
    this.points = const [CurvePoint(0, 0), CurvePoint(1, 1)],
  });

  factory ColorCurve.linear(CurveChannel channel) {
    return ColorCurve(
      channel: channel,
      points: const [CurvePoint(0, 0), CurvePoint(1, 1)],
    );
  }

  ColorCurve copyWith({
    CurveChannel? channel,
    List<CurvePoint>? points,
  }) {
    return ColorCurve(
      channel: channel ?? this.channel,
      points: points ?? List.from(this.points),
    );
  }

  bool get isLinear {
    if (points.length != 2) return false;
    return points[0].x == 0 &&
        points[0].y == 0 &&
        points[1].x == 1 &&
        points[1].y == 1;
  }

  /// Build FFmpeg curves filter string
  String toFFmpegFilter() {
    if (isLinear) return '';

    final channelName =
        channel == CurveChannel.master ? 'm' : channel.name[0];
    final pointsStr = points.map((p) => '${p.x}/${p.y}').join(' ');
    return 'curves=$channelName=\'$pointsStr\'';
  }
}

/// Extension for ColorRange utilities
extension ColorRangeExtension on ColorRange {
  String get displayName {
    switch (this) {
      case ColorRange.reds:
        return 'Reds';
      case ColorRange.oranges:
        return 'Oranges';
      case ColorRange.yellows:
        return 'Yellows';
      case ColorRange.greens:
        return 'Greens';
      case ColorRange.cyans:
        return 'Cyans';
      case ColorRange.blues:
        return 'Blues';
      case ColorRange.magentas:
        return 'Magentas';
      case ColorRange.all:
        return 'All Colors';
    }
  }
}

/// Extension for CurveChannel utilities
extension CurveChannelExtension on CurveChannel {
  String get displayName {
    switch (this) {
      case CurveChannel.master:
        return 'Master';
      case CurveChannel.red:
        return 'Red';
      case CurveChannel.green:
        return 'Green';
      case CurveChannel.blue:
        return 'Blue';
    }
  }
}
