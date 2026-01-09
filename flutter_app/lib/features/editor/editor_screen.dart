import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/editor_models.dart';
import 'providers/editor_provider.dart';
import 'providers/undo_system.dart';
import 'services/playback_controller.dart';
import 'widgets/timeline_widget.dart';
import 'widgets/track_header.dart';
import 'widgets/time_ruler.dart';
import 'widgets/playhead_widget.dart';
import 'widgets/preview_panel.dart';
import 'widgets/clip_widget.dart';
import 'widgets/media_browser_panel.dart';
import 'widgets/effect_panel.dart';
import 'widgets/color_wheels_panel.dart';
import 'widgets/audio_mixer_panel.dart';
import 'widgets/export_dialog.dart';
import 'widgets/markers_panel.dart';
import 'widgets/keyframe_editor.dart';

/// Main video editor screen
///
/// Layout:
/// ```
/// ┌─────────────────────────────────────────────────┐
/// │  Toolbar                                        │
/// ├─────────────────────┬───────────────────────────┤
/// │   Preview Panel     │   Inspector Panel         │
/// ├─────────────────────┴───────────────────────────┤
/// │  Time Ruler                                     │
/// ├────────┬────────────────────────────────────────┤
/// │ Track  │        Timeline                        │
/// │ Headers│        (clips on tracks)               │
/// └────────┴────────────────────────────────────────┘
/// ```
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> with SingleTickerProviderStateMixin {
  final ScrollController _timelineHorizontalController = ScrollController();
  final ScrollController _timelineVerticalController = ScrollController();
  final ScrollController _trackHeadersController = ScrollController();

  double _topPanelHeight = 300;
  double _inspectorWidth = 320;

  final FocusNode _keyboardFocusNode = FocusNode();

  // Tab controller for right panel
  late TabController _rightPanelTabController;

  // Tab index names
  static const List<String> _rightPanelTabs = ['Inspector', 'Effects', 'Color', 'Audio', 'Markers'];

  @override
  void initState() {
    super.initState();
    // Initialize tab controller
    _rightPanelTabController = TabController(length: _rightPanelTabs.length, vsync: this);

    // Sync track headers scroll with timeline
    _timelineVerticalController.addListener(_syncTrackHeadersScroll);

    // Initialize default project
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDefaultProject();
    });
  }

  @override
  void dispose() {
    _rightPanelTabController.dispose();
    _timelineHorizontalController.dispose();
    _timelineVerticalController.dispose();
    _trackHeadersController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _syncTrackHeadersScroll() {
    if (_trackHeadersController.hasClients) {
      _trackHeadersController.jumpTo(_timelineVerticalController.offset);
    }
  }

  void _initializeDefaultProject() {
    final notifier = ref.read(editorProjectProvider.notifier);
    // Add default tracks
    notifier.addTrack(TrackType.video);
    notifier.addTrack(TrackType.video);
    notifier.addTrack(TrackType.audio);
    notifier.addTrack(TrackType.audio);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: Column(
          children: [
            // Toolbar
            _buildToolbar(context, colorScheme),

            // Main content
            Expanded(
              child: Column(
                children: [
                  // Top panel (Media Browser + Preview + Inspector)
                  SizedBox(
                    height: _topPanelHeight,
                    child: Row(
                      children: [
                        // Media Browser panel (left)
                        SizedBox(
                          width: 280,
                          child: _buildMediaBrowserPanel(context, colorScheme),
                        ),

                        // Preview panel (center)
                        Expanded(
                          flex: 2,
                          child: _buildPreviewArea(context, colorScheme),
                        ),

                        // Resize handle
                        _buildVerticalResizeHandle(colorScheme),

                        // Inspector panel (right)
                        SizedBox(
                          width: _inspectorWidth,
                          child: _buildInspectorPanel(context, colorScheme),
                        ),
                      ],
                    ),
                  ),

                  // Horizontal resize handle for top panel
                  _buildHorizontalResizeHandle(colorScheme),

                  // Timeline area
                  Expanded(
                    child: _buildTimelineArea(context, colorScheme),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, ColorScheme colorScheme) {
    final playbackState = ref.watch(playbackStateProvider);
    final editorState = ref.watch(editorProjectProvider);
    final project = editorState.project;
    final canUndo = ref.watch(canUndoProvider);
    final canRedo = ref.watch(canRedoProvider);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          // File operations
          _ToolbarButton(
            icon: Icons.add,
            tooltip: 'New Project',
            onPressed: () => _showNewProjectDialog(context),
          ),
          _ToolbarButton(
            icon: Icons.folder_open,
            tooltip: 'Open Project',
            onPressed: () {},
          ),
          _ToolbarButton(
            icon: Icons.save,
            tooltip: 'Save Project',
            onPressed: () {},
          ),
          _ToolbarButton(
            icon: Icons.movie_creation,
            tooltip: 'Export Video',
            onPressed: () => _showExportDialog(context),
          ),

          const VerticalDivider(width: 16),

          // Edit operations
          _ToolbarButton(
            icon: Icons.undo,
            tooltip: 'Undo (Ctrl+Z)',
            onPressed: canUndo ? () => ref.read(undoSystemProvider.notifier).undo() : null,
          ),
          _ToolbarButton(
            icon: Icons.redo,
            tooltip: 'Redo (Ctrl+Y)',
            onPressed: canRedo ? () => ref.read(undoSystemProvider.notifier).redo() : null,
          ),

          const VerticalDivider(width: 16),

          // Tools
          _buildToolSelector(colorScheme),

          const Spacer(),

          // Playback controls
          _ToolbarButton(
            icon: Icons.skip_previous,
            tooltip: 'Go to Start',
            onPressed: () => ref.read(editorProjectProvider.notifier).setPlayhead(const EditorTime.zero()),
          ),
          _ToolbarButton(
            icon: Icons.fast_rewind,
            tooltip: 'Step Back',
            onPressed: () {
              final current = project.playheadPosition;
              final frameTime = EditorTime.fromFrames(1, project.settings.frameRate);
              ref.read(editorProjectProvider.notifier).setPlayhead(
                EditorTime((current.microseconds - frameTime.microseconds).clamp(0, project.duration.microseconds)),
              );
            },
          ),
          _ToolbarButton(
            icon: playbackState == PlaybackState.playing ? Icons.pause : Icons.play_arrow,
            tooltip: playbackState == PlaybackState.playing ? 'Pause (Space)' : 'Play (Space)',
            onPressed: () {
              final playbackController = ref.read(playbackControllerProvider);
              if (playbackState == PlaybackState.playing) {
                playbackController.pause();
              } else {
                playbackController.play();
              }
            },
            highlighted: playbackState == PlaybackState.playing,
          ),
          _ToolbarButton(
            icon: Icons.stop,
            tooltip: 'Stop',
            onPressed: () => ref.read(playbackControllerProvider).stop(),
          ),
          _ToolbarButton(
            icon: Icons.fast_forward,
            tooltip: 'Step Forward',
            onPressed: () {
              final current = project.playheadPosition;
              final frameTime = EditorTime.fromFrames(1, project.settings.frameRate);
              ref.read(editorProjectProvider.notifier).setPlayhead(current + frameTime);
            },
          ),
          _ToolbarButton(
            icon: Icons.skip_next,
            tooltip: 'Go to End',
            onPressed: () => ref.read(editorProjectProvider.notifier).setPlayhead(project.duration),
          ),
          _ToolbarButton(
            icon: Icons.loop,
            tooltip: 'Loop Playback',
            onPressed: () {},
          ),

          const SizedBox(width: 8),

          // Speed selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.speed, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('1x', style: TextStyle(fontSize: 12, color: colorScheme.onSurface)),
                Icon(Icons.arrow_drop_down, size: 16, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Volume
          Icon(Icons.volume_up, size: 18, color: colorScheme.onSurfaceVariant),

          const SizedBox(width: 16),

          // Time display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Text(
              project.playheadPosition.toString(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Zoom controls
          Icon(Icons.zoom_out, size: 18, color: colorScheme.onSurfaceVariant),
          SizedBox(
            width: 120,
            child: Slider(
              value: project.zoomLevel,
              min: 10,
              max: 500,
              onChanged: (v) => ref.read(editorProjectProvider.notifier).setZoom(v),
            ),
          ),
          Icon(Icons.zoom_in, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildToolSelector(ColorScheme colorScheme) {
    final currentTool = ref.watch(currentToolProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolButton(
          icon: Icons.near_me,
          label: 'Select',
          isSelected: currentTool == EditorTool.select,
          onPressed: () => ref.read(currentToolProvider.notifier).state = EditorTool.select,
        ),
        _ToolButton(
          icon: Icons.content_cut,
          label: 'Cut',
          isSelected: currentTool == EditorTool.cut,
          onPressed: () => ref.read(currentToolProvider.notifier).state = EditorTool.cut,
        ),
        _ToolButton(
          icon: Icons.swap_horiz,
          label: 'Ripple',
          isSelected: currentTool == EditorTool.ripple,
          onPressed: () => ref.read(currentToolProvider.notifier).state = EditorTool.ripple,
        ),
      ],
    );
  }

  Widget _buildPreviewArea(BuildContext context, ColorScheme colorScheme) {
    final editorState = ref.watch(editorProjectProvider);
    final project = editorState.project;
    final playbackState = ref.watch(playbackStateProvider);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: PreviewPanel(
        currentTime: project.playheadPosition,
        duration: project.duration,
        isPlaying: playbackState == PlaybackState.playing,
        playbackSpeed: 1.0,
        volume: 1.0,
        isLooping: false,
        onPlay: () => ref.read(editorProjectProvider.notifier).play(),
        onPause: () => ref.read(editorProjectProvider.notifier).pause(),
        onStop: () => ref.read(editorProjectProvider.notifier).stop(),
        onSeek: (time) => ref.read(editorProjectProvider.notifier).setPlayhead(time),
      ),
    );
  }

  Widget _buildMediaBrowserPanel(BuildContext context, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 8, bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: MediaBrowserPanel(
        onMediaDoubleClick: (media) {
          // Add clip to first video track at playhead position
          final editorState = ref.read(editorProjectProvider);
          final project = editorState.project;
          if (project.tracks.isEmpty) return;

          // Find first video track
          final videoTrack = project.tracks.firstWhere(
            (t) => t.type == TrackType.video,
            orElse: () => project.tracks.first,
          );

          // Get duration from media info or default to 5 seconds
          final mediaDuration = media.mediaInfo?.duration;
          final clipDuration = mediaDuration != null
              ? EditorTime.fromMilliseconds(mediaDuration.inMilliseconds)
              : EditorTime.fromSeconds(5);

          // Create clip from media
          final clip = Clip(
            type: media.type.name == 'video' ? ClipType.video : ClipType.image,
            name: media.fileName,
            timelineStart: project.playheadPosition,
            duration: clipDuration,
            sourcePath: media.filePath,
            sourceDuration: clipDuration,
          );

          ref.read(editorProjectProvider.notifier).addClip(videoTrack.id, clip);
        },
      ),
    );
  }

  Widget _buildInspectorPanel(BuildContext context, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(top: 8, right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: TabBar(
              controller: _rightPanelTabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              tabs: const [
                Tab(text: 'Inspector', icon: Icon(Icons.tune, size: 14)),
                Tab(text: 'Effects', icon: Icon(Icons.auto_fix_high, size: 14)),
                Tab(text: 'Color', icon: Icon(Icons.palette, size: 14)),
                Tab(text: 'Audio', icon: Icon(Icons.audiotrack, size: 14)),
                Tab(text: 'Markers', icon: Icon(Icons.flag, size: 14)),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _rightPanelTabController,
              children: [
                _buildInspectorTab(colorScheme),
                const EffectPanel(),
                const ColorWheelsPanel(),
                const AudioMixerPanel(),
                const MarkersPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorTab(ColorScheme colorScheme) {
    final selectedClips = ref.watch(selectedClipsProvider);

    return selectedClips.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.select_all,
                  size: 40,
                  color: colorScheme.outlineVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a clip to\nedit properties',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        : _buildClipInspector(selectedClips.first, colorScheme);
  }

  Widget _buildClipInspector(Clip clip, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clip name
          Text(
            clip.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            clip.type.name.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: clip.color,
            ),
          ),
          const SizedBox(height: 16),

          // Properties
          _InspectorField(
            label: 'Start',
            value: clip.timelineStart.toString(),
          ),
          _InspectorField(
            label: 'Duration',
            value: clip.duration.toString(),
          ),
          _InspectorField(
            label: 'End',
            value: clip.timelineEnd.toString(),
          ),
          const Divider(height: 24),
          _InspectorField(
            label: 'Source Start',
            value: clip.sourceStart.toString(),
          ),
          _InspectorField(
            label: 'Source Duration',
            value: clip.sourceDuration.toString(),
          ),
          if (clip.sourcePath != null) ...[
            const Divider(height: 24),
            _InspectorField(
              label: 'Source',
              value: clip.sourcePath!.split('/').last,
            ),
          ],
          const Divider(height: 24),

          // Opacity slider
          Text(
            'Opacity',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: clip.opacity,
                  min: 0,
                  max: 1,
                  onChanged: (v) {
                    // TODO: Update clip opacity
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${(clip.opacity * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalResizeHandle(ColorScheme colorScheme) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _inspectorWidth = (_inspectorWidth - details.delta.dx).clamp(200.0, 400.0);
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalResizeHandle(ColorScheme colorScheme) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _topPanelHeight = (_topPanelHeight + details.delta.dy).clamp(150.0, 500.0);
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: Container(
          height: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineArea(BuildContext context, ColorScheme colorScheme) {
    // Use TimelineWidget directly - it has its own track headers and time ruler
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: TimelineWidget(
        horizontalScrollController: _timelineHorizontalController,
      ),
    );
  }

  Widget _buildTrackHeaders(ColorScheme colorScheme, EditorProject project) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: ListView.builder(
        controller: _trackHeadersController,
        itemCount: project.tracks.length,
        itemBuilder: (context, index) {
          final track = project.tracks[index];
          return TrackHeader(
            track: track,
            isSelected: false,
            onTap: () {},
            onNameChanged: (name) {
              // TODO: Update track name
            },
            onMuteChanged: (muted) {
              // TODO: Update track mute
            },
            onSoloChanged: (solo) {
              // TODO: Update track solo
            },
            onLockChanged: (locked) {
              // TODO: Update track lock
            },
            onVisibilityChanged: (visible) {
              // TODO: Update track visibility
            },
            onVolumeChanged: (volume) {
              // TODO: Update track volume
            },
            onDelete: () {
              ref.read(editorProjectProvider.notifier).removeTrack(track.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildTimeline(ColorScheme colorScheme, EditorProject project) {
    return Stack(
      children: [
        // Timeline content
        TimelineWidget(
          horizontalScrollController: _timelineHorizontalController,
        ),

        // Playhead overlay
        Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: PlayheadWidget(
              position: project.playheadPosition,
              pixelsPerSecond: project.zoomLevel,
              scrollOffset: project.scrollOffset,
              height: project.tracks.length * 60.0,
              isDragging: false,
              isPlaying: ref.watch(playbackStateProvider) == PlaybackState.playing,
              onPositionChanged: (time) {
                ref.read(editorProjectProvider.notifier).setPlayhead(time);
              },
            ),
          ),
        ),
      ],
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    // Space - Play/Pause
    if (event.logicalKey == LogicalKeyboardKey.space) {
      final playbackController = ref.read(playbackControllerProvider);
      final playbackState = ref.read(playbackStateProvider);
      if (playbackState == PlaybackState.playing) {
        playbackController.pause();
      } else {
        playbackController.play();
      }
    }
    // Ctrl+Z - Undo
    else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
      ref.read(undoSystemProvider.notifier).undo();
    }
    // Ctrl+Y - Redo
    else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyY) {
      ref.read(undoSystemProvider.notifier).redo();
    }
    // Delete - Delete selected clips
    else if (event.logicalKey == LogicalKeyboardKey.delete) {
      final selectedClips = ref.read(selectedClipsProvider);
      for (final clip in selectedClips) {
        ref.read(editorProjectProvider.notifier).removeClip(clip.id);
      }
    }
    // Home - Go to start
    else if (event.logicalKey == LogicalKeyboardKey.home) {
      ref.read(editorProjectProvider.notifier).setPlayhead(const EditorTime.zero());
    }
    // End - Go to end
    else if (event.logicalKey == LogicalKeyboardKey.end) {
      final editorState = ref.read(editorProjectProvider);
      ref.read(editorProjectProvider.notifier).setPlayhead(editorState.project.duration);
    }
  }

  void _showNewProjectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Project'),
        content: const Text('Create a new project? Unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(editorProjectProvider.notifier).newProject();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ExportDialog(),
    );
  }
}

/// Toolbar button widget
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool highlighted;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: highlighted ? colorScheme.primary.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: onPressed == null
                  ? colorScheme.onSurface.withOpacity(0.3)
                  : highlighted
                      ? colorScheme.primary
                      : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tool selection button
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: label,
      child: Material(
        color: isSelected ? colorScheme.primary.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inspector field row
class _InspectorField extends StatelessWidget {
  final String label;
  final String value;

  const _InspectorField({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
