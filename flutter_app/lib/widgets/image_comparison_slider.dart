import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Image comparison slider widget for before/after comparison
///
/// Displays two images with a draggable divider to reveal/hide portions
/// of each image. Supports horizontal sliding and image swapping.
class ImageComparisonSlider extends StatefulWidget {
  /// URL of the left/before image
  final String beforeImageUrl;

  /// URL of the right/after image
  final String afterImageUrl;

  /// Optional label for the before image
  final String? beforeLabel;

  /// Optional label for the after image
  final String? afterLabel;

  /// Initial divider position (0.0 to 1.0, default 0.5)
  final double initialPosition;

  /// Divider line color
  final Color? dividerColor;

  /// Divider handle color
  final Color? handleColor;

  /// Whether to show labels
  final bool showLabels;

  /// Divider width
  final double dividerWidth;

  /// Handle size
  final double handleSize;

  const ImageComparisonSlider({
    super.key,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    this.beforeLabel,
    this.afterLabel,
    this.initialPosition = 0.5,
    this.dividerColor,
    this.handleColor,
    this.showLabels = true,
    this.dividerWidth = 3.0,
    this.handleSize = 48.0,
  });

  @override
  State<ImageComparisonSlider> createState() => _ImageComparisonSliderState();
}

class _ImageComparisonSliderState extends State<ImageComparisonSlider> {
  late double _dividerPosition;
  bool _isSwapped = false;

  @override
  void initState() {
    super.initState();
    _dividerPosition = widget.initialPosition.clamp(0.0, 1.0);
  }

  String get _leftImageUrl => _isSwapped ? widget.afterImageUrl : widget.beforeImageUrl;
  String get _rightImageUrl => _isSwapped ? widget.beforeImageUrl : widget.afterImageUrl;
  String? get _leftLabel => _isSwapped ? widget.afterLabel : widget.beforeLabel;
  String? get _rightLabel => _isSwapped ? widget.beforeLabel : widget.afterLabel;

  void _swapImages() {
    setState(() {
      _isSwapped = !_isSwapped;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dividerColor = widget.dividerColor ?? colorScheme.primary;
    final handleColor = widget.handleColor ?? colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Stack(
          children: [
            // Right/After image (full width, shown beneath)
            Positioned.fill(
              child: _buildImage(_rightImageUrl, BoxFit.contain),
            ),

            // Left/Before image (clipped by divider position)
            Positioned.fill(
              child: ClipRect(
                clipper: _ImageClipper(
                  clipWidth: width * _dividerPosition,
                ),
                child: _buildImage(_leftImageUrl, BoxFit.contain),
              ),
            ),

            // Divider line and handle
            Positioned(
              left: width * _dividerPosition - widget.dividerWidth / 2,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _dividerPosition += details.delta.dx / width;
                    _dividerPosition = _dividerPosition.clamp(0.05, 0.95);
                  });
                },
                child: Container(
                  width: widget.handleSize,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Divider line (top)
                      Expanded(
                        child: Container(
                          width: widget.dividerWidth,
                          color: dividerColor,
                        ),
                      ),
                      // Handle
                      Container(
                        width: widget.handleSize,
                        height: widget.handleSize,
                        decoration: BoxDecoration(
                          color: handleColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.swap_horiz,
                          color: colorScheme.onPrimary,
                          size: widget.handleSize * 0.5,
                        ),
                      ),
                      // Divider line (bottom)
                      Expanded(
                        child: Container(
                          width: widget.dividerWidth,
                          color: dividerColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Labels
            if (widget.showLabels) ...[
              // Left/Before label
              if (_leftLabel != null && _leftLabel!.isNotEmpty)
                Positioned(
                  top: 16,
                  left: 16,
                  child: _buildLabel(_leftLabel!, colorScheme),
                ),
              // Right/After label
              if (_rightLabel != null && _rightLabel!.isNotEmpty)
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildLabel(_rightLabel!, colorScheme),
                ),
            ],

            // Swap button (bottom center)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _swapImages,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz, size: 18, color: colorScheme.onSurface),
                          const SizedBox(width: 8),
                          Text(
                            'Swap Images',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImage(String url, BoxFit fit) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (context, url) => Container(
        color: Colors.grey[900],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.broken_image, size: 48, color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Custom clipper for the before image
class _ImageClipper extends CustomClipper<Rect> {
  final double clipWidth;

  _ImageClipper({required this.clipWidth});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, clipWidth, size.height);
  }

  @override
  bool shouldReclip(_ImageClipper oldClipper) {
    return oldClipper.clipWidth != clipWidth;
  }
}

/// Dialog wrapper for image comparison
///
/// Shows the ImageComparisonSlider in a full-screen dialog
class ImageComparisonDialog extends StatelessWidget {
  final String beforeImageUrl;
  final String afterImageUrl;
  final String? beforeLabel;
  final String? afterLabel;
  final String? title;

  const ImageComparisonDialog({
    super.key,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    this.beforeLabel,
    this.afterLabel,
    this.title,
  });

  /// Show the comparison dialog
  static Future<void> show(
    BuildContext context, {
    required String beforeImageUrl,
    required String afterImageUrl,
    String? beforeLabel,
    String? afterLabel,
    String? title,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => ImageComparisonDialog(
        beforeImageUrl: beforeImageUrl,
        afterImageUrl: afterImageUrl,
        beforeLabel: beforeLabel,
        afterLabel: afterLabel,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black.withOpacity(0.5),
          foregroundColor: Colors.white,
          title: Text(title ?? 'Compare Images'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('How to Compare'),
                    content: const Text(
                      'Drag the slider left or right to reveal more of each image.\n\n'
                      'Tap "Swap Images" to switch the before and after positions.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Help',
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ImageComparisonSlider(
              beforeImageUrl: beforeImageUrl,
              afterImageUrl: afterImageUrl,
              beforeLabel: beforeLabel ?? 'Before',
              afterLabel: afterLabel ?? 'After',
            ),
          ),
        ),
      ),
    );
  }
}

/// Selection dialog for choosing an image to compare with
///
/// Shows a grid of available images for the user to select
class ImageComparisonSelectDialog extends StatelessWidget {
  final List<String> imageUrls;
  final String currentImageUrl;
  final Function(String) onImageSelected;

  const ImageComparisonSelectDialog({
    super.key,
    required this.imageUrls,
    required this.currentImageUrl,
    required this.onImageSelected,
  });

  /// Show the selection dialog
  static Future<String?> show(
    BuildContext context, {
    required List<String> imageUrls,
    required String currentImageUrl,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => ImageComparisonSelectDialog(
        imageUrls: imageUrls.where((url) => url != currentImageUrl).toList(),
        currentImageUrl: currentImageUrl,
        onImageSelected: (url) => Navigator.of(context).pop(url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.compare, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Select Image to Compare',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Image grid
            Expanded(
              child: imageUrls.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No other images available',
                            style: TextStyle(color: colorScheme.outline),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 150,
                        childAspectRatio: 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) {
                        final url = imageUrls[index];
                        return InkWell(
                          onTap: () => onImageSelected(url),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: CachedNetworkImage(
                                imageUrl: url,
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
                                    Icons.broken_image,
                                    color: colorScheme.error,
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
      ),
    );
  }
}
