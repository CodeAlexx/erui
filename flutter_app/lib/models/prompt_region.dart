import 'dart:ui';

/// Model representing a rectangular region for regional prompting.
///
/// Coordinates are normalized (0.0 - 1.0) as fractions of the image dimensions.
class PromptRegion {
  /// Unique identifier for this region
  final String id;

  /// X position (0.0 - 1.0, fraction of image width)
  final double x;

  /// Y position (0.0 - 1.0, fraction of image height)
  final double y;

  /// Width (0.0 - 1.0, fraction of image width)
  final double width;

  /// Height (0.0 - 1.0, fraction of image height)
  final double height;

  /// Prompt text for this region
  final String prompt;

  /// Region strength (0.0 - 1.0)
  final double strength;

  /// Optional LoRA name to apply in this region
  final String? loraName;

  /// Optional LoRA strength (0.0 - 2.0)
  final double loraStrength;

  /// Display color for visual representation
  final Color color;

  const PromptRegion({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.prompt = '',
    this.strength = 1.0,
    this.loraName,
    this.loraStrength = 1.0,
    required this.color,
  });

  /// Create a copy with updated properties
  PromptRegion copyWith({
    String? id,
    double? x,
    double? y,
    double? width,
    double? height,
    String? prompt,
    double? strength,
    String? loraName,
    double? loraStrength,
    Color? color,
  }) {
    return PromptRegion(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      prompt: prompt ?? this.prompt,
      strength: strength ?? this.strength,
      loraName: loraName ?? this.loraName,
      loraStrength: loraStrength ?? this.loraStrength,
      color: color ?? this.color,
    );
  }

  /// Clear the LoRA from this region
  PromptRegion clearLora() {
    return PromptRegion(
      id: id,
      x: x,
      y: y,
      width: width,
      height: height,
      prompt: prompt,
      strength: strength,
      loraName: null,
      loraStrength: 1.0,
      color: color,
    );
  }

  /// Convert to normalized rectangle (0.0 - 1.0)
  Rect toNormalizedRect() {
    return Rect.fromLTWH(x, y, width, height);
  }

  /// Convert to pixel rectangle given canvas size
  Rect toPixelRect(Size canvasSize) {
    return Rect.fromLTWH(
      x * canvasSize.width,
      y * canvasSize.height,
      width * canvasSize.width,
      height * canvasSize.height,
    );
  }

  /// Create from pixel rectangle given canvas size
  static PromptRegion fromPixelRect({
    required String id,
    required Rect rect,
    required Size canvasSize,
    required Color color,
    String prompt = '',
    double strength = 1.0,
  }) {
    return PromptRegion(
      id: id,
      x: (rect.left / canvasSize.width).clamp(0.0, 1.0),
      y: (rect.top / canvasSize.height).clamp(0.0, 1.0),
      width: (rect.width / canvasSize.width).clamp(0.0, 1.0),
      height: (rect.height / canvasSize.height).clamp(0.0, 1.0),
      prompt: prompt,
      strength: strength,
      color: color,
    );
  }

  /// Export to regional prompt syntax: <region:x,y,w,h,strength> prompt text
  String toPromptSyntax() {
    final regionTag = '<region:${x.toStringAsFixed(3)},${y.toStringAsFixed(3)},${width.toStringAsFixed(3)},${height.toStringAsFixed(3)},${strength.toStringAsFixed(2)}>';

    // Add LoRA syntax if specified
    String loraPrefix = '';
    if (loraName != null && loraName!.isNotEmpty) {
      loraPrefix = '<lora:$loraName:${loraStrength.toStringAsFixed(2)}> ';
    }

    return '$regionTag $loraPrefix$prompt';
  }

  /// Parse from regional prompt syntax
  static PromptRegion? fromPromptSyntax(String syntax, Color color) {
    final regionMatch = RegExp(r'<region:([\d.]+),([\d.]+),([\d.]+),([\d.]+),([\d.]+)>').firstMatch(syntax);
    if (regionMatch == null) return null;

    // Extract LoRA if present
    String? loraName;
    double loraStrength = 1.0;
    final loraMatch = RegExp(r'<lora:([^:]+):([\d.]+)>').firstMatch(syntax);
    if (loraMatch != null) {
      loraName = loraMatch.group(1);
      loraStrength = double.tryParse(loraMatch.group(2) ?? '1.0') ?? 1.0;
    }

    // Extract prompt text (everything after the region tag and optional lora tag)
    String prompt = syntax
        .replaceFirst(regionMatch.group(0)!, '')
        .replaceFirst(RegExp(r'<lora:[^>]+>'), '')
        .trim();

    return PromptRegion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      x: double.tryParse(regionMatch.group(1)!) ?? 0.0,
      y: double.tryParse(regionMatch.group(2)!) ?? 0.0,
      width: double.tryParse(regionMatch.group(3)!) ?? 0.5,
      height: double.tryParse(regionMatch.group(4)!) ?? 0.5,
      strength: double.tryParse(regionMatch.group(5)!) ?? 1.0,
      prompt: prompt,
      loraName: loraName,
      loraStrength: loraStrength,
      color: color,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'prompt': prompt,
      'strength': strength,
      'loraName': loraName,
      'loraStrength': loraStrength,
      'color': color.value,
    };
  }

  /// Create from JSON
  factory PromptRegion.fromJson(Map<String, dynamic> json) {
    return PromptRegion(
      id: json['id'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      prompt: json['prompt'] as String? ?? '',
      strength: (json['strength'] as num?)?.toDouble() ?? 1.0,
      loraName: json['loraName'] as String?,
      loraStrength: (json['loraStrength'] as num?)?.toDouble() ?? 1.0,
      color: Color(json['color'] as int),
    );
  }

  @override
  String toString() {
    return 'PromptRegion(id: $id, x: $x, y: $y, w: $width, h: $height, prompt: $prompt, strength: $strength)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PromptRegion && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Predefined colors for regions
class RegionColors {
  static const List<Color> palette = [
    Color(0xFFE57373), // Red
    Color(0xFF64B5F6), // Blue
    Color(0xFF81C784), // Green
    Color(0xFFFFD54F), // Yellow
    Color(0xFFBA68C8), // Purple
    Color(0xFF4DB6AC), // Teal
    Color(0xFFFF8A65), // Orange
    Color(0xFF90A4AE), // Blue Grey
    Color(0xFFA1887F), // Brown
    Color(0xFFF06292), // Pink
  ];

  /// Get next available color based on existing regions
  static Color getNextColor(List<PromptRegion> existingRegions) {
    final usedColors = existingRegions.map((r) => r.color.value).toSet();
    for (final color in palette) {
      if (!usedColors.contains(color.value)) {
        return color;
      }
    }
    // If all colors used, cycle back
    return palette[existingRegions.length % palette.length];
  }
}
