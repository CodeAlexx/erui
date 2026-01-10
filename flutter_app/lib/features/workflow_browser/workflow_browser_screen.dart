import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'workflow_browser.dart';

/// Full-page workflow browser screen with comprehensive workflow management
class WorkflowBrowserScreen extends ConsumerStatefulWidget {
  const WorkflowBrowserScreen({super.key});

  @override
  ConsumerState<WorkflowBrowserScreen> createState() => _WorkflowBrowserScreenState();
}

class _WorkflowBrowserScreenState extends ConsumerState<WorkflowBrowserScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Full workflow browser panel
          Expanded(
            flex: 2,
            child: WorkflowBrowserPanel(
              onWorkflowSelected: (workflow) {
                // Select the workflow
                ref.read(workflowBrowserProvider.notifier).selectWorkflow(workflow.id);
              },
              onWorkflowEdit: (workflow) {
                // Navigate to editor with this workflow
                context.go('/workflow/edit/${workflow.id}');
              },
              onCreateNew: () {
                // Navigate to new workflow editor
                context.go('/workflow/new');
              },
              onImport: () {
                // Import handled by the panel itself
              },
            ),
          ),

          // Divider
          const VerticalDivider(width: 1),

          // Preview/Details panel
          Expanded(
            flex: 3,
            child: _WorkflowPreviewPanel(),
          ),
        ],
      ),
    );
  }
}

/// Preview panel showing selected workflow details
class _WorkflowPreviewPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final browserState = ref.watch(workflowBrowserProvider);
    final selectedWorkflow = browserState.selectedWorkflow;

    if (selectedWorkflow == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 64,
              color: colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a workflow to preview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a workflow from the list or create a new one',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              // Workflow icon/thumbnail
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: selectedWorkflow.image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildThumbnail(selectedWorkflow.image!, colorScheme),
                      )
                    : Icon(
                        Icons.account_tree,
                        size: 32,
                        color: colorScheme.onPrimaryContainer,
                      ),
              ),
              const SizedBox(width: 16),
              // Workflow info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedWorkflow.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (selectedWorkflow.description != null &&
                        selectedWorkflow.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        selectedWorkflow.description!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (selectedWorkflow.folder != null) ...[
                          Icon(Icons.folder, size: 14, color: colorScheme.outline),
                          const SizedBox(width: 4),
                          Text(
                            selectedWorkflow.folder!,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Icon(Icons.access_time, size: 14, color: colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(selectedWorkflow.updatedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                        ),
                        if (selectedWorkflow.enableInSimple) ...[
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Quick Generate',
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              Column(
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      // Navigate to editor
                      context.go('/workflow/edit/${selectedWorkflow.id}');
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Use workflow in generate screen
                      context.go('/generate?workflow=${selectedWorkflow.id}');
                    },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Use'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Parameters preview
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Parameters section
                Text(
                  'Parameters',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                _buildParametersList(context, selectedWorkflow),

                const SizedBox(height: 24),

                // Metadata section
                Text(
                  'Metadata',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                _buildMetadataSection(context, selectedWorkflow),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(String imageData, ColorScheme colorScheme) {
    try {
      if (imageData.startsWith('data:')) {
        final uri = Uri.parse(imageData);
        final bytes = uri.data?.contentAsBytes();
        if (bytes != null) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              Icons.account_tree,
              size: 32,
              color: colorScheme.onPrimaryContainer,
            ),
          );
        }
      }
    } catch (_) {}
    return Icon(
      Icons.account_tree,
      size: 32,
      color: colorScheme.onPrimaryContainer,
    );
  }

  Widget _buildParametersList(BuildContext context, EriWorkflow workflow) {
    final colorScheme = Theme.of(context).colorScheme;
    final params = workflow.parameters;

    if (params.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: colorScheme.outline),
            const SizedBox(width: 8),
            Text(
              'This workflow uses default parameters only',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Group parameters by group name
    final grouped = <String, List<EriWorkflowParam>>{};
    for (final param in params) {
      final group = param.group ?? 'General';
      grouped.putIfAbsent(group, () => []);
      grouped[group]!.add(param);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in grouped.entries) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${entry.value.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Parameters
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: entry.value.map((param) {
                      return SizedBox(
                        width: 200,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              param.name,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${param.type})',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetadataSection(BuildContext context, EriWorkflow workflow) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildMetadataRow(context, 'ID', workflow.id),
          _buildMetadataRow(context, 'Created', _formatDate(workflow.createdAt)),
          _buildMetadataRow(context, 'Modified', _formatDate(workflow.updatedAt)),
          _buildMetadataRow(
            context,
            'Quick Generate',
            workflow.enableInSimple ? 'Enabled' : 'Disabled',
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
