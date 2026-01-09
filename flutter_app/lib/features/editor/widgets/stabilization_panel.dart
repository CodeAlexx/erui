import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/stabilization_service.dart';

/// Panel for video stabilization controls
class StabilizationPanel extends ConsumerStatefulWidget {
  final String? videoPath;
  final VoidCallback? onClose;
  final void Function(String outputPath)? onStabilized;

  const StabilizationPanel({
    super.key,
    this.videoPath,
    this.onClose,
    this.onStabilized,
  });

  @override
  ConsumerState<StabilizationPanel> createState() => _StabilizationPanelState();
}

class _StabilizationPanelState extends ConsumerState<StabilizationPanel> {
  StabilizationSettings _settings = const StabilizationSettings();
  StabilizationPreset? _selectedPreset;
  bool _isAnalyzing = false;
  bool _isStabilizing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  StabilizationAnalysis? _analysis;

  final _service = StabilizationService();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(context),

          // Content
          Expanded(
            child: widget.videoPath == null
                ? _buildEmptyState(context)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Presets
                        _buildPresetsSection(context),
                        const SizedBox(height: 16),

                        // Settings
                        _buildSettingsSection(context),
                        const SizedBox(height: 16),

                        // Analysis results
                        if (_analysis != null) ...[
                          _buildAnalysisResults(context),
                          const SizedBox(height: 16),
                        ],

                        // Progress
                        if (_isAnalyzing || _isStabilizing)
                          _buildProgressSection(context),
                      ],
                    ),
                  ),
          ),

          // Actions
          if (widget.videoPath != null) _buildActions(context),
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
          Icon(Icons.video_stable, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Stabilization',
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

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'No video selected',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _Section(
      title: 'Presets',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: StabilizationPreset.presets.map((preset) {
          final isSelected = _selectedPreset?.id == preset.id;
          return ChoiceChip(
            label: Text(preset.name),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _selectedPreset = selected ? preset : null;
                if (selected) {
                  _settings = preset.settings;
                }
              });
            },
            tooltip: preset.description,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return _Section(
      title: 'Settings',
      child: Column(
        children: [
          // Shakiness
          _SliderRow(
            label: 'Shakiness',
            value: _settings.shakiness.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (v) {
              setState(() {
                _settings = _settings.copyWith(shakiness: v.round());
                _selectedPreset = null;
              });
            },
          ),

          // Smoothing
          _SliderRow(
            label: 'Smoothing',
            value: _settings.smoothing.toDouble(),
            min: 0,
            max: 50,
            divisions: 50,
            onChanged: (v) {
              setState(() {
                _settings = _settings.copyWith(smoothing: v.round());
                _selectedPreset = null;
              });
            },
          ),

          // Zoom
          _SliderRow(
            label: 'Zoom',
            value: _settings.zoom.toDouble(),
            min: 0,
            max: 20,
            divisions: 20,
            suffix: '%',
            onChanged: (v) {
              setState(() {
                _settings = _settings.copyWith(zoom: v.round());
                _selectedPreset = null;
              });
            },
          ),

          const SizedBox(height: 8),

          // Optimal zoom
          Row(
            children: [
              const Expanded(child: Text('Optimal Zoom')),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Off')),
                  ButtonSegment(value: 1, label: Text('Static')),
                  ButtonSegment(value: 2, label: Text('Adaptive')),
                ],
                selected: {_settings.optZoom},
                onSelectionChanged: (selected) {
                  setState(() {
                    _settings = _settings.copyWith(optZoom: selected.first);
                    _selectedPreset = null;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Interpolation
          Row(
            children: [
              const Expanded(child: Text('Quality')),
              DropdownButton<StabilizationInterpolation>(
                value: _settings.interpolation,
                underline: const SizedBox(),
                items: StabilizationInterpolation.values
                    .map((i) => DropdownMenuItem(
                          value: i,
                          child: Text(i.displayName),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _settings = _settings.copyWith(interpolation: value);
                      _selectedPreset = null;
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResults(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _Section(
      title: 'Analysis Results',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Motion analyzed',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Average motion: ${_analysis!.averageMotion.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'Max motion: ${_analysis!.maxMotion.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'Analysis time: ${_analysis!.analyzeDuration.inSeconds}s',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _Section(
      title: 'Progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusMessage,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 4),
          Text(
            '${(_progress * 100).round()}%',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
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
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.analytics, size: 16),
              label: const Text('Analyze'),
              onPressed: _isAnalyzing || _isStabilizing ? null : _analyze,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.video_stable, size: 16),
              label: const Text('Stabilize'),
              onPressed: _isAnalyzing || _isStabilizing ? null : _stabilize,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _analyze() async {
    if (widget.videoPath == null) return;

    setState(() {
      _isAnalyzing = true;
      _progress = 0.0;
      _statusMessage = 'Analyzing motion...';
      _analysis = null;
    });

    try {
      final analysis = await _service.analyzeMotion(
        widget.videoPath!,
        _settings,
        onProgress: (p) {
          setState(() {
            _progress = p;
          });
        },
      );

      setState(() {
        _analysis = analysis;
        _statusMessage = 'Analysis complete';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _stabilize() async {
    if (widget.videoPath == null) return;

    setState(() {
      _isStabilizing = true;
      _progress = 0.0;
    });

    try {
      final outputPath = widget.videoPath!.replaceAll(
        RegExp(r'(\.[^.]+)$'),
        '_stabilized\$1',
      );

      final result = await _service.stabilize(
        widget.videoPath!,
        outputPath,
        _settings,
        onProgress: (stage, p) {
          setState(() {
            _statusMessage = stage;
            _progress = p;
          });
        },
      );

      setState(() {
        _statusMessage = 'Stabilization complete';
      });

      widget.onStabilized?.call(result);
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isStabilizing = false;
      });
    }
  }
}

/// Section wrapper widget
class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Slider row widget
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? suffix;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${value.round()}${suffix ?? ''}',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
