import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'models/workflow_models.dart';
import 'providers/workflow_provider.dart';
import 'widgets/node_editor.dart';

/// Main workflow editor screen
class WorkflowScreen extends ConsumerWidget {
  const WorkflowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workflowEditorProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.account_tree),
            const SizedBox(width: 8),
            if (state.workflow != null) ...[
              Text(state.workflow!.name),
              if (state.isDirty)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '*',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
            ] else
              const Text('Workflow Editor'),
          ],
        ),
        actions: [
          // New workflow
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Workflow',
            onPressed: () => _newWorkflow(context, ref),
          ),
          // Open workflow
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open Workflow',
            onPressed: () => _openWorkflow(context, ref),
          ),
          // Save workflow
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Workflow',
            onPressed: state.workflow != null
                ? () => _saveWorkflow(context, ref)
                : null,
          ),
          const VerticalDivider(),
          // Import from JSON
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Import from ComfyUI JSON',
            onPressed: () => _importWorkflow(context, ref),
          ),
          // Export to JSON
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Export to ComfyUI JSON',
            onPressed: state.workflow != null
                ? () => _exportWorkflow(context, ref)
                : null,
          ),
          const VerticalDivider(),
          // Delete selected node
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Selected Node',
            onPressed: state.selectedNodeId != null
                ? () {
                    ref.read(workflowEditorProvider.notifier)
                        .removeNode(state.selectedNodeId!);
                  }
                : null,
          ),
        ],
      ),
      body: state.workflow == null
          ? _EmptyState(onNew: () => _newWorkflow(context, ref))
          : Row(
              children: [
                // Main editor canvas
                Expanded(
                  child: const NodeEditor(),
                ),
                // Properties panel
                if (state.selectedNodeId != null)
                  SizedBox(
                    width: 300,
                    child: _PropertiesPanel(
                      node: state.workflow!.nodes[state.selectedNodeId]!,
                    ),
                  ),
              ],
            ),
    );
  }

  void _newWorkflow(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: 'New Workflow');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Workflow'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Workflow Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(workflowEditorProvider.notifier)
                  .newWorkflow(name: controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _openWorkflow(BuildContext context, WidgetRef ref) async {
    final workflows = await ref.read(workflowEditorProvider.notifier)
        .getSavedWorkflows();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Workflow'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: workflows.isEmpty
              ? const Center(child: Text('No saved workflows'))
              : ListView.builder(
                  itemCount: workflows.length,
                  itemBuilder: (context, index) {
                    final workflow = workflows[index];
                    return ListTile(
                      leading: const Icon(Icons.account_tree),
                      title: Text(workflow.name),
                      subtitle: Text(
                        '${workflow.nodes.length} nodes • Modified ${_formatDate(workflow.modifiedAt)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          await ref.read(workflowEditorProvider.notifier)
                              .deleteWorkflow(workflow.id);
                          Navigator.of(context).pop();
                          _openWorkflow(context, ref);
                        },
                      ),
                      onTap: () {
                        ref.read(workflowEditorProvider.notifier)
                            .loadWorkflow(workflow);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  void _saveWorkflow(BuildContext context, WidgetRef ref) async {
    final success = await ref.read(workflowEditorProvider.notifier)
        .saveWorkflow();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Workflow saved' : 'Failed to save workflow'),
        ),
      );
    }
  }

  void _importWorkflow(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final json = await file.readAsString();

      ref.read(workflowEditorProvider.notifier).importFromComfyUI(
        json,
        name: result.files.single.name.replaceAll('.json', ''),
      );
    }
  }

  void _exportWorkflow(BuildContext context, WidgetRef ref) async {
    final json = ref.read(workflowEditorProvider.notifier).exportToComfyUI();
    if (json == null) return;

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: json));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workflow JSON copied to clipboard')),
      );
    }

    // Also offer to save to file
    final savePath = await FilePicker.platform.saveFile(
      fileName: '${ref.read(workflowEditorProvider).workflow?.name ?? 'workflow'}.json',
      allowedExtensions: ['json'],
    );

    if (savePath != null) {
      await File(savePath).writeAsString(json);
    }
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  final VoidCallback onNew;

  const _EmptyState({required this.onNew});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree,
            size: 64,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No workflow open',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new workflow or open an existing one',
            style: TextStyle(color: colorScheme.outline),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('New Workflow'),
            onPressed: onNew,
          ),
        ],
      ),
    );
  }
}

