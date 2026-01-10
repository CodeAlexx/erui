import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/workflow_models.dart';

/// Provider for the workflow storage service
final workflowStorageServiceProvider = Provider<WorkflowStorageService>((ref) {
  return WorkflowStorageService();
});

/// Persistent workflow storage using Hive
///
/// Provides CRUD operations for workflows, folder management,
/// import/export functionality, and example workflow loading.
class WorkflowStorageService {
  static const String _workflowBoxName = 'eri_workflows';
  static const String _folderBoxName = 'eri_workflow_folders';
  static const String _metadataBoxName = 'eri_workflow_metadata';

  static Box<String>? _workflowBox;
  static Box<String>? _folderBox;
  static Box<dynamic>? _metadataBox;

  static const _uuid = Uuid();

  /// Check if the service has been initialized
  static bool get isInitialized => _workflowBox != null && _workflowBox!.isOpen;

  /// Initialize the storage service
  ///
  /// Must be called before using any other methods.
  /// Typically called during app startup.
  static Future<void> init() async {
    if (isInitialized) return;

    _workflowBox = await Hive.openBox<String>(_workflowBoxName);
    _folderBox = await Hive.openBox<String>(_folderBoxName);
    _metadataBox = await Hive.openBox<dynamic>(_metadataBoxName);
  }

  /// Ensure the service is initialized
  Future<void> _ensureInitialized() async {
    if (!isInitialized) {
      await init();
    }
  }

  // ============================================
  // CRUD Operations
  // ============================================

