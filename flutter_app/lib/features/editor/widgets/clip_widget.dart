import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../providers/clip_thumbnail_provider.dart';
import '../providers/editor_provider.dart';

/// A widget representing a single clip on the video editor timeline.
///
/// Displays clip information including name, type icon, thumbnail preview,
/// and supports dragging, resizing from edges, and selection highlighting.
class ClipWidget extends ConsumerStatefulWidget {
  /// The clip data model
  final EditorClip clip;

  /// Zoom level in pixels per second
  final double pixelsPerSecond;

  /// Whether this clip is currently selected
  final bool isSelected;

  /// Called when the clip is tapped
  final VoidCallback? onTap;

  /// Called during drag updates for moving the clip
  final Function(DragUpdateDetails)? onDragUpdate;

  /// Called when drag ends
  final Function(DragEndDetails)? onDragEnd;

  /// Called during resize operations
  /// [deltaWidth] is the change in width
  /// [fromStart] is true if resizing from the left edge
  final Function(double deltaWidth, bool fromStart)? onResize;

  /// Called when resize operation ends
  final VoidCallback? onResizeEnd;

  /// Called when "Extract frames for training" is selected from context menu
  final VoidCallback? onExtractFramesForTraining;

  const ClipWidget({
    super.key,
    required this.clip,
    required this.pixelsPerSecond,
    this.isSelected = false,
    this.onTap,
    this.onDragUpdate,
    this.onDragEnd,
    this.onResize,
    this.onResizeEnd,
    this.onExtractFramesForTraining,
  });

  @override
  ConsumerState<ClipWidget> createState() => _ClipWidgetState();
}

