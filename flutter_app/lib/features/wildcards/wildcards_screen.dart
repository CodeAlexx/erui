import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../services/wildcards_service.dart';
import '../../widgets/widgets.dart';
import 'widgets/wildcard_editor.dart';

/// Screen for managing wildcards
class WildcardsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onCollapse;
  const WildcardsScreen({super.key, this.onCollapse});

  @override
  ConsumerState<WildcardsScreen> createState() => _WildcardsScreenState();
}

class _WildcardsScreenState extends ConsumerState<WildcardsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wildcardsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Toolbar
        _WildcardsToolbar(
          onCreateNew: () => _showEditor(context, ref, null),
          onImport: () => _importFromFile(context, ref),
          onRefresh: () => ref.read(wildcardsProvider.notifier).loadWildcards(),
          onCollapse: widget.onCollapse,
        ),
        const Divider(height: 1),
        // Main content
        Expanded(
          child: state.isLoading
              ? const LoadingIndicator(message: 'Loading wildcards...')
              : state.error != null
                  ? ErrorDisplay(
                      message: state.error!,
                      onRetry: () =>
                          ref.read(wildcardsProvider.notifier).loadWildcards(),
                    )
                  : Row(
                      children: [
                        // Folder tree
                        SizedBox(
                          width: 250,
                          child: _FolderTree(
                            folderTree: state.buildFolderTree(),
                            selectedFolder: state.selectedFolder,
                            onFolderSelected: (folder) {
                              ref
                                  .read(wildcardsProvider.notifier)
                                  .selectFolder(folder);
                            },
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: colorScheme.outlineVariant,
                        ),
                        // Wildcard list
                        Expanded(
                          flex: 2,
                          child: _WildcardList(
                            wildcards: state.filteredWildcards,
                            selectedWildcard: state.selectedWildcard,
                            onWildcardSelected: (wildcard) {
                              ref
                                  .read(wildcardsProvider.notifier)
                                  .selectWildcard(wildcard);
                            },
                            onWildcardEdit: (wildcard) =>
                                _showEditor(context, ref, wildcard),
                            onWildcardDelete: (wildcard) =>
                                _confirmDelete(context, ref, wildcard),
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: colorScheme.outlineVariant,
                        ),
                        // Preview panel
                        Expanded(
                          flex: 3,
                          child: _PreviewPanel(
                            wildcard: state.selectedWildcard,
                            onEdit: () => _showEditor(
                                context, ref, state.selectedWildcard),
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  void _showEditor(BuildContext context, WidgetRef ref, Wildcard? wildcard) {
    final state = ref.read(wildcardsProvider);
    showDialog(
      context: context,
      builder: (context) => WildcardEditorDialog(
        wildcard: wildcard,
        folders: state.folders,
        currentFolder: state.selectedFolder,
        onSave: (newWildcard) async {
          final notifier = ref.read(wildcardsProvider.notifier);
          bool success;
          if (wildcard == null) {
            success = await notifier.createWildcard(newWildcard);
          } else {
            success = await notifier.updateWildcard(wildcard, newWildcard);
          }
          if (success && context.mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Future<void> _importFromFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      final notifier = ref.read(wildcardsProvider.notifier);
      int imported = 0;
      int failed = 0;

      for (final file in result.files) {
        if (file.path == null) continue;

        try {
          final content = await File(file.path!).readAsString();
          final name = file.name.replaceAll('.txt', '');
          final success = await notifier.importFromText(name, content);
          if (success) {
            imported++;
          } else {
            failed++;
          }
        } catch (e) {
          failed++;
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failed > 0
                  ? 'Imported $imported wildcards, $failed failed'
                  : 'Imported $imported wildcards',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Wildcard wildcard,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wildcard'),
        content: Text(
          'Are you sure you want to delete "${wildcard.name}"?\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(wildcardsProvider.notifier).deleteWildcard(wildcard);
    }
  }
}

/// Toolbar for wildcards screen
class _WildcardsToolbar extends StatelessWidget {
  final VoidCallback onCreateNew;
  final VoidCallback onImport;
  final VoidCallback onRefresh;
  final VoidCallback? onCollapse;

  const _WildcardsToolbar({
    required this.onCreateNew,
    required this.onImport,
    required this.onRefresh,
    this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.surface,
      child: Row(
        children: [
          Icon(Icons.casino, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Wildcards',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(width: 24),
          FilledButton.icon(
            onPressed: onCreateNew,
            icon: const Icon(Icons.add),
            label: const Text('New Wildcard'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.file_upload),
            label: const Text('Import'),
          ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          if (onCollapse != null)
            IconButton(
              onPressed: onCollapse,
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Collapse panel',
            ),
        ],
      ),
    );
  }
}

/// Folder tree widget
class _FolderTree extends StatelessWidget {
  final WildcardFolder folderTree;
  final String selectedFolder;
  final Function(String) onFolderSelected;

  const _FolderTree({
    required this.folderTree,
    required this.selectedFolder,
    required this.onFolderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.folder, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Folders',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                // Root folder
                _FolderTile(
                  name: 'All Wildcards',
                  path: '',
                  depth: 0,
                  isSelected: selectedFolder.isEmpty,
                  wildcardCount: folderTree.wildcards.length,
                  onTap: () => onFolderSelected(''),
                ),
                // Subfolders
                ..._buildFolderTiles(folderTree.subfolders, 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFolderTiles(List<WildcardFolder> folders, int depth) {
    final tiles = <Widget>[];
    for (final folder in folders) {
      tiles.add(
        _FolderTile(
          name: folder.name,
          path: folder.path,
          depth: depth,
          isSelected: selectedFolder == folder.path,
          wildcardCount: folder.wildcards.length,
          onTap: () => onFolderSelected(folder.path),
        ),
      );
      tiles.addAll(_buildFolderTiles(folder.subfolders, depth + 1));
    }
    return tiles;
  }
}

/// Single folder tile in the tree
class _FolderTile extends StatelessWidget {
  final String name;
  final String path;
  final int depth;
  final bool isSelected;
  final int wildcardCount;
  final VoidCallback onTap;

  const _FolderTile({
    required this.name,
    required this.path,
    required this.depth,
    required this.isSelected,
    required this.wildcardCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(
        left: 16 + (depth * 16),
        right: 16,
      ),
      leading: Icon(
        depth == 0 ? Icons.folder_special : Icons.folder,
        size: 20,
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$wildcardCount',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      selected: isSelected,
      selectedColor: colorScheme.primary,
      selectedTileColor: colorScheme.primaryContainer.withOpacity(0.3),
      onTap: onTap,
    );
  }
}

/// Wildcard list widget
class _WildcardList extends StatelessWidget {
  final List<Wildcard> wildcards;
  final Wildcard? selectedWildcard;
  final Function(Wildcard) onWildcardSelected;
  final Function(Wildcard) onWildcardEdit;
  final Function(Wildcard) onWildcardDelete;

  const _WildcardList({
    required this.wildcards,
    required this.selectedWildcard,
    required this.onWildcardSelected,
    required this.onWildcardEdit,
    required this.onWildcardDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (wildcards.isEmpty) {
      return const EmptyState(
        title: 'No wildcards',
        message: 'Create a new wildcard or select a different folder',
        icon: Icons.casino_outlined,
      );
    }

    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.list, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Wildcards (${wildcards.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: wildcards.length,
              itemBuilder: (context, index) {
                final wildcard = wildcards[index];
                final isSelected = selectedWildcard?.name == wildcard.name &&
                    selectedWildcard?.folder == wildcard.folder;

                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.casino,
                    size: 20,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    wildcard.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${wildcard.options.length} options',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => onWildcardEdit(wildcard),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        onPressed: () => onWildcardDelete(wildcard),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: colorScheme.primary,
                  selectedTileColor:
                      colorScheme.primaryContainer.withOpacity(0.3),
                  onTap: () => onWildcardSelected(wildcard),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Preview panel for selected wildcard
class _PreviewPanel extends ConsumerStatefulWidget {
  final Wildcard? wildcard;
  final VoidCallback onEdit;

  const _PreviewPanel({
    required this.wildcard,
    required this.onEdit,
  });

  @override
  ConsumerState<_PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends ConsumerState<_PreviewPanel> {
  String? _randomSelection;

  @override
  void didUpdateWidget(_PreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wildcard != oldWidget.wildcard) {
      _randomSelection = null;
    }
  }

  void _getRandomSelection() {
    if (widget.wildcard != null && widget.wildcard!.options.isNotEmpty) {
      setState(() {
        _randomSelection = widget.wildcard!.getRandomOption();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final wildcard = widget.wildcard;

    if (wildcard == null) {
      return const EmptyState(
        title: 'No wildcard selected',
        message: 'Select a wildcard to preview its contents',
        icon: Icons.visibility_outlined,
      );
    }

    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.casino, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wildcard.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (wildcard.folder.isNotEmpty)
                        Text(
                          'Folder: ${wildcard.folder}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                        ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Random selection
          Container(
            padding: const EdgeInsets.all(16),
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Random Selection',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.outline,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Text(
                          _randomSelection ?? 'Click "Roll" to get a random option',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontStyle: _randomSelection == null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                color: _randomSelection == null
                                    ? colorScheme.outline
                                    : null,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _getRandomSelection,
                  icon: const Icon(Icons.casino),
                  label: const Text('Roll'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Options list header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Options (${wildcard.options.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  'Usage: __${wildcard.fullPath}__',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Options list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: wildcard.options.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final option = wildcard.options[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${index + 1}.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(option),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
