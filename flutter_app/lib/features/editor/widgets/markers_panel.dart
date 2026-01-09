import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/marker_models.dart';
import '../providers/markers_provider.dart';

/// Panel for managing timeline markers.
///
/// Shows a list view of all markers with add/edit/delete functionality.
/// Supports filtering by type and color.
class MarkersPanel extends ConsumerStatefulWidget {
  /// Called when the panel should close
  final VoidCallback? onClose;

  /// Called when a marker is clicked (for navigation)
  final ValueChanged<Marker>? onMarkerTap;

  const MarkersPanel({
    super.key,
    this.onClose,
    this.onMarkerTap,
  });

  @override
  ConsumerState<MarkersPanel> createState() => _MarkersPanelState();
}

class _MarkersPanelState extends ConsumerState<MarkersPanel> {
  MarkerType? _filterType;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final markersState = ref.watch(markersProvider);
    final markers = markersState.collection.sortedMarkers;

    // Apply filters
    final filteredMarkers = markers.where((m) {
      if (_filterType != null && m.type != _filterType) return false;
      if (_searchQuery.isNotEmpty &&
          !m.label.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(context),

          // Search and filter
          _buildSearchAndFilter(context),

          // Markers list
          Expanded(
            child: filteredMarkers.isEmpty
                ? _buildEmptyState(context)
                : _buildMarkersList(context, filteredMarkers),
          ),

          // Add marker button
          _buildAddButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.flag, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Markers',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Search field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search markers...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 8),

          // Type filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _filterType == null,
                  onTap: () {
                    setState(() {
                      _filterType = null;
                    });
                  },
                ),
                ...MarkerType.values.map((type) => _FilterChip(
                      label: type.displayName,
                      isSelected: _filterType == type,
                      color: Marker.create(
                        timestamp: const EditorTime.zero(),
                        label: '',
                        type: type,
                      ).color,
                      onTap: () {
                        setState(() {
                          _filterType = _filterType == type ? null : type;
                        });
                      },
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flag_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No markers',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Press M to add a marker at playhead',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkersList(BuildContext context, List<Marker> markers) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: markers.length,
      itemBuilder: (context, index) {
        final marker = markers[index];
        return _MarkerListItem(
          marker: marker,
          onTap: () => widget.onMarkerTap?.call(marker),
          onEdit: () => _showEditDialog(context, marker),
          onDelete: () {
            ref.read(markersProvider.notifier).removeMarker(marker.id);
          },
        );
      },
    );
  }

  Widget _buildAddButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: FilledButton.tonalIcon(
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Marker'),
        onPressed: () => _showAddDialog(context),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _MarkerEditDialog(
        onSave: (label, type, color, description) {
          ref.read(markersProvider.notifier).addMarkerAtPlayhead(
                label: label,
                type: type,
                color: color,
                description: description,
              );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, Marker marker) {
    showDialog(
      context: context,
      builder: (context) => _MarkerEditDialog(
        marker: marker,
        onSave: (label, type, color, description) {
          ref.read(markersProvider.notifier).updateMarker(
                marker.copyWith(
                  label: label,
                  type: type,
                  color: color,
                  description: description,
                ),
              );
        },
      ),
    );
  }
}

/// Filter chip for marker types
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback? onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(fontSize: 11),
        ),
        selected: isSelected,
        onSelected: (_) => onTap?.call(),
        avatar: color != null
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// List item for a single marker
class _MarkerListItem extends StatelessWidget {
  final Marker marker;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MarkerListItem({
    required this.marker,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Color indicator
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: marker.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Type icon
              Icon(
                _getIconForType(marker.type),
                size: 20,
                color: marker.color,
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marker.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${marker.timestamp} \u2022 ${marker.type.displayName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              IconButton(
                icon: Icon(Icons.delete, size: 18, color: colorScheme.error),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(MarkerType type) {
    switch (type) {
      case MarkerType.comment:
        return Icons.comment;
      case MarkerType.chapter:
        return Icons.bookmark;
      case MarkerType.todo:
        return Icons.check_box;
      case MarkerType.sync:
        return Icons.sync;
      case MarkerType.edit:
        return Icons.edit;
      case MarkerType.cue:
        return Icons.flag;
    }
  }
}

/// Dialog for adding/editing a marker
class _MarkerEditDialog extends StatefulWidget {
  final Marker? marker;
  final void Function(String label, MarkerType type, Color color, String? description)?
      onSave;

  const _MarkerEditDialog({
    this.marker,
    this.onSave,
  });

  @override
  State<_MarkerEditDialog> createState() => _MarkerEditDialogState();
}

class _MarkerEditDialogState extends State<_MarkerEditDialog> {
  late TextEditingController _labelController;
  late TextEditingController _descriptionController;
  late MarkerType _type;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.marker?.label ?? '');
    _descriptionController =
        TextEditingController(text: widget.marker?.description ?? '');
    _type = widget.marker?.type ?? MarkerType.comment;
    _color = widget.marker?.color ??
        Marker.create(
          timestamp: const EditorTime.zero(),
          label: '',
          type: _type,
        ).color;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.marker == null ? 'Add Marker' : 'Edit Marker'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Enter marker label',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Enter description',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Type selector
            Text(
              'Type',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MarkerType.values.map((type) {
                return ChoiceChip(
                  label: Text(type.displayName),
                  selected: _type == type,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _type = type;
                        // Update color to match type default
                        _color = Marker.create(
                          timestamp: const EditorTime.zero(),
                          label: '',
                          type: type,
                        ).color;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Color selector
            Text(
              'Color',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.orange,
                Colors.red,
                Colors.purple,
                Colors.pink,
                Colors.cyan,
              ].map((color) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _color = color;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _color == color
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _labelController.text.isNotEmpty
              ? () {
                  widget.onSave?.call(
                    _labelController.text,
                    _type,
                    _color,
                    _descriptionController.text.isNotEmpty
                        ? _descriptionController.text
                        : null,
                  );
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
