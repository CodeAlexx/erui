# EriUI ComfyUI Workflow Integration Plan

## Executive Summary

This plan details how to integrate ComfyUI workflows into EriUI, based on a comprehensive audit of SwarmUI's implementation. EriUI will support browsing, loading, saving, and executing ComfyUI workflows through its own standalone ComfyUI backend (port 8199).

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         EriUI Flutter App                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  Generate   │  │   Trainer   │  │    Comfy Workflow       │  │
│  │    Tab      │  │     Tab     │  │         Tab             │  │
│  └──────┬──────┘  └─────────────┘  └───────────┬─────────────┘  │
│         │                                       │                │
│         │     ┌─────────────────────────────────┤                │
│         │     │                                 │                │
│  ┌──────▼─────▼──────────────────────────────────▼──────────┐   │
│  │              Workflow Service (Dart)                      │   │
│  │  - Load/Save workflows                                    │   │
│  │  - Template filling (${tag} substitution)                 │   │
│  │  - Parameter mapping                                      │   │
│  └──────────────────────────┬───────────────────────────────┘   │
└─────────────────────────────┼───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    EriUI Dart Server (7803)                      │
├─────────────────────────────────────────────────────────────────┤
│  Workflow API Endpoints:                                         │
│  - GET  /api/workflows              List all workflows           │
│  - GET  /api/workflows/{name}       Read workflow                │
│  - POST /api/workflows/{name}       Save workflow                │
│  - DELETE /api/workflows/{name}     Delete workflow              │
│  - POST /api/workflows/execute      Execute workflow             │
│  - GET  /api/workflows/generate     Generate from params         │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   EriUI ComfyUI Backend (8199)                   │
├─────────────────────────────────────────────────────────────────┤
│  ComfyUI Standard Endpoints:                                     │
│  - POST /prompt          Queue workflow                          │
│  - GET  /object_info     Node types and inputs                   │
│  - GET  /system_stats    System status                           │
│  - WS   /ws              Live progress streaming                 │
│  - GET  /view            Retrieve output images                  │
│  - GET  /history         Execution history                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Workflow Storage System

### 1.1 Directory Structure

```
/home/alex/eriui/
├── workflows/
│   ├── examples/           # Built-in example workflows (read-only)
│   │   ├── Basic_SDXL.json
│   │   ├── Basic_Flux.json
│   │   ├── Img2Img.json
│   │   └── LoRA_Example.json
│   └── custom/             # User-saved workflows
│       └── ...
├── output/                 # Generated images
└── comfyui/ComfyUI/        # ComfyUI installation
```

### 1.2 Workflow JSON Schema

```json
{
  "name": "My Workflow",
  "description": "Description for the browser",
  "version": "1.0",
  "created": "2026-01-07T12:00:00Z",
  "modified": "2026-01-07T12:00:00Z",

  "workflow": {
    // ComfyUI visual graph format (for editor UI)
    "last_node_id": 18,
    "last_link_id": 20,
    "nodes": [...],
    "links": [...],
    "groups": [...],
    "config": {},
    "extra": {}
  },

  "prompt": {
    // ComfyUI API execution format
    "3": {
      "class_type": "KSampler",
      "inputs": {
        "seed": "${seed:-1}",
        "steps": "${steps:20}",
        "cfg": "${cfg:7.0}",
        "sampler_name": "${sampler:euler}",
        "scheduler": "${scheduler:normal}",
        "model": ["4", 0],
        "positive": ["6", 0],
        "negative": ["7", 0],
        "latent_image": ["5", 0]
      }
    }
    // ... more nodes
  },

  "parameters": {
    // Exposed parameters for Generate tab integration
    "prompt": {"type": "text", "label": "Prompt", "default": ""},
    "negative_prompt": {"type": "text", "label": "Negative Prompt", "default": ""},
    "seed": {"type": "integer", "label": "Seed", "default": -1},
    "steps": {"type": "integer", "label": "Steps", "default": 20, "min": 1, "max": 150},
    "cfg": {"type": "decimal", "label": "CFG Scale", "default": 7.0, "min": 1, "max": 30},
    "width": {"type": "integer", "label": "Width", "default": 1024},
    "height": {"type": "integer", "label": "Height", "default": 1024},
    "sampler": {"type": "select", "label": "Sampler", "default": "euler", "options": []},
    "scheduler": {"type": "select", "label": "Scheduler", "default": "normal", "options": []},
    "model": {"type": "model", "label": "Model", "default": ""}
  },

  "preview_image": "base64_or_path",
  "tags": ["sdxl", "text2img"],
  "enable_in_generate": true
}
```

