import 'package:flutter/material.dart';

import '../../../services/wildcards_service.dart';

/// Dialog for creating/editing wildcards
class WildcardEditorDialog extends StatefulWidget {
  final Wildcard? wildcard;
  final List<String> folders;
  final String currentFolder;
  final Function(Wildcard) onSave;

  const WildcardEditorDialog({
    super.key,
    this.wildcard,
    required this.folders,
    required this.currentFolder,
    required this.onSave,
  });

  @override
  State<WildcardEditorDialog> createState() => _WildcardEditorDialogState();
}

class _WildcardEditorDialogState extends State<WildcardEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _optionsController;
  late final TextEditingController _newFolderController;
  late String _selectedFolder;
  bool _creatingNewFolder = false;
  String? _randomPreview;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.wildcard?.name ?? '');
    _optionsController = TextEditingController(
      text: widget.wildcard?.options.join('\n') ?? '',
    );
    _newFolderController = TextEditingController();
    _selectedFolder = widget.wildcard?.folder ?? widget.currentFolder;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _optionsController.dispose();
    _newFolderController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.wildcard != null;

  List<String> get _currentOptions {
    return _optionsController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  void _rollRandomPreview() {
    final options = _currentOptions;
    if (options.isEmpty) {
      setState(() => _randomPreview = null);
      return;
    }
    final index = DateTime.now().microsecond % options.length;
    setState(() => _randomPreview = options[index]);
  }

  void _validateName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
    } else if (name.contains('/') || name.contains('\\')) {
      setState(() => _nameError = 'Name cannot contain slashes');
    } else {
      setState(() => _nameError = null);
    }
  }

  bool _validate() {
    _validateName();
    if (_nameError != null) return false;
    if (_currentOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one option')),
      );
      return false;
    }
    return true;
  }

  void _save() {
    if (!_validate()) return;

    final folder = _creatingNewFolder
        ? _newFolderController.text.trim()
        : _selectedFolder;

    final wildcard = Wildcard(
      name: _nameController.text.trim(),
      folder: folder,
      options: _currentOptions,
      createdAt: widget.wildcard?.createdAt,
    );

    widget.onSave(wildcard);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEditing ? Icons.edit : Icons.add_circle,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Edit Wildcard' : 'New Wildcard',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Name field
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g., colors, animals, styles',
                        prefixIcon: const Icon(Icons.label),
                        errorText: _nameError,
                      ),
                      onChanged: (_) => _validateName(),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    // Folder selector
                    _FolderSelector(
                      folders: widget.folders,
                      selectedFolder: _selectedFolder,
                      creatingNewFolder: _creatingNewFolder,
                      newFolderController: _newFolderController,
                      onFolderSelected: (folder) {
                        setState(() {
                          _selectedFolder = folder;
                          _creatingNewFolder = false;
                        });
                      },
                      onCreateNewFolder: () {
                        setState(() {
                          _creatingNewFolder = true;
                        });
                      },
                      onCancelNewFolder: () {
                        setState(() {
                          _creatingNewFolder = false;
                          _newFolderController.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    // Options text area
                    Text(
                      'Options (one per line)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _optionsController,
                      decoration: InputDecoration(
                        hintText: 'red\nblue\ngreen\nyellow',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 10,
                      minLines: 6,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_currentOptions.length} options',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 20),
                    // Random preview
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Random Preview',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(color: colorScheme.outline),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _randomPreview ?? 'Click to preview',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        fontStyle: _randomPreview == null
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                        color: _randomPreview == null
                                            ? colorScheme.outline
                                            : null,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _currentOptions.isNotEmpty
                                ? _rollRandomPreview
                                : null,
                            icon: const Icon(Icons.casino),
                            label: const Text('Roll'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: Text(_isEditing ? 'Save Changes' : 'Create'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Folder selector widget
class _FolderSelector extends StatelessWidget {
  final List<String> folders;
  final String selectedFolder;
  final bool creatingNewFolder;
  final TextEditingController newFolderController;
  final Function(String) onFolderSelected;
  final VoidCallback onCreateNewFolder;
  final VoidCallback onCancelNewFolder;

  const _FolderSelector({
    required this.folders,
    required this.selectedFolder,
    required this.creatingNewFolder,
    required this.newFolderController,
    required this.onFolderSelected,
    required this.onCreateNewFolder,
    required this.onCancelNewFolder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (creatingNewFolder) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: newFolderController,
              decoration: InputDecoration(
                labelText: 'New Folder Name',
                hintText: 'e.g., styles/anime',
                prefixIcon: const Icon(Icons.create_new_folder),
                helperText: 'Use / to create nested folders',
              ),
              autofocus: true,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onCancelNewFolder,
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Folder',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Root folder option
            _FolderChip(
              label: 'Root',
              icon: Icons.folder_special,
              isSelected: selectedFolder.isEmpty,
              onTap: () => onFolderSelected(''),
            ),
            // Existing folders
            ...folders.map((folder) => _FolderChip(
                  label: folder,
                  icon: Icons.folder,
                  isSelected: selectedFolder == folder,
                  onTap: () => onFolderSelected(folder),
                )),
            // Create new folder button
            ActionChip(
              avatar: Icon(
                Icons.add,
                size: 18,
                color: colorScheme.primary,
              ),
              label: const Text('New Folder'),
              onPressed: onCreateNewFolder,
            ),
          ],
        ),
      ],
    );
  }
}

/// Folder chip widget
class _FolderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FolderChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
      onSelected: (_) => onTap(),
    );
  }
}

/// Inline wildcard editor for quick edits
class WildcardQuickEditor extends StatefulWidget {
  final Wildcard wildcard;
  final Function(Wildcard) onSave;
  final VoidCallback onCancel;

  const WildcardQuickEditor({
    super.key,
    required this.wildcard,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<WildcardQuickEditor> createState() => _WildcardQuickEditorState();
}

class _WildcardQuickEditorState extends State<WildcardQuickEditor> {
  late final TextEditingController _optionsController;

  @override
  void initState() {
    super.initState();
    _optionsController = TextEditingController(
      text: widget.wildcard.options.join('\n'),
    );
  }

  @override
  void dispose() {
    _optionsController.dispose();
    super.dispose();
  }

  List<String> get _currentOptions {
    return _optionsController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  void _save() {
    if (_currentOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one option')),
      );
      return;
    }

    final updated = widget.wildcard.copyWith(options: _currentOptions);
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.edit, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Edit: ${widget.wildcard.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _optionsController,
            decoration: InputDecoration(
              hintText: 'One option per line',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 8,
            minLines: 4,
          ),
          const SizedBox(height: 8),
          Text(
            '${_currentOptions.length} options',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
