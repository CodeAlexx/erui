import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/providers.dart';

/// Generation history panel
class GenerationHistoryPanel extends ConsumerWidget {
  const GenerationHistoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final history = ref.watch(generationHistoryProvider);
    final generationState = ref.watch(generationProvider);

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.history, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (history.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () {
                      _showClearDialog(context, ref);
                    },
                    tooltip: 'Clear history',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Current generation images
          if (generationState.generatedImages.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Current Batch',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                    ),
                  ),
                  ...generationState.generatedImages.map((url) {
                    return _HistoryThumbnail(
                      imageUrl: url,
                      onTap: () {
                        // TODO: Show full image
                      },
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          // History items
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No history yet',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final image = history[index];
                      return _HistoryThumbnail(
                        imageUrl: image.url,
                        prompt: image.prompt,
                        onTap: () {
                          // Load parameters from history
                          ref.read(generationParamsProvider.notifier)
                            ..setPrompt(image.prompt)
                            ..setNegativePrompt(image.negativePrompt ?? '')
                            ..setWidth(image.params.width)
                            ..setHeight(image.params.height)
                            ..setSteps(image.params.steps)
                            ..setCfgScale(image.params.cfgScale)
                            ..setSeed(image.params.seed)
                            ..setSampler(image.params.sampler)
                            ..setScheduler(image.params.scheduler);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(generationHistoryProvider.notifier).clear();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _HistoryThumbnail extends StatelessWidget {
  final String imageUrl;
  final String? prompt;
  final VoidCallback? onTap;

  const _HistoryThumbnail({
    required this.imageUrl,
    this.prompt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colorScheme.error,
                  ),
                ),
              ),
            ),
            if (prompt != null && prompt!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  prompt!,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
