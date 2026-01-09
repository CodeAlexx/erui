import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/noise_reduction_service.dart';

/// Panel for noise reduction settings.
///
/// Features:
/// - Video noise reduction (hqdn3d, nlmeans)
/// - Audio noise reduction (afftdn)
/// - Presets for common scenarios
/// - Strength sliders
class NoiseReductionPanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final void Function(VideoNoiseSettings? video, AudioNoiseSettings? audio)? onApply;

  const NoiseReductionPanel({
    super.key,
    this.onClose,
    this.onApply,
  });

  @override
  ConsumerState<NoiseReductionPanel> createState() => _NoiseReductionPanelState();
}

class _NoiseReductionPanelState extends ConsumerState<NoiseReductionPanel> {
  bool _enableVideoNoise = true;
  bool _enableAudioNoise = true;
  VideoNoiseSettings _videoSettings = const VideoNoiseSettings();
  AudioNoiseSettings _audioSettings = const AudioNoiseSettings();
  NoiseReductionPreset? _selectedPreset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context),

          // Preset selector
          _buildPresetSelector(context),

          // Settings
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video noise reduction
                  _buildVideoSection(context),

                  const SizedBox(height: 16),

                  // Audio noise reduction
                  _buildAudioSection(context),
                ],
              ),
            ),
          ),

          // Apply button
          _buildApplyButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.blur_off, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Noise Reduction',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildPresetSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: DropdownButtonFormField<NoiseReductionPreset>(
        value: _selectedPreset,
        decoration: const InputDecoration(
          labelText: 'Preset',
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('Custom'),
          ),
          ...NoiseReductionPreset.presets.map((preset) {
            return DropdownMenuItem(
              value: preset,
              child: Text(preset.name),
            );
          }),
        ],
        onChanged: (preset) {
          setState(() {
            _selectedPreset = preset;
            if (preset != null) {
              _enableVideoNoise = preset.videoSettings != null;
              _enableAudioNoise = preset.audioSettings != null;
              if (preset.videoSettings != null) {
                _videoSettings = preset.videoSettings!;
              }
              if (preset.audioSettings != null) {
                _audioSettings = preset.audioSettings!;
              }
            }
          });
        },
      ),
    );
  }

  Widget _buildVideoSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Switch(
              value: _enableVideoNoise,
              onChanged: (v) => setState(() => _enableVideoNoise = v),
            ),
            const SizedBox(width: 8),
            Text(
              'Video Noise Reduction',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),

        if (_enableVideoNoise) ...[
          const SizedBox(height: 12),

          // Method selector
          Text(
            'Method',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          SegmentedButton<VideoNoiseMethod>(
            segments: VideoNoiseMethod.values.map((m) {
              return ButtonSegment(
                value: m,
                label: Text(m == VideoNoiseMethod.hqdn3d ? 'Fast' : 'Quality', style: const TextStyle(fontSize: 11)),
              );
            }).toList(),
            selected: {_videoSettings.method},
            onSelectionChanged: (v) {
              setState(() {
                _videoSettings = _videoSettings.copyWith(method: v.first);
                _selectedPreset = null;
              });
            },
          ),

          const SizedBox(height: 8),
          Text(
            _videoSettings.method.description,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
          ),

          const SizedBox(height: 16),

          // Strength slider
          _buildSlider(
            label: 'Strength',
            value: _videoSettings.strength.toDouble(),
            min: 0,
            max: 100,
            onChanged: (v) {
              setState(() {
                _videoSettings = _videoSettings.withStrength(v.round());
                _selectedPreset = null;
              });
            },
          ),

          // Method-specific controls
          if (_videoSettings.method == VideoNoiseMethod.hqdn3d) ...[
            const SizedBox(height: 8),
            _buildSlider(
              label: 'Luma Spatial',
              value: _videoSettings.lumaSpatial,
              min: 0,
              max: 20,
              onChanged: (v) {
                setState(() {
                  _videoSettings = _videoSettings.copyWith(lumaSpatial: v);
                  _selectedPreset = null;
                });
              },
            ),
            const SizedBox(height: 8),
            _buildSlider(
              label: 'Luma Temporal',
              value: _videoSettings.lumaTemporal,
              min: 0,
              max: 20,
              onChanged: (v) {
                setState(() {
                  _videoSettings = _videoSettings.copyWith(lumaTemporal: v);
                  _selectedPreset = null;
                });
              },
            ),
          ] else ...[
            const SizedBox(height: 8),
            _buildSlider(
              label: 'Denoise Strength',
              value: _videoSettings.nlmeansStrength,
              min: 0,
              max: 10,
              onChanged: (v) {
                setState(() {
                  _videoSettings = _videoSettings.copyWith(nlmeansStrength: v);
                  _selectedPreset = null;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCompactSlider(
                    label: 'Patch',
                    value: _videoSettings.nlmeansPatchSize.toDouble(),
                    min: 3,
                    max: 15,
                    onChanged: (v) {
                      setState(() {
                        _videoSettings = _videoSettings.copyWith(nlmeansPatchSize: v.round());
                        _selectedPreset = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactSlider(
                    label: 'Search',
                    value: _videoSettings.nlmeansSearchSize.toDouble(),
                    min: 9,
                    max: 31,
                    onChanged: (v) {
                      setState(() {
                        _videoSettings = _videoSettings.copyWith(nlmeansSearchSize: v.round());
                        _selectedPreset = null;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildAudioSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Switch(
              value: _enableAudioNoise,
              onChanged: (v) => setState(() => _enableAudioNoise = v),
            ),
            const SizedBox(width: 8),
            Text(
              'Audio Noise Reduction',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),

        if (_enableAudioNoise) ...[
          const SizedBox(height: 12),

          // Noise reduction slider
          _buildSlider(
            label: 'Noise Reduction',
            value: _audioSettings.noiseReduction.toDouble(),
            min: 0,
            max: 100,
            suffix: '%',
            onChanged: (v) {
              setState(() {
                _audioSettings = _audioSettings.copyWith(noiseReduction: v.round());
                _selectedPreset = null;
              });
            },
          ),

          const SizedBox(height: 8),

          // Noise floor slider
          _buildSlider(
            label: 'Noise Floor',
            value: _audioSettings.noiseFloor,
            min: -80,
            max: -20,
            suffix: 'dB',
            onChanged: (v) {
              setState(() {
                _audioSettings = _audioSettings.copyWith(noiseFloor: v);
                _selectedPreset = null;
              });
            },
          ),

          const SizedBox(height: 8),

          // Bands selector
          _buildSlider(
            label: 'Analysis Bands',
            value: _audioSettings.bands.toDouble(),
            min: 8,
            max: 64,
            onChanged: (v) {
              setState(() {
                _audioSettings = _audioSettings.copyWith(bands: v.round());
                _selectedPreset = null;
              });
            },
          ),

          const SizedBox(height: 12),

          // Options
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  value: _audioSettings.trackNoise,
                  onChanged: (v) {
                    setState(() {
                      _audioSettings = _audioSettings.copyWith(trackNoise: v ?? true);
                      _selectedPreset = null;
                    });
                  },
                  title: Text(
                    'Adaptive',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurface),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  value: _audioSettings.outputResidue,
                  onChanged: (v) {
                    setState(() {
                      _audioSettings = _audioSettings.copyWith(outputResidue: v ?? false);
                      _selectedPreset = null;
                    });
                  },
                  title: Text(
                    'Preview Noise',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurface),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    String? suffix,
    required ValueChanged<double> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            '${value.round()}${suffix ?? ''}',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
            Text('${value.round()}', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildApplyButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          // Preview button
          OutlinedButton.icon(
            icon: const Icon(Icons.preview, size: 16),
            label: const Text('Preview'),
            onPressed: () {
              // TODO: Apply preview
            },
          ),
          const SizedBox(width: 8),
          // Apply button
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Apply'),
              onPressed: () {
                widget.onApply?.call(
                  _enableVideoNoise ? _videoSettings : null,
                  _enableAudioNoise ? _audioSettings : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact noise reduction widget for integration into other panels
class NoiseReductionQuickSettings extends StatelessWidget {
  final int videoStrength;
  final int audioStrength;
  final ValueChanged<int> onVideoStrengthChanged;
  final ValueChanged<int> onAudioStrengthChanged;

  const NoiseReductionQuickSettings({
    super.key,
    required this.videoStrength,
    required this.audioStrength,
    required this.onVideoStrengthChanged,
    required this.onAudioStrengthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Noise Reduction',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.videocam, size: 16),
            const SizedBox(width: 4),
            const Text('Video', style: TextStyle(fontSize: 11)),
            Expanded(
              child: Slider(
                value: videoStrength.toDouble(),
                min: 0,
                max: 100,
                onChanged: (v) => onVideoStrengthChanged(v.round()),
              ),
            ),
            SizedBox(
              width: 30,
              child: Text('$videoStrength', style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.mic, size: 16),
            const SizedBox(width: 4),
            const Text('Audio', style: TextStyle(fontSize: 11)),
            Expanded(
              child: Slider(
                value: audioStrength.toDouble(),
                min: 0,
                max: 100,
                onChanged: (v) => onAudioStrengthChanged(v.round()),
              ),
            ),
            SizedBox(
              width: 30,
              child: Text('$audioStrength', style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ],
    );
  }
}
