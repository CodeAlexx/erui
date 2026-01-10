import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/eri_workflow_models.dart';
import 'workflow_tile.dart';
import 'workflow_tree.dart';
import 'workflow_search.dart';

// Re-export for convenience
export 'models/eri_workflow_models.dart';

/// State for the workflow browser
class WorkflowBrowserState {
  final List<EriWorkflow> workflows;
  final String? selectedWorkflowId;
  final String? currentFolder;
  final String searchQuery;
  final bool isLoading;
  final String? error;
  final Set<String> expandedFolders;

  const WorkflowBrowserState({
    this.workflows = const [],
    this.selectedWorkflowId,
    this.currentFolder,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
    this.expandedFolders = const {},
  });

  WorkflowBrowserState copyWith({
    List<EriWorkflow>? workflows,
    String? selectedWorkflowId,
    String? currentFolder,
    String? searchQuery,
    bool? isLoading,
    String? error,
    Set<String>? expandedFolders,
    bool clearSelectedWorkflow = false,
    bool clearCurrentFolder = false,
    bool clearError = false,
  }) {
    return WorkflowBrowserState(
      workflows: workflows ?? this.workflows,
      selectedWorkflowId: clearSelectedWorkflow ? null : (selectedWorkflowId ?? this.selectedWorkflowId),
      currentFolder: clearCurrentFolder ? null : (currentFolder ?? this.currentFolder),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      expandedFolders: expandedFolders ?? this.expandedFolders,
    );
  }

