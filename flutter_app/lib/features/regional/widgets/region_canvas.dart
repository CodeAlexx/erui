import 'package:flutter/material.dart';
import '../../../models/prompt_region.dart';

/// Handle position for resizing regions
enum ResizeHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

/// Canvas widget for drawing and manipulating regions
class RegionCanvas extends StatefulWidget {
  /// List of regions to display
  final List<PromptRegion> regions;

  /// Currently selected region ID
  final String? selectedRegionId;

  /// Callback when a region is selected
  final ValueChanged<String?>? onRegionSelected;

  /// Callback when a region is updated
  final ValueChanged<PromptRegion>? onRegionUpdated;

  /// Callback when a new region is created
  final ValueChanged<PromptRegion>? onRegionCreated;

  /// Callback when a region is deleted
  final ValueChanged<String>? onRegionDeleted;

  /// Optional background image URL
  final String? backgroundImageUrl;

  /// Canvas aspect ratio (width/height)
  final double aspectRatio;

  /// Whether editing is enabled
  final bool enabled;

  const RegionCanvas({
    super.key,
    required this.regions,
    this.selectedRegionId,
    this.onRegionSelected,
    this.onRegionUpdated,
    this.onRegionCreated,
    this.onRegionDeleted,
    this.backgroundImageUrl,
    this.aspectRatio = 1.0,
    this.enabled = true,
  });

  @override
  State<RegionCanvas> createState() => _RegionCanvasState();
}

class _RegionCanvasState extends State<RegionCanvas> {
  // Interaction state
  bool _isDragging = false;
  bool _isCreating = false;
  ResizeHandle? _activeHandle;
  Offset? _dragStart;
  Rect? _creationRect;
  PromptRegion? _draggedRegion;

  static const double _handleSize = 10.0;
  static const double _handleHitArea = 16.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate canvas size maintaining aspect ratio
        double canvasWidth = constraints.maxWidth;
        double canvasHeight = constraints.maxWidth / widget.aspectRatio;

        if (canvasHeight > constraints.maxHeight) {
          canvasHeight = constraints.maxHeight;
          canvasWidth = canvasHeight * widget.aspectRatio;
        }

        final canvasSize = Size(canvasWidth, canvasHeight);

        return Center(
          child: Container(
            width: canvasWidth,
            height: canvasHeight,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  // Background grid or image
                  if (widget.backgroundImageUrl != null)
                    Positioned.fill(
                      child: Image.network(
                        widget.backgroundImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildGridBackground(canvasSize),
                      ),
                    )
                  else
                    _buildGridBackground(canvasSize),

                  // Regions layer
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: widget.enabled ? (d) => _handleTapDown(d, canvasSize) : null,
                      onPanStart: widget.enabled ? (d) => _handlePanStart(d, canvasSize) : null,
                      onPanUpdate: widget.enabled ? (d) => _handlePanUpdate(d, canvasSize) : null,
                      onPanEnd: widget.enabled ? (d) => _handlePanEnd(d, canvasSize) : null,
                      child: CustomPaint(
                        size: canvasSize,
                        painter: _RegionPainter(
                          regions: widget.regions,
                          selectedRegionId: widget.selectedRegionId,
                          creationRect: _creationRect,
                          handleSize: _handleSize,
                        ),
                      ),
                    ),
                  ),

                  // Delete buttons for selected region
                  if (widget.selectedRegionId != null && widget.enabled)
                    ..._buildDeleteButton(canvasSize),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridBackground(Size size) {
    return CustomPaint(
      size: size,
      painter: _GridPainter(
        gridSize: 20,
        color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
      ),
    );
  }

  List<Widget> _buildDeleteButton(Size canvasSize) {
    if (widget.selectedRegionId == null) return [];

    final regionFound = widget.regions.any((r) => r.id == widget.selectedRegionId);
    if (!regionFound) return [];

    final selectedRegion = widget.regions.firstWhere((r) => r.id == widget.selectedRegionId);
    final rect = selectedRegion.toPixelRect(canvasSize);

    return [
      Positioned(
        left: rect.right - 24,
        top: rect.top + 4,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => widget.onRegionDeleted?.call(selectedRegion.id),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ),
    ];
  }

  void _handleTapDown(TapDownDetails details, Size canvasSize) {
    final pos = details.localPosition;

    // Check if tapping on a region
    for (final region in widget.regions.reversed) {
      final rect = region.toPixelRect(canvasSize);
      if (rect.contains(pos)) {
        widget.onRegionSelected?.call(region.id);
        return;
      }
    }

    // Tapped on empty space - deselect
    widget.onRegionSelected?.call(null);
  }

