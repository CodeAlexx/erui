import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/providers.dart';
import '../../../providers/lora_provider.dart';
import '../../../providers/models_provider.dart';
import '../../../providers/gallery_provider.dart';
import '../../../services/api_service.dart';
import '../../../widgets/image_viewer_dialog.dart';

/// Bottom tab selection
enum BottomTab { history, presets, models, loras, vaes, embeddings, controlnets, wildcards, tools }

final bottomTabProvider = StateProvider<BottomTab>((ref) => BottomTab.history);
final bottomPanelHeightProvider = StateProvider<double>((ref) => 0); // 0 = collapsed

/// ERI-style bottom panel with tabs
class EriBottomPanel extends ConsumerStatefulWidget {
  const EriBottomPanel({super.key});

  @override
  ConsumerState<EriBottomPanel> createState() => _EriBottomPanelState();
}

class _EriBottomPanelState extends ConsumerState<EriBottomPanel> {
  double _panelHeight = 0; // 0 = collapsed, otherwise height in pixels
  static const double _minHeight = 100; // Minimum when open
  static const double _collapseThreshold = 50; // Below this, auto-collapse
  static const double _maxHeight = 500;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedTab = ref.watch(bottomTabProvider);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Resizable tab content panel
          if (_panelHeight > 0) ...[
            // Drag handle for resizing
            GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  final newHeight = _panelHeight - details.delta.dy;
                  if (newHeight < _collapseThreshold) {
                    _panelHeight = 0; // Collapse
                  } else {
                    _panelHeight = newHeight.clamp(_minHeight, _maxHeight);
                  }
                });
              },
              child: Container(
                height: 8,
                color: colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            // Tab content
            SizedBox(
              height: _panelHeight,
              child: _TabContent(selectedTab: selectedTab),
            ),
          ],

          // Current LoRAs row (above tab bar, like SwarmUI)
          _CurrentLorasRow(),

          // Tab bar - compact
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                _TabButton(
                  label: 'History',
                  isSelected: selectedTab == BottomTab.history && _panelHeight > 0,
                  onTap: () => _toggleTab(BottomTab.history),
                ),
                _TabButton(
                  label: 'Presets',
                  isSelected: selectedTab == BottomTab.presets && _panelHeight > 0,
                  onTap: () => _toggleTab(BottomTab.presets),
                ),
                _TabButton(
                  label: 'Models',
                  isSelected: selectedTab == BottomTab.models && _panelHeight > 0,
                  onTap: () => _toggleTab(BottomTab.models),
                ),
                _TabButton(
                  label: 'VAEs',
                  isSelected: selectedTab == BottomTab.vaes && _panelHeight > 0,
                  onTap: () => _toggleTab(BottomTab.vaes),
                ),
                _TabButton(
                  label: 'LoRAs',
                  isSelected: selectedTab == BottomTab.loras && _panelHeight > 0,
                  onTap: () => _toggleTab(BottomTab.loras),
                ),
                _TabButton(
                  label: 'Embeddings',
                  isSelected: selectedTab == BottomTab.embeddings && _panelHeight > 0,
                  onTap: () => _toggleTab(BottomTab.embeddings),
                ),
                _TabButton(
                  label: 'ControlNets',
                  isSelected: selectedTab == BottomTab.controlnets && _panelHeight > 0,
                  onTap: () => _toggleTab(BottomTab.controlnets),
                ),
                _TabButton(
                  label: 'Wildcards',
                  isSelected: selectedTab == BottomTab.wildcards && _panelHeight > 0,
                  onTap: () => _toggleTab(BottomTab.wildcards),
                ),
                _TabButton(
                  label: 'Tools',
                  isSelected: selectedTab == BottomTab.tools && _panelHeight > 0,
                  onTap: () => _toggleTab(BottomTab.tools),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleTab(BottomTab tab) {
    final currentTab = ref.read(bottomTabProvider);
    if (currentTab == tab && _panelHeight > 0) {
      // Collapse if clicking same tab
      setState(() => _panelHeight = 0);
    } else {
      // Expand and switch to new tab
      ref.read(bottomTabProvider.notifier).state = tab;
      setState(() {
        if (_panelHeight == 0) _panelHeight = 200; // Default expanded height
      });
    }
  }
}

/// Tab button
class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab content
class _TabContent extends ConsumerWidget {
  final BottomTab selectedTab;

