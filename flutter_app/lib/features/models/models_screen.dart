import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'widgets/model_card.dart';
import 'widgets/model_details_dialog.dart';

/// Model browser screen
class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(modelsProvider.notifier).loadModels();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left panel - Categories
        SizedBox(
          width: 220,
          child: _CategoriesPanel(
            selectedCategory: _selectedCategory,
            onCategorySelected: (category) {
              setState(() => _selectedCategory = category);
            },
          ),
        ),
        const VerticalDivider(width: 1),
        // Main content - Model grid
        Expanded(
          child: Column(
            children: [
              // Search bar
              _SearchBar(
                controller: _searchController,
                isGridView: _isGridView,
                onChanged: (query) {
                  setState(() => _searchQuery = query);
                },
                onViewChanged: (isGrid) {
                  setState(() => _isGridView = isGrid);
                },
                onRefresh: () {
                  ref.read(modelsProvider.notifier).refresh();
                },
              ),
              const Divider(height: 1),
              // Model grid/list
              Expanded(
                child: _ModelsContent(
                  category: _selectedCategory,
                  searchQuery: _searchQuery,
                  isGridView: _isGridView,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoriesPanel extends ConsumerWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const _CategoriesPanel({
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelsState = ref.watch(modelsProvider);

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
                Icon(Icons.category, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Categories',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Category list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _CategoryTile(
                  icon: Icons.apps,
                  label: 'All Models',
                  count: modelsState.all.length,
                  value: 'all',
                  selected: selectedCategory == 'all',
                  onTap: () => onCategorySelected('all'),
                ),
                _CategoryTile(
                  icon: Icons.auto_awesome,
                  label: 'Checkpoints',
                  count: modelsState.checkpoints.length,
                  value: 'checkpoint',
                  selected: selectedCategory == 'checkpoint',
                  onTap: () => onCategorySelected('checkpoint'),
                ),
                _CategoryTile(
                  icon: Icons.layers,
                  label: 'LoRA',
                  count: modelsState.loras.length,
                  value: 'lora',
                  selected: selectedCategory == 'lora',
                  onTap: () => onCategorySelected('lora'),
                ),
                _CategoryTile(
                  icon: Icons.tune,
                  label: 'VAE',
                  count: modelsState.vaes.length,
                  value: 'vae',
                  selected: selectedCategory == 'vae',
                  onTap: () => onCategorySelected('vae'),
                ),
                _CategoryTile(
                  icon: Icons.control_camera,
                  label: 'ControlNet',
                  count: modelsState.controlnets.length,
                  value: 'controlnet',
                  selected: selectedCategory == 'controlnet',
                  onTap: () => onCategorySelected('controlnet'),
                ),
                _CategoryTile(
                  icon: Icons.text_fields,
                  label: 'Text Encoder',
                  count: modelsState.textEncoders.length,
                  value: 'text_encoder',
                  selected: selectedCategory == 'text_encoder',
                  onTap: () => onCategorySelected('text_encoder'),
                ),
                _CategoryTile(
                  icon: Icons.brush,
                  label: 'Embeddings',
                  count: modelsState.embeddings.length,
                  value: 'embedding',
                  selected: selectedCategory == 'embedding',
                  onTap: () => onCategorySelected('embedding'),
                ),
              ],
            ),
          ),
          // Storage info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Models',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${modelsState.all.length} models',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(label),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          count.toString(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
        ),
      ),
      selected: selected,
      selectedColor: colorScheme.primary,
      selectedTileColor: colorScheme.primaryContainer.withOpacity(0.3),
      onTap: onTap,
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isGridView;
  final Function(String) onChanged;
  final Function(bool) onViewChanged;
  final VoidCallback onRefresh;

  const _SearchBar({
    required this.controller,
    required this.isGridView,
    required this.onChanged,
    required this.onViewChanged,
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
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Search models...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // View toggle
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.grid_view)),
              ButtonSegment(value: false, icon: Icon(Icons.list)),
            ],
            selected: {isGridView},
            onSelectionChanged: (selection) {
              onViewChanged(selection.first);
            },
          ),
          const SizedBox(width: 8),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
            tooltip: 'Refresh models',
          ),
        ],
      ),
    );
  }
}

class _ModelsContent extends ConsumerWidget {
  final String category;
  final String searchQuery;
  final bool isGridView;

  const _ModelsContent({
    required this.category,
    required this.searchQuery,
    required this.isGridView,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelsState = ref.watch(modelsProvider);

    if (modelsState.isLoading) {
      return const LoadingIndicator(message: 'Loading models...');
    }

    if (modelsState.error != null) {
      return ErrorDisplay(
        message: modelsState.error!,
        onRetry: () => ref.read(modelsProvider.notifier).refresh(),
      );
    }

    // Get filtered models
    List<ModelInfo> models;
    if (searchQuery.isNotEmpty) {
      models = ref.read(modelsProvider.notifier).search(
            searchQuery,
            type: category == 'all' ? null : category,
          );
    } else {
      models = modelsState.byType(category);
    }

    if (models.isEmpty) {
      return EmptyState(
        title: searchQuery.isNotEmpty ? 'No matching models' : 'No models found',
        message: searchQuery.isNotEmpty
            ? 'Try a different search term'
            : 'Connect to a backend to browse models',
        icon: Icons.view_in_ar_outlined,
        action: searchQuery.isEmpty
            ? OutlinedButton.icon(
                onPressed: () {
                  // TODO: Navigate to settings
                },
                icon: const Icon(Icons.settings),
                label: const Text('Configure Backend'),
              )
            : null,
      );
    }

    if (isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: models.length,
        itemBuilder: (context, index) {
          final model = models[index];
          return ModelCard(
            model: model,
            onTap: () => _showModelDetails(context, model),
            onSelect: () {
              ref.read(selectedModelProvider.notifier).state = model;
            },
          );
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: models.length,
        itemBuilder: (context, index) {
          final model = models[index];
          return ModelListTile(
            model: model,
            onTap: () => _showModelDetails(context, model),
            onSelect: () {
              ref.read(selectedModelProvider.notifier).state = model;
            },
          );
        },
      );
    }
  }

  void _showModelDetails(BuildContext context, ModelInfo model) {
    showDialog(
      context: context,
      builder: (context) => ModelDetailsDialog(model: model),
    );
  }
}