  void _handlePanStart(DragStartDetails details, Size canvasSize) {
    final pos = details.localPosition;
    _dragStart = pos;

    // Check if starting on a resize handle of selected region
    if (widget.selectedRegionId != null &&
        widget.regions.any((r) => r.id == widget.selectedRegionId)) {
      final selectedRegion = widget.regions.firstWhere((r) => r.id == widget.selectedRegionId);
      final handle = _getHandleAtPosition(pos, selectedRegion.toPixelRect(canvasSize));
      if (handle != null) {
        setState(() {
          _activeHandle = handle;
          _draggedRegion = selectedRegion;
          _isDragging = true;
        });
        return;
      }
    }

    // Check if starting on a region (drag to move)
    for (final region in widget.regions.reversed) {
      final rect = region.toPixelRect(canvasSize);
      if (rect.contains(pos)) {
        widget.onRegionSelected?.call(region.id);
        setState(() {
          _draggedRegion = region;
          _isDragging = true;
          _activeHandle = null;
        });
        return;
      }
    }

    // Starting on empty space - create new region
    setState(() {
      _isCreating = true;
      _creationRect = Rect.fromPoints(pos, pos);
    });
  }

  void _handlePanUpdate(DragUpdateDetails details, Size canvasSize) {
    final pos = details.localPosition;

    if (_isCreating) {
      // Update creation rect
      setState(() {
        _creationRect = Rect.fromPoints(
          _dragStart!,
          Offset(
            pos.dx.clamp(0, canvasSize.width),
            pos.dy.clamp(0, canvasSize.height),
          ),
        );
      });
    } else if (_isDragging && _draggedRegion != null) {
      final delta = pos - _dragStart!;
      _dragStart = pos;

      if (_activeHandle != null) {
        // Resize
        _resizeRegion(delta, canvasSize);
      } else {
        // Move
        _moveRegion(delta, canvasSize);
      }
    }
  }

  void _handlePanEnd(DragEndDetails details, Size canvasSize) {
    if (_isCreating && _creationRect != null) {
      // Create new region if large enough
      if (_creationRect!.width > 20 && _creationRect!.height > 20) {
        final normalizedRect = Rect.fromLTWH(
          (_creationRect!.left / canvasSize.width).clamp(0.0, 1.0),
          (_creationRect!.top / canvasSize.height).clamp(0.0, 1.0),
          (_creationRect!.width / canvasSize.width).clamp(0.0, 1.0),
          (_creationRect!.height / canvasSize.height).clamp(0.0, 1.0),
        );

        final newRegion = PromptRegion(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          x: normalizedRect.left,
          y: normalizedRect.top,
          width: normalizedRect.width,
          height: normalizedRect.height,
          color: RegionColors.getNextColor(widget.regions),
        );

        widget.onRegionCreated?.call(newRegion);
        widget.onRegionSelected?.call(newRegion.id);
      }
    }

    setState(() {
      _isDragging = false;
      _isCreating = false;
      _activeHandle = null;
      _dragStart = null;
      _creationRect = null;
      _draggedRegion = null;
    });
  }

  void _moveRegion(Offset delta, Size canvasSize) {
    if (_draggedRegion == null) return;

    final normalizedDelta = Offset(
      delta.dx / canvasSize.width,
      delta.dy / canvasSize.height,
    );

    final newX = (_draggedRegion!.x + normalizedDelta.dx).clamp(0.0, 1.0 - _draggedRegion!.width);
    final newY = (_draggedRegion!.y + normalizedDelta.dy).clamp(0.0, 1.0 - _draggedRegion!.height);

    final updated = _draggedRegion!.copyWith(x: newX, y: newY);
    _draggedRegion = updated;
    widget.onRegionUpdated?.call(updated);
  }

