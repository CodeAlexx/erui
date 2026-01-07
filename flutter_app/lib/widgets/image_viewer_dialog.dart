import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Full-screen image viewer dialog with zoom and pan support
class ImageViewerDialog extends StatefulWidget {
  final String imageUrl;
  final List<String>? allImages;
  final int initialIndex;

  const ImageViewerDialog({
    super.key,
    required this.imageUrl,
    this.allImages,
    this.initialIndex = 0,
  });

  /// Show the image viewer dialog
  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    List<String>? allImages,
    int initialIndex = 0,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => ImageViewerDialog(
        imageUrl: imageUrl,
        allImages: allImages,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  late int _currentIndex;
  late PageController _pageController;
  final TransformationController _transformController = TransformationController();

  List<String> get _images => widget.allImages ?? [widget.imageUrl];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _previousImage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextImage() {
    if (_currentIndex < _images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasMultipleImages = _images.length > 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image viewer with gesture support
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: hasMultipleImages
                ? PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                      _resetZoom();
                    },
                    itemCount: _images.length,
                    itemBuilder: (context, index) => _buildImageView(_images[index]),
                  )
                : _buildImageView(widget.imageUrl),
          ),

          // Top bar with close button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                    if (hasMultipleImages) ...[
                      const Spacer(),
                      Text(
                        '${_currentIndex + 1} / ${_images.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.zoom_out_map, color: Colors.white),
                      onPressed: _resetZoom,
                      tooltip: 'Reset zoom',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Navigation arrows for multiple images
          if (hasMultipleImages) ...[
            // Left arrow
            if (_currentIndex > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _NavigationButton(
                    icon: Icons.chevron_left,
                    onTap: _previousImage,
                  ),
                ),
              ),
            // Right arrow
            if (_currentIndex < _images.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _NavigationButton(
                    icon: Icons.chevron_right,
                    onTap: _nextImage,
                  ),
                ),
              ),
          ],

          // Bottom thumbnail strip for multiple images
          if (hasMultipleImages && _images.length <= 20)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_images.length, (index) {
                          final isSelected = index == _currentIndex;
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              width: 56,
                              height: 56,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected ? colorScheme.primary : Colors.white30,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: CachedNetworkImage(
                                  imageUrl: _images[index],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[800],
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.broken_image, size: 20, color: Colors.white54),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageView(String url) {
    return Center(
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.5,
        maxScale: 4.0,
        child: GestureDetector(
          // Stop tap from closing dialog when interacting with image
          onTap: () {},
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavigationButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