  const _TabContent({required this.selectedTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (selectedTab) {
      case BottomTab.history:
        return _HistoryTab();
      case BottomTab.models:
        return _ModelsGridTab();
      case BottomTab.loras:
        return _LorasGridTab();
      case BottomTab.vaes:
        return _VAEsTab();
      default:
        return Center(
          child: Text(
            '${selectedTab.name} coming soon',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        );
    }
  }
}

/// History tab content - shows persistent history from ERI output folder
class _HistoryTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  @override
  void initState() {
    super.initState();
    // Load persistent history on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(galleryProvider.notifier).loadImages(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final apiService = ref.watch(apiServiceProvider);
    final galleryState = ref.watch(galleryProvider);
    final generationState = ref.watch(generationProvider);

    // Combine current session images with persistent history
    final currentImages = generationState.generatedImages;
    final historyImages = galleryState.images;

    // Create unified list with current batch first
    final allEntries = <_HistoryEntry>[
      ...currentImages.map((url) => _HistoryEntry(url: url, isCurrentSession: true)),
      ...historyImages.map((img) => _HistoryEntry(
        url: '${apiService.baseUrl}${img.url}',
        image: img,
        isCurrentSession: false,
      )),
    ];

    if (allEntries.isEmpty) {
      if (galleryState.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No images yet', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.read(galleryProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    final allUrls = allEntries.map((e) => e.url).toList();

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text('${allEntries.length} images', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: () => ref.read(galleryProvider.notifier).refresh(),
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        // Image grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            scrollDirection: Axis.horizontal,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: allEntries.length,
            itemBuilder: (context, index) {
              final entry = allEntries[index];
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => ImageViewerDialog.show(
                    context,
                    imageUrl: entry.url,
                    allImages: allUrls,
                    initialIndex: index,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: entry.url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: colorScheme.surfaceContainerHighest),
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(Icons.broken_image, color: colorScheme.error, size: 20),
                          ),
                        ),
                      ),
                      // Current session indicator
                      if (entry.isCurrentSession)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(Icons.auto_awesome, size: 10, color: colorScheme.onPrimary),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryEntry {
  final String url;
  final GalleryImage? image;
  final bool isCurrentSession;

  _HistoryEntry({required this.url, this.image, required this.isCurrentSession});
}

/// Models grid tab content like ERI
class _ModelsGridTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelsState = ref.watch(modelsProvider);
    final params = ref.watch(generationParamsProvider);
    final models = modelsState.checkpoints;

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // View mode buttons
              _ViewModeButton(icon: Icons.grid_view, isSelected: true),
              _ViewModeButton(icon: Icons.view_list, isSelected: false),
              const SizedBox(width: 12),
              // Filter
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filter...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const Spacer(),
              Text('Sort: ', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              DropdownButton<String>(
                value: 'Name',
                isDense: true,
                items: ['Name', 'Date', 'Size'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (_) {},
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
        // Model grid - horizontal cards like ERI
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: models.length,
            itemBuilder: (context, index) {
              final model = models[index];
              final isSelected = params.model == model.name;

              return _ModelCard(model: model, isSelected: isSelected, onTap: () {
                ref.read(generationParamsProvider.notifier).setModel(model.name);
                ref.read(generationParamsProvider.notifier).applyModelDefaults(model.name);
              });
            },
          ),
        ),
      ],
    );
  }
}

/// Model card like ERI - horizontal layout with preview and text
class _ModelCard extends ConsumerWidget {
  final ModelInfo model;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModelCard({required this.model, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final apiService = ref.watch(apiServiceProvider);

    // Build full preview URL
    String? previewUrl;
    if (model.previewImage != null) {
      previewUrl = '${apiService.baseUrl}${model.previewImage}';
    }

    return Card(
      color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview image (square on left)
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: colorScheme.surface,
                child: previewUrl != null
                    ? Image.network(
                        previewUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => _PlaceholderIcon(colorScheme: colorScheme),
                      )
                    : _PlaceholderIcon(colorScheme: colorScheme),
              ),
            ),
            // Info on right
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      'Title: ${model.title ?? model.displayName}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Type
                    Text(
                      'Type: ${model.modelClass ?? model.type}',
                      style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    // Resolution placeholder
                    Text(
                      'Resolution: 1024x1024',
                      style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    // Description
                    Expanded(
                      child: Text(
                        'Description: ${_getDescription(model)}',
                        style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Menu icon
            Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.menu, size: 16, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _getDescription(ModelInfo model) {
    // Try to extract description from metadata or generate one
    if (model.metadata != null && model.metadata!['description'] != null) {
      return model.metadata!['description'] as String;
    }
    // Default descriptions based on model type/name
    if (model.name.toLowerCase().contains('flux')) {
      return 'A guidance distilled rectified flow model.';
    }
    if (model.name.toLowerCase().contains('sdxl') || model.name.toLowerCase().contains('sd_xl')) {
      return 'Stable Diffusion XL base model.';
    }
    return '(Unset)';
  }
}

/// Placeholder icon for models without preview
class _PlaceholderIcon extends StatelessWidget {
  final ColorScheme colorScheme;
  const _PlaceholderIcon({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers, size: 32, color: colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 4),
          Text(
            'PLACEHOLDER',
            style: TextStyle(fontSize: 8, color: colorScheme.onSurfaceVariant, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

/// View mode button
class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;

  const _ViewModeButton({required this.icon, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primary.withOpacity(0.2) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: () {},
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// LoRAs grid tab content
class _LorasGridTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final lorasAsync = ref.watch(loraListProvider);
    final selectedLoras = ref.watch(selectedLorasProvider);
    final loras = lorasAsync.valueOrNull ?? [];

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filter...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const Spacer(),
              Text('${selectedLoras.length} selected', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
        // LoRA grid - horizontal cards like ERI
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: loras.length,
            itemBuilder: (context, index) {
              final lora = loras[index];
              final isSelected = selectedLoras.any((s) => s.lora.name == lora.name);

              return _LoraCard(lora: lora, isSelected: isSelected, onTap: () {
                if (isSelected) {
                  ref.read(selectedLorasProvider.notifier).removeLora(lora.name);
                } else {
                  ref.read(selectedLorasProvider.notifier).addLora(lora);
                }
              });
            },
          ),
        ),
      ],
    );
  }
}

/// LoRA card - horizontal layout like ERI
class _LoraCard extends ConsumerWidget {
  final LoraModel lora;
  final bool isSelected;
  final VoidCallback onTap;

  const _LoraCard({required this.lora, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final apiService = ref.watch(apiServiceProvider);

    // Build preview URL if available
    String? previewUrl;
    if (lora.previewImage != null) {
      previewUrl = '${apiService.baseUrl}${lora.previewImage}';
    }

    return Card(
      color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview image (square on left)
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: colorScheme.surface,
                child: Stack(
                  children: [
                    previewUrl != null
                        ? Image.network(
                            previewUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => _PlaceholderIcon(colorScheme: colorScheme),
                          )
                        : _PlaceholderIcon(colorScheme: colorScheme),
                    if (isSelected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check, color: colorScheme.onPrimary, size: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Info on right
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      'Title: ${lora.title}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Type
                    Text(
                      'Type: (Unset)',
                      style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    // Resolution
                    Text(
                      'Resolution: 0x0',
                      style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    // Description
                    Expanded(
                      child: Text(
                        'Description: (Unset)',
                        style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Menu icon
            Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.menu, size: 16, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// VAEs tab content
class _VAEsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelsState = ref.watch(modelsProvider);
    final vaes = modelsState.vaes;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filter...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
        Expanded(
          child: vaes.isEmpty
              ? Center(child: Text('No VAEs found', style: TextStyle(color: colorScheme.onSurfaceVariant)))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    childAspectRatio: 1.2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: vaes.length,
                  itemBuilder: (context, index) {
                    final vae = vaes[index];
                    return Card(
                      color: colorScheme.surfaceContainerHighest,
                      child: InkWell(
                        onTap: () {},
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.memory, color: colorScheme.onSurfaceVariant),
                              const SizedBox(height: 4),
                              Text(
                                vae.displayName,
                                style: const TextStyle(fontSize: 10),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Current LoRAs row - shows selected LoRAs above tab bar like SwarmUI
class _CurrentLorasRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedLoras = ref.watch(selectedLorasProvider);

    // Don't show row if no LoRAs selected
    if (selectedLoras.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          // Label
          Text(
            'Current LoRAs (${selectedLoras.length}):',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          // LoRA chips (scrollable if many)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: selectedLoras.map((lora) => _LoraChip(lora: lora)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual LoRA chip with scroll-wheel strength adjustment
class _LoraChip extends ConsumerStatefulWidget {
  final SelectedLora lora;

  const _LoraChip({required this.lora});

  @override
  ConsumerState<_LoraChip> createState() => _LoraChipState();
}

class _LoraChipState extends ConsumerState<_LoraChip> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final loraName = widget.lora.lora.name.replaceAll('.safetensors', '');
    // Truncate long names
    final displayName = loraName.length > 15 ? '${loraName.substring(0, 15)}...' : loraName;

    // SwarmUI-style orange/yellow color
    const loraColor = Color(0xFFE6A83C);
    const loraTextColor = Color(0xFF1A1A1A);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: loraColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: loraColor.withOpacity(0.8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // LoRA name
            Text(
              displayName,
              style: const TextStyle(fontSize: 11, color: loraTextColor, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            // Strength value with scroll wheel support
            Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  final delta = event.scrollDelta.dy > 0 ? -0.1 : 0.1;
                  final newStrength = (widget.lora.strength + delta).clamp(0.0, 2.0);
                  ref.read(selectedLorasProvider.notifier).updateStrength(
                    widget.lora.lora.name,
                    double.parse(newStrength.toStringAsFixed(1)),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: loraTextColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: loraTextColor.withOpacity(0.3)),
                ),
                child: Text(
                  widget.lora.strength.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10, color: loraTextColor, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // Remove button (shows on hover or always for mobile)
            if (_isHovering) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => ref.read(selectedLorasProvider.notifier).removeLora(widget.lora.lora.name),
                child: Icon(Icons.close, size: 14, color: loraTextColor.withOpacity(0.7)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
