import 'dart:ui';
import 'editor_models.dart';

/// Status of a render job
enum RenderStatus {
  queued,
  preparing,
  rendering,
  encoding,
  completed,
  failed,
  cancelled,
  paused,
}

extension RenderStatusExtension on RenderStatus {
  String get displayName {
    switch (this) {
      case RenderStatus.queued:
        return 'Queued';
      case RenderStatus.preparing:
        return 'Preparing';
      case RenderStatus.rendering:
        return 'Rendering';
      case RenderStatus.encoding:
        return 'Encoding';
      case RenderStatus.completed:
        return 'Completed';
      case RenderStatus.failed:
        return 'Failed';
      case RenderStatus.cancelled:
        return 'Cancelled';
      case RenderStatus.paused:
        return 'Paused';
    }
  }

  bool get isActive =>
      this == RenderStatus.preparing ||
      this == RenderStatus.rendering ||
      this == RenderStatus.encoding;

  bool get isFinished =>
      this == RenderStatus.completed ||
      this == RenderStatus.failed ||
      this == RenderStatus.cancelled;

  Color get color {
    switch (this) {
      case RenderStatus.queued:
        return const Color(0xFF9E9E9E);
      case RenderStatus.preparing:
        return const Color(0xFF2196F3);
      case RenderStatus.rendering:
        return const Color(0xFF4CAF50);
      case RenderStatus.encoding:
        return const Color(0xFF8BC34A);
      case RenderStatus.completed:
        return const Color(0xFF4CAF50);
      case RenderStatus.failed:
        return const Color(0xFFF44336);
      case RenderStatus.cancelled:
        return const Color(0xFFFF9800);
      case RenderStatus.paused:
        return const Color(0xFFFFC107);
    }
  }
}

/// Video codec options
enum VideoCodec {
  h264,
  h265,
  prores,
  dnxhd,
  vp9,
  av1,
}

extension VideoCodecExtension on VideoCodec {
  String get displayName {
    switch (this) {
      case VideoCodec.h264:
        return 'H.264 (AVC)';
      case VideoCodec.h265:
        return 'H.265 (HEVC)';
      case VideoCodec.prores:
        return 'Apple ProRes';
      case VideoCodec.dnxhd:
        return 'Avid DNxHD';
      case VideoCodec.vp9:
        return 'VP9';
      case VideoCodec.av1:
        return 'AV1';
    }
  }

  String get ffmpegCodec {
    switch (this) {
      case VideoCodec.h264:
        return 'libx264';
      case VideoCodec.h265:
        return 'libx265';
      case VideoCodec.prores:
        return 'prores_ks';
      case VideoCodec.dnxhd:
        return 'dnxhd';
      case VideoCodec.vp9:
        return 'libvpx-vp9';
      case VideoCodec.av1:
        return 'libaom-av1';
    }
  }

  String get fileExtension {
    switch (this) {
      case VideoCodec.h264:
      case VideoCodec.h265:
        return 'mp4';
      case VideoCodec.prores:
        return 'mov';
      case VideoCodec.dnxhd:
        return 'mxf';
      case VideoCodec.vp9:
      case VideoCodec.av1:
        return 'webm';
    }
  }
}

/// Audio codec options
enum AudioCodec {
  aac,
  mp3,
  pcm,
  flac,
  opus,
}

extension AudioCodecExtension on AudioCodec {
  String get displayName {
    switch (this) {
      case AudioCodec.aac:
        return 'AAC';
      case AudioCodec.mp3:
        return 'MP3';
      case AudioCodec.pcm:
        return 'PCM (Uncompressed)';
      case AudioCodec.flac:
        return 'FLAC';
      case AudioCodec.opus:
        return 'Opus';
    }
  }

  String get ffmpegCodec {
    switch (this) {
      case AudioCodec.aac:
        return 'aac';
      case AudioCodec.mp3:
        return 'libmp3lame';
      case AudioCodec.pcm:
        return 'pcm_s16le';
      case AudioCodec.flac:
        return 'flac';
      case AudioCodec.opus:
        return 'libopus';
    }
  }
}

