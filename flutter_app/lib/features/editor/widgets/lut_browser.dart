import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/color_grading_models.dart';
import '../models/editor_models.dart' hide Clip;
import '../providers/color_grading_provider.dart';

/// Panel for browsing and selecting LUT files.
///
/// Shows a grid of LUT thumbnails with preview capability.
/// Supports importing .cube files and organizing favorites.
class LUTBrowser extends ConsumerStatefulWidget {
  /// Clip ID to apply LUT to
  final EditorId? clipId;

  /// Called when a LUT is selected
  final ValueChanged<LUTFile>? onSelect;

  /// Called when the panel should close
  final VoidCallback? onClose;

  const LUTBrowser({
    super.key,
    this.clipId,
    this.onSelect,
    this.onClose,
  });

  @override
  ConsumerState<LUTBrowser> createState() => _LUTBrowserState();
}

class _LUTBrowserState extends ConsumerState<LUTBrowser>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final lutsState = ref.watch(lutLibraryProvider);
    final selectedLut = widget.clipId != null
        ? ref.watch(clipLUTProvider(widget.clipId!))
        : null;

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

          // Search bar
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search LUTs...',
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
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Tabs
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Favorites'),
                Tab(text: 'Recent'),
              ],
              labelStyle: const TextStyle(fontSize: 12),
              indicatorSize: TabBarIndicatorSize.tab,
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLUTGrid(
                  context,
                  lutsState.luts
                      .where((l) =>
                          l.name.toLowerCase().contains(_searchQuery))
                      .toList(),
                  selectedLut,
                ),
                _buildLUTGrid(
                  context,
                  lutsState.luts
                      .where((l) =>
                          l.isFavorite &&
                          l.name.toLowerCase().contains(_searchQuery))
                      .toList(),
                  selectedLut,
                ),
                _buildLUTGrid(
                  context,
                  lutsState.recentLuts
                      .where((l) =>
                          l.name.toLowerCase().contains(_searchQuery))
                      .toList(),
                  selectedLut,
                ),
              ],
            ),
          ),

          // Import button
          _buildImportButton(context),
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
          Icon(Icons.filter_vintage, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'LUT Browser',
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

  Widget _buildLUTGrid(
    BuildContext context,
    List<LUTFile> luts,
    LUTFile? selectedLut,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (luts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_vintage_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No LUTs found',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import .cube files to get started',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: luts.length,
      itemBuilder: (context, index) {
        final lut = luts[index];
        final isSelected = selectedLut?.id == lut.id;

        return _LUTCard(
          lut: lut,
          isSelected: isSelected,
          onTap: () {
            if (widget.clipId != null) {
              ref.read(colorGradingNotifierProvider.notifier).setLUT(
                    widget.clipId!,
                    lut,
                  );
            }
            widget.onSelect?.call(lut);
          },
          onFavoriteToggle: () {
            ref.read(lutLibraryProvider.notifier).toggleFavorite(lut.id);
          },
        );
      },
    );
  }

  Widget _buildImportButton(BuildContext context) {
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
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Import LUT'),
              onPressed: () {
                _showImportDialog(context);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.folder_open, size: 20),
            tooltip: 'Open LUT Folder',
            onPressed: () {
              ref.read(lutLibraryProvider.notifier).openLUTFolder();
            },
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import LUT'),
        content: const Text(
          'Select a .cube LUT file to import.\n\n'
          'LUTs will be copied to your LUT library folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(lutLibraryProvider.notifier).importLUT();
            },
            child: const Text('Browse...'),
          ),
        ],
      ),
    );
  }
}

/// Card widget for a single LUT
class _LUTCard extends StatelessWidget {
  final LUTFile lut;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  const _LUTCard({
    required this.lut,
    required this.isSelected,
    this.onTap,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // Thumbnail or placeholder
            Positioned.fill(
              child: lut.thumbnailPath != null
                  ? Image.file(
                      File(lut.thumbnailPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(context),
                    )
                  : _buildPlaceholder(context),
            ),

            // Gradient overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
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
                padding: const EdgeInsets.all(8),
                child: Text(
                  lut.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Favorite button
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: Icon(
                  lut.isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: lut.isFavorite ? Colors.red : Colors.white70,
                ),
                onPressed: onFavoriteToggle,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ),

            // Selected indicator
            if (isSelected)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 12,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.filter_vintage,
          size: 32,
          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }
}
