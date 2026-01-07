import 'package:flutter/material.dart';
import '../comfy_workflow_screen.dart';

/// Workflow card widget for grid display
class WorkflowCard extends StatefulWidget {
  final WorkflowInfo workflow;
  final VoidCallback onUse;
  final VoidCallback? onDelete;

  const WorkflowCard({
    super.key,
    required this.workflow,
    required this.onUse,
    this.onDelete,
  });

  @override
  State<WorkflowCard> createState() => _WorkflowCardState();
}

class _WorkflowCardState extends State<WorkflowCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final workflow = widget.workflow;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onUse,
        onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isHovered
                ? colorScheme.surfaceContainerHighest.withOpacity(0.6)
                : colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? colorScheme.primary.withOpacity(0.5)
                  : colorScheme.outlineVariant.withOpacity(0.3),
              width: _isHovered ? 2 : 1,
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
                      // Preview image or placeholder
                      _buildPreview(colorScheme),

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
                                  onTap: widget.onUse,
                                  color: colorScheme.primary,
                                ),
                                if (widget.onDelete != null) ...[
                                  const SizedBox(width: 16),
                                  _HoverAction(
                                    icon: Icons.delete_outline,
                                    label: 'Delete',
                                    onTap: widget.onDelete!,
                                    color: Colors.red,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                      // Example badge
                      if (workflow.isExample)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'EXAMPLE',
                              style: TextStyle(
                                color: colorScheme.onTertiary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
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
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        workflow.name,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Description
                      if (workflow.description.isNotEmpty)
                        Expanded(
                          child: Text(
                            workflow.description,
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      // Tags
                      if (workflow.tags.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: workflow.tags.take(3).map((tag) => _TagChip(tag: tag)).toList(),
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

  Widget _buildPreview(ColorScheme colorScheme) {
    // Use network image from server's preview endpoint
    return Image.network(
      'http://localhost:7803/api/workflows/preview/${widget.workflow.filename}',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder(colorScheme);
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildPlaceholder(colorScheme);
      },
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_tree,
              size: 40,
              color: colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 8),
            Text(
              widget.workflow.name,
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.4),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
          value: 'use',
          child: Row(
            children: [
              Icon(Icons.play_arrow, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Use Workflow'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 8),
              const Text('Duplicate'),
            ],
          ),
        ),
        if (widget.onDelete != null)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
    ).then((value) {
      switch (value) {
        case 'use':
          widget.onUse();
          break;
        case 'duplicate':
          // TODO: Implement duplicate
          break;
        case 'delete':
          widget.onDelete?.call();
          break;
      }
    });
  }
}

/// Hover action button
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tag chip widget
class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: colorScheme.onSecondaryContainer,
          fontSize: 10,
        ),
      ),
    );
  }
}
