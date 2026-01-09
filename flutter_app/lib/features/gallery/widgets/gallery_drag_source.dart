import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/gallery_provider.dart';

/// Enum to identify the media type being dragged
enum DragMediaType {
  image,
  video,
  audio,
}

/// Data transferred during drag and drop from gallery to timeline.
///
/// Contains all information needed to create a clip when dropped on the timeline.
class GalleryDragData {
  /// The gallery image being dragged
  final GalleryImage image;

  /// The media type (image, video, audio)
  final DragMediaType mediaType;

  /// Duration in seconds (for videos/audio, default for images)
  final double durationSeconds;

  /// The URL to the full-size media
  final String sourceUrl;

  /// The path to the source file
  final String sourcePath;

  /// Optional thumbnail URL for preview
  final String? thumbnailUrl;

  const GalleryDragData({
    required this.image,
    required this.mediaType,
    this.durationSeconds = 0,
    required this.sourceUrl,
    required this.sourcePath,
    this.thumbnailUrl,
  });

  /// Create from a GalleryImage, detecting media type from filename
  factory GalleryDragData.fromGalleryImage(GalleryImage image) {
    final filename = image.filename.toLowerCase();
    DragMediaType mediaType;
    double durationSeconds = 0;

    // Detect media type from file extension
    if (_isVideoFile(filename)) {
      mediaType = DragMediaType.video;
      // Duration would be extracted from metadata if available
      durationSeconds = _extractDuration(image.metadata) ?? 5.0;
    } else if (_isAudioFile(filename)) {
      mediaType = DragMediaType.audio;
      durationSeconds = _extractDuration(image.metadata) ?? 5.0;
    } else {
      // Default to image
      mediaType = DragMediaType.image;
      durationSeconds = 5.0; // Default image duration on timeline
    }

    return GalleryDragData(
      image: image,
      mediaType: mediaType,
      durationSeconds: durationSeconds,
      sourceUrl: image.url,
      sourcePath: image.path,
      thumbnailUrl: image.thumbnailUrl,
    );
  }

  /// Check if filename is a video file
  static bool _isVideoFile(String filename) {
    const videoExtensions = [
      '.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.wmv', '.flv'
    ];
    return videoExtensions.any((ext) => filename.endsWith(ext));
  }

  /// Check if filename is an audio file
  static bool _isAudioFile(String filename) {
    const audioExtensions = [
      '.mp3', '.wav', '.aac', '.flac', '.ogg', '.m4a', '.wma'
    ];
    return audioExtensions.any((ext) => filename.endsWith(ext));
  }

  /// Extract duration from metadata if available
  static double? _extractDuration(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;

    // Try various metadata keys for duration
    final duration = metadata['duration'] ??
        metadata['Duration'] ??
        metadata['video_duration'] ??
        metadata['audio_duration'];

    if (duration is num) {
      return duration.toDouble();
    }
    if (duration is String) {
      // Try parsing as plain number
      final parsed = double.tryParse(duration);
      if (parsed != null) return parsed;

      // Try parsing as timecode (HH:MM:SS or MM:SS or MM:SS.ms)
      return _parseDurationString(duration);
    }
    return null;
  }

  /// Parse duration from common string formats
  static double? _parseDurationString(String duration) {
    final parts = duration.split(':');
    if (parts.length >= 2) {
      int hours = 0;
      int minutes = 0;
      double seconds = 0;

      if (parts.length == 3) {
        hours = int.tryParse(parts[0]) ?? 0;
        minutes = int.tryParse(parts[1]) ?? 0;
        seconds = double.tryParse(parts[2]) ?? 0;
      } else if (parts.length == 2) {
        minutes = int.tryParse(parts[0]) ?? 0;
        seconds = double.tryParse(parts[1]) ?? 0;
      }

      return hours * 3600.0 + minutes * 60.0 + seconds;
    }
    return null;
  }

  /// Whether this is a video
  bool get isVideo => mediaType == DragMediaType.video;

  /// Whether this is an image
  bool get isImage => mediaType == DragMediaType.image;

  /// Whether this is audio
  bool get isAudio => mediaType == DragMediaType.audio;

  /// Get a display name for the media
  String get displayName => image.filename;

  /// Get dimensions as a string
  String get dimensions => '${image.width}x${image.height}';

  /// Duration as a Duration object
  Duration get duration => Duration(milliseconds: (durationSeconds * 1000).round());

  /// Serialize to JSON string for cross-widget communication
  String toJson() {
    return jsonEncode({
      'mediaType': mediaType.name,
      'durationSeconds': durationSeconds,
      'sourceUrl': sourceUrl,
      'sourcePath': sourcePath,
      'thumbnailUrl': thumbnailUrl,
      'filename': image.filename,
      'width': image.width,
      'height': image.height,
    });
  }

