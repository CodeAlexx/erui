import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../workflow/models/workflow_models.dart';
import '../workflow/providers/workflow_provider.dart';
import 'workflow_node_widget.dart';
import 'connection_painter.dart';

/// Interactive canvas for the workflow editor
///
/// Features:
/// - Pan and zoom via InteractiveViewer
/// - Grid background
/// - Node positioning and dragging
/// - Connection drawing with bezier curves
/// - Pending connection preview during drag
class WorkflowCanvas extends ConsumerStatefulWidget {
  /// Callback when a node is selected
  final void Function(String? nodeId)? onNodeSelected;

  const WorkflowCanvas({
    super.key,
    this.onNodeSelected,
  });

  @override
  ConsumerState<WorkflowCanvas> createState() => _WorkflowCanvasState();
}

class _WorkflowCanvasState extends ConsumerState<WorkflowCanvas> {
  /// Current mouse position for pending connection
  Offset? _pendingConnectionEnd;

  /// Whether user is currently panning the canvas
  bool _isPanning = false;

  /// Track if we're drawing a connection
  bool _isDrawingConnection = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowEditorProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRect(
      child: GestureDetector(
        // Canvas pan
        onPanStart: (details) {
          if (!_isDrawingConnection) {
            _isPanning = true;
          }
        },
        onPanUpdate: (details) {
          if (_isPanning && !_isDrawingConnection) {
            ref.read(workflowEditorProvider.notifier).updateViewOffset(
              state.viewOffset + details.delta,
            );
          }
        },
        onPanEnd: (_) {
          _isPanning = false;
        },
        // Tap to deselect
        onTap: () {
          ref.read(workflowEditorProvider.notifier).selectNode(null);
          widget.onNodeSelected?.call(null);
        },
        child: Listener(
          // Mouse wheel zoom
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              final delta = event.scrollDelta.dy > 0 ? -0.1 : 0.1;
              ref.read(workflowEditorProvider.notifier).updateZoom(
                state.zoom + delta,
              );
            }
          },
          // Track mouse for pending connection
          onPointerMove: (event) {
            if (state.pendingConnection != null) {
              setState(() {
                _pendingConnectionEnd = _screenToCanvas(
                  event.localPosition,
                  state.viewOffset,
                  state.zoom,
                );
              });
            }
          },
          child: Container(
            color: colorScheme.surfaceContainerLowest,
            child: Stack(
              children: [
                // Grid background
                _GridBackground(
                  offset: state.viewOffset,
                  zoom: state.zoom,
                  gridColor: colorScheme.outlineVariant.withOpacity(0.3),
                ),

                // Transform layer for nodes and connections
                Transform(
                  transform: Matrix4.identity()
                    ..translate(state.viewOffset.dx, state.viewOffset.dy)
                    ..scale(state.zoom),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Connections layer (behind nodes)
                      if (state.workflow != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ConnectionPainter(
                              connections: state.workflow!.connections,
                              nodes: state.workflow!.nodes,
                              pendingConnection: state.pendingConnection,
                              pendingEnd: _pendingConnectionEnd,
                              colorScheme: colorScheme,
                            ),
                          ),
                        ),

                      // Nodes layer
                      if (state.workflow != null)
                        for (final node in state.workflow!.nodes.values)
                          Positioned(
                            left: node.position.dx,
                            top: node.position.dy,
                            child: WorkflowNodeWidget(
                              node: node,
                              isSelected: state.selectedNodeId == node.id,
                              progress: state.nodeProgress[node.id],
                              zoom: state.zoom,
                              onTap: () {
                                ref.read(workflowEditorProvider.notifier).selectNode(node.id);
                                widget.onNodeSelected?.call(node.id);
                              },
                              onPositionChanged: (newPosition) {
                                ref.read(workflowEditorProvider.notifier)
                                    .updateNodePosition(node.id, newPosition);
                              },
                              onConnectionStart: (outputIndex) {
                                setState(() => _isDrawingConnection = true);
                                ref.read(workflowEditorProvider.notifier)
                                    .startConnection(node.id, outputIndex);
                              },
                              onConnectionEnd: (inputName) {
                                setState(() => _isDrawingConnection = false);
                                ref.read(workflowEditorProvider.notifier)
                                    .completeConnection(node.id, inputName);
                                setState(() => _pendingConnectionEnd = null);
                              },
                              onConnectionCancel: () {
                                setState(() {
                                  _isDrawingConnection = false;
                                  _pendingConnectionEnd = null;
                                });
                                ref.read(workflowEditorProvider.notifier).cancelConnection();
                              },
                            ),
                          ),
                    ],
                  ),
                ),

                // Execution status overlay
                if (state.isExecuting)
                  _ExecutionOverlay(colorScheme: colorScheme),

                // Error message overlay
                if (state.executionError != null)
                  _ErrorOverlay(
                    error: state.executionError!,
                    colorScheme: colorScheme,
                    onDismiss: () {
                      // Clear error by updating state
                    },
                  ),

                // Minimap (optional, top-right corner)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _Minimap(
                    nodes: state.workflow?.nodes ?? {},
                    viewOffset: state.viewOffset,
                    zoom: state.zoom,
                    colorScheme: colorScheme,
                  ),
                ),

                // Coordinates display
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Pan: (${state.viewOffset.dx.toStringAsFixed(0)}, ${state.viewOffset.dy.toStringAsFixed(0)})',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Convert screen coordinates to canvas coordinates
  Offset _screenToCanvas(Offset screen, Offset viewOffset, double zoom) {
    return (screen - viewOffset) / zoom;
  }
}

