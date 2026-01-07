import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../services/onetrainer_service.dart' as ot;

/// Datasets Screen - Shows training datasets with expandable image preview
/// Connected to OneTrainer API - loads concepts from preset config
class DatasetsScreen extends ConsumerStatefulWidget {
  const DatasetsScreen({super.key});

  @override
  ConsumerState<DatasetsScreen> createState() => _DatasetsScreenState();
}

class _DatasetsScreenState extends ConsumerState<DatasetsScreen> {
  List<Dataset> _datasets = [];
  bool _datasetsLoaded = false;

  String? _selectedDatasetId;
  String _searchQuery = '';
  bool _gridView = true;
  List<DatasetImage> _currentImages = [];
  Set<String> _expandedDatasets = {};  // Track which datasets are expanded

  void _loadDatasetsFromConfig(List<dynamic> concepts) {
    if (concepts.isEmpty) return;

    final datasets = <Dataset>[];
    for (int i = 0; i < concepts.length; i++) {
      final concept = concepts[i] as Map<String, dynamic>?;
      if (concept == null) continue;

      final name = concept['name'] as String? ?? 'Concept ${i + 1}';
      final path = concept['path'] as String? ?? '';
      final conceptType = concept['concept_type'] as String? ?? 'STANDARD';

      datasets.add(Dataset(
        id: i.toString(),
        name: name,
        path: path,
        type: conceptType,
        imageCount: 0,
        isSelected: i == 0,
      ));
    }

    setState(() {
      _datasets = datasets;
      _datasetsLoaded = true;
      if (datasets.isNotEmpty && _selectedDatasetId == null) {
        _selectedDatasetId = datasets.first.id;
      }
    });
  }

