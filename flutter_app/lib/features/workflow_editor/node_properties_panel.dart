import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../workflow/models/workflow_models.dart';
import '../workflow/providers/workflow_provider.dart';
import 'workflow_node_widget.dart';

/// Properties panel for editing selected node
///
/// Features:
/// - Node type info and description
/// - Editable input values (text, number, dropdown, etc.)
/// - Connection info
/// - Delete node button
class NodePropertiesPanel extends ConsumerStatefulWidget {
  /// ID of the selected node
  final String nodeId;

  /// Callback when delete is pressed
  final VoidCallback onDelete;

  const NodePropertiesPanel({
    super.key,
    required this.nodeId,
    required this.onDelete,
  });

  @override
  ConsumerState<NodePropertiesPanel> createState() => _NodePropertiesPanelState();
}

class _NodePropertiesPanelState extends ConsumerState<NodePropertiesPanel> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowEditorProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final node = state.workflow?.nodes[widget.nodeId];
    if (node == null) {
      return _buildEmptyState(colorScheme);
    }

    final definition = NodeDefinitions.getDefinition(node.type);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(context, node, definition, colorScheme),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Node info section
                _buildNodeInfoSection(node, definition, colorScheme),

                const SizedBox(height: 16),

                // Inputs section
                if (definition != null && definition.inputs.isNotEmpty) ...[
                  _buildSectionHeader('Inputs', Icons.input, colorScheme),
                  const SizedBox(height: 8),
                  ...definition.inputs.map((input) => _buildInputField(
                        input,
                        node,
                        state.workflow?.connections ?? [],
                        colorScheme,
                      )),
                ],

                const SizedBox(height: 16),

                // Outputs section
                if (definition != null && definition.outputs.isNotEmpty) ...[
                  _buildSectionHeader('Outputs', Icons.output, colorScheme),
                  const SizedBox(height: 8),
                  ...definition.outputs.map((output) => _buildOutputInfo(
                        output,
                        node,
                        state.workflow?.connections ?? [],
                        colorScheme,
                      )),
                ],

                const SizedBox(height: 16),

                // Connections section
                _buildConnectionsSection(node, state.workflow?.connections ?? [], colorScheme),

                const SizedBox(height: 24),

                // Delete button
                _buildDeleteButton(colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app,
              size: 40,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Select a node to\nedit properties',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WorkflowNode node,
    NodeDefinition? definition,
    ColorScheme colorScheme,
  ) {
    final nodeColor = definition?.color ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // Color indicator
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: nodeColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          // Title and type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Properties',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  node.type,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          // Close button
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Close',
            onPressed: () {
              ref.read(workflowEditorProvider.notifier).selectNode(null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNodeInfoSection(
    WorkflowNode node,
    NodeDefinition? definition,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node title (editable)
          Row(
            children: [
              Icon(
                Icons.label_outline,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (definition?.description.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              definition!.description,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Position info
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Position: (${node.position.dx.toStringAsFixed(0)}, ${node.position.dy.toStringAsFixed(0)})',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Node ID
          Row(
            children: [
              Icon(
                Icons.tag,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'ID: ${node.id}',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(
    NodeInput input,
    WorkflowNode node,
    List<WorkflowConnection> connections,
    ColorScheme colorScheme,
  ) {
    // Check if this input has a connection
    final connection = connections.firstWhere(
      (c) => c.targetNodeId == node.id && c.targetInput == input.name,
      orElse: () => WorkflowConnection(
        id: '',
        sourceNodeId: '',
        sourceOutput: 0,
        targetNodeId: '',
        targetInput: '',
      ),
    );
    final isConnected = connection.id.isNotEmpty;

    final currentValue = node.inputValues[input.name] ?? input.defaultValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input label with type indicator
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: getDataTypeColor(input.type),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  input.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                input.type,
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Input widget or connection info
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Connected from ${connection.sourceNodeId}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            )
          else
            _buildInputWidget(input, currentValue, node.id, colorScheme),
        ],
      ),
    );
  }

  Widget _buildInputWidget(
    NodeInput input,
    dynamic currentValue,
    String nodeId,
    ColorScheme colorScheme,
  ) {
    switch (input.type.toUpperCase()) {
      case 'INT':
        return _IntInputWidget(
          value: currentValue is int ? currentValue : int.tryParse(currentValue?.toString() ?? ''),
          min: input.min is int ? input.min as int : null,
          max: input.max is int ? input.max as int : null,
          onChanged: (v) => _updateInput(nodeId, input.name, v),
        );

      case 'FLOAT':
        return _FloatInputWidget(
          value: currentValue is double
              ? currentValue
              : double.tryParse(currentValue?.toString() ?? ''),
          min: input.min is num ? (input.min as num).toDouble() : null,
          max: input.max is num ? (input.max as num).toDouble() : null,
          onChanged: (v) => _updateInput(nodeId, input.name, v),
        );

      case 'STRING':
        if (input.options != null && input.options!.isNotEmpty) {
          return _DropdownInputWidget(
            value: currentValue?.toString(),
            options: input.options!,
            onChanged: (v) => _updateInput(nodeId, input.name, v),
          );
        }
        return _TextInputWidget(
          value: currentValue?.toString() ?? '',
          multiline: input.name.toLowerCase().contains('text') ||
              input.name.toLowerCase().contains('prompt'),
          onChanged: (v) => _updateInput(nodeId, input.name, v),
        );

      case 'BOOLEAN':
        return _BooleanInputWidget(
          value: currentValue is bool ? currentValue : false,
          onChanged: (v) => _updateInput(nodeId, input.name, v),
        );

      default:
        // For connectable types, show a placeholder
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Connect from another node',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );
    }
  }

  void _updateInput(String nodeId, String inputName, dynamic value) {
    ref.read(workflowEditorProvider.notifier).updateNodeInput(
          nodeId,
          inputName,
          value,
        );
  }

  Widget _buildOutputInfo(
    NodeOutput output,
    WorkflowNode node,
    List<WorkflowConnection> connections,
    ColorScheme colorScheme,
  ) {
    // Count connections from this output
    final outputConnections = connections
        .where((c) => c.sourceNodeId == node.id)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: getDataTypeColor(output.type),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                output.name,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              output.type,
              style: TextStyle(
                fontSize: 9,
                fontFamily: 'monospace',
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (outputConnections.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${outputConnections.length}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionsSection(
    WorkflowNode node,
    List<WorkflowConnection> allConnections,
    ColorScheme colorScheme,
  ) {
    final incomingConnections = allConnections
        .where((c) => c.targetNodeId == node.id)
        .toList();
    final outgoingConnections = allConnections
        .where((c) => c.sourceNodeId == node.id)
        .toList();

    if (incomingConnections.isEmpty && outgoingConnections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Connections', Icons.cable, colorScheme),
        const SizedBox(height: 8),

        // Incoming connections
        if (incomingConnections.isNotEmpty) ...[
          Text(
            'Incoming (${incomingConnections.length})',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          ...incomingConnections.map((conn) => _ConnectionChip(
                connection: conn,
                isIncoming: true,
                colorScheme: colorScheme,
                onDelete: () {
                  ref.read(workflowEditorProvider.notifier).removeConnection(conn.id);
                },
              )),
        ],

        if (incomingConnections.isNotEmpty && outgoingConnections.isNotEmpty)
          const SizedBox(height: 8),

        // Outgoing connections
        if (outgoingConnections.isNotEmpty) ...[
          Text(
            'Outgoing (${outgoingConnections.length})',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          ...outgoingConnections.map((conn) => _ConnectionChip(
                connection: conn,
                isIncoming: false,
                colorScheme: colorScheme,
                onDelete: () {
                  ref.read(workflowEditorProvider.notifier).removeConnection(conn.id);
                },
              )),
        ],
      ],
    );
  }

  Widget _buildDeleteButton(ColorScheme colorScheme) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.delete_outline, size: 18),
      label: const Text('Delete Node'),
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.error,
        side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Node'),
            content: const Text('Are you sure you want to delete this node?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDelete();
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Connection chip showing connection info with delete option
class _ConnectionChip extends StatelessWidget {
  final WorkflowConnection connection;
  final bool isIncoming;
  final ColorScheme colorScheme;
  final VoidCallback onDelete;

  const _ConnectionChip({
    required this.connection,
    required this.isIncoming,
    required this.colorScheme,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              isIncoming ? Icons.arrow_back : Icons.arrow_forward,
              size: 12,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isIncoming
                    ? '${connection.sourceNodeId} -> ${connection.targetInput}'
                    : '${connection.targetNodeId}.${connection.targetInput}',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Integer input widget with optional slider
class _IntInputWidget extends StatefulWidget {
  final int? value;
  final int? min;
  final int? max;
  final ValueChanged<int?> onChanged;

  const _IntInputWidget({
    this.value,
    this.min,
    this.max,
    required this.onChanged,
  });

  @override
  State<_IntInputWidget> createState() => _IntInputWidgetState();
}

class _IntInputWidgetState extends State<_IntInputWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _IntInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasRange = widget.min != null && widget.max != null;

    return Column(
      children: [
        // Text field
        TextField(
          controller: _controller,
          style: const TextStyle(fontSize: 12),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            isDense: true,
          ),
          onChanged: (text) {
            final value = int.tryParse(text);
            widget.onChanged(value);
          },
        ),

        // Slider if range is defined
        if (hasRange) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${widget.min}',
                style: TextStyle(
                  fontSize: 9,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Slider(
                  value: (widget.value ?? widget.min ?? 0)
                      .toDouble()
                      .clamp(widget.min!.toDouble(), widget.max!.toDouble()),
                  min: widget.min!.toDouble(),
                  max: widget.max!.toDouble(),
                  divisions: widget.max! - widget.min!,
                  onChanged: (v) {
                    final intValue = v.round();
                    _controller.text = intValue.toString();
                    widget.onChanged(intValue);
                  },
                ),
              ),
              Text(
                '${widget.max}',
                style: TextStyle(
                  fontSize: 9,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Float input widget with optional slider
class _FloatInputWidget extends StatefulWidget {
  final double? value;
  final double? min;
  final double? max;
  final ValueChanged<double?> onChanged;

  const _FloatInputWidget({
    this.value,
    this.min,
    this.max,
    required this.onChanged,
  });

  @override
  State<_FloatInputWidget> createState() => _FloatInputWidgetState();
}

class _FloatInputWidgetState extends State<_FloatInputWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toStringAsFixed(2) ?? '');
  }

  @override
  void didUpdateWidget(covariant _FloatInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value?.toStringAsFixed(2) ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasRange = widget.min != null && widget.max != null;

    return Column(
      children: [
        // Text field
        TextField(
          controller: _controller,
          style: const TextStyle(fontSize: 12),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            isDense: true,
          ),
          onChanged: (text) {
            final value = double.tryParse(text);
            widget.onChanged(value);
          },
        ),

        // Slider if range is defined
        if (hasRange) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                widget.min!.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 9,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Slider(
                  value: (widget.value ?? widget.min ?? 0)
                      .clamp(widget.min!, widget.max!),
                  min: widget.min!,
                  max: widget.max!,
                  onChanged: (v) {
                    _controller.text = v.toStringAsFixed(2);
                    widget.onChanged(v);
                  },
                ),
              ),
              Text(
                widget.max!.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 9,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Text input widget
class _TextInputWidget extends StatefulWidget {
  final String value;
  final bool multiline;
  final ValueChanged<String> onChanged;

  const _TextInputWidget({
    required this.value,
    this.multiline = false,
    required this.onChanged,
  });

  @override
  State<_TextInputWidget> createState() => _TextInputWidgetState();
}

class _TextInputWidgetState extends State<_TextInputWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _TextInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: _controller,
      style: const TextStyle(fontSize: 12),
      maxLines: widget.multiline ? 4 : 1,
      decoration: InputDecoration(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        isDense: true,
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// Dropdown input widget
class _DropdownInputWidget extends StatelessWidget {
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _DropdownInputWidget({
    this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButton<String>(
        value: options.contains(value) ? value : null,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurface,
        ),
        items: options
            .map((opt) => DropdownMenuItem(
                  value: opt,
                  child: Text(opt),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

/// Boolean input widget (switch)
class _BooleanInputWidget extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BooleanInputWidget({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
        ),
        Text(
          value ? 'Enabled' : 'Disabled',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
