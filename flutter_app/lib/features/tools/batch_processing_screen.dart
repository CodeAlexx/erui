import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import '../../providers/generation_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/comfyui_service.dart';
import '../../services/comfyui_workflow_builder.dart';
import '../../widgets/image_viewer_dialog.dart';

/// Batch Processing Screen
///
/// Allows users to batch process multiple prompts and/or init images.
/// Import prompts from text file, init images from folder, configure base params,
/// manage queue, and export results.
class BatchProcessingScreen extends ConsumerStatefulWidget {
  final VoidCallback? onCollapse;
  const BatchProcessingScreen({super.key, this.onCollapse});

  @override
  ConsumerState<BatchProcessingScreen> createState() => _BatchProcessingScreenState();
}

class _BatchProcessingScreenState extends ConsumerState<BatchProcessingScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final batchState = ref.watch(batchProcessingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Processing'),
        actions: [
          // Reset button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: () => ref.read(batchProcessingProvider.notifier).reset(),
          ),
          // Collapse button
          if (widget.onCollapse != null)
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Collapse panel',
              onPressed: widget.onCollapse,
            ),
        ],
      ),
      body: Row(
        children: [
          // Left side - Configuration
          SizedBox(
            width: 420,
            child: _ConfigurationPanel(),
          ),
          VerticalDivider(width: 1, color: colorScheme.outlineVariant),
          // Right side - Results
          Expanded(
            child: batchState.isProcessing || batchState.results.isNotEmpty
                ? _ResultsPanel()
                : _EmptyStatePanel(),
          ),
        ],
      ),
    );
  }
}

