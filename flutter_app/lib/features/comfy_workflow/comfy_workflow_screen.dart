import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import 'widgets/workflow_card.dart';
import 'widgets/save_workflow_dialog.dart';

/// Workflow info model
class WorkflowInfo {
  final String name;
  final String filename;
  final String description;
  final List<String> tags;
  final String? previewImage;
  final bool isExample;
  final bool enableInGenerate;
  final String? modified;

  WorkflowInfo({
    required this.name,
    required this.filename,
    this.description = '',
    this.tags = const [],
    this.previewImage,
    this.isExample = false,
    this.enableInGenerate = true,
    this.modified,
  });

  factory WorkflowInfo.fromJson(Map<String, dynamic> json) {
    return WorkflowInfo(
      name: json['name'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      previewImage: json['preview_image'] as String?,
      isExample: json['is_example'] as bool? ?? false,
      enableInGenerate: json['enable_in_generate'] as bool? ?? true,
      modified: json['modified'] as String?,
    );
  }
}

/// Provider for workflow list
final workflowListProvider = FutureProvider<List<WorkflowInfo>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.getJson('/api/workflows');
  if (response != null && response['workflows'] != null) {
    return (response['workflows'] as List)
        .map((w) => WorkflowInfo.fromJson(w as Map<String, dynamic>))
        .toList();
  }
  return [];
});

/// Provider for search query
final workflowSearchProvider = StateProvider<String>((ref) => '');

/// Provider for filter (all, examples, custom)
final workflowFilterProvider = StateProvider<String>((ref) => 'all');

/// ComfyUI Workflow Browser - Native Flutter UI
class ComfyWorkflowScreen extends ConsumerStatefulWidget {
  const ComfyWorkflowScreen({super.key});

  @override
  ConsumerState<ComfyWorkflowScreen> createState() => _ComfyWorkflowScreenState();
}

class _ComfyWorkflowScreenState extends ConsumerState<ComfyWorkflowScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WorkflowInfo> _filterWorkflows(List<WorkflowInfo> workflows, String search, String filter) {
    var result = workflows;

    // Apply search filter
    if (search.isNotEmpty) {
      final query = search.toLowerCase();
      result = result.where((w) =>
        w.name.toLowerCase().contains(query) ||
        w.description.toLowerCase().contains(query) ||
        w.tags.any((t) => t.toLowerCase().contains(query))
      ).toList();
    }

    // Apply category filter
    if (filter == 'examples') {
      result = result.where((w) => w.isExample).toList();
    } else if (filter == 'custom') {
      result = result.where((w) => !w.isExample).toList();
    }

    return result;
  }

  Future<void> _useWorkflow(WorkflowInfo workflow) async {
    // Navigate to ComfyUI tab with workflow
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loading workflow: ${workflow.name}'),
        duration: const Duration(seconds: 1),
      ),
    );
    // Navigate to ComfyUI editor
    context.go('/comfyui');
  }

  Future<void> _deleteWorkflow(WorkflowInfo workflow) async {
    if (workflow.isExample) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete example workflows')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workflow'),
        content: Text('Are you sure you want to delete "${workflow.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final api = ref.read(apiServiceProvider);
      await api.deleteJson('/api/workflows/${workflow.filename}');
      ref.invalidate(workflowListProvider);
    }
  }

  Future<void> _saveNewWorkflow() async {
    final result = await SaveWorkflowDialog.show(context);
    if (result != null) {
      ref.invalidate(workflowListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final workflowsAsync = ref.watch(workflowListProvider);
    final searchQuery = ref.watch(workflowSearchProvider);
    final filter = ref.watch(workflowFilterProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.account_tree, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Comfy Workflow',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Action buttons
                _ActionButton(
                  icon: Icons.add,
                  label: 'Save New',
                  onPressed: _saveNewWorkflow,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.refresh,
                  label: 'Refresh',
                  onPressed: () => ref.invalidate(workflowListProvider),
                  color: colorScheme.secondary,
                ),
              ],
            ),
          ),

          // Search and Filter bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Search
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search workflows...',
                      hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
                      prefixIcon: Icon(Icons.search, color: colorScheme.onSurface.withOpacity(0.4)),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (v) => ref.read(workflowSearchProvider.notifier).state = v,
                  ),
                ),
                const SizedBox(width: 16),

                // Filter chips
                _FilterChip(
                  label: 'All',
                  isActive: filter == 'all',
                  onTap: () => ref.read(workflowFilterProvider.notifier).state = 'all',
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Examples',
                  isActive: filter == 'examples',
                  onTap: () => ref.read(workflowFilterProvider.notifier).state = 'examples',
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Custom',
                  isActive: filter == 'custom',
                  onTap: () => ref.read(workflowFilterProvider.notifier).state = 'custom',
                ),
              ],
            ),
          ),

          // Workflow Grid
          Expanded(
            child: workflowsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                    const SizedBox(height: 8),
                    Text('Error loading workflows', style: TextStyle(color: colorScheme.error)),
                    const SizedBox(height: 4),
                    Text(err.toString(), style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                  ],
                ),
              ),
              data: (workflows) {
                final filtered = _filterWorkflows(workflows, searchQuery, filter);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 48, color: colorScheme.onSurface.withOpacity(0.2)),
                        const SizedBox(height: 8),
                        Text(
                          searchQuery.isNotEmpty ? 'No workflows found' : 'No workflows yet',
                          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
                        ),
                        if (searchQuery.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _saveNewWorkflow,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Workflow'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final workflow = filtered[index];
                    return WorkflowCard(
                      workflow: workflow,
                      onUse: () => _useWorkflow(workflow),
                      onDelete: workflow.isExample ? null : () => _deleteWorkflow(workflow),
                    );
                  },
                );
              },
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                workflowsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (workflows) {
                    final filtered = _filterWorkflows(workflows, searchQuery, filter);
                    return Text(
                      '${filtered.length} workflow${filtered.length == 1 ? '' : 's'}',
                      style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12),
                    );
                  },
                ),
                const Spacer(),
                Text(
                  'Click to use • Right-click for options',
                  style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Action button widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primary : colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.6),
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
