import 'dart:ui';
import 'package:flutter/material.dart';
import 'editor_models.dart';

/// Types of masks available
enum MaskType {
  rectangle,
  ellipse,
  bezier,
  freehand,
  luminosity,
  colorKey,
}

extension MaskTypeExtension on MaskType {
  String get displayName {
    switch (this) {
      case MaskType.rectangle:
        return 'Rectangle';
      case MaskType.ellipse:
        return 'Ellipse';
      case MaskType.bezier:
        return 'Bezier Path';
      case MaskType.freehand:
        return 'Freehand';
      case MaskType.luminosity:
        return 'Luminosity';
      case MaskType.colorKey:
        return 'Color Key';
    }
  }

  IconData get icon {
    switch (this) {
      case MaskType.rectangle:
        return Icons.crop_square;
      case MaskType.ellipse:
        return Icons.circle_outlined;
      case MaskType.bezier:
        return Icons.gesture;
      case MaskType.freehand:
        return Icons.create;
      case MaskType.luminosity:
        return Icons.brightness_6;
      case MaskType.colorKey:
        return Icons.color_lens;
    }
  }
}

/// A point in a bezier path
class MaskPoint {
  final double x;
  final double y;

  /// Control point for incoming curve (relative to point)
  final Offset? handleIn;

  /// Control point for outgoing curve (relative to point)
  final Offset? handleOut;

  /// Whether this point is selected in UI
  final bool isSelected;

  /// Whether handles are linked (mirror each other)
  final bool linkedHandles;

  const MaskPoint({
    required this.x,
    required this.y,
    this.handleIn,
    this.handleOut,
    this.isSelected = false,
    this.linkedHandles = true,
  });

  MaskPoint copyWith({
    double? x,
    double? y,
    Offset? handleIn,
    Offset? handleOut,
    bool? isSelected,
    bool? linkedHandles,
  }) {
    return MaskPoint(
      x: x ?? this.x,
      y: y ?? this.y,
      handleIn: handleIn ?? this.handleIn,
      handleOut: handleOut ?? this.handleOut,
      isSelected: isSelected ?? this.isSelected,
      linkedHandles: linkedHandles ?? this.linkedHandles,
    );
  }

  Offset get position => Offset(x, y);

  /// Get absolute position of incoming handle
  Offset get absoluteHandleIn => handleIn != null
      ? Offset(x + handleIn!.dx, y + handleIn!.dy)
      : position;

  /// Get absolute position of outgoing handle
  Offset get absoluteHandleOut => handleOut != null
      ? Offset(x + handleOut!.dx, y + handleOut!.dy)
      : position;
}

/// Base mask class
abstract class Mask {
  final EditorId id;
  final MaskType type;
  final String name;

  /// Whether mask is enabled
  final bool enabled;

  /// Feather/blur amount (0-100)
  final double feather;

  /// Opacity of the mask (0-1)
  final double opacity;

  /// Invert the mask
  final bool inverted;

  /// Expansion/contraction (-100 to 100)
  final double expansion;

  /// Whether mask is selected in UI
  final bool isSelected;

  const Mask({
    required this.id,
    required this.type,
    this.name = 'Mask',
    this.enabled = true,
    this.feather = 0.0,
    this.opacity = 1.0,
    this.inverted = false,
    this.expansion = 0.0,
    this.isSelected = false,
  });

  Mask copyWith({
    EditorId? id,
    MaskType? type,
    String? name,
    bool? enabled,
    double? feather,
    double? opacity,
    bool? inverted,
    double? expansion,
    bool? isSelected,
  });

  /// Generate FFmpeg filter for this mask
  String toFfmpegFilter(Size videoSize);
}

/// Rectangle shape mask
class RectangleMask extends Mask {
  /// Position (normalized 0-1)
  final double x;
  final double y;
  final double width;
  final double height;

  /// Corner radius (0-1, relative to smaller dimension)
  final double cornerRadius;

