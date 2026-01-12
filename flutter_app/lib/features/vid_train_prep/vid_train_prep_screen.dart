import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'providers/vid_train_prep_provider.dart';
import 'models/vid_train_prep_models.dart';
import 'widgets/video_preview.dart';
import 'widgets/range_timeline_widget.dart';

/// VidTrainPrep Screen - Video Training Dataset Preparation
///
/// Layout:
/// ┌──────────────────────────────────────────────────────────────┐
/// │ Toolbar: [Model▼] [Resolution▼] [Import Folder] [Export All] │
/// ├──────────────┬─────────────────────────┬────────────────────┤
/// │ Video List   │   Video Preview         │  Range List        │
/// │ (280px)      │   (Expanded)            │  (300px)           │
/// ├──────────────┴─────────────────────────┴────────────────────┤
/// │ Timeline strip (100px height)                                │
/// └──────────────────────────────────────────────────────────────┘
class VidTrainPrepScreen extends ConsumerStatefulWidget {
  const VidTrainPrepScreen({super.key});

  @override
  ConsumerState<VidTrainPrepScreen> createState() => _VidTrainPrepScreenState();
}

class _VidTrainPrepScreenState extends ConsumerState<VidTrainPrepScreen> {
  // Panel sizes for resizable layout
  double _leftPanelWidth = 280;
  double _rightPanelWidth = 300;

