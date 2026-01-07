import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workflow_models.dart';
import '../providers/workflow_provider.dart';

/// The main node editor canvas
class NodeEditor extends ConsumerStatefulWidget {
  const NodeEditor({super.key});

  @override
  ConsumerState<NodeEditor> createState() => _NodeEditorState();
}

class _NodeEditorState extends ConsumerState<NodeEditor> {
  Offset? _dragStart;
  Offset? _pendingConnectionEnd;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowEditorProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRect(
      child: GestureDetector(
        onPanStart: (details) {
          _dragStart = details.localPosition;
        },
        onPanUpdate: (details) {
          if (_dragStart != null) {
            ref.read(workflowEditorProvider.notifier).updateViewOffset(
              state.viewOffset + details.delta,
            );
          }
        },
        onPanEnd: (_) {
          _dragStart = null;
        },
        onTap: () {
          ref.read(workflowEditorProvider.notifier).selectNode(null);
        },
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              final delta = event.scrollDelta.dy > 0 ? -0.1 : 0.1;
              ref.read(workflowEditorProvider.notifier).updateZoom(
                state.zoom + delta,
              );
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
                ),

                // Transform layer for nodes and connections
                Transform(
                  transform: Matrix4.identity()
                    ..translate(state.viewOffset.dx, state.viewOffset.dy)
                    ..scale(state.zoom),
                  child: Stack(
                    children: [
                      // Connections
                      if (state.workflow != null)
                        CustomPaint(
                          size: Size.infinite,
                          painter: _ConnectionPainter(
                            connections: state.workflow!.connections,
                            nodes: state.workflow!.nodes,
                            pendingConnection: state.pendingConnection,
                            pendingEnd: _pendingConnectionEnd,
                            colorScheme: colorScheme,
                          ),
                        ),

                      // Nodes
                      if (state.workflow != null)
                        for (final node in state.workflow!.nodes.values)
                          Positioned(
                            left: node.position.dx,
                            top: node.position.dy,
                            child: _NodeWidget(
                              node: node,
                              isSelected: state.selectedNodeId == node.id,
                              progress: state.nodeProgress[node.id],
                              onConnectionStart: (outputIndex) {
                                ref.read(workflowEditorProvider.notifier)
                                    .startConnection(node.id, outputIndex);
                              },
                              onConnectionEnd: (inputName) {
                                ref.read(workflowEditorProvider.notifier)
                                    .completeConnection(node.id, inputName);
                              },
                            ),
                          ),
                    ],
                  ),
                ),

                // Pending connection line (follows mouse)
                if (state.pendingConnection != null)
                  MouseRegion(
                    onHover: (event) {
                      setState(() {
                        _pendingConnectionEnd = (event.localPosition - state.viewOffset) / state.zoom;
                      });
                    },
                  ),

                // Toolbar
                Positioned(
                  top: 8,
                  right: 8,
                  child: _EditorToolbar(),
                ),

                // Node palette
                if (state.workflow != null)
                  Positioned(
                    left: 8,
                    top: 8,
                    bottom: 8,
                    child: _NodePalette(),
                  ),

                // Execution status
                if (state.isExecuting)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Executing...',
                              style: TextStyle(color: colorScheme.onPrimaryContainer),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.stop, size: 16, color: colorScheme.onPrimaryContainer),
                              onPressed: () {
                                ref.read(workflowEditorProvider.notifier).cancelExecution();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Error message
                if (state.executionError != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: colorScheme.onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.executionError!,
                              style: TextStyle(color: colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
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
}

/// Grid background
class _GridBackground extends StatelessWidget {
  final Offset offset;
  final double zoom;

  const _GridBackground({
    required this.offset,
    required this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomPaint(
      size: Size.infinite,
      painter: _GridPainter(
        offset: offset,
        zoom: zoom,
        color: colorScheme.outlineVariant.withOpacity(0.3),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Offset offset;
  final double zoom;
  final Color color;

  _GridPainter({
    required this.offset,
    required this.zoom,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final gridSize = 50.0 * zoom;
    final startX = offset.dx % gridSize;
    final startY = offset.dy % gridSize;

    // Vertical lines
    for (double x = startX; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = startY; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return offset != oldDelegate.offset || zoom != oldDelegate.zoom;
  }
}

/// Connection painter
class _ConnectionPainter extends CustomPainter {
  final List<WorkflowConnection> connections;
  final Map<String, WorkflowNode> nodes;
  final WorkflowConnection? pendingConnection;
  final Offset? pendingEnd;
  final ColorScheme colorScheme;

  _ConnectionPainter({
    required this.connections,
    required this.nodes,
    this.pendingConnection,
    this.pendingEnd,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw existing connections
    for (final conn in connections) {
      final sourceNode = nodes[conn.sourceNodeId];
      final targetNode = nodes[conn.targetNodeId];
      if (sourceNode == null || targetNode == null) continue;

      final start = _getOutputPosition(sourceNode, conn.sourceOutput);
      final end = _getInputPosition(targetNode, conn.targetInput);

      _drawConnection(canvas, start, end, paint);
    }

    // Draw pending connection
    if (pendingConnection != null && pendingEnd != null) {
      final sourceNode = nodes[pendingConnection!.sourceNodeId];
      if (sourceNode != null) {
        final start = _getOutputPosition(sourceNode, pendingConnection!.sourceOutput);
        paint.color = colorScheme.primary.withOpacity(0.5);
        _drawConnection(canvas, start, pendingEnd!, paint);
      }
    }
  }

  Offset _getOutputPosition(WorkflowNode node, int outputIndex) {
    return Offset(
      node.position.dx + node.size.width,
      node.position.dy + 50 + outputIndex * 25,
    );
  }

  Offset _getInputPosition(WorkflowNode node, String inputName) {
    final definition = NodeDefinitions.getDefinition(node.type);
    if (definition == null) {
      return Offset(node.position.dx, node.position.dy + 50);
    }

    final inputIndex = definition.inputs.indexWhere((i) => i.name == inputName);
    return Offset(
      node.position.dx,
      node.position.dy + 50 + (inputIndex >= 0 ? inputIndex : 0) * 25,
    );
  }

  void _drawConnection(Canvas canvas, Offset start, Offset end, Paint paint) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    final controlDistance = (end.dx - start.dx).abs() / 2;
    path.cubicTo(
      start.dx + controlDistance,
      start.dy,
      end.dx - controlDistance,
      end.dy,
      end.dx,
      end.dy,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter oldDelegate) => true;
}

/// Node widget
class _NodeWidget extends ConsumerStatefulWidget {
  final WorkflowNode node;
  final bool isSelected;
  final double? progress;
  final void Function(int outputIndex) onConnectionStart;
  final void Function(String inputName) onConnectionEnd;

  const _NodeWidget({
    required this.node,
    required this.isSelected,
    this.progress,
    required this.onConnectionStart,
    required this.onConnectionEnd,
  });

  @override
  ConsumerState<_NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends ConsumerState<_NodeWidget> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final definition = NodeDefinitions.getDefinition(widget.node.type);
    final nodeColor = definition?.color ?? Colors.grey;

    return GestureDetector(
      onTap: () {
        ref.read(workflowEditorProvider.notifier).selectNode(widget.node.id);
      },
      onPanUpdate: (details) {
        final state = ref.read(workflowEditorProvider);
        ref.read(workflowEditorProvider.notifier).updateNodePosition(
          widget.node.id,
          widget.node.position + details.delta / state.zoom,
        );
      },
      child: Container(
        width: widget.node.size.width,
        constraints: BoxConstraints(minHeight: widget.node.size.height),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isSelected ? colorScheme.primary : colorScheme.outline,
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: nodeColor.withOpacity(0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.node.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Collapse button
                  InkWell(
                    onTap: () {
                      ref.read(workflowEditorProvider.notifier)
                          .toggleNodeCollapse(widget.node.id);
                    },
                    child: Icon(
                      widget.node.isCollapsed
                          ? Icons.expand_more
                          : Icons.expand_less,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),

            // Progress indicator
            if (widget.progress != null)
              LinearProgressIndicator(
                value: widget.progress,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),

            // Content
            if (!widget.node.isCollapsed) ...[
              // Inputs
              if (definition != null)
                for (final input in definition.inputs)
                  _InputSocket(
                    input: input,
                    value: widget.node.inputValues[input.name],
                    onValueChanged: (value) {
                      ref.read(workflowEditorProvider.notifier)
                          .updateNodeInput(widget.node.id, input.name, value);
                    },
                    onConnectionEnd: () => widget.onConnectionEnd(input.name),
                  ),

              const Divider(height: 1),

              // Outputs
              if (definition != null)
                for (var i = 0; i < definition.outputs.length; i++)
                  _OutputSocket(
                    output: definition.outputs[i],
                    onConnectionStart: () => widget.onConnectionStart(i),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Input socket widget
class _InputSocket extends StatelessWidget {
  final NodeInput input;
  final dynamic value;
  final ValueChanged<dynamic> onValueChanged;
  final VoidCallback onConnectionEnd;

  const _InputSocket({
    required this.input,
    this.value,
    required this.onValueChanged,
    required this.onConnectionEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Socket
          GestureDetector(
            onTap: onConnectionEnd,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getTypeColor(input.type),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Label and value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  input.name,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_isWidgetInput(input.type))
                  _InputWidget(
                    input: input,
                    value: value,
                    onChanged: onValueChanged,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isWidgetInput(String type) {
    return ['STRING', 'INT', 'FLOAT', 'BOOLEAN'].contains(type.toUpperCase());
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'MODEL':
        return Colors.purple;
      case 'CLIP':
        return Colors.yellow;
      case 'VAE':
        return Colors.red;
      case 'CONDITIONING':
        return Colors.orange;
      case 'LATENT':
        return Colors.pink;
      case 'IMAGE':
        return Colors.green;
      case 'MASK':
        return Colors.white;
      default:
        return Colors.grey;
    }
  }
}

/// Input widget for different types
class _InputWidget extends StatelessWidget {
  final NodeInput input;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  const _InputWidget({
    required this.input,
    this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (input.type.toUpperCase()) {
      case 'INT':
        return SizedBox(
          height: 24,
          child: TextField(
            controller: TextEditingController(text: (value ?? input.defaultValue)?.toString() ?? ''),
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => onChanged(int.tryParse(v)),
          ),
        );
      case 'FLOAT':
        return SizedBox(
          height: 24,
          child: TextField(
            controller: TextEditingController(text: (value ?? input.defaultValue)?.toString() ?? ''),
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => onChanged(double.tryParse(v)),
          ),
        );
      case 'STRING':
        if (input.options != null && input.options!.isNotEmpty) {
          return SizedBox(
            height: 24,
            child: DropdownButton<String>(
              value: value?.toString() ?? input.defaultValue?.toString(),
              isDense: true,
              items: input.options!.map((o) => DropdownMenuItem(
                value: o,
                child: Text(o, style: const TextStyle(fontSize: 11)),
              )).toList(),
              onChanged: (v) => onChanged(v),
            ),
          );
        }
        return SizedBox(
          height: 24,
          child: TextField(
            controller: TextEditingController(text: (value ?? input.defaultValue)?.toString() ?? ''),
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            ),
            onChanged: onChanged,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Output socket widget
class _OutputSocket extends StatelessWidget {
  final NodeOutput output;
  final VoidCallback onConnectionStart;

  const _OutputSocket({
    required this.output,
    required this.onConnectionStart,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            output.name,
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          // Socket
          GestureDetector(
            onPanStart: (_) => onConnectionStart(),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getTypeColor(output.type),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'MODEL':
        return Colors.purple;
      case 'CLIP':
        return Colors.yellow;
      case 'VAE':
        return Colors.red;
      case 'CONDITIONING':
        return Colors.orange;
      case 'LATENT':
        return Colors.pink;
      case 'IMAGE':
        return Colors.green;
      case 'MASK':
        return Colors.white;
      default:
        return Colors.grey;
    }
  }
}

/// Editor toolbar
class _EditorToolbar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workflowEditorProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zoom controls
            IconButton(
              icon: const Icon(Icons.zoom_out),
              tooltip: 'Zoom out',
              onPressed: () {
                ref.read(workflowEditorProvider.notifier).updateZoom(state.zoom - 0.1);
              },
            ),
            Text('${(state.zoom * 100).round()}%'),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              tooltip: 'Zoom in',
              onPressed: () {
                ref.read(workflowEditorProvider.notifier).updateZoom(state.zoom + 0.1);
              },
            ),
            const VerticalDivider(),
            // Fit view
            IconButton(
              icon: const Icon(Icons.fit_screen),
              tooltip: 'Fit in view',
              onPressed: () {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  ref.read(workflowEditorProvider.notifier).fitInView(box.size);
                }
              },
            ),
            // Reset view
            IconButton(
              icon: const Icon(Icons.center_focus_strong),
              tooltip: 'Reset view',
              onPressed: () {
                ref.read(workflowEditorProvider.notifier).resetView();
              },
            ),
            const VerticalDivider(),
            // Execute
            FilledButton.icon(
              icon: state.isExecuting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(state.isExecuting ? 'Running...' : 'Run'),
              onPressed: state.isExecuting
                  ? null
                  : () {
                      ref.read(workflowEditorProvider.notifier).executeWorkflow();
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// Node palette
class _NodePalette extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = NodeDefinitions.categories;

    return Card(
      child: SizedBox(
        width: 200,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Add Node',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final nodes = NodeDefinitions.getByCategory(category);

                  return ExpansionTile(
                    title: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    dense: true,
                    children: nodes.map((def) => ListTile(
                      dense: true,
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: def.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(def.title, style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        ref.read(workflowEditorProvider.notifier).addNode(def.type);
                      },
                    )).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