/// Render quality preset
enum RenderQuality {
  draft,
  preview,
  standard,
  high,
  maximum,
}

extension RenderQualityExtension on RenderQuality {
  String get displayName {
    switch (this) {
      case RenderQuality.draft:
        return 'Draft (Fast)';
      case RenderQuality.preview:
        return 'Preview';
      case RenderQuality.standard:
        return 'Standard';
      case RenderQuality.high:
        return 'High';
      case RenderQuality.maximum:
        return 'Maximum';
    }
  }

  int get crf {
    switch (this) {
      case RenderQuality.draft:
        return 32;
      case RenderQuality.preview:
        return 28;
      case RenderQuality.standard:
        return 23;
      case RenderQuality.high:
        return 18;
      case RenderQuality.maximum:
        return 14;
    }
  }

  String get ffmpegPreset {
    switch (this) {
      case RenderQuality.draft:
        return 'ultrafast';
      case RenderQuality.preview:
        return 'veryfast';
      case RenderQuality.standard:
        return 'medium';
      case RenderQuality.high:
        return 'slow';
      case RenderQuality.maximum:
        return 'veryslow';
    }
  }
}

/// Render preset with all settings
class RenderPreset {
  final String id;
  final String name;
  final String category;
  final String description;

  /// Video settings
  final int width;
  final int height;
  final double frameRate;
  final VideoCodec videoCodec;
  final int? videoBitrate; // in kbps, null for auto
  final RenderQuality quality;

  /// Audio settings
  final AudioCodec audioCodec;
  final int audioBitrate; // in kbps
  final int sampleRate;

  /// Whether this is a built-in preset
  final bool isBuiltIn;

  const RenderPreset({
    required this.id,
    required this.name,
    this.category = 'Custom',
    this.description = '',
    this.width = 1920,
    this.height = 1080,
    this.frameRate = 30.0,
    this.videoCodec = VideoCodec.h264,
    this.videoBitrate,
    this.quality = RenderQuality.standard,
    this.audioCodec = AudioCodec.aac,
    this.audioBitrate = 192,
    this.sampleRate = 48000,
    this.isBuiltIn = false,
  });

