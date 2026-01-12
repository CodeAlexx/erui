import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../models/vid_train_prep_models.dart';
import '../services/vid_train_prep_service.dart';

/// Service provider for video operations
final vidTrainPrepServiceProvider = Provider<VidTrainPrepService>((ref) {
  return VidTrainPrepService();
});

/// Main state for VidTrainPrep feature
class VidTrainPrepState {
  final VidTrainProject project;
  final String? selectedVideoId;
  final String? selectedRangeId;
  final bool isLoading;
  final bool isExporting;
  final double exportProgress;
  final String? exportStatus;
  final String? error;

  const VidTrainPrepState({
    required this.project,
    this.selectedVideoId,
    this.selectedRangeId,
    this.isLoading = false,
    this.isExporting = false,
    this.exportProgress = 0.0,
    this.exportStatus,
    this.error,
  });

  factory VidTrainPrepState.initial() {
    return VidTrainPrepState(
      project: VidTrainProject.create(),
    );
  }

  VidTrainPrepState copyWith({
    VidTrainProject? project,
    String? selectedVideoId,
    String? selectedRangeId,
    bool? isLoading,
    bool? isExporting,
    double? exportProgress,
    String? exportStatus,
    String? error,
    // Allow explicitly clearing nullable fields
    bool clearSelectedVideoId = false,
    bool clearSelectedRangeId = false,
    bool clearExportStatus = false,
    bool clearError = false,
  }) {
    return VidTrainPrepState(
      project: project ?? this.project,
      selectedVideoId: clearSelectedVideoId ? null : (selectedVideoId ?? this.selectedVideoId),
      selectedRangeId: clearSelectedRangeId ? null : (selectedRangeId ?? this.selectedRangeId),
      isLoading: isLoading ?? this.isLoading,
      isExporting: isExporting ?? this.isExporting,
      exportProgress: exportProgress ?? this.exportProgress,
      exportStatus: clearExportStatus ? null : (exportStatus ?? this.exportStatus),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// State notifier for VidTrainPrep feature
class VidTrainPrepNotifier extends StateNotifier<VidTrainPrepState> {
  final Ref _ref;

  VidTrainPrepNotifier(this._ref) : super(VidTrainPrepState.initial());

  // ============================================================
  // Video Operations
  // ============================================================

  /// Load all videos from a folder
  Future<void> loadFolder(String folderPath) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        throw Exception('Directory does not exist: $folderPath');
      }

      final videoExtensions = {'.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'};
      final newVideos = <VideoSource>[];
      final service = _ref.read(vidTrainPrepServiceProvider);

      // Create thumbnails directory
      final thumbDir = Directory('${Directory.systemTemp.path}/eriui_vidprep_thumbs');
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }

      await for (final entity in dir.list()) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (videoExtensions.contains(ext)) {
            // Probe video for actual metadata
            final probedVideo = await service.probeVideo(entity.path);

            if (probedVideo != null) {
              // Generate thumbnail
              final thumbPath = await service.generateThumbnail(entity.path, thumbDir.path);

              final video = VideoSource.create(
                filePath: entity.path,
                fileName: path.basename(entity.path),
                width: probedVideo.width,
                height: probedVideo.height,
                fps: probedVideo.fps,
                frameCount: probedVideo.frameCount,
                fileSizeBytes: probedVideo.fileSizeBytes,
                thumbnailPath: thumbPath,
              );
              newVideos.add(video);
            } else {
              // Fallback if probe fails
              final video = VideoSource.create(
                filePath: entity.path,
                fileName: path.basename(entity.path),
                width: 1920,
                height: 1080,
                fps: 30.0,
                frameCount: 300,
                fileSizeBytes: await entity.length(),
              );
              newVideos.add(video);
            }
          }
        }
      }

      // Sort by filename
      newVideos.sort((a, b) => a.fileName.compareTo(b.fileName));

      // Add videos to project
      final updatedProject = state.project.copyWith(
        videos: [...state.project.videos, ...newVideos],
      );

      state = state.copyWith(
        project: updatedProject,
        isLoading: false,
      );

      // Select first video if none selected
      if (state.selectedVideoId == null && newVideos.isNotEmpty) {
        selectVideo(newVideos.first.id);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load folder: $e',
      );
    }
  }

  /// Add a single video to the project
  void addVideo(VideoSource video) {
    final videos = [...state.project.videos, video];
    state = state.copyWith(
      project: state.project.copyWith(videos: videos),
    );

    // Select if first video
    if (state.selectedVideoId == null) {
      selectVideo(video.id);
    }
  }

  /// Remove a video and all its ranges
  void removeVideo(String videoId) {
    // Remove video from list
    final videos = state.project.videos.where((v) => v.id != videoId).toList();

    // Remove ranges for this video
    final rangesByVideo = Map<VidTrainId, List<ClipRange>>.from(state.project.rangesByVideo);
    rangesByVideo.remove(videoId);

    // Clear selection if removing selected video
    final clearVideoSelection = state.selectedVideoId == videoId;
    final clearRangeSelection = clearVideoSelection ||
        (state.selectedRangeId != null &&
         state.project.rangesByVideo[videoId]?.any((r) => r.id == state.selectedRangeId) == true);

    state = state.copyWith(
      project: state.project.copyWith(
        videos: videos,
        rangesByVideo: rangesByVideo,
      ),
      clearSelectedVideoId: clearVideoSelection,
      clearSelectedRangeId: clearRangeSelection,
    );

    // Auto-select another video if available
    if (clearVideoSelection && videos.isNotEmpty) {
      selectVideo(videos.first.id);
    }
  }

  /// Select a video
  void selectVideo(String? videoId) {
    if (videoId == state.selectedVideoId) return;

    state = state.copyWith(
      selectedVideoId: videoId,
      clearSelectedVideoId: videoId == null,
      clearSelectedRangeId: true, // Clear range selection when changing video
    );
  }

  // ============================================================
  // Range Operations
  // ============================================================

  /// Add a new range to a video
  void addRange(
    String videoId, {
    int? startFrame,
    int? endFrame,
    String? caption,
  }) {
    final video = state.project.videoById(videoId);
    if (video == null) return;

    // Default to full video if no frames specified
    final start = startFrame ?? 0;
    final end = endFrame ?? (video.frameCount - 1);

    // Get existing ranges for ordering
    final existingRanges = state.project.rangesFor(videoId);
    final nextOrderIndex = existingRanges.isEmpty
        ? 0
        : existingRanges.map((r) => r.orderIndex).reduce((a, b) => a > b ? a : b) + 1;

    final range = ClipRange.create(
      videoId: videoId,
      startFrame: start,
      endFrame: end,
      caption: caption ?? '',
      orderIndex: nextOrderIndex,
    );

    // Add range to map
    final rangesByVideo = Map<VidTrainId, List<ClipRange>>.from(state.project.rangesByVideo);
    rangesByVideo[videoId] = [...existingRanges, range];

    state = state.copyWith(
      project: state.project.copyWith(rangesByVideo: rangesByVideo),
      selectedRangeId: range.id, // Auto-select new range
    );
  }

  /// Update an existing range
  void updateRange(
    String rangeId, {
    int? startFrame,
    int? endFrame,
    String? caption,
    CropRegion? crop,
    bool? useCrop,
  }) {
    final rangesByVideo = Map<VidTrainId, List<ClipRange>>.from(state.project.rangesByVideo);

    // Find and update the range
    for (final videoId in rangesByVideo.keys) {
      final ranges = rangesByVideo[videoId]!;
      final rangeIndex = ranges.indexWhere((r) => r.id == rangeId);

      if (rangeIndex != -1) {
        final oldRange = ranges[rangeIndex];
        final updatedRange = oldRange.copyWith(
          startFrame: startFrame,
          endFrame: endFrame,
          caption: caption,
          crop: crop,
          useCrop: useCrop,
        );

        rangesByVideo[videoId] = [
          ...ranges.sublist(0, rangeIndex),
          updatedRange,
          ...ranges.sublist(rangeIndex + 1),
        ];

        state = state.copyWith(
          project: state.project.copyWith(rangesByVideo: rangesByVideo),
        );
        return;
      }
    }
  }

  /// Delete a range
  void deleteRange(String rangeId) {
    final rangesByVideo = Map<VidTrainId, List<ClipRange>>.from(state.project.rangesByVideo);

    // Find and remove the range
    for (final videoId in rangesByVideo.keys) {
      final ranges = rangesByVideo[videoId]!;
      final rangeIndex = ranges.indexWhere((r) => r.id == rangeId);

      if (rangeIndex != -1) {
        rangesByVideo[videoId] = [
          ...ranges.sublist(0, rangeIndex),
          ...ranges.sublist(rangeIndex + 1),
        ];

        // Clear selection if deleting selected range
        final clearSelection = state.selectedRangeId == rangeId;

        state = state.copyWith(
          project: state.project.copyWith(rangesByVideo: rangesByVideo),
          clearSelectedRangeId: clearSelection,
        );
        return;
      }
    }
  }

  /// Select a range
  void selectRange(String? rangeId) {
    if (rangeId == state.selectedRangeId) return;

    state = state.copyWith(
      selectedRangeId: rangeId,
      clearSelectedRangeId: rangeId == null,
    );
  }

  // ============================================================
  // Crop Operations
  // ============================================================

  /// Set crop region for a range
  void setCropForRange(String rangeId, CropRegion crop) {
    updateRange(rangeId, crop: crop, useCrop: true);
  }

  /// Clear crop for a range (sets useCrop to false but preserves crop data)
  void clearCropForRange(String rangeId) {
    updateRange(rangeId, useCrop: false);
  }

  // ============================================================
  // Model Preset Operations
  // ============================================================

  /// Set the model preset
  void setModelPreset(String presetId) {
    final preset = ModelPresets.byId(presetId);
    if (preset == null) return;

    state = state.copyWith(
      project: state.project.copyWith(
        exportSettings: state.project.exportSettings.copyWith(
          modelPresetId: presetId,
          resolutionIndex: preset.defaultResolutionIndex,
        ),
      ),
    );
  }

  /// Set the resolution index within current preset
  void setResolutionIndex(int index) {
    final preset = state.project.exportSettings.modelPreset;
    if (preset == null || index < 0 || index >= preset.resolutions.length) {
      return;
    }

    state = state.copyWith(
      project: state.project.copyWith(
        exportSettings: state.project.exportSettings.copyWith(
          resolutionIndex: index,
        ),
      ),
    );
  }

  // ============================================================
  // Export Settings
  // ============================================================

  /// Update export settings
  void updateExportSettings(VidTrainExportSettings settings) {
    state = state.copyWith(
      project: state.project.copyWith(exportSettings: settings),
    );
  }

  /// Set output directory
  void setOutputDirectory(String outputDirectory) {
    state = state.copyWith(
      project: state.project.copyWith(
        exportSettings: state.project.exportSettings.copyWith(
          outputDirectory: outputDirectory,
        ),
      ),
    );
  }

  // ============================================================
  // Export State
  // ============================================================

  /// Set exporting state with progress and status
  void setExporting(bool isExporting, {double progress = 0, String? status}) {
    state = state.copyWith(
      isExporting: isExporting,
      exportProgress: progress,
      exportStatus: status,
      clearExportStatus: status == null && !isExporting,
    );
  }

  /// Update export progress
  void updateExportProgress(double progress, {String? status}) {
    state = state.copyWith(
      exportProgress: progress,
      exportStatus: status,
    );
  }

  // ============================================================
  // Error Handling
  // ============================================================

  /// Set an error message
  void setError(String? error) {
    state = state.copyWith(
      error: error,
      clearError: error == null,
    );
  }

  /// Clear current error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ============================================================
  // Project Management
  // ============================================================

  /// Create a new empty project
  void newProject() {
    state = VidTrainPrepState(
      project: VidTrainProject.create(),
    );
  }

  /// Set project name
  void setProjectName(String name) {
    state = state.copyWith(
      project: state.project.copyWith(name: name),
    );
  }

  /// Load a project (placeholder for serialization)
  void loadProject(VidTrainProject project) {
    state = VidTrainPrepState(
      project: project,
    );

    // Auto-select first video
    if (project.videos.isNotEmpty) {
      selectVideo(project.videos.first.id);
    }
  }

  // ============================================================
  // Utility Methods
  // ============================================================

  /// Duplicate a range
  void duplicateRange(String rangeId) {
    // Find the range
    for (final videoId in state.project.rangesByVideo.keys) {
      final ranges = state.project.rangesByVideo[videoId]!;
      final range = ranges.cast<ClipRange?>().firstWhere(
        (r) => r?.id == rangeId,
        orElse: () => null,
      );

      if (range != null) {
        addRange(
          videoId,
          startFrame: range.startFrame,
          endFrame: range.endFrame,
          caption: range.caption,
        );

        // Apply crop if present
        if (range.crop != null && range.useCrop) {
          final newRanges = state.project.rangesByVideo[videoId]!;
          final newRangeId = newRanges.last.id;
          setCropForRange(newRangeId, range.crop!);
        }
        return;
      }
    }
  }

  /// Split a range at a specific frame
  void splitRange(String rangeId, int splitFrame) {
    // Find the range
    for (final videoId in state.project.rangesByVideo.keys) {
      final ranges = state.project.rangesByVideo[videoId]!;
      final range = ranges.cast<ClipRange?>().firstWhere(
        (r) => r?.id == rangeId,
        orElse: () => null,
      );

      if (range != null && splitFrame > range.startFrame && splitFrame < range.endFrame) {
        // Update original range to end before split
        updateRange(rangeId, endFrame: splitFrame - 1);

        // Create new range starting from split
        addRange(
          videoId,
          startFrame: splitFrame,
          endFrame: range.endFrame,
          caption: range.caption,
        );

        // Apply crop if present
        if (range.crop != null && range.useCrop) {
          final newRanges = state.project.rangesByVideo[videoId]!;
          final newRangeId = newRanges.last.id;
          setCropForRange(newRangeId, range.crop!);
        }
        return;
      }
    }
  }

  /// Reorder ranges within a video
  void reorderRanges(String videoId, List<String> rangeIds) {
    final rangesByVideo = Map<VidTrainId, List<ClipRange>>.from(state.project.rangesByVideo);
    final ranges = rangesByVideo[videoId];

    if (ranges == null) return;

    // Create a map for quick lookup
    final rangeMap = {for (final r in ranges) r.id: r};

    // Reorder based on provided IDs
    final reordered = <ClipRange>[];
    for (var i = 0; i < rangeIds.length; i++) {
      final range = rangeMap[rangeIds[i]];
      if (range != null) {
        reordered.add(range.copyWith(orderIndex: i));
      }
    }

    rangesByVideo[videoId] = reordered;

    state = state.copyWith(
      project: state.project.copyWith(rangesByVideo: rangesByVideo),
    );
  }
}

