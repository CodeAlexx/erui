import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'models/eri_workflow_models.dart';

/// Dialog for saving/editing workflow metadata
/// Allows setting name, folder, description, preview image, and custom parameters
class WorkflowSaveDialog extends StatefulWidget {
  final EriWorkflow? existingWorkflow;  // null for new workflow
  final String workflowJson;            // The ComfyUI workflow JSON
  final String promptJson;              // The execution prompt JSON
  final List<String> availableFolders;  // Available folders for selection
  final Function(EriWorkflow) onSave;   // Callback when workflow is saved

  const WorkflowSaveDialog({
    super.key,
    this.existingWorkflow,
    required this.workflowJson,
    required this.promptJson,
    this.availableFolders = const [],
    required this.onSave,
  });

  @override
  State<WorkflowSaveDialog> createState() => _WorkflowSaveDialogState();

  /// Show the dialog and return the saved workflow, or null if cancelled
  static Future<EriWorkflow?> show({
    required BuildContext context,
    EriWorkflow? existingWorkflow,
    required String workflowJson,
    required String promptJson,
    List<String> availableFolders = const [],
  }) async {
    EriWorkflow? result;
    await showDialog(
      context: context,
      builder: (context) => WorkflowSaveDialog(
        existingWorkflow: existingWorkflow,
        workflowJson: workflowJson,
        promptJson: promptJson,
        availableFolders: availableFolders,
        onSave: (workflow) {
          result = workflow;
          Navigator.pop(context);
        },
      ),
    );
    return result;
  }
}

