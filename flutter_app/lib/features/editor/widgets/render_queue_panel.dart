import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/render_job_models.dart';
import '../providers/render_queue_provider.dart';

/// Panel for managing the render queue
class RenderQueuePanel extends ConsumerWidget {
  final VoidCallback? onClose;

  const RenderQueuePanel({super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final queue = ref.watch(renderQueueProvider);

    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context, ref, queue),

          // Active job
          if (queue.activeJob != null) _buildActiveJob(context, ref, queue.activeJob!),

          // Queue controls
          _buildQueueControls(context, ref, queue),

          // Job list
          Expanded(
            child: _buildJobList(context, ref, queue),
          ),

          // Add new render
          _buildAddRenderButton(context, ref),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, RenderQueue queue) {
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
          Icon(Icons.queue, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Render Queue',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${queue.queuedJobs.length} queued, ${queue.completedJobs.length} completed',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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

  Widget _buildActiveJob(BuildContext context, WidgetRef ref, RenderJob job) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                job.status == RenderStatus.rendering
                    ? Icons.play_circle
                    : Icons.hourglass_empty,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  job.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.cancel_outlined, size: 16),
                onPressed: () {
                  ref.read(renderQueueProvider.notifier).cancelJob(job.id);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Cancel',
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: job.progress,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),

          const SizedBox(height: 8),

          // Stats
          Row(
            children: [
              Text(
                job.progressString,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (job.renderSpeed != null)
                Text(
                  '${job.renderSpeed!.toStringAsFixed(1)} fps',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 12),
              Text(
                'ETA: ${job.etaString}',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQueueControls(BuildContext context, WidgetRef ref, RenderQueue queue) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Pause/Resume
          IconButton(
            icon: Icon(
              queue.isPaused ? Icons.play_arrow : Icons.pause,
              size: 20,
            ),
            onPressed: () {
              if (queue.isPaused) {
                ref.read(renderQueueProvider.notifier).resumeQueue();
              } else {
                ref.read(renderQueueProvider.notifier).pauseQueue();
              }
            },
            tooltip: queue.isPaused ? 'Resume Queue' : 'Pause Queue',
          ),

          if (queue.isPaused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PAUSED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
            ),

          const Spacer(),

          // Clear completed
          TextButton.icon(
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Clear Done'),
            onPressed: queue.completedJobs.isEmpty
                ? null
                : () {
                    ref.read(renderQueueProvider.notifier).clearCompleted();
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildJobList(BuildContext context, WidgetRef ref, RenderQueue queue) {
    if (queue.jobs.isEmpty) {
      return _buildEmptyState(context);
    }

    // Filter out active job
    final jobs = queue.jobs.where((j) => j.id != queue.activeJobId).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        return _JobListItem(
          job: jobs[index],
          canMoveUp: index > 0 && jobs[index].status == RenderStatus.queued,
          canMoveDown: index < jobs.length - 1 &&
              jobs[index].status == RenderStatus.queued,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_creation_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No renders in queue',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a render to get started',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRenderButton(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Render'),
          onPressed: () {
            _showAddRenderDialog(context, ref);
          },
        ),
      ),
    );
  }

  void _showAddRenderDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _AddRenderDialog(),
    );
  }
}

/// Job list item
class _JobListItem extends ConsumerWidget {
  final RenderJob job;
  final bool canMoveUp;
  final bool canMoveDown;

  const _JobListItem({
    required this.job,
    required this.canMoveUp,
    required this.canMoveDown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: job.status == RenderStatus.failed
            ? Border.all(color: colorScheme.error.withOpacity(0.5))
            : null,
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: _StatusIcon(status: job.status),
            title: Text(
              job.name,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${job.preset.name} - ${job.preset.resolution}',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: _buildActions(context, ref),
          ),

          // Error message
          if (job.status == RenderStatus.failed && job.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                job.errorMessage!,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.error,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canMoveUp)
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 18),
            onPressed: () {
              ref.read(renderQueueProvider.notifier).moveJobUp(job.id);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        if (canMoveDown)
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            onPressed: () {
              ref.read(renderQueueProvider.notifier).moveJobDown(job.id);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        IconButton(
          icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
          onPressed: () {
            ref.read(renderQueueProvider.notifier).removeJob(job.id);
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        ),
      ],
    );
  }
}

/// Status icon for job
class _StatusIcon extends StatelessWidget {
  final RenderStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color = status.color;

    switch (status) {
      case RenderStatus.queued:
        icon = Icons.schedule;
        break;
      case RenderStatus.preparing:
        icon = Icons.hourglass_empty;
        break;
      case RenderStatus.rendering:
        icon = Icons.play_circle;
        break;
      case RenderStatus.encoding:
        icon = Icons.compress;
        break;
      case RenderStatus.completed:
        icon = Icons.check_circle;
        break;
      case RenderStatus.failed:
        icon = Icons.error;
        break;
      case RenderStatus.cancelled:
        icon = Icons.cancel;
        break;
      case RenderStatus.paused:
        icon = Icons.pause_circle;
        break;
    }

    return Icon(icon, color: color, size: 20);
  }
}

/// Dialog for adding a new render
class _AddRenderDialog extends ConsumerStatefulWidget {
  const _AddRenderDialog();

  @override
  ConsumerState<_AddRenderDialog> createState() => _AddRenderDialogState();
}

class _AddRenderDialogState extends ConsumerState<_AddRenderDialog> {
  late TextEditingController _nameController;
  late TextEditingController _pathController;
  RenderPreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Render ${DateTime.now().millisecondsSinceEpoch}');
    _pathController = TextEditingController(text: '/home/output.mp4');
    _selectedPreset = RenderPreset.builtInPresets.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presets = ref.watch(allPresetsProvider);
    final presetsByCategory = ref.watch(presetsByCategoryProvider);

    return AlertDialog(
      title: const Text('Add Render'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pathController,
              decoration: const InputDecoration(
                labelText: 'Output Path',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RenderPreset>(
              value: _selectedPreset,
              decoration: const InputDecoration(
                labelText: 'Preset',
                border: OutlineInputBorder(),
              ),
              items: presets
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text('${p.name} (${p.resolution})'),
                      ))
                  .toList(),
              onChanged: (preset) {
                setState(() => _selectedPreset = preset);
                // Update output path extension
                if (preset != null) {
                  final ext = preset.videoCodec.fileExtension;
                  final path = _pathController.text;
                  final lastDot = path.lastIndexOf('.');
                  if (lastDot > 0) {
                    _pathController.text = '${path.substring(0, lastDot)}.$ext';
                  }
                }
              },
            ),
            if (_selectedPreset != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_selectedPreset!.resolution} @ ${_selectedPreset!.frameRate}fps',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '${_selectedPreset!.videoCodec.displayName} - ${_selectedPreset!.quality.displayName}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Audio: ${_selectedPreset!.audioCodec.displayName} @ ${_selectedPreset!.audioBitrate}kbps',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedPreset == null
              ? null
              : () {
                  ref.read(renderQueueProvider.notifier).addJob(
                        projectId: 'current_project',
                        name: _nameController.text,
                        outputPath: _pathController.text,
                        preset: _selectedPreset!,
                      );
                  Navigator.of(context).pop();
                },
          child: const Text('Add to Queue'),
        ),
      ],
    );
  }
}