### 1.3 Server API Implementation

Add to `/home/alex/eriui/bin/server.dart`:

```dart
// Workflow endpoints
if (path.contains('/workflows')) {
  if (request.method == 'GET' && path.endsWith('/workflows')) {
    return _json(await _listWorkflows());
  }
  if (request.method == 'GET' && path.contains('/workflows/')) {
    final name = _extractWorkflowName(path);
    return _json(await _readWorkflow(name));
  }
  if (request.method == 'POST' && path.contains('/workflows/')) {
    final name = _extractWorkflowName(path);
    return _json(await _saveWorkflow(name, body));
  }
  if (request.method == 'DELETE' && path.contains('/workflows/')) {
    final name = _extractWorkflowName(path);
    return _json(await _deleteWorkflow(name));
  }
  if (path.endsWith('/workflows/execute')) {
    return _json(await _executeWorkflow(body));
  }
}
```

---

## Phase 2: Template Filling System

### 2.1 Tag Syntax

Support SwarmUI-compatible template tags:

| Tag | Description | Default |
|-----|-------------|---------|
| `${prompt}` | Positive prompt | "" |
| `${negative_prompt}` | Negative prompt | "" |
| `${seed}` or `${seed:-1}` | Random seed | -1 (random) |
| `${steps:20}` | Number of steps | 20 |
| `${cfg:7.0}` | CFG scale | 7.0 |
| `${width:1024}` | Image width | 1024 |
| `${height:1024}` | Image height | 1024 |
| `${model}` | Model name | "" |
| `${sampler:euler}` | Sampler | euler |
| `${scheduler:normal}` | Scheduler | normal |
| `${loras}` | LoRA list (JSON) | [] |

### 2.2 Template Filler Implementation

```dart
class WorkflowTemplateFiller {
  /// Fill template tags in workflow JSON
  static Map<String, dynamic> fill(
    Map<String, dynamic> workflow,
    Map<String, dynamic> params,
  ) {
    final json = jsonEncode(workflow);
    var filled = json;

    // Pattern: ${tag} or ${tag:default}
    final pattern = RegExp(r'\$\{([^}:]+)(?::([^}]*))?\}');

    filled = filled.replaceAllMapped(pattern, (match) {
      final tag = match.group(1)!;
      final defaultValue = match.group(2) ?? '';

      // Get value from params, or use default
      final value = params[tag] ?? params[_normalizeTag(tag)] ?? defaultValue;

      // Handle special types
      if (value is int || value is double || value is bool) {
        return value.toString();
      }
      if (value is List || value is Map) {
        return jsonEncode(value);
      }
      return value.toString();
    });

    return jsonDecode(filled) as Map<String, dynamic>;
  }

  static String _normalizeTag(String tag) {
    // Convert variations: negative_prompt -> negativeprompt
    return tag.replaceAll('_', '').toLowerCase();
  }
}
```

---

## Phase 3: Workflow Browser UI (Flutter)

### 3.1 New Screen: `comfy_workflow_screen.dart`

```dart
/// ComfyUI Workflow browser and editor integration
class ComfyWorkflowScreen extends ConsumerStatefulWidget {
  // Features:
  // - Grid/list view of available workflows
  // - Thumbnail previews
  // - Search and filter
  // - Quick actions: Use, Edit, Delete
  // - Save workflow dialog
  // - Import from Generate tab
}
```

### 3.2 UI Components

