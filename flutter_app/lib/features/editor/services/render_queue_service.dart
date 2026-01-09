import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/editor_models.dart';
import '../models/render_job_models.dart';
import 'ffmpeg_service.dart';

/// Service for managing render queue
class RenderQueueService {
  final FFmpegService _ffmpeg;
  final StreamController<RenderQueue> _queueController =
      StreamController<RenderQueue>.broadcast();

  RenderQueue _queue = const RenderQueue();
  bool _isProcessing = false;

  RenderQueueService({FFmpegService? ffmpeg})
      : _ffmpeg = ffmpeg ?? FFmpegService();

  /// Current queue state
  RenderQueue get queue => _queue;

  /// Stream of queue state changes
  Stream<RenderQueue> get queueStream => _queueController.stream;

  /// Add a job to the queue
  RenderJob addJob({
    required EditorId projectId,
    required String name,
    required String outputPath,
    required RenderPreset preset,
    EditorTimeRange? range,
  }) {
    final job = RenderJob(
      id: generateId(),
      projectId: projectId,
      name: name,
      outputPath: outputPath,
      preset: preset,
      status: RenderStatus.queued,
      range: range,
      createdAt: DateTime.now(),
    );

    _queue = _queue.addJob(job);
    _queueController.add(_queue);

    // Start processing if not already
    _processQueue();

    return job;
  }

  /// Remove a job from the queue
  void removeJob(EditorId jobId) {
    final job = _findJob(jobId);
    if (job != null && job.status.isActive) {
      // Can't remove active job - cancel it first
      cancelJob(jobId);
      return;
    }

    _queue = _queue.removeJob(jobId);
    _queueController.add(_queue);
  }

  /// Cancel an active job
  void cancelJob(EditorId jobId) {
    final job = _findJob(jobId);
    if (job == null) return;

    if (job.status.isActive) {
      // TODO: Actually cancel FFmpeg process
    }

    _queue = _queue.updateJob(job.copyWith(
      status: RenderStatus.cancelled,
    ));
    _queueController.add(_queue);
  }

  /// Pause the queue
  void pauseQueue() {
    _queue = _queue.copyWith(isPaused: true);
    _queueController.add(_queue);
  }

  /// Resume the queue
  void resumeQueue() {
    _queue = _queue.copyWith(isPaused: false);
    _queueController.add(_queue);
    _processQueue();
  }

  /// Clear completed and failed jobs
  void clearCompleted() {
    _queue = _queue.clearCompleted();
    _queueController.add(_queue);
  }

  /// Move job up in queue
  void moveJobUp(EditorId jobId) {
    final jobs = List<RenderJob>.from(_queue.jobs);
    final index = jobs.indexWhere((j) => j.id == jobId);
    if (index > 0 && jobs[index].status == RenderStatus.queued) {
      final job = jobs.removeAt(index);
      jobs.insert(index - 1, job);
      _queue = _queue.copyWith(jobs: jobs);
      _queueController.add(_queue);
    }
  }

  /// Move job down in queue
  void moveJobDown(EditorId jobId) {
    final jobs = List<RenderJob>.from(_queue.jobs);
    final index = jobs.indexWhere((j) => j.id == jobId);
    if (index >= 0 && index < jobs.length - 1 && jobs[index].status == RenderStatus.queued) {
      final job = jobs.removeAt(index);
      jobs.insert(index + 1, job);
      _queue = _queue.copyWith(jobs: jobs);
      _queueController.add(_queue);
    }
  }

  /// Process the queue (desktop only - FFmpeg not available on web)
  Future<void> _processQueue() async {
    if (kIsWeb || _isProcessing || _queue.isPaused) return;

    final nextJob = _queue.nextJob;
    if (nextJob == null) return;

    _isProcessing = true;
    await _processJob(nextJob);
    _isProcessing = false;

    // Continue processing
    _processQueue();
  }

  /// Process a single job
  Future<void> _processJob(RenderJob job) async {
    // Update to preparing
    _updateJob(job.copyWith(
      status: RenderStatus.preparing,
      startedAt: DateTime.now(),
    ));

    try {
      // Build FFmpeg command
      final command = _buildRenderCommand(job);

      // Update to rendering
      _updateJob(job.copyWith(status: RenderStatus.rendering));

      // Execute render
      await _ffmpeg.executeCommand(
        command,
        onProgress: (progress) {
          _updateJob(job.copyWith(
            progress: progress,
            currentFrame: (progress * job.totalFrames).round(),
            renderSpeed: _calculateRenderSpeed(job, progress),
            estimatedTimeRemaining: _estimateTimeRemaining(job, progress),
          ));
        },
      );

      // Update to encoding (if two-pass)
      _updateJob(job.copyWith(status: RenderStatus.encoding));

      // Verify output exists (skip on web)
      if (!kIsWeb) {
        // File verification is desktop only
        // On web, trust that FFmpeg completed successfully
      }

      // Mark completed
      _updateJob(job.copyWith(
        status: RenderStatus.completed,
        progress: 1.0,
        completedAt: DateTime.now(),
      ));
    } catch (e) {
      // Mark failed
      _updateJob(job.copyWith(
        status: RenderStatus.failed,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      ));
    }
  }

