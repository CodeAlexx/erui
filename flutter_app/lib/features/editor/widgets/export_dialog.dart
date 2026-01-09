import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../models/editor_models.dart';
import '../providers/editor_provider.dart';
import '../services/ffmpeg_service.dart';

/// Output format options for video export
enum ExportFormat {
  mp4('MP4', 'mp4', 'libx264', 'aac'),
  webm('WebM', 'webm', 'libvpx-vp9', 'libopus'),
  gif('GIF', 'gif', 'gif', null);

  final String label;
  final String extension;
  final String videoCodec;
  final String? audioCodec;

  const ExportFormat(this.label, this.extension, this.videoCodec, this.audioCodec);
}

/// Resolution preset options
enum ExportResolution {
  original('Original', null, null),
  hd1080('1080p (1920x1080)', 1920, 1080),
  hd720('720p (1280x720)', 1280, 720),
  sd480('480p (854x480)', 854, 480),
  custom('Custom', null, null);

  final String label;
  final int? width;
  final int? height;

  const ExportResolution(this.label, this.width, this.height);
}

/// Frame rate options
enum ExportFrameRate {
  fps24('24 fps', 24.0),
  fps30('30 fps', 30.0),
  fps60('60 fps', 60.0);

  final String label;
  final double value;

  const ExportFrameRate(this.label, this.value);
}

/// Quality preset options
enum ExportQuality {
  low('Low', 28, 64000),
  medium('Medium', 23, 128000),
  high('High', 18, 192000),
  lossless('Lossless', 0, 320000);

  final String label;
  final int crf;
  final int audioBitrate;

  const ExportQuality(this.label, this.crf, this.audioBitrate);
}

/// Export state for tracking progress
enum ExportState {
  idle,
  exporting,
  completed,
  cancelled,
  error,
}

/// State notifier for export dialog
class ExportDialogNotifier extends StateNotifier<ExportDialogState> {
  final FFmpegService _ffmpegService;
  final EditorProject _project;

  ExportDialogNotifier(this._ffmpegService, this._project)
      : super(ExportDialogState(
          format: ExportFormat.mp4,
          resolution: ExportResolution.original,
          frameRate: ExportFrameRate.fps30,
          quality: ExportQuality.medium,
          includeAudio: true,
          customWidth: _project.settings.width,
          customHeight: _project.settings.height,
        )) {
    _updateEstimatedSize();
  }

  /// Update export format
  void setFormat(ExportFormat format) {
    state = state.copyWith(format: format);
    _updateEstimatedSize();
  }

  /// Update resolution preset
  void setResolution(ExportResolution resolution) {
    state = state.copyWith(resolution: resolution);
    _updateEstimatedSize();
  }

  /// Update frame rate
  void setFrameRate(ExportFrameRate frameRate) {
    state = state.copyWith(frameRate: frameRate);
    _updateEstimatedSize();
  }

  /// Update quality
  void setQuality(ExportQuality quality) {
    state = state.copyWith(quality: quality);
    _updateEstimatedSize();
  }

  /// Toggle audio inclusion
  void setIncludeAudio(bool include) {
    state = state.copyWith(includeAudio: include);
    _updateEstimatedSize();
  }

  /// Update audio bitrate (in kbps)
  void setAudioBitrate(int bitrate) {
    state = state.copyWith(audioBitrateKbps: bitrate);
    _updateEstimatedSize();
  }

  /// Update custom width
  void setCustomWidth(int width) {
    state = state.copyWith(customWidth: width);
    _updateEstimatedSize();
  }

  /// Update custom height
  void setCustomHeight(int height) {
    state = state.copyWith(customHeight: height);
    _updateEstimatedSize();
  }

  /// Update output path
  void setOutputPath(String outputPath) {
    state = state.copyWith(outputPath: outputPath);
  }

