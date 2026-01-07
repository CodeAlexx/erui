import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'image_viewer_dialog.dart';

/// Image preview widget with loading and error states
class ImagePreview extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const ImagePreview({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget content;

    if (imageUrl == null || imageUrl!.isEmpty) {
      content = _buildPlaceholder(context);
    } else {
      content = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildLoading(context),
        errorWidget: (context, url, error) => _buildError(context),
      );
    }

    if (borderRadius != null) {
      content = ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: colorScheme.outlineVariant,
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: colorScheme.surfaceContainerHighest,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 48,
          color: colorScheme.error,
        ),
      ),
    );
  }
}

/// Generation preview widget with progress overlay
class GenerationPreview extends StatelessWidget {
  final String? imageUrl;
  final bool isGenerating;
  final double progress;
  final int currentStep;
  final int totalSteps;
  final List<String>? allImages;

  const GenerationPreview({
    super.key,
    this.imageUrl,
    this.isGenerating = false,
    this.progress = 0.0,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.allImages,
  });

  void _openViewer(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return;

    int index = 0;
    if (allImages != null && allImages!.contains(imageUrl)) {
      index = allImages!.indexOf(imageUrl!);
    }

    ImageViewerDialog.show(
      context,
      imageUrl: imageUrl!,
      allImages: allImages,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Image or placeholder - clickable
        if (imageUrl != null && imageUrl!.isNotEmpty)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _openViewer(context),
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.contain,
                placeholder: (context, url) => _buildPlaceholder(context),
                errorWidget: (context, url, error) => _buildPlaceholder(context),
              ),
            ),
          )
        else
          _buildPlaceholder(context),

        // Progress overlay
        if (isGenerating)
          Container(
            color: Colors.black45,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(value: progress),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Generating...',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Step $currentStep / $totalSteps',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 80,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Generated images will appear here',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
