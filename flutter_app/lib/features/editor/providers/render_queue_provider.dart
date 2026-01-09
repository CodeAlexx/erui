import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/render_job_models.dart';
import '../services/render_queue_service.dart';

/// Provider for render queue service
final renderQueueServiceProvider = Provider<RenderQueueService>((ref) {
  final service = RenderQueueService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for render preset manager
final renderPresetManagerProvider = Provider<RenderPresetManager>((ref) {
  return RenderPresetManager();
});

/// Provider for render queue state
final renderQueueProvider =
    StateNotifierProvider<RenderQueueNotifier, RenderQueue>((ref) {
  final service = ref.watch(renderQueueServiceProvider);
  return RenderQueueNotifier(service);
});

/// Notifier for render queue
class RenderQueueNotifier extends StateNotifier<RenderQueue> {
  final RenderQueueService _service;

  RenderQueueNotifier(this._service) : super(const RenderQueue()) {
    // Subscribe to service updates
    _service.queueStream.listen((queue) {
      state = queue;
    });
  }

  /// Add a job to the queue
  RenderJob addJob({
    required EditorId projectId,
    required String name,
    required String outputPath,
    required RenderPreset preset,
    EditorTimeRange? range,
  }) {
    return _service.addJob(
      projectId: projectId,
      name: name,
      outputPath: outputPath,
      preset: preset,
      range: range,
    );
  }

  /// Remove a job
  void removeJob(EditorId jobId) {
    _service.removeJob(jobId);
  }

  /// Cancel a job
  void cancelJob(EditorId jobId) {
    _service.cancelJob(jobId);
  }

  /// Pause the queue
  void pauseQueue() {
    _service.pauseQueue();
  }

  /// Resume the queue
  void resumeQueue() {
    _service.resumeQueue();
  }

  /// Clear completed jobs
  void clearCompleted() {
    _service.clearCompleted();
  }

  /// Move job up in queue
  void moveJobUp(EditorId jobId) {
    _service.moveJobUp(jobId);
  }

  /// Move job down in queue
  void moveJobDown(EditorId jobId) {
    _service.moveJobDown(jobId);
  }
}

/// Provider for active render job
final activeRenderJobProvider = Provider<RenderJob?>((ref) {
  return ref.watch(renderQueueProvider).activeJob;
});

/// Provider for queued jobs
final queuedJobsProvider = Provider<List<RenderJob>>((ref) {
  return ref.watch(renderQueueProvider).queuedJobs;
});

/// Provider for completed jobs
final completedJobsProvider = Provider<List<RenderJob>>((ref) {
  return ref.watch(renderQueueProvider).completedJobs;
});

/// Provider for failed jobs
final failedJobsProvider = Provider<List<RenderJob>>((ref) {
  return ref.watch(renderQueueProvider).failedJobs;
});

/// Provider for whether queue is paused
final queuePausedProvider = Provider<bool>((ref) {
  return ref.watch(renderQueueProvider).isPaused;
});

/// Provider for all render presets
final allPresetsProvider = Provider<List<RenderPreset>>((ref) {
  return ref.watch(renderPresetManagerProvider).allPresets;
});

/// Provider for presets by category
final presetsByCategoryProvider =
    Provider<Map<String, List<RenderPreset>>>((ref) {
  return ref.watch(renderPresetManagerProvider).presetsByCategory;
});

/// Provider for render queue panel visibility
final renderQueuePanelVisibleProvider = StateProvider<bool>((ref) => false);

/// Provider for current render progress
final currentRenderProgressProvider = Provider<double?>((ref) {
  final activeJob = ref.watch(activeRenderJobProvider);
  return activeJob?.progress;
});

/// Provider for total queue progress
final totalQueueProgressProvider = Provider<double>((ref) {
  final queue = ref.watch(renderQueueProvider);
  if (queue.jobs.isEmpty) return 1.0;

  int completed = 0;
  double activeProgress = 0;

  for (final job in queue.jobs) {
    if (job.status == RenderStatus.completed) {
      completed++;
    } else if (job.status.isActive) {
      activeProgress = job.progress;
    }
  }

  return (completed + activeProgress) / queue.jobs.length;
});
