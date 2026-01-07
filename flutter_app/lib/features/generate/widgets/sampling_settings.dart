import 'package:flutter/material.dart';

import '../../../widgets/widgets.dart';

/// Sampling settings widget
class SamplingSettings extends StatelessWidget {
  final int steps;
  final double cfgScale;
  final String sampler;
  final String scheduler;
  final ValueChanged<int> onStepsChanged;
  final ValueChanged<double> onCfgScaleChanged;
  final ValueChanged<String> onSamplerChanged;
  final ValueChanged<String> onSchedulerChanged;
  final bool enabled;

  const SamplingSettings({
    super.key,
    required this.steps,
    required this.cfgScale,
    required this.sampler,
    required this.scheduler,
    required this.onStepsChanged,
    required this.onCfgScaleChanged,
    required this.onSamplerChanged,
    required this.onSchedulerChanged,
    this.enabled = true,
  });

  static const List<String> samplers = [
    'euler',
    'euler_ancestral',
    'heun',
    'heunpp2',
    'dpm_2',
    'dpm_2_ancestral',
    'lms',
    'dpm_fast',
    'dpm_adaptive',
    'dpmpp_2s_ancestral',
    'dpmpp_sde',
    'dpmpp_sde_gpu',
    'dpmpp_2m',
    'dpmpp_2m_sde',
    'dpmpp_2m_sde_gpu',
    'dpmpp_3m_sde',
    'dpmpp_3m_sde_gpu',
    'ddpm',
    'lcm',
    'uni_pc',
    'uni_pc_bh2',
  ];

  static const List<String> schedulers = [
    'normal',
    'karras',
    'exponential',
    'sgm_uniform',
    'simple',
    'ddim_uniform',
    'beta',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sampling',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
              ),
        ),
        const SizedBox(height: 16),
        // Sampler dropdown
        DropdownButtonFormField<String>(
          value: sampler,
          decoration: const InputDecoration(
            labelText: 'Sampler',
          ),
          items: samplers.map((s) {
            return DropdownMenuItem(
              value: s,
              child: Text(_formatSamplerName(s)),
            );
          }).toList(),
          onChanged: enabled ? (v) => onSamplerChanged(v!) : null,
        ),
        const SizedBox(height: 16),
        // Scheduler dropdown
        DropdownButtonFormField<String>(
          value: scheduler,
          decoration: const InputDecoration(
            labelText: 'Scheduler',
          ),
          items: schedulers.map((s) {
            return DropdownMenuItem(
              value: s,
              child: Text(_formatSchedulerName(s)),
            );
          }).toList(),
          onChanged: enabled ? (v) => onSchedulerChanged(v!) : null,
        ),
        const SizedBox(height: 16),
        // Steps slider
        IntSliderParameter(
          label: 'Steps',
          value: steps,
          min: 1,
          max: 150,
          onChanged: onStepsChanged,
          enabled: enabled,
        ),
        const SizedBox(height: 8),
        // CFG Scale slider
        SliderParameter(
          label: 'CFG Scale',
          value: cfgScale,
          min: 1,
          max: 30,
          divisions: 58,
          valueLabel: (v) => v.toStringAsFixed(1),
          onChanged: onCfgScaleChanged,
          enabled: enabled,
        ),
        // Quick presets
        const SizedBox(height: 8),
        Text(
          'Quick Presets',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.outline,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PresetChip(
              label: 'Fast',
              onTap: enabled
                  ? () {
                      onStepsChanged(10);
                      onSamplerChanged('euler');
                      onSchedulerChanged('normal');
                    }
                  : null,
            ),
            _PresetChip(
              label: 'Balanced',
              onTap: enabled
                  ? () {
                      onStepsChanged(20);
                      onSamplerChanged('dpmpp_2m');
                      onSchedulerChanged('karras');
                    }
                  : null,
            ),
            _PresetChip(
              label: 'Quality',
              onTap: enabled
                  ? () {
                      onStepsChanged(35);
                      onSamplerChanged('dpmpp_2m_sde');
                      onSchedulerChanged('karras');
                    }
                  : null,
            ),
            _PresetChip(
              label: 'LCM',
              onTap: enabled
                  ? () {
                      onStepsChanged(6);
                      onSamplerChanged('lcm');
                      onSchedulerChanged('sgm_uniform');
                      onCfgScaleChanged(1.5);
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  String _formatSamplerName(String name) {
    return name
        .replaceAll('_', ' ')
        .replaceAll('dpmpp', 'DPM++')
        .replaceAll('dpm', 'DPM')
        .replaceAll('sde', 'SDE')
        .replaceAll('gpu', 'GPU')
        .replaceAll('lcm', 'LCM')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _formatSchedulerName(String name) {
    return name
        .replaceAll('_', ' ')
        .replaceAll('sgm', 'SGM')
        .replaceAll('ddim', 'DDIM')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _PresetChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}
