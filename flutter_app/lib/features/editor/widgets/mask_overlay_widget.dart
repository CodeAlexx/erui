import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/mask_models.dart';
import '../providers/mask_provider.dart';

/// Widget for drawing masks on video preview.
///
/// Features:
/// - Render mask shapes
/// - Interactive editing handles
/// - Bezier point manipulation
/// - Visual feedback for feather/opacity
class MaskOverlayWidget extends ConsumerStatefulWidget {
  final Size videoSize;
  final EditorId clipId;

  const MaskOverlayWidget({
    super.key,
    required this.videoSize,
    required this.clipId,
  });

  @override
  ConsumerState<MaskOverlayWidget> createState() => _MaskOverlayWidgetState();
}

class _MaskOverlayWidgetState extends ConsumerState<MaskOverlayWidget> {
  Offset? _dragStart;
  Offset? _currentDrag;

  @override
  Widget build(BuildContext context) {
    final maskState = ref.watch(maskProvider);
    final clipMasks = maskState.clipMasks[widget.clipId];
    final showOutlines = maskState.showOutlines;
    final showOverlay = maskState.showOverlay;
    final selectedMaskId = maskState.selectedMaskId;
    final selectedPointIndex = maskState.selectedPointIndex;
    final currentTool = maskState.currentTool;
    final isEditing = maskState.isEditing;

    if (clipMasks == null || clipMasks.masks.isEmpty) {
      return _buildDrawingArea(context, currentTool, isEditing);
    }

    return Stack(
      children: [
        // Drawing area for new masks
        if (isEditing) _buildDrawingArea(context, currentTool, isEditing),

        // Render masks
        ...clipMasks.masks.map((mask) {
          if (!mask.enabled && !showOutlines) return const SizedBox.shrink();

          final isSelected = mask.id == selectedMaskId;

          return _MaskRenderer(
            mask: mask,
            videoSize: widget.videoSize,
            showOverlay: showOverlay && mask.enabled,
            showOutline: showOutlines || isSelected,
            isSelected: isSelected,
            selectedPointIndex: isSelected ? selectedPointIndex : null,
            onPointSelected: (index) {
              ref.read(maskProvider.notifier).selectMask(mask.id);
              ref.read(maskProvider.notifier).selectPoint(index);
            },
            onPointMoved: (index, position) {
              if (mask is BezierMask) {
                final normalized = Offset(
                  position.dx / widget.videoSize.width,
                  position.dy / widget.videoSize.height,
                );
                ref.read(maskProvider.notifier).updateBezierPoint(
                  mask.id,
                  index,
                  mask.points[index].copyWith(x: normalized.dx, y: normalized.dy),
                );
              }
            },
            onMaskMoved: (delta) {
              _moveMask(mask, delta);
            },
            onMaskResized: (corner, delta) {
              _resizeMask(mask, corner, delta);
            },
          );
        }),
      ],
    );
  }