  /// Calculate estimated file size based on current settings
  void _updateEstimatedSize() {
    final durationSeconds = _project.duration.inSeconds;
    if (durationSeconds <= 0) {
      state = state.copyWith(estimatedSizeBytes: 0);
      return;
    }

    // Get resolution
    int width;
    int height;
    if (state.resolution == ExportResolution.custom) {
      width = state.customWidth;
      height = state.customHeight;
    } else if (state.resolution == ExportResolution.original) {
      width = _project.settings.width;
      height = _project.settings.height;
    } else {
      width = state.resolution.width!;
      height = state.resolution.height!;
    }

    // Estimate video bitrate based on resolution, frame rate, and quality
    // Using rough estimates: base bitrate scales with pixels and frame rate
    final pixels = width * height;
    final pixelMultiplier = pixels / (1920 * 1080); // Relative to 1080p
    final fpsMultiplier = state.frameRate.value / 30.0;

    // Base bitrate for 1080p@30fps at each quality level (in bits/second)
    int baseBitrate;
    switch (state.quality) {
      case ExportQuality.low:
        baseBitrate = 2000000; // 2 Mbps
        break;
      case ExportQuality.medium:
        baseBitrate = 5000000; // 5 Mbps
        break;
      case ExportQuality.high:
        baseBitrate = 10000000; // 10 Mbps
        break;
      case ExportQuality.lossless:
        baseBitrate = 50000000; // 50 Mbps
        break;
    }

    // Apply format multiplier (WebM is typically larger, GIF much larger)
    double formatMultiplier = 1.0;
    if (state.format == ExportFormat.webm) {
      formatMultiplier = 1.2;
    } else if (state.format == ExportFormat.gif) {
      formatMultiplier = 3.0; // GIF is very inefficient
    }

    final videoBitrate = baseBitrate * pixelMultiplier * fpsMultiplier * formatMultiplier;
    final audioBitrate = state.includeAudio && state.format.audioCodec != null
        ? (state.audioBitrateKbps ?? (state.quality.audioBitrate ~/ 1000)) * 1000.0
        : 0.0;

    final totalBitrate = videoBitrate + audioBitrate;
    final estimatedBytes = (totalBitrate * durationSeconds / 8).round();

    state = state.copyWith(estimatedSizeBytes: estimatedBytes);
  }

  /// Pick output file path
  Future<void> pickOutputPath() async {
    final projectName = _project.name.replaceAll(RegExp(r'[^\w\s-]'), '_');
    final defaultFileName = '${projectName}_export.${state.format.extension}';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Video As',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: [state.format.extension],
    );

