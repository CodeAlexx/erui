import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../workflow/models/workflow_models.dart';

/// Visual representation of a workflow node
///
/// Features:
/// - Draggable positioning
/// - Color-coded header by category
/// - Input slots on left (circles)
/// - Output slots on right (circles)
/// - Selection highlight
/// - Collapse/expand support
/// - Progress indicator during execution
class WorkflowNodeWidget extends ConsumerStatefulWidget {
  final WorkflowNode node;
  final bool isSelected;
  final double? progress;
  final double zoom;
  final VoidCallback onTap;
  final void Function(Offset newPosition) onPositionChanged;
  final void Function(int outputIndex) onConnectionStart;
  final void Function(String inputName) onConnectionEnd;
  final VoidCallback onConnectionCancel;

  const WorkflowNodeWidget({
    super.key,
    required this.node,
    required this.isSelected,
    this.progress,
    required this.zoom,
    required this.onTap,
    required this.onPositionChanged,
    required this.onConnectionStart,
    required this.onConnectionEnd,
    required this.onConnectionCancel,
  });

  @override
  ConsumerState<WorkflowNodeWidget> createState() => _WorkflowNodeWidgetState();
}

class _WorkflowNodeWidgetState extends ConsumerState<WorkflowNodeWidget> {
  bool _isDragging = false;
  Offset _dragStartPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final definition = NodeDefinitions.getDefinition(widget.node.type);
    final nodeColor = definition?.color ?? Colors.grey;
    final category = definition?.category ?? 'unknown';

