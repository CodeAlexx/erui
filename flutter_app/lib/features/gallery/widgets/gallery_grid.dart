import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/gallery_provider.dart';

/// Gallery grid widget
class GalleryGrid extends StatelessWidget {
  final List<GalleryImage> images;
  final GalleryViewMode viewMode;
  final Function(GalleryImage) onImageTap;
  final Function(GalleryImage) onImageDelete;

  const GalleryGrid({
    super.key,
    required this.images,
    required this.viewMode,
    required this.onImageTap,
    required this.onImageDelete,
  });

  @override
  Widget build(BuildContext context) {
    switch (viewMode) {
      case GalleryViewMode.grid:
        return _buildGrid(context);
      case GalleryViewMode.masonry:
        return _buildMasonry(context);
      case GalleryViewMode.list:
        return _buildList(context);
    }
  }

  Widget _buildGrid(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return GalleryImageCard(
          image: images[index],
          onTap: () => onImageTap(images[index]),
          onDelete: () => onImageDelete(images[index]),
        );
      },
    );
  }

  Widget _buildMasonry(BuildContext context) {
    // Simple masonry-like layout using multiple columns
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = (constraints.maxWidth / 250).floor().clamp(2, 5);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(columnCount, (colIndex) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: colIndex > 0 ? 6 : 0,
                    right: colIndex < columnCount - 1 ? 6 : 0,
                  ),
                  child: Column(
                    children: images
                        .asMap()
                        .entries
                        .where((e) => e.key % columnCount == colIndex)
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GalleryImageCard(
                                image: e.value,
                                aspectRatio: null, // Natural aspect ratio
                                onTap: () => onImageTap(e.value),
                                onDelete: () => onImageDelete(e.value),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return GalleryListTile(
          image: images[index],
          onTap: () => onImageTap(images[index]),
          onDelete: () => onImageDelete(images[index]),
        );
      },
    );
  }
}

/// Gallery image card
class GalleryImageCard extends StatefulWidget {
  final GalleryImage image;
  final double? aspectRatio;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const GalleryImageCard({
    super.key,
    required this.image,
    this.aspectRatio = 1,
    this.onTap,
    this.onDelete,
  });

  @override
  State<GalleryImageCard> createState() => _GalleryImageCardState();
}

class _GalleryImageCardState extends State<GalleryImageCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget imageWidget = CachedNetworkImage(
      imageUrl: widget.image.thumbnailUrl ?? widget.image.url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => Container(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.broken_image, color: colorScheme.error),
      ),
    );

    if (widget.aspectRatio != null) {
      imageWidget = AspectRatio(
        aspectRatio: widget.aspectRatio!,
        child: imageWidget,
      );
    } else {
      // For masonry layout, use natural aspect ratio
      imageWidget = AspectRatio(
        aspectRatio: widget.image.width > 0 && widget.image.height > 0
            ? widget.image.width / widget.image.height
            : 1,
        child: imageWidget,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              imageWidget,
              // Hover overlay
              if (_isHovered)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),
              // Info overlay (always visible on hover)
              if (_isHovered)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.image.prompt != null &&
                          widget.image.prompt!.isNotEmpty)
                        Text(
                          widget.image.prompt!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            widget.image.dimensions,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            widget.image.formattedSize,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              // Action buttons
              if (_isHovered)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionButton(
                        icon: Icons.download,
                        onPressed: () {
                          // TODO: Download
                        },
                        tooltip: 'Download',
                      ),
                      const SizedBox(width: 4),
                      if (widget.onDelete != null)
                        _ActionButton(
                          icon: Icons.delete_outline,
                          onPressed: widget.onDelete,
                          tooltip: 'Delete',
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.5),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

/// Gallery list tile
class GalleryListTile extends StatelessWidget {
  final GalleryImage image;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const GalleryListTile({
    super.key,
    required this.image,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 60,
            height: 60,
            child: CachedNetworkImage(
              imageUrl: image.thumbnailUrl ?? image.url,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  Icon(Icons.broken_image, color: colorScheme.error),
            ),
          ),
        ),
        title: Text(
          image.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image.prompt != null && image.prompt!.isNotEmpty)
              Text(
                image.prompt!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Row(
              children: [
                Text(
                  image.dimensions,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  image.formattedSize,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(image.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'download', child: Text('Download')),
            const PopupMenuItem(value: 'copy', child: Text('Copy path')),
            if (onDelete != null)
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          onSelected: (value) {
            if (value == 'delete' && onDelete != null) {
              onDelete!();
            }
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