```
┌────────────────────────────────────────────────────────────────┐
│  Comfy Workflow                                                 │
├────────────────────────────────────────────────────────────────┤
│ ┌──────────────────┐  ┌──────────────────────────────────────┐ │
│ │ [Use Workflow]   │  │ Search: [________________] [Filter▼] │ │
│ │ [Save Workflow]  │  ├──────────────────────────────────────┤ │
│ │ [Import from Gen]│  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐    │ │
│ │ [Browse]         │  │  │     │ │     │ │     │ │     │    │ │
│ ├──────────────────┤  │  │ WF1 │ │ WF2 │ │ WF3 │ │ WF4 │    │ │
│ │ ▼ Examples       │  │  │     │ │     │ │     │ │     │    │ │
│ │   Basic SDXL     │  │  └─────┘ └─────┘ └─────┘ └─────┘    │ │
│ │   Basic Flux     │  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐    │ │
│ │   Img2Img        │  │  │     │ │     │ │     │ │     │    │ │
│ │ ▼ Custom         │  │  │ WF5 │ │ WF6 │ │ WF7 │ │ WF8 │    │ │
│ │   My Workflow    │  │  │     │ │     │ │     │ │     │    │ │
│ │   ...            │  │  └─────┘ └─────┘ └─────┘ └─────┘    │ │
│ └──────────────────┘  └──────────────────────────────────────┘ │
├────────────────────────────────────────────────────────────────┤
│  [ ComfyUI Editor (WebView/iframe) ]                           │
│  - Load ComfyUI UI from http://localhost:8199                  │
│  - Bidirectional communication for workflow loading/saving     │
└────────────────────────────────────────────────────────────────┘
```

### 3.3 State Management (Riverpod)

```dart
/// Workflow list provider
final workflowListProvider = FutureProvider<List<WorkflowInfo>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.listWorkflows();
});

/// Current workflow provider
final currentWorkflowProvider = StateProvider<WorkflowData?>((ref) => null);

/// Workflow search/filter provider
final workflowFilterProvider = StateProvider<WorkflowFilter>((ref) => WorkflowFilter());
```

---

## Phase 4: Workflow Execution

### 4.1 Execution Flow

```
1. User selects workflow in browser
2. Load workflow JSON from server
3. User modifies parameters (or uses defaults)
4. Template filler substitutes ${tags}
5. Send filled prompt to ComfyUI /prompt endpoint
6. Connect WebSocket for progress
7. Stream progress updates to UI
8. Retrieve output images
9. Display in gallery
```

### 4.2 WebSocket Progress Handler

```dart
class ComfyWorkflowExecutor {
  final String comfyUrl;
  final String clientId;
  WebSocketChannel? _ws;

  Stream<WorkflowProgress> execute(Map<String, dynamic> prompt) async* {
    // Connect WebSocket
    final wsUrl = comfyUrl.replaceFirst('http', 'ws') + '/ws?clientId=$clientId';
    _ws = WebSocketChannel.connect(Uri.parse(wsUrl));

    // Queue prompt
    final response = await _queuePrompt(prompt);
    final promptId = response['prompt_id'];

    // Listen for events
    await for (final message in _ws!.stream) {
      final data = jsonDecode(message);
      final type = data['type'];

      switch (type) {
        case 'execution_start':
          yield WorkflowProgress(status: 'started', promptId: promptId);
          break;
        case 'progress':
          yield WorkflowProgress(
            status: 'generating',
            step: data['data']['value'],
            total: data['data']['max'],
          );
          break;
        case 'executing':
          if (data['data']['node'] == null) {
            // Execution complete
            final images = await _getOutputImages(promptId);
            yield WorkflowProgress(status: 'complete', images: images);
            return;
          }
          break;
        case 'execution_error':
          yield WorkflowProgress(
            status: 'error',
            error: data['data']['exception_message'],
          );
          return;
      }
    }
  }
}
```

---

## Phase 5: ComfyUI Editor Integration

### 5.1 Option A: WebView Embed (Recommended)

Use `webview_flutter` or `flutter_inappwebview` to embed ComfyUI's native UI:

