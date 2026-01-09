import 'package:flutter/material.dart';
import '../models/editor_models.dart';

/// Preview resolution options for video playback
enum PreviewResolution {
  full('Full', 1.0),
  half('1/2', 0.5),
  quarter('1/4', 0.25);

  final String label;
  final double scale;
  const PreviewResolution(this.label, this.scale);
}

/// Available playback speed options
const List<double> _playbackSpeeds = [0.25, 0.5, 1.0, 2.0];

/// Video preview panel for the editor
///
/// Displays the video output at the current playhead position with
/// transport controls, volume, playback speed, and resolution options.
class PreviewPanel extends StatelessWidget {
  /// The actual video display widget (placeholder when null)
  final Widget? videoWidget;

  /// Current playhead position
  final EditorTime currentTime;

  /// Total duration of the video/project
  final EditorTime duration;

  /// Whether playback is currently active
  final bool isPlaying;

  /// Current playback speed multiplier
  final double playbackSpeed;

  /// Current volume level (0.0 - 1.0)
  final double volume;

  /// Whether loop playback is enabled
  final bool isLooping;

  /// Callback when play is requested
  final VoidCallback? onPlay;

  /// Callback when pause is requested
  final VoidCallback? onPause;

  /// Callback when stop is requested
  final VoidCallback? onStop;

  /// Callback when seeking to a specific time
  final Function(EditorTime)? onSeek;

  /// Callback when stepping forward one frame
  final VoidCallback? onStepForward;

  /// Callback when stepping backward one frame
  final VoidCallback? onStepBackward;

  /// Callback when playback speed is changed
  final Function(double)? onSpeedChanged;

  /// Callback when volume is changed
  final Function(double)? onVolumeChanged;

  /// Callback when loop mode is changed
  final Function(bool)? onLoopChanged;

  const PreviewPanel({
    super.key,
    this.videoWidget,
    required this.currentTime,
    required this.duration,
    this.isPlaying = false,
    this.playbackSpeed = 1.0,
    this.volume = 1.0,
    this.isLooping = false,
    this.onPlay,
    this.onPause,
    this.onStop,
    this.onSeek,
    this.onStepForward,
    this.onStepBackward,
    this.onSpeedChanged,
    this.onVolumeChanged,
    this.onLoopChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Video display area
        Expanded(
          child: _VideoDisplay(
            videoWidget: videoWidget,
          ),
        ),

        // Transport controls bar
        _TransportControls(
          currentTime: currentTime,
          duration: duration,
          isPlaying: isPlaying,
          playbackSpeed: playbackSpeed,
          volume: volume,
          isLooping: isLooping,
          onPlay: onPlay,
          onPause: onPause,
          onStop: onStop,
          onSeek: onSeek,
          onStepForward: onStepForward,
          onStepBackward: onStepBackward,
          onSpeedChanged: onSpeedChanged,
          onVolumeChanged: onVolumeChanged,
          onLoopChanged: onLoopChanged,
        ),
      ],
    );
  }
}

/// Video display area with letterboxing/pillarboxing
class _VideoDisplay extends StatefulWidget {
  final Widget? videoWidget;

  const _VideoDisplay({this.videoWidget});

  @override
  State<_VideoDisplay> createState() => _VideoDisplayState();
}

