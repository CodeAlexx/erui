import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'image_viewer_dialog.dart';

/// Check if URL is a video file
bool isVideoUrl(String? url) {
  if (url == null) return false;
  final lower = url.toLowerCase();
  return lower.contains('.mp4') || lower.contains('.webm') ||
         lower.contains('.mov') || lower.contains('.avi') ||
         lower.contains('.mkv');
}

/// Check if URL is a base64 data URL (from WebSocket preview)
bool isBase64DataUrl(String? url) {
  if (url == null) return false;
  return url.startsWith('data:image/');
}

/// Decode base64 data URL to bytes
Uint8List? decodeBase64DataUrl(String dataUrl) {
  try {
    // Format: data:image/jpeg;base64,/9j/4AAQSkZJ...
    final parts = dataUrl.split(',');
    if (parts.length == 2) {
      return base64Decode(parts[1]);
    }
  } catch (e) {
    print('Failed to decode base64 image: $e');
  }
  return null;
}

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

/// Generation preview widget with progress overlay - supports images and videos
class GenerationPreview extends StatefulWidget {
  final String? imageUrl;
  final bool isGenerating;
  final bool isVideoMode;
  final double progress;
  final int currentStep;
  final int totalSteps;
  final List<String>? allImages;

  const GenerationPreview({
    super.key,
    this.imageUrl,
    this.isGenerating = false,
    this.isVideoMode = false,
    this.progress = 0.0,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.allImages,
  });

  @override
  State<GenerationPreview> createState() => _GenerationPreviewState();
}

class _GenerationPreviewState extends State<GenerationPreview> {
  Player? _player;
  VideoController? _videoController;
  String? _currentVideoUrl;

  @override
  void initState() {
    super.initState();
    _initVideoIfNeeded();
  }

  @override
  void didUpdateWidget(GenerationPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _initVideoIfNeeded();
    }
  }

  void _initVideoIfNeeded() {
    final url = widget.imageUrl;
    if (url != null && isVideoUrl(url) && url != _currentVideoUrl) {
      _disposeVideo();
      _player = Player();
      _videoController = VideoController(_player!);
      _currentVideoUrl = url;
      _player!.open(Media(url));
      _player!.setPlaylistMode(PlaylistMode.loop);
      setState(() {});
    } else if ((url == null || !isVideoUrl(url)) && _player != null) {
      _disposeVideo();
      setState(() {});
    }
  }

  void _disposeVideo() {
    _player?.dispose();
    _player = null;
    _videoController = null;
    _currentVideoUrl = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  void _openImageViewer(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) return;
    if (isVideoUrl(widget.imageUrl)) return;

    int index = 0;
    if (widget.allImages != null && widget.allImages!.contains(widget.imageUrl)) {
      index = widget.allImages!.indexOf(widget.imageUrl!);
    }

    ImageViewerDialog.show(
      context,
      imageUrl: widget.imageUrl!,
      allImages: widget.allImages,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isVideo = isVideoUrl(widget.imageUrl);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video, Image or placeholder
        if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
          if (isVideo && _videoController != null)
            // Embedded video player - uses fit to maintain native aspect ratio
            Container(
              color: Colors.black,
              child: Center(
                child: Video(
                  controller: _videoController!,
                  controls: MaterialVideoControls,
                  fit: BoxFit.contain,
                ),
              ),
            )
          else if (isVideo)
            // Loading video
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Loading video...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            )
          else
            // Image
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _openImageViewer(context),
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl!,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => _buildPlaceholder(context),
                  errorWidget: (context, url, error) => _buildPlaceholder(context),
                ),
              ),
            )
        else
          _buildPlaceholder(context),

        // Progress overlay
        if (widget.isGenerating)
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
                        child: LinearProgressIndicator(value: widget.progress),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.isVideoMode ? 'Generating video...' : 'Generating image...',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Step ${widget.currentStep} / ${widget.totalSteps}',
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