/// Properties panel for selected node
class _PropertiesPanel extends ConsumerWidget {
  final WorkflowNode node;

  const _PropertiesPanel({required this.node});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final definition = NodeDefinitions.getDefinition(node.type);

    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: (definition?.color ?? Colors.grey).withOpacity(0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  node.type,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Inputs
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Inputs',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (definition != null)
                  for (final input in definition.inputs)
                    _PropertyInput(
                      input: input,
                      value: node.inputValues[input.name],
                      onChanged: (value) {
                        ref.read(workflowEditorProvider.notifier)
                            .updateNodeInput(node.id, input.name, value);
                      },
                    ),
                const SizedBox(height: 16),
                Text(
                  'Outputs',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (definition != null)
                  for (final output in definition.outputs)
                    ListTile(
                      dense: true,
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getTypeColor(output.type),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(output.name),
                      subtitle: Text(output.type, style: TextStyle(color: colorScheme.outline)),
                    ),
              ],
            ),
          ),
          // Delete button
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete),
              label: const Text('Delete Node'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
              onPressed: () {
                ref.read(workflowEditorProvider.notifier).removeNode(node.id);
              },
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

/// Property input widget
class _PropertyInput extends StatelessWidget {
  final NodeInput input;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  const _PropertyInput({
    required this.input,
    this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getTypeColor(input.type),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                input.name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (input.required)
                Text(
                  ' *',
                  style: TextStyle(color: colorScheme.error),
                ),
            ],
          ),
          const SizedBox(height: 4),
          _buildInputWidget(context),
        ],
      ),
    );
  }

  Widget _buildInputWidget(BuildContext context) {
    switch (input.type.toUpperCase()) {
      case 'INT':
        return TextFormField(
          initialValue: (value ?? input.defaultValue)?.toString() ?? '',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter integer',
            helperText: input.min != null && input.max != null
                ? 'Range: ${input.min} - ${input.max}'
                : null,
          ),
          onChanged: (v) => onChanged(int.tryParse(v)),
        );

      case 'FLOAT':
        return Column(
          children: [
            if (input.min != null && input.max != null)
              Slider(
                value: ((value ?? input.defaultValue) as num?)?.toDouble() ?? 0,
                min: (input.min as num).toDouble(),
                max: (input.max as num).toDouble(),
                onChanged: (v) => onChanged(v),
              ),
            TextFormField(
              initialValue: (value ?? input.defaultValue)?.toString() ?? '',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter decimal',
                helperText: input.min != null && input.max != null
                    ? 'Range: ${input.min} - ${input.max}'
                    : null,
              ),
              onChanged: (v) => onChanged(double.tryParse(v)),
            ),
          ],
        );

      case 'STRING':
        if (input.options != null && input.options!.isNotEmpty) {
          return DropdownButtonFormField<String>(
            value: value?.toString() ?? input.defaultValue?.toString(),
            decoration: const InputDecoration(
              hintText: 'Select option',
            ),
            items: input.options!.map((o) => DropdownMenuItem(
              value: o,
              child: Text(o),
            )).toList(),
            onChanged: (v) => onChanged(v),
          );
        }
        return TextFormField(
          initialValue: (value ?? input.defaultValue)?.toString() ?? '',
          maxLines: input.name.toLowerCase().contains('text') ? 3 : 1,
          decoration: const InputDecoration(
            hintText: 'Enter text',
          ),
          onChanged: onChanged,
        );

      case 'BOOLEAN':
        return SwitchListTile(
          title: Text(input.name),
          value: (value ?? input.defaultValue) == true,
          onChanged: onChanged,
        );

      default:
        // Non-widget types (MODEL, CLIP, VAE, etc.) show connection status
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.link, color: Theme.of(context).colorScheme.outline),
              const SizedBox(width: 8),
              Text(
                'Connect ${input.type}',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        );
    }
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
      case 'INT':
        return Colors.blue;
      case 'FLOAT':
        return Colors.cyan;
      case 'STRING':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
