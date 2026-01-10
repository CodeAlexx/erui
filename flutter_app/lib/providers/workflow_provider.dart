import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workflow_models.dart';
import '../services/workflow_storage_service.dart';

/// Workflow list state provider
final workflowProvider =
    StateNotifierProvider<WorkflowNotifier, WorkflowState>((ref) {
  final storageService = ref.watch(workflowStorageServiceProvider);
  return WorkflowNotifier(storageService);
});

/// Selected workflow provider
final selectedWorkflowProvider = StateProvider<EriWorkflow?>((ref) => null);

/// Selected workflow ID provider (for simpler comparisons)
final selectedWorkflowIdProvider = Provider<String?>((ref) {
  return ref.watch(selectedWorkflowProvider)?.id;
});

/// Current folder provider
final currentFolderProvider = StateProvider<String?>((ref) => null);

/// Workflow folders provider
final workflowFoldersProvider = FutureProvider<List<WorkflowFolder>>((ref) async {
  final storageService = ref.watch(workflowStorageServiceProvider);
  return storageService.getFolders();
});

/// Filtered workflows provider (based on current folder and search)
final filteredWorkflowsProvider = Provider<List<EriWorkflow>>((ref) {
  final state = ref.watch(workflowProvider);
  final currentFolder = ref.watch(currentFolderProvider);
  final searchQuery = ref.watch(workflowSearchQueryProvider);

  List<EriWorkflow> workflows = state.workflows;

  // Filter by folder
  if (currentFolder != null) {
    workflows = workflows.where((w) => w.folder == currentFolder).toList();
  } else {
    // Show root-level workflows when no folder is selected
    workflows = workflows.where((w) => w.folder == null || w.folder!.isEmpty).toList();
  }

  // Filter by search query
  if (searchQuery.isNotEmpty) {
    final lowerQuery = searchQuery.toLowerCase();
    workflows = workflows.where((w) {
      if (w.name.toLowerCase().contains(lowerQuery)) return true;
      if (w.description?.toLowerCase().contains(lowerQuery) ?? false) return true;
      if (w.tags?.any((tag) => tag.toLowerCase().contains(lowerQuery)) ?? false) return true;
      return false;
    }).toList();
  }

  return workflows;
});

/// Simple workflows provider (for quick generate tab)
final simpleWorkflowsProvider = Provider<List<EriWorkflow>>((ref) {
  final state = ref.watch(workflowProvider);
  return state.workflows.where((w) => w.enableInSimple).toList();
});

/// Workflow search query provider
final workflowSearchQueryProvider = StateProvider<String>((ref) => '');

/// Show workflow browser panel provider
final showWorkflowBrowserProvider = StateProvider<bool>((ref) => true);

/// Workflow state
class WorkflowState {
  /// All loaded workflows
  final List<EriWorkflow> workflows;

  /// Whether workflows are currently loading
  final bool isLoading;

  /// Current error message (if any)
  final String? error;

  /// Whether the initial load has completed
  final bool initialized;

  const WorkflowState({
    this.workflows = const [],
    this.isLoading = false,
    this.error,
    this.initialized = false,
  });

  WorkflowState copyWith({
    List<EriWorkflow>? workflows,
    bool? isLoading,
    String? error,
    bool? initialized,
  }) {
    return WorkflowState(
      workflows: workflows ?? this.workflows,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      initialized: initialized ?? this.initialized,
    );
  }

  /// Get workflows in a specific folder
  List<EriWorkflow> getWorkflowsInFolder(String? folder) {
    if (folder == null || folder.isEmpty) {
      return workflows.where((w) => w.folder == null || w.folder!.isEmpty).toList();
    }
    return workflows.where((w) => w.folder == folder).toList();
  }

  /// Get all unique folders from workflows
  Set<String> get folders {
    return workflows
        .where((w) => w.folder != null && w.folder!.isNotEmpty)
        .map((w) => w.folder!)
        .toSet();
  }
}

/// Workflow state notifier
class WorkflowNotifier extends StateNotifier<WorkflowState> {
  final WorkflowStorageService _storageService;

  WorkflowNotifier(this._storageService) : super(const WorkflowState()) {
    // Auto-load workflows on creation
    loadWorkflows();
  }

  /// Load all workflows from storage
  Future<void> loadWorkflows() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load example workflows if needed
      await _storageService.loadExampleWorkflows();

      // Load all workflows
      final workflows = await _storageService.getAllWorkflows();

