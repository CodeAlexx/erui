import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../workflow/models/workflow_models.dart';
import '../workflow/providers/workflow_provider.dart';
import 'workflow_canvas.dart';
import 'node_palette.dart';
import 'node_properties_panel.dart';

/// Visual node-based workflow editor like ComfyUI
///
/// Three-column layout:
/// - Left: Node Palette (categorized node types)
/// - Center: Interactive Canvas (nodes and connections)
/// - Right: Properties Panel (selected node properties)
class VisualWorkflowEditor extends ConsumerStatefulWidget {
  /// Initial workflow to load (optional)
  final Workflow? initialWorkflow;

  /// Callback when workflow is saved
  final void Function(Workflow workflow)? onSave;

  const VisualWorkflowEditor({
    super.key,
    this.initialWorkflow,
    this.onSave,
  });

  @override
  ConsumerState<VisualWorkflowEditor> createState() => _VisualWorkflowEditorState();
}

class _VisualWorkflowEditorState extends ConsumerState<VisualWorkflowEditor> {
  bool _showNodePalette = true;
  bool _showPropertiesPanel = true;
  double _nodePaletteWidth = 240;
  double _propertiesPanelWidth = 300;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeEditor();
    });
  }

  void _initializeEditor() {
    final notifier = ref.read(workflowEditorProvider.notifier);
    if (widget.initialWorkflow != null) {
      notifier.loadWorkflow(widget.initialWorkflow!);
    } else {
      notifier.newWorkflow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workflowEditorProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(context, state, colorScheme),
      body: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Row(
          children: [
            // Left: Node Palette
            if (_showNodePalette) ...[
              SizedBox(
                width: _nodePaletteWidth,
                child: NodePalette(
                  onNodeSelected: (nodeType) {
                    ref.read(workflowEditorProvider.notifier).addNode(nodeType);
                  },
                ),
              ),
              _buildVerticalResizeHandle(
                colorScheme,
                onDrag: (delta) {
                  setState(() {
                    _nodePaletteWidth = (_nodePaletteWidth + delta).clamp(180.0, 350.0);
                  });
                },
              ),
            ],

            // Center: Canvas
            Expanded(
              child: Column(
                children: [
                  // Canvas toolbar
                  _buildCanvasToolbar(context, state, colorScheme),
                  // Canvas
                  Expanded(
                    child: WorkflowCanvas(
                      onNodeSelected: (nodeId) {
                        ref.read(workflowEditorProvider.notifier).selectNode(nodeId);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Right: Properties Panel
            if (_showPropertiesPanel && state.selectedNodeId != null) ...[
              _buildVerticalResizeHandle(
                colorScheme,
                onDrag: (delta) {
                  setState(() {
                    _propertiesPanelWidth = (_propertiesPanelWidth - delta).clamp(250.0, 450.0);
                  });
                },
              ),
              SizedBox(
                width: _propertiesPanelWidth,
                child: NodePropertiesPanel(
                  nodeId: state.selectedNodeId!,
                  onDelete: () {
                    ref.read(workflowEditorProvider.notifier).removeNode(state.selectedNodeId!);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WorkflowEditorState state,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      title: Row(
        children: [
          Icon(Icons.account_tree, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(state.workflow?.name ?? 'Workflow Editor'),
          if (state.isDirty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '*',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        // Save button
        TextButton.icon(
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save'),
          onPressed: state.isDirty ? _handleSave : null,
        ),
        const SizedBox(width: 8),

        // Test/Run button
        FilledButton.icon(
          icon: state.isExecuting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.play_arrow, size: 18),
          label: Text(state.isExecuting ? 'Running...' : 'Test'),
          onPressed: state.isExecuting
              ? () => ref.read(workflowEditorProvider.notifier).cancelExecution()
              : () => ref.read(workflowEditorProvider.notifier).executeWorkflow(),
        ),
        const SizedBox(width: 8),

        // Import/Export menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'More options',
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'import',
              child: ListTile(
                leading: Icon(Icons.file_upload),
                title: Text('Import ComfyUI JSON'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: ListTile(
                leading: Icon(Icons.file_download),
                title: Text('Export ComfyUI JSON'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'clipboard_import',
              child: ListTile(
                leading: Icon(Icons.content_paste),
                title: Text('Import from Clipboard'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'clipboard_export',
              child: ListTile(
                leading: Icon(Icons.content_copy),
                title: Text('Copy to Clipboard'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'new',
              child: ListTile(
                leading: Icon(Icons.add),
                title: Text('New Workflow'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: ListTile(
                leading: Icon(Icons.delete_sweep),
                title: Text('Clear All Nodes'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCanvasToolbar(
    BuildContext context,
    WorkflowEditorState state,
    ColorScheme colorScheme,
  ) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // Toggle node palette
          IconButton(
            icon: Icon(
              Icons.view_sidebar,
              size: 18,
              color: _showNodePalette ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Toggle Node Palette',
            onPressed: () {
              setState(() => _showNodePalette = !_showNodePalette);
            },
          ),

          const VerticalDivider(width: 16),

          // Zoom controls
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 18),
            tooltip: 'Zoom Out',
            onPressed: () {
              ref.read(workflowEditorProvider.notifier).updateZoom(state.zoom - 0.1);
            },
          ),
          GestureDetector(
            onTap: () {
              ref.read(workflowEditorProvider.notifier).updateZoom(1.0);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(state.zoom * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 18),
            tooltip: 'Zoom In',
            onPressed: () {
              ref.read(workflowEditorProvider.notifier).updateZoom(state.zoom + 0.1);
            },
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen, size: 18),
            tooltip: 'Fit to View',
            onPressed: () {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                ref.read(workflowEditorProvider.notifier).fitInView(box.size);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong, size: 18),
            tooltip: 'Reset View',
            onPressed: () {
              ref.read(workflowEditorProvider.notifier).resetView();
            },
          ),

          const Spacer(),

          // Node count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.grid_view, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${state.workflow?.nodes.length ?? 0} nodes',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Connection count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cable, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${state.workflow?.connections.length ?? 0} connections',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const VerticalDivider(width: 16),

          // Toggle properties panel
          IconButton(
            icon: Icon(
              Icons.tune,
              size: 18,
              color: _showPropertiesPanel ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Toggle Properties Panel',
            onPressed: () {
              setState(() => _showPropertiesPanel = !_showPropertiesPanel);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalResizeHandle(
    ColorScheme colorScheme, {
    required void Function(double delta) onDrag,
  }) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 6,
          color: colorScheme.surfaceContainerHigh,
          child: Center(
            child: Container(
              width: 2,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final state = ref.read(workflowEditorProvider);

    // Ctrl+S - Save
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyS) {
      _handleSave();
    }
    // Ctrl+Z - Undo (placeholder)
    else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
      // TODO: Implement undo
    }
    // Ctrl+Y - Redo (placeholder)
    else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyY) {
      // TODO: Implement redo
    }
    // Delete - Delete selected node
    else if (event.logicalKey == LogicalKeyboardKey.delete) {
      if (state.selectedNodeId != null) {
        ref.read(workflowEditorProvider.notifier).removeNode(state.selectedNodeId!);
      }
    }
    // Escape - Deselect / Cancel connection
    else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (state.pendingConnection != null) {
        ref.read(workflowEditorProvider.notifier).cancelConnection();
      } else {
        ref.read(workflowEditorProvider.notifier).selectNode(null);
      }
    }
  }

  void _handleSave() async {
    final notifier = ref.read(workflowEditorProvider.notifier);
    final state = ref.read(workflowEditorProvider);

    if (state.workflow == null) return;

    final success = await notifier.saveWorkflow();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workflow saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
      widget.onSave?.call(state.workflow!);
    }
  }

  void _handleMenuAction(String action) async {
    final notifier = ref.read(workflowEditorProvider.notifier);
    final state = ref.read(workflowEditorProvider);

    switch (action) {
      case 'import':
        _importFromFile();
        break;

      case 'export':
        _exportToFile();
        break;

      case 'clipboard_import':
        final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
        if (clipboardData?.text != null) {
          notifier.importFromComfyUI(clipboardData!.text!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Workflow imported from clipboard')),
            );
          }
        }
        break;

      case 'clipboard_export':
        final json = notifier.exportToComfyUI();
        if (json != null) {
          await Clipboard.setData(ClipboardData(text: json));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Workflow copied to clipboard')),
            );
          }
        }
        break;

      case 'new':
        _showNewWorkflowDialog();
        break;

      case 'clear':
        _showClearConfirmDialog();
        break;
    }
  }

  void _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final json = utf8.decode(result.files.single.bytes!);
      ref.read(workflowEditorProvider.notifier).importFromComfyUI(
        json,
        name: result.files.single.name.replaceAll('.json', ''),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workflow imported successfully')),
        );
      }
    }
  }

  void _exportToFile() async {
    final notifier = ref.read(workflowEditorProvider.notifier);
    final state = ref.read(workflowEditorProvider);
    final json = notifier.exportToComfyUI();

    if (json == null) return;

    final fileName = '${state.workflow?.name ?? "workflow"}.json';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Workflow',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      // Write the file after getting the path
      final file = File(result);
      await file.writeAsString(json);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workflow exported successfully')),
        );
      }
    }
  }

  void _showNewWorkflowDialog() {
    final nameController = TextEditingController(text: 'New Workflow');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Workflow'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Workflow Name',
            border: OutlineInputBorder(),
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
              Navigator.of(context).pop();
              ref.read(workflowEditorProvider.notifier).newWorkflow(
                name: nameController.text.trim(),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Nodes'),
        content: const Text('Are you sure you want to remove all nodes? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              // Clear all nodes by creating a new workflow with same name
              final state = ref.read(workflowEditorProvider);
              ref.read(workflowEditorProvider.notifier).newWorkflow(
                name: state.workflow?.name ?? 'New Workflow',
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