  // Minimum panel widths
  static const double _minLeftPanelWidth = 200;
  static const double _maxLeftPanelWidth = 400;
  static const double _minRightPanelWidth = 220;
  static const double _maxRightPanelWidth = 450;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(vidTrainPrepProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          // Toolbar
          _buildToolbar(context, colorScheme, state),

          // Main content area
          Expanded(
            child: Row(
              children: [
                // Left panel - Video list
                SizedBox(
                  width: _leftPanelWidth,
                  child: _buildVideoListPanel(context, colorScheme, state),
                ),

                // Left divider (resizable)
                _buildResizableDivider(
                  colorScheme: colorScheme,
                  onDrag: (delta) {
                    setState(() {
                      _leftPanelWidth = (_leftPanelWidth + delta)
                          .clamp(_minLeftPanelWidth, _maxLeftPanelWidth);
                    });
                  },
                ),

                // Center - Preview + Timeline
                Expanded(
                  child: Column(
                    children: [
                      // Video preview
                      Expanded(
                        child: _buildPreviewPanel(context, colorScheme, state),
                      ),

                      // Timeline divider
                      Container(
                        height: 1,
                        color: colorScheme.outlineVariant.withOpacity(0.3),
                      ),

                      // Timeline strip
                      SizedBox(
                        height: 100,
                        child: _buildTimelinePanel(context, colorScheme, state),
                      ),
                    ],
                  ),
                ),

                // Right divider (resizable)
                _buildResizableDivider(
                  colorScheme: colorScheme,
                  onDrag: (delta) {
                    setState(() {
                      _rightPanelWidth = (_rightPanelWidth - delta)
                          .clamp(_minRightPanelWidth, _maxRightPanelWidth);
                    });
                  },
                ),

                // Right panel - Range list
                SizedBox(
                  width: _rightPanelWidth,
                  child: _buildRangeListPanel(context, colorScheme, state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the top toolbar with model preset, resolution, import, and export controls
  Widget _buildToolbar(BuildContext context, ColorScheme colorScheme, VidTrainPrepState state) {
    final currentPreset = ref.watch(currentModelPresetProvider);
    final currentResolution = ref.watch(currentResolutionProvider);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Project name / title
          Text(
            state.project.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(width: 24),

          // Model preset dropdown
          _buildDropdown<ModelPreset>(
            label: 'Model',
            value: currentPreset,
            items: ModelPresets.all,
            itemBuilder: (preset) => preset.name,
            onChanged: (preset) {
              if (preset != null) {
                ref.read(vidTrainPrepProvider.notifier).setModelPreset(preset.id);
              }
            },
            colorScheme: colorScheme,
          ),

          const SizedBox(width: 12),

          // Resolution dropdown
          if (currentPreset != null)
            _buildDropdown<ResolutionOption>(
              label: 'Resolution',
              value: currentResolution,
              items: currentPreset.resolutions,
              itemBuilder: (res) => res.label,
              onChanged: (res) {
                if (res != null) {
                  final index = currentPreset.resolutions.indexOf(res);
                  ref.read(vidTrainPrepProvider.notifier).setResolutionIndex(index);
                }
              },
              colorScheme: colorScheme,
            ),

          const Spacer(),

          // Video/Range stats
          if (state.project.videos.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${state.project.videoCount} videos, ${state.project.totalRangeCount} ranges',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          const SizedBox(width: 16),

          // Import Folder button
          ElevatedButton.icon(
            onPressed: state.isLoading ? null : _importFolder,
            icon: state.isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.folder_open, size: 18),
            label: const Text('Import Folder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
          ),

          const SizedBox(width: 8),

          // Export All button
          FilledButton.icon(
            onPressed: state.project.totalRangeCount > 0 && !state.isExporting
                ? _exportAll
                : null,
            icon: state.isExporting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.file_download, size: 18),
            label: Text(state.isExporting ? 'Exporting...' : 'Export All'),
          ),
        ],
      ),
    );
  }

  /// Builds a dropdown selector with label
  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required void Function(T?) onChanged,
    required ColorScheme colorScheme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemBuilder(item),
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              dropdownColor: colorScheme.surfaceContainerHighest,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a resizable divider between panels
  Widget _buildResizableDivider({
    required ColorScheme colorScheme,
    required void Function(double) onDrag,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: Container(
          width: 6,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              color: colorScheme.outlineVariant.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the left panel - Video list
  Widget _buildVideoListPanel(BuildContext context, ColorScheme colorScheme, VidTrainPrepState state) {
    final videos = state.project.videos;

    return Container(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.video_library, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Videos',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${videos.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Video list
          Expanded(
            child: videos.isEmpty
                ? _buildEmptyState(
                    icon: Icons.video_library_outlined,
                    message: 'No videos loaded',
                    hint: 'Click Import Folder to add videos',
                    colorScheme: colorScheme,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: videos.length,
                    itemBuilder: (context, index) {
                      final video = videos[index];
                      final isSelected = state.selectedVideoId == video.id;
                      final rangeCount = state.project.rangesFor(video.id).length;

                      return _buildVideoListItem(
                        video: video,
                        isSelected: isSelected,
                        rangeCount: rangeCount,
                        colorScheme: colorScheme,
                        onTap: () {
                          ref.read(vidTrainPrepProvider.notifier).selectVideo(video.id);
                        },
                        onDelete: () {
                          ref.read(vidTrainPrepProvider.notifier).removeVideo(video.id);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds a single video list item
  Widget _buildVideoListItem({
    required VideoSource video,
    required bool isSelected,
    required int rangeCount,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary.withOpacity(0.5)
                    : colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 64,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: video.thumbnailPath != null && File(video.thumbnailPath!).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            File(video.thumbnailPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.videocam,
                              size: 24,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.videocam,
                          size: 24,
                          color: colorScheme.onSurfaceVariant,
                        ),
                ),
                const SizedBox(width: 10),

                // Video info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.fileName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${video.width}x${video.height} | ${video.durationFormatted} | $rangeCount ranges',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete button
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: 'Remove video',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the center panel - Video preview
  Widget _buildPreviewPanel(BuildContext context, ColorScheme colorScheme, VidTrainPrepState state) {
    final selectedVideo = ref.watch(selectedVideoProvider);
    final selectedRange = ref.watch(selectedRangeProvider);

    if (selectedVideo == null) {
      return Container(
        color: Colors.black,
        child: _buildEmptyState(
          icon: Icons.play_circle_outline,
          message: 'No video selected',
          hint: 'Select a video from the list',
          colorScheme: colorScheme,
          dark: true,
        ),
      );
    }

    return VideoPreview(
      video: selectedVideo,
      crop: selectedRange?.useCrop == true ? selectedRange?.crop : null,
      showCropOverlay: selectedRange?.useCrop == true,
      onCropChanged: selectedRange != null
          ? (crop) {
              ref.read(vidTrainPrepProvider.notifier).setCropForRange(selectedRange.id, crop);
            }
          : null,
    );
  }

  /// Builds the timeline strip panel
  Widget _buildTimelinePanel(BuildContext context, ColorScheme colorScheme, VidTrainPrepState state) {
    final selectedVideo = ref.watch(selectedVideoProvider);
    final ranges = ref.watch(rangesForSelectedVideoProvider);

    return Container(
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.all(8),
      child: selectedVideo == null
          ? Center(
              child: Text(
                'Select a video to view timeline',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Timeline header
                Row(
                  children: [
                    Text(
                      'Timeline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${ranges.length} ranges | ${selectedVideo.durationFormatted}',
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Timeline visualization placeholder
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        'Timeline Strip (Placeholder)',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Builds the right panel - Range list
  Widget _buildRangeListPanel(BuildContext context, ColorScheme colorScheme, VidTrainPrepState state) {
    final selectedVideo = ref.watch(selectedVideoProvider);
    final ranges = ref.watch(rangesForSelectedVideoProvider);

    return Container(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.content_cut, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Ranges',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                // Add range button
                if (selectedVideo != null)
                  IconButton(
                    icon: Icon(Icons.add, size: 20, color: colorScheme.primary),
                    onPressed: () {
                      ref.read(vidTrainPrepProvider.notifier).addRange(selectedVideo.id);
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Add range',
                  ),
              ],
            ),
          ),

          // Range list
          Expanded(
            child: selectedVideo == null
                ? _buildEmptyState(
                    icon: Icons.content_cut,
                    message: 'No video selected',
                    hint: 'Select a video to manage ranges',
                    colorScheme: colorScheme,
                  )
                : ranges.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.add_circle_outline,
                        message: 'No ranges defined',
                        hint: 'Click + to add a range',
                        colorScheme: colorScheme,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: ranges.length,
                        itemBuilder: (context, index) {
                          final range = ranges[index];
                          final isSelected = state.selectedRangeId == range.id;

                          return _buildRangeListItem(
                            range: range,
                            video: selectedVideo,
                            isSelected: isSelected,
                            index: index,
                            colorScheme: colorScheme,
                            onTap: () {
                              ref.read(vidTrainPrepProvider.notifier).selectRange(range.id);
                            },
                            onDelete: () {
                              ref.read(vidTrainPrepProvider.notifier).deleteRange(range.id);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// Builds a single range list item
  Widget _buildRangeListItem({
    required ClipRange range,
    required VideoSource video,
    required bool isSelected,
    required int index,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary.withOpacity(0.5)
                    : colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Range index badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Time range
                    Expanded(
                      child: Text(
                        range.timeRangeFormatted(video.fps),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),

                    // Crop indicator
                    if (range.useCrop && range.crop != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.crop,
                          size: 14,
                          color: colorScheme.tertiary,
                        ),
                      ),

                    // Delete button
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      tooltip: 'Delete range',
                    ),
                  ],
                ),

                // Caption preview (if exists)
                if (range.caption.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    range.caption,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Frame info
                const SizedBox(height: 4),
                Text(
                  'Frames: ${range.startFrame}-${range.endFrame} (${range.frameCount} frames)',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds an empty state placeholder
  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String hint,
    required ColorScheme colorScheme,
    bool dark = false,
  }) {
    final color = dark ? colorScheme.onSurface.withOpacity(0.3) : colorScheme.onSurfaceVariant;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: color.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Import videos from a folder
  Future<void> _importFolder() async {
    final folderPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Video Folder',
    );

    if (folderPath != null) {
      ref.read(vidTrainPrepProvider.notifier).loadFolder(folderPath);
    }
  }

  /// Export all ranges
  Future<void> _exportAll() async {
    final outputPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Export Destination',
    );

    if (outputPath != null) {
      ref.read(vidTrainPrepProvider.notifier).setOutputDirectory(outputPath);
      // TODO: Implement actual export via FFmpeg service
      ref.read(vidTrainPrepProvider.notifier).setExporting(true, status: 'Preparing export...');

      // Placeholder - actual export would be handled by an export service
      await Future.delayed(const Duration(seconds: 2));
      ref.read(vidTrainPrepProvider.notifier).setExporting(false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export functionality coming soon')),
        );
      }
    }
  }
}
