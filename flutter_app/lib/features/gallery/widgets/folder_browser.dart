import 'package:flutter/material.dart';

/// Folder browser widget
class FolderBrowser extends StatelessWidget {
  final List<String> folders;
  final String currentFolder;
  final Function(String) onFolderSelected;

  const FolderBrowser({
    super.key,
    required this.folders,
    required this.currentFolder,
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
          // Header
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
          // Folder list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                final isSelected = folder == currentFolder;

                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.folder,
                    size: 20,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    _getFolderName(folder),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: isSelected,
                  selectedColor: colorScheme.primary,
                  selectedTileColor: colorScheme.primaryContainer.withOpacity(0.3),
                  onTap: () => onFolderSelected(folder),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getFolderName(String path) {
    final parts = path.split('/');
    return parts.last.isEmpty ? 'Root' : parts.last;
  }
}

/// Date-based folder structure widget
class DateFolderTree extends StatelessWidget {
  final Map<String, List<String>> foldersByDate;
  final String currentFolder;
  final Function(String) onFolderSelected;

  const DateFolderTree({
    super.key,
    required this.foldersByDate,
    required this.currentFolder,
    required this.onFolderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sortedDates = foldersByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

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
                Icon(Icons.calendar_today, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'By Date',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Date tree
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final date = sortedDates[index];
                final folders = foldersByDate[date]!;

                return ExpansionTile(
                  leading: Icon(
                    Icons.calendar_month,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    _formatDateHeader(date),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  children: folders.map((folder) {
                    final isSelected = folder == currentFolder;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 56, right: 16),
                      leading: Icon(
                        Icons.folder,
                        size: 18,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        _getFolderName(folder),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      selected: isSelected,
                      selectedColor: colorScheme.primary,
                      selectedTileColor:
                          colorScheme.primaryContainer.withOpacity(0.3),
                      onTap: () => onFolderSelected(folder),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateHeader(String date) {
    // Assuming date is in YYYY-MM format
    try {
      final parts = date.split('-');
      if (parts.length >= 2) {
        final year = parts[0];
        final month = int.parse(parts[1]);
        const months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        return '${months[month - 1]} $year';
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return date;
  }

  String _getFolderName(String path) {
    final parts = path.split('/');
    return parts.last.isEmpty ? 'Root' : parts.last;
  }
}
