import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../providers/editor_provider.dart';
import '../providers/media_browser_provider.dart';
import '../../gallery/widgets/gallery_drag_source.dart';
import 'media_browser_panel.dart';
import 'clip_widget.dart';

/// Main timeline widget for the video editor.
/// Displays tracks stacked vertically with horizontally scrollable clips.
///
/// Features:
/// - Horizontal scroll (time) and vertical scroll (tracks)
/// - Clips positioned by timelineStart and duration
/// - Zoom level control (pixels per second)
/// - Background grid/markers for timing
/// - Drop target for adding new clips
/// - Drag-to-scroll support
class TimelineWidget extends ConsumerStatefulWidget {
  /// Callback when a clip is tapped
  final void Function(EditorClip clip)? onClipTap;

  /// Callback when clip drag starts
  final void Function(Clip clip, DragStartDetails details)? onClipDragStart;

  /// Callback when clip is being dragged
  final void Function(Clip clip, DragUpdateDetails details)? onClipDragUpdate;

  /// Callback when clip drag ends
  final void Function(Clip clip, DragEndDetails details)? onClipDragEnd;

  /// Callback when background is tapped (for placing playhead)
  final void Function(EditorTime time, int? trackIndex)? onBackgroundTap;

  /// Callback when a file is dropped on the timeline
  final void Function(String path, EditorTime time, int trackIndex)? onFileDrop;

  /// External scroll controller for horizontal sync (e.g., with time ruler)
  final ScrollController? horizontalScrollController;

  const TimelineWidget({
    super.key,
    this.onClipTap,
    this.onClipDragStart,
    this.onClipDragUpdate,
    this.onClipDragEnd,
    this.onBackgroundTap,
    this.onFileDrop,
    this.horizontalScrollController,
  });

