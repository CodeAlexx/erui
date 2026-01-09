import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

import '../../../providers/providers.dart';

/// Resize modes for init image
enum InitImageResizeMode {
  stretch('Stretch', 'Stretch image to fit target dimensions'),
  crop('Crop', 'Crop image to fill target dimensions'),
  pad('Pad', 'Pad image to fit within target dimensions'),
  justResize('Just Resize', 'Resize without aspect ratio correction');

  final String label;
  final String description;
  const InitImageResizeMode(this.label, this.description);
}

/// Init Image Panel widget with full feature support
/// - Drag & drop support
/// - Paste from clipboard
/// - Preview thumbnail
/// - Denoise/Creativity slider
/// - Resize mode selection
/// - Clear button
class InitImagePanel extends ConsumerStatefulWidget {
  /// Whether the panel is expanded/enabled
  final bool enabled;

  /// Callback when enabled state changes
  final ValueChanged<bool>? onEnabledChanged;

  const InitImagePanel({
    super.key,
    this.enabled = false,
    this.onEnabledChanged,
  });

  @override
  ConsumerState<InitImagePanel> createState() => _InitImagePanelState();
}

class _InitImagePanelState extends ConsumerState<InitImagePanel> {
  bool _isDragHovering = false;
  bool _isLoadingImage = false;
  InitImageResizeMode _resizeMode = InitImageResizeMode.stretch;

  // Local image bytes for preview (when using base64/file)
  Uint8List? _localImageBytes;