  RenderPreset copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    int? width,
    int? height,
    double? frameRate,
    VideoCodec? videoCodec,
    int? videoBitrate,
    RenderQuality? quality,
    AudioCodec? audioCodec,
    int? audioBitrate,
    int? sampleRate,
    bool? isBuiltIn,
  }) {
    return RenderPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      width: width ?? this.width,
      height: height ?? this.height,
      frameRate: frameRate ?? this.frameRate,
      videoCodec: videoCodec ?? this.videoCodec,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      quality: quality ?? this.quality,
      audioCodec: audioCodec ?? this.audioCodec,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  /// Resolution string
  String get resolution => '${width}x$height';

  /// Generate FFmpeg video codec options
  String toFfmpegVideoArgs() {
    final args = StringBuffer();

    args.write('-c:v ${videoCodec.ffmpegCodec} ');

    if (videoCodec == VideoCodec.h264 || videoCodec == VideoCodec.h265) {
      args.write('-preset ${quality.ffmpegPreset} ');
      args.write('-crf ${quality.crf} ');
    }

    if (videoBitrate != null) {
      args.write('-b:v ${videoBitrate}k ');
    }

    args.write('-s ${width}x$height ');
    args.write('-r $frameRate ');

    return args.toString().trim();
  }

  /// Generate FFmpeg audio codec options
  String toFfmpegAudioArgs() {
    return '-c:a ${audioCodec.ffmpegCodec} -b:a ${audioBitrate}k -ar $sampleRate';
  }

  /// Built-in presets
  static const List<RenderPreset> builtInPresets = [
    // Social Media
    RenderPreset(
      id: 'youtube_1080p',
      name: 'YouTube 1080p',
      category: 'Social Media',
      description: 'Optimized for YouTube at 1080p',
      width: 1920,
      height: 1080,
      frameRate: 30.0,
      videoCodec: VideoCodec.h264,
      quality: RenderQuality.high,
      isBuiltIn: true,
    ),
    RenderPreset(
      id: 'youtube_4k',
      name: 'YouTube 4K',
      category: 'Social Media',
      description: 'Optimized for YouTube at 4K',
      width: 3840,
      height: 2160,
      frameRate: 30.0,
      videoCodec: VideoCodec.h265,
      quality: RenderQuality.high,
      isBuiltIn: true,
    ),
    RenderPreset(
      id: 'instagram_square',
      name: 'Instagram Square',
      category: 'Social Media',
      description: '1:1 aspect ratio for Instagram',
      width: 1080,
      height: 1080,
      frameRate: 30.0,
      videoCodec: VideoCodec.h264,
      quality: RenderQuality.standard,
      isBuiltIn: true,
    ),
    RenderPreset(
      id: 'tiktok_vertical',
      name: 'TikTok/Reels',
      category: 'Social Media',
      description: '9:16 vertical format',
      width: 1080,
      height: 1920,
      frameRate: 30.0,
      videoCodec: VideoCodec.h264,
      quality: RenderQuality.standard,
      isBuiltIn: true,
    ),

    // Professional
    RenderPreset(
      id: 'prores_422',
      name: 'ProRes 422',
      category: 'Professional',
      description: 'Apple ProRes 422 for editing',
      width: 1920,
      height: 1080,
      frameRate: 24.0,
      videoCodec: VideoCodec.prores,
      quality: RenderQuality.high,
      audioCodec: AudioCodec.pcm,
      isBuiltIn: true,
    ),
    RenderPreset(
      id: 'dnxhd_185',
      name: 'DNxHD 185',
      category: 'Professional',
      description: 'Avid DNxHD for broadcast',
      width: 1920,
      height: 1080,
      frameRate: 24.0,
      videoCodec: VideoCodec.dnxhd,
      videoBitrate: 185000,
      quality: RenderQuality.maximum,
      audioCodec: AudioCodec.pcm,
      isBuiltIn: true,
    ),

    // Web
    RenderPreset(
      id: 'web_720p',
      name: 'Web 720p',
      category: 'Web',
      description: 'Small file size for web',
      width: 1280,
      height: 720,
      frameRate: 30.0,
      videoCodec: VideoCodec.h264,
      quality: RenderQuality.standard,
      isBuiltIn: true,
    ),
    RenderPreset(
      id: 'web_vp9',
      name: 'Web VP9',
      category: 'Web',
      description: 'VP9 for modern browsers',
      width: 1920,
      height: 1080,
      frameRate: 30.0,
      videoCodec: VideoCodec.vp9,
      quality: RenderQuality.standard,
      audioCodec: AudioCodec.opus,
      isBuiltIn: true,
    ),

    // Archive
    RenderPreset(
      id: 'archive_lossless',
      name: 'Lossless Archive',
      category: 'Archive',
      description: 'Maximum quality for archival',
      width: 1920,
      height: 1080,
      frameRate: 24.0,
      videoCodec: VideoCodec.h264,
      quality: RenderQuality.maximum,
      audioCodec: AudioCodec.flac,
      isBuiltIn: true,
    ),
  ];
}

/// A single render job
class RenderJob {
  final EditorId id;

  /// Project being rendered
  final EditorId projectId;

  /// Display name for this job
  final String name;

  /// Output file path
  final String outputPath;

  /// Render preset used
  final RenderPreset preset;

  /// Current status
  final RenderStatus status;

  /// Progress (0.0 - 1.0)
  final double progress;

  /// Current frame being rendered
  final int currentFrame;

  /// Total frames to render
  final int totalFrames;

  /// Time range to render (null = full project)
  final EditorTimeRange? range;

  /// Error message if failed
  final String? errorMessage;

  /// When job was created
  final DateTime createdAt;

  /// When job started rendering
  final DateTime? startedAt;