  @override
  ConsumerState<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends ConsumerState<TimelineWidget> {
  late ScrollController _horizontalScrollController;
  final ScrollController _verticalScrollController = ScrollController();

  /// Track header width
  static const double _trackHeaderWidth = 120.0;

  /// Minimum track height
  static const double _minTrackHeight = 40.0;

  /// Time ruler height
  static const double _timeRulerHeight = 32.0;

  /// Whether we're currently dragging to scroll
  bool _isDraggingToScroll = false;
  Offset _lastDragPosition = Offset.zero;

  /// Drag and drop state for visual feedback
  bool _isDragHovering = false;
  Offset? _dragHoverPosition;
  int? _dragHoverTrackIndex;
  GalleryDragData? _dragData;

  @override
  void initState() {
    super.initState();
    // Use external scroll controller if provided, otherwise create our own
    _horizontalScrollController =
        widget.horizontalScrollController ?? ScrollController();
  }

  @override
  void didUpdateWidget(TimelineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle scroll controller changes
    if (widget.horizontalScrollController != oldWidget.horizontalScrollController) {
      if (oldWidget.horizontalScrollController == null) {
        _horizontalScrollController.dispose();
      }
      _horizontalScrollController =
          widget.horizontalScrollController ?? ScrollController();
    }
  }

  @override
  void dispose() {
    // Only dispose if we created our own controller
    if (widget.horizontalScrollController == null) {
      _horizontalScrollController.dispose();
    }
    _verticalScrollController.dispose();
    super.dispose();
  }

  /// Convert time to pixel position based on zoom level
  double _timeToPixel(EditorTime time, double pixelsPerSecond) {
    return time.inSeconds * pixelsPerSecond;
  }

  /// Convert pixel position to time based on zoom level
  EditorTime _pixelToTime(double pixel, double pixelsPerSecond) {
    return EditorTime.fromSeconds(pixel / pixelsPerSecond);
  }

  /// Get track at Y position
  int? _getTrackIndexAtY(double y, List<Track> tracks) {
    double currentY = 0;
    for (int i = 0; i < tracks.length; i++) {
      final trackHeight = math.max(tracks[i].height, _minTrackHeight);
      if (y >= currentY && y < currentY + trackHeight) {
        return i;
      }
      currentY += trackHeight;
    }
    return null;
  }

  /// Handle tap on timeline background
  void _handleBackgroundTap(TapUpDetails details, EditorProject project) {
    final localX = details.localPosition.dx + _horizontalScrollController.offset;
    final localY = details.localPosition.dy + _verticalScrollController.offset;

    final time = _pixelToTime(localX, project.zoomLevel);
    final trackIndex = _getTrackIndexAtY(localY, project.tracks);

    widget.onBackgroundTap?.call(time, trackIndex);
  }

  /// Handle drag to scroll (middle mouse button or two-finger drag)
  void _handlePanStart(DragStartDetails details) {
    _isDraggingToScroll = true;
    _lastDragPosition = details.localPosition;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDraggingToScroll) return;

    final delta = _lastDragPosition - details.localPosition;
    _lastDragPosition = details.localPosition;

    if (_horizontalScrollController.hasClients) {
      _horizontalScrollController.jumpTo(
        (_horizontalScrollController.offset + delta.dx).clamp(
          0.0,
          _horizontalScrollController.position.maxScrollExtent,
        ),
      );
    }
    if (_verticalScrollController.hasClients) {
      _verticalScrollController.jumpTo(
        (_verticalScrollController.offset + delta.dy).clamp(
          0.0,
          _verticalScrollController.position.maxScrollExtent,
        ),
      );
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _isDraggingToScroll = false;
  }

  /// Handle mouse wheel scroll
  void _handlePointerSignal(PointerSignalEvent event, EditorProject project) {
    if (event is PointerScrollEvent) {
      // Horizontal scroll with mouse wheel
      if (_horizontalScrollController.hasClients) {
        _horizontalScrollController.jumpTo(
          (_horizontalScrollController.offset + event.scrollDelta.dy).clamp(
            0.0,
            _horizontalScrollController.position.maxScrollExtent,
          ),
        );
      }
    }
  }

  /// Handle gallery drag data drop on timeline
  void _handleGalleryDrop(
    GalleryDragData data,
    Offset localPosition,
    EditorProject project,
  ) {
    // Calculate drop position in pixels (accounting for scroll)
    final pixelX = localPosition.dx + _horizontalScrollController.offset;
    final pixelY = localPosition.dy + _verticalScrollController.offset;

    // Convert pixel position to time
    final dropTime = _pixelToTime(pixelX, project.zoomLevel);

    // Find which track was dropped on
    final trackIndex = _getTrackIndexAtY(pixelY, project.tracks);

    if (trackIndex == null || trackIndex >= project.tracks.length) {
      return; // Invalid track
    }

    final track = project.tracks[trackIndex];

    // Determine clip type and duration based on drag data
    ClipType clipType;
    EditorTime duration;

    switch (data.mediaType) {
      case DragMediaType.video:
        clipType = ClipType.video;
        // Use actual video duration if available, otherwise default to 5 seconds
        duration = EditorTime.fromSeconds(
          data.durationSeconds > 0 ? data.durationSeconds : 5.0,
        );
        break;
      case DragMediaType.audio:
        clipType = ClipType.audio;
        // Use actual audio duration if available, otherwise default to 5 seconds
        duration = EditorTime.fromSeconds(
          data.durationSeconds > 0 ? data.durationSeconds : 5.0,
        );
        break;
      case DragMediaType.image:
      default:
        clipType = ClipType.image;
        // Images default to 5 seconds duration
        duration = EditorTime.fromSeconds(5.0);
        break;
    }

    // Check if the track type is compatible with the clip type
    bool isCompatible = false;
    switch (track.type) {
      case TrackType.video:
        isCompatible = clipType == ClipType.video || clipType == ClipType.image;
        break;
      case TrackType.audio:
        isCompatible = clipType == ClipType.audio;
        break;
      case TrackType.text:
      case TrackType.effect:
        isCompatible = false;
        break;
    }

    if (!isCompatible) {
      // Find a compatible track or show feedback
      // For now, just return - could show a snackbar message
      return;
    }

    // Create the new clip
    final newClip = EditorClip(
      type: clipType,
      name: data.displayName,
      timelineStart: dropTime,
      duration: duration,
      sourcePath: data.sourcePath,
      sourceDuration: duration,
      trackIndex: trackIndex,
    );

    // Add clip to the track using the editor provider
    final notifier = ref.read(editorProjectProvider.notifier);
    notifier.addClip(track.id, newClip);

    // Also trigger the onFileDrop callback if provided
    widget.onFileDrop?.call(data.sourcePath, dropTime, trackIndex);
  }

  /// Handle media browser drag data drop on timeline
  void _handleMediaDrop(
    MediaDragData data,
    Offset localPosition,
    EditorProject project,
  ) {
    print('DEBUG: _handleMediaDrop called with ${data.media.fileName}');
    // Calculate drop position in pixels (accounting for scroll)
    final pixelX = localPosition.dx + _horizontalScrollController.offset;
    final pixelY = localPosition.dy + _verticalScrollController.offset;

    // Convert pixel position to time
    final dropTime = _pixelToTime(pixelX, project.zoomLevel);

    // Find which track was dropped on
    final trackIndex = _getTrackIndexAtY(pixelY, project.tracks);

    if (trackIndex == null || trackIndex >= project.tracks.length) {
      return; // Invalid track
    }

    final track = project.tracks[trackIndex];

    // Determine clip type and duration based on media data
    ClipType clipType;
    EditorTime duration;

    if (data.clipType == ClipType.video) {
      clipType = ClipType.video;
      // Use actual duration if available, otherwise default to 5 seconds
      final mediaInfo = data.media.mediaInfo;
      duration = EditorTime.fromSeconds(
        mediaInfo?.duration.inMilliseconds != null
            ? mediaInfo!.duration.inMilliseconds / 1000.0
            : 5.0,
      );
    } else {
      clipType = ClipType.image;
      // Images default to 5 seconds duration
      duration = EditorTime.fromSeconds(5.0);
    }

    // Check if the track type is compatible with the clip type
    bool isCompatible = false;
    switch (track.type) {
      case TrackType.video:
        isCompatible = clipType == ClipType.video || clipType == ClipType.image;
        break;
      case TrackType.audio:
        isCompatible = clipType == ClipType.audio;
        break;
      case TrackType.text:
      case TrackType.effect:
        isCompatible = false;
        break;
    }

    if (!isCompatible) {
      return;
    }

    // Create the new clip
    final newClip = EditorClip(
      type: clipType,
      name: data.media.fileName,
      timelineStart: dropTime,
      duration: duration,
      sourcePath: data.media.filePath,
      sourceDuration: duration,
      trackIndex: trackIndex,
    );

    // Add clip to the track using the editor provider
    final notifier = ref.read(editorProjectProvider.notifier);
    notifier.addClip(track.id, newClip);

    // Also trigger the onFileDrop callback if provided
    widget.onFileDrop?.call(data.media.filePath, dropTime, trackIndex);
  }

  /// Update drag hover state for visual feedback
  void _updateDragHover(
    Offset? localPosition,
    GalleryDragData? data,
    EditorProject project,
  ) {
    if (localPosition == null || data == null) {
      setState(() {
        _isDragHovering = false;
        _dragHoverPosition = null;
        _dragHoverTrackIndex = null;
        _dragData = null;
      });
      return;
    }

    final pixelY = localPosition.dy + _verticalScrollController.offset;
    final trackIndex = _getTrackIndexAtY(pixelY, project.tracks);

    setState(() {
      _isDragHovering = true;
      _dragHoverPosition = localPosition;
      _dragHoverTrackIndex = trackIndex;
      _dragData = data;
    });
  }

  /// Check if a track is a valid drop target for the drag data
  bool _isValidDropTarget(int trackIndex, GalleryDragData data, EditorProject project) {
    if (trackIndex < 0 || trackIndex >= project.tracks.length) {
      return false;
    }

    final track = project.tracks[trackIndex];

    switch (data.mediaType) {
      case DragMediaType.video:
      case DragMediaType.image:
        return track.type == TrackType.video;
      case DragMediaType.audio:
        return track.type == TrackType.audio;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProjectProvider);
    final selectedClipIds = ref.watch(selectedClipIdsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final project = editorState.project;

    final totalHeight = project.tracks.fold<double>(
      0,
      (sum, track) => sum + math.max(track.height, _minTrackHeight),
    );

    final totalWidth = _timeToPixel(project.duration, project.zoomLevel);

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Time ruler row
          SizedBox(
            height: _timeRulerHeight,
            child: Row(
              children: [
                // Empty corner
                Container(
                  width: _trackHeaderWidth,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    border: Border(
                      right: BorderSide(color: colorScheme.outlineVariant),
                      bottom: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                ),
                // Time ruler
                Expanded(
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: _TimeRuler(
                      duration: project.duration,
                      zoomLevel: project.zoomLevel,
                      width: totalWidth,
                      fps: project.settings.frameRate,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tracks area
          Expanded(
            child: Row(
              children: [
                // Track headers
                SizedBox(
                  width: _trackHeaderWidth,
                  child: SingleChildScrollView(
                    controller: _verticalScrollController,
                    child: _TrackHeaders(tracks: project.tracks),
                  ),
                ),
                // Timeline content
                Expanded(
                  child: Listener(
                    onPointerSignal: (event) =>
                        _handlePointerSignal(event, project),
                child: DragTarget<Object>(
                      onWillAcceptWithDetails: (details) {
                        final data = details.data;
                        if (data is MediaDragData) {
                          print('DEBUG: MediaDragData will accept');
                          return true;
                        } else if (data is GalleryDragData) {
                          _updateDragHover(details.offset, data, project);
                          return true;
                        }
                        return false;
                      },
                      onAcceptWithDetails: (details) {
                        final data = details.data;
                        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
                        if (renderBox == null) return;
                        final localPosition = renderBox.globalToLocal(details.offset);

                        if (data is MediaDragData) {
                          print('DEBUG: MediaDragData accepted at $localPosition');
                          _handleMediaDrop(data, localPosition, project);
                        } else if (data is GalleryDragData) {
                          _handleGalleryDrop(data, localPosition, project);
                          _updateDragHover(null, null, project);
                        }
                      },
                      onLeave: (data) {
                        _updateDragHover(null, null, project);
                      },
                      builder: (context, candidateData, rejectedData) {
                        final hasCandidateData = candidateData.isNotEmpty;
                        return Listener(
                          onPointerSignal: (event) =>
                              _handlePointerSignal(event, project),
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (details) =>
                                _handleBackgroundTap(details, project),
                            // NOTE: Removed onPan* handlers - they were blocking drag-drop
                            // Scrolling is handled by mouse wheel via onPointerSignal
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                controller: _verticalScrollController,
                                child: SizedBox(
                                  width: totalWidth,
                                  height: totalHeight,
                                  child: Stack(
                                    children: [
                                      // Background grid
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: _TimelineGridPainter(
                                            zoomLevel: project.zoomLevel,
                                            duration: project.duration,
                                            tracks: project.tracks,
                                            colorScheme: colorScheme,
                                          ),
                                        ),
                                      ),
                                      // Track drop zone highlights (when dragging)
                                      if (_isDragHovering && _dragData != null)
                                        ..._buildTrackDropZones(project, colorScheme),
                                      // Clips
                                      ..._buildClips(project, selectedClipIds, colorScheme),
                                      // Playhead
                                      _Playhead(
                                        position: project.playheadPosition,
                                        zoomLevel: project.zoomLevel,
                                        height: totalHeight,
                                        color: colorScheme.primary,
                                      ),
                                      // In/Out markers
                                      if (project.inPoint != null)
                                        _RangeMarker(
                                          position: project.inPoint!,
                                          zoomLevel: project.zoomLevel,
                                          height: totalHeight,
                                          color: colorScheme.tertiary
                                              .withOpacity(0.5),
                                          isInPoint: true,
                                        ),
                                      if (project.outPoint != null)
                                        _RangeMarker(
                                          position: project.outPoint!,
                                          zoomLevel: project.zoomLevel,
                                          height: totalHeight,
                                          color: colorScheme.tertiary
                                              .withOpacity(0.5),
                                          isInPoint: false,
                                        ),
                                      // Insertion point indicator (when dragging)
                                      if (_isDragHovering && _dragHoverPosition != null && _dragData != null)
                                        _buildInsertionIndicator(project, colorScheme),
                                      // Ghost preview of where clip will land
                                      if (_isDragHovering && _dragHoverPosition != null && _dragData != null)
                                        _buildGhostPreview(project, colorScheme),
                                      // Drop highlight overlay
                                      if (hasCandidateData)
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: Container(
                                              color: colorScheme.primary
                                                  .withOpacity(0.05),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build clip widgets
  List<Widget> _buildClips(
    EditorProject project,
    Set<EditorId> selectedClipIds,
    ColorScheme colorScheme,
  ) {
    final clips = <Widget>[];
    double trackOffset = 0;

    for (int trackIndex = 0; trackIndex < project.tracks.length; trackIndex++) {
      final track = project.tracks[trackIndex];
      final trackHeight = math.max(track.height, _minTrackHeight);

      for (final clip in track.clips) {
        final left = _timeToPixel(clip.timelineStart, project.zoomLevel);
        final width = _timeToPixel(clip.duration, project.zoomLevel);
        final isSelected = selectedClipIds.contains(clip.id);

        clips.add(
          Positioned(
            left: left,
            top: trackOffset,
            width: math.max(width, 20), // Minimum visible width
            height: trackHeight - 4, // Leave some padding
            child: ClipWidget(
              clip: clip,
              pixelsPerSecond: project.zoomLevel,
              isSelected: isSelected,
              onTap: () {
                // Select the clip in the editor state
                ref.read(editorProjectProvider.notifier).selectClip(clip.id);
                // Also call external handler if provided
                widget.onClipTap?.call(clip);
              },
              onDragUpdate: (details) =>
                  widget.onClipDragUpdate?.call(clip, details),
              onDragEnd: (details) =>
                  widget.onClipDragEnd?.call(clip, details),
            ),
          ),
        );
      }

      trackOffset += trackHeight;
    }

    return clips;
  }

  /// Build track drop zone highlights
  List<Widget> _buildTrackDropZones(
    EditorProject project,
    ColorScheme colorScheme,
  ) {
    final zones = <Widget>[];
    double trackOffset = 0;

    for (int trackIndex = 0; trackIndex < project.tracks.length; trackIndex++) {
      final track = project.tracks[trackIndex];
      final trackHeight = math.max(track.height, _minTrackHeight);

      // Check if this track is a valid drop target
      final isValidTarget = _dragData != null &&
          _isValidDropTarget(trackIndex, _dragData!, project);

      // Highlight the hovered track
      final isHovered = _dragHoverTrackIndex == trackIndex;

      zones.add(
        Positioned(
          left: 0,
          top: trackOffset,
          right: 0,
          height: trackHeight,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isHovered && isValidTarget
                    ? colorScheme.primary.withOpacity(0.15)
                    : isValidTarget
                        ? colorScheme.primary.withOpacity(0.05)
                        : Colors.transparent,
                border: isHovered && isValidTarget
                    ? Border.all(
                        color: colorScheme.primary.withOpacity(0.5),
                        width: 2,
                      )
                    : null,
              ),
            ),
          ),
        ),
      );

      trackOffset += trackHeight;
    }

    return zones;
  }

  /// Build insertion point indicator
  Widget _buildInsertionIndicator(
    EditorProject project,
    ColorScheme colorScheme,
  ) {
    if (_dragHoverPosition == null || _dragHoverTrackIndex == null) {
      return const SizedBox.shrink();
    }

    // Check if this is a valid drop target
    if (_dragData != null &&
        !_isValidDropTarget(_dragHoverTrackIndex!, _dragData!, project)) {
      return const SizedBox.shrink();
    }

    // Calculate the x position accounting for scroll
    final pixelX = _dragHoverPosition!.dx + _horizontalScrollController.offset;

    // Calculate track offset
    double trackTop = 0;
    for (int i = 0; i < _dragHoverTrackIndex!; i++) {
      trackTop += math.max(project.tracks[i].height, _minTrackHeight);
    }
    final trackHeight = math.max(
      project.tracks[_dragHoverTrackIndex!].height,
      _minTrackHeight,
    );

    return Positioned(
      left: pixelX - 1,
      top: trackTop,
      width: 2,
      height: trackHeight,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.5),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  /// Build ghost preview of where clip will land
  Widget _buildGhostPreview(
    EditorProject project,
    ColorScheme colorScheme,
  ) {
    if (_dragHoverPosition == null ||
        _dragHoverTrackIndex == null ||
        _dragData == null) {
      return const SizedBox.shrink();
    }

    // Check if this is a valid drop target
    if (!_isValidDropTarget(_dragHoverTrackIndex!, _dragData!, project)) {
      return const SizedBox.shrink();
    }

    // Calculate the x position accounting for scroll
    final pixelX = _dragHoverPosition!.dx + _horizontalScrollController.offset;

    // Calculate duration in pixels
    final durationSeconds = _dragData!.durationSeconds > 0
        ? _dragData!.durationSeconds
        : 5.0; // Default 5 seconds for images
    final durationPixels = durationSeconds * project.zoomLevel;

    // Calculate track offset
    double trackTop = 0;
    for (int i = 0; i < _dragHoverTrackIndex!; i++) {
      trackTop += math.max(project.tracks[i].height, _minTrackHeight);
    }
    final trackHeight = math.max(
      project.tracks[_dragHoverTrackIndex!].height,
      _minTrackHeight,
    );

    // Determine clip color based on media type
    Color clipColor;
    IconData clipIcon;
    switch (_dragData!.mediaType) {
      case DragMediaType.video:
        clipColor = const Color(0xFF4A90D9);
        clipIcon = Icons.videocam;
        break;
      case DragMediaType.audio:
        clipColor = const Color(0xFF50C878);
        clipIcon = Icons.audiotrack;
        break;
      case DragMediaType.image:
      default:
        clipColor = const Color(0xFFE6A23C);
        clipIcon = Icons.image;
        break;
    }

    return Positioned(
      left: pixelX,
      top: trackTop + 2,
      width: math.max(durationPixels, 40), // Minimum visible width
      height: trackHeight - 8,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: clipColor.withOpacity(0.4),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: clipColor.withOpacity(0.8),
              width: 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Stack(
            children: [
              // Striped pattern to indicate ghost/preview
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: CustomPaint(
                    painter: _DiagonalStripesPainter(
                      color: clipColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              // Icon and name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      clipIcon,
                      size: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _dragData!.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painter for diagonal stripes pattern (ghost preview indicator)
class _DiagonalStripesPainter extends CustomPainter {
  final Color color;

  _DiagonalStripesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const spacing = 8.0;
    final maxDimension = size.width + size.height;

    for (double i = -maxDimension; i < maxDimension; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiagonalStripesPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Time ruler widget showing time markers
class _TimeRuler extends StatelessWidget {
  final EditorTime duration;
  final double zoomLevel;
  final double width;
  final double fps;

  const _TimeRuler({
    required this.duration,
    required this.zoomLevel,
    required this.width,
    required this.fps,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: 32,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: CustomPaint(
        painter: _TimeRulerPainter(
          duration: duration,
          zoomLevel: zoomLevel,
          colorScheme: colorScheme,
          fps: fps,
        ),
      ),
    );
  }
}

/// Custom painter for time ruler
class _TimeRulerPainter extends CustomPainter {
  final EditorTime duration;
  final double zoomLevel;
  final ColorScheme colorScheme;
  final double fps;

  _TimeRulerPainter({
    required this.duration,
    required this.zoomLevel,
    required this.colorScheme,
    required this.fps,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Calculate appropriate interval based on zoom level
    final interval = _calculateInterval(zoomLevel);
    final totalSeconds = duration.inSeconds;

    for (double t = 0; t <= totalSeconds; t += interval) {
      final x = t * zoomLevel;

      // Draw tick
      final isMajor = (t % (interval * 5)).abs() < 0.001;
      final tickHeight = isMajor ? 16.0 : 8.0;

      canvas.drawLine(
        Offset(x, size.height - tickHeight),
        Offset(x, size.height),
        paint,
      );

      // Draw time label for major ticks
      if (isMajor) {
        final time = EditorTime.fromSeconds(t);
        final label = _formatTime(time);

        textPainter.text = TextSpan(
          text: label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, 2),
        );
      }
    }
  }

  double _calculateInterval(double zoom) {
    // Adjust interval based on zoom to keep labels readable
    if (zoom >= 200) return 0.5; // Half second
    if (zoom >= 100) return 1; // 1 second
    if (zoom >= 50) return 2; // 2 seconds
    if (zoom >= 20) return 5; // 5 seconds
    if (zoom >= 10) return 10; // 10 seconds
    if (zoom >= 5) return 30; // 30 seconds
    return 60; // 1 minute
  }

  String _formatTime(EditorTime time) {
    final totalSeconds = time.inSeconds;
    final minutes = (totalSeconds / 60).floor();
    final seconds = (totalSeconds % 60).floor();
    final frames = ((totalSeconds % 1) * fps).round();

    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
    return '$seconds:${frames.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(covariant _TimeRulerPainter oldDelegate) {
    return oldDelegate.duration != duration ||
        oldDelegate.zoomLevel != zoomLevel;
  }
}

/// Track header widgets
class _TrackHeaders extends StatelessWidget {
  final List<Track> tracks;

  const _TrackHeaders({required this.tracks});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: tracks.asMap().entries.map((entry) {
        final index = entry.key;
        final track = entry.value;
        final height = math.max(track.height, 40.0);

        // Build track tooltip
        final trackTypeStr = track.type.name[0].toUpperCase() + track.type.name.substring(1);
        final tooltipText = 'Track ${index + 1}: ${track.name}\nType: $trackTypeStr\n${track.clips.length} clip(s)';

        return Tooltip(
          message: tooltipText,
          waitDuration: const Duration(milliseconds: 500),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              border: Border(
                right: BorderSide(color: colorScheme.outlineVariant),
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
            children: [
              // Track type icon
              Icon(
                _getTrackIcon(track.type),
                size: 16,
                color: _getTrackColor(track.type, colorScheme),
              ),
              const SizedBox(width: 8),
              // Track name
              Expanded(
                child: Text(
                  track.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Track controls
              if (track.type == TrackType.audio) ...[
                _TrackButton(
                  icon: track.isMuted ? Icons.volume_off : Icons.volume_up,
                  isActive: track.isMuted,
                  tooltip: track.isMuted ? 'Unmute' : 'Mute',
                  onPressed: () {
                    // Toggle mute
                  },
                ),
                _TrackButton(
                  icon: Icons.headphones,
                  isActive: track.isSolo,
                  tooltip: track.isSolo ? 'Disable Solo' : 'Solo',
                  onPressed: () {
                    // Toggle solo
                  },
                ),
              ],
              _TrackButton(
                icon: track.isLocked ? Icons.lock : Icons.lock_open,
                isActive: track.isLocked,
                tooltip: track.isLocked ? 'Unlock Track' : 'Lock Track',
                onPressed: () {
                  // Toggle lock
                },
              ),
              _TrackButton(
                icon:
                    track.isVisible ? Icons.visibility : Icons.visibility_off,
                isActive: !track.isVisible,
                tooltip: track.isVisible ? 'Hide Track' : 'Show Track',
                onPressed: () {
                  // Toggle visibility
                },
              ),
            ],
          ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getTrackIcon(TrackType type) {
    switch (type) {
      case TrackType.video:
        return Icons.videocam;
      case TrackType.audio:
        return Icons.audiotrack;
      case TrackType.text:
        return Icons.text_fields;
      case TrackType.effect:
        return Icons.auto_fix_high;
    }
  }

  Color _getTrackColor(TrackType type, ColorScheme colorScheme) {
    switch (type) {
      case TrackType.video:
        return colorScheme.primary;
      case TrackType.audio:
        return colorScheme.tertiary;
      case TrackType.text:
        return colorScheme.secondary;
      case TrackType.effect:
        return colorScheme.error;
    }
  }
}

/// Small track button with tooltip
class _TrackButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;
  final String? tooltip;

  const _TrackButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget button = SizedBox(
      width: 20,
      height: 20,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 14,
        icon: Icon(
          icon,
          color: isActive
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
        onPressed: onPressed,
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: button,
      );
    }

    return button;
  }
}

/// Timeline grid painter
class _TimelineGridPainter extends CustomPainter {
  final double zoomLevel;
  final EditorTime duration;
  final List<Track> tracks;
  final ColorScheme colorScheme;

  _TimelineGridPainter({
    required this.zoomLevel,
    required this.duration,
    required this.tracks,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = colorScheme.outlineVariant.withOpacity(0.3)
      ..strokeWidth = 1;

    final majorGridPaint = Paint()
      ..color = colorScheme.outlineVariant.withOpacity(0.6)
      ..strokeWidth = 1;

    // Calculate grid interval based on zoom
    final interval = _calculateGridInterval(zoomLevel);
    final totalSeconds = duration.inSeconds;

    // Draw vertical grid lines (time)
    for (double t = 0; t <= totalSeconds; t += interval) {
      final x = t * zoomLevel;
      final isMajor = (t % (interval * 5)).abs() < 0.001;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMajor ? majorGridPaint : gridPaint,
      );
    }

    // Draw horizontal track separators
    final trackPaint = Paint()
      ..color = colorScheme.outlineVariant
      ..strokeWidth = 1;

    double y = 0;
    for (final track in tracks) {
      y += math.max(track.height, 40.0);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        trackPaint,
      );
    }

    // Draw track backgrounds (alternating)
    y = 0;
    for (int i = 0; i < tracks.length; i++) {
      final trackHeight = math.max(tracks[i].height, 40.0);
      if (i.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, trackHeight),
          Paint()..color = colorScheme.surfaceContainerLow.withOpacity(0.3),
        );
      }
      y += trackHeight;
    }
  }

  double _calculateGridInterval(double zoom) {
    if (zoom >= 200) return 0.25; // Quarter second
    if (zoom >= 100) return 0.5; // Half second
    if (zoom >= 50) return 1; // 1 second
    if (zoom >= 20) return 2; // 2 seconds
    if (zoom >= 10) return 5; // 5 seconds
    return 10; // 10 seconds
  }

  @override
  bool shouldRepaint(covariant _TimelineGridPainter oldDelegate) {
    return oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.duration != duration ||
        oldDelegate.tracks.length != tracks.length;
  }
}

/// Individual clip widget
class _ClipWidget extends StatelessWidget {
  final EditorClip clip;
  final Track track;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;
  final void Function(DragStartDetails)? onDragStart;
  final void Function(DragUpdateDetails)? onDragUpdate;
  final void Function(DragEndDetails)? onDragEnd;

  const _ClipWidget({
    required this.clip,
    required this.track,
    required this.isSelected,
    required this.colorScheme,
    this.onTap,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final clipColor = clip.color;
    final borderColor =
        isSelected ? colorScheme.primary : clipColor.withOpacity(0.8);

    return GestureDetector(
      onTap: onTap,
      onPanStart: clip.isLocked ? null : onDragStart,
      onPanUpdate: clip.isLocked ? null : onDragUpdate,
      onPanEnd: clip.isLocked ? null : onDragEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: clipColor.withOpacity(clip.opacity * 0.8),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Clip waveform/thumbnail area
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: _ClipContent(clip: clip, colorScheme: colorScheme),
              ),
            ),
            // Clip header with name
            Positioned(
              left: 4,
              top: 2,
              right: 4,
              child: Text(
                clip.name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _getContrastColor(clipColor),
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 2,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Duration indicator
            Positioned(
              right: 4,
              bottom: 2,
              child: Text(
                clip.duration.toString(),
                style: TextStyle(
                  fontSize: 9,
                  color: _getContrastColor(clipColor).withOpacity(0.7),
                ),
              ),
            ),
            // Trim handles (visible when selected)
            if (isSelected && !clip.isLocked) ...[
              // Left trim handle
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.chevron_left, size: 12, color: Colors.white),
                  ),
                ),
              ),
              // Right trim handle
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.chevron_right, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
            // Lock indicator
            if (clip.isLocked)
              Positioned(
                right: 4,
                top: 2,
                child: Icon(
                  Icons.lock,
                  size: 12,
                  color: _getContrastColor(clipColor).withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

/// Clip content based on type (waveform, thumbnail, etc.)
class _ClipContent extends StatelessWidget {
  final EditorClip clip;
  final ColorScheme colorScheme;

  const _ClipContent({required this.clip, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    switch (clip.type) {
      case ClipType.video:
      case ClipType.image:
        // Show thumbnail placeholder
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                clip.color.withOpacity(0.4),
                clip.color.withOpacity(0.6),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              clip.type == ClipType.video ? Icons.videocam : Icons.image,
              color: Colors.white.withOpacity(0.3),
              size: 24,
            ),
          ),
        );

      case ClipType.audio:
        // Show waveform placeholder
        return CustomPaint(
          painter: _WaveformPainter(
            color: Colors.white.withOpacity(0.4),
          ),
        );

      case ClipType.text:
        return Container(
          color: clip.color.withOpacity(0.3),
          child: Center(
            child: Icon(
              Icons.text_fields,
              color: Colors.white.withOpacity(0.3),
              size: 20,
            ),
          ),
        );

      case ClipType.effect:
      case ClipType.transition:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                clip.color.withOpacity(0.3),
                clip.color.withOpacity(0.5),
                clip.color.withOpacity(0.3),
              ],
            ),
          ),
          child: Center(
            child: Icon(
              clip.type == ClipType.effect
                  ? Icons.auto_fix_high
                  : Icons.compare_arrows,
              color: Colors.white.withOpacity(0.4),
              size: 20,
            ),
          ),
        );
    }
  }
}

/// Simple waveform painter placeholder
class _WaveformPainter extends CustomPainter {
  final Color color;

  _WaveformPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final random = math.Random(42); // Fixed seed for consistent look
    final midY = size.height / 2;

    for (double x = 0; x < size.width; x += 2) {
      final amplitude = random.nextDouble() * (size.height / 3);
      canvas.drawLine(
        Offset(x, midY - amplitude),
        Offset(x, midY + amplitude),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Playhead indicator
class _Playhead extends StatelessWidget {
  final EditorTime position;
  final double zoomLevel;
  final double height;
  final Color color;

  const _Playhead({
    required this.position,
    required this.zoomLevel,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final x = position.inSeconds * zoomLevel;

    return Positioned(
      left: x - 1,
      top: 0,
      child: Column(
        children: [
          // Playhead handle
          Container(
            width: 10,
            height: 12,
            transform: Matrix4.translationValues(-4, 0, 0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
          ),
          // Playhead line
          Container(
            width: 2,
            height: height - 12,
            color: color,
          ),
        ],
      ),
    );
  }
}

/// In/Out point marker
class _RangeMarker extends StatelessWidget {
  final EditorTime position;
  final double zoomLevel;
  final double height;
  final Color color;
  final bool isInPoint;

  const _RangeMarker({
    required this.position,
    required this.zoomLevel,
    required this.height,
    required this.color,
    required this.isInPoint,
  });

  @override
  Widget build(BuildContext context) {
    final x = position.inSeconds * zoomLevel;

    return Positioned(
      left: x - 1,
      top: 0,
      child: Column(
        children: [
          // Marker handle
          Container(
            width: 8,
            height: 10,
            transform: Matrix4.translationValues(isInPoint ? -7 : 1, 0, 0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                bottomLeft:
                    isInPoint ? Radius.zero : const Radius.circular(4),
                bottomRight:
                    isInPoint ? const Radius.circular(4) : Radius.zero,
              ),
            ),
            child: Center(
              child: Text(
                isInPoint ? 'I' : 'O',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Marker line
          Container(
            width: 1,
            height: height - 10,
            color: color,
          ),
        ],
      ),
    );
  }
}