  Widget _buildDrawingArea(BuildContext context, MaskType tool, bool isEditing) {
    if (!isEditing) return const SizedBox.shrink();

    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _dragStart = details.localPosition;
          _currentDrag = details.localPosition;
        });
      },
      onPanUpdate: (details) {
        setState(() {
          _currentDrag = details.localPosition;
        });
      },
      onPanEnd: (details) {
        if (_dragStart != null && _currentDrag != null) {
          _createMaskFromDrag(tool, _dragStart!, _currentDrag!);
        }
        setState(() {
          _dragStart = null;
          _currentDrag = null;
        });
      },
      child: Container(
        color: Colors.transparent,
        child: _dragStart != null && _currentDrag != null
            ? CustomPaint(
                size: widget.videoSize,
                painter: _DrawingPreviewPainter(
                  tool: tool,
                  start: _dragStart!,
                  end: _currentDrag!,
                ),
              )
            : null,
      ),
    );
  }

  void _createMaskFromDrag(MaskType tool, Offset start, Offset end) {
    final x1 = (start.dx / widget.videoSize.width).clamp(0.0, 1.0);
    final y1 = (start.dy / widget.videoSize.height).clamp(0.0, 1.0);
    final x2 = (end.dx / widget.videoSize.width).clamp(0.0, 1.0);
    final y2 = (end.dy / widget.videoSize.height).clamp(0.0, 1.0);

    switch (tool) {
      case MaskType.rectangle:
        ref.read(maskProvider.notifier).addRectangleMask(
          x: x1.clamp(0.0, x2),
          y: y1.clamp(0.0, y2),
          width: (x2 - x1).abs(),
          height: (y2 - y1).abs(),
        );
        break;
      case MaskType.ellipse:
        final cx = (x1 + x2) / 2;
        final cy = (y1 + y2) / 2;
        final rx = (x2 - x1).abs() / 2;
        final ry = (y2 - y1).abs() / 2;
        ref.read(maskProvider.notifier).addEllipseMask(
          centerX: cx,
          centerY: cy,
          radiusX: rx,
          radiusY: ry,
        );
        break;
      default:
        break;
    }
  }

  void _moveMask(Mask mask, Offset delta) {
    final dx = delta.dx / widget.videoSize.width;
    final dy = delta.dy / widget.videoSize.height;

    if (mask is RectangleMask) {
      ref.read(maskProvider.notifier).updateMask(
        mask.copyWith(
          x: (mask.x + dx).clamp(0.0, 1.0 - mask.width),
          y: (mask.y + dy).clamp(0.0, 1.0 - mask.height),
        ),
      );
    } else if (mask is EllipseMask) {
      ref.read(maskProvider.notifier).updateMask(
        mask.copyWith(
          centerX: (mask.centerX + dx).clamp(mask.radiusX, 1.0 - mask.radiusX),
          centerY: (mask.centerY + dy).clamp(mask.radiusY, 1.0 - mask.radiusY),
        ),
      );
    }
  }

  void _resizeMask(Mask mask, int corner, Offset delta) {
    final dx = delta.dx / widget.videoSize.width;
    final dy = delta.dy / widget.videoSize.height;

    if (mask is RectangleMask) {
      double x = mask.x;
      double y = mask.y;
      double w = mask.width;
      double h = mask.height;

      switch (corner) {
        case 0: // Top-left
          x += dx;
          y += dy;
          w -= dx;
          h -= dy;
          break;
        case 1: // Top-right
          y += dy;
          w += dx;
          h -= dy;
          break;
        case 2: // Bottom-right
          w += dx;
          h += dy;
          break;
        case 3: // Bottom-left
          x += dx;
          w -= dx;
          h += dy;
          break;
      }

      if (w > 0.01 && h > 0.01) {
        ref.read(maskProvider.notifier).updateMask(
          mask.copyWith(
            x: x.clamp(0.0, 1.0),
            y: y.clamp(0.0, 1.0),
            width: w.clamp(0.01, 1.0),
            height: h.clamp(0.01, 1.0),
          ),
        );
      }
    }
  }
}

/// Renders an individual mask
class _MaskRenderer extends StatelessWidget {
  final Mask mask;
  final Size videoSize;
  final bool showOverlay;
  final bool showOutline;
  final bool isSelected;
  final int? selectedPointIndex;
  final void Function(int index)? onPointSelected;
  final void Function(int index, Offset position)? onPointMoved;
  final void Function(Offset delta)? onMaskMoved;
  final void Function(int corner, Offset delta)? onMaskResized;