  /// Get filtered workflows based on search query and current folder
  List<EriWorkflow> get filteredWorkflows {
    List<EriWorkflow> result = workflows;

    // Filter by folder
    if (currentFolder != null) {
      result = result.where((w) => w.folder == currentFolder).toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result.where((w) {
        return w.name.toLowerCase().contains(query) ||
            (w.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return result;
  }

  /// Get all unique folders from workflows
  List<String> get folders {
    final folderSet = <String>{};
    for (final workflow in workflows) {
      if (workflow.folder != null && workflow.folder!.isNotEmpty) {
        folderSet.add(workflow.folder!);
      }
    }
    return folderSet.toList()..sort();
  }

  /// Get workflow count for a folder
  int getWorkflowCount(String? folder) {
    if (folder == null) {
      return workflows.where((w) => w.folder == null || w.folder!.isEmpty).length;
    }
    return workflows.where((w) => w.folder == folder).length;
  }

  /// Get selected workflow
  EriWorkflow? get selectedWorkflow {
    if (selectedWorkflowId == null) return null;
    try {
      return workflows.firstWhere((w) => w.id == selectedWorkflowId);
    } catch (_) {
      return null;
    }
  }
}

/// Notifier for workflow browser state
class WorkflowBrowserNotifier extends StateNotifier<WorkflowBrowserState> {
  WorkflowBrowserNotifier() : super(const WorkflowBrowserState()) {
    loadWorkflows();
  }

  /// Load workflows from storage/API
  Future<void> loadWorkflows() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // TODO: Replace with actual API/storage call
      // For now, using sample data
      await Future.delayed(const Duration(milliseconds: 300));

      final workflows = [
        EriWorkflow(
          id: '1',
          name: 'Basic SDXL',
          description: 'Standard SDXL text-to-image workflow',
          folder: null,
          workflow: '{}',
          prompt: '{}',
          enableInSimple: true,
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        EriWorkflow(
          id: '2',
          name: 'SDXL with Refiner',
          description: 'SDXL with refiner pass for improved details',
          folder: 'Advanced',
          workflow: '{}',
          prompt: '{}',
          enableInSimple: false,
          createdAt: DateTime.now().subtract(const Duration(days: 14)),
          updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        EriWorkflow(
          id: '3',
          name: 'ControlNet Depth',
          description: 'Depth-guided image generation using ControlNet',
          folder: 'ControlNet',
          workflow: '{}',
          prompt: '{}',
          enableInSimple: true,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        EriWorkflow(
          id: '4',
          name: 'LoRA Stack',
          description: 'Multiple LoRAs combined for style mixing',
          folder: 'Advanced',
          workflow: '{}',
          prompt: '{}',
          enableInSimple: false,
          createdAt: DateTime.now().subtract(const Duration(days: 21)),
          updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        EriWorkflow(
          id: '5',
          name: 'Upscale 2x',
          description: 'Image upscaling with model-based upscaler',
          folder: 'Post-Processing',
          workflow: '{}',
          prompt: '{}',
          enableInSimple: true,
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        EriWorkflow(
          id: '6',
          name: 'AnimateDiff Basic',
          description: 'Basic video generation with AnimateDiff',
          folder: 'Video',
          workflow: '{}',
          prompt: '{}',
          enableInSimple: false,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          updatedAt: DateTime.now(),
        ),
      ];

      state = state.copyWith(
        workflows: workflows,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Select a workflow
  void selectWorkflow(String? workflowId) {
    if (workflowId == null) {
      state = state.copyWith(clearSelectedWorkflow: true);
    } else {
      state = state.copyWith(selectedWorkflowId: workflowId);
    }
  }

  /// Set current folder filter
  void setFolder(String? folder) {
    if (folder == null) {
      state = state.copyWith(clearCurrentFolder: true);
    } else {
      state = state.copyWith(currentFolder: folder);
    }
  }

  /// Update search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Toggle folder expansion
  void toggleFolderExpansion(String folder) {
    final expanded = Set<String>.from(state.expandedFolders);
    if (expanded.contains(folder)) {
      expanded.remove(folder);
    } else {
      expanded.add(folder);
    }
    state = state.copyWith(expandedFolders: expanded);
  }

  /// Duplicate a workflow
  Future<EriWorkflow?> duplicateWorkflow(String workflowId) async {
    EriWorkflow? original;
    for (final w in state.workflows) {
      if (w.id == workflowId) {
        original = w;
        break;
      }
    }
    if (original == null) return null;

    final duplicate = EriWorkflow(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${original.name} (Copy)',
      folder: original.folder,
      workflow: original.workflow,
      prompt: original.prompt,
      customParams: original.customParams,
      paramValues: original.paramValues,
      image: original.image,
      description: original.description,
      enableInSimple: original.enableInSimple,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final workflows = List<EriWorkflow>.from(state.workflows)..add(duplicate);
    state = state.copyWith(workflows: workflows);

    return duplicate;
  }

  /// Delete a workflow
  Future<bool> deleteWorkflow(String workflowId) async {
    final workflows = state.workflows.where((w) => w.id != workflowId).toList();
    state = state.copyWith(
      workflows: workflows,
      clearSelectedWorkflow: state.selectedWorkflowId == workflowId,
    );
    return true;
  }

  /// Refresh workflows
  Future<void> refresh() async {
    await loadWorkflows();
  }
}

/// Provider for workflow browser
final workflowBrowserProvider = StateNotifierProvider<WorkflowBrowserNotifier, WorkflowBrowserState>((ref) {
  return WorkflowBrowserNotifier();
});

/// Hierarchical workflow browser panel like SwarmUI's top-left workflow selector
class WorkflowBrowserPanel extends ConsumerStatefulWidget {
  /// Callback when a workflow is selected
  final void Function(dynamic workflow)? onWorkflowSelected;

  /// Callback when edit is requested for a workflow
  final void Function(EriWorkflow workflow)? onWorkflowEdit;

  /// Callback when creating a new workflow is requested
  final VoidCallback? onCreateNew;

  /// Callback when importing a workflow is requested
  final VoidCallback? onImport;

  /// Width of the panel
  final double? width;

  /// Whether to show in compact mode (hides header and footer)
  final bool compact;

  const WorkflowBrowserPanel({
    super.key,
    this.onWorkflowSelected,
    this.onWorkflowEdit,
    this.onCreateNew,
    this.onImport,
    this.width,
    this.compact = false,
  });

  @override
  ConsumerState<WorkflowBrowserPanel> createState() => _WorkflowBrowserPanelState();
}

class _WorkflowBrowserPanelState extends ConsumerState<WorkflowBrowserPanel> {
  bool _showFolderTree = true;

  @override
  void initState() {
    super.initState();
    // In compact mode, don't show folder tree by default
    if (widget.compact) {
      _showFolderTree = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final browserState = ref.watch(workflowBrowserProvider);

    return Container(
      width: widget.width,
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (hidden in compact mode)
          if (!widget.compact) ...[
            _WorkflowBrowserHeader(
              onCreateNew: widget.onCreateNew,
              onImport: _showImportDialog,
              onRefresh: () => ref.read(workflowBrowserProvider.notifier).refresh(),
              onToggleFolders: () => setState(() => _showFolderTree = !_showFolderTree),
              showFolders: _showFolderTree,
            ),
            const Divider(height: 1),
          ],

          // Search bar
          WorkflowSearchBar(
            initialValue: browserState.searchQuery,
            onSearch: (query) {
              ref.read(workflowBrowserProvider.notifier).setSearchQuery(query);
            },
          ),

          const Divider(height: 1),

          // Content area
          Expanded(
            child: browserState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : browserState.error != null
                    ? _buildErrorState(browserState.error!)
                    : widget.compact
                        // In compact mode, just show workflow list
                        ? _buildWorkflowList(browserState)
                        // In normal mode, show folder tree + workflow list
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Folder tree (collapsible)
                              if (_showFolderTree)
                                SizedBox(
                                  width: 160,
                                  child: WorkflowTree(
                                    folders: browserState.folders,
                                    currentFolder: browserState.currentFolder,
                                    expandedFolders: browserState.expandedFolders,
                                    workflowCounts: {
                                      for (final folder in browserState.folders)
                                        folder: browserState.getWorkflowCount(folder),
                                      '': browserState.getWorkflowCount(null),
                                    },
                                    onFolderSelected: (folder) {
                                      ref.read(workflowBrowserProvider.notifier).setFolder(folder);
                                    },
                                    onFolderToggle: (folder) {
                                      ref.read(workflowBrowserProvider.notifier).toggleFolderExpansion(folder);
                                    },
                                  ),
                                ),

                              if (_showFolderTree)
                                const VerticalDivider(width: 1),

                              // Workflow list
                              Expanded(
                                child: _buildWorkflowList(browserState),
                              ),
                            ],
                          ),
          ),

          // Footer with workflow count (hidden in compact mode)
          if (!widget.compact)
            _WorkflowBrowserFooter(
              totalCount: browserState.workflows.length,
              filteredCount: browserState.filteredWorkflows.length,
              currentFolder: browserState.currentFolder,
            ),
        ],
      ),
    );
  }

  Widget _buildWorkflowList(WorkflowBrowserState browserState) {
    final workflows = browserState.filteredWorkflows;

    if (workflows.isEmpty) {
      return _buildEmptyState(browserState);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: workflows.length,
      itemBuilder: (context, index) {
        final workflow = workflows[index];
        final isSelected = workflow.id == browserState.selectedWorkflowId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: WorkflowTile(
            workflow: workflow,
            isSelected: isSelected,
            onTap: () {
              ref.read(workflowBrowserProvider.notifier).selectWorkflow(workflow.id);
              widget.onWorkflowSelected?.call(workflow);
            },
            onDoubleTap: () {
              widget.onWorkflowEdit?.call(workflow);
            },
            onEdit: () => widget.onWorkflowEdit?.call(workflow),
            onDuplicate: () async {
              final duplicate = await ref.read(workflowBrowserProvider.notifier).duplicateWorkflow(workflow.id);
              if (duplicate != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Duplicated "${workflow.name}"')),
                );
              }
            },
            onExport: () => _showExportDialog(workflow),
            onDelete: () => _showDeleteConfirmation(workflow),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(WorkflowBrowserState browserState) {
    final colorScheme = Theme.of(context).colorScheme;

    String message;
    String actionLabel;
    VoidCallback? action;

    if (browserState.searchQuery.isNotEmpty) {
      message = 'No workflows match "${browserState.searchQuery}"';
      actionLabel = 'Clear Search';
      action = () => ref.read(workflowBrowserProvider.notifier).setSearchQuery('');
    } else if (browserState.currentFolder != null) {
      message = 'No workflows in "${browserState.currentFolder}"';
      actionLabel = 'View All';
      action = () => ref.read(workflowBrowserProvider.notifier).setFolder(null);
    } else {
      message = 'No workflows yet';
      actionLabel = 'Create New';
      action = widget.onCreateNew;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 48,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: action,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load workflows',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.read(workflowBrowserProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Workflow'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import a workflow from:'),
            SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onImport?.call();
            },
            icon: const Icon(Icons.file_upload),
            label: const Text('From File'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement clipboard import
            },
            icon: const Icon(Icons.content_paste),
            label: const Text('From Clipboard'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(EriWorkflow workflow) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export "${workflow.name}"'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export workflow as:'),
            SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement file export
            },
            icon: const Icon(Icons.file_download),
            label: const Text('Save to File'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement clipboard export
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Workflow copied to clipboard')),
              );
            },
            icon: const Icon(Icons.content_copy),
            label: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(EriWorkflow workflow) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workflow?'),
        content: Text('Are you sure you want to delete "${workflow.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(workflowBrowserProvider.notifier).deleteWorkflow(workflow.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted "${workflow.name}"')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Header widget for the workflow browser
class _WorkflowBrowserHeader extends StatelessWidget {
  final VoidCallback? onCreateNew;
  final VoidCallback? onImport;
  final VoidCallback? onRefresh;
  final VoidCallback? onToggleFolders;
  final bool showFolders;

  const _WorkflowBrowserHeader({
    this.onCreateNew,
    this.onImport,
    this.onRefresh,
    this.onToggleFolders,
    this.showFolders = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.account_tree,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Workflows',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          // Toggle folders button
          IconButton(
            icon: Icon(
              showFolders ? Icons.folder : Icons.folder_off,
              size: 20,
            ),
            onPressed: onToggleFolders,
            tooltip: showFolders ? 'Hide folders' : 'Show folders',
            visualDensity: VisualDensity.compact,
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: onRefresh,
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
          ),
          // Import button
          IconButton(
            icon: const Icon(Icons.file_upload, size: 20),
            onPressed: onImport,
            tooltip: 'Import',
            visualDensity: VisualDensity.compact,
          ),
          // New workflow button
          FilledButton.tonalIcon(
            onPressed: onCreateNew,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer widget showing workflow count
class _WorkflowBrowserFooter extends StatelessWidget {
  final int totalCount;
  final int filteredCount;
  final String? currentFolder;

  const _WorkflowBrowserFooter({
    required this.totalCount,
    required this.filteredCount,
    this.currentFolder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String countText;
    if (filteredCount == totalCount) {
      countText = '$totalCount workflow${totalCount == 1 ? '' : 's'}';
    } else {
      countText = '$filteredCount of $totalCount workflows';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (currentFolder != null) ...[
            Icon(
              Icons.folder,
              size: 14,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              currentFolder!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 12,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            countText,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