    if (result != null) {
      // Ensure correct extension
      String outputPath = result;
      if (!outputPath.endsWith('.${state.format.extension}')) {
        outputPath = '$outputPath.${state.format.extension}';
      }
      state = state.copyWith(outputPath: outputPath);
    }
  }

  /// Start the export process
  Future<void> startExport() async {
    if (state.outputPath == null || state.outputPath!.isEmpty) {
      state = state.copyWith(
        exportState: ExportState.error,
        errorMessage: 'Please select an output path',
      );
      return;
    }

    state = state.copyWith(
      exportState: ExportState.exporting,
      progress: 0.0,
      errorMessage: null,
    );

    try {
      // Build export clips from project tracks
      final exportClips = <ExportClip>[];

      for (int trackIndex = 0; trackIndex < _project.tracks.length; trackIndex++) {
        final track = _project.tracks[trackIndex];
        if (track.isMuted) continue;

        for (final clip in track.clips) {
          if (clip.sourcePath == null) continue;

          exportClips.add(ExportClip(
            sourcePath: clip.sourcePath!,
            sourceStart: Duration(microseconds: clip.sourceStart.microseconds),
            duration: Duration(microseconds: clip.duration.microseconds),
            timelineStart: Duration(microseconds: clip.timelineStart.microseconds),
            trackIndex: trackIndex,
            volume: track.volume,
            speed: 1.0,
          ));
        }
      }

      if (exportClips.isEmpty) {
        state = state.copyWith(
          exportState: ExportState.error,
          errorMessage: 'No clips to export',
        );
        return;
      }

      // Get resolution
      int width;
      int height;
      if (state.resolution == ExportResolution.custom) {
        width = state.customWidth;
        height = state.customHeight;
      } else if (state.resolution == ExportResolution.original) {
        width = _project.settings.width;
        height = _project.settings.height;
      } else {
        width = state.resolution.width!;
        height = state.resolution.height!;
      }

      // Determine encoder preset based on quality
      String preset;
      switch (state.quality) {
        case ExportQuality.low:
          preset = 'ultrafast';
          break;
        case ExportQuality.medium:
          preset = 'medium';
          break;
        case ExportQuality.high:
          preset = 'slow';
          break;
        case ExportQuality.lossless:
          preset = 'veryslow';
          break;
      }

      // Start export
      final success = await _ffmpegService.exportVideo(
        outputPath: state.outputPath!,
        clips: exportClips,
        width: width,
        height: height,
        frameRate: state.frameRate.value,
        codec: state.format.videoCodec,
        preset: preset,
        crf: state.quality.crf,
        audioCodec: state.includeAudio ? state.format.audioCodec : null,
        audioBitrate: state.includeAudio
            ? ((state.audioBitrateKbps ?? (state.quality.audioBitrate ~/ 1000)) * 1000)
            : null,
        onProgress: (progress) {
          if (state.exportState == ExportState.exporting) {
            state = state.copyWith(progress: progress);
          }
        },
      );

      if (state.exportState == ExportState.cancelled) {
        // Export was cancelled
        return;
      }

      if (success) {
        state = state.copyWith(
          exportState: ExportState.completed,
          progress: 1.0,
        );
      } else {
        state = state.copyWith(
          exportState: ExportState.error,
          errorMessage: 'Export failed. Check FFmpeg logs for details.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        exportState: ExportState.error,
        errorMessage: 'Export error: $e',
      );
    }
  }

  /// Cancel the export process
  Future<void> cancelExport() async {
    state = state.copyWith(exportState: ExportState.cancelled);
    await _ffmpegService.cancelAll();
  }

  /// Reset to idle state
  void reset() {
    state = state.copyWith(
      exportState: ExportState.idle,
      progress: 0.0,
      errorMessage: null,
    );
  }
}

/// State for the export dialog
class ExportDialogState {
  final ExportFormat format;
  final ExportResolution resolution;
  final ExportFrameRate frameRate;
  final ExportQuality quality;
  final bool includeAudio;
  final int? audioBitrateKbps;
  final int customWidth;
  final int customHeight;
  final String? outputPath;
  final ExportState exportState;
  final double progress;
  final int estimatedSizeBytes;
  final String? errorMessage;

  const ExportDialogState({
    required this.format,
    required this.resolution,
    required this.frameRate,
    required this.quality,
    required this.includeAudio,
    this.audioBitrateKbps,
    required this.customWidth,
    required this.customHeight,
    this.outputPath,
    this.exportState = ExportState.idle,
    this.progress = 0.0,
    this.estimatedSizeBytes = 0,
    this.errorMessage,
  });

  ExportDialogState copyWith({
    ExportFormat? format,
    ExportResolution? resolution,
    ExportFrameRate? frameRate,
    ExportQuality? quality,
    bool? includeAudio,
    int? audioBitrateKbps,
    int? customWidth,
    int? customHeight,
    String? outputPath,
    ExportState? exportState,
    double? progress,
    int? estimatedSizeBytes,
    String? errorMessage,
  }) {
    return ExportDialogState(
      format: format ?? this.format,
      resolution: resolution ?? this.resolution,
      frameRate: frameRate ?? this.frameRate,
      quality: quality ?? this.quality,
      includeAudio: includeAudio ?? this.includeAudio,
      audioBitrateKbps: audioBitrateKbps ?? this.audioBitrateKbps,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      outputPath: outputPath ?? this.outputPath,
      exportState: exportState ?? this.exportState,
      progress: progress ?? this.progress,
      estimatedSizeBytes: estimatedSizeBytes ?? this.estimatedSizeBytes,
      errorMessage: errorMessage,
    );
  }
}

