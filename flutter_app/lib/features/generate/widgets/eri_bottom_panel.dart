import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/providers.dart';
import '../../../providers/lora_provider.dart';
import '../../../providers/models_provider.dart';
import '../../../providers/gallery_provider.dart';
import '../../../services/comfyui_service.dart';
import '../../../widgets/image_viewer_dialog.dart';
import '../../../widgets/image_preview.dart' show isVideoUrl;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// Feature imports
import 'presets_panel.dart';
import '../../tools/grid_generator_screen.dart';
import '../../tools/model_comparison_screen.dart';
import '../../tools/batch_processing_screen.dart';
import '../../tools/image_interrogator_screen.dart';
import '../../tools/model_merger_screen.dart';
import '../../tools/analytics_screen.dart';
import '../../wildcards/wildcards_screen.dart';

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
      case BottomTab.presets:
        return const PresetsPanel();
      case BottomTab.models:
        return _ModelsGridTab();
      case BottomTab.loras:
        return _LorasGridTab();
      case BottomTab.vaes:
        return _VAEsTab();
      case BottomTab.embeddings:
        return _EmbeddingsTab();
      case BottomTab.controlnets:
        return _ControlNetsTab();
      case BottomTab.wildcards:
        return const WildcardsScreen();
      case BottomTab.tools:
        return _ToolsTab();
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
    final comfyService = ref.watch(comfyUIServiceProvider);
    final galleryState = ref.watch(galleryProvider);
    final generationState = ref.watch(generationProvider);
    final baseUrl = 'http://${comfyService.host}:${comfyService.port}';

    // Combine current session images with persistent history
    final currentImages = generationState.generatedImages;
    final historyImages = galleryState.images;

    // Create unified list with current batch first
    final allEntries = <_HistoryEntry>[
      ...currentImages.map((url) {
        // For current session videos, construct thumbnail URL from the video URL
        String? thumbUrl;
        if (isVideoUrl(url)) {
          // Extract path from URL and create thumbnail URL
          // ComfyUI uses /view?filename=... format
          final uri = Uri.parse(url);
          final filename = uri.queryParameters['filename'];
          if (filename != null) {
            // Use first frame as thumbnail for videos
            thumbUrl = url;
          }
        }
        return _HistoryEntry(url: url, thumbnailUrl: thumbUrl, isCurrentSession: true);
      }),
      ...historyImages.map((img) => _HistoryEntry(
        url: '$baseUrl${img.url}',
        thumbnailUrl: img.thumbnailUrl != null ? '$baseUrl${img.thumbnailUrl}' : null,
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
              final isVideo = isVideoUrl(entry.url);
              // Use thumbnail for videos, or the image URL itself for images
              final displayUrl = isVideo && entry.thumbnailUrl != null ? entry.thumbnailUrl! : entry.url;

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    if (isVideo) {
                      _showVideoDialog(context, entry.url);
                    } else {
                      ImageViewerDialog.show(
                        context,
                        imageUrl: entry.url,
                        allImages: allUrls.where((u) => !isVideoUrl(u)).toList(),
                        initialIndex: allUrls.where((u) => !isVideoUrl(u)).toList().indexOf(entry.url),
                      );
                    }
                  },
                  onSecondaryTapUp: (details) {
                    _showContextMenu(context, ref, entry, details.globalPosition);
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: displayUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: colorScheme.surfaceContainerHighest),
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: isVideo
                                ? Icon(Icons.play_circle_filled, color: colorScheme.primary, size: 32)
                                : Icon(Icons.broken_image, color: colorScheme.error, size: 20),
                          ),
                        ),
                      ),
                      // Video indicator overlay
                      if (isVideo)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
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