  Future<List<DatasetImage>> _loadImagesFromPath(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final images = <DatasetImage>[];
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'];

    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (imageExtensions.contains(ext)) {
            images.add(DatasetImage(
              id: entity.path,
              filename: p.basename(entity.path),
              thumbnailUrl: entity.path,
              caption: '',
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading images: $e');
    }

    return images;
  }

  void _toggleDatasetExpand(Dataset dataset) async {
    setState(() {
      if (_expandedDatasets.contains(dataset.id)) {
        _expandedDatasets.remove(dataset.id);
      } else {
        _expandedDatasets.add(dataset.id);
      }
    });

    // Load images if expanding and not already loaded
    if (_expandedDatasets.contains(dataset.id) && !_datasetImages.containsKey(dataset.id)) {
      final images = await _loadImagesFromPath(dataset.path);
      setState(() {
        _datasetImages[dataset.id] = images;
      });
    }
  }

  Map<String, List<DatasetImage>> _datasetImages = {};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    // Watch the loaded config and get concepts (datasets)
    final currentConfig = ref.watch(ot.currentConfigProvider);
    final concepts = currentConfig.concepts;

    // Load datasets from config if not already loaded
    if (!_datasetsLoaded && concepts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDatasetsFromConfig(concepts);
      });
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(Icons.folder_open, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Datasets',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Subheader with search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Datasets',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 24),
                // Search
                SizedBox(
                  width: 250,
                  child: TextField(
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search images or captions...',
                      hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4)),
                      prefixIcon: Icon(Icons.search, size: 18, color: colorScheme.onSurface.withOpacity(0.4)),
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_currentImages.length} images',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                // View toggle
                IconButton(
                  icon: Icon(_gridView ? Icons.grid_view : Icons.list, size: 20),
                  onPressed: () => setState(() => _gridView = !_gridView),
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Datasets list (left) - WIDENED to 500
                  Container(
                    width: 500,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current dataset header
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.folder, size: 18, color: colorScheme.onSurface.withOpacity(0.6)),
                              const SizedBox(width: 8),
                              Text(
                                'Current Dataset',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'from: #z-imageGiger16GB',
                                style: TextStyle(
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {},
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
                        // Dataset list with expandable items
                        Expanded(
                          child: ListView.builder(
                            itemCount: _datasets.length,
                            itemBuilder: (context, index) {
                              final dataset = _datasets[index];
                              final isSelected = dataset.id == _selectedDatasetId;
                              final isExpanded = _expandedDatasets.contains(dataset.id);
                              return _buildExpandableDatasetItem(dataset, isSelected, isExpanded, colorScheme);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Images grid (right)
                  Expanded(
                    child: _currentImages.isEmpty
                        ? _buildEmptyState(colorScheme)
                        : _gridView
                            ? _buildImageGrid(colorScheme)
                            : _buildImageList(colorScheme),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildExpandableDatasetItem(Dataset dataset, bool isSelected, bool isExpanded, ColorScheme colorScheme) {
    final images = _datasetImages[dataset.id] ?? [];

    return Column(
      children: [
        // Dataset header row - compact
        InkWell(
          onTap: () => setState(() => _selectedDatasetId = dataset.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.primary.withOpacity(0.1) : null,
              border: Border(
                left: BorderSide(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                // Expand/collapse arrow
                InkWell(
                  onTap: () => _toggleDatasetExpand(dataset),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                      size: 18,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                // Status dot
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dataset.isSelected ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                // Info - more compact
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dataset.name,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        dataset.path,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Type badge - smaller
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    dataset.type,
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Open folder - smaller
                IconButton(
                  icon: Icon(Icons.open_in_new, size: 14, color: colorScheme.onSurface.withOpacity(0.4)),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                ),
              ],
            ),
          ),
        ),
        // Expanded image preview section - more compact
        if (isExpanded)
          Container(
            padding: const EdgeInsets.only(left: 32, right: 8, top: 6, bottom: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
            ),
            child: images.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'Loading images...',
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 64,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length > 12 ? 13 : images.length,
                      itemBuilder: (context, index) {
                        if (index == 12 && images.length > 12) {
                          // Show "more" indicator
                          return Container(
                            width: 56,
                            height: 56,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '+${images.length - 12}',
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'more',
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withOpacity(0.5),
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        final image = images[index];
                        return Container(
                          width: 56,
                          height: 56,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.file(
                              File(image.thumbnailUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(Icons.image, color: colorScheme.onSurface.withOpacity(0.3), size: 20),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No images found in this folder',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add images to your training concepts folder',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(ColorScheme colorScheme) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _currentImages.length,
      itemBuilder: (context, index) {
        final image = _currentImages[index];
        return _buildImageTile(image, colorScheme);
      },
    );
  }

  Widget _buildImageList(ColorScheme colorScheme) {
    return ListView.builder(
      itemCount: _currentImages.length,
      itemBuilder: (context, index) {
        final image = _currentImages[index];
        return _buildImageListItem(image, colorScheme);
      },
    );
  }

  Widget _buildImageTile(DatasetImage image, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(image.thumbnailUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(Icons.image, color: colorScheme.onSurface.withOpacity(0.3)),
              ),
            ),
            // Caption overlay
            if (image.caption.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  color: Colors.black54,
                  child: Text(
                    image.caption,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageListItem(DatasetImage image, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              File(image.thumbnailUrl),
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 60,
                height: 60,
                color: colorScheme.surfaceContainerHighest,
                child: Icon(Icons.image, color: colorScheme.onSurface.withOpacity(0.3)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  image.filename,
                  style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                ),
                if (image.caption.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    image.caption,
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Dataset {
  final String id;
  final String name;
  final String path;
  final String type;
  final int imageCount;
  final bool isSelected;

  Dataset({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    this.imageCount = 0,
    this.isSelected = false,
  });
}

class DatasetImage {
  final String id;
  final String filename;
  final String thumbnailUrl;
  final String caption;

  DatasetImage({
    required this.id,
    required this.filename,
    required this.thumbnailUrl,
    this.caption = '',
  });
}