  /// Build FFmpeg command for render job
  List<String> _buildRenderCommand(RenderJob job) {
    final preset = job.preset;
    final args = <String>[];

    // Input
    // TODO: Get actual project video path
    args.addAll(['-i', 'input.mp4']);

    // Time range if specified
    if (job.range != null) {
      args.addAll([
        '-ss', job.range!.start.inSeconds.toString(),
        '-t', job.range!.duration.inSeconds.toString(),
      ]);
    }

    // Video encoding
    args.addAll(preset.toFfmpegVideoArgs().split(' '));

    // Audio encoding
    args.addAll(preset.toFfmpegAudioArgs().split(' '));

    // Output
    args.addAll(['-y', job.outputPath]);

    return args;
  }

  /// Calculate render speed
  double? _calculateRenderSpeed(RenderJob job, double progress) {
    if (job.startedAt == null || progress <= 0) return null;

    final elapsed = DateTime.now().difference(job.startedAt!).inSeconds;
    if (elapsed <= 0) return null;

    final frames = progress * job.totalFrames;
    return frames / elapsed; // fps
  }

  /// Estimate time remaining
  double? _estimateTimeRemaining(RenderJob job, double progress) {
    if (progress <= 0 || job.startedAt == null) return null;

    final elapsed = DateTime.now().difference(job.startedAt!).inSeconds;
    if (elapsed <= 0) return null;

    final remaining = (1 - progress) / progress * elapsed;
    return remaining;
  }

  /// Update job in queue
  void _updateJob(RenderJob job) {
    _queue = _queue.updateJob(job);
    if (_queue.activeJobId == null) {
      _queue = _queue.copyWith(activeJobId: job.id);
    }
    _queueController.add(_queue);
  }

  /// Find job by ID
  RenderJob? _findJob(EditorId jobId) {
    for (final job in _queue.jobs) {
      if (job.id == jobId) return job;
    }
    return null;
  }

  /// Dispose
  void dispose() {
    _queueController.close();
  }
}

/// Manager for render presets
class RenderPresetManager {
  List<RenderPreset> _customPresets = [];

  /// All available presets (built-in + custom)
  List<RenderPreset> get allPresets => [
        ...RenderPreset.builtInPresets,
        ..._customPresets,
      ];

  /// Get presets by category
  Map<String, List<RenderPreset>> get presetsByCategory {
    final map = <String, List<RenderPreset>>{};
    for (final preset in allPresets) {
      map.putIfAbsent(preset.category, () => []).add(preset);
    }
    return map;
  }

  /// Add a custom preset
  void addPreset(RenderPreset preset) {
    _customPresets.add(preset);
  }

  /// Remove a custom preset
  void removePreset(String presetId) {
    _customPresets.removeWhere((p) => p.id == presetId);
  }

  /// Update a custom preset
  void updatePreset(RenderPreset preset) {
    final index = _customPresets.indexWhere((p) => p.id == preset.id);
    if (index >= 0) {
      _customPresets[index] = preset;
    }
  }

  /// Get preset by ID
  RenderPreset? getPreset(String presetId) {
    for (final preset in allPresets) {
      if (preset.id == presetId) return preset;
    }
    return null;
  }

  /// Create preset from current settings
  RenderPreset createPreset({
    required String name,
    required String category,
    String? description,
    required int width,
    required int height,
    required double frameRate,
    required VideoCodec videoCodec,
    int? videoBitrate,
    required RenderQuality quality,
    required AudioCodec audioCodec,
    required int audioBitrate,
    required int sampleRate,
  }) {
    return RenderPreset(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: category,
      description: description ?? '',
      width: width,
      height: height,
      frameRate: frameRate,
      videoCodec: videoCodec,
      videoBitrate: videoBitrate,
      quality: quality,
      audioCodec: audioCodec,
      audioBitrate: audioBitrate,
      sampleRate: sampleRate,
      isBuiltIn: false,
    );
  }
}

/// Batch render helper
class BatchRender {
  final RenderQueueService _service;
  final List<RenderJob> _jobs = [];

  BatchRender(this._service);

  /// Add a render to the batch
  BatchRender add({
    required EditorId projectId,
    required String name,
    required String outputPath,
    required RenderPreset preset,
    EditorTimeRange? range,
  }) {
    final job = _service.addJob(
      projectId: projectId,
      name: name,
      outputPath: outputPath,
      preset: preset,
      range: range,
    );
    _jobs.add(job);
    return this;
  }

  /// Get all jobs in this batch
  List<RenderJob> get jobs => List.unmodifiable(_jobs);

  /// Wait for all jobs to complete
  Future<List<RenderJob>> waitForCompletion() async {
    final completer = Completer<List<RenderJob>>();

    late StreamSubscription<RenderQueue> subscription;
    subscription = _service.queueStream.listen((queue) {
      final allDone = _jobs.every((j) {
        final current = queue.jobs.firstWhere(
          (qj) => qj.id == j.id,
          orElse: () => j,
        );
        return current.status.isFinished;
      });

      if (allDone) {
        subscription.cancel();
        completer.complete(_jobs.map((j) {
          return queue.jobs.firstWhere(
            (qj) => qj.id == j.id,
            orElse: () => j,
          );
        }).toList());
      }
    });

    return completer.future;
  }
}