  /// Deserialize from JSON string
  static GalleryDragData? fromJson(String jsonString) {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;

      // Create a minimal GalleryImage from the JSON data
      final image = GalleryImage(
        id: map['sourcePath'] as String? ?? '',
        filename: map['filename'] as String? ?? 'Untitled',
        path: map['sourcePath'] as String? ?? '',
        url: map['sourceUrl'] as String? ?? '',
        thumbnailUrl: map['thumbnailUrl'] as String?,
        width: map['width'] as int? ?? 0,
        height: map['height'] as int? ?? 0,
        size: 0,
        createdAt: DateTime.now(),
      );

      return GalleryDragData(
        image: image,
        mediaType: DragMediaType.values.firstWhere(
          (e) => e.name == map['mediaType'],
          orElse: () => DragMediaType.image,
        ),
        durationSeconds: (map['durationSeconds'] as num?)?.toDouble() ?? 0,
        sourceUrl: map['sourceUrl'] as String? ?? '',
        sourcePath: map['sourcePath'] as String? ?? '',
        thumbnailUrl: map['thumbnailUrl'] as String?,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() => 'GalleryDragData($displayName, type: $mediaType, duration: ${durationSeconds}s)';
}

/// A draggable wrapper for gallery items that can be dropped on the timeline.
///
/// Wraps gallery thumbnails and provides drag functionality with a semi-transparent
/// preview during drag operations.
///
/// Example usage:
/// ```dart
/// GalleryDraggableItem(
///   image: galleryImage,
///   child: GalleryImageCard(image: galleryImage, ...),
/// )
/// ```
class GalleryDraggableItem extends StatelessWidget {
  /// The gallery image to make draggable
  final GalleryImage image;

  /// The child widget to wrap
  final Widget child;

  /// Called when drag starts
  final VoidCallback? onDragStarted;

  /// Called when drag ends
  final void Function(bool wasAccepted)? onDragEnd;

  /// Called when dragging completes successfully
  final VoidCallback? onDragCompleted;

  /// Called when the drag was cancelled
  final VoidCallback? onDraggableCanceled;

  /// Custom feedback widget during drag
  final Widget? feedback;

  /// Widget to show in place while dragging
  final Widget? childWhenDragging;

  /// Size of the default feedback widget
  final Size feedbackSize;

  /// Whether to use long press to initiate drag (for mobile)
  final bool useLongPress;

  const GalleryDraggableItem({
    super.key,
    required this.image,
    required this.child,
    this.onDragStarted,
    this.onDragEnd,
    this.onDragCompleted,
    this.onDraggableCanceled,
    this.feedback,
    this.childWhenDragging,
    this.feedbackSize = const Size(120, 80),
    this.useLongPress = false,
  });

  @override
  Widget build(BuildContext context) {
    final dragData = GalleryDragData.fromGalleryImage(image);

    final feedbackWidget = feedback ?? _buildDefaultFeedback(context, dragData);
    final childWhenDraggingWidget = childWhenDragging ?? _buildChildWhenDragging();

    if (useLongPress) {
      return LongPressDraggable<GalleryDragData>(
        data: dragData,
        onDragStarted: onDragStarted,
        onDragEnd: (details) => onDragEnd?.call(details.wasAccepted),
        onDragCompleted: onDragCompleted,
        onDraggableCanceled: (_, __) => onDraggableCanceled?.call(),
        feedback: feedbackWidget,
        childWhenDragging: childWhenDraggingWidget,
        child: child,
      );
    }

    return Draggable<GalleryDragData>(
      data: dragData,
      onDragStarted: onDragStarted,
      onDragEnd: (details) => onDragEnd?.call(details.wasAccepted),
      onDragCompleted: onDragCompleted,
      onDraggableCanceled: (_, __) => onDraggableCanceled?.call(),
      feedback: feedbackWidget,
      childWhenDragging: childWhenDraggingWidget,
      child: child,
    );
  }

  /// Build the widget shown in place while dragging
  Widget _buildChildWhenDragging() {
    return Opacity(
      opacity: 0.5,
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.grey,
          BlendMode.saturation,
        ),
        child: child,
      ),
    );
  }

