import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/models_provider.dart';

/// Model tag editor dialog for managing user-defined tags on models
class ModelTagEditor extends ConsumerStatefulWidget {
  final ModelInfo model;

  const ModelTagEditor({
    super.key,
    required this.model,
  });

  @override
  ConsumerState<ModelTagEditor> createState() => _ModelTagEditorState();
}

class _ModelTagEditorState extends ConsumerState<ModelTagEditor> {
  final _tagController = TextEditingController();
  late Set<String> _currentTags;

  @override
  void initState() {
    super.initState();
    _currentTags = Set.from(
      ref.read(modelUserDataProvider).getTags(widget.model.modelKey),
    );
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmed = tag.trim().toLowerCase();
    if (trimmed.isNotEmpty && !_currentTags.contains(trimmed)) {
      setState(() {
        _currentTags.add(trimmed);
      });
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _currentTags.remove(tag);
    });
  }

  void _saveTags() {
    ref.read(modelUserDataProvider.notifier).setTags(
      widget.model.modelKey,
      _currentTags,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allTags = ref.watch(modelUserDataProvider.notifier).allUniqueTags.toList()..sort();

    // Get suggested tags (tags used on other models but not this one)
    final suggestedTags = allTags.where((t) => !_currentTags.contains(t)).take(10).toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.label, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Tags',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          widget.model.displayName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add tag input
                    TextField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        labelText: 'Add tag',
                        hintText: 'Type a tag and press Enter',
                        prefixIcon: const Icon(Icons.add),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: () => _addTag(_tagController.text),
                        ),
                      ),
                      onSubmitted: _addTag,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 16),

                    // Current tags
                    Text(
                      'Current Tags',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_currentTags.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.label_off, color: colorScheme.outline),
                            const SizedBox(width: 8),
                            Text(
                              'No tags yet',
                              style: TextStyle(color: colorScheme.outline),
                            ),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _currentTags.map((tag) => Chip(
                          label: Text(tag),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () => _removeTag(tag),
                        )).toList(),
                      ),

                    // Suggested tags
                    if (suggestedTags.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Suggested Tags',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: suggestedTags.map((tag) => ActionChip(
                          label: Text(tag),
                          avatar: const Icon(Icons.add, size: 16),
                          onPressed: () => _addTag(tag),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
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
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saveTags,
                    child: const Text('Save Tags'),
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
