import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/vid_train_prep_models.dart';

// Placeholder import - will be implemented separately
// import 'crop_selector_canvas.dart';

/// Video preview widget for VidTrainPrep feature.
///
/// Displays the selected video using media_kit with playback controls,
/// frame-accurate seeking, and optional crop overlay for defining
/// crop regions.
class VideoPreview extends ConsumerStatefulWidget {
  /// The video source to display (null shows empty state).
  final VideoSource? video;

  /// Current crop region (if any).
  final CropRegion? crop;

  /// Whether to show the interactive crop overlay.
  final bool showCropOverlay;

  /// Callback when crop region is changed by user interaction.
  final ValueChanged<CropRegion>? onCropChanged;

  /// Callback when playback position changes.
  final ValueChanged<Duration>? onPositionChanged;

  /// Callback when user seeks to a specific position.
  final ValueChanged<Duration>? onSeek;

  const VideoPreview({
    super.key,
    this.video,
    this.crop,
    this.showCropOverlay = false,
    this.onCropChanged,
    this.onPositionChanged,
    this.onSeek,
  });

  @override
  ConsumerState<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends ConsumerState<VideoPreview> {
  late Player _player;
  late VideoController _controller;
  bool _isInitialized = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isSeeking = false;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _setupListeners();

    // Load video if one is already provided
    if (widget.video != null) {
      _loadVideo();
    }
  }