      state = state.copyWith(
        workflows: workflows,
        isLoading: false,
        initialized: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load workflows: $e',
        initialized: true,
      );
    }
  }

  /// Reload workflows from storage
  Future<void> refresh() async {
    await loadWorkflows();
  }

  /// Save a workflow
  ///
  /// If the workflow is new (empty ID), it will be assigned a new ID.
  /// Returns the saved workflow.
  Future<EriWorkflow> saveWorkflow(EriWorkflow workflow) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final savedWorkflow = await _storageService.saveWorkflow(workflow);

      // Update the workflows list
      final workflows = List<EriWorkflow>.from(state.workflows);
      final existingIndex = workflows.indexWhere((w) => w.id == savedWorkflow.id);

      if (existingIndex >= 0) {
        workflows[existingIndex] = savedWorkflow;
      } else {
        workflows.insert(0, savedWorkflow);
      }

      state = state.copyWith(
        workflows: workflows,
        isLoading: false,
      );

      return savedWorkflow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to save workflow: $e',
      );
      rethrow;
    }
  }

  /// Delete a workflow
  Future<void> deleteWorkflow(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _storageService.deleteWorkflow(id);

      // Remove from the workflows list
      final workflows = state.workflows.where((w) => w.id != id).toList();

      state = state.copyWith(
        workflows: workflows,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete workflow: $e',
      );
      rethrow;
    }
  }

  /// Duplicate a workflow
  ///
  /// Creates a copy of the workflow with a new name.
  /// Returns the new workflow.
  Future<EriWorkflow> duplicateWorkflow(String id, String newName) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final newWorkflow = await _storageService.duplicateWorkflow(id, newName);

      // Add to the workflows list
      final workflows = List<EriWorkflow>.from(state.workflows);
      workflows.insert(0, newWorkflow);

      state = state.copyWith(
        workflows: workflows,
        isLoading: false,
      );

      return newWorkflow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to duplicate workflow: $e',
      );
      rethrow;
    }
  }

  /// Move a workflow to a different folder
  Future<void> moveWorkflow(String id, String? newFolder) async {
    final workflow = state.workflows.firstWhere((w) => w.id == id);
    final updated = workflow.copyWith(folder: newFolder);
    await saveWorkflow(updated);
  }

  /// Import a workflow from JSON
  Future<EriWorkflow> importWorkflow(String json) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final workflow = await _storageService.importFromJson(json);

      // Add to the workflows list
      final workflows = List<EriWorkflow>.from(state.workflows);
      workflows.insert(0, workflow);

      state = state.copyWith(
        workflows: workflows,
        isLoading: false,
      );

      return workflow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to import workflow: $e',
      );
      rethrow;
    }
  }

  /// Export a workflow to JSON
  Future<String> exportWorkflow(String id, {bool includeMetadata = true}) async {
    try {
      return await _storageService.exportToJson(id, includeMetadata: includeMetadata);
    } catch (e) {
      state = state.copyWith(error: 'Failed to export workflow: $e');
      rethrow;
    }
  }

  /// Search workflows by query
  List<EriWorkflow> searchWorkflows(String query) {
    if (query.isEmpty) return state.workflows;

    final lowerQuery = query.toLowerCase();
    return state.workflows.where((w) {
      if (w.name.toLowerCase().contains(lowerQuery)) return true;
      if (w.description?.toLowerCase().contains(lowerQuery) ?? false) return true;
      if (w.tags?.any((tag) => tag.toLowerCase().contains(lowerQuery)) ?? false) return true;
      if (w.folder?.toLowerCase().contains(lowerQuery) ?? false) return true;
      return false;
    }).toList();
  }

  /// Filter workflows by tag
  List<EriWorkflow> filterByTag(String tag) {
    final lowerTag = tag.toLowerCase();
    return state.workflows.where((w) {
      return w.tags?.any((t) => t.toLowerCase() == lowerTag) ?? false;
    }).toList();
  }

  /// Create a new folder
  Future<void> createFolder(String path) async {
    try {
      await _storageService.createFolder(path);
    } catch (e) {
      state = state.copyWith(error: 'Failed to create folder: $e');
      rethrow;
    }
  }

  /// Delete a folder
  Future<void> deleteFolder(String path, {bool deleteContents = false}) async {
    try {
      await _storageService.deleteFolder(path, deleteContents: deleteContents);
      await loadWorkflows(); // Reload to reflect changes
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete folder: $e');
      rethrow;
    }
  }

  /// Rename a folder
  Future<void> renameFolder(String oldPath, String newPath) async {
    try {
      await _storageService.renameFolder(oldPath, newPath);
      await loadWorkflows(); // Reload to reflect changes
    } catch (e) {
      state = state.copyWith(error: 'Failed to rename folder: $e');
      rethrow;
    }
  }

  /// Clear the current error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Get a workflow by ID
  EriWorkflow? getWorkflow(String id) {
    try {
      return state.workflows.firstWhere((w) => w.id == id);
    } catch (e) {
      return null;
    }
  }
}

/// Convenience extension for selecting workflows via ref
extension WorkflowSelectionExtension on WidgetRef {
  /// Select a workflow by ID
  void selectWorkflow(String? id) {
    if (id == null) {
      read(selectedWorkflowProvider.notifier).state = null;
      return;
    }

    final workflow = read(workflowProvider.notifier).getWorkflow(id);
    read(selectedWorkflowProvider.notifier).state = workflow;
  }

  /// Select a workflow directly
  void selectWorkflowDirect(EriWorkflow? workflow) {
    read(selectedWorkflowProvider.notifier).state = workflow;
  }

  /// Set the current folder
  void setCurrentFolder(String? folder) {
    read(currentFolderProvider.notifier).state = folder;
  }

  /// Set the search query
  void setWorkflowSearchQuery(String query) {
    read(workflowSearchQueryProvider.notifier).state = query;
  }

  /// Toggle the workflow browser panel visibility
  void toggleWorkflowBrowser() {
    read(showWorkflowBrowserProvider.notifier).state =
        !read(showWorkflowBrowserProvider);
  }
}
