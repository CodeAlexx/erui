import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/model_download_provider.dart';

/// Model downloader widget for downloading models from CivitAI
class ModelDownloader extends ConsumerStatefulWidget {
  const ModelDownloader({super.key});

  @override
  ConsumerState<ModelDownloader> createState() => _ModelDownloaderState();
}

class _ModelDownloaderState extends ConsumerState<ModelDownloader> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  CivitAIModelInfo? _modelInfo;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _parseUrl() async {
    if (_urlController.text.trim().isEmpty) {
      setState(() {
        _modelInfo = null;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final info = await ref.read(modelDownloadProvider.notifier).parseCivitAIUrl(
        _urlController.text.trim(),
      );

      setState(() {
        _modelInfo = info;
        _isLoading = false;
        if (info == null) {
          _error = 'Could not parse URL. Please enter a valid CivitAI URL or model ID.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error parsing URL: $e';
      });
    }
  }

  Future<void> _startDownload() async {
    if (_modelInfo == null || _modelInfo!.downloadUrl == null) return;

    final downloadId = await ref.read(modelDownloadProvider.notifier).addDownload(
      url: _modelInfo!.downloadUrl!,
      name: _modelInfo!.fileName ?? '${_modelInfo!.name}.safetensors',
      modelType: _modelInfo!.type,
      targetFolder: _modelInfo!.targetFolder,
      totalBytes: _modelInfo!.fileSize,
    );

    if (downloadId != null) {
      _urlController.clear();
      setState(() {
        _modelInfo = null;
        _error = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download started: ${_modelInfo?.name ?? "Model"}'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                // Could navigate to downloads view
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final downloadState = ref.watch(modelDownloadProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.download, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Download Model',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // URL Input
            Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: 'CivitAI URL or Model ID',
                        hintText: 'https://civitai.com/models/12345 or 12345',
                        prefixIcon: const Icon(Icons.link),
                        suffixIcon: _urlController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _urlController.clear();
                                  setState(() {
                                    _modelInfo = null;
                                    _error = null;
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) => _parseUrl(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _parseUrl,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Lookup'),
                  ),
                ],
              ),
            ),

            // Error message
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Model info preview
            if (_modelInfo != null) ...[
              const SizedBox(height: 16),
              _ModelInfoCard(
                info: _modelInfo!,
                onDownload: _modelInfo!.downloadUrl != null ? _startDownload : null,
              ),
            ],

            // Active downloads
            if (downloadState.activeDownloads.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.downloading, color: colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'Downloads (${downloadState.activeDownloads.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...downloadState.activeDownloads.map((download) => _DownloadItemTile(
                download: download,
                onCancel: () => ref.read(modelDownloadProvider.notifier).cancelDownload(download.id),
              )),
            ],

            // Recent downloads (completed/failed)
            if (downloadState.completedDownloads.isNotEmpty || downloadState.failedDownloads.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Recent',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => ref.read(modelDownloadProvider.notifier).clearFinished(),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...downloadState.completedDownloads.take(3).map((download) => _DownloadItemTile(
                download: download,
                onRemove: () => ref.read(modelDownloadProvider.notifier).removeDownload(download.id),
              )),
              ...downloadState.failedDownloads.take(3).map((download) => _DownloadItemTile(
                download: download,
                onRetry: () => ref.read(modelDownloadProvider.notifier).retryDownload(download.id),
                onRemove: () => ref.read(modelDownloadProvider.notifier).removeDownload(download.id),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Model info preview card
class _ModelInfoCard extends StatelessWidget {
  final CivitAIModelInfo info;
  final VoidCallback? onDownload;

  const _ModelInfoCard({
    required this.info,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Model name and type
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _TypeBadge(type: info.type),
                        const SizedBox(width: 8),
                        if (info.fileSize != null)
                          Text(
                            _formatBytes(info.fileSize!),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (info.previewUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    info.previewUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      width: 80,
                      height: 80,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.image, color: colorScheme.outline),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // File info
          if (info.fileName != null) ...[
            Row(
              children: [
                Icon(Icons.insert_drive_file, size: 16, color: colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    info.fileName!,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Target folder
          Row(
            children: [
              Icon(Icons.folder, size: 16, color: colorScheme.outline),
              const SizedBox(width: 8),
              Text(
                'Will be saved to: Models/${info.targetFolder}/',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Download button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download),
              label: const Text('Download'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Type badge widget
class _TypeBadge extends StatelessWidget {
  final String type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getTypeColor(type),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'checkpoint':
        return Colors.blue;
      case 'lora':
      case 'locon':
        return Colors.orange;
      case 'textualinversion':
      case 'embedding':
        return Colors.purple;
      case 'vae':
        return Colors.green;
      case 'controlnet':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Download item tile
class _DownloadItemTile extends StatelessWidget {
  final DownloadItem download;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  const _DownloadItemTile({
    required this.download,
    this.onCancel,
    this.onRetry,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusIcon(status: download.status),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        download.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${download.modelType} - ${download.targetFolder}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                if (download.status == DownloadStatus.downloading ||
                    download.status == DownloadStatus.queued)
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: onCancel,
                    tooltip: 'Cancel',
                  ),
                if (download.status == DownloadStatus.failed)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onRetry,
                    tooltip: 'Retry',
                  ),
                if (download.status == DownloadStatus.completed ||
                    download.status == DownloadStatus.failed ||
                    download.status == DownloadStatus.cancelled)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onRemove,
                    tooltip: 'Remove',
                  ),
              ],
            ),
            // Progress bar
            if (download.status == DownloadStatus.downloading) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: download.progress,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    download.formattedProgress,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            // Error message
            if (download.error != null && download.status == DownloadStatus.failed) ...[
              const SizedBox(height: 8),
              Text(
                download.error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status icon widget
class _StatusIcon extends StatelessWidget {
  final DownloadStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (status) {
      case DownloadStatus.queued:
        return Icon(Icons.schedule, color: colorScheme.outline);
      case DownloadStatus.downloading:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        );
      case DownloadStatus.paused:
        return Icon(Icons.pause_circle, color: colorScheme.tertiary);
      case DownloadStatus.completed:
        return Icon(Icons.check_circle, color: colorScheme.primary);
      case DownloadStatus.failed:
        return Icon(Icons.error, color: colorScheme.error);
      case DownloadStatus.cancelled:
        return Icon(Icons.cancel, color: colorScheme.outline);
    }
  }
}

/// Dialog for showing model downloader
class ModelDownloaderDialog extends StatelessWidget {
  const ModelDownloaderDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ModelDownloaderDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 700,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.download, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Download Model from CivitAI',
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
            // Content
            const Flexible(
              child: SingleChildScrollView(
                child: ModelDownloader(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