/// Configuration panel for batch processing setup
class _ConfigurationPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final batchState = ref.watch(batchProcessingProvider);
    final baseParams = ref.watch(generationParamsProvider);

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Summary
          _BatchSummary(state: batchState),
          Divider(height: 1, color: colorScheme.outlineVariant),
          // Configuration
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Prompts import
                _PromptsImportCard(),
                const SizedBox(height: 16),
                // Init images import
                _InitImagesImportCard(),
                const SizedBox(height: 16),
                // Processing mode
                _ProcessingModeCard(),
                const SizedBox(height: 16),
                // Output configuration
                _OutputConfigCard(),
              ],
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: batchState.isProcessing
                  ? _ProcessingControls()
                  : FilledButton.icon(
                      onPressed: batchState.canStart
                          ? () => ref.read(batchProcessingProvider.notifier)
                              .startProcessing(baseParams)
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        batchState.canStart
                            ? 'Process ${batchState.totalItems} Items'
                            : 'Import prompts or images to start',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary showing batch configuration
class _BatchSummary extends StatelessWidget {
  final BatchProcessingState state;

  const _BatchSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        children: [
          Icon(Icons.batch_prediction, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batch: ${state.prompts.length} prompts, ${state.initImages.length} images',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  state.canStart
                      ? '${state.totalItems} items to process (${state.processingMode.displayName})'
                      : 'Import prompts or init images to begin',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (state.canStart)
            Text(
              'Est. ${_formatDuration(state.estimatedTime)}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }
}

/// Card for importing prompts from text file
class _PromptsImportCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final batchState = ref.watch(batchProcessingProvider);
    final prompts = batchState.prompts;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_snippet, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Prompts',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${prompts.length} loaded',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _importPromptsFromFile(ref),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Import from File'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showManualPromptDialog(context, ref),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Manual Entry'),
                  ),
                ),
              ],
            ),
            if (prompts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: prompts.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Text(
                        prompts[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => ref
                            .read(batchProcessingProvider.notifier)
                            .removePrompt(index),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () =>
                    ref.read(batchProcessingProvider.notifier).clearPrompts(),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _importPromptsFromFile(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      final prompts = content
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('#'))
          .toList();

      ref.read(batchProcessingProvider.notifier).setPrompts(prompts);
    }
  }

  void _showManualPromptDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Prompts'),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Enter one prompt per line...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final prompts = controller.text
                  .split('\n')
                  .map((line) => line.trim())
                  .where((line) => line.isNotEmpty)
                  .toList();
              ref.read(batchProcessingProvider.notifier).addPrompts(prompts);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

/// Card for importing init images from folder
class _InitImagesImportCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final batchState = ref.watch(batchProcessingProvider);
    final initImages = batchState.initImages;

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
                  'Init Images',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${initImages.length} loaded',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _importFromFolder(ref),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Import Folder'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _importFiles(ref),
                    icon: const Icon(Icons.add_photo_alternate, size: 18),
                    label: const Text('Select Files'),
                  ),
                ),
              ],
            ),
            if (initImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: initImages.length,
                  itemBuilder: (context, index) {
                    final imagePath = initImages[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colorScheme.outline),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.file(
                                File(imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => ref
                                  .read(batchProcessingProvider.notifier)
                                  .removeInitImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 12,
                                  color: colorScheme.onError,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () =>
                    ref.read(batchProcessingProvider.notifier).clearInitImages(),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _importFromFolder(WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath();

    if (result != null) {
      final dir = Directory(result);
      final imageExtensions = ['.png', '.jpg', '.jpeg', '.webp', '.gif'];
      final images = dir
          .listSync()
          .whereType<File>()
          .where((file) =>
              imageExtensions.contains(path.extension(file.path).toLowerCase()))
          .map((file) => file.path)
          .toList();

      images.sort();
      ref.read(batchProcessingProvider.notifier).setInitImages(images);
    }
  }

  Future<void> _importFiles(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
      ref.read(batchProcessingProvider.notifier).addInitImages(paths);
    }
  }
}

/// Card for selecting processing mode
class _ProcessingModeCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final batchState = ref.watch(batchProcessingProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Processing Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<BatchProcessingMode>(
              segments: BatchProcessingMode.values.map((mode) {
                return ButtonSegment(
                  value: mode,
                  label: Text(mode.displayName),
                  icon: Icon(mode.icon),
                );
              }).toList(),
              selected: {batchState.processingMode},
              onSelectionChanged: (selected) {
                ref
                    .read(batchProcessingProvider.notifier)
                    .setProcessingMode(selected.first);
              },
            ),
            const SizedBox(height: 8),
            Text(
              batchState.processingMode.description,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card for output configuration
class _OutputConfigCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_OutputConfigCard> createState() => _OutputConfigCardState();
}

class _OutputConfigCardState extends ConsumerState<_OutputConfigCard> {
  final _folderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _folderController.text = ref.read(batchProcessingProvider).outputFolder ?? '';
  }

  @override
  void dispose() {
    _folderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final batchState = ref.watch(batchProcessingProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.save_alt, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Output',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _folderController,
                    decoration: const InputDecoration(
                      labelText: 'Export Folder',
                      hintText: 'Leave empty to use default',
                      isDense: true,
                    ),
                    onChanged: (value) {
                      ref
                          .read(batchProcessingProvider.notifier)
                          .setOutputFolder(value.isEmpty ? null : value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: () async {
                    final result = await FilePicker.platform.getDirectoryPath();
                    if (result != null) {
                      _folderController.text = result;
                      ref
                          .read(batchProcessingProvider.notifier)
                          .setOutputFolder(result);
                    }
                  },
                  tooltip: 'Browse',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Create subfolder per batch'),
              value: batchState.createSubfolder,
              onChanged: (value) {
                ref
                    .read(batchProcessingProvider.notifier)
                    .setCreateSubfolder(value);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Include prompt in filename'),
              value: batchState.includePromptInFilename,
              onChanged: (value) {
                ref
                    .read(batchProcessingProvider.notifier)
                    .setIncludePromptInFilename(value);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

/// Processing control buttons
class _ProcessingControls extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(batchProcessingProvider);

    return Column(
      children: [
        LinearProgressIndicator(
          value: state.progress,
          backgroundColor: colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 8),
        Text(
          '${state.completedCount} / ${state.totalItems} completed',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        if (state.currentPrompt != null) ...[
          const SizedBox(height: 4),
          Text(
            state.currentPrompt!,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: state.isPaused
                  ? FilledButton.icon(
                      onPressed: () =>
                          ref.read(batchProcessingProvider.notifier).resume(),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Resume'),
                    )
                  : OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(batchProcessingProvider.notifier).pause(),
                      icon: const Icon(Icons.pause),
                      label: const Text('Pause'),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    ref.read(batchProcessingProvider.notifier).cancel(),
                icon: const Icon(Icons.stop),
                label: const Text('Cancel'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Empty state panel
class _EmptyStatePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.batch_prediction_outlined,
              size: 64,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Import prompts or init images to begin',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Results will be shown in a grid',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Results panel showing generated images
class _ResultsPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(batchProcessingProvider);

    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          // Header with progress
          Container(
            padding: const EdgeInsets.all(16),
            color: colorScheme.surfaceContainerHigh,
            child: Row(
              children: [
                if (state.isProcessing)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: state.progress,
                    ),
                  )
                else if (state.isCancelled)
                  Icon(Icons.cancel, color: colorScheme.error)
                else
                  Icon(Icons.check_circle, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.isProcessing
                            ? 'Processing...'
                            : state.isCancelled
                                ? 'Cancelled'
                                : 'Complete',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${state.completedCount}/${state.totalItems} items',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!state.isProcessing) ...[
                  TextButton.icon(
                    onPressed: state.results.any((r) => r.imageUrl != null)
                        ? () => _exportResults(ref, context)
                        : null,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Export'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () =>
                        ref.read(batchProcessingProvider.notifier).reset(),
                    icon: const Icon(Icons.add),
                    label: const Text('New Batch'),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          // Results grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 1.0,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: state.results.length,
              itemBuilder: (context, index) {
                return _ResultCell(result: state.results[index], index: index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportResults(WidgetRef ref, BuildContext context) async {
    final state = ref.read(batchProcessingProvider);
    final completedResults =
        state.results.where((r) => r.imageUrl != null).toList();

    if (completedResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images to export')),
      );
      return;
    }

    final folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null) return;

    // Export logic would go here - download images from URLs to folder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting ${completedResults.length} images to $folderPath'),
      ),
    );

    await ref
        .read(batchProcessingProvider.notifier)
        .exportResults(folderPath);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export complete')),
      );
    }
  }
}

/// Single result cell in the grid
class _ResultCell extends StatelessWidget {
  final BatchProcessingResult result;
  final int index;

  const _ResultCell({required this.result, required this.index});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getBorderColor(colorScheme),
          width: result.status == BatchItemStatus.processing ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          _buildContent(context, colorScheme),
          // Index badge
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBorderColor(ColorScheme colorScheme) {
    switch (result.status) {
      case BatchItemStatus.processing:
        return colorScheme.primary;
      case BatchItemStatus.completed:
        return colorScheme.outline;
      case BatchItemStatus.failed:
        return colorScheme.error;
      case BatchItemStatus.cancelled:
        return colorScheme.outline;
      case BatchItemStatus.pending:
        return colorScheme.outlineVariant;
    }
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    switch (result.status) {
      case BatchItemStatus.pending:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hourglass_empty,
                color: colorScheme.outlineVariant,
                size: 24,
              ),
              const SizedBox(height: 4),
              if (result.prompt != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    result.prompt!,
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      case BatchItemStatus.processing:
        return const Center(
          child: CircularProgressIndicator(),
        );
      case BatchItemStatus.completed:
        if (result.imageUrl != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: GestureDetector(
              onTap: () =>
                  ImageViewerDialog.show(context, imageUrl: result.imageUrl!),
              child: Image.network(
                result.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stack) => Center(
                  child: Icon(
                    Icons.broken_image,
                    color: colorScheme.error,
                  ),
                ),
              ),
            ),
          );
        }
        return Center(
          child: Icon(
            Icons.check,
            color: colorScheme.primary,
          ),
        );
      case BatchItemStatus.failed:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error),
              if (result.error != null)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    result.error!,
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      case BatchItemStatus.cancelled:
        return Center(
          child: Icon(
            Icons.cancel_outlined,
            color: colorScheme.outline,
          ),
        );
    }
  }
}

// ============================================================================
// State Management
// ============================================================================

/// Batch processing state provider
final batchProcessingProvider =
    StateNotifierProvider<BatchProcessingNotifier, BatchProcessingState>((ref) {
  final comfyService = ref.watch(comfyUIServiceProvider);
  final session = ref.watch(sessionProvider);
  return BatchProcessingNotifier(comfyService, session);
});

/// Processing mode
enum BatchProcessingMode {
  promptsOnly,
  imagesOnly,
  promptsWithImages,
  allCombinations;

  String get displayName {
    switch (this) {
      case BatchProcessingMode.promptsOnly:
        return 'Prompts';
      case BatchProcessingMode.imagesOnly:
        return 'Images';
      case BatchProcessingMode.promptsWithImages:
        return 'Paired';
      case BatchProcessingMode.allCombinations:
        return 'All Combos';
    }
  }

  String get description {
    switch (this) {
      case BatchProcessingMode.promptsOnly:
        return 'Generate one image per prompt';
      case BatchProcessingMode.imagesOnly:
        return 'Process each init image with base prompt';
      case BatchProcessingMode.promptsWithImages:
        return 'Pair prompts with images (1:1)';
      case BatchProcessingMode.allCombinations:
        return 'Every prompt with every image';
    }
  }

  IconData get icon {
    switch (this) {
      case BatchProcessingMode.promptsOnly:
        return Icons.text_snippet;
      case BatchProcessingMode.imagesOnly:
        return Icons.photo_library;
      case BatchProcessingMode.promptsWithImages:
        return Icons.link;
      case BatchProcessingMode.allCombinations:
        return Icons.grid_view;
    }
  }
}

/// Status of a batch result
enum BatchItemStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

/// Result for a single batch item
class BatchProcessingResult {
  final String? prompt;
  final String? initImagePath;
  final BatchItemStatus status;
  final String? imageUrl;
  final String? error;

  const BatchProcessingResult({
    this.prompt,
    this.initImagePath,
    this.status = BatchItemStatus.pending,
    this.imageUrl,
    this.error,
  });

  BatchProcessingResult copyWith({
    String? prompt,
    String? initImagePath,
    BatchItemStatus? status,
    String? imageUrl,
    String? error,
  }) {
    return BatchProcessingResult(
      prompt: prompt ?? this.prompt,
      initImagePath: initImagePath ?? this.initImagePath,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      error: error ?? this.error,
    );
  }
}

/// State for batch processing
class BatchProcessingState {
  final List<String> prompts;
  final List<String> initImages;
  final BatchProcessingMode processingMode;
  final String? outputFolder;
  final bool createSubfolder;
  final bool includePromptInFilename;
  final List<BatchProcessingResult> results;
  final int currentIndex;
  final bool isProcessing;
  final bool isPaused;
  final bool isCancelled;
  final String? error;
  final String? currentPrompt;

  const BatchProcessingState({
    this.prompts = const [],
    this.initImages = const [],
    this.processingMode = BatchProcessingMode.promptsOnly,
    this.outputFolder,
    this.createSubfolder = true,
    this.includePromptInFilename = false,
    this.results = const [],
    this.currentIndex = 0,
    this.isProcessing = false,
    this.isPaused = false,
    this.isCancelled = false,
    this.error,
    this.currentPrompt,
  });

  BatchProcessingState copyWith({
    List<String>? prompts,
    List<String>? initImages,
    BatchProcessingMode? processingMode,
    String? outputFolder,
    bool? createSubfolder,
    bool? includePromptInFilename,
    List<BatchProcessingResult>? results,
    int? currentIndex,
    bool? isProcessing,
    bool? isPaused,
    bool? isCancelled,
    String? error,
    String? currentPrompt,
  }) {
    return BatchProcessingState(
      prompts: prompts ?? this.prompts,
      initImages: initImages ?? this.initImages,
      processingMode: processingMode ?? this.processingMode,
      outputFolder: outputFolder ?? this.outputFolder,
      createSubfolder: createSubfolder ?? this.createSubfolder,
      includePromptInFilename: includePromptInFilename ?? this.includePromptInFilename,
      results: results ?? this.results,
      currentIndex: currentIndex ?? this.currentIndex,
      isProcessing: isProcessing ?? this.isProcessing,
      isPaused: isPaused ?? this.isPaused,
      isCancelled: isCancelled ?? this.isCancelled,
      error: error,
      currentPrompt: currentPrompt,
    );
  }

  /// Calculate total items based on mode
  int get totalItems {
    switch (processingMode) {
      case BatchProcessingMode.promptsOnly:
        return prompts.length;
      case BatchProcessingMode.imagesOnly:
        return initImages.length;
      case BatchProcessingMode.promptsWithImages:
        return prompts.length.clamp(0, initImages.length);
      case BatchProcessingMode.allCombinations:
        if (prompts.isEmpty) return initImages.length;
        if (initImages.isEmpty) return prompts.length;
        return prompts.length * initImages.length;
    }
  }

  /// Check if batch can start
  bool get canStart {
    switch (processingMode) {
      case BatchProcessingMode.promptsOnly:
        return prompts.isNotEmpty;
      case BatchProcessingMode.imagesOnly:
        return initImages.isNotEmpty;
      case BatchProcessingMode.promptsWithImages:
        return prompts.isNotEmpty && initImages.isNotEmpty;
      case BatchProcessingMode.allCombinations:
        return prompts.isNotEmpty || initImages.isNotEmpty;
    }
  }

  int get completedCount =>
      results.where((r) => r.status == BatchItemStatus.completed).length;

  double get progress => totalItems > 0 ? completedCount / totalItems : 0.0;

  Duration get estimatedTime {
    // Estimate 10 seconds per image (can be adjusted)
    return Duration(seconds: totalItems * 10);
  }
}

/// Batch processing state notifier
class BatchProcessingNotifier extends StateNotifier<BatchProcessingState> {
  final ComfyUIService _comfyService;
  final SessionState _session;
  bool _shouldCancel = false;
  String? _currentPromptId;
  GenerationParams? _baseParams;
  StreamSubscription<ComfyProgressUpdate>? _progressSubscription;

  BatchProcessingNotifier(this._comfyService, this._session)
      : super(const BatchProcessingState());

  /// Set prompts
  void setPrompts(List<String> prompts) {
    state = state.copyWith(prompts: prompts);
  }

  /// Add prompts
  void addPrompts(List<String> prompts) {
    state = state.copyWith(prompts: [...state.prompts, ...prompts]);
  }

  /// Remove prompt at index
  void removePrompt(int index) {
    final prompts = List<String>.from(state.prompts);
    prompts.removeAt(index);
    state = state.copyWith(prompts: prompts);
  }

  /// Clear all prompts
  void clearPrompts() {
    state = state.copyWith(prompts: []);
  }

  /// Set init images
  void setInitImages(List<String> images) {
    state = state.copyWith(initImages: images);
  }

  /// Add init images
  void addInitImages(List<String> images) {
    state = state.copyWith(initImages: [...state.initImages, ...images]);
  }

  /// Remove init image at index
  void removeInitImage(int index) {
    final images = List<String>.from(state.initImages);
    images.removeAt(index);
    state = state.copyWith(initImages: images);
  }

  /// Clear all init images
  void clearInitImages() {
    state = state.copyWith(initImages: []);
  }

  /// Set processing mode
  void setProcessingMode(BatchProcessingMode mode) {
    state = state.copyWith(processingMode: mode);
  }

  /// Set output folder
  void setOutputFolder(String? folder) {
    state = state.copyWith(outputFolder: folder);
  }

  /// Set create subfolder
  void setCreateSubfolder(bool value) {
    state = state.copyWith(createSubfolder: value);
  }

  /// Set include prompt in filename
  void setIncludePromptInFilename(bool value) {
    state = state.copyWith(includePromptInFilename: value);
  }

  /// Start batch processing
  Future<void> startProcessing(GenerationParams baseParams) async {
    if (_comfyService.currentConnectionState != ComfyConnectionState.connected) {
      state = state.copyWith(error: 'Not connected to ComfyUI');
      return;
    }

    if (!state.canStart) {
      state = state.copyWith(error: 'Nothing to process');
      return;
    }

    _shouldCancel = false;
    _baseParams = baseParams;

    // Build results list based on mode
    final results = _buildResultsList();

    state = state.copyWith(
      results: results,
      currentIndex: 0,
      isProcessing: true,
      isPaused: false,
      isCancelled: false,
      error: null,
    );

    // Process queue
    await _processQueue(baseParams);
  }

  /// Build results list based on processing mode
  List<BatchProcessingResult> _buildResultsList() {
    final results = <BatchProcessingResult>[];

    switch (state.processingMode) {
      case BatchProcessingMode.promptsOnly:
        for (final prompt in state.prompts) {
          results.add(BatchProcessingResult(prompt: prompt));
        }
        break;

      case BatchProcessingMode.imagesOnly:
        for (final image in state.initImages) {
          results.add(BatchProcessingResult(initImagePath: image));
        }
        break;

      case BatchProcessingMode.promptsWithImages:
        final count = state.prompts.length.clamp(0, state.initImages.length);
        for (int i = 0; i < count; i++) {
          results.add(BatchProcessingResult(
            prompt: state.prompts[i],
            initImagePath: state.initImages[i],
          ));
        }
        break;

      case BatchProcessingMode.allCombinations:
        if (state.prompts.isEmpty) {
          for (final image in state.initImages) {
            results.add(BatchProcessingResult(initImagePath: image));
          }
        } else if (state.initImages.isEmpty) {
          for (final prompt in state.prompts) {
            results.add(BatchProcessingResult(prompt: prompt));
          }
        } else {
          for (final prompt in state.prompts) {
            for (final image in state.initImages) {
              results.add(BatchProcessingResult(
                prompt: prompt,
                initImagePath: image,
              ));
            }
          }
        }
        break;
    }

    return results;
  }

  /// Process the generation queue
  Future<void> _processQueue(GenerationParams baseParams) async {
    while (state.currentIndex < state.results.length &&
        !_shouldCancel &&
        !state.isPaused) {
      final result = state.results[state.currentIndex];

      // Update status to processing
      _updateResultStatus(state.currentIndex, BatchItemStatus.processing);
      state = state.copyWith(currentPrompt: result.prompt ?? baseParams.prompt);

      try {
        final imageUrl = await _generateSingle(baseParams, result);

        if (imageUrl != null) {
          _updateResult(
            state.currentIndex,
            (r) => r.copyWith(
              status: BatchItemStatus.completed,
              imageUrl: imageUrl,
            ),
          );
        } else if (_shouldCancel) {
          _updateResultStatus(state.currentIndex, BatchItemStatus.cancelled);
        } else {
          _updateResult(
            state.currentIndex,
            (r) => r.copyWith(
              status: BatchItemStatus.failed,
              error: 'Generation failed',
            ),
          );
        }
      } catch (e) {
        _updateResult(
          state.currentIndex,
          (r) => r.copyWith(
            status: BatchItemStatus.failed,
            error: e.toString(),
          ),
        );
      }

      // Move to next
      if (!_shouldCancel && !state.isPaused) {
        state = state.copyWith(currentIndex: state.currentIndex + 1);
      }
    }

    // Mark as complete
    if (!state.isPaused) {
      state = state.copyWith(
        isProcessing: false,
        isCancelled: _shouldCancel,
        currentPrompt: null,
      );
    }
  }

  /// Generate a single image using ComfyUI
  Future<String?> _generateSingle(
      GenerationParams baseParams, BatchProcessingResult result) async {
    try {
      final prompt = result.prompt ?? baseParams.prompt;

      // Build init image data if provided
      String? initImageBase64;
      if (result.initImagePath != null) {
        final file = File(result.initImagePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          initImageBase64 = base64Encode(bytes);
        }
      }

      // Build ComfyUI workflow
      final builder = ComfyUIWorkflowBuilder();
      final workflow = builder.buildText2Image(
        model: baseParams.model ?? 'model.safetensors',
        prompt: prompt,
        negativePrompt: baseParams.negativePrompt,
        width: baseParams.width,
        height: baseParams.height,
        steps: baseParams.steps,
        cfg: baseParams.cfgScale,
        seed: baseParams.seed,
        sampler: baseParams.sampler,
        scheduler: baseParams.scheduler,
        initImageBase64: initImageBase64,
        denoise: initImageBase64 != null ? baseParams.initImageCreativity : 1.0,
        filenamePrefix: 'batch',
      );

      // Queue the prompt
      final promptId = await _comfyService.queuePrompt(workflow);
      if (promptId == null) {
        return null;
      }

      _currentPromptId = promptId;

      // Wait for completion via WebSocket progress stream
      return await _waitForCompletion(promptId);
    } catch (e) {
      return null;
    }
  }

  /// Wait for ComfyUI generation to complete
  Future<String?> _waitForCompletion(String promptId) async {
    final completer = Completer<String?>();

    // Listen to progress stream for completion
    _progressSubscription?.cancel();
    _progressSubscription = _comfyService.progressStream.listen((update) {
      if (update.promptId == promptId) {
        if (update.isComplete) {
          _progressSubscription?.cancel();
          if (update.outputImages != null && update.outputImages!.isNotEmpty) {
            if (!completer.isCompleted) {
              completer.complete(update.outputImages!.first);
            }
          } else {
            // Try to get images from history
            _getImagesFromHistory(promptId).then((images) {
              if (!completer.isCompleted) {
                completer.complete(images.isNotEmpty ? images.first : null);
              }
            });
          }
        } else if (update.status == 'error') {
          _progressSubscription?.cancel();
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      }
    });

    // Also listen for errors
    final errorSubscription = _comfyService.errorStream.listen((error) {
      if (error.promptId == promptId) {
        _progressSubscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    });

    // Timeout after 5 minutes
    Future.delayed(const Duration(minutes: 5), () {
      if (!completer.isCompleted) {
        _progressSubscription?.cancel();
        errorSubscription.cancel();
        completer.complete(null);
      }
    });

    // Also check if cancelled
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_shouldCancel) {
        timer.cancel();
        _progressSubscription?.cancel();
        errorSubscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
      if (completer.isCompleted) {
        timer.cancel();
        errorSubscription.cancel();
      }
    });

    return completer.future;
  }

  /// Get images from ComfyUI history
  Future<List<String>> _getImagesFromHistory(String promptId) async {
    return await _comfyService.getOutputImages(promptId);
  }

  /// Update result status
  void _updateResultStatus(int index, BatchItemStatus status) {
    _updateResult(index, (r) => r.copyWith(status: status));
  }

  /// Update result with transformer
  void _updateResult(
      int index, BatchProcessingResult Function(BatchProcessingResult) transform) {
    final results = List<BatchProcessingResult>.from(state.results);
    if (index >= 0 && index < results.length) {
      results[index] = transform(results[index]);
      state = state.copyWith(results: results);
    }
  }

  /// Pause processing
  void pause() {
    state = state.copyWith(isPaused: true);
  }

  /// Resume processing
  Future<void> resume() async {
    if (!state.isPaused || _baseParams == null) return;

    state = state.copyWith(isPaused: false, isProcessing: true);
    await _processQueue(_baseParams!);
  }

  /// Cancel processing
  Future<void> cancel() async {
    _shouldCancel = true;
    _progressSubscription?.cancel();

    // Try to cancel current generation via ComfyUI
    try {
      await _comfyService.interrupt();
    } catch (_) {
      // Ignore cancel errors
    }

    // Mark remaining as cancelled
    final results = List<BatchProcessingResult>.from(state.results);
    for (int i = state.currentIndex; i < results.length; i++) {
      if (results[i].status == BatchItemStatus.pending ||
          results[i].status == BatchItemStatus.processing) {
        results[i] = results[i].copyWith(status: BatchItemStatus.cancelled);
      }
    }

    state = state.copyWith(
      results: results,
      isProcessing: false,
      isCancelled: true,
      currentPrompt: null,
    );
  }

  /// Export results to folder
  Future<void> exportResults(String folderPath) async {
    final completedResults =
        state.results.where((r) => r.imageUrl != null).toList();

    for (int i = 0; i < completedResults.length; i++) {
      final result = completedResults[i];
      if (result.imageUrl == null) continue;

      try {
        // Download image from ComfyUI
        final response = await Dio().get<List<int>>(
          result.imageUrl!,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.data == null) continue;

        // Generate filename
        String filename;
        if (state.includePromptInFilename && result.prompt != null) {
          final safePrompt = result.prompt!
              .replaceAll(RegExp(r'[^\w\s-]'), '')
              .replaceAll(RegExp(r'\s+'), '_')
              .substring(0, 50.clamp(0, result.prompt!.length));
          filename = 'batch_${i + 1}_$safePrompt.png';
        } else {
          filename = 'batch_${i + 1}.png';
        }

        // Save file
        final outputPath = path.join(folderPath, filename);
        final file = File(outputPath);
        await file.writeAsBytes(response.data!);
      } catch (e) {
        // Continue with next file on error
      }
    }
  }

  /// Reset state
  void reset() {
    _shouldCancel = false;
    _currentPromptId = null;
    _baseParams = null;
    _progressSubscription?.cancel();
    state = const BatchProcessingState();
  }
}