```dart
class ComfyEditorWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return WebViewWidget(
      controller: WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse('http://localhost:8199'))
        ..addJavaScriptChannel(
          'EriUI',
          onMessageReceived: (message) {
            // Handle messages from ComfyUI
            _handleComfyMessage(message.message);
          },
        ),
    );
  }
}
```

### 5.2 Option B: Native Node Editor (Future)

Build a native Flutter node editor using `flutter_flow_chart` or custom implementation:
- More work but better integration
- Full control over UI/UX
- Better performance on desktop

---

## Phase 6: Generate Tab Integration

### 6.1 Workflow Selection in Generate

Add workflow selector to Generate tab:

```dart
// In parameters panel
DropdownButton<String>(
  value: selectedWorkflow,
  items: workflows.map((w) => DropdownMenuItem(
    value: w.name,
    child: Text(w.name),
  )).toList(),
  onChanged: (name) {
    // Load workflow and populate parameters
    loadWorkflowToGenerate(name);
  },
)
```

### 6.2 "Use This Workflow" Action

When user clicks "Use This Workflow":
1. Load workflow parameters into Generate tab
2. Set workflow name in hidden field
3. Generate uses workflow template instead of dynamic generation

---

## Implementation Timeline

| Phase | Component | Priority | Complexity |
|-------|-----------|----------|------------|
| 1 | Workflow Storage API | High | Low |
| 2 | Template Filler | High | Medium |
| 3 | Workflow Browser UI | High | Medium |
| 4 | Workflow Execution | High | Medium |
| 5 | ComfyUI Editor (WebView) | Medium | Low |
| 6 | Generate Tab Integration | Medium | Low |

---

## Files to Create/Modify

### New Files

```
flutter_app/lib/
├── features/comfy_workflow/
│   ├── comfy_workflow_screen.dart      # Main workflow browser
│   ├── widgets/
│   │   ├── workflow_grid.dart          # Grid view of workflows
│   │   ├── workflow_card.dart          # Single workflow card
│   │   ├── workflow_editor.dart        # WebView editor embed
│   │   └── save_workflow_dialog.dart   # Save dialog
│   └── services/
│       ├── workflow_service.dart       # API calls
│       └── workflow_executor.dart      # Execution logic
├── models/
│   └── workflow_model.dart             # Data models
└── providers/
    └── workflow_providers.dart         # Riverpod providers

bin/server.dart                         # Add workflow API endpoints
```

### Modified Files

```
flutter_app/lib/
├── app_shell.dart                      # Add Comfy Workflow tab
├── features/generate/
│   └── widgets/
│       └── eri_parameters_panel.dart   # Add workflow selector
```

---

## Example Workflows to Include

1. **Basic_Text2Img.json** - Simple text-to-image (any model)
2. **Basic_SDXL.json** - SDXL optimized
3. **Basic_Flux.json** - Flux Dev/Schnell
4. **Img2Img.json** - Image-to-image
5. **LoRA_Example.json** - With LoRA loader
6. **Inpainting.json** - Inpainting workflow
7. **ControlNet.json** - ControlNet example

---

## Dependencies

```yaml
# pubspec.yaml additions
dependencies:
  webview_flutter: ^4.4.2       # For ComfyUI editor embed
  webview_flutter_wgt: ^3.0.6   # Linux WebView support
  # OR
  flutter_inappwebview: ^6.0.0  # Alternative WebView
```

---

## Security Considerations

1. **Path Traversal**: Sanitize workflow names (no `..`, `/`, `\`)
2. **JSON Injection**: Validate workflow JSON structure
3. **Template Injection**: Escape special characters in user input
4. **WebSocket**: Validate messages from ComfyUI
5. **File Access**: Restrict workflow directory access

---

## Testing Strategy

1. **Unit Tests**: Template filler, workflow parser
2. **Integration Tests**: API endpoints, workflow execution
3. **UI Tests**: Workflow browser, save dialog
4. **E2E Tests**: Full workflow load → execute → output flow