  /// When job completed
  final DateTime? completedAt;

  /// Estimated time remaining in seconds
  final double? estimatedTimeRemaining;

  /// Current rendering speed (frames per second)
  final double? renderSpeed;

  const RenderJob({
    required this.id,
    required this.projectId,
    required this.name,
    required this.outputPath,
    required this.preset,
    this.status = RenderStatus.queued,
    this.progress = 0.0,
    this.currentFrame = 0,
    this.totalFrames = 0,
    this.range,
    this.errorMessage,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.estimatedTimeRemaining,
    this.renderSpeed,
  });

  RenderJob copyWith({
    EditorId? id,
    EditorId? projectId,
    String? name,
    String? outputPath,
    RenderPreset? preset,
    RenderStatus? status,
    double? progress,
    int? currentFrame,
    int? totalFrames,
    EditorTimeRange? range,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    double? estimatedTimeRemaining,
    double? renderSpeed,
  }) {
    return RenderJob(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      outputPath: outputPath ?? this.outputPath,
      preset: preset ?? this.preset,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentFrame: currentFrame ?? this.currentFrame,
      totalFrames: totalFrames ?? this.totalFrames,
      range: range ?? this.range,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      estimatedTimeRemaining: estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      renderSpeed: renderSpeed ?? this.renderSpeed,
    );
  }

  /// Duration of rendering
  Duration? get renderDuration {
    if (startedAt == null) return null;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  /// Formatted progress string
  String get progressString => '${(progress * 100).toStringAsFixed(1)}%';

  /// Formatted ETA string
  String get etaString {
    if (estimatedTimeRemaining == null) return '--:--';
    final seconds = estimatedTimeRemaining!.round();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

/// Render queue state
class RenderQueue {
  /// List of all jobs
  final List<RenderJob> jobs;

  /// Currently active job ID
  final EditorId? activeJobId;

  /// Whether queue is paused
  final bool isPaused;

  /// Maximum concurrent renders
  final int maxConcurrent;

  const RenderQueue({
    this.jobs = const [],
    this.activeJobId,
    this.isPaused = false,
    this.maxConcurrent = 1,
  });

  RenderQueue copyWith({
    List<RenderJob>? jobs,
    EditorId? activeJobId,
    bool? isPaused,
    int? maxConcurrent,
  }) {
    return RenderQueue(
      jobs: jobs ?? List.from(this.jobs),
      activeJobId: activeJobId ?? this.activeJobId,
      isPaused: isPaused ?? this.isPaused,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
    );
  }

  /// Get active job
  RenderJob? get activeJob {
    if (activeJobId == null) return null;
    for (final job in jobs) {
      if (job.id == activeJobId) return job;
    }
    return null;
  }

  /// Get queued jobs
  List<RenderJob> get queuedJobs =>
      jobs.where((j) => j.status == RenderStatus.queued).toList();

  /// Get completed jobs
  List<RenderJob> get completedJobs =>
      jobs.where((j) => j.status == RenderStatus.completed).toList();

  /// Get failed jobs
  List<RenderJob> get failedJobs =>
      jobs.where((j) => j.status == RenderStatus.failed).toList();

  /// Get next job in queue
  RenderJob? get nextJob =>
      queuedJobs.isEmpty ? null : queuedJobs.first;

  /// Add a job to the queue
  RenderQueue addJob(RenderJob job) {
    return copyWith(jobs: [...jobs, job]);
  }

  /// Remove a job from the queue
  RenderQueue removeJob(EditorId jobId) {
    return copyWith(
      jobs: jobs.where((j) => j.id != jobId).toList(),
    );
  }

  /// Update a job
  RenderQueue updateJob(RenderJob job) {
    return copyWith(
      jobs: jobs.map((j) => j.id == job.id ? job : j).toList(),
    );
  }

  /// Clear completed jobs
  RenderQueue clearCompleted() {
    return copyWith(
      jobs: jobs.where((j) => !j.status.isFinished).toList(),
    );
  }
}
