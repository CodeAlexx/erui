import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../providers/media_browser_provider.dart';

/// Data class for dragging media items to the timeline.
/// Compatible with the editor's clip creation system.
class MediaDragData {
  /// The source media item being dragged
  final ImportedMedia media;

  /// Clip type to create (video or image)
  final ClipType clipType;

  const MediaDragData({
    required this.media,
    required this.clipType,
  });
}

/// A panel for browsing and importing media files into the editor project.
///
/// Features:
/// - File picker button to import videos/images
/// - Grid view of imported media with thumbnails
/// - Draggable items for timeline integration
/// - Right-click context menu for file operations
class MediaBrowserPanel extends ConsumerStatefulWidget {
  /// Callback when a media item is double-clicked
  final void Function(ImportedMedia media)? onMediaDoubleClick;

  const MediaBrowserPanel({
    super.key,
    this.onMediaDoubleClick,
  });

  @override
  ConsumerState<MediaBrowserPanel> createState() => _MediaBrowserPanelState();
}

class _MediaBrowserPanelState extends ConsumerState<MediaBrowserPanel> {
  /// Grid item size
  static const double _itemWidth = 140.0;
  static const double _itemHeight = 120.0;

  /// Import media files using file picker
  Future<void> _importMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4', 'webm', 'mov', 'mkv', 'avi', 'gif', // Video
          'png', 'jpg', 'jpeg', 'webp', 'bmp', 'tiff', // Image
        ],
        allowMultiple: true,
        withData: kIsWeb, // Load bytes on web platform
      );

      if (result != null && result.files.isNotEmpty) {
        if (kIsWeb) {
          // On web, use bytes
          await ref.read(mediaBrowserProvider.notifier).importFromBytes(
            result.files.map((f) => (name: f.name, bytes: f.bytes!)).toList(),
          );
        } else {
          // On desktop/mobile, use paths
          final paths = result.paths.whereType<String>().toList();
          await ref.read(mediaBrowserProvider.notifier).importFiles(paths);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import media: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Show context menu for a media item
  void _showContextMenu(BuildContext context, ImportedMedia media, Offset position) {
    final colorScheme = Theme.of(context).colorScheme;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
              const SizedBox(width: 8),
              Text('Remove from project', style: TextStyle(color: colorScheme.onSurface)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'show_in_folder',
          child: Row(
            children: [
              Icon(Icons.folder_open, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('Show in folder', style: TextStyle(color: colorScheme.onSurface)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('Refresh', style: TextStyle(color: colorScheme.onSurface)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'remove':
          ref.read(mediaBrowserProvider.notifier).removeMedia(media.id);
          break;
        case 'show_in_folder':
          _showInFolder(media.filePath);
          break;
        case 'refresh':
          ref.read(mediaBrowserProvider.notifier).refreshMedia(media.id);
          break;
      }
    });
  }

  /// Open file manager at the media file location (not supported on web)
  Future<void> _showInFolder(String filePath) async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Show in folder not supported on web')),
        );
      }
      return;
    }
    // Desktop implementation would go here
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Show in folder: desktop only feature')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaList = ref.watch(importedMediaProvider);
    final isImporting = ref.watch(isImportingProvider);
    final selectedId = ref.watch(mediaBrowserProvider).selectedId;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with import button
          _buildHeader(context, colorScheme, isImporting),

          // Media grid
          Expanded(
            child: mediaList.isEmpty
                ? _buildEmptyState(context, colorScheme)
                : _buildMediaGrid(context, colorScheme, mediaList, selectedId),
          ),
        ],
      ),
    );
  }

  /// Build the header with title and import button
  Widget _buildHeader(BuildContext context, ColorScheme colorScheme, bool isImporting) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          Icon(Icons.perm_media, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Media Browser',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          // Import button
          SizedBox(
            height: 28,
            child: ElevatedButton.icon(
              onPressed: isImporting ? null : _importMedia,
              icon: isImporting
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.add, size: 16),
              label: Text(isImporting ? 'Importing...' : 'Import'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build empty state when no media is imported
  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No media imported',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Click Import to add videos and images',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _importMedia,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Import Media'),
          ),
        ],
      ),
    );
  }

  /// Build the media grid view
  Widget _buildMediaGrid(
    BuildContext context,
    ColorScheme colorScheme,
    List<ImportedMedia> mediaList,
    String? selectedId,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _itemWidth,
        mainAxisExtent: _itemHeight,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: mediaList.length,
      itemBuilder: (context, index) {
        final media = mediaList[index];
        final isSelected = media.id == selectedId;

        return _MediaGridItem(
          media: media,
          isSelected: isSelected,
          onTap: () {
            ref.read(mediaBrowserProvider.notifier).selectMedia(media.id);
          },
          onDoubleTap: () {
            widget.onMediaDoubleClick?.call(media);
          },
          onContextMenu: (position) {
            _showContextMenu(context, media, position);
          },
        );
      },
    );
  }
}