  void _setupListeners() {
    _player.stream.position.listen((pos) {
      if (mounted && !_isSeeking) {
        setState(() => _position = pos);
        widget.onPositionChanged?.call(pos);
      }
    });

    _player.stream.duration.listen((dur) {
      if (mounted) {
        setState(() => _duration = dur);
      }
    });

    _player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() => _isPlaying = playing);
      }
    });

    _player.stream.volume.listen((vol) {
      if (mounted) {
        setState(() => _volume = vol / 100.0);
      }
    });
  }

  @override
  void didUpdateWidget(covariant VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.video?.filePath != oldWidget.video?.filePath) {
      _loadVideo();
    }
  }

  Future<void> _loadVideo() async {
    if (widget.video == null) {
      await _player.stop();
      setState(() {
        _isInitialized = false;
        _position = Duration.zero;
        _duration = Duration.zero;
        _isPlaying = false;
      });
      return;
    }

    try {
      // Use file:// URI for local files
      final filePath = widget.video!.filePath;
      final uri = filePath.startsWith('file://') ? filePath : 'file://$filePath';
      debugPrint('[VideoPreview] Loading video: $uri');
      await _player.open(Media(uri), play: false);
      setState(() => _isInitialized = true);
      debugPrint('[VideoPreview] Video loaded successfully');
    } catch (e) {
      debugPrint('[VideoPreview] Error loading video: $e');
      setState(() => _isInitialized = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.video == null) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Video display with optional crop overlay
        Expanded(
          child: Stack(
            children: [
              // Video player
              Container(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: widget.video!.aspectRatio,
                    child: Video(
                      controller: _controller,
                      controls: NoVideoControls,
                    ),
                  ),
                ),
              ),

              // Video info overlay (top-right)
              if (_isInitialized)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildInfoOverlay(),
                ),

              // Crop overlay (when enabled)
              if (widget.showCropOverlay && widget.onCropChanged != null)
                Positioned.fill(
                  child: _CropOverlayPlaceholder(
                    crop: widget.crop,
                    videoAspectRatio: widget.video!.aspectRatio,
                    onCropChanged: widget.onCropChanged!,
                  ),
                ),
            ],
          ),
        ),

        // Controls bar
        _buildControlsBar(),
      ],
    );
  }

  Widget _buildInfoOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.video!.width}x${widget.video!.height}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            '${widget.video!.fps.toStringAsFixed(2)} fps',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final hasVideo = widget.video != null && _isInitialized;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek slider
          _buildSeekSlider(colorScheme, hasVideo),

          const SizedBox(height: 4),

          // Transport controls row
          Row(
            children: [
              // Time display
              _buildTimeDisplay(colorScheme),

              const SizedBox(width: 12),

              // Frame step backward
              _buildIconButton(
                icon: Icons.keyboard_arrow_left,
                tooltip: 'Previous Frame (,)',
                onPressed: hasVideo ? () => _stepFrame(-1) : null,
                colorScheme: colorScheme,
              ),

              // Skip backward (10 frames)
              _buildIconButton(
                icon: Icons.fast_rewind,
                tooltip: 'Skip Back 10 Frames',
                onPressed: hasVideo ? () => _stepFrame(-10) : null,
                colorScheme: colorScheme,
              ),

              const SizedBox(width: 4),

              // Play/Pause button (highlighted)
              Container(
                decoration: BoxDecoration(
                  color: hasVideo ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 26,
                  color: hasVideo ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                  tooltip: _isPlaying ? 'Pause (Space)' : 'Play (Space)',
                  onPressed: hasVideo ? _togglePlayPause : null,
                ),
              ),

              const SizedBox(width: 4),

              // Skip forward (10 frames)
              _buildIconButton(
                icon: Icons.fast_forward,
                tooltip: 'Skip Forward 10 Frames',
                onPressed: hasVideo ? () => _stepFrame(10) : null,
                colorScheme: colorScheme,
              ),

              // Frame step forward
              _buildIconButton(
                icon: Icons.keyboard_arrow_right,
                tooltip: 'Next Frame (.)',
                onPressed: hasVideo ? () => _stepFrame(1) : null,
                colorScheme: colorScheme,
              ),

              const Spacer(),

              // Frame number display
              if (hasVideo) _buildFrameDisplay(colorScheme),

              const SizedBox(width: 12),

              // Volume control
              _buildVolumeControl(colorScheme, hasVideo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeekSlider(ColorScheme colorScheme, bool hasVideo) {
    final maxValue = _duration.inMilliseconds.toDouble();
    final currentValue = _position.inMilliseconds.toDouble().clamp(0.0, maxValue);

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withOpacity(0.2),
      ),
      child: Slider(
        value: hasVideo ? currentValue : 0,
        max: hasVideo && maxValue > 0 ? maxValue : 1,
        onChangeStart: hasVideo
            ? (_) {
                setState(() => _isSeeking = true);
              }
            : null,
        onChanged: hasVideo
            ? (value) {
                final position = Duration(milliseconds: value.round());
                setState(() => _position = position);
              }
            : null,
        onChangeEnd: hasVideo
            ? (value) {
                final position = Duration(milliseconds: value.round());
                _seek(position);
                setState(() => _isSeeking = false);
              }
            : null,
      ),
    );
  }

  Widget _buildTimeDisplay(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0d0d1a),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${_formatTimecode(_position)} / ${_formatTimecode(_duration)}',
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFrameDisplay(ColorScheme colorScheme) {
    final currentFrame = _positionToFrame(_position);
    final totalFrames = widget.video?.frameCount ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'F: $currentFrame / $totalFrames',
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontFamily: 'monospace',
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required ColorScheme colorScheme,
  }) {
    return IconButton(
      icon: Icon(icon),
      iconSize: 22,
      color: onPressed != null ? Colors.grey : colorScheme.onSurfaceVariant.withOpacity(0.3),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget _buildVolumeControl(ColorScheme colorScheme, bool hasVideo) {
    final isMuted = _volume == 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            isMuted
                ? Icons.volume_off
                : _volume < 0.5
                    ? Icons.volume_down
                    : Icons.volume_up,
          ),
          iconSize: 20,
          color: isMuted ? Colors.red : Colors.grey,
          tooltip: isMuted ? 'Unmute' : 'Mute',
          onPressed: hasVideo ? _toggleMute : null,
        ),
        SizedBox(
          width: 80,
          child: Slider(
            value: _volume,
            min: 0,
            max: 1,
            onChanged: hasVideo
                ? (value) {
                    _player.setVolume(value * 100);
                  }
                : null,
            activeColor: colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_off_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select a video',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a video from the list to preview',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Empty controls bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
            ),
            child: _buildControlsBar(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Playback Controls
  // ============================================================

  void _togglePlayPause() {
    _player.playOrPause();
  }

  void _seek(Duration position) {
    // Clamp to valid range
    final clamped = Duration(
      milliseconds: position.inMilliseconds.clamp(0, _duration.inMilliseconds),
    );
    _player.seek(clamped);
    widget.onSeek?.call(clamped);
  }

  void _stepFrame(int frames) {
    if (widget.video == null) return;

    // Calculate frame duration based on video FPS
    final fps = widget.video!.fps;
    final frameDurationMs = (1000 / fps).round();
    final frameDuration = Duration(milliseconds: frameDurationMs);

    // Calculate new position
    final newPosition = _position + (frameDuration * frames);

    // Pause playback for frame stepping
    if (_isPlaying) {
      _player.pause();
    }

    _seek(newPosition);
  }

  void _toggleMute() {
    if (_volume > 0) {
      _player.setVolume(0);
    } else {
      _player.setVolume(100);
    }
  }

  // ============================================================
  // Utility Methods
  // ============================================================

  /// Formats duration as MM:SS:FF (minutes:seconds:frames).
  String _formatTimecode(Duration duration) {
    final fps = widget.video?.fps ?? 30.0;
    final totalSeconds = duration.inMilliseconds / 1000;
    final minutes = (totalSeconds / 60).floor();
    final seconds = (totalSeconds % 60).floor();
    final frames = ((totalSeconds % 1) * fps).round();

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}:'
        '${frames.toString().padLeft(2, '0')}';
  }

  /// Converts position to frame number.
  int _positionToFrame(Duration position) {
    if (widget.video == null) return 0;
    final fps = widget.video!.fps;
    return (position.inMilliseconds / 1000 * fps).round();
  }
}

/// Placeholder widget for crop overlay - will be replaced with CropSelectorCanvas.
///
/// This shows a visual representation of the crop region over the video.
class _CropOverlayPlaceholder extends StatelessWidget {
  final CropRegion? crop;
  final double videoAspectRatio;
  final ValueChanged<CropRegion> onCropChanged;

  const _CropOverlayPlaceholder({
    required this.crop,
    required this.videoAspectRatio,
    required this.onCropChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate video display area within container
        final containerAspect = constraints.maxWidth / constraints.maxHeight;
        double videoWidth, videoHeight;
        double offsetX = 0, offsetY = 0;

        if (containerAspect > videoAspectRatio) {
          // Container is wider - video is pillarboxed
          videoHeight = constraints.maxHeight;
          videoWidth = videoHeight * videoAspectRatio;
          offsetX = (constraints.maxWidth - videoWidth) / 2;
        } else {
          // Container is taller - video is letterboxed
          videoWidth = constraints.maxWidth;
          videoHeight = videoWidth / videoAspectRatio;
          offsetY = (constraints.maxHeight - videoHeight) / 2;
        }

        // Default crop is full frame
        final currentCrop = crop ?? const CropRegion.full();

        // Calculate crop rectangle in display coordinates
        final cropRect = Rect.fromLTWH(
          offsetX + currentCrop.x * videoWidth,
          offsetY + currentCrop.y * videoHeight,
          currentCrop.width * videoWidth,
          currentCrop.height * videoHeight,
        );

        return Stack(
          children: [
            // Dimmed overlay outside crop region
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _CropDimmerPainter(
                cropRect: cropRect,
                dimColor: Colors.black54,
              ),
            ),

            // Crop border
            Positioned(
              left: cropRect.left,
              top: cropRect.top,
              width: cropRect.width,
              height: cropRect.height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),

            // Instruction text
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Drag to adjust crop region',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Custom painter for dimming areas outside the crop region.
class _CropDimmerPainter extends CustomPainter {
  final Rect cropRect;
  final Color dimColor;

  _CropDimmerPainter({
    required this.cropRect,
    required this.dimColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dimColor;

    // Create path covering entire canvas
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Subtract crop region
    final cropPath = Path()..addRect(cropRect);
    final combinedPath = Path.combine(PathOperation.difference, fullPath, cropPath);

    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _CropDimmerPainter oldDelegate) {
    return cropRect != oldDelegate.cropRect || dimColor != oldDelegate.dimColor;
  }
}

/// Keyboard shortcuts handler for video preview.
///
/// Wrap VideoPreview with this widget to enable keyboard shortcuts.
class VideoPreviewKeyboardHandler extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPlayPause;
  final VoidCallback? onStepForward;
  final VoidCallback? onStepBackward;
  final VoidCallback? onSkipForward;
  final VoidCallback? onSkipBackward;

  const VideoPreviewKeyboardHandler({
    super.key,
    required this.child,
    this.onPlayPause,
    this.onStepForward,
    this.onStepBackward,
    this.onSkipForward,
    this.onSkipBackward,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Space - play/pause
          if (event.logicalKey == LogicalKeyboardKey.space) {
            onPlayPause?.call();
            return KeyEventResult.handled;
          }
          // Period - step forward
          if (event.logicalKey == LogicalKeyboardKey.period) {
            onStepForward?.call();
            return KeyEventResult.handled;
          }
          // Comma - step backward
          if (event.logicalKey == LogicalKeyboardKey.comma) {
            onStepBackward?.call();
            return KeyEventResult.handled;
          }
          // Right arrow - skip forward
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            onSkipForward?.call();
            return KeyEventResult.handled;
          }
          // Left arrow - skip backward
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            onSkipBackward?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