class _ClipWidgetState extends ConsumerState<ClipWidget>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isResizingStart = false;
  bool _isResizingEnd = false;

  late AnimationController _selectionAnimController;
  late Animation<double> _selectionGlow;

  /// Width of the resize handle zones
  static const double _resizeHandleWidth = 8.0;

  /// Minimum clip width in pixels
  static const double _minClipWidth = 30.0;

  @override
  void initState() {
    super.initState();
    _selectionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _selectionGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _selectionAnimController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isSelected) {
      _selectionAnimController.forward();
    }
  }

  @override
  void didUpdateWidget(ClipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _selectionAnimController.forward();
      } else {
        _selectionAnimController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _selectionAnimController.dispose();
    super.dispose();
  }

  /// Calculate clip width based on duration and zoom level
  double get _clipWidth {
    final width = widget.clip.duration.inSeconds * widget.pixelsPerSecond;
    return width.clamp(_minClipWidth, double.infinity);
  }

  /// Get the appropriate color for the clip type
  Color _getClipColor() {
    switch (widget.clip.type) {
      case ClipType.video:
        return const Color(0xFF4A90D9); // Blue
      case ClipType.audio:
        return const Color(0xFF50C878); // Green
      case ClipType.image:
        return const Color(0xFFE6A23C); // Orange
      case ClipType.text:
        return const Color(0xFFAB68FF); // Purple
      case ClipType.effect:
        return const Color(0xFFFF6B6B); // Red
      case ClipType.transition:
        return const Color(0xFF45B7D1); // Cyan
    }
  }

  /// Get the icon for the clip type
  IconData _getClipIcon() {
    switch (widget.clip.type) {
      case ClipType.video:
        return Icons.videocam_rounded;
      case ClipType.audio:
        return Icons.audiotrack_rounded;
      case ClipType.image:
        return Icons.image_rounded;
      case ClipType.text:
        return Icons.text_fields_rounded;
      case ClipType.effect:
        return Icons.auto_awesome_rounded;
      case ClipType.transition:
        return Icons.compare_arrows_rounded;
    }
  }

  /// Format duration for display
  String _formatDuration(EditorTime duration) {
    final seconds = duration.inSeconds;
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)}s';
    }
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toStringAsFixed(0).padLeft(2, '0')}';
  }

  /// Build tooltip message for clip info
  String _buildTooltipMessage() {
    final lines = <String>[
      widget.clip.name,
      'Duration: ${_formatDuration(widget.clip.duration)}',
      'Type: ${widget.clip.type.name[0].toUpperCase()}${widget.clip.type.name.substring(1)}',
    ];
    if (widget.clip.sourcePath != null) {
      // Show just filename, not full path
      final fileName = widget.clip.sourcePath!.split('/').last.split('\\').last;
      lines.add('Source: $fileName');
    }
    if (widget.clip.isLocked) {
      lines.add('(Locked)');
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clipColor = _getClipColor();
    final clipWidth = _clipWidth;

    return Tooltip(
      message: _buildTooltipMessage(),
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: _getCursor(),
        child: AnimatedBuilder(
        animation: _selectionGlow,
        builder: (context, child) {
          return Container(
            width: clipWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                // Base shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
                // Selection glow
                if (widget.isSelected)
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.4 * _selectionGlow.value),
                    blurRadius: 12 * _selectionGlow.value,
                    spreadRadius: 2 * _selectionGlow.value,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  // Main clip content
                  _buildClipContent(clipColor, colorScheme),

                  // Selection border overlay
                  if (widget.isSelected)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Locked overlay
                  if (widget.clip.isLocked) _buildLockedOverlay(colorScheme),

                  // Resize handles (only visible on hover and not locked)
                  if (_isHovered && !widget.clip.isLocked) ...[
                    _buildResizeHandle(true, clipWidth),
                    _buildResizeHandle(false, clipWidth),
                  ],

                  // Drag area (excludes resize handles)
                  if (!widget.clip.isLocked)
                    Positioned(
                      left: _resizeHandleWidth,
                      right: _resizeHandleWidth,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: widget.onTap,
                        onSecondaryTapUp: (details) {
                          _showContextMenu(context, details.globalPosition);
                        },
                        onPanUpdate: widget.onDragUpdate,
                        onPanEnd: widget.onDragEnd,
                        behavior: HitTestBehavior.opaque,
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  /// Build the main clip content
  Widget _buildClipContent(Color clipColor, ColorScheme colorScheme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail preview as background (full coverage)
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: _buildThumbnailPreview(clipColor),
        ),
        // Semi-transparent gradient overlay for better text visibility
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                clipColor.withOpacity(0.4),
                clipColor.withOpacity(0.2),
              ],
            ),
          ),
        ),
        // Waveform for audio clips
        if (widget.clip.type == ClipType.audio)
          _buildWaveformPreview(clipColor),
        // Top bar with clip info
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildClipHeader(clipColor),
        ),
        // Duration overlay (bottom right)
        Positioned(
          bottom: 4,
          right: 6,
          child: _buildDurationBadge(clipColor),
        ),
        // Opacity indicator (if not 100%)
        if (widget.clip.opacity < 1.0)
          Positioned(
            bottom: 4,
            left: 6,
            child: _buildOpacityBadge(clipColor),
          ),
      ],
    );
  }

  /// Build thumbnail preview with actual video frames
  Widget _buildThumbnailPreview(Color clipColor) {
    // Triple logging to ensure we see the output somewhere
    debugPrint('[ClipWidget] >>> _buildThumbnailPreview called for: ${widget.clip.name}, type: ${widget.clip.type}, sourcePath: ${widget.clip.sourcePath}');
    print('PRINT: [ClipWidget] >>> _buildThumbnailPreview called');
    
    // Only video clips get frame thumbnails
    if (widget.clip.type != ClipType.video || widget.clip.sourcePath == null) {
      debugPrint('[ClipWidget] Skipping thumbnails - not a video clip or no sourcePath');
      print('PRINT: Skipping thumbnails');
      return Opacity(
        opacity: 0.15,
        child: CustomPaint(
          painter: _ThumbnailPlaceholderPainter(
            color: Colors.white,
            clipType: widget.clip.type,
          ),
        ),
      );
    }
    
    debugPrint('[ClipWidget] Video clip detected, requesting thumbnails...');
    print('PRINT: [ClipWidget] Video clip detected!');

    // Calculate how many thumbnails to show based on clip width
    final thumbnailCount = ClipThumbnailCache.getThumbnailCount(_clipWidth);

    // Watch the thumbnail provider
    final thumbnailsAsync = ref.watch(
      clipThumbnailsProvider((clip: widget.clip, count: thumbnailCount)),
    );

    return thumbnailsAsync.when(
      data: (thumbnails) {
        print('[ClipWidget] Got ${thumbnails.length} thumbnails for ${widget.clip.name}');
        if (thumbnails.isEmpty) {
          print('[ClipWidget] Thumbnails list is empty!');
          return _buildPlaceholderPattern();
        }
        print('[ClipWidget] First thumbnail size: ${thumbnails.first.length} bytes');
        // DEBUG: Show green if thumbnails exist, red containers for each image
        return Container(
          color: Colors.green.withOpacity(0.5), // DEBUG: green = thumbnails loaded
          child: Row(
            children: thumbnails
                .take(10) // Limit to 10 for performance
                .map(
                  (bytes) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(1),
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stack) {
                          print('[ClipWidget] Image error: $error');
                          return Container(color: Colors.red); // red = image decode error
                        },
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
      loading: () {
        print('[ClipWidget] Loading thumbnails for ${widget.clip.name}...');
        return Stack(
          children: [
            _buildPlaceholderPattern(),
            const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
              ),
            ),
          ],
        );
      },
      error: (error, stack) {
        print('[ClipWidget] ERROR extracting thumbnails for ${widget.clip.name}: $error');
        return _buildPlaceholderPattern();
      },
    );
  }

  Widget _buildPlaceholderPattern() {
    return Opacity(
      opacity: 0.15,
      child: CustomPaint(
        painter: _ThumbnailPlaceholderPainter(
          color: Colors.white,
          clipType: widget.clip.type,
        ),
      ),
    );
  }

  /// Build waveform preview placeholder for audio clips
  Widget _buildWaveformPreview(Color clipColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: CustomPaint(
        painter: _WaveformPlaceholderPainter(
          color: Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }

  /// Build the clip header with icon and name
  Widget _buildClipHeader(Color clipColor) {
    final darkerColor = HSLColor.fromColor(clipColor)
        .withLightness(
            (HSLColor.fromColor(clipColor).lightness * 0.6).clamp(0.0, 1.0))
        .toColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            darkerColor.withOpacity(0.9),
            darkerColor.withOpacity(0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getClipIcon(),
            size: 14,
            color: Colors.white.withOpacity(0.9),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.clip.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 2,
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// Build duration badge
  Widget _buildDurationBadge(Color clipColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        _formatDuration(widget.clip.duration),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Build opacity badge
  Widget _buildOpacityBadge(Color clipColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.opacity,
            size: 10,
            color: Colors.white.withOpacity(0.8),
          ),
          const SizedBox(width: 2),
          Text(
            '${(widget.clip.opacity * 100).round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build locked state overlay
  Widget _buildLockedOverlay(ColorScheme colorScheme) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_rounded,
              size: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }

  /// Build resize handle
  Widget _buildResizeHandle(bool isStart, double clipWidth) {
    return Positioned(
      left: isStart ? 0 : null,
      right: isStart ? null : 0,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onHorizontalDragStart: (_) {
          setState(() {
            if (isStart) {
              _isResizingStart = true;
            } else {
              _isResizingEnd = true;
            }
          });
        },
        onHorizontalDragUpdate: (details) {
          widget.onResize?.call(details.delta.dx, isStart);
        },
        onHorizontalDragEnd: (_) {
          setState(() {
            _isResizingStart = false;
            _isResizingEnd = false;
          });
          widget.onResizeEnd?.call();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _resizeHandleWidth,
          decoration: BoxDecoration(
            color: (_isResizingStart && isStart) || (_isResizingEnd && !isStart)
                ? Colors.white.withOpacity(0.4)
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.horizontal(
              left: isStart ? const Radius.circular(6) : Radius.zero,
              right: isStart ? Radius.zero : const Radius.circular(6),
            ),
          ),
          child: Center(
            child: Container(
              width: 2,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show rename dialog for the clip
  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.clip.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Clip'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Clip Name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              ref.read(editorProjectProvider.notifier).setClipName(widget.clip.id, value);
            }
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(editorProjectProvider.notifier).setClipName(widget.clip.id, controller.text);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  /// Get appropriate cursor based on hover position
  MouseCursor _getCursor() {
    if (widget.clip.isLocked) {
      return SystemMouseCursors.forbidden;
    }
    if (_isResizingStart || _isResizingEnd) {
      return SystemMouseCursors.resizeColumn;
    }
    return SystemMouseCursors.grab;
  }

  /// Show context menu for clip actions
  void _showContextMenu(BuildContext context, Offset globalPosition) {
    final colorScheme = Theme.of(context).colorScheme;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 8),
              const Text('Rename'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 8),
              const Text('Duplicate'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'create_compound',
          child: Row(
            children: [
              Icon(Icons.layers, size: 18, color: colorScheme.tertiary),
              const SizedBox(width: 8),
              Text(
                'Create Compound Clip',
                style: TextStyle(color: colorScheme.tertiary),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        // Only show training option for video clips
        if (widget.clip.type == ClipType.video)
          PopupMenuItem<String>(
            value: 'extract_frames',
            child: Row(
              children: [
                Icon(Icons.model_training, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Extract frames for training...',
                  style: TextStyle(color: colorScheme.primary),
                ),
              ],
            ),
          ),
        if (widget.clip.type == ClipType.video) const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: colorScheme.error),
              const SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: colorScheme.error)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'extract_frames':
          widget.onExtractFramesForTraining?.call();
          break;
        case 'rename':
          _showRenameDialog(context);
          break;
        case 'duplicate':
          ref.read(editorProjectProvider.notifier).duplicateClip(widget.clip.id);
          break;
        case 'create_compound':
          // Compound clips not yet implemented
          break;
        case 'delete':
          ref.read(editorProjectProvider.notifier).removeClip(widget.clip.id);
          break;
      }
    });
  }
}

/// Custom painter for thumbnail placeholder
class _ThumbnailPlaceholderPainter extends CustomPainter {
  final Color color;
  final ClipType clipType;

  _ThumbnailPlaceholderPainter({
    required this.color,
    required this.clipType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw diagonal lines pattern
    const spacing = 12.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThumbnailPlaceholderPainter oldDelegate) {
    return color != oldDelegate.color || clipType != oldDelegate.clipType;
  }
}

/// Custom painter for waveform placeholder
class _WaveformPlaceholderPainter extends CustomPainter {
  final Color color;

  _WaveformPlaceholderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;

    final centerY = size.height / 2;
    final barWidth = 2.0;
    final spacing = 4.0;
    final totalBars = (size.width / (barWidth + spacing)).floor();

    // Generate pseudo-random heights for waveform visualization
    for (int i = 0; i < totalBars; i++) {
      // Create varying heights using a simple deterministic pattern
      final seed = (i * 7 + 11) % 13;
      final heightRatio = 0.2 + (seed / 13.0) * 0.8;
      final barHeight = size.height * heightRatio * 0.8;

      final x = i * (barWidth + spacing);
      final y = centerY - barHeight / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPlaceholderPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