  @override
  void initState() {
    super.initState();
    // Set up keyboard listener for paste
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  /// Handle keyboard events for paste shortcut
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyV) {
        // Only handle paste if this widget is focused/enabled
        if (widget.enabled) {
          _handlePaste();
          return true;
        }
      }
    }
    return false;
  }

  /// Handle paste from clipboard
  Future<void> _handlePaste() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        final text = clipboardData!.text!;
        // Check if it's a URL
        if (text.startsWith('http://') || text.startsWith('https://')) {
          _setInitImageFromUrl(text);
          return;
        }
        // Check if it's base64
        if (text.startsWith('data:image/') || _isBase64Image(text)) {
          _setInitImageFromBase64(text);
          return;
        }
      }

      // Try to get image data directly from clipboard
      // This requires platform-specific handling
      final imageBytes = await _getImageFromClipboard();
      if (imageBytes != null) {
        _setInitImageFromBytes(imageBytes);
      }
    } catch (e) {
      debugPrint('Error pasting image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to paste image: $e')),
        );
      }
    }
  }

  /// Check if string is valid base64 image
  bool _isBase64Image(String text) {
    try {
      final bytes = base64Decode(text);
      // Check for common image headers
      if (bytes.length > 4) {
        // PNG header
        if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
          return true;
        }
        // JPEG header
        if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
          return true;
        }
        // WebP header
        if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Platform-specific clipboard image retrieval
  Future<Uint8List?> _getImageFromClipboard() async {
    // This is a placeholder - actual implementation would need
    // platform channels or a dedicated package like pasteboard
    return null;
  }

  /// Set init image from URL
  void _setInitImageFromUrl(String url) {
    setState(() {
      _localImageBytes = null;
    });
    ref.read(generationParamsProvider.notifier).setInitImage(url);
    _showSuccessMessage('Init image set from URL');
  }

  /// Set init image from base64 string
  void _setInitImageFromBase64(String base64Data) {
    try {
      String cleanBase64 = base64Data;
      if (base64Data.startsWith('data:image/')) {
        cleanBase64 = base64Data.split(',').last;
      }
      final bytes = base64Decode(cleanBase64);
      _setInitImageFromBytes(bytes);
    } catch (e) {
      debugPrint('Error decoding base64: $e');
    }
  }

  /// Set init image from bytes
  void _setInitImageFromBytes(Uint8List bytes) {
    setState(() {
      _localImageBytes = bytes;
    });
    // Convert to base64 for the API
    final base64 = 'data:image/png;base64,${base64Encode(bytes)}';
    ref.read(generationParamsProvider.notifier).setInitImage(base64);
    _showSuccessMessage('Init image set');
  }

  /// Show success message
  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Handle file drop from desktop_drop
  Future<void> _handleFilesDrop(List<DropDoneDetails> details) async {
    if (details.isEmpty) return;

    final files = details.first.files;
    if (files.isEmpty) return;

    setState(() {
      _isLoadingImage = true;
      _isDragHovering = false;
    });

    try {
      final xFile = files.first;
      final bytes = await xFile.readAsBytes();

      // Verify it's an image by checking magic bytes
      if (bytes.length > 4) {
        final isPng = bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
        final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
        final isWebp = bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46;
        final isGif = bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46;

        if (isPng || isJpeg || isWebp || isGif) {
          _setInitImageFromBytes(bytes);
        } else {
          throw Exception('Unsupported image format');
        }
      }
    } catch (e) {
      debugPrint('Error processing dropped file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoadingImage = false;
      });
    }
  }

  /// Open file picker
  Future<void> _pickImage() async {
    setState(() => _isLoadingImage = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        _setInitImageFromBytes(bytes);
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    } finally {
      setState(() => _isLoadingImage = false);
    }
  }

  /// Clear init image
  void _clearInitImage() {
    setState(() {
      _localImageBytes = null;
    });
    ref.read(generationParamsProvider.notifier).setInitImage(null);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final params = ref.watch(generationParamsProvider);
    final paramsNotifier = ref.read(generationParamsProvider.notifier);
    final hasImage = params.initImage != null && params.initImage!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drop zone / Preview area
        _buildDropZone(context, colorScheme, params, hasImage),

        if (hasImage) ...[
          const SizedBox(height: 12),

          // Creativity (Denoise) slider
          _buildCreativitySlider(context, colorScheme, params, paramsNotifier),

          const SizedBox(height: 12),

          // Resize mode dropdown
          _buildResizeModeDropdown(context, colorScheme),

          const SizedBox(height: 12),

          // Clear button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearInitImage,
              icon: Icon(Icons.clear, color: colorScheme.error, size: 16),
              label: Text('Clear Init Image', style: TextStyle(color: colorScheme.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Build the drop zone / preview area
  Widget _buildDropZone(
    BuildContext context,
    ColorScheme colorScheme,
    GenerationParams params,
    bool hasImage,
  ) {
    final dropZoneContent = hasImage
        ? _buildImagePreview(context, colorScheme, params)
        : _buildEmptyDropZone(context, colorScheme);

    return DropTarget(
      onDragEntered: (details) {
        setState(() => _isDragHovering = true);
      },
      onDragExited: (details) {
        setState(() => _isDragHovering = false);
      },
      onDragDone: (details) {
        _handleFilesDrop([details]);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isDragHovering
              ? colorScheme.primary.withOpacity(0.1)
              : colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isDragHovering
                ? colorScheme.primary
                : hasImage
                    ? colorScheme.primary.withOpacity(0.5)
                    : colorScheme.outlineVariant,
            width: _isDragHovering ? 2 : 1,
          ),
        ),
        child: dropZoneContent,
      ),
    );
  }

  /// Build empty drop zone UI
  Widget _buildEmptyDropZone(BuildContext context, ColorScheme colorScheme) {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        child: _isLoadingImage
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 28, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Icon(Icons.content_paste,
                          size: 20, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Drop image, click to browse, or paste (Ctrl+V)',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PNG, JPG, WebP supported',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Build image preview
  Widget _buildImagePreview(
    BuildContext context,
    ColorScheme colorScheme,
    GenerationParams params,
  ) {
    Widget imageWidget;

    // Determine the image source
    final initImage = params.initImage!;

    if (_localImageBytes != null) {
      // Local bytes (from file picker or paste)
      imageWidget = Image.memory(
        _localImageBytes!,
        fit: BoxFit.contain,
      );
    } else if (initImage.startsWith('data:image/')) {
      // Base64 data URL
      try {
        final base64Data = initImage.split(',').last;
        final bytes = base64Decode(base64Data);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.contain,
        );
      } catch (e) {
        imageWidget = _buildErrorWidget(colorScheme);
      }
    } else if (initImage.startsWith('http://') || initImage.startsWith('https://')) {
      // Network URL
      imageWidget = CachedNetworkImage(
        imageUrl: initImage,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => _buildErrorWidget(colorScheme),
      );
    } else {
      // Try as file path
      imageWidget = Image.file(
        File(initImage),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(colorScheme),
      );
    }

    return Container(
      height: 150,
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          // Image
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: imageWidget,
            ),
          ),

          // Clear button overlay
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                onTap: _clearInitImage,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),

          // Replace button overlay
          Positioned(
            top: 4,
            left: 4,
            child: Material(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.swap_horiz, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),

          // img2img indicator badge
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'img2img',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build error widget for failed image loads
  Widget _buildErrorWidget(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.errorContainer,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, color: colorScheme.error),
          const SizedBox(height: 4),
          Text(
            'Failed to load',
            style: TextStyle(fontSize: 10, color: colorScheme.error),
          ),
        ],
      ),
    );
  }

  /// Build creativity/denoise slider
  Widget _buildCreativitySlider(
    BuildContext context,
    ColorScheme colorScheme,
    GenerationParams params,
    GenerationParamsNotifier paramsNotifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Creativity (Denoise)',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            const Spacer(),
            Text(
              params.initImageCreativity.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: params.initImageCreativity,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: (v) => paramsNotifier.setInitImageCreativity(v),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Follow Original',
              style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
            ),
            Text(
              'More Creative',
              style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
            ),
          ],
        ),
      ],
    );
  }

  /// Build resize mode dropdown
  Widget _buildResizeModeDropdown(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resize Mode',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<InitImageResizeMode>(
              value: _resizeMode,
              isExpanded: true,
              isDense: true,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
              items: InitImageResizeMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mode.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (mode) {
                if (mode != null) {
                  setState(() => _resizeMode = mode);
                  // TODO: Send resize mode to generation params when API supports it
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _resizeMode.description,
          style: TextStyle(
            fontSize: 9,
            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
