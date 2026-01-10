import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../workflow/models/workflow_models.dart';
import 'workflow_node_widget.dart';

/// Node palette for selecting node types to add to the workflow
///
/// Features:
/// - Search/filter functionality
/// - Categorized node list (Loaders, Samplers, Conditioning, etc.)
/// - Expandable categories
/// - Click or drag to add node
class NodePalette extends ConsumerStatefulWidget {
  /// Callback when a node type is selected
  final void Function(String nodeType) onNodeSelected;

  const NodePalette({
    super.key,
    required this.onNodeSelected,
  });

  @override
  ConsumerState<NodePalette> createState() => _NodePaletteState();
}

class _NodePaletteState extends ConsumerState<NodePalette> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _expandedCategories = {'loaders', 'sampling', 'conditioning'};

  @override
  void initState() {
    super.initState();
    // Ensure node definitions are registered
    NodeDefinitions.registerDefaults();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = NodeDefinitions.categories;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.widgets,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Nodes',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                // Node count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${NodeDefinitions.all.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search nodes...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),

          // Node list
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults(colorScheme)
                : _buildCategoryList(categories, colorScheme),
          ),

          // Quick add buttons
          _buildQuickAddBar(colorScheme),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ColorScheme colorScheme) {
    final filteredNodes = NodeDefinitions.all.where((def) {
      return def.title.toLowerCase().contains(_searchQuery) ||
          def.type.toLowerCase().contains(_searchQuery) ||
          def.category.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredNodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 40,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'No nodes found',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: filteredNodes.length,
      itemBuilder: (context, index) {
        final def = filteredNodes[index];
        return _NodeTile(
          definition: def,
          onTap: () => widget.onNodeSelected(def.type),
        );
      },
    );
  }

  Widget _buildCategoryList(List<String> categories, ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final nodes = NodeDefinitions.getByCategory(category);
        final isExpanded = _expandedCategories.contains(category);

        return _CategorySection(
          category: category,
          nodes: nodes,
          isExpanded: isExpanded,
          onToggle: () {
            setState(() {
              if (isExpanded) {
                _expandedCategories.remove(category);
              } else {
                _expandedCategories.add(category);
              }
            });
          },
          onNodeSelected: widget.onNodeSelected,
        );
      },
    );
  }

  Widget _buildQuickAddBar(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Add',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _QuickAddChip(
                label: 'Checkpoint',
                color: getCategoryColor('loaders'),
                onTap: () => widget.onNodeSelected('CheckpointLoaderSimple'),
              ),
              _QuickAddChip(
                label: 'KSampler',
                color: getCategoryColor('sampling'),
                onTap: () => widget.onNodeSelected('KSampler'),
              ),
              _QuickAddChip(
                label: 'CLIP',
                color: getCategoryColor('conditioning'),
                onTap: () => widget.onNodeSelected('CLIPTextEncode'),
              ),
              _QuickAddChip(
                label: 'VAE Decode',
                color: getCategoryColor('latent'),
                onTap: () => widget.onNodeSelected('VAEDecode'),
              ),
              _QuickAddChip(
                label: 'Save',
                color: getCategoryColor('image'),
                onTap: () => widget.onNodeSelected('SaveImage'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Category section with expandable node list
class _CategorySection extends StatelessWidget {
  final String category;
  final List<NodeDefinition> nodes;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(String nodeType) onNodeSelected;

  const _CategorySection({
    required this.category,
    required this.nodes,
    required this.isExpanded,
    required this.onToggle,
    required this.onNodeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryColor = getCategoryColor(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category header
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // Color indicator
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                // Category name
                Expanded(
                  child: Text(
                    category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${nodes.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Expand/collapse icon
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),

        // Node list
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Column(
              children: nodes
                  .map((def) => _NodeTile(
                        definition: def,
                        onTap: () => onNodeSelected(def.type),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

/// Individual node tile
class _NodeTile extends StatelessWidget {
  final NodeDefinition definition;
  final VoidCallback onTap;

  const _NodeTile({
    required this.definition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // Color dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: definition.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                // Node title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        definition.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (definition.description.isNotEmpty)
                        Text(
                          definition.description,
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Add icon
                Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick add chip button
class _QuickAddChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAddChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
