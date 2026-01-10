import 'dart:convert';

import 'package:flutter/material.dart';

import 'models/eri_workflow_models.dart';

/// Individual workflow tile/card with thumbnail preview, name, description, and context menu
class WorkflowTile extends StatefulWidget {
  /// The workflow to display
  final EriWorkflow workflow;

  /// Whether this tile is currently selected
  final bool isSelected;

  /// Callback when the tile is tapped
  final VoidCallback? onTap;

  /// Callback when the tile is double-tapped
  final VoidCallback? onDoubleTap;

  /// Callback when edit is requested
  final VoidCallback? onEdit;

  /// Callback when duplicate is requested
  final VoidCallback? onDuplicate;

  /// Callback when export is requested
  final VoidCallback? onExport;

  /// Callback when delete is requested
  final VoidCallback? onDelete;

  const WorkflowTile({
    super.key,
    required this.workflow,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onEdit,
    this.onDuplicate,
    this.onExport,
    this.onDelete,
  });

  @override
  State<WorkflowTile> createState() => _WorkflowTileState();
}

class _WorkflowTileState extends State<WorkflowTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.primaryContainer.withOpacity(0.5)
                : _isHovered
                    ? colorScheme.surfaceContainerHighest.withOpacity(0.7)
                    : colorScheme.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? colorScheme.primary
                  : _isHovered
                      ? colorScheme.outline.withOpacity(0.5)
                      : colorScheme.outlineVariant.withOpacity(0.3),
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: widget.isSelected || _isHovered
                ? [
                    BoxShadow(
                      color: widget.isSelected
                          ? colorScheme.primary.withOpacity(0.15)
                          : colorScheme.shadow.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thumbnail preview
                _WorkflowThumbnail(
                  imageData: widget.workflow.image,
                  name: widget.workflow.name,
                  isSelected: widget.isSelected,
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Name with quick access badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.workflow.name,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: widget.isSelected
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurface,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.workflow.enableInSimple)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Tooltip(
                                  message: 'Available in Quick Generate',
                                  child: Icon(
                                    Icons.flash_on,
                                    size: 14,
                                    color: colorScheme.tertiary,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Description
                        if (widget.workflow.description != null && widget.workflow.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.workflow.description!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: widget.isSelected
                                      ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                                      : colorScheme.onSurfaceVariant,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        // Folder indicator
                        if (widget.workflow.folder != null && widget.workflow.folder!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.folder_outlined,
                                size: 12,
                                color: widget.isSelected
                                    ? colorScheme.onPrimaryContainer.withOpacity(0.6)
                                    : colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.workflow.folder!,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: widget.isSelected
                                          ? colorScheme.onPrimaryContainer.withOpacity(0.6)
                                          : colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Actions menu (visible on hover or selection)
                if (_isHovered || widget.isSelected)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: widget.isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Actions',
                      onSelected: _handleMenuAction,
                      itemBuilder: (context) => _buildMenuItems(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return [
      PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit, size: 18, color: colorScheme.onSurface),
            const SizedBox(width: 12),
            const Text('Edit'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'duplicate',
        child: Row(
          children: [
            Icon(Icons.copy, size: 18, color: colorScheme.onSurface),
            const SizedBox(width: 12),
            const Text('Duplicate'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'export',
        child: Row(
          children: [
            Icon(Icons.file_download, size: 18, color: colorScheme.onSurface),
            const SizedBox(width: 12),
            const Text('Export'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
            const SizedBox(width: 12),
            Text('Delete', style: TextStyle(color: colorScheme.error)),
          ],
        ),
      ),
    ];
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        widget.onEdit?.call();
        break;
      case 'duplicate':
        widget.onDuplicate?.call();
        break;
      case 'export':
        widget.onExport?.call();
        break;
      case 'delete':
        widget.onDelete?.call();
        break;
    }
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final colorScheme = Theme.of(context).colorScheme;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: _buildMenuItems(context),
    ).then((value) {
      if (value != null) {
        _handleMenuAction(value);
      }
    });
  }
}

/// Thumbnail preview widget for workflows
class _WorkflowThumbnail extends StatelessWidget {
  final String? imageData;
  final String name;
  final bool isSelected;

  const _WorkflowThumbnail({
    this.imageData,
    required this.name,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(7),
        bottomLeft: Radius.circular(7),
      ),
      child: SizedBox(
        width: 80,
        child: _buildContent(colorScheme),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    // Try to parse image data
    if (imageData != null && imageData!.isNotEmpty) {
      // Check if it's a base64 image
      if (imageData!.startsWith('data:image')) {
        try {
          final parts = imageData!.split(',');
          if (parts.length == 2) {
            final bytes = base64Decode(parts[1]);
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(colorScheme),
            );
          }
        } catch (_) {
          // Fall through to placeholder
        }
      }

      // Check if it's a URL
      if (imageData!.startsWith('http')) {
        return Image.network(
          imageData!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(colorScheme),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingPlaceholder(colorScheme);
          },
        );
      }
    }

    return _buildPlaceholder(colorScheme);
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: isSelected
          ? colorScheme.primary.withOpacity(0.15)
          : colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_tree,
              size: 28,
              color: isSelected
                  ? colorScheme.primary.withOpacity(0.6)
                  : colorScheme.onSurfaceVariant.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}

/// Tag chip widget
class _TagChip extends StatelessWidget {
  final String tag;
  final bool isSelected;

  const _TagChip({
    required this.tag,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.onPrimaryContainer.withOpacity(0.15)
            : colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 10,
          color: isSelected
              ? colorScheme.onPrimaryContainer.withOpacity(0.8)
              : colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Compact workflow tile for grid view
class WorkflowGridTile extends StatefulWidget {
  final EriWorkflow workflow;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;

  const WorkflowGridTile({
    super.key,
    required this.workflow,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onEdit,
    this.onDuplicate,
    this.onExport,
    this.onDelete,
  });

  @override
  State<WorkflowGridTile> createState() => _WorkflowGridTileState();
}

class _WorkflowGridTileState extends State<WorkflowGridTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.primaryContainer.withOpacity(0.5)
                : _isHovered
                    ? colorScheme.surfaceContainerHighest.withOpacity(0.7)
                    : colorScheme.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? colorScheme.primary
                  : _isHovered
                      ? colorScheme.outline.withOpacity(0.5)
                      : colorScheme.outlineVariant.withOpacity(0.3),
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: _isHovered
                ? [BoxShadow(color: colorScheme.primary.withOpacity(0.1), blurRadius: 8)]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview area
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _WorkflowThumbnail(
                        imageData: widget.workflow.image,
                        name: widget.workflow.name,
                        isSelected: widget.isSelected,
                      ),

                      // Hover overlay with actions
                      if (_isHovered)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _HoverAction(
                                  icon: Icons.play_arrow,
                                  label: 'Use',
                                  onTap: widget.onTap ?? () {},
                                  color: colorScheme.primary,
                                ),
                                if (widget.onEdit != null) ...[
                                  const SizedBox(width: 8),
                                  _HoverAction(
                                    icon: Icons.edit,
                                    label: 'Edit',
                                    onTap: widget.onEdit!,
                                    color: colorScheme.secondary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                      // Quick generate badge
                      if (widget.workflow.enableInSimple)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flash_on, size: 10, color: colorScheme.onTertiary),
                                const SizedBox(width: 2),
                                Text(
                                  'QUICK',
                                  style: TextStyle(
                                    color: colorScheme.onTertiary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Info area
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        widget.workflow.name,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Description
                      if (widget.workflow.description != null && widget.workflow.description!.isNotEmpty)
                        Expanded(
                          child: Text(
                            widget.workflow.description!,
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final colorScheme = Theme.of(context).colorScheme;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 12),
              const Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 12),
              const Text('Duplicate'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.file_download, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 12),
              const Text('Export'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
              const SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: colorScheme.error)),
            ],
          ),
        ),
      ],
    ).then((value) {
      switch (value) {
        case 'edit':
          widget.onEdit?.call();
          break;
        case 'duplicate':
          widget.onDuplicate?.call();
          break;
        case 'export':
          widget.onExport?.call();
          break;
        case 'delete':
          widget.onDelete?.call();
          break;
      }
    });
  }
}

/// Hover action button for grid tiles
class _HoverAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _HoverAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
