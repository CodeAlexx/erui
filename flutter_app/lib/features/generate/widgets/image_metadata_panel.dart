import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/selected_image_provider.dart';
import '../../../providers/providers.dart';

/// Image metadata panel - shows when an image is selected (SwarmUI style)
class ImageMetadataPanel extends ConsumerWidget {
  const ImageMetadataPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedState = ref.watch(selectedImageProvider);

    if (!selectedState.hasImage) {
      return const SizedBox.shrink();
    }

    final metadata = selectedState.metadata;
    final imageUrl = selectedState.displayUrl;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // Image preview with action buttons overlay
          _ImagePreviewSection(imageUrl: imageUrl, metadata: metadata),

          // Metadata content (scrollable)
          Expanded(
            child: selectedState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : metadata != null
                    ? _MetadataContent(metadata: metadata)
                    : Center(
                        child: Text(
                          'No metadata available',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Image preview section with action buttons
class _ImagePreviewSection extends ConsumerWidget {
  final String? imageUrl;
  final ImageMetadata? metadata;

  const _ImagePreviewSection({this.imageUrl, this.metadata});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // SwarmUI-style orange button color
    const buttonColor = Color(0xFFE6A83C);
    const buttonTextColor = Color(0xFF1A1A1A);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // Action buttons row (SwarmUI style)
          Container(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _ActionButton(
                  label: 'Use As Init',
                  color: buttonColor,
                  textColor: buttonTextColor,
                  onTap: () => _useAsInit(context, ref),
                ),
                _ActionButton(
                  label: 'Edit Image',
                  color: buttonColor,
                  textColor: buttonTextColor,
                  onTap: () => _editImage(context),
                ),
                _ActionButton(
                  label: 'Star',
                  color: buttonColor,
                  textColor: buttonTextColor,
                  onTap: () => _starImage(context, ref),
                ),
                _ActionButton(
                  label: 'Reuse Parameters',
                  color: buttonColor,
                  textColor: buttonTextColor,
                  onTap: () => _reuseParameters(context, ref),
                ),
                _MoreButton(imageUrl: imageUrl),
              ],
            ),
          ),

          // Small image preview
          if (imageUrl != null)
            Container(
              height: 150,
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.broken_image, color: colorScheme.error),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _useAsInit(BuildContext context, WidgetRef ref) {
    // TODO: Implement use as init image
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Use As Init - Coming soon')),
    );
  }

  void _editImage(BuildContext context) {
    // TODO: Implement edit image
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit Image - Coming soon')),
    );
  }

  void _starImage(BuildContext context, WidgetRef ref) {
    // TODO: Implement star image
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Star - Coming soon')),
    );
  }

  void _reuseParameters(BuildContext context, WidgetRef ref) {
    if (metadata == null) return;

    final params = ref.read(generationParamsProvider.notifier);

    if (metadata!.prompt != null) params.setPrompt(metadata!.prompt!);
    if (metadata!.negativePrompt != null) params.setNegativePrompt(metadata!.negativePrompt!);
    if (metadata!.model != null) params.setModel(metadata!.model!);
    if (metadata!.width != null) params.setWidth(metadata!.width!);
    if (metadata!.height != null) params.setHeight(metadata!.height!);
    if (metadata!.steps != null) params.setSteps(metadata!.steps!);
    if (metadata!.cfgScale != null) params.setCfgScale(metadata!.cfgScale!);
    if (metadata!.seed != null) params.setSeed(metadata!.seed!);
    if (metadata!.sampler != null) params.setSampler(metadata!.sampler!);
    if (metadata!.scheduler != null) params.setScheduler(metadata!.scheduler!);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Parameters loaded')),
    );
  }
}

/// Action button (SwarmUI style)
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// More dropdown button
class _MoreButton extends StatelessWidget {
  final String? imageUrl;

  const _MoreButton({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    const buttonColor = Color(0xFFE6A83C);
    const buttonTextColor = Color(0xFF1A1A1A);

    return PopupMenuButton<String>(
      tooltip: 'More options',
      onSelected: (value) => _handleMenuAction(context, value),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'use_prompt', child: Text('Use As Image Prompt')),
        const PopupMenuItem(value: 'upscale', child: Text('Upscale 2x')),
        const PopupMenuItem(value: 'refine', child: Text('Refine Image')),
        const PopupMenuItem(value: 'view_history', child: Text('View In History')),
        const PopupMenuItem(value: 'copy_metadata', child: Text('Copy Raw Metadata')),
        const PopupMenuItem(value: 'open_folder', child: Text('Open In Folder')),
        const PopupMenuItem(value: 'download', child: Text('Download')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'More',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: buttonTextColor),
            ),
            Icon(Icons.arrow_drop_down, size: 16, color: buttonTextColor),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action - Coming soon')),
    );
  }
}

/// Metadata content (SwarmUI style - single line key:value)
class _MetadataContent extends StatelessWidget {
  final ImageMetadata metadata;

  const _MetadataContent({required this.metadata});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // Prompt section
        if (metadata.prompt != null && metadata.prompt!.isNotEmpty) ...[
          _MetadataLabel('Prompt:'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              metadata.prompt!,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
            ),
          ),
        ],

        // Key-value pairs (single line each like SwarmUI)
        if (metadata.model != null) _MetadataRow('Model:', _formatModel(metadata.model!)),
        if (metadata.images != null) _MetadataRow('Images:', metadata.images.toString()),
        if (metadata.resolution != null) _MetadataRow('Resolution:', metadata.resolution!),
        if (metadata.seed != null) _MetadataRow('Seed:', metadata.seed.toString()),
        if (metadata.steps != null) _MetadataRow('Steps:', metadata.steps.toString()),
        if (metadata.cfgScale != null) _MetadataRow('CFG Scale:', metadata.cfgScale!.toStringAsFixed(1)),
        if (metadata.sampler != null) _MetadataRow('Sampler:', metadata.sampler!),
        if (metadata.scheduler != null) _MetadataRow('Scheduler:', metadata.scheduler!),
        if (metadata.vae != null) _MetadataRow('VAE:', metadata.vae!),

        // LoRAs section
        if (metadata.loras != null && metadata.loras!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _MetadataLabel('LoRAs:'),
          ...metadata.loras!.map((lora) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Text(
              '${lora.displayName} @ ${lora.weight.toStringAsFixed(1)}',
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
          )),
        ],

        // Extra data
        if (metadata.date != null || metadata.prepTime != null || metadata.genTime != null) ...[
          const SizedBox(height: 8),
          const Divider(),
          if (metadata.date != null) _MetadataRow('Date:', metadata.date!),
          if (metadata.prepTime != null) _MetadataRow('Prep Time:', metadata.prepTime!),
          if (metadata.genTime != null) _MetadataRow('Gen Time:', metadata.genTime!),
        ],

        // Negative prompt (collapsed by default)
        if (metadata.negativePrompt != null && metadata.negativePrompt!.isNotEmpty) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            title: Text('Negative Prompt', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  metadata.negativePrompt!,
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatModel(String model) {
    // Remove path and extension for cleaner display
    final name = model.split('/').last.replaceAll('.safetensors', '');
    return name.length > 30 ? '${name.substring(0, 30)}...' : name;
  }
}

/// Metadata section label
class _MetadataLabel extends StatelessWidget {
  final String text;

  const _MetadataLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Single-line metadata row (SwarmUI style)
class _MetadataRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetadataRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontSize: 11, color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
