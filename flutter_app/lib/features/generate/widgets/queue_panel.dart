import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/advanced_generation_provider.dart';

/// Queue management panel
class QueuePanel extends ConsumerStatefulWidget {
  const QueuePanel({super.key});

  @override
  ConsumerState<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends ConsumerState<QueuePanel> {
  @override
  void initState() {
    super.initState();
    // Refresh queue on init
    Future.microtask(() {
      ref.read(queueProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(queueProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.queue, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Generation Queue',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                // Status badges
                _StatusBadge(
                  label: 'Running',
                  count: queueState.running,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                _StatusBadge(
                  label: 'Pending',
                  count: queueState.pending,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: queueState.isLoading
                      ? null
                      : () => ref.read(queueProvider.notifier).refresh(),
                ),
                // Clear all button
                if (queueState.items.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    tooltip: 'Clear queue',
                    onPressed: () => _confirmClearQueue(context),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Queue list
          if (queueState.isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (queueState.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error: ${queueState.error}',
                style: TextStyle(color: colorScheme.error),
              ),
            )
          else if (queueState.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Queue is empty',
                      style: TextStyle(color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: queueState.items.length,
              onReorder: (oldIndex, newIndex) {
                final items = List<QueueItem>.from(queueState.items);
                if (newIndex > oldIndex) newIndex--;
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                ref.read(queueProvider.notifier).reorderQueue(
                  items.map((i) => i.id).toList(),
                );
              },
              itemBuilder: (context, index) {
                final item = queueState.items[index];
                return _QueueItemTile(
                  key: ValueKey(item.id),
                  item: item,
                  index: index,
                  onCancel: () => ref.read(queueProvider.notifier).cancelItem(item.id),
                );
              },
            ),
        ],
      ),
    );
  }

  void _confirmClearQueue(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Queue'),
        content: const Text('Are you sure you want to clear all queued items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(queueProvider.notifier).clearQueue();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

/// Status badge widget
class _StatusBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Queue item tile
class _QueueItemTile extends StatelessWidget {
  final QueueItem item;
  final int index;
  final VoidCallback onCancel;

  const _QueueItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
      title: Row(
        children: [
          _StatusIcon(status: item.status),
          const SizedBox(width: 8),
          Text(_getTypeLabel(item.type)),
          if (item.batchId != null) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text('Batch'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ID: ${item.id.substring(0, 8)}...',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          if (item.progress != null)
            LinearProgressIndicator(
              value: item.progress,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
        ],
      ),
      trailing: item.status == 'pending' || item.status == 'running'
          ? IconButton(
              icon: const Icon(Icons.cancel),
              tooltip: 'Cancel',
              onPressed: onCancel,
            )
          : null,
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'txt2img':
        return 'Text to Image';
      case 'img2img':
        return 'Image to Image';
      case 'inpaint':
        return 'Inpainting';
      case 'controlnet':
        return 'ControlNet';
      case 'upscale':
        return 'Upscale';
      case 'refiner':
        return 'Refiner';
      case 'batch':
        return 'Batch';
      case 'variation':
        return 'Variation';
      case 'regional':
        return 'Regional';
      default:
        return type;
    }
  }
}

/// Status icon
class _StatusIcon extends StatelessWidget {
  final String status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    Color color;

    switch (status) {
      case 'pending':
        icon = Icons.schedule;
        color = colorScheme.outline;
        break;
      case 'running':
        icon = Icons.play_circle;
        color = colorScheme.primary;
        break;
      case 'completed':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'failed':
        icon = Icons.error;
        color = colorScheme.error;
        break;
      case 'cancelled':
        icon = Icons.cancel;
        color = colorScheme.outline;
        break;
      default:
        icon = Icons.help;
        color = colorScheme.outline;
    }

    return Icon(icon, color: color, size: 20);
  }
}

/// Compact queue indicator for the main generate screen
class QueueIndicator extends ConsumerWidget {
  const QueueIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(queueProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (queueState.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (queueState.running > 0) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '${queueState.running + queueState.pending} in queue',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