  /// Rotation in degrees
  final double rotation;

  const RectangleMask({
    required super.id,
    super.name = 'Rectangle Mask',
    super.enabled,
    super.feather,
    super.opacity,
    super.inverted,
    super.expansion,
    super.isSelected,
    this.x = 0.25,
    this.y = 0.25,
    this.width = 0.5,
    this.height = 0.5,
    this.cornerRadius = 0.0,
    this.rotation = 0.0,
  }) : super(type: MaskType.rectangle);

  @override
  RectangleMask copyWith({
    EditorId? id,
    MaskType? type,
    String? name,
    bool? enabled,
    double? feather,
    double? opacity,
    bool? inverted,
    double? expansion,
    bool? isSelected,
    double? x,
    double? y,
    double? width,
    double? height,
    double? cornerRadius,
    double? rotation,
  }) {
    return RectangleMask(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      feather: feather ?? this.feather,
      opacity: opacity ?? this.opacity,
      inverted: inverted ?? this.inverted,
      expansion: expansion ?? this.expansion,
      isSelected: isSelected ?? this.isSelected,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  String toFfmpegFilter(Size videoSize) {
    final px = (x * videoSize.width).round();
    final py = (y * videoSize.height).round();
    final pw = (width * videoSize.width).round();
    final ph = (height * videoSize.height).round();

    String filter = "drawbox=x=$px:y=$py:w=$pw:h=$ph:color=white@${opacity}:t=fill";

    if (feather > 0) {
      final blur = (feather / 2).round();
      filter = "[$filter]boxblur=$blur:$blur";
    }

    if (inverted) {
      filter = "[$filter]negate";
    }

    return filter;
  }
}

/// Ellipse shape mask
class EllipseMask extends Mask {
  /// Center position (normalized 0-1)
  final double centerX;
  final double centerY;

  /// Radii (normalized 0-1)
  final double radiusX;
  final double radiusY;

  /// Rotation in degrees
  final double rotation;

  const EllipseMask({
    required super.id,
    super.name = 'Ellipse Mask',
    super.enabled,
    super.feather,
    super.opacity,
    super.inverted,
    super.expansion,
    super.isSelected,
    this.centerX = 0.5,
    this.centerY = 0.5,
    this.radiusX = 0.25,
    this.radiusY = 0.25,
    this.rotation = 0.0,
  }) : super(type: MaskType.ellipse);

  @override
  EllipseMask copyWith({
    EditorId? id,
    MaskType? type,
    String? name,
    bool? enabled,
    double? feather,
    double? opacity,
    bool? inverted,
    double? expansion,
    bool? isSelected,
    double? centerX,
    double? centerY,
    double? radiusX,
    double? radiusY,
    double? rotation,
  }) {
    return EllipseMask(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      feather: feather ?? this.feather,
      opacity: opacity ?? this.opacity,
      inverted: inverted ?? this.inverted,
      expansion: expansion ?? this.expansion,
      isSelected: isSelected ?? this.isSelected,
      centerX: centerX ?? this.centerX,
      centerY: centerY ?? this.centerY,
      radiusX: radiusX ?? this.radiusX,
      radiusY: radiusY ?? this.radiusY,
      rotation: rotation ?? this.rotation,
    );
  }

  @override
  String toFfmpegFilter(Size videoSize) {
    final cx = (centerX * videoSize.width).round();
    final cy = (centerY * videoSize.height).round();
    final rx = (radiusX * videoSize.width).round();
    final ry = (radiusY * videoSize.height).round();

    // Use geq filter for ellipse
    String filter = "geq=lum='if(lt(pow((X-$cx)/$rx,2)+pow((Y-$cy)/$ry,2),1),255,0)'";

    if (feather > 0) {
      final blur = (feather / 2).round();
      filter = "[$filter]boxblur=$blur:$blur";
    }

    if (inverted) {
      filter = "[$filter]negate";
    }

    return filter;
  }
}

/// Bezier path mask with control points
class BezierMask extends Mask {
  /// List of points defining the path
  final List<MaskPoint> points;

  /// Whether the path is closed
  final bool closed;

  const BezierMask({
    required super.id,
    super.name = 'Bezier Mask',
    super.enabled,
    super.feather,
    super.opacity,
    super.inverted,
    super.expansion,
    super.isSelected,
    this.points = const [],
    this.closed = true,
  }) : super(type: MaskType.bezier);

  @override
  BezierMask copyWith({
    EditorId? id,
    MaskType? type,
    String? name,
    bool? enabled,
    double? feather,
    double? opacity,
    bool? inverted,
    double? expansion,
    bool? isSelected,
    List<MaskPoint>? points,
    bool? closed,
  }) {
    return BezierMask(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      feather: feather ?? this.feather,
      opacity: opacity ?? this.opacity,
      inverted: inverted ?? this.inverted,
      expansion: expansion ?? this.expansion,
      isSelected: isSelected ?? this.isSelected,
      points: points ?? List.from(this.points),
      closed: closed ?? this.closed,
    );
  }

  /// Add a point to the path
  BezierMask addPoint(MaskPoint point) {
    return copyWith(points: [...points, point]);
  }

  /// Remove a point by index
  BezierMask removePoint(int index) {
    final newPoints = List<MaskPoint>.from(points);
    newPoints.removeAt(index);
    return copyWith(points: newPoints);
  }

  /// Update a point
  BezierMask updatePoint(int index, MaskPoint point) {
    final newPoints = List<MaskPoint>.from(points);
    newPoints[index] = point;
    return copyWith(points: newPoints);
  }

  /// Convert to Flutter Path
  Path toPath(Size videoSize) {
    if (points.isEmpty) return Path();

    final path = Path();
    final scaledPoints = points.map((p) => MaskPoint(
      x: p.x * videoSize.width,
      y: p.y * videoSize.height,
      handleIn: p.handleIn != null
          ? Offset(p.handleIn!.dx * videoSize.width, p.handleIn!.dy * videoSize.height)
          : null,
      handleOut: p.handleOut != null
          ? Offset(p.handleOut!.dx * videoSize.width, p.handleOut!.dy * videoSize.height)
          : null,
    )).toList();

    path.moveTo(scaledPoints.first.x, scaledPoints.first.y);

    for (int i = 1; i < scaledPoints.length; i++) {
      final prev = scaledPoints[i - 1];
      final curr = scaledPoints[i];

      if (prev.handleOut != null || curr.handleIn != null) {
        path.cubicTo(
          prev.absoluteHandleOut.dx,
          prev.absoluteHandleOut.dy,
          curr.absoluteHandleIn.dx,
          curr.absoluteHandleIn.dy,
          curr.x,
          curr.y,
        );
      } else {
        path.lineTo(curr.x, curr.y);
      }
    }

    if (closed && scaledPoints.length > 2) {
      final last = scaledPoints.last;
      final first = scaledPoints.first;

      if (last.handleOut != null || first.handleIn != null) {
        path.cubicTo(
          last.absoluteHandleOut.dx,
          last.absoluteHandleOut.dy,
          first.absoluteHandleIn.dx,
          first.absoluteHandleIn.dy,
          first.x,
          first.y,
        );
      }
      path.close();
    }

    return path;
  }

  @override
  String toFfmpegFilter(Size videoSize) {
    // FFmpeg doesn't directly support bezier masks
    // This generates an approximation using a polygon
    if (points.isEmpty) return '';

    final coords = points
        .map((p) => '${(p.x * videoSize.width).round()} ${(p.y * videoSize.height).round()}')
        .join(' ');

    return "geq=lum='if(gte(random(1),0.5),255,0)'"; // Placeholder - would need custom filter
  }
}

/// Luminosity-based mask
class LuminosityMask extends Mask {
  /// Range of luminosity values to include (0-255)
  final int lowThreshold;
  final int highThreshold;

  /// Softness of the threshold edges
  final double softness;

  const LuminosityMask({
    required super.id,
    super.name = 'Luminosity Mask',
    super.enabled,
    super.feather,
    super.opacity,
    super.inverted,
    super.expansion,
    super.isSelected,
    this.lowThreshold = 128,
    this.highThreshold = 255,
    this.softness = 0.0,
  }) : super(type: MaskType.luminosity);

  @override
  LuminosityMask copyWith({
    EditorId? id,
    MaskType? type,
    String? name,
    bool? enabled,
    double? feather,
    double? opacity,
    bool? inverted,
    double? expansion,
    bool? isSelected,
    int? lowThreshold,
    int? highThreshold,
    double? softness,
  }) {
    return LuminosityMask(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      feather: feather ?? this.feather,
      opacity: opacity ?? this.opacity,
      inverted: inverted ?? this.inverted,
      expansion: expansion ?? this.expansion,
      isSelected: isSelected ?? this.isSelected,
      lowThreshold: lowThreshold ?? this.lowThreshold,
      highThreshold: highThreshold ?? this.highThreshold,
      softness: softness ?? this.softness,
    );
  }

  @override
  String toFfmpegFilter(Size videoSize) {
    final low = lowThreshold / 255.0;
    final high = highThreshold / 255.0;

    String filter = "geq=lum='if(between(lum(X,Y),$low,$high),255,0)'";

    if (feather > 0) {
      final blur = (feather / 2).round();
      filter = "[$filter]boxblur=$blur:$blur";
    }

    if (inverted) {
      filter = "[$filter]negate";
    }

    return filter;
  }
}

/// State for masks on a clip
class ClipMaskState {
  final EditorId clipId;

  /// List of masks (applied in order)
  final List<Mask> masks;

  /// Mask blend mode
  final MaskBlendMode blendMode;

  /// Whether to show mask outlines in preview
  final bool showOutlines;

  const ClipMaskState({
    required this.clipId,
    this.masks = const [],
    this.blendMode = MaskBlendMode.add,
    this.showOutlines = true,
  });

  ClipMaskState copyWith({
    EditorId? clipId,
    List<Mask>? masks,
    MaskBlendMode? blendMode,
    bool? showOutlines,
  }) {
    return ClipMaskState(
      clipId: clipId ?? this.clipId,
      masks: masks ?? List.from(this.masks),
      blendMode: blendMode ?? this.blendMode,
      showOutlines: showOutlines ?? this.showOutlines,
    );
  }

  /// Add a mask
  ClipMaskState addMask(Mask mask) {
    return copyWith(masks: [...masks, mask]);
  }

  /// Remove a mask
  ClipMaskState removeMask(EditorId maskId) {
    return copyWith(masks: masks.where((m) => m.id != maskId).toList());
  }

  /// Update a mask
  ClipMaskState updateMask(Mask mask) {
    return copyWith(
      masks: masks.map((m) => m.id == mask.id ? mask : m).toList(),
    );
  }

  /// Reorder masks
  ClipMaskState reorderMasks(int oldIndex, int newIndex) {
    final newMasks = List<Mask>.from(masks);
    final mask = newMasks.removeAt(oldIndex);
    newMasks.insert(newIndex, mask);
    return copyWith(masks: newMasks);
  }
}

/// How multiple masks are combined
enum MaskBlendMode {
  add,
  subtract,
  intersect,
  difference,
}

extension MaskBlendModeExtension on MaskBlendMode {
  String get displayName {
    switch (this) {
      case MaskBlendMode.add:
        return 'Add';
      case MaskBlendMode.subtract:
        return 'Subtract';
      case MaskBlendMode.intersect:
        return 'Intersect';
      case MaskBlendMode.difference:
        return 'Difference';
    }
  }
}
