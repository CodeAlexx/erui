import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/widgets.dart';
import '../widgets/settings_section.dart';

/// Generation settings page
class GenerationSettingsPage extends ConsumerStatefulWidget {
  const GenerationSettingsPage({super.key});

  @override
  ConsumerState<GenerationSettingsPage> createState() => _GenerationSettingsPageState();
}

class _GenerationSettingsPageState extends ConsumerState<GenerationSettingsPage> {
  int _defaultSteps = 20;
  double _defaultCfgScale = 7.0;
  int _defaultWidth = 1024;
  int _defaultHeight = 1024;
  String _defaultSampler = 'euler';
  String _defaultScheduler = 'normal';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Generation',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Configure default generation parameters',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
        ),
        const SizedBox(height: 24),
        // Default resolution
        SettingsSection(
          title: 'Default Resolution',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ResolutionParameter(
                width: _defaultWidth,
                height: _defaultHeight,
                onWidthChanged: (value) => setState(() => _defaultWidth = value),
                onHeightChanged: (value) => setState(() => _defaultHeight = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Default sampling
        SettingsSection(
          title: 'Default Sampling',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sampler dropdown
                  DropdownButtonFormField<String>(
                    value: _defaultSampler,
                    decoration: const InputDecoration(
                      labelText: 'Default Sampler',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'euler', child: Text('Euler')),
                      DropdownMenuItem(value: 'euler_ancestral', child: Text('Euler Ancestral')),
                      DropdownMenuItem(value: 'dpmpp_2m', child: Text('DPM++ 2M')),
                      DropdownMenuItem(value: 'dpmpp_sde', child: Text('DPM++ SDE')),
                      DropdownMenuItem(value: 'lcm', child: Text('LCM')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _defaultSampler = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Scheduler dropdown
                  DropdownButtonFormField<String>(
                    value: _defaultScheduler,
                    decoration: const InputDecoration(
                      labelText: 'Default Scheduler',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'karras', child: Text('Karras')),
                      DropdownMenuItem(value: 'exponential', child: Text('Exponential')),
                      DropdownMenuItem(value: 'sgm_uniform', child: Text('SGM Uniform')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _defaultScheduler = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Steps slider
                  IntSliderParameter(
                    label: 'Default Steps',
                    value: _defaultSteps,
                    min: 1,
                    max: 150,
                    onChanged: (value) => setState(() => _defaultSteps = value),
                  ),
                  const SizedBox(height: 8),
                  // CFG Scale slider
                  SliderParameter(
                    label: 'Default CFG Scale',
                    value: _defaultCfgScale,
                    min: 1,
                    max: 30,
                    divisions: 58,
                    valueLabel: (v) => v.toStringAsFixed(1),
                    onChanged: (value) => setState(() => _defaultCfgScale = value),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Batch settings
        SettingsSection(
          title: 'Batch Generation',
          children: [
            ListTile(
              title: const Text('Default Batch Size'),
              subtitle: const Text('Number of images to generate at once'),
              trailing: DropdownButton<int>(
                value: 1,
                underline: const SizedBox(),
                items: List.generate(9, (i) => i + 1)
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (value) {
                  // TODO: Implement
                },
              ),
            ),
            SwitchListTile(
              title: const Text('Show live preview'),
              subtitle: const Text('Display progress while generating'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Seed settings
        SettingsSection(
          title: 'Seed',
          children: [
            SwitchListTile(
              title: const Text('Random seed by default'),
              subtitle: const Text('Use a random seed for each generation'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            SwitchListTile(
              title: const Text('Increment seed for batch'),
              subtitle: const Text('Use sequential seeds for batch generations'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Save button
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved')),
              );
            },
            icon: const Icon(Icons.save),
            label: const Text('Save Defaults'),
          ),
        ),
      ],
    );
  }
}
