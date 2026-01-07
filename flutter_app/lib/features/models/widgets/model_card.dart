import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/models_provider.dart';

/// Model card widget for grid display
class ModelCard extends StatelessWidget {
  final ModelInfo model;
  final VoidCallback? onTap;
  final VoidCallback? onSelect;

  const ModelCard({
    super.key,
    required this.model,
    this.onTap,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview image
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPreviewImage(context),
                  // Model class badge
                  if (model.modelClass != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getClassColor(model.modelClass!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          model.modelClass!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Model info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            model.type,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          model.formattedSize,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Select button
                    if (onSelect != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: onSelect,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                          child: const Text('Select'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewImage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (model.previewUrl != null && model.previewUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: model.previewUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(context),
        errorWidget: (context, url, error) => _buildPlaceholder(context),
      );
    }

    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          _getTypeIcon(model.type),
          size: 48,
          color: colorScheme.outlineVariant,
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'stable-diffusion':
      case 'checkpoint':
        return Icons.auto_awesome;
      case 'lora':
        return Icons.layers;
      case 'vae':
        return Icons.tune;
      case 'controlnet':
        return Icons.control_camera;
      case 'embedding':
        return Icons.brush;
      case 'clip':
      case 'text_encoder':
        return Icons.text_fields;
      default:
        return Icons.view_in_ar;
    }
  }

  Color _getClassColor(String modelClass) {
    switch (modelClass.toLowerCase()) {
      case 'sd1':
      case 'sd15':
        return Colors.blue;
      case 'sd2':
      case 'sd21':
        return Colors.purple;
      case 'sdxl':
        return Colors.orange;
      case 'flux':
        return Colors.green;
      case 'sd3':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Model list tile for list display
class ModelListTile extends StatelessWidget {
  final ModelInfo model;
  final VoidCallback? onTap;
  final VoidCallback? onSelect;

  const ModelListTile({
    super.key,
    required this.model,
    this.onTap,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: model.previewUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: model.previewUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                        Icon(Icons.view_in_ar, color: colorScheme.outline),
                  ),
                )
              : Icon(Icons.view_in_ar, color: colorScheme.outline),
        ),
        title: Text(
          model.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                model.type,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
              ),
            ),
            if (model.modelClass != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  model.modelClass!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Text(
              model.formattedSize,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
          ],
        ),
        trailing: onSelect != null
            ? FilledButton.tonal(
                onPressed: onSelect,
                child: const Text('Select'),
              )
            : null,
      ),
    );
  }
}