/// Provider for the export dialog state
final exportDialogProvider = StateNotifierProvider.autoDispose
    .family<ExportDialogNotifier, ExportDialogState, EditorProject>(
  (ref, project) {
    final ffmpegService = ref.watch(ffmpegServiceProvider);
    return ExportDialogNotifier(ffmpegService, project);
  },
);

/// Shows the export dialog
Future<void> showExportDialog(BuildContext context) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const ExportDialog(),
  );
}

/// Export dialog widget
class ExportDialog extends ConsumerWidget {
  const ExportDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(editorProjectProvider).project;
    final state = ref.watch(exportDialogProvider(project));
    final notifier = ref.read(exportDialogProvider(project).notifier);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.movie_creation_outlined),
          const SizedBox(width: 12),
          const Text('Export Video'),
          const Spacer(),
          if (state.exportState == ExportState.idle)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: state.exportState == ExportState.exporting
            ? _ExportProgress(state: state, onCancel: notifier.cancelExport)
            : state.exportState == ExportState.completed
                ? _ExportCompleted(
                    outputPath: state.outputPath!,
                    onClose: () => Navigator.of(context).pop(),
                  )
                : state.exportState == ExportState.error
                    ? _ExportError(
                        errorMessage: state.errorMessage ?? 'Unknown error',
                        onRetry: notifier.reset,
                        onClose: () => Navigator.of(context).pop(),
                      )
                    : _ExportSettings(
                        state: state,
                        notifier: notifier,
                        projectSettings: project.settings,
                      ),
      ),
      actions: state.exportState == ExportState.idle
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: state.outputPath != null && state.outputPath!.isNotEmpty
                    ? () => notifier.startExport()
                    : null,
                icon: const Icon(Icons.save_alt),
                label: const Text('Export'),
              ),
            ]
          : null,
    );
  }
}

/// Export settings form
class _ExportSettings extends StatelessWidget {
  final ExportDialogState state;
  final ExportDialogNotifier notifier;
  final ProjectSettings projectSettings;