// ============================================================
// Providers
// ============================================================

/// Main provider for VidTrainPrep state
final vidTrainPrepProvider = StateNotifierProvider<VidTrainPrepNotifier, VidTrainPrepState>(
  (ref) => VidTrainPrepNotifier(ref),
);

/// Provider for the currently selected video
final selectedVideoProvider = Provider<VideoSource?>((ref) {
  final state = ref.watch(vidTrainPrepProvider);
  if (state.selectedVideoId == null) return null;
  return state.project.videos.cast<VideoSource?>().firstWhere(
    (v) => v?.id == state.selectedVideoId,
    orElse: () => null,
  );
});

/// Provider for ranges of the currently selected video
final rangesForSelectedVideoProvider = Provider<List<ClipRange>>((ref) {
  final state = ref.watch(vidTrainPrepProvider);
  if (state.selectedVideoId == null) return [];
  return state.project.rangesByVideo[state.selectedVideoId] ?? [];
});

/// Provider for the currently selected range
final selectedRangeProvider = Provider<ClipRange?>((ref) {
  final state = ref.watch(vidTrainPrepProvider);
  if (state.selectedRangeId == null) return null;
  for (final ranges in state.project.rangesByVideo.values) {
    for (final range in ranges) {
      if (range.id == state.selectedRangeId) return range;
    }
  }
  return null;
});