class _VideoDisplayState extends State<_VideoDisplay> {
  bool _isFullscreen = false;
  PreviewResolution _resolution = PreviewResolution.full;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Video or placeholder
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: widget.videoWidget ?? _buildPlaceholder(),
            ),
          ),

          // Top-right controls (fullscreen, resolution)
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Resolution selector
                _ResolutionSelector(
                  currentResolution: _resolution,
                  onChanged: (res) => setState(() => _resolution = res),
                ),
                const SizedBox(width: 4),
                // Fullscreen toggle
                _OverlayButton(
                  icon: _isFullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  tooltip: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                  onPressed: () {
                    setState(() => _isFullscreen = !_isFullscreen);
                    // TODO: Implement actual fullscreen logic
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a checkerboard pattern placeholder when no video is loaded
  Widget _buildPlaceholder() {
    return CustomPaint(
      painter: _CheckerboardPainter(),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No Video',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Checkerboard pattern painter for empty video placeholder
class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const int gridSize = 16;
    final Paint lightPaint = Paint()..color = const Color(0xFF2A2A2A);
    final Paint darkPaint = Paint()..color = const Color(0xFF1A1A1A);

    for (int y = 0; y < size.height / gridSize; y++) {
      for (int x = 0; x < size.width / gridSize; x++) {
        final paint = (x + y) % 2 == 0 ? lightPaint : darkPaint;
        canvas.drawRect(
          Rect.fromLTWH(
            x * gridSize.toDouble(),
            y * gridSize.toDouble(),
            gridSize.toDouble(),
            gridSize.toDouble(),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small overlay button for preview area
class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _OverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: 20,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolution selector dropdown
class _ResolutionSelector extends StatelessWidget {
  final PreviewResolution currentResolution;
  final Function(PreviewResolution) onChanged;

  const _ResolutionSelector({
    required this.currentResolution,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
      child: PopupMenuButton<PreviewResolution>(
        initialValue: currentResolution,
        onSelected: onChanged,
        tooltip: 'Preview Resolution',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentResolution.label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: Colors.white70,
              ),
            ],
          ),
        ),
        itemBuilder: (context) => PreviewResolution.values
            .map(
              (res) => PopupMenuItem(
                value: res,
                child: Text(res.label),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Transport controls bar below the video display
class _TransportControls extends StatelessWidget {
  final EditorTime currentTime;
  final EditorTime duration;
  final bool isPlaying;
  final double playbackSpeed;
  final double volume;
  final bool isLooping;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onStop;
  final Function(EditorTime)? onSeek;
  final VoidCallback? onStepForward;
  final VoidCallback? onStepBackward;
  final Function(double)? onSpeedChanged;
  final Function(double)? onVolumeChanged;
  final Function(bool)? onLoopChanged;

  const _TransportControls({
    required this.currentTime,
    required this.duration,
    required this.isPlaying,
    required this.playbackSpeed,
    required this.volume,
    required this.isLooping,
    this.onPlay,
    this.onPause,
    this.onStop,
    this.onSeek,
    this.onStepForward,
    this.onStepBackward,
    this.onSpeedChanged,
    this.onVolumeChanged,
    this.onLoopChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
      child: Row(
        children: [
          // Time display
          _TimeDisplay(
            currentTime: currentTime,
            duration: duration,
          ),

          const SizedBox(width: 16),

          // Main transport buttons
          _TransportButtons(
            isPlaying: isPlaying,
            onPlay: onPlay,
            onPause: onPause,
            onStop: onStop,
            onSeek: onSeek,
            onStepForward: onStepForward,
            onStepBackward: onStepBackward,
            duration: duration,
          ),

          const SizedBox(width: 16),

          // Loop toggle
          _LoopButton(
            isLooping: isLooping,
            onChanged: onLoopChanged,
          ),

          const Spacer(),

          // Playback speed selector
          _SpeedSelector(
            currentSpeed: playbackSpeed,
            onChanged: onSpeedChanged,
          ),

          const SizedBox(width: 16),

          // Volume control
          _VolumeControl(
            volume: volume,
            onChanged: onVolumeChanged,
          ),
        ],
      ),
    );
  }
}

/// Time display showing current time / total time in MM:SS:FF format
class _TimeDisplay extends StatelessWidget {
  final EditorTime currentTime;
  final EditorTime duration;

  const _TimeDisplay({
    required this.currentTime,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0d0d1a),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${_formatTime(currentTime)} / ${_formatTime(duration)}',
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Formats EditorTime as MM:SS:FF
  String _formatTime(EditorTime time) {
    final totalSeconds = time.inSeconds;
    final minutes = (totalSeconds / 60).floor();
    final seconds = (totalSeconds % 60).floor();
    final frames = ((totalSeconds % 1) * 30).round(); // 30fps assumed

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}:'
        '${frames.toString().padLeft(2, '0')}';
  }
}

/// Main transport buttons: |< << Play/Pause >> >|
class _TransportButtons extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onStop;
  final Function(EditorTime)? onSeek;
  final VoidCallback? onStepForward;
  final VoidCallback? onStepBackward;
  final EditorTime duration;

  const _TransportButtons({
    required this.isPlaying,
    this.onPlay,
    this.onPause,
    this.onStop,
    this.onSeek,
    this.onStepForward,
    this.onStepBackward,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Go to start |<
        IconButton(
          icon: const Icon(Icons.skip_previous),
          iconSize: 22,
          color: Colors.grey,
          tooltip: 'Go to Start',
          onPressed: () => onSeek?.call(const EditorTime.zero()),
        ),

        // Step backward <<
        IconButton(
          icon: const Icon(Icons.fast_rewind),
          iconSize: 22,
          color: Colors.grey,
          tooltip: 'Step Backward (1 frame)',
          onPressed: onStepBackward,
        ),

        // Play/Pause (highlighted)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            iconSize: 26,
            color: colorScheme.onPrimary,
            tooltip: isPlaying ? 'Pause' : 'Play',
            onPressed: isPlaying ? onPause : onPlay,
          ),
        ),

        // Step forward >>
        IconButton(
          icon: const Icon(Icons.fast_forward),
          iconSize: 22,
          color: Colors.grey,
          tooltip: 'Step Forward (1 frame)',
          onPressed: onStepForward,
        ),

        // Go to end >|
        IconButton(
          icon: const Icon(Icons.skip_next),
          iconSize: 22,
          color: Colors.grey,
          tooltip: 'Go to End',
          onPressed: () => onSeek?.call(duration),
        ),
      ],
    );
  }
}

/// Loop toggle button
class _LoopButton extends StatelessWidget {
  final bool isLooping;
  final Function(bool)? onChanged;

  const _LoopButton({
    required this.isLooping,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: const Icon(Icons.repeat),
      iconSize: 20,
      color: isLooping ? colorScheme.primary : Colors.grey,
      tooltip: isLooping ? 'Disable Loop' : 'Enable Loop',
      onPressed: () => onChanged?.call(!isLooping),
    );
  }
}

/// Playback speed selector dropdown
class _SpeedSelector extends StatelessWidget {
  final double currentSpeed;
  final Function(double)? onChanged;

  const _SpeedSelector({
    required this.currentSpeed,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<double>(
      initialValue: currentSpeed,
      onSelected: onChanged,
      tooltip: 'Playback Speed',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.speed,
              size: 16,
              color: Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              '${currentSpeed}x',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => _playbackSpeeds
          .map(
            (speed) => PopupMenuItem(
              value: speed,
              child: Text(
                '${speed}x',
                style: TextStyle(
                  fontWeight:
                      speed == currentSpeed ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

/// Volume control with icon and slider
class _VolumeControl extends StatefulWidget {
  final double volume;
  final Function(double)? onChanged;

  const _VolumeControl({
    required this.volume,
    this.onChanged,
  });

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  bool _showSlider = false;
  double _previousVolume = 1.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMuted = widget.volume == 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _showSlider = true),
      onExit: (_) => setState(() => _showSlider = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Volume icon / mute toggle
          IconButton(
            icon: Icon(
              isMuted
                  ? Icons.volume_off
                  : widget.volume < 0.5
                      ? Icons.volume_down
                      : Icons.volume_up,
            ),
            iconSize: 20,
            color: isMuted ? Colors.red : Colors.grey,
            tooltip: isMuted ? 'Unmute' : 'Mute',
            onPressed: () {
              if (isMuted) {
                widget.onChanged?.call(_previousVolume > 0 ? _previousVolume : 1.0);
              } else {
                _previousVolume = widget.volume;
                widget.onChanged?.call(0);
              }
            },
          ),

          // Volume slider (shown on hover)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _showSlider ? 80 : 0,
            child: _showSlider
                ? Slider(
                    value: widget.volume,
                    min: 0,
                    max: 1,
                    onChanged: widget.onChanged,
                    activeColor: colorScheme.primary,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
