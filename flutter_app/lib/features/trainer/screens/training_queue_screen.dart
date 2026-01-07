import 'package:flutter/material.dart';

/// Training Queue Screen - Shows current job, pending queue, and history
class TrainingQueueScreen extends StatefulWidget {
  const TrainingQueueScreen({super.key});

  @override
  State<TrainingQueueScreen> createState() => _TrainingQueueScreenState();
}

class _TrainingQueueScreenState extends State<TrainingQueueScreen> {
  List<TrainingJob> _pendingJobs = [];
  List<TrainingJob> _historyJobs = [];
  TrainingJob? _currentJob;
  bool _historyExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Text(
                  'Training Queue',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshQueue,
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addNewJob,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Job'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Job
                  _buildSection(
                    'CURRENT JOB',
                    _currentJob != null
                        ? _buildJobCard(_currentJob!, isCurrentJob: true)
                        : _buildEmptyState('No job currently running'),
                    colorScheme,
                  ),

                  const SizedBox(height: 24),

                  // Pending Queue
                  _buildSection(
                    'PENDING QUEUE (${_pendingJobs.length})',
                    _pendingJobs.isNotEmpty
                        ? Column(
                            children: _pendingJobs
                                .map((job) => _buildJobCard(job))
                                .toList(),
                          )
                        : _buildEmptyState('No jobs in queue'),
                    colorScheme,
                  ),

                  const SizedBox(height: 24),

                  // History (collapsible)
                  _buildCollapsibleSection(
                    'HISTORY (${_historyJobs.length})',
                    _historyExpanded,
                    () => setState(() => _historyExpanded = !_historyExpanded),
                    _historyJobs.isNotEmpty
                        ? Column(
                            children: _historyJobs
                                .map((job) => _buildJobCard(job, isHistory: true))
                                .toList(),
                          )
                        : _buildEmptyState('No training history'),
                    colorScheme,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildCollapsibleSection(
    String title,
    bool expanded,
    VoidCallback onToggle,
    Widget content,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Row(
            children: [
              Icon(
                expanded ? Icons.expand_more : Icons.chevron_right,
                size: 20,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 12),
          content,
        ],
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(TrainingJob job, {bool isCurrentJob = false, bool isHistory = false}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentJob
              ? colorScheme.primary.withOpacity(0.5)
              : colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(job.status),
            ),
          ),
          const SizedBox(width: 12),

          // Job info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.name,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${job.modelType} • ${job.trainingMethod} • ${job.steps} steps',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Progress or actions
          if (isCurrentJob && job.status == JobStatus.running) ...[
            SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${job.progress}%',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: job.progress / 100,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.stop, color: Colors.red),
              onPressed: () => _stopJob(job),
              tooltip: 'Stop',
            ),
          ] else if (!isHistory) ...[
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _startJob(job),
              tooltip: 'Start',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _removeJob(job),
              tooltip: 'Remove',
            ),
          ] else ...[
            Text(
              _formatDuration(job.duration),
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.running:
        return Colors.green;
      case JobStatus.pending:
        return Colors.orange;
      case JobStatus.completed:
        return Colors.blue;
      case JobStatus.failed:
        return Colors.red;
      case JobStatus.stopped:
        return Colors.grey;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  void _refreshQueue() {
    // TODO: Refresh from API
  }

  void _addNewJob() {
    // TODO: Open new job dialog
  }

  void _startJob(TrainingJob job) {
    // TODO: Start job via API
  }

  void _stopJob(TrainingJob job) {
    // TODO: Stop job via API
  }

  void _removeJob(TrainingJob job) {
    // TODO: Remove job via API
  }
}

enum JobStatus { pending, running, completed, failed, stopped }

class TrainingJob {
  final String id;
  final String name;
  final String modelType;
  final String trainingMethod;
  final int steps;
  final JobStatus status;
  final double progress;
  final Duration duration;

  TrainingJob({
    required this.id,
    required this.name,
    required this.modelType,
    required this.trainingMethod,
    required this.steps,
    required this.status,
    this.progress = 0,
    this.duration = Duration.zero,
  });
}
