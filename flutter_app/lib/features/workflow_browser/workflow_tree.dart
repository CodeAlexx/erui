import 'package:flutter/material.dart';

/// Hierarchical folder tree navigation widget for workflow browser
class WorkflowTree extends StatelessWidget {
  /// List of folder paths
  final List<String> folders;

  /// Currently selected folder (null for root/all)
  final String? currentFolder;

  /// Set of expanded folder paths
  final Set<String> expandedFolders;

  /// Map of folder path to workflow count
  final Map<String, int> workflowCounts;

  /// Callback when a folder is selected
  final void Function(String? folder) onFolderSelected;

  /// Callback when a folder is toggled (expanded/collapsed)
  final void Function(String folder) onFolderToggle;

  const WorkflowTree({
    super.key,
    required this.folders,
    this.currentFolder,
    this.expandedFolders = const {},
    this.workflowCounts = const {},
    required this.onFolderSelected,
    required this.onFolderToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Build folder tree structure
    final folderTree = _buildFolderTree();

    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _FolderTreeHeader(),

          const Divider(height: 1),

          // Folder list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                // Root/All folder
                _FolderTile(
                  name: 'All Workflows',
                  icon: Icons.folder_special,
                  isSelected: currentFolder == null,
                  count: workflowCounts.values.fold(0, (a, b) => a + b),
                  onTap: () => onFolderSelected(null),
                ),

                // Root-level items (no folder)
                if (workflowCounts[''] != null && workflowCounts['']! > 0)
                  _FolderTile(
                    name: 'Uncategorized',
                    icon: Icons.folder_outlined,
                    isSelected: currentFolder == '',
                    count: workflowCounts[''] ?? 0,
                    onTap: () => onFolderSelected(''),
                    indent: 0,
                  ),

                // Folder tree
                ...folderTree.entries.map((entry) {
                  return _buildFolderItem(
                    context,
                    entry.key,
                    entry.value,
                    0,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a nested folder tree from flat folder list
  Map<String, dynamic> _buildFolderTree() {
    final tree = <String, dynamic>{};

    for (final folder in folders) {
      if (folder.isEmpty) continue;

      final parts = folder.split('/');
      Map<String, dynamic> current = tree;

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (!current.containsKey(part)) {
          current[part] = <String, dynamic>{};
        }
        current = current[part] as Map<String, dynamic>;
      }
    }

    return tree;
  }

  Widget _buildFolderItem(
    BuildContext context,
    String name,
    Map<String, dynamic> children,
    int depth,
  ) {
    final fullPath = _buildFullPath(name, depth);
    final hasChildren = children.isNotEmpty;
    final isExpanded = expandedFolders.contains(fullPath);
    final isSelected = currentFolder == fullPath;
    final count = workflowCounts[fullPath] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FolderTile(
          name: name,
          icon: hasChildren
              ? (isExpanded ? Icons.folder_open : Icons.folder)
              : Icons.folder_outlined,
          isSelected: isSelected,
          isExpanded: isExpanded,
          hasChildren: hasChildren,
          count: count,
          indent: depth,
          onTap: () => onFolderSelected(fullPath),
          onToggle: hasChildren ? () => onFolderToggle(fullPath) : null,
        ),

        // Children (if expanded)
        if (hasChildren && isExpanded)
          ...children.entries.map((entry) {
            return _buildFolderItem(
              context,
              entry.key,
              entry.value as Map<String, dynamic>,
              depth + 1,
            );
          }),
      ],
    );
  }

  String _buildFullPath(String name, int depth) {
    // For now, simple implementation - could be enhanced for nested paths
    return name;
  }
}

/// Header for the folder tree
class _FolderTreeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.folder,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            'Folders',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

/// Individual folder tile in the tree
class _FolderTile extends StatefulWidget {
  final String name;
  final IconData icon;
  final bool isSelected;
  final bool isExpanded;
  final bool hasChildren;
  final int count;
  final int indent;
  final VoidCallback onTap;
  final VoidCallback? onToggle;

  const _FolderTile({
    required this.name,
    required this.icon,
    this.isSelected = false,
    this.isExpanded = false,
    this.hasChildren = false,
    this.count = 0,
    this.indent = 0,
    required this.onTap,
    this.onToggle,
  });

  @override
  State<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<_FolderTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final indentPadding = 12.0 + (widget.indent * 16.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: EdgeInsets.only(
            left: indentPadding,
            right: 8,
            top: 6,
            bottom: 6,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.primaryContainer.withOpacity(0.4)
                : _isHovered
                    ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
                    : null,
            border: Border(
              left: BorderSide(
                color: widget.isSelected ? colorScheme.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              // Expand/collapse button
              if (widget.hasChildren)
                GestureDetector(
                  onTap: widget.onToggle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      widget.isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const SizedBox(width: 20),

              // Folder icon
              Icon(
                widget.icon,
                size: 16,
                color: widget.isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),

              // Folder name
              Expanded(
                child: Text(
                  widget.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Count badge
              if (widget.count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? colorScheme.primary.withOpacity(0.2)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.count.toString(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: widget.isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simplified folder browser widget for horizontal layout
class WorkflowFolderChips extends StatelessWidget {
  final List<String> folders;
  final String? currentFolder;
  final Map<String, int> workflowCounts;
  final void Function(String? folder) onFolderSelected;

  const WorkflowFolderChips({
    super.key,
    required this.folders,
    this.currentFolder,
    this.workflowCounts = const {},
    required this.onFolderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalCount = workflowCounts.values.fold(0, (a, b) => a + b);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // All workflows chip
          _FolderChip(
            label: 'All',
            count: totalCount,
            isSelected: currentFolder == null,
            onTap: () => onFolderSelected(null),
          ),

          const SizedBox(width: 6),

          // Folder chips
          ...folders.map((folder) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FolderChip(
                label: folder.isEmpty ? 'Uncategorized' : folder,
                count: workflowCounts[folder] ?? 0,
                isSelected: currentFolder == folder,
                onTap: () => onFolderSelected(folder),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Individual folder chip
class _FolderChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FolderChip({
    required this.label,
    required this.count,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_outlined,
                size: 14,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withOpacity(0.3)
                        : colorScheme.outline.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count.toString(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapsible folder section widget
class CollapsibleFolderSection extends StatefulWidget {
  final String title;
  final List<String> folders;
  final String? currentFolder;
  final Map<String, int> workflowCounts;
  final void Function(String? folder) onFolderSelected;
  final bool initiallyExpanded;

  const CollapsibleFolderSection({
    super.key,
    required this.title,
    required this.folders,
    this.currentFolder,
    this.workflowCounts = const {},
    required this.onFolderSelected,
    this.initiallyExpanded = true,
  });

  @override
  State<CollapsibleFolderSection> createState() => _CollapsibleFolderSectionState();
}

class _CollapsibleFolderSectionState extends State<CollapsibleFolderSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.folder,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Text(
                  widget.folders.length.toString(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        ),

        // Content
        if (_isExpanded)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.folders.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // All items option
                final totalCount = widget.workflowCounts.values.fold(0, (a, b) => a + b);
                return _FolderTile(
                  name: 'All',
                  icon: Icons.folder_special,
                  isSelected: widget.currentFolder == null,
                  count: totalCount,
                  onTap: () => widget.onFolderSelected(null),
                );
              }

              final folder = widget.folders[index - 1];
              return _FolderTile(
                name: folder.isEmpty ? 'Uncategorized' : folder,
                icon: Icons.folder_outlined,
                isSelected: widget.currentFolder == folder,
                count: widget.workflowCounts[folder] ?? 0,
                onTap: () => widget.onFolderSelected(folder),
              );
            },
          ),
      ],
    );
  }
}
