import 'package:flutter/material.dart';

import '../models/editor_models.dart';
import '../models/adjustment_layer_models.dart';

/// Widget for displaying adjustment layers on the timeline
class AdjustmentLayerWidget extends StatefulWidget {
  /// The adjustment layer to display
  final AdjustmentLayer layer;

  /// Zoom level in pixels per second
  final double pixelsPerSecond;

  /// Whether this layer is currently selected
  final bool isSelected;

  /// Called when the layer is tapped
  final VoidCallback? onTap;

  /// Called during drag updates
  final Function(DragUpdateDetails)? onDragUpdate;

  /// Called when drag ends
  final Function(DragEndDetails)? onDragEnd;

  /// Called during resize operations
  final Function(double deltaWidth, bool fromStart)? onResize;

  /// Called when resize ends
  final VoidCallback? onResizeEnd;

  /// Called to add an effect to this layer
  final VoidCallback? onAddEffect;

  const AdjustmentLayerWidget({
    super.key,
    required this.layer,
    required this.pixelsPerSecond,
    this.isSelected = false,
    this.onTap,
    this.onDragUpdate,
    this.onDragEnd,
    this.onResize,
    this.onResizeEnd,
    this.onAddEffect,
  });

  @override
  State<AdjustmentLayerWidget> createState() => _AdjustmentLayerWidgetState();
}

class _AdjustmentLayerWidgetState extends State<AdjustmentLayerWidget>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isResizingStart = false;
  bool _isResizingEnd = false;

  late AnimationController _selectionAnimController;
  late Animation<double> _selectionGlow;

  static const double _resizeHandleWidth = 8.0;
  static const double _minWidth = 50.0;

  @override
  void initState() {
    super.initState();
    _selectionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _selectionGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _selectionAnimController, curve: Curves.easeInOut),
    );

    if (widget.isSelected) {
      _selectionAnimController.forward();
    }
  }

  @override
  void didUpdateWidget(AdjustmentLayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _selectionAnimController.forward();
      } else {
        _selectionAnimController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _selectionAnimController.dispose();
    super.dispose();
  }

  double get _clipWidth {
    final width = widget.layer.duration.inSeconds * widget.pixelsPerSecond;
    return width.clamp(_minWidth, double.infinity);
  }

  Color get _layerColor => widget.layer.color ?? const Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: _getCursor(),
      child: AnimatedBuilder(
        animation: _selectionGlow,
        builder: (context, child) {
          return Container(
            width: _clipWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
                if (widget.isSelected)
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.4 * _selectionGlow.value),
                    blurRadius: 12 * _selectionGlow.value,
                    spreadRadius: 2 * _selectionGlow.value,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  // Main content
                  _buildLayerContent(colorScheme),

                  // Selection border
                  if (widget.isSelected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Disabled overlay
                  if (!widget.layer.effectsEnabled)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.visibility_off,
                            color: Colors.white.withOpacity(0.7),
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                  // Resize handles
                  if (_isHovered && widget.layer.effectsEnabled) ...[
                    _buildResizeHandle(true),
                    _buildResizeHandle(false),
                  ],

                  // Drag area
                  if (widget.layer.effectsEnabled)
                    Positioned(
                      left: _resizeHandleWidth,
                      right: _resizeHandleWidth,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: widget.onTap,
                        onDoubleTap: widget.onAddEffect,
                        onSecondaryTapUp: (details) =>
                            _showContextMenu(context, details.globalPosition),
                        onPanUpdate: widget.onDragUpdate,
                        onPanEnd: widget.onDragEnd,
                        behavior: HitTestBehavior.opaque,
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLayerContent(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _layerColor.withOpacity(0.6),
            _layerColor.withOpacity(0.3),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Pattern background (diagonal stripes)
          Positioned.fill(
            child: CustomPaint(
              painter: _AdjustmentPatternPainter(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(),
          ),

          // Effects preview
          if (widget.layer.effects.isNotEmpty)
            Positioned(
              bottom: 18,
              left: 6,
              right: 6,
              child: _buildEffectsList(),
            ),

          // Duration badge
          Positioned(
            bottom: 4,
            right: 6,
            child: _buildDurationBadge(),
          ),

          // Blend mode badge
          if (widget.layer.blendMode != AdjustmentBlendMode.normal)
            Positioned(
              bottom: 4,
              left: 6,
              child: _buildBlendModeBadge(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.5),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.layers,
            size: 14,
            color: Colors.white.withOpacity(0.9),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.layer.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'ADJ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEffectsList() {
    final effectCount = widget.layer.effects.length;
    final displayCount = effectCount > 3 ? 3 : effectCount;

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        ...widget.layer.effects.take(displayCount).map((effect) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              effect.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }),
        if (effectCount > displayCount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '+${effectCount - displayCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDurationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        _formatDuration(widget.layer.duration),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBlendModeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.blender, size: 10, color: Colors.white.withOpacity(0.8)),
          const SizedBox(width: 2),
          Text(
            widget.layer.blendMode.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResizeHandle(bool isStart) {
    return Positioned(
      left: isStart ? 0 : null,
      right: isStart ? null : 0,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          setState(() {
            if (isStart) _isResizingStart = true;
            else _isResizingEnd = true;
          });
        },
        onHorizontalDragUpdate: (details) {
          widget.onResize?.call(details.delta.dx, isStart);
        },
        onHorizontalDragEnd: (_) {
          setState(() {
            _isResizingStart = false;
            _isResizingEnd = false;
          });
          widget.onResizeEnd?.call();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _resizeHandleWidth,
          decoration: BoxDecoration(
            color: (_isResizingStart && isStart) || (_isResizingEnd && !isStart)
                ? Colors.white.withOpacity(0.4)
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.horizontal(
              left: isStart ? const Radius.circular(6) : Radius.zero,
              right: isStart ? Radius.zero : const Radius.circular(6),
            ),
          ),
          child: Center(
            child: Container(
              width: 2,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  MouseCursor _getCursor() {
    if (!widget.layer.effectsEnabled) return SystemMouseCursors.forbidden;
    if (_isResizingStart || _isResizingEnd) return SystemMouseCursors.resizeColumn;
    return SystemMouseCursors.grab;
  }

  String _formatDuration(EditorTime duration) {
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toStringAsFixed(0).padLeft(2, '0')}';
  }

  void _showContextMenu(BuildContext context, Offset globalPosition) {
    final colorScheme = Theme.of(context).colorScheme;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'add_effect',
          child: Row(
            children: [
              Icon(Icons.add, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Add Effect'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'toggle_enabled',
          child: Row(
            children: [
              Icon(
                widget.layer.effectsEnabled ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(widget.layer.effectsEnabled ? 'Disable' : 'Enable'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 8),
              const Text('Duplicate'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: colorScheme.error),
              const SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: colorScheme.error)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'add_effect':
          widget.onAddEffect?.call();
          break;
        case 'toggle_enabled':
        case 'duplicate':
        case 'delete':
          // Handled by parent
          break;
      }
    });
  }
}

/// Painter for adjustment layer pattern background
class _AdjustmentPatternPainter extends CustomPainter {
  final Color color;

  _AdjustmentPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw diagonal stripes
    const spacing = 12.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AdjustmentPatternPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

/// Button to add adjustment layer to track
class AddAdjustmentLayerButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AddAdjustmentLayerButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton.icon(
      icon: Icon(Icons.layers, size: 16, color: colorScheme.tertiary),
      label: Text(
        'Adjustment Layer',
        style: TextStyle(fontSize: 12, color: colorScheme.tertiary),
      ),
      onPressed: onPressed,
    );
  }
}

