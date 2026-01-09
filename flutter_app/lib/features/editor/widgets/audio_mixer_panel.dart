import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_track_models.dart';
import '../models/editor_models.dart';
import '../providers/audio_mixer_provider.dart';
import '../providers/editor_provider.dart';
import '../services/audio_ducking_service.dart';

/// Professional audio mixer panel with channel strips.
///
/// Features:
/// - Volume faders with dB scale
/// - Pan knobs
/// - Mute/Solo buttons
/// - Level meters
/// - Master fader
class AudioMixerPanel extends ConsumerWidget {
  /// Called when the panel should be closed
  final VoidCallback? onClose;

  const AudioMixerPanel({
    super.key,
    this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final tracks = ref.watch(tracksProvider);
    final mixerState = ref.watch(audioMixerProvider);

    // Filter to only audio tracks
    final audioTracks =
        tracks.where((t) => t.type == TrackType.audio).toList();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context),

          // Mixer content
          Expanded(
            child: Row(
              children: [
                // Channel strips
                Expanded(
                  child: audioTracks.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(8),
                          itemCount: audioTracks.length,
                          itemBuilder: (context, index) {
                            final track = audioTracks[index];
                            final state = mixerState.trackStates[track.id] ??
                                AudioTrackState(trackId: track.id);
                            return _ChannelStrip(
                              track: track,
                              state: state,
                              isAudible: mixerState.isTrackAudible(track.id),
                              onVolumeChanged: (volume) {
                                ref
                                    .read(audioMixerProvider.notifier)
                                    .setTrackVolume(track.id, volume);
                              },
                              onPanChanged: (pan) {
                                ref
                                    .read(audioMixerProvider.notifier)
                                    .setTrackPan(track.id, pan);
                              },
                              onMuteToggle: () {
                                ref
                                    .read(audioMixerProvider.notifier)
                                    .toggleTrackMute(track.id);
                              },
                              onSoloToggle: () {
                                ref
                                    .read(audioMixerProvider.notifier)
                                    .toggleTrackSolo(track.id);
                              },
                            );
                          },
                        ),
                ),

                // Divider
                VerticalDivider(
                  width: 1,
                  color: colorScheme.outlineVariant,
                ),

                // Master fader
                _MasterStrip(
                  volume: mixerState.masterVolume,
                  muted: mixerState.masterMuted,
                  level: mixerState.masterLevel,
                  peakLevel: mixerState.masterPeakLevel,
                  onVolumeChanged: (volume) {
                    ref.read(audioMixerProvider.notifier).setMasterVolume(volume);
                  },
                  onMuteToggle: () {
                    ref.read(audioMixerProvider.notifier).toggleMasterMute();
                  },
                  onResetPeaks: () {
                    ref.read(audioMixerProvider.notifier).resetAllPeaks();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.tune, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Audio Mixer',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          // Ducking button
          _DuckingButton(),
          const SizedBox(width: 8),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No audio tracks',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single channel strip in the mixer
class _ChannelStrip extends StatelessWidget {
  final Track track;
  final AudioTrackState state;
  final bool isAudible;
  final ValueChanged<double>? onVolumeChanged;
  final ValueChanged<double>? onPanChanged;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onSoloToggle;

  const _ChannelStrip({
    required this.track,
    required this.state,
    required this.isAudible,
    this.onVolumeChanged,
    this.onPanChanged,
    this.onMuteToggle,
    this.onSoloToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 80,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Track name
          Text(
            track.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isAudible
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Pan knob
          _PanKnob(
            value: state.pan,
            enabled: isAudible,
            onChanged: onPanChanged,
          ),
          const SizedBox(height: 4),

          // Pan value
          Text(
            state.panDisplay,
            style: TextStyle(
              fontSize: 9,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          // Fader and meter
          Expanded(
            child: Row(
              children: [
                // Level meter
                _LevelMeter(
                  level: state.currentLevel,
                  peakLevel: state.peakLevel,
                  enabled: isAudible,
                ),
                const SizedBox(width: 4),
                // Volume fader
                Expanded(
                  child: _VolumeFader(
                    value: state.volume,
                    enabled: isAudible,
                    onChanged: onVolumeChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Volume dB display
          Text(
            _formatDb(state.volumeDb),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          // Mute/Solo buttons
          Row(
            children: [
              Expanded(
                child: _MuteButton(
                  isMuted: state.muted,
                  onPressed: onMuteToggle,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _SoloButton(
                  isSolo: state.solo,
                  onPressed: onSoloToggle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDb(double db) {
    if (db == double.negativeInfinity) return '-inf';
    return '${db.toStringAsFixed(1)}dB';
  }
}

/// Master channel strip
class _MasterStrip extends StatelessWidget {
  final double volume;
  final bool muted;
  final double level;
  final double peakLevel;
  final ValueChanged<double>? onVolumeChanged;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onResetPeaks;

  const _MasterStrip({
    required this.volume,
    required this.muted,
    required this.level,
    required this.peakLevel,
    this.onVolumeChanged,
    this.onMuteToggle,
    this.onResetPeaks,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAudible = !muted;

    return Container(
      width: 90,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
      ),
      child: Column(
        children: [
          // Master label
          Text(
            'MASTER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Fader and stereo meter
          Expanded(
            child: Row(
              children: [
                // Left meter
                _LevelMeter(
                  level: level,
                  peakLevel: peakLevel,
                  enabled: isAudible,
                ),
                const SizedBox(width: 2),
                // Right meter
                _LevelMeter(
                  level: level * 0.95, // Slight variation
                  peakLevel: peakLevel,
                  enabled: isAudible,
                ),
                const SizedBox(width: 4),
                // Volume fader
                Expanded(
                  child: _VolumeFader(
                    value: volume,
                    enabled: isAudible,
                    onChanged: onVolumeChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Volume dB display
          Text(
            _formatDb(_volumeToDb(volume)),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          // Mute button
          _MuteButton(
            isMuted: muted,
            onPressed: onMuteToggle,
          ),
          const SizedBox(height: 4),

          // Reset peaks button
          TextButton(
            onPressed: onResetPeaks,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: Text(
              'Reset',
              style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDb(double db) {
    if (db == double.negativeInfinity) return '-inf';
    return '${db.toStringAsFixed(1)}dB';
  }

  double _volumeToDb(double volume) {
    if (volume <= 0) return double.negativeInfinity;
    return 20 * (math.log(volume) / math.ln10);
  }
}

/// Vertical volume fader widget
class _VolumeFader extends StatelessWidget {
  final double value;
  final bool enabled;
  final ValueChanged<double>? onChanged;

  const _VolumeFader({
    required this.value,
    required this.enabled,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RotatedBox(
      quarterTurns: 3, // Rotate to make vertical
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          activeTrackColor:
              enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
          inactiveTrackColor: colorScheme.onSurface.withOpacity(0.1),
          thumbColor:
              enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        child: Slider(
          value: value.clamp(0.0, 2.0),
          min: 0.0,
          max: 2.0, // +6dB
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

/// Pan knob widget
class _PanKnob extends StatelessWidget {
  final double value;
  final bool enabled;
  final ValueChanged<double>? onChanged;

  const _PanKnob({
    required this.value,
    required this.enabled,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onPanUpdate: enabled
          ? (details) {
              final delta = details.delta.dx / 50;
              final newValue = (value + delta).clamp(-1.0, 1.0);
              onChanged?.call(newValue);
            }
          : null,
      onDoubleTap: enabled ? () => onChanged?.call(0.0) : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: enabled
                ? colorScheme.primary.withOpacity(0.5)
                : colorScheme.outlineVariant,
          ),
        ),
        child: CustomPaint(
          painter: _PanKnobPainter(
            value: value,
            color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for pan knob indicator
class _PanKnobPainter extends CustomPainter {
  final double value;
  final Color color;

  _PanKnobPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Draw indicator line
    final angle = value * math.pi / 2 - math.pi / 2; // -90 to +90 degrees
    final endPoint = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );

    canvas.drawLine(
      center,
      endPoint,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Draw center dot
    canvas.drawCircle(
      center,
      2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _PanKnobPainter oldDelegate) {
    return value != oldDelegate.value || color != oldDelegate.color;
  }
}

/// Level meter widget
class _LevelMeter extends StatelessWidget {
  final double level;
  final double peakLevel;
  final bool enabled;

  const _LevelMeter({
    required this.level,
    required this.peakLevel,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 8,
      child: CustomPaint(
        painter: _LevelMeterPainter(
          level: enabled ? level : 0.0,
          peakLevel: enabled ? peakLevel : 0.0,
        ),
      ),
    );
  }
}

/// Custom painter for level meter
class _LevelMeterPainter extends CustomPainter {
  final double level;
  final double peakLevel;

  _LevelMeterPainter({required this.level, required this.peakLevel});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = Colors.black26,
    );

    // Segments
    final segmentCount = 20;
    final segmentHeight = size.height / segmentCount;
    final gapHeight = 1.0;

    for (int i = 0; i < segmentCount; i++) {
      final segmentLevel = 1.0 - (i / segmentCount);
      final isLit = level >= segmentLevel;

      if (isLit) {
        Color segmentColor;
        if (segmentLevel > 0.9) {
          segmentColor = Colors.red;
        } else if (segmentLevel > 0.7) {
          segmentColor = Colors.yellow;
        } else {
          segmentColor = Colors.green;
        }

        final segmentRect = Rect.fromLTWH(
          0,
          i * segmentHeight + gapHeight / 2,
          size.width,
          segmentHeight - gapHeight,
        );

        canvas.drawRect(
          segmentRect,
          Paint()..color = segmentColor,
        );
      }
    }

    // Peak indicator
    if (peakLevel > 0) {
      final peakY = size.height * (1.0 - peakLevel);
      canvas.drawRect(
        Rect.fromLTWH(0, peakY, size.width, 2),
        Paint()..color = peakLevel > 0.9 ? Colors.red : Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LevelMeterPainter oldDelegate) {
    return level != oldDelegate.level || peakLevel != oldDelegate.peakLevel;
  }
}

/// Mute button widget
class _MuteButton extends StatelessWidget {
  final bool isMuted;
  final VoidCallback? onPressed;

  const _MuteButton({
    required this.isMuted,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isMuted ? Colors.red : Colors.grey.shade700,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Text(
          'M',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isMuted ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// Solo button widget
class _SoloButton extends StatelessWidget {
  final bool isSolo;
  final VoidCallback? onPressed;

  const _SoloButton({
    required this.isSolo,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isSolo ? Colors.amber : Colors.grey.shade700,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Text(
          'S',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isSolo ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// Ducking toggle button with settings popup
class _DuckingButton extends ConsumerStatefulWidget {
  const _DuckingButton();

  @override
  ConsumerState<_DuckingButton> createState() => _DuckingButtonState();
}

class _DuckingButtonState extends ConsumerState<_DuckingButton> {
  bool _duckingEnabled = false;
  DuckingPreset _selectedPreset = DuckingPreset.presets[1]; // Podcast default

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<DuckingPreset?>(
      tooltip: 'Audio Ducking',
      onSelected: (preset) {
        if (preset == null) {
          setState(() => _duckingEnabled = !_duckingEnabled);
        } else {
          setState(() {
            _selectedPreset = preset;
            _duckingEnabled = true;
          });
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: null,
          child: Row(
            children: [
              Icon(
                _duckingEnabled ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text('Enable Auto-Ducking'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ...DuckingPreset.presets.map((preset) => PopupMenuItem(
          value: preset,
          child: Row(
            children: [
              if (preset.id == _selectedPreset.id)
                Icon(Icons.check, size: 16, color: colorScheme.primary)
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.name, style: const TextStyle(fontSize: 13)),
                    Text(
                      preset.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _duckingEnabled
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _duckingEnabled
                ? colorScheme.primary
                : colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volume_down,
              size: 16,
              color: _duckingEnabled
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              'Duck',
              style: TextStyle(
                fontSize: 11,
                fontWeight: _duckingEnabled ? FontWeight.w600 : FontWeight.normal,
                color: _duckingEnabled
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: _duckingEnabled
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
