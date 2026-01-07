import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

import '../../../providers/gallery_provider.dart';

/// Full image viewer dialog
class FullImageViewerDialog extends StatefulWidget {
  final GalleryImage image;

  const FullImageViewerDialog({
    super.key,
    required this.image,
  });

  @override
  State<FullImageViewerDialog> createState() => _FullImageViewerDialogState();
}

class _FullImageViewerDialogState extends State<FullImageViewerDialog> {
  bool _showInfo = false;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black.withOpacity(0.5),
          foregroundColor: Colors.white,
          title: Text(widget.image.filename),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                // TODO: Download
              },
              tooltip: 'Download',
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                // TODO: Share
              },
              tooltip: 'Share',
            ),
            IconButton(
              icon: Icon(_showInfo ? Icons.info : Icons.info_outline),
              onPressed: () {
                setState(() => _showInfo = !_showInfo);
              },
              tooltip: 'Info',
            ),
          ],
        ),
        body: Stack(
          children: [
            // Image viewer
            PhotoView(
              imageProvider: CachedNetworkImageProvider(widget.image.url),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              loadingBuilder: (context, event) {
                return Center(
                  child: CircularProgressIndicator(
                    value: event != null && event.expectedTotalBytes != null
                        ? event.cumulativeBytesLoaded /
                            event.expectedTotalBytes!
                        : null,
                    color: Colors.white,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 64,
                  ),
                );
              },
            ),
            // Info panel
            if (_showInfo)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _ImageInfoPanel(image: widget.image),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageInfoPanel extends StatelessWidget {
  final GalleryImage image;

  const _ImageInfoPanel({required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      color: Colors.black.withOpacity(0.85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(context, 'File Info', [
              _InfoRow(label: 'Filename', value: image.filename),
              _InfoRow(label: 'Dimensions', value: image.dimensions),
              _InfoRow(label: 'Size', value: image.formattedSize),
              _InfoRow(label: 'Created', value: _formatDateTime(image.createdAt)),
            ]),
            const SizedBox(height: 16),
            if (image.prompt != null && image.prompt!.isNotEmpty) ...[
              _buildSection(context, 'Prompt', [
                _TextBlock(text: image.prompt!),
              ]),
              const SizedBox(height: 16),
            ],
            if (image.negativePrompt != null &&
                image.negativePrompt!.isNotEmpty) ...[
              _buildSection(context, 'Negative Prompt', [
                _TextBlock(text: image.negativePrompt!),
              ]),
              const SizedBox(height: 16),
            ],
            if (image.metadata != null && image.metadata!.isNotEmpty) ...[
              _buildSection(
                context,
                'Generation Parameters',
                image.metadata!.entries
                    .map((e) => _InfoRow(
                          label: _formatKey(e.key),
                          value: e.value.toString(),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            // Copy buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (image.prompt != null) {
                        Clipboard.setData(ClipboardData(text: image.prompt!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Prompt copied')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Prompt'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Use these parameters
                    },
                    icon: const Icon(Icons.replay, size: 16),
                    label: const Text('Use Parameters'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String text;

  const _TextBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 12),
    );
  }
}