/// Grid background painter
class _GridBackground extends StatelessWidget {
  final Offset offset;
  final double zoom;
  final Color gridColor;

  const _GridBackground({
    required this.offset,
    required this.zoom,
    required this.gridColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GridPainter(
        offset: offset,
        zoom: zoom,
        color: gridColor,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Offset offset;
  final double zoom;
  final Color color;

  static const double _smallGridSize = 20.0;
  static const double _largeGridSize = 100.0;

  _GridPainter({
    required this.offset,
    required this.zoom,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Small grid
    final smallPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 0.5;

    final smallGridSize = _smallGridSize * zoom;
    final startX = offset.dx % smallGridSize;
    final startY = offset.dy % smallGridSize;

    // Only draw small grid when zoomed in enough
    if (zoom >= 0.5) {
      for (double x = startX; x < size.width; x += smallGridSize) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), smallPaint);
      }
      for (double y = startY; y < size.height; y += smallGridSize) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), smallPaint);
      }
    }

    // Large grid
    final largePaint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 1;

    final largeGridSize = _largeGridSize * zoom;
    final largeStartX = offset.dx % largeGridSize;
    final largeStartY = offset.dy % largeGridSize;

    for (double x = largeStartX; x < size.width; x += largeGridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), largePaint);
    }
    for (double y = largeStartY; y < size.height; y += largeGridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), largePaint);
    }

    // Origin crosshair
    if (offset.dx > 0 && offset.dx < size.width) {
      final originPaint = Paint()
        ..color = color.withOpacity(0.8)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(offset.dx, 0),
        Offset(offset.dx, size.height),
        originPaint,
      );
    }
    if (offset.dy > 0 && offset.dy < size.height) {
      final originPaint = Paint()
        ..color = color.withOpacity(0.8)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(0, offset.dy),
        Offset(size.width, offset.dy),
        originPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return offset != oldDelegate.offset ||
        zoom != oldDelegate.zoom ||
        color != oldDelegate.color;
  }
}

/// Execution status overlay
class _ExecutionOverlay extends StatelessWidget {
  final ColorScheme colorScheme;