  /// Save a workflow to storage
  ///
  /// If the workflow has no ID, a new UUID will be generated.
  /// Returns the saved workflow with its ID.
  Future<EriWorkflow> saveWorkflow(EriWorkflow workflow) async {
    await _ensureInitialized();

    // Generate ID if needed
    EriWorkflow workflowToSave = workflow;
    if (workflow.id.isEmpty) {
      workflowToSave = workflow.copyWith(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } else {
      workflowToSave = workflow.copyWith(updatedAt: DateTime.now());
    }

    // Save to Hive
    await _workflowBox!.put(workflowToSave.id, workflowToSave.encode());

    // Update folder if specified
    if (workflowToSave.folder != null) {
      await _ensureFolderExists(workflowToSave.folder!);
    }

    return workflowToSave;
  }

  /// Get a workflow by ID
  ///
  /// Returns null if the workflow is not found.
  Future<EriWorkflow?> getWorkflow(String id) async {
    await _ensureInitialized();

    final json = _workflowBox!.get(id);
    if (json == null) return null;

    try {
      return EriWorkflow.decode(json);
    } catch (e) {
      print('Error decoding workflow $id: $e');
      return null;
    }
  }

  /// Get all workflows
  ///
  /// Returns an empty list if no workflows exist.
  Future<List<EriWorkflow>> getAllWorkflows() async {
    await _ensureInitialized();

    final workflows = <EriWorkflow>[];
    for (final key in _workflowBox!.keys) {
      final json = _workflowBox!.get(key);
      if (json != null) {
        try {
          workflows.add(EriWorkflow.decode(json));
        } catch (e) {
          print('Error decoding workflow $key: $e');
        }
      }
    }

    // Sort by updatedAt (most recent first)
    workflows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return workflows;
  }

  /// Get workflows in a specific folder
  ///
  /// Pass null or empty string to get root-level workflows.
  Future<List<EriWorkflow>> getWorkflowsInFolder(String? folder) async {
    final allWorkflows = await getAllWorkflows();

    if (folder == null || folder.isEmpty) {
      return allWorkflows.where((w) => w.folder == null || w.folder!.isEmpty).toList();
    }

    return allWorkflows.where((w) => w.folder == folder).toList();
  }

  /// Get workflows that are enabled for simple/quick mode
  Future<List<EriWorkflow>> getSimpleWorkflows() async {
    final allWorkflows = await getAllWorkflows();
    return allWorkflows.where((w) => w.enableInSimple).toList();
  }

  /// Delete a workflow by ID
  ///
  /// Returns true if the workflow was deleted, false if it didn't exist.
  Future<bool> deleteWorkflow(String id) async {
    await _ensureInitialized();

    if (!_workflowBox!.containsKey(id)) {
      return false;
    }

    await _workflowBox!.delete(id);
    return true;
  }

  /// Delete multiple workflows
  Future<void> deleteWorkflows(List<String> ids) async {
    await _ensureInitialized();
    await _workflowBox!.deleteAll(ids);
  }

  /// Duplicate a workflow with a new name
  ///
  /// Returns the new workflow copy.
  Future<EriWorkflow> duplicateWorkflow(String id, String newName) async {
    final original = await getWorkflow(id);
    if (original == null) {
      throw Exception('Workflow not found: $id');
    }

    final copy = original.copyWith(
      id: _uuid.v4(),
      name: newName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return saveWorkflow(copy);
  }

  // ============================================
  // Folder Management
  // ============================================

  /// Get all folders
  ///
  /// Returns a list of all workflow folders.
  Future<List<WorkflowFolder>> getFolders() async {
    await _ensureInitialized();

    // Get all workflows to count items per folder
    final workflows = await getAllWorkflows();
    final folderCounts = <String, int>{};

    for (final workflow in workflows) {
      if (workflow.folder != null && workflow.folder!.isNotEmpty) {
        folderCounts[workflow.folder!] = (folderCounts[workflow.folder!] ?? 0) + 1;
      }
    }

    // Get explicit folders from storage
    final folders = <WorkflowFolder>[];
    for (final key in _folderBox!.keys) {
      final json = _folderBox!.get(key);
      if (json != null) {
        try {
          final data = jsonDecode(json) as Map<String, dynamic>;
          final folder = WorkflowFolder.fromJson(data);
          folders.add(WorkflowFolder(
            name: folder.name,
            parentFolder: folder.parentFolder,
            workflowCount: folderCounts[folder.path] ?? 0,
          ));
        } catch (e) {
          print('Error decoding folder $key: $e');
        }
      }
    }

    // Add implicit folders from workflows that aren't in storage
    for (final folderPath in folderCounts.keys) {
      if (!folders.any((f) => f.path == folderPath)) {
        final parts = folderPath.split('/');
        folders.add(WorkflowFolder(
          name: parts.last,
          parentFolder: parts.length > 1 ? parts.sublist(0, parts.length - 1).join('/') : null,
          workflowCount: folderCounts[folderPath] ?? 0,
        ));
      }
    }

    // Sort alphabetically
    folders.sort((a, b) => a.path.compareTo(b.path));
    return folders;
  }

  /// Create a new folder
  ///
  /// Creates parent folders if they don't exist.
  Future<void> createFolder(String path) async {
    await _ensureFolderExists(path);
  }

  /// Ensure a folder exists, creating it and parent folders if needed
  Future<void> _ensureFolderExists(String path) async {
    await _ensureInitialized();

    final parts = path.split('/');
    String? parentPath;

    for (int i = 0; i < parts.length; i++) {
      final folderName = parts[i];
      final currentPath = parts.sublist(0, i + 1).join('/');

      if (!_folderBox!.containsKey(currentPath)) {
        final folder = WorkflowFolder(
          name: folderName,
          parentFolder: parentPath,
        );
        await _folderBox!.put(currentPath, jsonEncode(folder.toJson()));
      }

      parentPath = currentPath;
    }
  }

  /// Delete a folder and optionally its contents
  ///
  /// If deleteContents is false, workflows in the folder are moved to root.
  Future<void> deleteFolder(String path, {bool deleteContents = false}) async {
    await _ensureInitialized();

    // Get workflows in this folder
    final workflows = await getWorkflowsInFolder(path);

    if (deleteContents) {
      // Delete all workflows in the folder
      await deleteWorkflows(workflows.map((w) => w.id).toList());
    } else {
      // Move workflows to root
      for (final workflow in workflows) {
        await saveWorkflow(workflow.copyWith(folder: null));
      }
    }

    // Delete the folder
    await _folderBox!.delete(path);

    // Delete any subfolders
    final allFolders = await getFolders();
    for (final folder in allFolders) {
      if (folder.path.startsWith('$path/')) {
        await _folderBox!.delete(folder.path);
      }
    }
  }

  /// Rename a folder
  Future<void> renameFolder(String oldPath, String newPath) async {
    await _ensureInitialized();

    // Update workflows in this folder
    final workflows = await getWorkflowsInFolder(oldPath);
    for (final workflow in workflows) {
      await saveWorkflow(workflow.copyWith(folder: newPath));
    }

    // Create new folder entry
    await _ensureFolderExists(newPath);

    // Delete old folder entry
    await _folderBox!.delete(oldPath);

    // Update subfolders
    final allFolders = await getFolders();
    for (final folder in allFolders) {
      if (folder.path.startsWith('$oldPath/')) {
        final newFolderPath = folder.path.replaceFirst(oldPath, newPath);

        // Update workflows in subfolder
        final subWorkflows = await getWorkflowsInFolder(folder.path);
        for (final workflow in subWorkflows) {
          await saveWorkflow(workflow.copyWith(folder: newFolderPath));
        }

        // Create new subfolder entry
        await _ensureFolderExists(newFolderPath);

        // Delete old subfolder entry
        await _folderBox!.delete(folder.path);
      }
    }
  }

  // ============================================
  // Import/Export
  // ============================================

  /// Import a workflow from JSON string
  ///
  /// Returns the imported workflow.
  Future<EriWorkflow> importFromJson(String json) async {
    final data = jsonDecode(json) as Map<String, dynamic>;

    // Check if this is a raw ComfyUI workflow or an EriWorkflow
    if (data.containsKey('workflow') && data.containsKey('prompt')) {
      // Already in EriWorkflow format
      final workflow = EriWorkflow.fromJson(data);
      return saveWorkflow(workflow.copyWith(id: '')); // Force new ID
    } else {
      // Raw ComfyUI workflow - convert it
      return importFromComfyUI(data);
    }
  }

  /// Export a workflow to JSON string
  ///
  /// If includeMetadata is false, only the ComfyUI prompt is exported.
  Future<String> exportToJson(String workflowId, {bool includeMetadata = true}) async {
    final workflow = await getWorkflow(workflowId);
    if (workflow == null) {
      throw Exception('Workflow not found: $workflowId');
    }

    if (includeMetadata) {
      return workflow.encode();
    } else {
      // Export just the ComfyUI prompt
      return workflow.prompt;
    }
  }

  /// Import a raw ComfyUI workflow
  ///
  /// Converts the ComfyUI format to EriWorkflow format.
  Future<EriWorkflow> importFromComfyUI(Map<String, dynamic> comfyWorkflow, {
    String? name,
    String? folder,
    String? description,
  }) async {
    // The comfyWorkflow could be either:
    // 1. A visual workflow (with nodes array)
    // 2. An execution prompt (with numbered node objects)

    String workflowJson;
    String promptJson;

    if (comfyWorkflow.containsKey('nodes') || comfyWorkflow.containsKey('links')) {
      // Visual workflow format
      workflowJson = jsonEncode(comfyWorkflow);
      // Convert to prompt format
      promptJson = _convertVisualToPrompt(comfyWorkflow);
    } else {
      // Already in prompt format
      promptJson = jsonEncode(comfyWorkflow);
      workflowJson = '{}'; // No visual representation
    }

    // Try to extract name from workflow
    final workflowName = name ?? _extractWorkflowName(comfyWorkflow) ?? 'Imported Workflow';

    final workflow = EriWorkflow(
      id: '',
      name: workflowName,
      folder: folder,
      workflow: workflowJson,
      prompt: promptJson,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return saveWorkflow(workflow);
  }

  /// Convert visual workflow format to execution prompt format
  String _convertVisualToPrompt(Map<String, dynamic> visualWorkflow) {
    // Basic conversion - in practice, ComfyUI handles this
    // This is a simplified version
    final nodes = visualWorkflow['nodes'] as List?;
    if (nodes == null) {
      return jsonEncode(visualWorkflow);
    }

    final prompt = <String, dynamic>{};
    for (final node in nodes) {
      final nodeData = node as Map<String, dynamic>;
      final nodeId = nodeData['id'].toString();

      prompt[nodeId] = {
        'class_type': nodeData['type'],
        'inputs': nodeData['widgets_values'] ?? {},
      };
    }

    return jsonEncode(prompt);
  }

  /// Try to extract a name from a ComfyUI workflow
  String? _extractWorkflowName(Map<String, dynamic> workflow) {
    // Try common metadata locations
    if (workflow.containsKey('extra')) {
      final extra = workflow['extra'] as Map<String, dynamic>?;
      if (extra != null && extra.containsKey('workflow')) {
        final workflowMeta = extra['workflow'] as Map<String, dynamic>?;
        if (workflowMeta != null && workflowMeta.containsKey('name')) {
          return workflowMeta['name'] as String?;
        }
      }
    }
    return null;
  }

  // ============================================
  // Example Workflows
  // ============================================

  /// Load example workflows from bundled assets
  ///
  /// Only loads if no workflows exist yet.
  Future<void> loadExampleWorkflows({bool forceReload = false}) async {
    await _ensureInitialized();

    // Check if we already have workflows
    if (!forceReload && _workflowBox!.isNotEmpty) {
      // Check metadata to see if examples were already loaded
      final examplesLoaded = _metadataBox!.get('examplesLoaded') as bool? ?? false;
      if (examplesLoaded) return;
    }

    try {
      // Load example workflows from assets
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;

      // Find workflow JSON files in assets
      final workflowAssets = manifest.keys
          .where((key) => key.startsWith('assets/example_workflows/') && key.endsWith('.json'))
          .toList();

      for (final assetPath in workflowAssets) {
        try {
          final json = await rootBundle.loadString(assetPath);
          final data = jsonDecode(json) as Map<String, dynamic>;

          // Determine folder from path
          final pathParts = assetPath.split('/');
          String? folder;
          if (pathParts.length > 3) {
            // Has subfolder: assets/example_workflows/Subfolder/file.json
            folder = pathParts.sublist(2, pathParts.length - 1).join('/');
          }

          // Determine name from filename
          final filename = pathParts.last.replaceAll('.json', '');

          // Check if workflow with same name already exists
          final existingWorkflows = await getAllWorkflows();
          if (existingWorkflows.any((w) => w.name == filename)) {
            continue; // Skip duplicate
          }

          await importFromComfyUI(data, name: filename, folder: folder);
        } catch (e) {
          print('Error loading example workflow $assetPath: $e');
        }
      }

      // Mark examples as loaded
      await _metadataBox!.put('examplesLoaded', true);
    } catch (e) {
      print('Error loading example workflows: $e');
      // Asset manifest might not be available, create default examples
      await _createDefaultExamples();
    }
  }

  /// Create default example workflows when assets aren't available
  Future<void> _createDefaultExamples() async {
    // Basic SDXL Text to Image workflow
    final basicSdxl = EriWorkflow(
      id: '',
      name: 'Basic SDXL',
      description: 'Simple SDXL text-to-image workflow',
      enableInSimple: true,
      workflow: '{}',
      prompt: jsonEncode(_createBasicSdxlPrompt()),
      customParams: jsonEncode({
        'prompt': {
          'name': 'Prompt',
          'type': 'text',
          'description': 'The main prompt',
          'default': 'a beautiful landscape',
          'group': 'Core',
        },
        'negative_prompt': {
          'name': 'Negative Prompt',
          'type': 'text',
          'description': 'What to avoid',
          'default': 'ugly, blurry, low quality',
          'group': 'Core',
        },
        'seed': {
          'name': 'Seed',
          'type': 'integer',
          'description': 'Random seed (-1 for random)',
          'default': -1,
          'min': -1,
          'max': 2147483647,
          'group': 'Core',
        },
        'steps': {
          'name': 'Steps',
          'type': 'integer',
          'description': 'Number of sampling steps',
          'default': 25,
          'min': 1,
          'max': 150,
          'group': 'Sampling',
        },
        'cfg_scale': {
          'name': 'CFG Scale',
          'type': 'decimal',
          'description': 'Classifier-free guidance scale',
          'default': 7.0,
          'min': 1.0,
          'max': 30.0,
          'step': 0.5,
          'group': 'Sampling',
        },
      }),
      paramValues: jsonEncode({
        'prompt': 'a beautiful landscape',
        'negative_prompt': 'ugly, blurry, low quality',
        'seed': -1,
        'steps': 25,
        'cfg_scale': 7.0,
      }),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await saveWorkflow(basicSdxl);
    await _metadataBox!.put('examplesLoaded', true);
  }

  /// Create a basic SDXL prompt structure
  Map<String, dynamic> _createBasicSdxlPrompt() {
    return {
      '1': {
        'class_type': 'CheckpointLoaderSimple',
        'inputs': {
          'ckpt_name': r'${model}',
        },
      },
      '2': {
        'class_type': 'CLIPTextEncode',
        'inputs': {
          'text': r'${prompt}',
          'clip': ['1', 1],
        },
      },
      '3': {
        'class_type': 'CLIPTextEncode',
        'inputs': {
          'text': r'${negative_prompt}',
          'clip': ['1', 1],
        },
      },
      '4': {
        'class_type': 'EmptyLatentImage',
        'inputs': {
          'width': r'${width}',
          'height': r'${height}',
          'batch_size': r'${batch_size}',
        },
      },
      '5': {
        'class_type': 'KSampler',
        'inputs': {
          'model': ['1', 0],
          'positive': ['2', 0],
          'negative': ['3', 0],
          'latent_image': ['4', 0],
          'seed': r'${seed}',
          'steps': r'${steps}',
          'cfg': r'${cfg_scale}',
          'sampler_name': r'${sampler}',
          'scheduler': r'${scheduler}',
          'denoise': 1.0,
        },
      },
      '6': {
        'class_type': 'VAEDecode',
        'inputs': {
          'samples': ['5', 0],
          'vae': ['1', 2],
        },
      },
      '7': {
        'class_type': 'SaveImage',
        'inputs': {
          'images': ['6', 0],
          'filename_prefix': 'ERI',
        },
      },
    };
  }

  // ============================================
  // Search
  // ============================================

  /// Search workflows by name, description, or tags
  Future<List<EriWorkflow>> searchWorkflows(String query) async {
    if (query.isEmpty) {
      return getAllWorkflows();
    }

    final allWorkflows = await getAllWorkflows();
    final lowerQuery = query.toLowerCase();

    return allWorkflows.where((w) {
      // Search name
      if (w.name.toLowerCase().contains(lowerQuery)) return true;

      // Search description
      if (w.description?.toLowerCase().contains(lowerQuery) ?? false) return true;

      // Search tags
      if (w.tags?.any((tag) => tag.toLowerCase().contains(lowerQuery)) ?? false) return true;

      // Search folder
      if (w.folder?.toLowerCase().contains(lowerQuery) ?? false) return true;

      return false;
    }).toList();
  }

  /// Filter workflows by tag
  Future<List<EriWorkflow>> filterByTag(String tag) async {
    final allWorkflows = await getAllWorkflows();
    final lowerTag = tag.toLowerCase();

    return allWorkflows.where((w) {
      return w.tags?.any((t) => t.toLowerCase() == lowerTag) ?? false;
    }).toList();
  }

  // ============================================
  // Metadata & Statistics
  // ============================================

  /// Get the total count of workflows
  Future<int> getWorkflowCount() async {
    await _ensureInitialized();
    return _workflowBox!.length;
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    await _ensureInitialized();

    final workflows = await getAllWorkflows();
    final folders = await getFolders();

    return {
      'totalWorkflows': workflows.length,
      'totalFolders': folders.length,
      'simpleWorkflows': workflows.where((w) => w.enableInSimple).length,
      'recentlyUpdated': workflows.take(5).map((w) => w.name).toList(),
    };
  }

  /// Clear all workflows and folders (use with caution!)
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _workflowBox!.clear();
    await _folderBox!.clear();
    await _metadataBox!.clear();
  }
}
