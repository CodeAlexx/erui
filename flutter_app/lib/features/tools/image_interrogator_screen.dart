import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../../providers/providers.dart';
import '../../services/api_service.dart';

/// Image Interrogator Screen
///
/// Tool for analyzing images and generating tags/captions using various
/// interrogation models (CLIP, BLIP, WD14 tagger, etc.)
class ImageInterrogatorScreen extends ConsumerStatefulWidget {
  const ImageInterrogatorScreen({super.key});

  @override
  ConsumerState<ImageInterrogatorScreen> createState() =>
      _ImageInterrogatorScreenState();
}

class _ImageInterrogatorScreenState
    extends ConsumerState<ImageInterrogatorScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(interrogatorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Interrogator'),
        actions: [
          // Clear all button
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear All',
            onPressed: state.images.isEmpty
                ? null
                : () => ref.read(interrogatorProvider.notifier).clearAll(),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left side - Image drop zone and controls
          SizedBox(
            width: 400,
            child: _ControlPanel(),
          ),
          VerticalDivider(width: 1, color: colorScheme.outlineVariant),
          // Right side - Results
          Expanded(
            child: _ResultsPanel(),
          ),
        ],
      ),
    );
  }
}

/// Control panel with drop zone and settings
class _ControlPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(interrogatorProvider);

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Summary header
          _InterrogatorSummary(state: state),
          Divider(height: 1, color: colorScheme.outlineVariant),
          // Controls
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Drop zone
                _ImageDropZone(),
                const SizedBox(height: 16),
                // Model selector
                _ModelSelector(),
                const SizedBox(height: 16),
                // Added images list
                if (state.images.isNotEmpty) ...[
                  _ImagesList(),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          // Interrogate button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: state.isInterrogating
                  ? _InterrogationProgress()
                  : FilledButton.icon(
                      onPressed: state.images.isEmpty
                          ? null
                          : () => ref
                              .read(interrogatorProvider.notifier)
                              .interrogateAll(),
                      icon: const Icon(Icons.psychology),
                      label: Text(
                        state.images.isEmpty
                            ? 'Add images to interrogate'
                            : 'Interrogate ${state.images.length} Image${state.images.length > 1 ? 's' : ''}',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary header showing status
class _InterrogatorSummary extends StatelessWidget {
  final InterrogatorState state;

  const _InterrogatorSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        children: [
          Icon(Icons.psychology, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.images.length} Image${state.images.length != 1 ? 's' : ''} Added',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  state.images.isEmpty
                      ? 'Drop images or click to add'
                      : '${state.completedCount}/${state.images.length} interrogated',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Chip(
            label: Text(
              state.selectedModel,
              style: const TextStyle(fontSize: 11),
            ),
            avatar: const Icon(Icons.smart_toy, size: 16),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Image drop zone widget
class _ImageDropZone extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ImageDropZone> createState() => _ImageDropZoneState();
}

class _ImageDropZoneState extends ConsumerState<_ImageDropZone> {
  bool _isDragHovering = false;
  bool _isLoading = false;

  Future<void> _handleFilesDrop(DropDoneDetails details) async {
    final files = details.files;
    if (files.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isDragHovering = false;
    });

    try {
      final notifier = ref.read(interrogatorProvider.notifier);
      for (final xFile in files) {
        final bytes = await xFile.readAsBytes();
        if (_isValidImage(bytes)) {
          notifier.addImage(InterrogatorImage(
            bytes: bytes,
            filename: xFile.name,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load images: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isValidImage(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) return true;
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // WebP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) return true;
    return false;
  }

  Future<void> _pickImages() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        final notifier = ref.read(interrogatorProvider.notifier);
        for (final file in result.files) {
          if (file.path != null) {
            final bytes = await File(file.path!).readAsBytes();
            notifier.addImage(InterrogatorImage(
              bytes: bytes,
              filename: file.name,
            ));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick images: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: DropTarget(
        onDragEntered: (details) => setState(() => _isDragHovering = true),
        onDragExited: (details) => setState(() => _isDragHovering = false),
        onDragDone: _handleFilesDrop,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isDragHovering
                ? colorScheme.primary.withOpacity(0.1)
                : colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  _isDragHovering ? colorScheme.primary : colorScheme.outline,
              width: _isDragHovering ? 2 : 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: InkWell(
            onTap: _isLoading ? null : _pickImages,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 140,
              padding: const EdgeInsets.all(16),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 32,
                              color: _isDragHovering
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.upload_file,
                              size: 24,
                              color: colorScheme.onSurfaceVariant
                                  .withOpacity(0.7),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Drop images here or click to browse',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _isDragHovering
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PNG, JPG, WebP supported - Multiple images allowed',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                colorScheme.onSurfaceVariant.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Model selector dropdown
class _ModelSelector extends ConsumerWidget {
  static const List<String> _models = [
    'CLIP',
    'BLIP',
    'BLIP2',
    'WD14 ViT',
    'WD14 ConvNext',
    'WD14 SwinV2',
    'DeepBooru',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(interrogatorProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Interrogation Model',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: state.selectedModel,
              decoration: const InputDecoration(
                labelText: 'Model',
                isDense: true,
              ),
              items: _models.map((model) {
                return DropdownMenuItem(
                  value: model,
                  child: Row(
                    children: [
                      Icon(
                        _getModelIcon(model),
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(model),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(interrogatorProvider.notifier).setModel(value);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              _getModelDescription(state.selectedModel),
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getModelIcon(String model) {
    if (model.contains('CLIP')) return Icons.search;
    if (model.contains('BLIP')) return Icons.description;
    if (model.contains('WD14')) return Icons.label;
    if (model.contains('DeepBooru')) return Icons.tag;
    return Icons.psychology;
  }

  String _getModelDescription(String model) {
    switch (model) {
      case 'CLIP':
        return 'Natural language captions using OpenAI CLIP';
      case 'BLIP':
        return 'Descriptive captions using BLIP model';
      case 'BLIP2':
        return 'Enhanced captions using BLIP-2 model';
      case 'WD14 ViT':
        return 'Anime-style tags using Vision Transformer';
      case 'WD14 ConvNext':
        return 'Anime-style tags using ConvNext architecture';
      case 'WD14 SwinV2':
        return 'Anime-style tags using Swin Transformer V2';
      case 'DeepBooru':
        return 'Booru-style tags for anime/illustration content';
      default:
        return 'Generate tags and captions from images';
    }
  }
}

/// List of added images
class _ImagesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(interrogatorProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Added Images',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${state.images.length} image${state.images.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: state.images.length,
                itemBuilder: (context, index) {
                  final image = state.images[index];
                  return Padding(
                    padding: EdgeInsets.only(
                        right: index < state.images.length - 1 ? 8 : 0),
                    child: _ImageThumbnail(
                      image: image,
                      onRemove: () => ref
                          .read(interrogatorProvider.notifier)
                          .removeImage(index),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Image thumbnail with remove button
class _ImageThumbnail extends StatelessWidget {
  final InterrogatorImage image;
  final VoidCallback onRemove;

  const _ImageThumbnail({
    required this.image,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: image.result != null
                  ? colorScheme.primary
                  : colorScheme.outline,
              width: image.result != null ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.memory(
              image.bytes,
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Status indicator
        if (image.isProcessing)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          )
        else if (image.result != null)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
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
        // Remove button
        Positioned(
          top: 2,
          right: 2,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Interrogation progress indicator
class _InterrogationProgress extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(interrogatorProvider);

    return Column(
      children: [
        LinearProgressIndicator(
          value: state.progress,
          backgroundColor: colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 8),
        Text(
          '${state.completedCount}/${state.images.length} images processed',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => ref.read(interrogatorProvider.notifier).cancel(),
          icon: const Icon(Icons.stop),
          label: const Text('Cancel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.error,
            side: BorderSide(color: colorScheme.error),
          ),
        ),
      ],
    );
  }
}

/// Results panel showing interrogation results
class _ResultsPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(interrogatorProvider);
    final resultsWithData =
        state.images.where((img) => img.result != null).toList();

    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: resultsWithData.isEmpty
          ? _buildEmptyState(context, colorScheme, state.images.isNotEmpty)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: resultsWithData.length,
              itemBuilder: (context, index) {
                final image = resultsWithData[index];
                return Padding(
                  padding:
                      EdgeInsets.only(bottom: index < resultsWithData.length - 1 ? 16 : 0),
                  child: _ResultCard(image: image),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, ColorScheme colorScheme, bool hasImages) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasImages ? Icons.psychology_outlined : Icons.image_search_outlined,
            size: 64,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            hasImages
                ? 'Click "Interrogate" to analyze images'
                : 'Add images to interrogate',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasImages
                ? 'Results will appear here'
                : 'Drop images or use the browse button',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Result card for a single image
class _ResultCard extends ConsumerWidget {
  final InterrogatorImage image;

  const _ResultCard({required this.image});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview and info header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    image.bytes,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                // Info and actions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        image.filename,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Model: ${image.modelUsed ?? "Unknown"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Action buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ActionButton(
                            icon: Icons.copy,
                            label: 'Copy',
                            onPressed: () => _copyToClipboard(context, image.result!),
                          ),
                          _ActionButton(
                            icon: Icons.send,
                            label: 'Send to Prompt',
                            onPressed: () => _sendToPrompt(context, ref, image.result!),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Result text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: SelectableText(
                image.result ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _sendToPrompt(BuildContext context, WidgetRef ref, String text) {
    final currentPrompt = ref.read(generationParamsProvider).prompt;
    final newPrompt = currentPrompt.isEmpty ? text : '$currentPrompt, $text';
    ref.read(generationParamsProvider.notifier).setPrompt(newPrompt);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to prompt'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Small action button
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ============================================================================
// State Management
// ============================================================================

/// Interrogator state provider
final interrogatorProvider =
    StateNotifierProvider<InterrogatorNotifier, InterrogatorState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final session = ref.watch(sessionProvider);
  return InterrogatorNotifier(apiService, session);
});

/// Single image for interrogation
class InterrogatorImage {
  final Uint8List bytes;
  final String filename;
  final String? result;
  final String? modelUsed;
  final bool isProcessing;
  final String? error;

  const InterrogatorImage({
    required this.bytes,
    required this.filename,
    this.result,
    this.modelUsed,
    this.isProcessing = false,
    this.error,
  });

  InterrogatorImage copyWith({
    Uint8List? bytes,
    String? filename,
    String? result,
    String? modelUsed,
    bool? isProcessing,
    String? error,
  }) {
    return InterrogatorImage(
      bytes: bytes ?? this.bytes,
      filename: filename ?? this.filename,
      result: result ?? this.result,
      modelUsed: modelUsed ?? this.modelUsed,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
    );
  }
}

/// Interrogator state
class InterrogatorState {
  final List<InterrogatorImage> images;
  final String selectedModel;
  final bool isInterrogating;
  final bool isCancelled;
  final String? error;

  const InterrogatorState({
    this.images = const [],
    this.selectedModel = 'CLIP',
    this.isInterrogating = false,
    this.isCancelled = false,
    this.error,
  });

  InterrogatorState copyWith({
    List<InterrogatorImage>? images,
    String? selectedModel,
    bool? isInterrogating,
    bool? isCancelled,
    String? error,
  }) {
    return InterrogatorState(
      images: images ?? this.images,
      selectedModel: selectedModel ?? this.selectedModel,
      isInterrogating: isInterrogating ?? this.isInterrogating,
      isCancelled: isCancelled ?? this.isCancelled,
      error: error,
    );
  }

  int get completedCount =>
      images.where((img) => img.result != null && !img.isProcessing).length;

  double get progress =>
      images.isEmpty ? 0.0 : completedCount / images.length;
}

/// Interrogator state notifier
class InterrogatorNotifier extends StateNotifier<InterrogatorState> {
  final ApiService _apiService;
  final SessionState _session;
  bool _shouldCancel = false;

  InterrogatorNotifier(this._apiService, this._session)
      : super(const InterrogatorState());

  /// Add an image to interrogate
  void addImage(InterrogatorImage image) {
    state = state.copyWith(
      images: [...state.images, image],
    );
  }

  /// Remove an image
  void removeImage(int index) {
    if (index < 0 || index >= state.images.length) return;
    final newImages = List<InterrogatorImage>.from(state.images);
    newImages.removeAt(index);
    state = state.copyWith(images: newImages);
  }

  /// Set the interrogation model
  void setModel(String model) {
    state = state.copyWith(selectedModel: model);
  }

  /// Clear all images and results
  void clearAll() {
    _shouldCancel = true;
    state = const InterrogatorState();
  }

  /// Cancel interrogation
  void cancel() {
    _shouldCancel = true;
    state = state.copyWith(
      isInterrogating: false,
      isCancelled: true,
    );
  }

  /// Interrogate all images
  Future<void> interrogateAll() async {
    if (state.images.isEmpty) return;
    if (_session.sessionId == null) {
      state = state.copyWith(error: 'Not connected');
      return;
    }

    _shouldCancel = false;
    state = state.copyWith(
      isInterrogating: true,
      isCancelled: false,
      error: null,
    );

    // Process each image
    for (int i = 0; i < state.images.length && !_shouldCancel; i++) {
      final image = state.images[i];

      // Skip if already has result
      if (image.result != null) continue;

      // Mark as processing
      _updateImage(i, (img) => img.copyWith(isProcessing: true));

      try {
        final result = await _interrogateSingle(image);

        if (result != null) {
          _updateImage(i, (img) => img.copyWith(
            isProcessing: false,
            result: result,
            modelUsed: state.selectedModel,
          ));
        } else {
          _updateImage(i, (img) => img.copyWith(
            isProcessing: false,
            error: 'Interrogation failed',
          ));
        }
      } catch (e) {
        _updateImage(i, (img) => img.copyWith(
          isProcessing: false,
          error: e.toString(),
        ));
      }
    }

    state = state.copyWith(
      isInterrogating: false,
      isCancelled: _shouldCancel,
    );
  }

  /// Interrogate a single image
  Future<String?> _interrogateSingle(InterrogatorImage image) async {
    try {
      // Convert image to base64
      final base64Image = base64Encode(image.bytes);

      final response = await _apiService.post<Map<String, dynamic>>(
        '/API/Interrogate',
        data: {
          'session_id': _session.sessionId,
          'image': 'data:image/png;base64,$base64Image',
          'model': state.selectedModel,
        },
      );

      if (!response.isSuccess || response.data == null) {
        return null;
      }

      final data = response.data!;

      // Handle different response formats
      if (data.containsKey('result')) {
        return data['result'] as String?;
      } else if (data.containsKey('caption')) {
        return data['caption'] as String?;
      } else if (data.containsKey('tags')) {
        final tags = data['tags'];
        if (tags is List) {
          return tags.join(', ');
        } else if (tags is String) {
          return tags;
        }
      } else if (data.containsKey('output')) {
        return data['output'] as String?;
      }

      // If none of the expected keys, try to get any string value
      for (final value in data.values) {
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update a single image in the list
  void _updateImage(int index, InterrogatorImage Function(InterrogatorImage) transform) {
    if (index < 0 || index >= state.images.length) return;
    final newImages = List<InterrogatorImage>.from(state.images);
    newImages[index] = transform(newImages[index]);
    state = state.copyWith(images: newImages);
  }
}
