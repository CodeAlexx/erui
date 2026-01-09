import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/proxy_models.dart';
import '../providers/proxy_provider.dart';

/// Panel for managing proxy files
class ProxyManagerPanel extends ConsumerWidget {
  final VoidCallback? onClose;

  const ProxyManagerPanel({super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final proxyState = ref.watch(proxyWorkflowProvider);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(context, ref),

          // Global toggle
          _buildGlobalToggle(context, ref, proxyState),

          // Settings
          _buildSettings(context, ref, proxyState.settings),

          const Divider(height: 1),

          // Proxy list
          Expanded(
            child: _buildProxyList(context, ref, proxyState),
          ),

          // Actions
          _buildActions(context, ref, proxyState),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.speed, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Proxy Manager',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildGlobalToggle(BuildContext context, WidgetRef ref, ProxyState state) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proxy Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  state.proxyModeEnabled
                      ? 'Using proxy files for editing'
                      : 'Using original files',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: state.proxyModeEnabled,
            onChanged: (value) {
              ref.read(proxyWorkflowProvider.notifier).setProxyMode(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettings(BuildContext context, WidgetRef ref, ProxySettings settings) {
    final colorScheme = Theme.of(context).colorScheme;

    return ExpansionTile(
      title: Text(
        'Settings',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // Target width
        _SettingRow(
          label: 'Target Width',
          child: DropdownButton<int>(
            value: settings.targetWidth,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 480, child: Text('480p')),
              DropdownMenuItem(value: 640, child: Text('640p')),
              DropdownMenuItem(value: 720, child: Text('720p')),
              DropdownMenuItem(value: 960, child: Text('960p')),
            ],
            onChanged: (value) {
              if (value != null) {
                ref.read(proxyWorkflowProvider.notifier).updateSettings(
                      settings.copyWith(targetWidth: value),
                    );
              }
            },
          ),
        ),

        // Codec
        _SettingRow(
          label: 'Codec',
          child: DropdownButton<ProxyCodec>(
            value: settings.codec,
            underline: const SizedBox(),
            items: ProxyCodec.values
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.displayName),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(proxyWorkflowProvider.notifier).updateSettings(
                      settings.copyWith(codec: value),
                    );
              }
            },
          ),
        ),

        // Quality
        _SettingRow(
          label: 'Quality',
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  value: settings.quality.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 9,
                  onChanged: (value) {
                    ref.read(proxyWorkflowProvider.notifier).updateSettings(
                          settings.copyWith(quality: value.round()),
                        );
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${settings.quality}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Auto generate
        _SettingRow(
          label: 'Auto Generate',
          child: Switch(
            value: settings.autoGenerate,
            onChanged: (value) {
              ref.read(proxyWorkflowProvider.notifier).updateSettings(
                    settings.copyWith(autoGenerate: value),
                  );
            },
          ),
        ),

        // Min source width
        _SettingRow(
          label: 'Min Source Width',
          child: DropdownButton<int>(
            value: settings.minSourceWidth,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 1280, child: Text('720p+')),
              DropdownMenuItem(value: 1920, child: Text('1080p+')),
              DropdownMenuItem(value: 2560, child: Text('1440p+')),
              DropdownMenuItem(value: 3840, child: Text('4K+')),
            ],
            onChanged: (value) {
              if (value != null) {
                ref.read(proxyWorkflowProvider.notifier).updateSettings(
                      settings.copyWith(minSourceWidth: value),
                    );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProxyList(BuildContext context, WidgetRef ref, ProxyState state) {
    final colorScheme = Theme.of(context).colorScheme;

    if (state.proxies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_creation_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No proxies generated',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.proxies.length,
      itemBuilder: (context, index) {
        final entry = state.proxies.entries.elementAt(index);
        return _ProxyListItem(
          clipId: entry.key,
          proxy: entry.value,
        );
      },
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref, ProxyState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasGenerating = state.hasGeneratingProxies;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // Cache size
          FutureBuilder<int>(
            future: ref.watch(proxyCacheSizeProvider.future),
            builder: (context, snapshot) {
              final size = snapshot.data ?? 0;
              final sizeStr = _formatBytes(size);
              return Text(
                'Cache: $sizeStr',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Clear All'),
                  onPressed: hasGenerating
                      ? null
                      : () {
                          ref.read(proxyWorkflowProvider.notifier).clearAllProxies();
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

/// Single proxy item in list
class _ProxyListItem extends ConsumerWidget {
  final EditorId clipId;
  final ProxyFile proxy;

  const _ProxyListItem({
    required this.clipId,
    required this.proxy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File name and status
          Row(
            children: [
              Expanded(
                child: Text(
                  proxy.originalPath.split('/').last,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusChip(status: proxy.status),
            ],
          ),

          const SizedBox(height: 4),

          // Resolution info
          Text(
            '${proxy.originalWidth}x${proxy.originalHeight}'
            ' -> ${proxy.proxyWidth ?? '?'}x${proxy.proxyHeight ?? '?'}',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          // Progress bar if generating
          if (proxy.status == ProxyStatus.generating) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: proxy.progress,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ],

          // Error message if failed
          if (proxy.status == ProxyStatus.failed && proxy.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              proxy.errorMessage!,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.error,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Actions
          if (proxy.status == ProxyStatus.ready) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(
                    proxy.useProxy ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 16,
                  ),
                  label: const Text('Use'),
                  onPressed: () {
                    ref.read(proxyWorkflowProvider.notifier).toggleProxyUsage(
                          clipId,
                          !proxy.useProxy,
                        );
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  onPressed: () {
                    ref.read(proxyWorkflowProvider.notifier).deleteProxy(clipId);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Status chip
class _StatusChip extends StatelessWidget {
  final ProxyStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color bgColor;
    Color textColor;
    String text;
    IconData? icon;

    switch (status) {
      case ProxyStatus.none:
        bgColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        text = 'None';
        break;
      case ProxyStatus.generating:
        bgColor = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        text = 'Generating';
        icon = Icons.hourglass_empty;
        break;
      case ProxyStatus.ready:
        bgColor = Colors.green.withOpacity(0.2);
        textColor = Colors.green;
        text = 'Ready';
        icon = Icons.check;
        break;
      case ProxyStatus.failed:
        bgColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        text = 'Failed';
        icon = Icons.error_outline;
        break;
      case ProxyStatus.notNeeded:
        bgColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        text = 'Not Needed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Setting row widget
class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingRow({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