/// Individual media item in the grid
class _MediaGridItem extends StatefulWidget {
  final ImportedMedia media;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final void Function(Offset position) onContextMenu;

  const _MediaGridItem({
    required this.media,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onContextMenu,
  });

  @override
  State<_MediaGridItem> createState() => _MediaGridItemState();
}

class _MediaGridItemState extends State<_MediaGridItem> {
  bool _isHovered = false;

  /// Get clip type for drag data
  ClipType get _clipType {
    return widget.media.type == MediaFileType.video
        ? ClipType.video
        : ClipType.image;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Draggable<MediaDragData>(
      data: MediaDragData(
        media: widget.media,
        clipType: _clipType,
      ),
      onDragStarted: () {
        print('DEBUG: Drag started for ${widget.media.fileName}');
      },
      onDragEnd: (details) {
        print('DEBUG: Drag ended, wasAccepted: ${details.wasAccepted}');
      },
      onDraggableCanceled: (velocity, offset) {
        print('DEBUG: Drag cancelled at $offset');
      },
      feedback: _buildDragFeedback(context, colorScheme),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildItemContent(context, colorScheme),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          onSecondaryTapUp: (details) {
            widget.onContextMenu(details.globalPosition);
          },
          child: _buildItemContent(context, colorScheme),
        ),
      ),
    );
  }

  /// Build the main item content
  Widget _buildItemContent(BuildContext context, ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isSelected
              ? colorScheme.primary
              : (_isHovered
                  ? colorScheme.outline.withOpacity(0.5)
                  : colorScheme.outlineVariant.withOpacity(0.3)),
          width: widget.isSelected ? 2 : 1,
        ),
        boxShadow: widget.isSelected
            ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail
            Expanded(
              child: _buildThumbnail(colorScheme),
            ),
            // File info
            _buildFileInfo(colorScheme),
          ],
        ),
      ),
    );
  }

  /// Build the thumbnail preview
  Widget _buildThumbnail(ColorScheme colorScheme) {
    if (widget.media.isLoading) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
        ),
      );
    }

    if (widget.media.error != null) {
      return Container(
        color: colorScheme.errorContainer,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 24,
                color: colorScheme.error,
              ),
              const SizedBox(height: 4),
              Text(
                'Error',
                style: TextStyle(
                  color: colorScheme.error,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.media.thumbnail != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            widget.media.thumbnail!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(colorScheme),
          ),
          // Duration overlay for videos
          if (widget.media.type == MediaFileType.video &&
              widget.media.displayDuration.isNotEmpty)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  widget.media.displayDuration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // Media type icon
          Positioned(
            left: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                widget.media.type == MediaFileType.video
                    ? Icons.videocam
                    : Icons.image,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return _buildPlaceholder(colorScheme);
  }

  /// Build placeholder for missing thumbnails
  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          widget.media.type == MediaFileType.video
              ? Icons.movie_outlined
              : Icons.image_outlined,
          size: 32,
          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }

  /// Build file info section
  Widget _buildFileInfo(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(6),
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File name
          Text(
            widget.media.fileName,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // Resolution
          if (widget.media.displayResolution.isNotEmpty)
            Text(
              widget.media.displayResolution,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }

  /// Build drag feedback widget
  Widget _buildDragFeedback(BuildContext context, ColorScheme colorScheme) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 120,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.media.thumbnail != null)
                Image.memory(
                  widget.media.thumbnail!,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    widget.media.type == MediaFileType.video
                        ? Icons.videocam
                        : Icons.image,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              // Overlay with file name
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  color: Colors.black.withOpacity(0.7),
                  child: Text(
                    widget.media.fileName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
