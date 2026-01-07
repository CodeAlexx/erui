import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/providers.dart';

/// Model details dialog
class ModelDetailsDialog extends ConsumerWidget {
  final ModelInfo model;

  const ModelDetailsDialog({
    super.key,
    required this.model,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.view_in_ar,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      model.displayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preview image
                    if (model.previewUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: CachedNetworkImage(
                            imageUrl: model.previewUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image_not_supported,
                                size: 48,
                                color: colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Model info sections
                    _InfoSection(
                      title: 'Basic Information',
                      items: [
                        _InfoItem(label: 'Name', value: model.name),
                        _InfoItem(label: 'Type', value: model.type),
                        if (model.modelClass != null)
                          _InfoItem(label: 'Model Class', value: model.modelClass!),
                        _InfoItem(label: 'Size', value: model.formattedSize),
                        _InfoItem(label: 'Path', value: model.path),
                      ],
                    ),
                    if (model.hash != null) ...[
                      const SizedBox(height: 16),
                      _InfoSection(
                        title: 'Hash',
                        items: [
                          _InfoItem(
                            label: 'SHA256',
                            value: model.hash!,
                            copyable: true,
                          ),
                        ],
                      ),
                    ],
                    if (model.metadata != null &&
                        model.metadata!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _InfoSection(
                        title: 'Metadata',
                        items: model.metadata!.entries
                            .map((e) => _InfoItem(
                                  label: e.key,
                                  value: e.value.toString(),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: model.name));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Model name copied to clipboard'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Name'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(selectedModelProvider.notifier).state = model;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Selected ${model.displayName}'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Select Model'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<_InfoItem> items;

  const _InfoSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: items
                .map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: item,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;

  const _InfoItem({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        if (copyable)
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Copy',
          ),
      ],
    );
  }
}
