import 'package:flutter/material.dart';
import '../models/vid_train_prep_models.dart';

/// Handle position for resizing crop region
enum _DragHandle {
  topLeft,
  top,
  topRight,
  left,
  center,
  right,
  bottomLeft,
  bottom,
  bottomRight,
}

/// Canvas widget for drawing and manipulating a crop region over video preview.
///
/// Features:
/// - Draw new crop rectangle by dragging on empty space
/// - Drag handles on corners and edges to resize
/// - Drag center to move the crop region
/// - Semi-transparent dark overlay outside crop area
/// - Shows crop dimensions (pixels and percentage)
/// - Optional aspect ratio lock
class CropSelectorCanvas extends StatefulWidget {
  /// Current crop region (normalized 0-1 coordinates)
  final CropRegion? crop;

  /// Callback when crop region changes
  final ValueChanged<CropRegion> onCropChanged;

  /// If set, lock to this aspect ratio (width/height)
  final double? aspectRatio;

  /// Whether editing is enabled
  final bool enabled;

  /// Video dimensions for displaying pixel values
  final int? videoWidth;
  final int? videoHeight;

  /// Whether to show the rule-of-thirds grid
  final bool showGrid;

  /// Whether to show dimension labels
  final bool showDimensions;

  const CropSelectorCanvas({
    super.key,
    this.crop,
    required this.onCropChanged,
    this.aspectRatio,
    this.enabled = true,
    this.videoWidth,
    this.videoHeight,
    this.showGrid = true,
    this.showDimensions = true,
  });

  @override
  State<CropSelectorCanvas> createState() => _CropSelectorCanvasState();
}

class _CropSelectorCanvasState extends State<CropSelectorCanvas> {
  CropRegion? _currentCrop;
  _DragHandle? _activeHandle;
  Offset? _dragStart;
  CropRegion? _cropAtDragStart;
  bool _isCreating = false;
  Offset? _createStart;

  static const double _handleSize = 12.0;
  static const double _handleHitArea = 20.0;
  static const double _minCropSize = 0.05; // Minimum 5% of canvas

  @override
  void initState() {
    super.initState();
    _currentCrop = widget.crop;
  }

