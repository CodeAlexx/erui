# EriUI Workflow Management Parity Plan
## Full SwarmUI Workflow System Implementation

### Executive Summary

This plan achieves **full parity** with SwarmUI's workflow management system in eriui's Flutter app. The implementation covers:
- Workflow CRUD operations (create, read, update, delete)
- Workflow browser/selector UI (like SwarmUI's top-left panel)
- Workflow editor with visual node graph
- Custom parameter definition and templating
- ComfyUI backend integration
- Workflow execution with parameter substitution

---

## Phase 1: Core Data Layer (Foundation)

### 1.1 Workflow Data Models

**File:** `lib/models/workflow_models.dart`

```dart
/// Mirrors SwarmUI's ComfyCustomWorkflow structure
class EriWorkflow {
  final String id;
  final String name;
  final String? folder;           // Supports hierarchical organization
  final String workflow;          // ComfyUI visual workflow JSON
  final String prompt;            // ComfyUI execution prompt JSON
  final String customParams;      // Parameter definitions JSON
  final String paramValues;       // Default parameter values JSON
  final String? image;            // Preview thumbnail (base64 or path)
  final String? description;
  final bool enableInSimple;      // Show in simple/quick tab
  final DateTime createdAt;
  final DateTime updatedAt;

  // Template tag support: ${prompt}, ${seed}, ${model}, etc.
  String fillTemplate(Map<String, dynamic> params);

  // Parse custom params into EriWorkflowParam list
  List<EriWorkflowParam> get parameters;
}

/// Parameter definition for workflow customization
class EriWorkflowParam {
  final String id;
  final String name;
  final String type;              // text, dropdown, integer, decimal, boolean, image, model
  final String? description;
  final dynamic defaultValue;
  final List<String>? values;     // For dropdowns
  final num? min, max, step;      // For numeric
  final bool toggleable;
  final bool visible;
  final bool advanced;
  final String? featureFlag;
  final String? group;
}

/// Workflow execution result
class WorkflowExecutionResult {
  final String promptId;
  final List<String> outputImages;
  final Map<String, dynamic> metadata;
  final Duration executionTime;
}
```

### 1.2 Workflow Storage Service

**File:** `lib/services/workflow_storage_service.dart`

```dart
/// Persistent workflow storage using Hive
class WorkflowStorageService {
  static const String _boxName = 'workflows';
  static const String _metadataBoxName = 'workflow_metadata';

  // CRUD Operations
  Future<void> saveWorkflow(EriWorkflow workflow);
  Future<EriWorkflow?> getWorkflow(String id);
  Future<List<EriWorkflow>> getAllWorkflows();
  Future<List<EriWorkflow>> getWorkflowsInFolder(String folder);
  Future<void> deleteWorkflow(String id);

  // Folder management
  Future<List<String>> getFolders();
  Future<void> createFolder(String path);
  Future<void> deleteFolder(String path);

  // Import/Export
  Future<void> importFromJson(String json);
  Future<String> exportToJson(String workflowId);
  Future<void> importFromComfyUI(Map<String, dynamic> comfyWorkflow);

  // Example workflows
  Future<void> loadExampleWorkflows();
}
```

### 1.3 Workflow Provider (State Management)

**File:** `lib/providers/workflow_provider.dart`

```dart
/// Riverpod state management for workflows
@riverpod
class WorkflowNotifier extends _$WorkflowNotifier {
  // State
  List<EriWorkflow> workflows = [];
  EriWorkflow? selectedWorkflow;
  String? currentFolder;
  bool isLoading = false;
  String? error;

  // Actions
  Future<void> loadWorkflows();
  Future<void> selectWorkflow(String id);
  Future<void> saveWorkflow(EriWorkflow workflow);
  Future<void> deleteWorkflow(String id);
  Future<void> duplicateWorkflow(String id, String newName);
  void setFolder(String? folder);

  // Search/Filter
  List<EriWorkflow> searchWorkflows(String query);
  List<EriWorkflow> filterByTag(String tag);
}

/// Current workflow execution state
@riverpod
class WorkflowExecutionNotifier extends _$WorkflowExecutionNotifier {
  Map<String, dynamic> currentParams = {};
  bool isExecuting = false;
  double progress = 0;
  String? currentPromptId;

  Future<WorkflowExecutionResult> executeWorkflow(
    EriWorkflow workflow,
    Map<String, dynamic> paramOverrides,
  );

  void updateParam(String key, dynamic value);
  void resetToDefaults(EriWorkflow workflow);
}
```

---

## Phase 2: API Integration Layer

### 2.1 ComfyUI Workflow API Extensions

**File:** `lib/services/comfyui_workflow_api.dart`

```dart
/// Extended ComfyUI service for workflow operations
extension ComfyUIWorkflowAPI on ComfyUIService {
  // Workflow execution with template filling
  Future<String> queueWorkflow(
    EriWorkflow workflow,
    Map<String, dynamic> params,
  ) {
    final filledPrompt = _fillWorkflowTemplate(workflow.prompt, params);
    return queuePrompt(jsonDecode(filledPrompt));
  }

  // Template tag replacement (mirrors SwarmUI's QuickSimpleTagFiller)
  String _fillWorkflowTemplate(String template, Map<String, dynamic> params) {
    var result = template;

    // Standard tags
    result = result.replaceAll('\${prompt}', params['prompt'] ?? '');
    result = result.replaceAll('\${negative_prompt}', params['negativePrompt'] ?? '');
    result = result.replaceAll('\${seed}', (params['seed'] ?? -1).toString());
    result = result.replaceAll('\${steps}', (params['steps'] ?? 20).toString());
    result = result.replaceAll('\${width}', (params['width'] ?? 1024).toString());
    result = result.replaceAll('\${height}', (params['height'] ?? 1024).toString());
    result = result.replaceAll('\${cfg_scale}', (params['cfgScale'] ?? 7.0).toString());
    result = result.replaceAll('\${model}', params['model'] ?? '');

    // Custom param tags: ${param_name:default_value}
    final customTagRegex = RegExp(r'\$\{(\w+)(?::([^}]*))?\}');
    result = result.replaceAllMapped(customTagRegex, (match) {
      final paramName = match.group(1)!;
      final defaultValue = match.group(2) ?? '';
      return (params[paramName] ?? defaultValue).toString();
    });

    // Seed offset support: ${seed+42}
    final seedOffsetRegex = RegExp(r'\$\{seed\+(\d+)\}');
    result = result.replaceAllMapped(seedOffsetRegex, (match) {
      final offset = int.parse(match.group(1)!);
      final baseSeed = params['seed'] ?? Random().nextInt(1 << 32);
      return (baseSeed + offset).toString();
    });

    return result;
  }

  // Get node types from ComfyUI (for workflow editor)
  Future<List<String>> getNodeTypes();

  // Get object info for node inputs/outputs
  Future<Map<String, dynamic>> getObjectInfo();
}
```

### 2.2 Workflow Validation Service

**File:** `lib/services/workflow_validation_service.dart`

```dart
/// Validates workflows before execution
class WorkflowValidationService {
  final ComfyUIService _comfyService;

  // Validate workflow structure
  ValidationResult validateWorkflow(EriWorkflow workflow) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check required nodes exist
    // Validate connections
    // Check for missing inputs
    // Verify model availability

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  // Check if required features are available
  Future<bool> checkFeatureSupport(EriWorkflow workflow);

  // Validate custom parameters
  bool validateParams(EriWorkflow workflow, Map<String, dynamic> params);
}
```

---

## Phase 3: UI Components

### 3.1 Workflow Browser Panel (SwarmUI Top-Left Style)

**File:** `lib/features/workflow_browser/workflow_browser_panel.dart`

```dart
/// Hierarchical workflow browser like SwarmUI
class WorkflowBrowserPanel extends ConsumerStatefulWidget {
  // Callbacks
  final Function(EriWorkflow) onWorkflowSelected;
  final Function(EriWorkflow)? onWorkflowEdit;
  final VoidCallback? onCreateNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Header with title and actions
        _WorkflowBrowserHeader(
          onCreateNew: onCreateNew,
          onImport: _showImportDialog,
        ),

        // Search bar
        _WorkflowSearchBar(
          onSearch: (query) => ref.read(workflowProvider.notifier).search(query),
        ),

        // Folder tree + workflow list
        Expanded(
          child: _WorkflowTree(
            folders: ref.watch(workflowFoldersProvider),
            workflows: ref.watch(filteredWorkflowsProvider),
            selectedId: ref.watch(selectedWorkflowIdProvider),
            onFolderTap: (folder) => ref.read(workflowProvider.notifier).setFolder(folder),
            onWorkflowTap: onWorkflowSelected,
            onWorkflowDoubleTap: onWorkflowEdit,
          ),
        ),
      ],
    );
  }
}

/// Individual workflow tile with preview
class WorkflowTile extends StatelessWidget {
  final EriWorkflow workflow;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Thumbnail preview
            if (workflow.image != null)
              WorkflowThumbnail(imageData: workflow.image!),

            // Name and description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workflow.name, style: Theme.of(context).textTheme.titleSmall),
                  if (workflow.description != null)
                    Text(
                      workflow.description!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Actions menu
            PopupMenuButton(
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                PopupMenuItem(value: 'export', child: Text('Export')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: _handleAction,
            ),
          ],
        ),
      ),
    );
  }
}
```

### 3.2 Workflow Parameter Panel

**File:** `lib/features/workflow_browser/workflow_params_panel.dart`

```dart
/// Dynamic parameter panel based on workflow custom_params
class WorkflowParamsPanel extends ConsumerWidget {
  final EriWorkflow workflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = workflow.parameters;
    final currentValues = ref.watch(workflowExecutionProvider).currentParams;

    // Group parameters by group name
    final groupedParams = _groupParameters(params);

    return ListView(
      children: [
        // Always show core parameters
        _CoreParamsSection(
          prompt: currentValues['prompt'],
          negativePrompt: currentValues['negativePrompt'],
          onPromptChanged: (v) => ref.read(workflowExecutionProvider.notifier).updateParam('prompt', v),
          onNegativePromptChanged: (v) => ref.read(workflowExecutionProvider.notifier).updateParam('negativePrompt', v),
        ),

        // Custom parameters by group
        for (final group in groupedParams.entries)
          _ParamGroupSection(
            groupName: group.key,
            params: group.value,
            currentValues: currentValues,
            onParamChanged: (key, value) =>
              ref.read(workflowExecutionProvider.notifier).updateParam(key, value),
          ),
      ],
    );
  }

  Widget _buildParamWidget(EriWorkflowParam param, dynamic value, Function(dynamic) onChange) {
    switch (param.type) {
      case 'text':
        return TextField(
          decoration: InputDecoration(labelText: param.name),
          controller: TextEditingController(text: value?.toString()),
          onChanged: onChange,
        );

      case 'dropdown':
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: param.name),
          value: value?.toString(),
          items: param.values?.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: onChange,
        );

      case 'integer':
      case 'decimal':
        return Slider(
          value: (value ?? param.defaultValue ?? param.min ?? 0).toDouble(),
          min: param.min?.toDouble() ?? 0,
          max: param.max?.toDouble() ?? 100,
          divisions: param.type == 'integer' ? (param.max! - param.min!).toInt() : null,
          label: value?.toString(),
          onChanged: (v) => onChange(param.type == 'integer' ? v.round() : v),
        );

      case 'boolean':
        return SwitchListTile(
          title: Text(param.name),
          value: value ?? param.defaultValue ?? false,
          onChanged: onChange,
        );

      case 'image':
        return ImagePickerWidget(
          currentImage: value,
          onImageSelected: onChange,
        );

      case 'model':
        return ModelSelectorWidget(
          selectedModel: value,
          onModelSelected: onChange,
        );

      default:
        return TextField(
          decoration: InputDecoration(labelText: param.name),
          controller: TextEditingController(text: value?.toString()),
          onChanged: onChange,
        );
    }
  }
}
```

### 3.3 Workflow Save Dialog

**File:** `lib/features/workflow_browser/workflow_save_dialog.dart`

```dart
/// Dialog for saving/editing workflow metadata
class WorkflowSaveDialog extends StatefulWidget {
  final EriWorkflow? existingWorkflow;  // null for new workflow
  final String workflowJson;            // The ComfyUI workflow to save
  final String promptJson;              // The execution prompt

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(existingWorkflow != null ? 'Edit Workflow' : 'Save Workflow'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Workflow Name',
                hintText: 'My Custom Workflow',
              ),
            ),

            // Folder selection
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Folder'),
              value: _selectedFolder,
              items: [
                DropdownMenuItem(value: null, child: Text('Root')),
                ..._folders.map((f) => DropdownMenuItem(value: f, child: Text(f))),
              ],
              onChanged: (v) => setState(() => _selectedFolder = v),
            ),

            // Description
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),

            // Preview image (capture or upload)
            _PreviewImageSelector(
              currentImage: _previewImage,
              onImageSelected: (img) => setState(() => _previewImage = img),
            ),

            // Enable in simple tab
            SwitchListTile(
              title: Text('Show in Quick Generate'),
              value: _enableInSimple,
              onChanged: (v) => setState(() => _enableInSimple = v),
            ),

            // Custom parameters editor
            ExpansionTile(
              title: Text('Custom Parameters'),
              children: [
                _CustomParamsEditor(
                  params: _customParams,
                  onParamsChanged: (p) => setState(() => _customParams = p),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveWorkflow,
          child: Text('Save'),
        ),
      ],
    );
  }
}
```

### 3.4 Visual Workflow Editor (Node Graph)

**File:** `lib/features/workflow_editor/visual_workflow_editor.dart`

```dart
/// Visual node-based workflow editor
class VisualWorkflowEditor extends ConsumerStatefulWidget {
  final EriWorkflow? initialWorkflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Workflow Editor'),
        actions: [
          IconButton(icon: Icon(Icons.save), onPressed: _saveWorkflow),
          IconButton(icon: Icon(Icons.play_arrow), onPressed: _testWorkflow),
          PopupMenuButton(
            itemBuilder: (_) => [
              PopupMenuItem(value: 'import', child: Text('Import ComfyUI JSON')),
              PopupMenuItem(value: 'export', child: Text('Export ComfyUI JSON')),
              PopupMenuItem(value: 'clear', child: Text('Clear All')),
            ],
            onSelected: _handleMenuAction,
          ),
        ],
      ),
      body: Row(
        children: [
          // Left: Node palette
          SizedBox(
            width: 250,
            child: _NodePalette(
              nodeTypes: ref.watch(comfyNodeTypesProvider),
              onNodeDragStart: _handleNodeDragStart,
            ),
          ),

          // Center: Canvas
          Expanded(
            child: _WorkflowCanvas(
              nodes: _nodes,
              connections: _connections,
              onNodeMoved: _handleNodeMoved,
              onConnectionCreated: _handleConnectionCreated,
              onNodeSelected: _handleNodeSelected,
            ),
          ),

          // Right: Node properties
          if (_selectedNode != null)
            SizedBox(
              width: 300,
              child: _NodePropertiesPanel(
                node: _selectedNode!,
                onPropertyChanged: _handlePropertyChanged,
              ),
            ),
        ],
      ),
    );
  }
}

/// Interactive canvas for node graph
class _WorkflowCanvas extends StatefulWidget {
  // Pan and zoom support
  // Node drag and drop
  // Connection drawing with bezier curves
  // Selection and multi-select
}

/// Node widget with inputs/outputs
class _WorkflowNode extends StatelessWidget {
  final WorkflowNode node;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: _getNodeColor(node.type),
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Column(
        children: [
          // Header with node type
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getNodeHeaderColor(node.type),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Text(node.type, style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          // Input slots
          for (final input in node.inputs)
            _InputSlot(name: input, onConnect: _handleInputConnect),

          // Output slots
          for (final output in node.outputs)
            _OutputSlot(name: output, onConnect: _handleOutputConnect),
        ],
      ),
    );
  }
}
```

---

## Phase 4: Integration & Polish

### 4.1 Generate Screen Integration

**File:** `lib/features/generate/generate_screen.dart` (modifications)

```dart
/// Modified generate screen with workflow browser
class GenerateScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedWorkflow = ref.watch(selectedWorkflowProvider);

    return Row(
      children: [
        // NEW: Workflow browser panel (collapsible)
        if (ref.watch(showWorkflowBrowserProvider))
          SizedBox(
            width: 280,
            child: WorkflowBrowserPanel(
              onWorkflowSelected: (workflow) {
                ref.read(selectedWorkflowProvider.notifier).select(workflow);
                // Load workflow parameters into generation params
                ref.read(generationProvider.notifier).loadFromWorkflow(workflow);
              },
              onWorkflowEdit: (workflow) {
                // Navigate to workflow editor
                context.push('/workflow/edit/${workflow.id}');
              },
              onCreateNew: () {
                // Create workflow from current params
                _showSaveWorkflowDialog(context, ref);
              },
            ),
          ),

        // Existing parameter panel
        SizedBox(
          width: ref.watch(leftPanelWidthProvider),
          child: selectedWorkflow != null
            ? WorkflowParamsPanel(workflow: selectedWorkflow)
            : EriParametersPanel(),  // Standard params when no workflow
        ),

        // ... rest of existing layout
      ],
    );
  }
}
```

### 4.2 Workflow Execution Integration

**File:** `lib/providers/generation_provider.dart` (modifications)

```dart
extension WorkflowExecutionExtension on GenerationNotifier {
  /// Execute a workflow instead of building from params
  Future<void> executeWorkflow(EriWorkflow workflow, Map<String, dynamic> params) async {
    state = state.copyWith(isGenerating: true, progress: 0);

    try {
      // Fill template with params
      final filledPrompt = workflow.fillTemplate(params);

      // Queue to ComfyUI
      final promptId = await _comfyService.queuePrompt(jsonDecode(filledPrompt));

      // Track execution
      state = state.copyWith(currentPromptId: promptId);

      // Wait for completion via WebSocket
      await for (final update in _comfyService.progressStream) {
        if (update.promptId == promptId) {
          state = state.copyWith(progress: update.progress);

          if (update.isComplete) {
            // Handle output images
            _handleWorkflowOutput(update.outputs);
            break;
          }
        }
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isGenerating: false);
    }
  }

  /// Load workflow defaults into generation params
  void loadFromWorkflow(EriWorkflow workflow) {
    final paramValues = jsonDecode(workflow.paramValues) as Map<String, dynamic>;

    // Apply workflow defaults to current params
    for (final entry in paramValues.entries) {
      _setParamValue(entry.key, entry.value);
    }
  }
}
```

### 4.3 Example Workflows

**File:** `assets/example_workflows/`

```
example_workflows/
├── Basic SDXL.json
├── SDXL with Refiner.json
├── ControlNet Depth.json
├── LoRA Stack.json
├── Upscale 2x.json
├── Video/
│   ├── AnimateDiff Basic.json
│   └── SVD Image to Video.json
└── Advanced/
    ├── Regional Prompting.json
    └── Multi-ControlNet.json
```

---

## Phase 5: Agent Coordination Plan

### Agent 1: Data Layer Agent
**Responsibility:** Models, storage, providers
**Files to create:**
- `lib/models/workflow_models.dart`
- `lib/services/workflow_storage_service.dart`
- `lib/providers/workflow_provider.dart`
- `lib/providers/workflow_execution_provider.dart`

### Agent 2: API Integration Agent
**Responsibility:** ComfyUI workflow API, template filling
**Files to create/modify:**
- `lib/services/comfyui_workflow_api.dart`
- `lib/services/workflow_validation_service.dart`
- Modify `lib/services/comfyui_service.dart`

### Agent 3: Workflow Browser UI Agent
**Responsibility:** Browser panel, tiles, search
**Files to create:**
- `lib/features/workflow_browser/workflow_browser_panel.dart`
- `lib/features/workflow_browser/workflow_tile.dart`
- `lib/features/workflow_browser/workflow_tree.dart`
- `lib/features/workflow_browser/workflow_search.dart`

### Agent 4: Workflow Parameters UI Agent
**Responsibility:** Dynamic parameter rendering
**Files to create:**
- `lib/features/workflow_browser/workflow_params_panel.dart`
- `lib/features/workflow_browser/param_widgets/`
- `lib/features/workflow_browser/workflow_save_dialog.dart`

### Agent 5: Visual Editor Agent
**Responsibility:** Node graph editor
**Files to create:**
- `lib/features/workflow_editor/visual_workflow_editor.dart`
- `lib/features/workflow_editor/workflow_canvas.dart`
- `lib/features/workflow_editor/workflow_node_widget.dart`
- `lib/features/workflow_editor/node_palette.dart`
- `lib/features/workflow_editor/node_properties_panel.dart`

### Agent 6: Integration Agent
**Responsibility:** Wire everything together
**Files to modify:**
- `lib/features/generate/generate_screen.dart`
- `lib/providers/generation_provider.dart`
- `lib/app.dart` (routing)
- `lib/widgets/app_shell.dart` (navigation)

---

## Implementation Order

1. **Phase 1** (Foundation): Agent 1 → Data models and storage
2. **Phase 2** (API): Agent 2 → ComfyUI integration
3. **Phase 3a** (UI - Browser): Agent 3 → Workflow browser
4. **Phase 3b** (UI - Params): Agent 4 → Parameter panel (parallel with 3a)
5. **Phase 3c** (UI - Editor): Agent 5 → Visual editor (parallel with 3a/3b)
6. **Phase 4** (Integration): Agent 6 → Wire together and test

---

## Success Criteria

- [ ] Workflows can be saved with custom parameters
- [ ] Workflows can be loaded and parameters edited
- [ ] Workflow browser shows hierarchical folder structure
- [ ] Workflow thumbnails display correctly
- [ ] Template tags (`${prompt}`, `${seed}`, etc.) work correctly
- [ ] Custom parameters render appropriate widgets
- [ ] Workflow execution sends correct JSON to ComfyUI
- [ ] Visual editor can create/edit node graphs
- [ ] Import/export ComfyUI JSON works
- [ ] Example workflows load on first run
- [ ] State persists across app restarts
