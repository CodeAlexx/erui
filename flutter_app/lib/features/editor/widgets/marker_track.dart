import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart' hide Clip;
import '../models/marker_models.dart';
import '../providers/markers_provider.dart';

/// Timeline track showing markers as flags.
///
/// Displays markers visually on the timeline with drag-to-reposition
/// and double-click-to-edit functionality.
class MarkerTrack extends ConsumerWidget {
  /// Pixels per second for scaling
  final double pixelsPerSecond;

  /// Scroll offset in time
  final EditorTime scrollOffset;

  /// Track height
  final double height;

  /// Called when a marker is tapped
  final ValueChanged<Marker>? onMarkerTap;

  /// Called when a marker is double-tapped
  final ValueChanged<Marker>? onMarkerDoubleTap;

  /// Called when a marker is dragged to a new position
  final void Function(Marker marker, EditorTime newTime)? onMarkerMoved;

  const MarkerTrack({
    super.key,
    required this.pixelsPerSecond,
    required this.scrollOffset,
    this.height = 24,
    this.onMarkerTap,
    this.onMarkerDoubleTap,
    this.onMarkerMoved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final markersState = ref.watch(markersProvider);
    final markers = markersState.collection.sortedMarkers;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background label
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(
                'MARKERS',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // Markers
          ...markers.map((marker) {
            final x =
                (marker.timestamp.inSeconds - scrollOffset.inSeconds) *
                    pixelsPerSecond;

            // Skip if off-screen
            if (x < -20 || x > 10000) return const SizedBox.shrink();

            return Positioned(
              left: x - 6, // Center the flag
              top: 0,
              bottom: 0,
              child: _MarkerFlag(
                marker: marker,
                onTap: () => onMarkerTap?.call(marker),
                onDoubleTap: () => onMarkerDoubleTap?.call(marker),
                onDragEnd: (delta) {
                  final newTime = EditorTime(
                    marker.timestamp.microseconds +
                        (delta / pixelsPerSecond * 1000000).round(),
                  );
                  onMarkerMoved?.call(marker, newTime);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Individual marker flag widget
class _MarkerFlag extends StatefulWidget {
  final Marker marker;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final ValueChanged<double>? onDragEnd;

  const _MarkerFlag({
    required this.marker,
    this.onTap,
    this.onDoubleTap,
    this.onDragEnd,
  });

  @override
  State<_MarkerFlag> createState() => _MarkerFlagState();
}

class _MarkerFlagState extends State<_MarkerFlag> {
  bool _isHovered = false;
  bool _isDragging = false;
  double _dragDelta = 0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onHorizontalDragStart: (_) {
          if (!widget.marker.isLocked) {
            setState(() {
              _isDragging = true;
              _dragDelta = 0;
            });
          }
        },
        onHorizontalDragUpdate: (details) {
          if (_isDragging) {
            setState(() {
              _dragDelta += details.delta.dx;
            });
          }
        },
        onHorizontalDragEnd: (_) {
          if (_isDragging) {
            widget.onDragEnd?.call(_dragDelta);
            setState(() {
              _isDragging = false;
              _dragDelta = 0;
            });
          }
        },
        child: Transform.translate(
          offset: Offset(_dragDelta, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flag head
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.marker.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: _isHovered || _isDragging
                      ? [
                          BoxShadow(
                            color: widget.marker.color.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIconForType(widget.marker.type),
                      size: 10,
                      color: Colors.white,
                    ),
                    if (_isHovered) ...[
                      const SizedBox(width: 2),
                      Text(
                        widget.marker.label,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Flag pole
              Expanded(
                child: Container(
                  width: 2,
                  color: widget.marker.color.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(MarkerType type) {
    switch (type) {
      case MarkerType.comment:
        return Icons.comment;
      case MarkerType.chapter:
        return Icons.bookmark;
      case MarkerType.todo:
        return Icons.check_box;
      case MarkerType.sync:
        return Icons.sync;
      case MarkerType.edit:
        return Icons.edit;
      case MarkerType.cue:
        return Icons.flag;
    }
  }
}