  @override
  void didUpdateWidget(covariant CropSelectorCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.crop != oldWidget.crop) {
      _currentCrop = widget.crop;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          cursor: _getCursor(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: widget.enabled ? (d) => _onPanStart(d, constraints.biggest) : null,
            onPanUpdate: widget.enabled ? (d) => _onPanUpdate(d, constraints.biggest) : null,
            onPanEnd: widget.enabled ? (d) => _onPanEnd() : null,
            child: CustomPaint(
              painter: _CropOverlayPainter(
                crop: _currentCrop,
                activeHandle: _activeHandle,
                handleSize: _handleSize,
                showGrid: widget.showGrid,
                showDimensions: widget.showDimensions,
                videoWidth: widget.videoWidth,
                videoHeight: widget.videoHeight,
              ),
              size: constraints.biggest,
            ),
          ),
        );
      },
    );
  }

  MouseCursor _getCursor() {
    if (!widget.enabled) return SystemMouseCursors.basic;

    switch (_activeHandle) {
      case _DragHandle.topLeft:
      case _DragHandle.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case _DragHandle.topRight:
      case _DragHandle.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
      case _DragHandle.top:
      case _DragHandle.bottom:
        return SystemMouseCursors.resizeUpDown;
      case _DragHandle.left:
      case _DragHandle.right:
        return SystemMouseCursors.resizeLeftRight;
      case _DragHandle.center:
        return SystemMouseCursors.move;
      case null:
        return SystemMouseCursors.precise;
    }
  }

  void _onPanStart(DragStartDetails details, Size canvasSize) {
    final localPos = details.localPosition;
    final normalizedPos = Offset(
      localPos.dx / canvasSize.width,
      localPos.dy / canvasSize.height,
    );

    if (_currentCrop != null) {
      // Check if hit a handle
      final handle = _hitTestHandle(localPos, _currentCrop!, canvasSize);
      if (handle != null) {
        setState(() {
          _activeHandle = handle;
          _dragStart = normalizedPos;
          _cropAtDragStart = _currentCrop;
        });
        return;
      }

      // Check if inside crop (move)
      if (_isInsideCrop(normalizedPos, _currentCrop!)) {
        setState(() {
          _activeHandle = _DragHandle.center;
          _dragStart = normalizedPos;
          _cropAtDragStart = _currentCrop;
        });
        return;
      }
    }

    // Start creating new crop
    setState(() {
      _isCreating = true;
      _createStart = normalizedPos;
      _currentCrop = CropRegion(
        x: normalizedPos.dx,
        y: normalizedPos.dy,
        width: 0,
        height: 0,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size canvasSize) {
    final localPos = details.localPosition;
    final normalizedPos = Offset(
      (localPos.dx / canvasSize.width).clamp(0.0, 1.0),
      (localPos.dy / canvasSize.height).clamp(0.0, 1.0),
    );

    if (_isCreating && _createStart != null) {
      // Creating new rectangle
      double x = normalizedPos.dx < _createStart!.dx ? normalizedPos.dx : _createStart!.dx;
      double y = normalizedPos.dy < _createStart!.dy ? normalizedPos.dy : _createStart!.dy;
      double w = (normalizedPos.dx - _createStart!.dx).abs();
      double h = (normalizedPos.dy - _createStart!.dy).abs();

      // Apply aspect ratio constraint if set
      if (widget.aspectRatio != null) {
        final targetRatio = widget.aspectRatio!;
        final currentRatio = w / (h == 0 ? 0.001 : h);

        if (currentRatio > targetRatio) {
          // Too wide, reduce width
          w = h * targetRatio;
        } else {
          // Too tall, reduce height
          h = w / targetRatio;
        }

        // Recalculate position based on drag direction
        if (normalizedPos.dx < _createStart!.dx) {
          x = _createStart!.dx - w;
        }
        if (normalizedPos.dy < _createStart!.dy) {
          y = _createStart!.dy - h;
        }
      }

      // Clamp to canvas bounds
      x = x.clamp(0.0, 1.0 - w);
      y = y.clamp(0.0, 1.0 - h);

      setState(() {
        _currentCrop = CropRegion(x: x, y: y, width: w, height: h);
      });
    } else if (_activeHandle != null && _dragStart != null && _cropAtDragStart != null) {
      final delta = normalizedPos - _dragStart!;
      setState(() {
        _currentCrop = _applyHandleDrag(_cropAtDragStart!, _activeHandle!, delta);
      });
    }
  }

  void _onPanEnd() {
    if (_currentCrop != null &&
        _currentCrop!.width > _minCropSize &&
        _currentCrop!.height > _minCropSize) {
      widget.onCropChanged(_currentCrop!);
    } else if (_currentCrop != null &&
        (_currentCrop!.width <= _minCropSize || _currentCrop!.height <= _minCropSize)) {
      // Reset to previous crop or null if too small
      _currentCrop = widget.crop;
    }

    setState(() {
      _activeHandle = null;
      _dragStart = null;
      _cropAtDragStart = null;
      _isCreating = false;
      _createStart = null;
    });
  }

  _DragHandle? _hitTestHandle(Offset pos, CropRegion crop, Size canvasSize) {
    final rect = Rect.fromLTWH(
      crop.x * canvasSize.width,
      crop.y * canvasSize.height,
      crop.width * canvasSize.width,
      crop.height * canvasSize.height,
    );

    final handles = <_DragHandle, Offset>{
      _DragHandle.topLeft: rect.topLeft,
      _DragHandle.topRight: rect.topRight,
      _DragHandle.bottomLeft: rect.bottomLeft,
      _DragHandle.bottomRight: rect.bottomRight,
      _DragHandle.top: Offset(rect.center.dx, rect.top),
      _DragHandle.bottom: Offset(rect.center.dx, rect.bottom),
      _DragHandle.left: Offset(rect.left, rect.center.dy),
      _DragHandle.right: Offset(rect.right, rect.center.dy),
    };

    for (final entry in handles.entries) {
      if ((entry.value - pos).distance < _handleHitArea) {
        return entry.key;
      }
    }
    return null;
  }

  bool _isInsideCrop(Offset pos, CropRegion crop) {
    return pos.dx >= crop.x &&
        pos.dx <= crop.x + crop.width &&
        pos.dy >= crop.y &&
        pos.dy <= crop.y + crop.height;
  }

  CropRegion _applyHandleDrag(CropRegion crop, _DragHandle handle, Offset delta) {
    double newX = crop.x;
    double newY = crop.y;
    double newWidth = crop.width;
    double newHeight = crop.height;

    switch (handle) {
      case _DragHandle.center:
        // Move entire crop
        newX = (crop.x + delta.dx).clamp(0.0, 1.0 - crop.width);
        newY = (crop.y + delta.dy).clamp(0.0, 1.0 - crop.height);
        break;

      case _DragHandle.topLeft:
        newX = crop.x + delta.dx;
        newY = crop.y + delta.dy;
        newWidth = crop.width - delta.dx;
        newHeight = crop.height - delta.dy;
        if (widget.aspectRatio != null) {
          final avgDelta = (delta.dx + delta.dy) / 2;
          newWidth = crop.width - avgDelta;
          newHeight = newWidth / widget.aspectRatio!;
          newX = crop.x + crop.width - newWidth;
          newY = crop.y + crop.height - newHeight;
        }
        break;

      case _DragHandle.topRight:
        newY = crop.y + delta.dy;
        newWidth = crop.width + delta.dx;
        newHeight = crop.height - delta.dy;
        if (widget.aspectRatio != null) {
          final avgDelta = (delta.dx - delta.dy) / 2;
          newWidth = crop.width + avgDelta;
          newHeight = newWidth / widget.aspectRatio!;
          newY = crop.y + crop.height - newHeight;
        }
        break;

      case _DragHandle.bottomLeft:
        newX = crop.x + delta.dx;
        newWidth = crop.width - delta.dx;
        newHeight = crop.height + delta.dy;
        if (widget.aspectRatio != null) {
          final avgDelta = (-delta.dx + delta.dy) / 2;
          newWidth = crop.width + avgDelta;
          newHeight = newWidth / widget.aspectRatio!;
          newX = crop.x + crop.width - newWidth;
        }
        break;

      case _DragHandle.bottomRight:
        newWidth = crop.width + delta.dx;
        newHeight = crop.height + delta.dy;
        if (widget.aspectRatio != null) {
          final avgDelta = (delta.dx + delta.dy) / 2;
          newWidth = crop.width + avgDelta;
          newHeight = newWidth / widget.aspectRatio!;
        }
        break;

      case _DragHandle.top:
        newY = crop.y + delta.dy;
        newHeight = crop.height - delta.dy;
        if (widget.aspectRatio != null) {
          newWidth = newHeight * widget.aspectRatio!;
          newX = crop.x + (crop.width - newWidth) / 2;
        }
        break;

      case _DragHandle.bottom:
        newHeight = crop.height + delta.dy;
        if (widget.aspectRatio != null) {
          newWidth = newHeight * widget.aspectRatio!;
          newX = crop.x + (crop.width - newWidth) / 2;
        }
        break;

      case _DragHandle.left:
        newX = crop.x + delta.dx;
        newWidth = crop.width - delta.dx;
        if (widget.aspectRatio != null) {
          newHeight = newWidth / widget.aspectRatio!;
          newY = crop.y + (crop.height - newHeight) / 2;
        }
        break;

      case _DragHandle.right:
        newWidth = crop.width + delta.dx;
        if (widget.aspectRatio != null) {
          newHeight = newWidth / widget.aspectRatio!;
          newY = crop.y + (crop.height - newHeight) / 2;
        }
        break;
    }

    // Enforce minimum size
    if (newWidth < _minCropSize) {
      if (handle == _DragHandle.left || handle == _DragHandle.topLeft || handle == _DragHandle.bottomLeft) {
        newX = crop.x + crop.width - _minCropSize;
      }
      newWidth = _minCropSize;
    }
    if (newHeight < _minCropSize) {
      if (handle == _DragHandle.top || handle == _DragHandle.topLeft || handle == _DragHandle.topRight) {
        newY = crop.y + crop.height - _minCropSize;
      }
      newHeight = _minCropSize;
    }

    // Clamp to canvas bounds
    newX = newX.clamp(0.0, 1.0 - _minCropSize);
    newY = newY.clamp(0.0, 1.0 - _minCropSize);
    newWidth = newWidth.clamp(_minCropSize, 1.0 - newX);
    newHeight = newHeight.clamp(_minCropSize, 1.0 - newY);

    return CropRegion(
      x: newX,
      y: newY,
      width: newWidth,
      height: newHeight,
    );
  }
}

/// Custom painter for the crop overlay
class _CropOverlayPainter extends CustomPainter {
  final CropRegion? crop;
  final _DragHandle? activeHandle;
  final double handleSize;
  final bool showGrid;
  final bool showDimensions;
  final int? videoWidth;
  final int? videoHeight;

  _CropOverlayPainter({
    this.crop,
    this.activeHandle,
    required this.handleSize,
    this.showGrid = true,
    this.showDimensions = true,
    this.videoWidth,
    this.videoHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (crop == null || crop!.width <= 0 || crop!.height <= 0) {
      // No crop - draw hint text
      _drawHintText(canvas, size);
      return;
    }

    final cropRect = Rect.fromLTWH(
      crop!.x * size.width,
      crop!.y * size.height,
      crop!.width * size.width,
      crop!.height * size.height,
    );

    // 1. Draw semi-transparent dark overlay outside crop
    _drawOverlay(canvas, size, cropRect);

    // 2. Draw rule-of-thirds grid inside crop
    if (showGrid) {
      _drawGrid(canvas, cropRect);
    }

    // 3. Draw crop rectangle border
    _drawCropBorder(canvas, cropRect);

    // 4. Draw resize handles at corners/edges
    _drawResizeHandles(canvas, cropRect);

    // 5. Draw dimension labels
    if (showDimensions) {
      _drawDimensions(canvas, size, cropRect);
    }
  }

  void _drawHintText(Canvas canvas, Size size) {
    const textSpan = TextSpan(
      text: 'Drag to create crop region',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        shadows: [
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1)),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  void _drawOverlay(Canvas canvas, Size size, Rect cropRect) {
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Draw four rectangles around the crop area
    // Top
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, cropRect.top),
      overlayPaint,
    );
    // Bottom
    canvas.drawRect(
      Rect.fromLTRB(0, cropRect.bottom, size.width, size.height),
      overlayPaint,
    );
    // Left
    canvas.drawRect(
      Rect.fromLTRB(0, cropRect.top, cropRect.left, cropRect.bottom),
      overlayPaint,
    );
    // Right
    canvas.drawRect(
      Rect.fromLTRB(cropRect.right, cropRect.top, size.width, cropRect.bottom),
      overlayPaint,
    );
  }

  void _drawGrid(Canvas canvas, Rect cropRect) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Rule of thirds - vertical lines
    final thirdWidth = cropRect.width / 3;
    canvas.drawLine(
      Offset(cropRect.left + thirdWidth, cropRect.top),
      Offset(cropRect.left + thirdWidth, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + thirdWidth * 2, cropRect.top),
      Offset(cropRect.left + thirdWidth * 2, cropRect.bottom),
      gridPaint,
    );

    // Rule of thirds - horizontal lines
    final thirdHeight = cropRect.height / 3;
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdHeight),
      Offset(cropRect.right, cropRect.top + thirdHeight),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdHeight * 2),
      Offset(cropRect.right, cropRect.top + thirdHeight * 2),
      gridPaint,
    );
  }

  void _drawCropBorder(Canvas canvas, Rect cropRect) {
    // Main border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(cropRect, borderPaint);

    // Corner accents (L-shaped marks)
    final accentPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    const accentLength = 20.0;

    // Top-left corner
    canvas.drawLine(
      cropRect.topLeft,
      cropRect.topLeft + const Offset(accentLength, 0),
      accentPaint,
    );
    canvas.drawLine(
      cropRect.topLeft,
      cropRect.topLeft + const Offset(0, accentLength),
      accentPaint,
    );

    // Top-right corner
    canvas.drawLine(
      cropRect.topRight,
      cropRect.topRight + const Offset(-accentLength, 0),
      accentPaint,
    );
    canvas.drawLine(
      cropRect.topRight,
      cropRect.topRight + const Offset(0, accentLength),
      accentPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      cropRect.bottomLeft,
      cropRect.bottomLeft + const Offset(accentLength, 0),
      accentPaint,
    );
    canvas.drawLine(
      cropRect.bottomLeft,
      cropRect.bottomLeft + const Offset(0, -accentLength),
      accentPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      cropRect.bottomRight,
      cropRect.bottomRight + const Offset(-accentLength, 0),
      accentPaint,
    );
    canvas.drawLine(
      cropRect.bottomRight,
      cropRect.bottomRight + const Offset(0, -accentLength),
      accentPaint,
    );
  }

  void _drawResizeHandles(Canvas canvas, Rect cropRect) {
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final handleBorderPaint = Paint()
      ..color = Colors.blue.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final activeHandlePaint = Paint()
      ..color = Colors.blue.shade400
      ..style = PaintingStyle.fill;

    final handles = <_DragHandle, Offset>{
      _DragHandle.topLeft: cropRect.topLeft,
      _DragHandle.topRight: cropRect.topRight,
      _DragHandle.bottomLeft: cropRect.bottomLeft,
      _DragHandle.bottomRight: cropRect.bottomRight,
      _DragHandle.top: Offset(cropRect.center.dx, cropRect.top),
      _DragHandle.bottom: Offset(cropRect.center.dx, cropRect.bottom),
      _DragHandle.left: Offset(cropRect.left, cropRect.center.dy),
      _DragHandle.right: Offset(cropRect.right, cropRect.center.dy),
    };

    for (final entry in handles.entries) {
      final isActive = entry.key == activeHandle;
      final isCorner = entry.key == _DragHandle.topLeft ||
          entry.key == _DragHandle.topRight ||
          entry.key == _DragHandle.bottomLeft ||
          entry.key == _DragHandle.bottomRight;

      // Draw larger handles for corners
      final size = isCorner ? handleSize : handleSize * 0.8;

      canvas.drawCircle(
        entry.value,
        size / 2,
        isActive ? activeHandlePaint : handlePaint,
      );
      canvas.drawCircle(entry.value, size / 2, handleBorderPaint);
    }
  }

  void _drawDimensions(Canvas canvas, Size canvasSize, Rect cropRect) {
    // Calculate pixel dimensions if video size is known
    String dimensionText;
    if (videoWidth != null && videoHeight != null) {
      final pixelWidth = (crop!.width * videoWidth!).round();
      final pixelHeight = (crop!.height * videoHeight!).round();
      final percentWidth = (crop!.width * 100).toStringAsFixed(0);
      final percentHeight = (crop!.height * 100).toStringAsFixed(0);
      dimensionText = '${pixelWidth}x$pixelHeight px ($percentWidth% x $percentHeight%)';
    } else {
      final percentWidth = (crop!.width * 100).toStringAsFixed(1);
      final percentHeight = (crop!.height * 100).toStringAsFixed(1);
      dimensionText = '$percentWidth% x $percentHeight%';
    }

    final textSpan = TextSpan(
      text: dimensionText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 1)),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Position below the crop rect, or above if no room
    double textY = cropRect.bottom + 8;
    if (textY + textPainter.height > canvasSize.height) {
      textY = cropRect.top - textPainter.height - 8;
    }

    // Center horizontally
    double textX = cropRect.center.dx - textPainter.width / 2;
    textX = textX.clamp(4, canvasSize.width - textPainter.width - 4);

    // Background for text
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        textX - 6,
        textY - 3,
        textPainter.width + 12,
        textPainter.height + 6,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      bgRect,
      Paint()..color = Colors.black.withOpacity(0.7),
    );

    textPainter.paint(canvas, Offset(textX, textY));

    // Also draw aspect ratio if crop exists
    if (crop!.width > 0 && crop!.height > 0) {
      final aspectRatio = crop!.width / crop!.height;
      final aspectText = _formatAspectRatio(aspectRatio);

      final aspectSpan = TextSpan(
        text: aspectText,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w400,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
          ],
        ),
      );

      final aspectPainter = TextPainter(
        text: aspectSpan,
        textDirection: TextDirection.ltr,
      );
      aspectPainter.layout();

      // Position in top-left of crop area
      final aspectX = cropRect.left + 6;
      final aspectY = cropRect.top + 6;

      // Background for aspect ratio
      final aspectBgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          aspectX - 4,
          aspectY - 2,
          aspectPainter.width + 8,
          aspectPainter.height + 4,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        aspectBgRect,
        Paint()..color = Colors.black.withOpacity(0.6),
      );

      aspectPainter.paint(canvas, Offset(aspectX, aspectY));
    }
  }

  String _formatAspectRatio(double ratio) {
    // Common aspect ratios - check each explicitly
    const tolerance = 0.02;

    if ((ratio - 16 / 9).abs() < tolerance) return '16:9';
    if ((ratio - 9 / 16).abs() < tolerance) return '9:16';
    if ((ratio - 4 / 3).abs() < tolerance) return '4:3';
    if ((ratio - 3 / 4).abs() < tolerance) return '3:4';
    if ((ratio - 1.0).abs() < tolerance) return '1:1';
    if ((ratio - 21 / 9).abs() < tolerance) return '21:9';
    if ((ratio - 9 / 21).abs() < tolerance) return '9:21';
    if ((ratio - 3 / 2).abs() < tolerance) return '3:2';
    if ((ratio - 2 / 3).abs() < tolerance) return '2:3';
    if ((ratio - 848 / 480).abs() < tolerance) return '848:480';
    if ((ratio - 480 / 848).abs() < tolerance) return '480:848';

    // Return decimal ratio
    return ratio.toStringAsFixed(2);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return crop != oldDelegate.crop ||
        activeHandle != oldDelegate.activeHandle ||
        showGrid != oldDelegate.showGrid ||
        showDimensions != oldDelegate.showDimensions ||
        videoWidth != oldDelegate.videoWidth ||
        videoHeight != oldDelegate.videoHeight;
  }
}