  const _MaskRenderer({
    required this.mask,
    required this.videoSize,
    required this.showOverlay,
    required this.showOutline,
    required this.isSelected,
    this.selectedPointIndex,
    this.onPointSelected,
    this.onPointMoved,
    this.onMaskMoved,
    this.onMaskResized,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Mask shape
        if (showOverlay)
          CustomPaint(
            size: videoSize,
            painter: _MaskShapePainter(
              mask: mask,
              videoSize: videoSize,
            ),
          ),

        // Outline and handles
        if (showOutline)
          CustomPaint(
            size: videoSize,
            painter: _MaskOutlinePainter(
              mask: mask,
              videoSize: videoSize,
              isSelected: isSelected,
            ),
          ),

        // Handles for selected mask
        if (isSelected) ..._buildHandles(context),
      ],
    );
  }

  List<Widget> _buildHandles(BuildContext context) {
    if (mask is RectangleMask) {
      return _buildRectangleHandles(mask as RectangleMask);
    } else if (mask is EllipseMask) {
      return _buildEllipseHandles(mask as EllipseMask);
    } else if (mask is BezierMask) {
      return _buildBezierHandles(mask as BezierMask);
    }
    return [];
  }

  List<Widget> _buildRectangleHandles(RectangleMask rect) {
    final corners = [
      Offset(rect.x * videoSize.width, rect.y * videoSize.height),
      Offset((rect.x + rect.width) * videoSize.width, rect.y * videoSize.height),
      Offset((rect.x + rect.width) * videoSize.width, (rect.y + rect.height) * videoSize.height),
      Offset(rect.x * videoSize.width, (rect.y + rect.height) * videoSize.height),
    ];

    return [
      // Center drag
      Positioned(
        left: (rect.x + rect.width / 2) * videoSize.width - 8,
        top: (rect.y + rect.height / 2) * videoSize.height - 8,
        child: GestureDetector(
          onPanUpdate: (d) => onMaskMoved?.call(d.delta),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 2),
            ),
          ),
        ),
      ),
      // Corner handles
      ...corners.asMap().entries.map((e) {
        return Positioned(
          left: e.value.dx - 6,
          top: e.value.dy - 6,
          child: GestureDetector(
            onPanUpdate: (d) => onMaskResized?.call(e.key, d.delta),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.blue, width: 2),
              ),
            ),
          ),
        );
      }),
    ];
  }

  List<Widget> _buildEllipseHandles(EllipseMask ellipse) {
    return [
      // Center drag
      Positioned(
        left: ellipse.centerX * videoSize.width - 8,
        top: ellipse.centerY * videoSize.height - 8,
        child: GestureDetector(
          onPanUpdate: (d) => onMaskMoved?.call(d.delta),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 2),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildBezierHandles(BezierMask bezier) {
    return bezier.points.asMap().entries.map((e) {
      final point = e.value;
      final index = e.key;
      final isPointSelected = selectedPointIndex == index;

      return Positioned(
        left: point.x * videoSize.width - 6,
        top: point.y * videoSize.height - 6,
        child: GestureDetector(
          onTap: () => onPointSelected?.call(index),
          onPanUpdate: (d) {
            final newPos = Offset(
              point.x * videoSize.width + d.delta.dx,
              point.y * videoSize.height + d.delta.dy,
            );
            onPointMoved?.call(index, newPos);
          },
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isPointSelected ? Colors.blue : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isPointSelected ? Colors.white : Colors.blue,
                width: 2,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

/// Painter for mask shape fill
class _MaskShapePainter extends CustomPainter {
  final Mask mask;
  final Size videoSize;

  _MaskShapePainter({required this.mask, required this.videoSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(mask.opacity * 0.3)
      ..style = PaintingStyle.fill;

    if (mask is RectangleMask) {
      final rect = mask as RectangleMask;
      canvas.drawRect(
        Rect.fromLTWH(
          rect.x * videoSize.width,
          rect.y * videoSize.height,
          rect.width * videoSize.width,
          rect.height * videoSize.height,
        ),
        paint,
      );
    } else if (mask is EllipseMask) {
      final ellipse = mask as EllipseMask;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(ellipse.centerX * videoSize.width, ellipse.centerY * videoSize.height),
          width: ellipse.radiusX * 2 * videoSize.width,
          height: ellipse.radiusY * 2 * videoSize.height,
        ),
        paint,
      );
    } else if (mask is BezierMask) {
      final bezier = mask as BezierMask;
      final path = bezier.toPath(videoSize);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MaskShapePainter oldDelegate) {
    return mask != oldDelegate.mask;
  }
}

/// Painter for mask outline
class _MaskOutlinePainter extends CustomPainter {
  final Mask mask;
  final Size videoSize;
  final bool isSelected;

  _MaskOutlinePainter({
    required this.mask,
    required this.videoSize,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isSelected ? Colors.blue : Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2 : 1;

    if (mask is RectangleMask) {
      final rect = mask as RectangleMask;
      canvas.drawRect(
        Rect.fromLTWH(
          rect.x * videoSize.width,
          rect.y * videoSize.height,
          rect.width * videoSize.width,
          rect.height * videoSize.height,
        ),
        paint,
      );
    } else if (mask is EllipseMask) {
      final ellipse = mask as EllipseMask;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(ellipse.centerX * videoSize.width, ellipse.centerY * videoSize.height),
          width: ellipse.radiusX * 2 * videoSize.width,
          height: ellipse.radiusY * 2 * videoSize.height,
        ),
        paint,
      );
    } else if (mask is BezierMask) {
      final bezier = mask as BezierMask;
      final path = bezier.toPath(videoSize);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MaskOutlinePainter oldDelegate) {
    return mask != oldDelegate.mask || isSelected != oldDelegate.isSelected;
  }
}

/// Painter for drawing preview
class _DrawingPreviewPainter extends CustomPainter {
  final MaskType tool;
  final Offset start;
  final Offset end;

  _DrawingPreviewPainter({
    required this.tool,
    required this.start,
    required this.end,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromPoints(start, end);

    switch (tool) {
      case MaskType.rectangle:
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, paint);
        break;
      case MaskType.ellipse:
        canvas.drawOval(rect, fillPaint);
        canvas.drawOval(rect, paint);
        break;
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPreviewPainter oldDelegate) {
    return start != oldDelegate.start || end != oldDelegate.end || tool != oldDelegate.tool;
  }
}