  const _ExportSettings({
    required this.state,
    required this.notifier,
    required this.projectSettings,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Output path
          const _SectionHeader(title: 'Output'),
          _OutputPathSelector(
            outputPath: state.outputPath,
            onPickPath: notifier.pickOutputPath,
          ),

          const SizedBox(height: 24),

          // Format settings
          const _SectionHeader(title: 'Format'),
          _DropdownSetting<ExportFormat>(
            label: 'Output Format',
            value: state.format,
            items: ExportFormat.values,
            itemLabel: (f) => f.label,
            onChanged: notifier.setFormat,
          ),

          const SizedBox(height: 16),

          // Resolution settings
          const _SectionHeader(title: 'Resolution'),
          _DropdownSetting<ExportResolution>(
            label: 'Resolution',
            value: state.resolution,
            items: ExportResolution.values,
            itemLabel: (r) => r == ExportResolution.original
                ? 'Original (${projectSettings.width}x${projectSettings.height})'
                : r.label,
            onChanged: notifier.setResolution,
          ),

          // Custom resolution inputs
          if (state.resolution == ExportResolution.custom)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Width',
                        suffixText: 'px',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: state.customWidth.toString()),
                      onChanged: (value) {
                        final width = int.tryParse(value);
                        if (width != null && width > 0) {
                          notifier.setCustomWidth(width);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('x'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        suffixText: 'px',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: state.customHeight.toString()),
                      onChanged: (value) {
                        final height = int.tryParse(value);
                        if (height != null && height > 0) {
                          notifier.setCustomHeight(height);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Frame rate
          _DropdownSetting<ExportFrameRate>(
            label: 'Frame Rate',
            value: state.frameRate,
            items: ExportFrameRate.values,
            itemLabel: (f) => f.label,
            onChanged: notifier.setFrameRate,
          ),

          const SizedBox(height: 16),

          // Quality
          const _SectionHeader(title: 'Quality'),
          _DropdownSetting<ExportQuality>(
            label: 'Quality',
            value: state.quality,
            items: ExportQuality.values,
            itemLabel: (q) => q.label,
            onChanged: notifier.setQuality,
          ),

          const SizedBox(height: 24),

          // Audio settings
          const _SectionHeader(title: 'Audio'),
          if (state.format == ExportFormat.gif)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'GIF format does not support audio',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Column(
              children: [
                CheckboxListTile(
                  title: const Text('Include Audio'),
                  value: state.includeAudio,
                  onChanged: (value) => notifier.setIncludeAudio(value ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
                if (state.includeAudio)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        const Text('Bitrate:'),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: state.audioBitrateKbps ?? (state.quality.audioBitrate ~/ 1000),
                          items: [64, 96, 128, 192, 256, 320]
                              .map((b) => DropdownMenuItem(
                                    value: b,
                                    child: Text('$b kbps'),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) notifier.setAudioBitrate(value);
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 24),

          // Estimated file size
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.storage, color: colorScheme.primary),
                const SizedBox(width: 12),
                const Text('Estimated Size:'),
                const Spacer(),
                Text(
                  _formatFileSize(state.estimatedSizeBytes),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Section header widget
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Output path selector widget
class _OutputPathSelector extends StatelessWidget {
  final String? outputPath;
  final VoidCallback onPickPath;

  const _OutputPathSelector({
    required this.outputPath,
    required this.onPickPath,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onPickPath,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_open,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: outputPath != null && outputPath!.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          path.basename(outputPath!),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          path.dirname(outputPath!),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  : Text(
                      'Choose output location...',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic dropdown setting widget
class _DropdownSetting<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T) onChanged;

  const _DropdownSetting({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label),
        ),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<T>(
            value: value,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: items
                .map((item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(itemLabel(item)),
                    ))
                .toList(),
            onChanged: (newValue) {
              if (newValue != null) onChanged(newValue);
            },
          ),
        ),
      ],
    );
  }
}

/// Export progress widget
class _ExportProgress extends StatelessWidget {
  final ExportDialogState state;
  final VoidCallback onCancel;

  const _ExportProgress({
    required this.state,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = (state.progress * 100).toStringAsFixed(1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: state.progress,
                  strokeWidth: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              Text(
                '$percentage%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Exporting video...',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          state.outputPath != null ? path.basename(state.outputPath!) : '',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(
          value: state.progress,
          backgroundColor: colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.cancel),
          label: const Text('Cancel Export'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Export completed widget
class _ExportCompleted extends StatelessWidget {
  final String outputPath;
  final VoidCallback onClose;

  const _ExportCompleted({
    required this.outputPath,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Export Complete!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.video_file, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path.basename(outputPath),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      path.dirname(outputPath),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _openContainingFolder(outputPath),
              icon: const Icon(Icons.folder_open),
              label: const Text('Show in Folder'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.done),
              label: const Text('Done'),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _openContainingFolder(String filePath) {
    final directory = path.dirname(filePath);
    if (Platform.isLinux) {
      Process.run('xdg-open', [directory]);
    } else if (Platform.isMacOS) {
      Process.run('open', [directory]);
    } else if (Platform.isWindows) {
      Process.run('explorer', [directory]);
    }
  }
}

/// Export error widget
class _ExportError extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const _ExportError({
    required this.errorMessage,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.error.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.error_outline,
            size: 64,
            color: colorScheme.error,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Export Failed',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  errorMessage,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              label: const Text('Close'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
