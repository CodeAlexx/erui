import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vid_train_prep_models.dart';
import '../providers/vid_train_prep_provider.dart';

/// Timeline widget for displaying and interacting with video ranges.
///
/// Features:
/// - Visual timeline showing video duration as horizontal bar
/// - Colored blocks for each defined range
/// - Click on empty space to seek to that position
/// - Click on range block to select it
/// - Playhead indicator showing current position
/// - Time ruler with tick marks
/// - Current time / total duration display
class RangeTimelineWidget extends ConsumerStatefulWidget {
  /// Current playback position from video player
  final Duration? currentPosition;

  /// Callback when user seeks to a position
  final ValueChanged<Duration>? onSeek;

  /// Callback when user wants to add a range at a position
  final ValueChanged<int>? onAddRangeAtFrame;

  const RangeTimelineWidget({
    super.key,
    this.currentPosition,
    this.onSeek,
    this.onAddRangeAtFrame,
  });

  @override
  ConsumerState<RangeTimelineWidget> createState() => _RangeTimelineWidgetState();
}

class _RangeTimelineWidgetState extends ConsumerState<RangeTimelineWidget> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final selectedVideo = ref.watch(selectedVideoProvider);
    final ranges = ref.watch(rangesForSelectedVideoProvider);
    final selectedRangeId = ref.watch(vidTrainPrepProvider.select((s) => s.selectedRangeId));
    final colorScheme = Theme.of(context).colorScheme;

    if (selectedVideo == null) {
      return Container(
        height: 80,
        color: colorScheme.surfaceContainerLow,
        child: Center(
          child: Text(
            'No video selected',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 80,
      color: colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // Time display bar
          _TimeDisplayBar(
            currentPosition: widget.currentPosition ?? Duration.zero,
            totalDuration: selectedVideo.duration,
            colorScheme: colorScheme,
          ),
          // Timeline track
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTapUp: (details) => _handleTap(
                        details,
                        constraints.maxWidth,
                        selectedVideo,
                        ranges,
                      ),
                      onHorizontalDragStart: (details) {
                        setState(() => _isDragging = true);
                        _handleDrag(details.localPosition.dx, constraints.maxWidth, selectedVideo);
                      },
                      onHorizontalDragUpdate: (details) {
                        _handleDrag(details.localPosition.dx, constraints.maxWidth, selectedVideo);
                      },
                      onHorizontalDragEnd: (_) {
                        setState(() => _isDragging = false);
                      },
                      child: CustomPaint(
                        painter: _TimelinePainter(
                          video: selectedVideo,
                          ranges: ranges,
                          selectedRangeId: selectedRangeId,
                          currentPosition: widget.currentPosition,
                          colorScheme: colorScheme,
                          isDragging: _isDragging,
                        ),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(
    TapUpDetails details,
    double width,
    VideoSource video,
    List<ClipRange> ranges,
  ) {
    final ratio = (details.localPosition.dx / width).clamp(0.0, 1.0);
    final tappedFrame = (video.frameCount * ratio).round();

    // Check if tapped on a range
    for (final range in ranges) {
      if (tappedFrame >= range.startFrame && tappedFrame <= range.endFrame) {
        ref.read(vidTrainPrepProvider.notifier).selectRange(range.id);
        // Also seek to the start of the range
        final seekDuration = Duration(
          milliseconds: ((range.startFrame / video.fps) * 1000).round(),
        );
        widget.onSeek?.call(seekDuration);
        return;
      }
    }

    // If not on a range, seek to position
    final tappedDuration = Duration(
      milliseconds: ((tappedFrame / video.fps) * 1000).round(),
    );
    widget.onSeek?.call(tappedDuration);
  }

  void _handleDrag(double dx, double width, VideoSource video) {
    final ratio = (dx / width).clamp(0.0, 1.0);
    final frame = (video.frameCount * ratio).round();
    final duration = Duration(
      milliseconds: ((frame / video.fps) * 1000).round(),
    );
    widget.onSeek?.call(duration);
  }
}

/// Time display bar showing current time and total duration.
class _TimeDisplayBar extends StatelessWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final ColorScheme colorScheme;

  const _TimeDisplayBar({
    required this.currentPosition,
    required this.totalDuration,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            _formatDuration(currentPosition),
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          Text(
            '/ ${_formatDuration(totalDuration)}',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    final milliseconds = d.inMilliseconds % 1000;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${(milliseconds ~/ 100).toString()}';
  }
}

/// Custom painter for the timeline track.
class _TimelinePainter extends CustomPainter {
  final VideoSource video;
  final List<ClipRange> ranges;
  final String? selectedRangeId;
  final Duration? currentPosition;
  final ColorScheme colorScheme;
  final bool isDragging;

  _TimelinePainter({
    required this.video,
    required this.ranges,
    this.selectedRangeId,
    this.currentPosition,
    required this.colorScheme,
    this.isDragging = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate track dimensions
    const rulerHeight = 16.0;
    final trackTop = rulerHeight + 4;
    final trackHeight = size.height - trackTop - 4;
    final trackRect = Rect.fromLTWH(0, trackTop, size.width, trackHeight);

    // Draw time ruler
    _drawTimeRuler(canvas, size, rulerHeight);

    // Draw background track
    final trackPaint = Paint()
      ..color = colorScheme.surfaceContainerHighest
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(4)),
      trackPaint,
    );

    // Draw track border
    final borderPaint = Paint()
      ..color = colorScheme.outlineVariant.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(4)),
      borderPaint,
    );

    // Draw ranges
    for (int i = 0; i < ranges.length; i++) {
      final range = ranges[i];
      _drawRange(canvas, trackRect, range, i);
    }

    // Draw playhead
    if (currentPosition != null) {
      _drawPlayhead(canvas, size, trackTop, trackHeight);
    }
  }

  void _drawTimeRuler(Canvas canvas, Size size, double rulerHeight) {
    final textStyle = TextStyle(
      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
      fontSize: 9,
      fontFamily: 'monospace',
    );

    // Calculate appropriate interval based on duration
    final totalSeconds = video.duration.inSeconds.toDouble();
    final interval = _calculateTickInterval(totalSeconds, size.width);

    final tickPaint = Paint()
      ..color = colorScheme.onSurfaceVariant.withOpacity(0.3)
      ..strokeWidth = 1;

    final majorTickPaint = Paint()
      ..color = colorScheme.onSurfaceVariant.withOpacity(0.5)
      ..strokeWidth = 1;

    // Draw tick marks
    for (double t = 0; t <= totalSeconds; t += interval) {
      final x = (t / totalSeconds) * size.width;
      final isMajor = (t % (interval * 5)).abs() < 0.001 || t == 0;

      // Draw tick
      final tickHeight = isMajor ? 10.0 : 6.0;
      canvas.drawLine(
        Offset(x, rulerHeight - tickHeight),
        Offset(x, rulerHeight),
        isMajor ? majorTickPaint : tickPaint,
      );

      // Draw time label for major ticks
      if (isMajor && x < size.width - 30) {
        final label = _formatSeconds(t);
        final textPainter = TextPainter(
          text: TextSpan(text: label, style: textStyle),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        final labelX = x - textPainter.width / 2;
        if (labelX >= 0) {
          textPainter.paint(canvas, Offset(labelX, 0));
        }
      }
    }
  }

  double _calculateTickInterval(double totalSeconds, double width) {
    // Aim for roughly 10 major ticks
    final pixelsPerSecond = width / totalSeconds;

    if (pixelsPerSecond > 50) return 1; // 1 second
    if (pixelsPerSecond > 20) return 2; // 2 seconds
    if (pixelsPerSecond > 10) return 5; // 5 seconds
    if (pixelsPerSecond > 5) return 10; // 10 seconds
    if (pixelsPerSecond > 2) return 30; // 30 seconds
    return 60; // 1 minute
  }

  String _formatSeconds(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    if (mins > 0) {
      return '$mins:${secs.toString().padLeft(2, '0')}';
    }
    return '${secs}s';
  }

  void _drawRange(Canvas canvas, Rect trackRect, ClipRange range, int index) {
    final isSelected = range.id == selectedRangeId;

    // Calculate range position
    final startX = (range.startFrame / video.frameCount) * trackRect.width;
    final endX = (range.endFrame / video.frameCount) * trackRect.width;
    final rangeWidth = math.max(endX - startX, 4.0); // Minimum 4px width

    final rangeRect = Rect.fromLTWH(
      trackRect.left + startX,
      trackRect.top + 2,
      rangeWidth,
      trackRect.height - 4,
    );

    // Generate color based on index for visual distinction
    final baseColor = _getRangeColor(index);
    final fillColor = isSelected
        ? baseColor.withOpacity(0.9)
        : baseColor.withOpacity(0.6);

    // Draw range fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rangeRect, const Radius.circular(3)),
      fillPaint,
    );

    // Draw selection border
    if (isSelected) {
      final selectedBorderPaint = Paint()
        ..color = colorScheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rangeRect, const Radius.circular(3)),
        selectedBorderPaint,
      );

      // Draw glow effect
      final glowPaint = Paint()
        ..color = colorScheme.primary.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rangeRect, const Radius.circular(3)),
        glowPaint,
      );
    } else {
      // Draw subtle border for unselected ranges
      final borderPaint = Paint()
        ..color = baseColor.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rangeRect, const Radius.circular(3)),
        borderPaint,
      );
    }

    // Draw range index label if wide enough
    if (rangeWidth > 20) {
      final textStyle = TextStyle(
        color: Colors.white.withOpacity(0.9),
        fontSize: 10,
        fontWeight: FontWeight.w500,
      );

      final textPainter = TextPainter(
        text: TextSpan(text: '${index + 1}', style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Center the label
      final textX = rangeRect.left + (rangeRect.width - textPainter.width) / 2;
      final textY = rangeRect.top + (rangeRect.height - textPainter.height) / 2;

      // Only draw if it fits
      if (textPainter.width < rangeWidth - 4) {
        textPainter.paint(canvas, Offset(textX, textY));
      }
    }
  }

  Color _getRangeColor(int index) {
    // Generate distinct colors for ranges using golden ratio distribution
    const colors = [
      Color(0xFF4A90D9), // Blue
      Color(0xFF50C878), // Green
      Color(0xFFE6A23C), // Orange
      Color(0xFFAB47BC), // Purple
      Color(0xFFEC407A), // Pink
      Color(0xFF26A69A), // Teal
      Color(0xFFFFA726), // Amber
      Color(0xFF7E57C2), // Deep Purple
    ];

    return colors[index % colors.length];
  }

  void _drawPlayhead(Canvas canvas, Size size, double trackTop, double trackHeight) {
    final currentFrame = (currentPosition!.inMilliseconds / 1000 * video.fps).round();
    final playheadX = (currentFrame / video.frameCount) * size.width;

    // Draw playhead line
    final linePaint = Paint()
      ..color = isDragging ? Colors.red : Colors.red.withOpacity(0.9)
      ..strokeWidth = isDragging ? 3 : 2;

    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      linePaint,
    );

    // Draw playhead handle at top
    final handlePath = Path()
      ..moveTo(playheadX - 6, 0)
      ..lineTo(playheadX + 6, 0)
      ..lineTo(playheadX + 6, 8)
      ..lineTo(playheadX, 14)
      ..lineTo(playheadX - 6, 8)
      ..close();

    final handlePaint = Paint()
      ..color = isDragging ? Colors.red : Colors.red.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    canvas.drawPath(handlePath, handlePaint);

    // Draw glow when dragging
    if (isDragging) {
      final glowPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return ranges != oldDelegate.ranges ||
        selectedRangeId != oldDelegate.selectedRangeId ||
        currentPosition != oldDelegate.currentPosition ||
        isDragging != oldDelegate.isDragging ||
        video != oldDelegate.video;
  }
}
