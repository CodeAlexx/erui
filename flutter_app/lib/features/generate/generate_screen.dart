import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'widgets/eri_parameters_panel.dart';
import 'widgets/eri_bottom_panel.dart';
import 'widgets/prompt_bar.dart';
import 'widgets/image_metadata_panel.dart';

/// Main image generation screen - ERI style layout
class GenerateScreen extends ConsumerStatefulWidget {
  const GenerateScreen({super.key});

  @override
  ConsumerState<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends ConsumerState<GenerateScreen> {
  bool _wasGenerating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(modelsProvider.notifier).loadModels();
    });
  }

  void _checkGenerationComplete() {
    final generationState = ref.read(generationProvider);
    final params = ref.read(generationParamsProvider);

    if (_wasGenerating && !generationState.isGenerating && generationState.generatedImages.isNotEmpty) {
      final historyNotifier = ref.read(generationHistoryProvider.notifier);
      for (final url in generationState.generatedImages) {
        historyNotifier.addImage(GeneratedImage(
          url: url,
          prompt: params.prompt,
          negativePrompt: params.negativePrompt,
          params: params,
          createdAt: DateTime.now(),
          id: '${DateTime.now().millisecondsSinceEpoch}_${url.hashCode}',
        ));
      }
    }
    _wasGenerating = generationState.isGenerating;
  }

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(generationProvider);
    ref.watch(generationParamsProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkGenerationComplete());

    return Column(
      children: [
        // Main content area
        Expanded(
          child: Row(
            children: [
              // Left panel - Scrollable parameters
              SizedBox(
                width: 320,
                child: EriParametersPanel(),
              ),
              // Center column - Image preview + Prompt bar
              Expanded(
                child: Column(
                  children: [
                    // Image preview (takes remaining space)
                    Expanded(
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Builder(builder: (context) {
                          final history = ref.watch(generationHistoryProvider);
                          final allImages = [
                            ...generationState.generatedImages,
                            ...history.map((h) => h.url),
                          ];
                          return GenerationPreview(
                            imageUrl: generationState.currentImage ??
                                (generationState.generatedImages.isNotEmpty
                                    ? generationState.generatedImages.first
                                    : null),
                            isGenerating: generationState.isGenerating,
                            progress: generationState.progress,
                            currentStep: generationState.currentStep,
                            totalSteps: generationState.totalSteps,
                            allImages: allImages.isNotEmpty ? allImages : null,
                          );
                        }),
                      ),
                    ),
                    // Prompt bar - above bottom tabs
                    const PromptBar(),
                  ],
                ),
              ),
              // Right panel - History OR Metadata (like SwarmUI)
              SizedBox(
                width: 300,
                child: _RightPanel(),
              ),
            ],
          ),
        ),
        // Bottom panel - ONLY tabs (no prompt area)
        EriBottomPanel(),
      ],
    );
  }
}

/// Right-side panel - shows History OR Metadata (like SwarmUI)
class _RightPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedImage = ref.watch(selectedImageProvider);

    // Show metadata panel if an image is selected
    if (selectedImage.hasImage) {
      return Column(
        children: [
          // Back to history button
          _BackToHistoryButton(),
          // Metadata panel
          const Expanded(child: ImageMetadataPanel()),
        ],
      );
    }

    // Otherwise show history
    return _HistoryPanel();
  }
}

/// Back to history button
class _BackToHistoryButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            onPressed: () => ref.read(selectedImageProvider.notifier).clearSelection(),
            tooltip: 'Back to history',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text('Image Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => ref.read(selectedImageProvider.notifier).clearSelection(),
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Show right-click context menu for image
void _showImageContextMenu(BuildContext context, WidgetRef ref, String imageUrl, Offset position) {
  final colorScheme = Theme.of(context).colorScheme;

  showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
    items: [
      PopupMenuItem<String>(
        value: 'use_image',
        child: Row(
          children: [
            Icon(Icons.image, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Use Image', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'view_full',
        child: Row(
          children: [
            Icon(Icons.fullscreen, size: 18, color: colorScheme.onSurface),
            const SizedBox(width: 8),
            const Text('View Full Size', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'reuse_params',
        child: Row(
          children: [
            Icon(Icons.refresh, size: 18, color: colorScheme.onSurface),
            const SizedBox(width: 8),
            const Text('Reuse Parameters', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: colorScheme.error),
            const SizedBox(width: 8),
            Text('Delete Image', style: TextStyle(fontSize: 13, color: colorScheme.error)),
          ],
        ),
      ),
    ],
  ).then((value) {
    if (value == null) return;

    switch (value) {
      case 'use_image':
        // Set as init image
        ref.read(generationParamsProvider.notifier).setExtraParam('init_image', imageUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image set as init image')),
        );
        break;
      case 'view_full':
        ImageViewerDialog.show(context, imageUrl: imageUrl);
        break;
      case 'reuse_params':
        // Select image to load params
        ref.read(selectedImageProvider.notifier).selectImageUrl(imageUrl);
        break;
      case 'delete':
        _confirmDeleteImage(context, ref, imageUrl);
        break;
    }
  });
}

/// Confirm delete dialog
void _confirmDeleteImage(BuildContext context, WidgetRef ref, String imageUrl) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Image?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // Remove from history
            final history = ref.read(generationHistoryProvider);
            final imageToRemove = history.firstWhere(
              (img) => img.url == imageUrl,
              orElse: () => GeneratedImage(
                url: imageUrl,
                prompt: '',
                params: const GenerationParams(),
                createdAt: DateTime.now(),
              ),
            );
            if (imageToRemove.id != null) {
              ref.read(generationHistoryProvider.notifier).removeImage(imageToRemove.id!);
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image removed from history')),
            );
          },
          child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    ),
  );
}

/// History panel showing generated images
class _HistoryPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final history = ref.watch(generationHistoryProvider);
    final generationState = ref.watch(generationProvider);
    final selectedImage = ref.watch(selectedImageProvider);

    // Combine current batch with history
    final allImages = [
      ...generationState.generatedImages,
      ...history.map((h) => h.url),
    ];

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.history, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('History', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                const Spacer(),
                Text('${allImages.length}', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          // Image grid
          Expanded(
            child: allImages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined, size: 40, color: colorScheme.outlineVariant),
                        const SizedBox(height: 8),
                        Text('No images yet', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text('Generate some!', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: allImages.length,
                    itemBuilder: (context, index) {
                      final imageUrl = allImages[index];
                      final isSelected = selectedImage.imageUrl == imageUrl;

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            // Select image to show metadata
                            ref.read(selectedImageProvider.notifier).selectImageUrl(imageUrl);
                          },
                          onDoubleTap: () {
                            // Double-click opens full viewer
                            ImageViewerDialog.show(
                              context,
                              imageUrl: imageUrl,
                              allImages: allImages,
                              initialIndex: index,
                            );
                          },
                          onSecondaryTapUp: (details) {
                            // Right-click context menu
                            _showImageContextMenu(context, ref, imageUrl, details.globalPosition);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: isSelected
                                  ? Border.all(color: colorScheme.primary, width: 2)
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(isSelected ? 2 : 4),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(Icons.broken_image, color: colorScheme.error, size: 20),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