  /// Build the default drag feedback with thumbnail preview
  Widget _buildDefaultFeedback(BuildContext context, GalleryDragData data) {
    final colorScheme = Theme.of(context).colorScheme;
    final thumbnailUrl = data.thumbnailUrl ?? data.sourceUrl;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: feedbackSize.width,
          height: feedbackSize.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail background
              if (thumbnailUrl.isNotEmpty)
                Opacity(
                  opacity: 0.85,
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: colorScheme.surfaceContainerHighest,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        _getMediaIcon(data),
                        color: colorScheme.onSurfaceVariant,
                        size: 32,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    _getMediaIcon(data),
                    color: colorScheme.onSurfaceVariant,
                    size: 32,
                  ),
                ),
              // Gradient overlay for text readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Border
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              // Media type badge
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getMediaColor(data).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getMediaIcon(data),
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _getMediaLabel(data),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // File name and duration
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (data.durationSeconds > 0)
                          Text(
                            _formatDuration(data.duration),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 9,
                            ),
                          ),
                        if (data.durationSeconds > 0 && data.image.width > 0)
                          Text(
                            ' | ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 9,
                            ),
                          ),
                        if (data.image.width > 0)
                          Text(
                            data.dimensions,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 9,
                            ),
                          ),
                      ],
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

  IconData _getMediaIcon(GalleryDragData data) {
    switch (data.mediaType) {
      case DragMediaType.video:
        return Icons.videocam;
      case DragMediaType.audio:
        return Icons.audiotrack;
      case DragMediaType.image:
        return Icons.image;
    }
  }

  Color _getMediaColor(GalleryDragData data) {
    switch (data.mediaType) {
      case DragMediaType.video:
        return Colors.red;
      case DragMediaType.audio:
        return Colors.green;
      case DragMediaType.image:
        return Colors.blue;
    }
  }

  String _getMediaLabel(GalleryDragData data) {
    switch (data.mediaType) {
      case DragMediaType.video:
        return 'VIDEO';
      case DragMediaType.audio:
        return 'AUDIO';
      case DragMediaType.image:
        return 'IMAGE';
    }
  }

  /// Format duration for display
  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final centiseconds = (duration.inMilliseconds % 1000) ~/ 10;

    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
    return '0:${seconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}';
  }
}

/// A DragTarget wrapper that accepts GalleryDragData from gallery items.
///
/// Use this on the timeline or any widget that should accept dragged gallery items.
///
/// Example usage:
/// ```dart
/// GalleryDropTarget(
///   onAccept: (data) {
///     // Create clip from data
///     createClipFromGalleryDrag(data);
///   },
///   builder: (context, candidateData, rejectedData) {
///     final isHovering = candidateData.isNotEmpty;
///     return Container(
///       decoration: BoxDecoration(
///         border: isHovering ? Border.all(color: Colors.blue, width: 2) : null,
///       ),
///       child: TimelineWidget(...),
///     );
///   },
/// )
/// ```
class GalleryDropTarget extends StatelessWidget {
  /// Builder for the child widget
  final Widget Function(
    BuildContext context,
    List<GalleryDragData?> candidateData,
    List<dynamic> rejectedData,
  ) builder;

  /// Called when drag data is accepted
  final void Function(GalleryDragData data)? onAccept;

  /// Called when drag data is accepted with position details
  final void Function(DragTargetDetails<GalleryDragData> details)? onAcceptWithDetails;

  /// Called to determine whether the data will be accepted
  final bool Function(GalleryDragData? data)? onWillAccept;

  /// Called when a draggable enters or moves within the target
  final void Function(DragTargetDetails<GalleryDragData> details)? onMove;

  /// Called when a draggable leaves the target
  final void Function(GalleryDragData? data)? onLeave;

  const GalleryDropTarget({
    super.key,
    required this.builder,
    this.onAccept,
    this.onAcceptWithDetails,
    this.onWillAccept,
    this.onMove,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<GalleryDragData>(
      builder: builder,
      onAcceptWithDetails: (details) {
        onAcceptWithDetails?.call(details);
        onAccept?.call(details.data);
      },
      onWillAcceptWithDetails: onWillAccept != null
          ? (details) => onWillAccept!(details.data)
          : null,
      onMove: onMove,
      onLeave: onLeave,
    );
  }
}

/// Extension to easily check if a filename is a supported media type
extension GalleryMediaTypeExtension on String {
  /// Check if this filename represents a video file
  bool get isVideoFile {
    final lower = toLowerCase();
    const videoExtensions = [
      '.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.wmv', '.flv'
    ];
    return videoExtensions.any((ext) => lower.endsWith(ext));
  }

  /// Check if this filename represents an audio file
  bool get isAudioFile {
    final lower = toLowerCase();
    const audioExtensions = [
      '.mp3', '.wav', '.aac', '.flac', '.ogg', '.m4a', '.wma'
    ];
    return audioExtensions.any((ext) => lower.endsWith(ext));
  }

  /// Check if this filename represents an image file
  bool get isImageFile {
    final lower = toLowerCase();
    const imageExtensions = [
      '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff', '.svg'
    ];
    return imageExtensions.any((ext) => lower.endsWith(ext));
  }

  /// Get the DragMediaType for this filename
  DragMediaType get dragMediaType {
    if (isVideoFile) return DragMediaType.video;
    if (isAudioFile) return DragMediaType.audio;
    return DragMediaType.image;
  }
}