    return GestureDetector(
      onTap: widget.onTap,
      onPanStart: (details) {
        setState(() {
          _isDragging = true;
          _dragStartPosition = widget.node.position;
        });
      },
      onPanUpdate: (details) {
        if (_isDragging) {
          widget.onPositionChanged(
            widget.node.position + details.delta / widget.zoom,
          );
        }
      },
      onPanEnd: (details) {
        setState(() => _isDragging = false);
      },
      child: Container(
        width: widget.node.size.width,
        constraints: BoxConstraints(
          minHeight: widget.node.isCollapsed ? 40 : 80,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isSelected
                ? colorScheme.primary
                : (_isDragging ? colorScheme.tertiary : colorScheme.outline),
            width: widget.isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isSelected
                  ? colorScheme.primary.withOpacity(0.3)
                  : Colors.black.withOpacity(0.15),
              blurRadius: widget.isSelected ? 12 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with node type name
            _NodeHeader(
              title: widget.node.title,
              color: nodeColor,
              category: category,
              isCollapsed: widget.node.isCollapsed,
            ),

            // Progress indicator
            if (widget.progress != null)
              LinearProgressIndicator(
                value: widget.progress,
                backgroundColor: colorScheme.surfaceContainerHighest,
                minHeight: 3,
              ),

            // Content (inputs/outputs)
            if (!widget.node.isCollapsed) ...[
              // Inputs
              if (definition != null && definition.inputs.isNotEmpty)
                _InputSlots(
                  inputs: definition.inputs,
                  inputValues: widget.node.inputValues,
                  connections: [], // Would need to pass from parent
                  onConnectionEnd: widget.onConnectionEnd,
                ),

              // Divider between inputs and outputs
              if (definition != null &&
                  definition.inputs.isNotEmpty &&
                  definition.outputs.isNotEmpty)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                ),

              // Outputs
              if (definition != null && definition.outputs.isNotEmpty)
                _OutputSlots(
                  outputs: definition.outputs,
                  onConnectionStart: widget.onConnectionStart,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Node header with title and category color
class _NodeHeader extends StatelessWidget {
  final String title;
  final Color color;
  final String category;
  final bool isCollapsed;

  const _NodeHeader({
    required this.title,
    required this.color,
    required this.category,
    required this.isCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(7),
          bottom: isCollapsed ? const Radius.circular(7) : Radius.zero,
        ),
      ),
      child: Row(
        children: [
          // Category icon
          Icon(
            _getCategoryIcon(category),
            size: 14,
            color: Colors.white.withOpacity(0.9),
          ),
          const SizedBox(width: 6),
          // Title
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Collapse indicator
          Icon(
            isCollapsed ? Icons.expand_more : Icons.expand_less,
            size: 16,
            color: Colors.white.withOpacity(0.7),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'loaders':
        return Icons.download;
      case 'sampling':
        return Icons.blur_on;
      case 'conditioning':
        return Icons.text_fields;
      case 'latent':
        return Icons.grid_4x4;
      case 'image':
        return Icons.image;
      case 'mask':
        return Icons.layers;
      default:
        return Icons.extension;
    }
  }
}

/// Input slots (left side of node)
class _InputSlots extends StatelessWidget {
  final List<NodeInput> inputs;
  final Map<String, dynamic> inputValues;
  final List<WorkflowConnection> connections;
  final void Function(String inputName) onConnectionEnd;

  const _InputSlots({
    required this.inputs,
    required this.inputValues,
    required this.connections,
    required this.onConnectionEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: inputs.map((input) {
          final isConnected = connections.any((c) => c.targetInput == input.name);
          final hasValue = inputValues.containsKey(input.name);
          final isConnectable = _isConnectableType(input.type);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
            child: Row(
              children: [
                // Connection socket
                GestureDetector(
                  onTap: () => onConnectionEnd(input.name),
                  child: Container(
                    width: 24,
                    height: 20,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(left: -6),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? _getTypeColor(input.type)
                            : (isConnectable
                                ? _getTypeColor(input.type).withOpacity(0.4)
                                : Colors.transparent),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isConnectable
                              ? _getTypeColor(input.type)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                // Input name
                Expanded(
                  child: Text(
                    input.name,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: isConnected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                // Value indicator (if has value and not connected)
                if (hasValue && !isConnected && !isConnectable)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      _formatValue(inputValues[input.name]),
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isConnectableType(String type) {
    // These types can receive connections
    return [
      'MODEL',
      'CLIP',
      'VAE',
      'CONDITIONING',
      'LATENT',
      'IMAGE',
      'MASK',
      'CONTROL_NET',
      'UPSCALE_MODEL',
    ].contains(type.toUpperCase());
  }

  String _formatValue(dynamic value) {
    if (value == null) return '?';
    final str = value.toString();
    if (str.length > 10) {
      return '${str.substring(0, 8)}...';
    }
    return str;
  }

  Color _getTypeColor(String type) {
    return getDataTypeColor(type);
  }
}

/// Output slots (right side of node)
class _OutputSlots extends StatelessWidget {
  final List<NodeOutput> outputs;
  final void Function(int outputIndex) onConnectionStart;

  const _OutputSlots({
    required this.outputs,
    required this.onConnectionStart,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: outputs.asMap().entries.map((entry) {
          final index = entry.key;
          final output = entry.value;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Output name
                Expanded(
                  child: Text(
                    output.name,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Connection socket
                GestureDetector(
                  onPanStart: (_) => onConnectionStart(index),
                  child: Container(
                    width: 24,
                    height: 20,
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: -6),
                      decoration: BoxDecoration(
                        color: _getTypeColor(output.type),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getTypeColor(String type) {
    return getDataTypeColor(type);
  }
}

/// Get color for a data type
Color getDataTypeColor(String type) {
  switch (type.toUpperCase()) {
    case 'MODEL':
      return const Color(0xFF9C27B0); // Purple
    case 'CLIP':
      return const Color(0xFFFFC107); // Amber
    case 'VAE':
      return const Color(0xFFF44336); // Red
    case 'CONDITIONING':
      return const Color(0xFFFF9800); // Orange
    case 'LATENT':
      return const Color(0xFFE91E63); // Pink
    case 'IMAGE':
      return const Color(0xFF4CAF50); // Green
    case 'MASK':
      return const Color(0xFFFFFFFF); // White
    case 'CONTROL_NET':
      return const Color(0xFF00BCD4); // Cyan
    case 'UPSCALE_MODEL':
      return const Color(0xFF3F51B5); // Indigo
    case 'INT':
      return const Color(0xFF2196F3); // Blue
    case 'FLOAT':
      return const Color(0xFF03A9F4); // Light Blue
    case 'STRING':
      return const Color(0xFF8BC34A); // Light Green
    case 'BOOLEAN':
      return const Color(0xFF795548); // Brown
    default:
      return const Color(0xFF9E9E9E); // Grey
  }
}

/// Get category color for a node
Color getCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'loaders':
      return const Color(0xFF9C27B0); // Purple
    case 'sampling':
      return const Color(0xFF2196F3); // Blue
    case 'conditioning':
      return const Color(0xFFFF9800); // Orange
    case 'latent':
      return const Color(0xFFE91E63); // Pink
    case 'image':
      return const Color(0xFF4CAF50); // Green
    case 'mask':
      return const Color(0xFF009688); // Teal
    default:
      return const Color(0xFF607D8B); // Blue Grey
  }
}
