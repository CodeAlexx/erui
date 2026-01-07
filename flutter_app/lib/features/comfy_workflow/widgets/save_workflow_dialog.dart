import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';

/// Dialog for saving a new workflow
class SaveWorkflowDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialWorkflow;

  const SaveWorkflowDialog({super.key, this.initialWorkflow});

  /// Show the save workflow dialog
  static Future<Map<String, dynamic>?> show(BuildContext context, {Map<String, dynamic>? initialWorkflow}) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SaveWorkflowDialog(initialWorkflow: initialWorkflow),
    );
  }

  @override
  ConsumerState<SaveWorkflowDialog> createState() => _SaveWorkflowDialogState();
}

class _SaveWorkflowDialogState extends ConsumerState<SaveWorkflowDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _enableInGenerate = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialWorkflow != null) {
      _nameController.text = widget.initialWorkflow!['name'] ?? '';
      _descriptionController.text = widget.initialWorkflow!['description'] ?? '';
      _tagsController.text = (widget.initialWorkflow!['tags'] as List?)?.join(', ') ?? '';
      _enableInGenerate = widget.initialWorkflow!['enable_in_generate'] ?? true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final api = ref.read(apiServiceProvider);
      final name = _nameController.text.trim();
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final workflow = {
        'name': name,
        'description': _descriptionController.text.trim(),
        'tags': tags,
        'enable_in_generate': _enableInGenerate,
        // Include initial workflow prompt if provided
        if (widget.initialWorkflow?['prompt'] != null)
          'prompt': widget.initialWorkflow!['prompt'],
        if (widget.initialWorkflow?['workflow'] != null)
          'workflow': widget.initialWorkflow!['workflow'],
        if (widget.initialWorkflow?['parameters'] != null)
          'parameters': widget.initialWorkflow!['parameters'],
      };

      final response = await api.postJson('/api/workflows/$name', workflow);

      if (response != null && response['success'] == true) {
        if (mounted) Navigator.pop(context, workflow);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save: ${response?['error'] ?? 'Unknown error'}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surface,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.save, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Save Workflow',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Workflow Name',
                  hintText: 'My Workflow',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  if (value.contains('/') || value.contains('\\') || value.contains('..')) {
                    return 'Invalid characters in name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'What does this workflow do?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Tags field
              TextFormField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: 'Tags',
                  hintText: 'text2img, sdxl, lora (comma separated)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              // Enable in Generate toggle
              SwitchListTile(
                title: const Text('Show in Generate Tab'),
                subtitle: const Text('Allow selecting this workflow from Generate'),
                value: _enableInGenerate,
                onChanged: (v) => setState(() => _enableInGenerate = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
