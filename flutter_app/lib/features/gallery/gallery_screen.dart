import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'widgets/gallery_grid.dart';
import 'widgets/image_viewer_dialog.dart';
import 'widgets/folder_browser.dart';

/// Gallery screen for viewing generated images
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(galleryProvider.notifier).loadImages(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final galleryState = ref.watch(galleryProvider);
    final viewMode = ref.watch(galleryViewModeProvider);
    final sortOption = ref.watch(gallerySortProvider);

    return Column(
      children: [
        // Toolbar
        _GalleryToolbar(
          viewMode: viewMode,
          sortOption: sortOption,
          searchController: _searchController,
          onSearch: (query) {
            setState(() => _searchQuery = query);
            if (query.isNotEmpty) {
              ref.read(galleryProvider.notifier).search(query);
            } else {
              ref.read(galleryProvider.notifier).refresh();
            }
          },
          onViewModeChanged: (mode) {
            ref.read(galleryViewModeProvider.notifier).state = mode;
          },
          onSortChanged: (sort) {
            ref.read(gallerySortProvider.notifier).state = sort;
          },
          onRefresh: () {
            ref.read(galleryProvider.notifier).refresh();
          },
        ),
        const Divider(height: 1),
        // Breadcrumb / folder path
        if (galleryState.currentFolder.isNotEmpty)
          _BreadcrumbBar(
            path: galleryState.currentFolder,
            onNavigate: (folder) {
              ref.read(galleryProvider.notifier).navigateToFolder(folder);
            },
          ),
        // Gallery content
        Expanded(
          child: Row(
            children: [
              // Folder browser (optional)
              if (galleryState.folders.isNotEmpty) ...[
                SizedBox(
                  width: 200,
                  child: FolderBrowser(
                    folders: galleryState.folders,
                    currentFolder: galleryState.currentFolder,
                    onFolderSelected: (folder) {
                      ref.read(galleryProvider.notifier).navigateToFolder(folder);
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
              ],
              // Main content
              Expanded(
                child: _GalleryContent(
                  state: galleryState,
                  viewMode: viewMode,
                  sortOption: sortOption,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GalleryToolbar extends StatelessWidget {
  final GalleryViewMode viewMode;
  final GallerySortOption sortOption;
  final TextEditingController searchController;
  final Function(String) onSearch;
  final Function(GalleryViewMode) onViewModeChanged;
  final Function(GallerySortOption) onSortChanged;
  final VoidCallback onRefresh;

  const _GalleryToolbar({
    required this.viewMode,
    required this.sortOption,
    required this.searchController,
    required this.onSearch,
    required this.onViewModeChanged,
    required this.onSortChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.surface,
      child: Row(
        children: [
          // Title
          Icon(Icons.photo_library, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Gallery',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(width: 24),
          // Search
          Expanded(
            child: SizedBox(
              width: 300,
              child: TextField(
                controller: searchController,
                onChanged: onSearch,
                decoration: InputDecoration(
                  hintText: 'Search by prompt...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            onSearch('');
                          },
                        )
                      : null,
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Sort dropdown
          PopupMenuButton<GallerySortOption>(
            initialValue: sortOption,
            onSelected: onSortChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: GallerySortOption.dateNewest,
                child: Text('Date (Newest)'),
              ),
              const PopupMenuItem(
                value: GallerySortOption.dateOldest,
                child: Text('Date (Oldest)'),
              ),
              const PopupMenuItem(
                value: GallerySortOption.nameAsc,
                child: Text('Name (A-Z)'),
              ),
              const PopupMenuItem(
                value: GallerySortOption.nameDesc,
                child: Text('Name (Z-A)'),
              ),
              const PopupMenuItem(
                value: GallerySortOption.sizeSmallest,
                child: Text('Size (Smallest)'),
              ),
              const PopupMenuItem(
                value: GallerySortOption.sizeLargest,
                child: Text('Size (Largest)'),
              ),
            ],
            child: Chip(
              avatar: const Icon(Icons.sort, size: 18),
              label: Text(_getSortLabel(sortOption)),
            ),
          ),
          const SizedBox(width: 8),
          // View mode toggle
          SegmentedButton<GalleryViewMode>(
            segments: const [
              ButtonSegment(value: GalleryViewMode.grid, icon: Icon(Icons.grid_view)),
              ButtonSegment(value: GalleryViewMode.masonry, icon: Icon(Icons.dashboard)),
              ButtonSegment(value: GalleryViewMode.list, icon: Icon(Icons.list)),
            ],
            selected: {viewMode},
            onSelectionChanged: (selection) {
              onViewModeChanged(selection.first);
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  String _getSortLabel(GallerySortOption sort) {
    switch (sort) {
      case GallerySortOption.dateNewest:
        return 'Newest';
      case GallerySortOption.dateOldest:
        return 'Oldest';
      case GallerySortOption.nameAsc:
        return 'Name A-Z';
      case GallerySortOption.nameDesc:
        return 'Name Z-A';
      case GallerySortOption.sizeSmallest:
        return 'Smallest';
      case GallerySortOption.sizeLargest:
        return 'Largest';
    }
  }
}

class _BreadcrumbBar extends StatelessWidget {
  final String path;
  final Function(String) onNavigate;

  const _BreadcrumbBar({
    required this.path,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Row(
        children: [
          InkWell(
            onTap: () => onNavigate(''),
            child: Row(
              children: [
                Icon(Icons.home, size: 16, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text('Output', style: TextStyle(color: colorScheme.primary)),
              ],
            ),
          ),
          ...parts.asMap().entries.map((entry) {
            final index = entry.key;
            final part = entry.value;
            final fullPath = parts.sublist(0, index + 1).join('/');

            return Row(
              children: [
                Icon(Icons.chevron_right, size: 16, color: colorScheme.outline),
                InkWell(
                  onTap: () => onNavigate(fullPath),
                  child: Text(
                    part,
                    style: TextStyle(
                      color: index == parts.length - 1
                          ? colorScheme.onSurface
                          : colorScheme.primary,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _GalleryContent extends ConsumerWidget {
  final GalleryState state;
  final GalleryViewMode viewMode;
  final GallerySortOption sortOption;

  const _GalleryContent({
    required this.state,
    required this.viewMode,
    required this.sortOption,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.images.isEmpty) {
      return const LoadingIndicator(message: 'Loading images...');
    }

    if (state.error != null) {
      return ErrorDisplay(
        message: state.error!,
        onRetry: () => ref.read(galleryProvider.notifier).refresh(),
      );
    }

    if (state.images.isEmpty) {
      return const EmptyState(
        title: 'No images yet',
        message: 'Generated images will appear here',
        icon: Icons.photo_library_outlined,
      );
    }

    // Sort images
    final sortedImages = _sortImages(state.images, sortOption);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200) {
          ref.read(galleryProvider.notifier).loadMore();
        }
        return false;
      },
      child: Column(
        children: [
          Expanded(
            child: GalleryGrid(
              images: sortedImages,
              viewMode: viewMode,
              onImageTap: (image) {
                showDialog(
                  context: context,
                  builder: (context) => FullImageViewerDialog(image: image),
                );
              },
              onImageDelete: (image) {
                _showDeleteDialog(context, ref, image);
              },
            ),
          ),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          // Image count
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${state.images.length} of ${state.totalCount} images',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  List<GalleryImage> _sortImages(
    List<GalleryImage> images,
    GallerySortOption sort,
  ) {
    final sorted = List<GalleryImage>.from(images);
    switch (sort) {
      case GallerySortOption.dateNewest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case GallerySortOption.dateOldest:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case GallerySortOption.nameAsc:
        sorted.sort((a, b) => a.filename.compareTo(b.filename));
        break;
      case GallerySortOption.nameDesc:
        sorted.sort((a, b) => b.filename.compareTo(a.filename));
        break;
      case GallerySortOption.sizeSmallest:
        sorted.sort((a, b) => a.size.compareTo(b.size));
        break;
      case GallerySortOption.sizeLargest:
        sorted.sort((a, b) => b.size.compareTo(a.size));
        break;
    }
    return sorted;
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    GalleryImage image,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: Text('Are you sure you want to delete "${image.filename}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final success =
                  await ref.read(galleryProvider.notifier).deleteImage(image.id);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Image deleted' : 'Failed to delete image',
                    ),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