  const _ExecutionOverlay({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Executing workflow...',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Error message overlay
class _ErrorOverlay extends StatelessWidget {
  final String error;
  final ColorScheme colorScheme;
  final VoidCallback onDismiss;

  const _ErrorOverlay({
    required this.error,
    required this.colorScheme,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: colorScheme.onErrorContainer),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimap showing overview of all nodes
class _Minimap extends StatelessWidget {
  final Map<String, WorkflowNode> nodes;
  final Offset viewOffset;
  final double zoom;
  final ColorScheme colorScheme;

  static const double _minimapWidth = 150;
  static const double _minimapHeight = 100;

  const _Minimap({
    required this.nodes,
    required this.viewOffset,
    required this.zoom,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) return const SizedBox.shrink();

    return Container(
      width: _minimapWidth,
      height: _minimapHeight,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: CustomPaint(
          size: const Size(_minimapWidth, _minimapHeight),
          painter: _MinimapPainter(
            nodes: nodes,
            viewOffset: viewOffset,
            zoom: zoom,
            nodeColor: colorScheme.primary.withOpacity(0.6),
            viewportColor: colorScheme.primary.withOpacity(0.3),
            borderColor: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final Map<String, WorkflowNode> nodes;
  final Offset viewOffset;
  final double zoom;
  final Color nodeColor;
  final Color viewportColor;
  final Color borderColor;

  _MinimapPainter({
    required this.nodes,
    required this.viewOffset,
    required this.zoom,
    required this.nodeColor,
    required this.viewportColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    // Calculate bounds of all nodes
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final node in nodes.values) {
      minX = node.position.dx < minX ? node.position.dx : minX;
      minY = node.position.dy < minY ? node.position.dy : minY;
      maxX = (node.position.dx + node.size.width) > maxX
          ? (node.position.dx + node.size.width)
          : maxX;
      maxY = (node.position.dy + node.size.height) > maxY
          ? (node.position.dy + node.size.height)
          : maxY;
    }

    // Add padding
    const padding = 50.0;
    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;

    final worldWidth = maxX - minX;
    final worldHeight = maxY - minY;

    // Calculate scale to fit in minimap
    final scaleX = size.width / worldWidth;
    final scaleY = size.height / worldHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Center offset
    final offsetX = (size.width - worldWidth * scale) / 2;
    final offsetY = (size.height - worldHeight * scale) / 2;

    // Draw nodes
    final nodePaint = Paint()..color = nodeColor;
    for (final node in nodes.values) {
      final rect = Rect.fromLTWH(
        offsetX + (node.position.dx - minX) * scale,
        offsetY + (node.position.dy - minY) * scale,
        node.size.width * scale,
        node.size.height * scale,
      );
      canvas.drawRect(rect, nodePaint);
    }

    // Draw viewport rectangle
    // The viewport in world coordinates is approximately:
    // x: -viewOffset.x / zoom
    // y: -viewOffset.y / zoom
    // width: viewportWidth / zoom
    // height: viewportHeight / zoom
    // For simplicity, we'll draw a fixed-size viewport indicator
    final viewportPaint = Paint()
      ..color = viewportColor
      ..style = PaintingStyle.fill;
    final viewportBorderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Estimate viewport in world space (assuming ~800x600 viewport)
    final viewportWorldX = -viewOffset.dx / zoom;
    final viewportWorldY = -viewOffset.dy / zoom;
    final viewportWorldWidth = 800 / zoom;
    final viewportWorldHeight = 600 / zoom;

    final viewportRect = Rect.fromLTWH(
      offsetX + (viewportWorldX - minX) * scale,
      offsetY + (viewportWorldY - minY) * scale,
      viewportWorldWidth * scale,
      viewportWorldHeight * scale,
    );

    canvas.drawRect(viewportRect, viewportPaint);
    canvas.drawRect(viewportRect, viewportBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) {
    return nodes != oldDelegate.nodes ||
        viewOffset != oldDelegate.viewOffset ||
        zoom != oldDelegate.zoom;
  }
}