  void _resizeRegion(Offset delta, Size canvasSize) {
    if (_draggedRegion == null || _activeHandle == null) return;

    final normalizedDelta = Offset(
      delta.dx / canvasSize.width,
      delta.dy / canvasSize.height,
    );

    double newX = _draggedRegion!.x;
    double newY = _draggedRegion!.y;
    double newWidth = _draggedRegion!.width;
    double newHeight = _draggedRegion!.height;

    switch (_activeHandle!) {
      case ResizeHandle.topLeft:
        newX += normalizedDelta.dx;
        newY += normalizedDelta.dy;
        newWidth -= normalizedDelta.dx;
        newHeight -= normalizedDelta.dy;
        break;
      case ResizeHandle.topRight:
        newY += normalizedDelta.dy;
        newWidth += normalizedDelta.dx;
        newHeight -= normalizedDelta.dy;
        break;
      case ResizeHandle.bottomLeft:
        newX += normalizedDelta.dx;
        newWidth -= normalizedDelta.dx;
        newHeight += normalizedDelta.dy;
        break;
      case ResizeHandle.bottomRight:
        newWidth += normalizedDelta.dx;
        newHeight += normalizedDelta.dy;
        break;
      case ResizeHandle.top:
        newY += normalizedDelta.dy;
        newHeight -= normalizedDelta.dy;
        break;
      case ResizeHandle.bottom:
        newHeight += normalizedDelta.dy;
        break;
      case ResizeHandle.left:
        newX += normalizedDelta.dx;
        newWidth -= normalizedDelta.dx;
        break;
      case ResizeHandle.right:
        newWidth += normalizedDelta.dx;
        break;
    }

    // Enforce minimum size
    const minSize = 0.05;
    if (newWidth < minSize || newHeight < minSize) return;

    // Clamp to canvas bounds
    newX = newX.clamp(0.0, 1.0 - minSize);
    newY = newY.clamp(0.0, 1.0 - minSize);
    newWidth = newWidth.clamp(minSize, 1.0 - newX);
    newHeight = newHeight.clamp(minSize, 1.0 - newY);

    final updated = _draggedRegion!.copyWith(
      x: newX,
      y: newY,
      width: newWidth,
      height: newHeight,
    );
    _draggedRegion = updated;
    widget.onRegionUpdated?.call(updated);
  }

  ResizeHandle? _getHandleAtPosition(Offset pos, Rect rect) {
    final handles = {
      ResizeHandle.topLeft: rect.topLeft,
      ResizeHandle.topRight: rect.topRight,
      ResizeHandle.bottomLeft: rect.bottomLeft,
      ResizeHandle.bottomRight: rect.bottomRight,
      ResizeHandle.top: Offset(rect.center.dx, rect.top),
      ResizeHandle.bottom: Offset(rect.center.dx, rect.bottom),
      ResizeHandle.left: Offset(rect.left, rect.center.dy),
      ResizeHandle.right: Offset(rect.right, rect.center.dy),
    };

    for (final entry in handles.entries) {
      if ((entry.value - pos).distance < _handleHitArea) {
        return entry.key;
      }
    }
    return null;
  }
}

/// Custom painter for drawing regions
class _RegionPainter extends CustomPainter {
  final List<PromptRegion> regions;
  final String? selectedRegionId;
  final Rect? creationRect;
  final double handleSize;

  _RegionPainter({
    required this.regions,
    required this.selectedRegionId,
    required this.creationRect,
    required this.handleSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw existing regions
    for (final region in regions) {
      final rect = region.toPixelRect(size);
      final isSelected = region.id == selectedRegionId;

      // Fill
      final fillPaint = Paint()
        ..color = region.color.withOpacity(isSelected ? 0.4 : 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      // Border
      final borderPaint = Paint()
        ..color = isSelected ? region.color : region.color.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 1.5;
      canvas.drawRect(rect, borderPaint);

      // Region label
      _drawRegionLabel(canvas, rect, region, isSelected);

      // Resize handles for selected region
      if (isSelected) {
        _drawResizeHandles(canvas, rect, region.color);
      }
    }

    // Draw creation preview
    if (creationRect != null) {
      final previewPaint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRect(creationRect!, previewPaint);

      final previewBorderPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(creationRect!, previewBorderPaint);
    }
  }

  void _drawRegionLabel(Canvas canvas, Rect rect, PromptRegion region, bool isSelected) {
    final textSpan = TextSpan(
      text: region.prompt.isEmpty
          ? 'Region ${regions.indexOf(region) + 1}'
          : (region.prompt.length > 20 ? '${region.prompt.substring(0, 20)}...' : region.prompt),
      style: TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 2, offset: const Offset(1, 1)),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: rect.width - 8);

    // Background for label
    final labelRect = Rect.fromLTWH(
      rect.left + 4,
      rect.top + 4,
      textPainter.width + 8,
      textPainter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(3)),
      Paint()..color = region.color.withOpacity(0.8),
    );

    textPainter.paint(canvas, Offset(rect.left + 8, rect.top + 6));
  }

  void _drawResizeHandles(Canvas canvas, Rect rect, Color color) {
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final handleBorderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final handles = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
      Offset(rect.center.dx, rect.top),
      Offset(rect.center.dx, rect.bottom),
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
    ];

    for (final pos in handles) {
      canvas.drawCircle(pos, handleSize / 2, handlePaint);
      canvas.drawCircle(pos, handleSize / 2, handleBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RegionPainter oldDelegate) {
    return regions != oldDelegate.regions ||
        selectedRegionId != oldDelegate.selectedRegionId ||
        creationRect != oldDelegate.creationRect;
  }
}

/// Custom painter for background grid
class _GridPainter extends CustomPainter {
  final double gridSize;
  final Color color;

  _GridPainter({required this.gridSize, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    // Vertical lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return gridSize != oldDelegate.gridSize || color != oldDelegate.color;
  }
}