class _WorkflowSaveDialogState extends State<WorkflowSaveDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  String? _selectedFolder;
  String? _previewImage;
  bool _enableInSimple = false;
  bool _showCustomParamsEditor = false;
  List<EriWorkflowParam> _customParams = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final existing = widget.existingWorkflow;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _selectedFolder = existing?.folder;
    _previewImage = existing?.image;
    _enableInSimple = existing?.enableInSimple ?? false;
    _customParams = existing?.parameters ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPreviewImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _previewImage = base64Encode(file.bytes!);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _saveWorkflow() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final workflow = EriWorkflow(
      id: widget.existingWorkflow?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      folder: _selectedFolder,
      workflow: widget.workflowJson,
      prompt: widget.promptJson,
      customParams: jsonEncode(_customParams.map((p) => p.toJson()).toList()),
      paramValues: widget.existingWorkflow?.paramValues ?? '{}',
      image: _previewImage,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      enableInSimple: _enableInSimple,
      createdAt: widget.existingWorkflow?.createdAt ?? now,
      updatedAt: now,
    );

    widget.onSave(workflow);
  }

  void _addCustomParam() {
    setState(() {
      _customParams.add(EriWorkflowParam(
        id: 'param_${_customParams.length + 1}',
        name: 'New Parameter',
        type: 'text',
      ));
    });
  }

  void _removeCustomParam(int index) {
    setState(() {
      _customParams.removeAt(index);
    });
  }

  void _updateCustomParam(int index, EriWorkflowParam param) {
    setState(() {
      _customParams[index] = param;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.existingWorkflow != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit : Icons.save,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(isEditing ? 'Edit Workflow' : 'Save Workflow'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Workflow Name',
                    hintText: 'My Custom Workflow',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a workflow name';
                    }
                    return null;
                  },
                  autofocus: true,
                ),
                const SizedBox(height: 16),

                // Folder selection
                DropdownButtonFormField<String>(
                  value: _selectedFolder,
                  decoration: const InputDecoration(
                    labelText: 'Folder',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Root'),
                    ),
                    ...widget.availableFolders.map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(f),
                    )),
                  ],
                  onChanged: (v) => setState(() => _selectedFolder = v),
                ),
                const SizedBox(height: 16),

                // Description field
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional description of what this workflow does',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Preview image
                _PreviewImageSection(
                  previewImage: _previewImage,
                  onPickImage: _pickPreviewImage,
                  onClearImage: () => setState(() => _previewImage = null),
                ),
                const SizedBox(height: 16),

                // Enable in simple toggle
                SwitchListTile(
                  title: const Text('Show in Quick Generate'),
                  subtitle: Text(
                    'Display this workflow in the simple generation tab',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  value: _enableInSimple,
                  onChanged: (v) => setState(() => _enableInSimple = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),

                // Custom parameters section
                ExpansionTile(
                  title: Row(
                    children: [
                      const Text('Custom Parameters'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_customParams.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  initiallyExpanded: _showCustomParamsEditor,
                  onExpansionChanged: (v) => setState(() => _showCustomParamsEditor = v),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8),
                  children: [
                    _CustomParamsEditor(
                      params: _customParams,
                      onAddParam: _addCustomParam,
                      onRemoveParam: _removeCustomParam,
                      onUpdateParam: _updateCustomParam,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _saveWorkflow,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

/// Preview image selection section
class _PreviewImageSection extends StatelessWidget {
  final String? previewImage;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;

  const _PreviewImageSection({
    required this.previewImage,
    required this.onPickImage,
    required this.onClearImage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = previewImage != null && previewImage!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview Image',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPickImage,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasImage ? colorScheme.primary : colorScheme.outlineVariant,
              ),
            ),
            child: hasImage
                ? Stack(
                    children: [
                      Center(child: _buildImagePreview(previewImage!, colorScheme)),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: Icon(Icons.close, size: 18, color: colorScheme.error),
                          onPressed: onClearImage,
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.surface.withOpacity(0.8),
                          ),
                          tooltip: 'Remove image',
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate, size: 32, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text(
                          'Click to select preview image',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          'or capture from current output',
                          style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(String imageData, ColorScheme colorScheme) {
    try {
      String data = imageData;
      if (data.startsWith('data:')) {
        data = data.split(',').last;
      }
      final bytes = base64Decode(data);
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          bytes,
          height: 110,
          fit: BoxFit.contain,
        ),
      );
    } catch (e) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image, size: 18, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text('Preview set', style: TextStyle(fontSize: 12, color: colorScheme.primary)),
        ],
      );
    }
  }
}

/// Custom parameters editor
class _CustomParamsEditor extends StatelessWidget {
  final List<EriWorkflowParam> params;
  final VoidCallback onAddParam;
  final Function(int) onRemoveParam;
  final Function(int, EriWorkflowParam) onUpdateParam;

  const _CustomParamsEditor({
    required this.params,
    required this.onAddParam,
    required this.onRemoveParam,
    required this.onUpdateParam,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info text
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: colorScheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Define parameters that users can adjust. Use \${param_id} in your workflow to reference them.',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Parameter list
        if (params.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No custom parameters defined',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ...params.asMap().entries.map((entry) => _CustomParamRow(
            index: entry.key,
            param: entry.value,
            onRemove: () => onRemoveParam(entry.key),
            onUpdate: (param) => onUpdateParam(entry.key, param),
          )),

        // Add parameter button
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAddParam,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Parameter'),
        ),
      ],
    );
  }
}

/// Single custom parameter row editor
class _CustomParamRow extends StatefulWidget {
  final int index;
  final EriWorkflowParam param;
  final VoidCallback onRemove;
  final Function(EriWorkflowParam) onUpdate;

  const _CustomParamRow({
    required this.index,
    required this.param,
    required this.onRemove,
    required this.onUpdate,
  });

  @override
  State<_CustomParamRow> createState() => _CustomParamRowState();
}

class _CustomParamRowState extends State<_CustomParamRow> {
  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _defaultController;
  late TextEditingController _valuesController;
  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _groupController;

  static const List<String> _typeOptions = [
    'text',
    'dropdown',
    'integer',
    'decimal',
    'boolean',
    'image',
    'model',
    'multiline',
    'color',
  ];

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.param.id);
    _nameController = TextEditingController(text: widget.param.name);
    _descriptionController = TextEditingController(text: widget.param.description ?? '');
    _defaultController = TextEditingController(text: widget.param.defaultValue?.toString() ?? '');
    _valuesController = TextEditingController(text: widget.param.values?.join(', ') ?? '');
    _minController = TextEditingController(text: widget.param.min?.toString() ?? '');
    _maxController = TextEditingController(text: widget.param.max?.toString() ?? '');
    _groupController = TextEditingController(text: widget.param.group ?? '');
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _defaultController.dispose();
    _valuesController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  void _updateParam() {
    final values = _valuesController.text.trim().isNotEmpty
        ? _valuesController.text.split(',').map((s) => s.trim()).toList()
        : null;

    widget.onUpdate(widget.param.copyWith(
      id: _idController.text.trim(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      defaultValue: _defaultController.text.trim().isNotEmpty
          ? _defaultController.text.trim()
          : null,
      values: values,
      min: _minController.text.trim().isNotEmpty
          ? num.tryParse(_minController.text.trim())
          : null,
      max: _maxController.text.trim().isNotEmpty
          ? num.tryParse(_maxController.text.trim())
          : null,
      group: _groupController.text.trim().isNotEmpty
          ? _groupController.text.trim()
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showNumericFields = ['integer', 'decimal', 'int', 'float', 'double', 'number'].contains(widget.param.type);
    final showDropdownValues = ['dropdown', 'select', 'enum'].contains(widget.param.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with delete button
          Row(
            children: [
              Text(
                'Parameter ${widget.index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
                onPressed: widget.onRemove,
                tooltip: 'Remove parameter',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ID and Name row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'ID',
                    hintText: 'my_param',
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (_) => _updateParam(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'My Parameter',
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (_) => _updateParam(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Type and Group row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: widget.param.type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                  items: _typeOptions.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      widget.onUpdate(widget.param.copyWith(type: v));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _groupController,
                  decoration: const InputDecoration(
                    labelText: 'Group',
                    hintText: 'General',
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (_) => _updateParam(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Default value and description
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _defaultController,
                  decoration: const InputDecoration(
                    labelText: 'Default Value',
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (_) => _updateParam(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (_) => _updateParam(),
                ),
              ),
            ],
          ),

          // Numeric fields (min/max)
          if (showNumericFields) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    decoration: const InputDecoration(
                      labelText: 'Min',
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateParam(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    decoration: const InputDecoration(
                      labelText: 'Max',
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updateParam(),
                  ),
                ),
              ],
            ),
          ],

          // Dropdown values
          if (showDropdownValues) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _valuesController,
              decoration: const InputDecoration(
                labelText: 'Values (comma-separated)',
                hintText: 'option1, option2, option3',
                isDense: true,
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (_) => _updateParam(),
            ),
          ],
        ],
      ),
    );
  }
}