/// Show context menu for history item
void _showContextMenu(BuildContext context, WidgetRef ref, _HistoryEntry entry, Offset position) {
  final isVideo = isVideoUrl(entry.url);
  showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
    items: [
      PopupMenuItem<String>(
        value: 'view',
        child: Row(
          children: [
            Icon(isVideo ? Icons.play_circle : Icons.image, size: 18),
            const SizedBox(width: 8),
            Text(isVideo ? 'Play Video' : 'View Image'),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'open_folder',
        child: const Row(
          children: [
            Icon(Icons.folder_open, size: 18),
            SizedBox(width: 8),
            Text('Open in File Manager'),
          ],
        ),
      ),
      if (entry.image?.metadata != null)
        PopupMenuItem<String>(
          value: 'reuse',
          child: const Row(
            children: [
              Icon(Icons.replay, size: 18),
              SizedBox(width: 8),
              Text('Reuse Parameters'),
            ],
          ),
        ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
    ],
  ).then((value) async {
    if (value == null) return;
    switch (value) {
      case 'view':
        if (isVideo) {
          _showVideoDialog(context, entry.url);
        } else {
          ImageViewerDialog.show(context, imageUrl: entry.url);
        }
        break;
      case 'open_folder':
        // Extract path and open in file manager
        final uri = Uri.parse(entry.url);
        final path = uri.queryParameters['path'] ?? '';
        if (path.isNotEmpty) {
          Process.run('xdg-open', ['/home/alex/eriui/comfyui/ComfyUI/output/']);
        }
        break;
      case 'reuse':
        // Apply parameters from image metadata
        if (entry.image?.metadata != null) {
          ref.read(generationParamsProvider.notifier).applyFromMetadata(entry.image!.metadata);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parameters applied'), duration: Duration(seconds: 2)),
          );
        }
        break;
      case 'delete':
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete?'),
            content: Text('Delete this ${isVideo ? 'video' : 'image'}?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        );
        if (confirmed == true && entry.image != null) {
          ref.read(galleryProvider.notifier).deleteImage(entry.image!.path);
        }
        break;
    }
  });
}

/// Show video player in a dialog
void _showVideoDialog(BuildContext context, String videoUrl) {
  showDialog(
    context: context,
    builder: (context) => _VideoPlayerDialog(videoUrl: videoUrl),
  );
}

/// Video player dialog widget
class _VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  const _VideoPlayerDialog({required this.videoUrl});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  Player? _player;
  VideoController? _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    print('Video URL: ${widget.videoUrl}');
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _player = Player();
      _controller = VideoController(_player!);

      // Listen for player state changes
      _player!.stream.playing.listen((playing) {
        if (mounted && _isLoading && playing) {
          setState(() => _isLoading = false);
        }
      });

      _player!.stream.error.listen((error) {
        if (mounted && error.isNotEmpty) {
          setState(() {
            _isLoading = false;
            _error = error;
          });
        }
      });

      await _player!.open(Media(widget.videoUrl));
      await _player!.setPlaylistMode(PlaylistMode.loop);

      // Set loading to false after a short delay if video starts
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isLoading && _error == null) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(40),
      child: Container(
        width: screenSize.width * 0.8,
        height: screenSize.height * 0.8,
        color: Colors.black,
        child: Stack(
          children: [
            // Video player - uses FittedBox to maintain aspect ratio
            if (_controller != null && _error == null)
              Center(
                child: Video(
                  controller: _controller!,
                  controls: MaterialVideoControls,
                  fit: BoxFit.contain,
                ),
              ),
            // Loading indicator
            if (_isLoading && _error == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: colorScheme.primary),
                    const SizedBox(height: 16),
                    const Text('Loading video...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            // Error display
            if (_error != null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.error, size: 48),
                    const SizedBox(height: 16),
                    Text('Failed to load video', style: TextStyle(color: colorScheme.error)),
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEntry {
  final String url;
  final String? thumbnailUrl;
  final GalleryImage? image;
  final bool isCurrentSession;

  _HistoryEntry({required this.url, this.thumbnailUrl, this.image, required this.isCurrentSession});
}

/// Models grid tab content like ERI
class _ModelsGridTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ModelsGridTab> createState() => _ModelsGridTabState();
}

class _ModelsGridTabState extends ConsumerState<_ModelsGridTab> {
  final _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize controller with current filter value
    _filterController.text = ref.read(modelFilterProvider);
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelsState = ref.watch(modelsProvider);
    final params = ref.watch(generationParamsProvider);
    final filterText = ref.watch(modelFilterProvider);

    // Combine checkpoints AND diffusion models (Flux, Wan, LTX, etc.)
    final allModels = [...modelsState.checkpoints, ...modelsState.diffusionModels];

    // Filter models based on filter text
    final models = filterText.isEmpty
        ? allModels
        : allModels.where((model) {
            final searchLower = filterText.toLowerCase();
            return model.name.toLowerCase().contains(searchLower) ||
                model.displayName.toLowerCase().contains(searchLower) ||
                (model.title?.toLowerCase().contains(searchLower) ?? false) ||
                (model.modelClass?.toLowerCase().contains(searchLower) ?? false);
          }).toList();

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
                  controller: _filterController,
                  decoration: InputDecoration(
                    hintText: 'Filter...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    suffixIcon: _filterController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _filterController.clear();
                              ref.read(modelFilterProvider.notifier).state = '';
                            },
                          )
                        : null,
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (value) {
                    ref.read(modelFilterProvider.notifier).state = value;
                  },
                ),
              ),
              const Spacer(),
              Text('${models.length} models', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 12),
              Text('Sort: ', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              DropdownButton<String>(
                value: 'Name',
                isDense: true,
                items: ['Name', 'Date', 'Size'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (_) {},
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.refresh, size: 18, color: colorScheme.primary),
                tooltip: 'Refresh Models',
                onPressed: () => ref.read(modelsProvider.notifier).refresh(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
    final comfyService = ref.watch(comfyUIServiceProvider);
    final baseUrl = 'http://${comfyService.host}:${comfyService.port}';

    // Build full preview URL
    String? previewUrl;
    if (model.previewImage != null) {
      previewUrl = '$baseUrl${model.previewImage}';
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
class _LorasGridTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LorasGridTab> createState() => _LorasGridTabState();
}

class _LorasGridTabState extends ConsumerState<_LorasGridTab> {
  final _filterController = TextEditingController();

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lorasAsync = ref.watch(filteredLoraListProvider);
    final selectedLoras = ref.watch(selectedLorasProvider);
    final loras = lorasAsync.valueOrNull ?? [];

    return Column(
      children: [
        // Toolbar with filter and refresh
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _filterController,
                  decoration: InputDecoration(
                    hintText: 'Filter...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    suffixIcon: _filterController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _filterController.clear();
                              ref.read(loraFilterProvider.notifier).state = '';
                            },
                          )
                        : null,
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (value) {
                    ref.read(loraFilterProvider.notifier).state = value;
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh LoRAs',
                onPressed: () => ref.invalidate(loraListProvider),
              ),
              const Spacer(),
              Text('${loras.length} LoRAs, ${selectedLoras.length} selected',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
        // LoRA grid
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
    final comfyService = ref.watch(comfyUIServiceProvider);
    final baseUrl = 'http://${comfyService.host}:${comfyService.port}';

    // Build preview URL if available
    String? previewUrl;
    if (lora.previewImage != null) {
      previewUrl = '$baseUrl${lora.previewImage}';
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
                    // Type (LoRA or LyCORIS)
                    Row(
                      children: [
                        Text(
                          'Type: ',
                          style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: lora.isLycoris
                                ? Colors.purple.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            lora.type,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: lora.isLycoris ? Colors.purple : Colors.blue,
                            ),
                          ),
                        ),
                        if (lora.baseModel != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            lora.baseModel!,
                            style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
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
class _VAEsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_VAEsTab> createState() => _VAEsTabState();
}

class _VAEsTabState extends ConsumerState<_VAEsTab> {
  final _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize controller with current filter value
    _filterController.text = ref.read(vaeFilterProvider);
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelsState = ref.watch(modelsProvider);
    final filterText = ref.watch(vaeFilterProvider);
    final allVaes = modelsState.vaes;

    // Filter VAEs based on filter text
    final vaes = filterText.isEmpty
        ? allVaes
        : allVaes.where((vae) {
            final searchLower = filterText.toLowerCase();
            return vae.name.toLowerCase().contains(searchLower) ||
                vae.displayName.toLowerCase().contains(searchLower) ||
                (vae.title?.toLowerCase().contains(searchLower) ?? false);
          }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _filterController,
                  decoration: InputDecoration(
                    hintText: 'Filter...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    suffixIcon: _filterController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _filterController.clear();
                              ref.read(vaeFilterProvider.notifier).state = '';
                            },
                          )
                        : null,
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (value) {
                    ref.read(vaeFilterProvider.notifier).state = value;
                  },
                ),
              ),
              const Spacer(),
              Text('${vaes.length} VAEs', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.refresh, size: 18, color: colorScheme.primary),
                tooltip: 'Refresh VAEs',
                onPressed: () => ref.read(modelsProvider.notifier).refresh(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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

/// Embeddings tab content
class _EmbeddingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelsState = ref.watch(modelsProvider);
    final embeddings = modelsState.embeddings;

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
                    hintText: 'Filter embeddings...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const Spacer(),
              Text('${embeddings.length} embeddings', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.refresh, size: 18, color: colorScheme.primary),
                tooltip: 'Refresh Embeddings',
                onPressed: () => ref.read(modelsProvider.notifier).refresh(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
        Expanded(
          child: embeddings.isEmpty
              ? Center(child: Text('No embeddings found', style: TextStyle(color: colorScheme.onSurfaceVariant)))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 2.5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: embeddings.length,
                  itemBuilder: (context, index) {
                    final embedding = embeddings[index];
                    return Card(
                      color: colorScheme.surfaceContainerHighest,
                      child: InkWell(
                        onTap: () {
                          // Copy embedding trigger to clipboard
                          final trigger = embedding.name.replaceAll('.safetensors', '').replaceAll('.pt', '');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied: <$trigger>'), duration: const Duration(seconds: 1)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Icon(Icons.text_fields, color: colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  embedding.displayName,
                                  style: const TextStyle(fontSize: 11),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
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

/// ControlNets tab content
class _ControlNetsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final modelsState = ref.watch(modelsProvider);
    final controlnets = modelsState.controlnets;
    final params = ref.watch(generationParamsProvider);
    final comfyService = ref.watch(comfyUIServiceProvider);
    final baseUrl = 'http://${comfyService.host}:${comfyService.port}';

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
                    hintText: 'Filter ControlNets...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const Spacer(),
              Text('${controlnets.length} models', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.refresh, size: 18, color: colorScheme.primary),
                tooltip: 'Refresh ControlNets',
                onPressed: () => ref.read(modelsProvider.notifier).refresh(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
        Expanded(
          child: controlnets.isEmpty
              ? Center(child: Text('No ControlNets found', style: TextStyle(color: colorScheme.onSurfaceVariant)))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: controlnets.length,
                  itemBuilder: (context, index) {
                    final cn = controlnets[index];
                    final isSelected = params.controlNetModel == cn.name;
                    String? previewUrl;
                    if (cn.previewImage != null) {
                      previewUrl = '$baseUrl${cn.previewImage}';
                    }

                    return Card(
                      color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          ref.read(generationParamsProvider.notifier).setControlNetModel(
                            isSelected ? null : cn.name,
                          );
                        },
                        child: Row(
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: previewUrl != null
                                  ? Image.network(previewUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                                      Icon(Icons.control_camera, color: colorScheme.primary))
                                  : Container(
                                      color: colorScheme.surface,
                                      child: Icon(Icons.control_camera, color: colorScheme.primary),
                                    ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      cn.displayName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (cn.modelClass != null)
                                      Text(
                                        cn.modelClass!,
                                        style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.check_circle, color: colorScheme.primary, size: 18),
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

/// Tools tab content - Grid Generator, Model Comparison, etc.
class _ToolsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _ToolCard(
          icon: Icons.grid_view,
          title: 'XY Grid Generator',
          description: 'Generate parameter comparison grids',
          color: Colors.blue,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const GridGeneratorScreen(),
            ));
          },
        ),
        _ToolCard(
          icon: Icons.compare,
          title: 'Model Comparison',
          description: 'Compare outputs between models',
          color: Colors.orange,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ModelComparisonScreen(),
            ));
          },
        ),
        _ToolCard(
          icon: Icons.batch_prediction,
          title: 'Batch Processing',
          description: 'Process multiple prompts/images',
          color: Colors.green,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const BatchProcessingScreen(),
            ));
          },
        ),
        _ToolCard(
          icon: Icons.image_search,
          title: 'Image Interrogator',
          description: 'Generate prompts from images',
          color: Colors.purple,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ImageInterrogatorScreen(),
            ));
          },
        ),
        _ToolCard(
          icon: Icons.merge_type,
          title: 'Model Merger',
          description: 'Merge checkpoint models',
          color: Colors.red,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ModelMergerScreen(),
            ));
          },
        ),
        _ToolCard(
          icon: Icons.analytics,
          title: 'Usage Analytics',
          description: 'View generation statistics',
          color: Colors.teal,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AnalyticsScreen(),
            ));
          },
        ),
      ],
    );
  }
}

/// Tool card widget
class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.outline),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