/// Provider for current model preset
final currentModelPresetProvider = Provider<ModelPreset?>((ref) {
  final state = ref.watch(vidTrainPrepProvider);
  return state.project.exportSettings.modelPreset;
});

/// Provider for current resolution option
final currentResolutionProvider = Provider<ResolutionOption?>((ref) {
  final state = ref.watch(vidTrainPrepProvider);
  return state.project.exportSettings.resolution;
});

/// Provider for all videos in the project
final videosProvider = Provider<List<VideoSource>>((ref) {
  return ref.watch(vidTrainPrepProvider).project.videos;
});

/// Provider for total range count
final totalRangeCountProvider = Provider<int>((ref) {
  return ref.watch(vidTrainPrepProvider).project.totalRangeCount;
});

/// Provider for export settings
final exportSettingsProvider = Provider<VidTrainExportSettings>((ref) {
  return ref.watch(vidTrainPrepProvider).project.exportSettings;
});

/// Provider for loading state
final isLoadingProvider = Provider<bool>((ref) {
  return ref.watch(vidTrainPrepProvider).isLoading;
});

/// Provider for exporting state
final isExportingProvider = Provider<bool>((ref) {
  return ref.watch(vidTrainPrepProvider).isExporting;
});

/// Provider for export progress (0.0 - 1.0)
final exportProgressProvider = Provider<double>((ref) {
  return ref.watch(vidTrainPrepProvider).exportProgress;
});

/// Provider for export status message
final exportStatusProvider = Provider<String?>((ref) {
  return ref.watch(vidTrainPrepProvider).exportStatus;
});

/// Provider for error state
final errorProvider = Provider<String?>((ref) {
  return ref.watch(vidTrainPrepProvider).error;
});

/// Provider for checking if a specific range is selected
final isRangeSelectedProvider = Provider.family<bool, String>((ref, rangeId) {
  return ref.watch(vidTrainPrepProvider).selectedRangeId == rangeId;
});

/// Provider for checking if a specific video is selected
final isVideoSelectedProvider = Provider.family<bool, String>((ref, videoId) {
  return ref.watch(vidTrainPrepProvider).selectedVideoId == videoId;
});
