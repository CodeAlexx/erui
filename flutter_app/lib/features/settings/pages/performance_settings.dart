import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/settings_section.dart';

/// Performance settings page
class PerformanceSettingsPage extends ConsumerWidget {
  const PerformanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Performance',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Configure performance and resource usage',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
        ),
        const SizedBox(height: 24),
        // Memory settings
        SettingsSection(
          title: 'Memory Management',
          children: [
            SwitchListTile(
              title: const Text('Low VRAM mode'),
              subtitle: const Text('Reduce VRAM usage at the cost of speed'),
              value: false,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            SwitchListTile(
              title: const Text('Enable model caching'),
              subtitle: const Text('Keep models in memory for faster switching'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            ListTile(
              title: const Text('Cache size limit'),
              subtitle: const Text('Maximum memory for cached models'),
              trailing: DropdownButton<String>(
                value: '8GB',
                underline: const SizedBox(),
                items: ['2GB', '4GB', '8GB', '16GB', 'Unlimited']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) {
                  // TODO: Implement
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Generation settings
        SettingsSection(
          title: 'Generation',
          children: [
            ListTile(
              title: const Text('Maximum concurrent generations'),
              subtitle: const Text('Number of parallel generation jobs'),
              trailing: DropdownButton<int>(
                value: 1,
                underline: const SizedBox(),
                items: [1, 2, 3, 4]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (value) {
                  // TODO: Implement
                },
              ),
            ),
            SwitchListTile(
              title: const Text('Queue overflow generations'),
              subtitle: const Text('Queue additional requests instead of rejecting'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            ListTile(
              title: const Text('Queue timeout'),
              subtitle: const Text('Maximum wait time in queue'),
              trailing: DropdownButton<String>(
                value: '5 minutes',
                underline: const SizedBox(),
                items: ['1 minute', '5 minutes', '15 minutes', '30 minutes', 'No limit']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) {
                  // TODO: Implement
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Preview settings
        SettingsSection(
          title: 'Preview',
          children: [
            ListTile(
              title: const Text('Preview quality'),
              subtitle: const Text('Resolution of live previews'),
              trailing: DropdownButton<String>(
                value: 'Medium',
                underline: const SizedBox(),
                items: ['Low', 'Medium', 'High', 'Full']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (value) {
                  // TODO: Implement
                },
              ),
            ),
            ListTile(
              title: const Text('Preview interval'),
              subtitle: const Text('Steps between preview updates'),
              trailing: DropdownButton<int>(
                value: 5,
                underline: const SizedBox(),
                items: [1, 2, 5, 10]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n steps')))
                    .toList(),
                onChanged: (value) {
                  // TODO: Implement
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Optimizations
        SettingsSection(
          title: 'Optimizations',
          children: [
            SwitchListTile(
              title: const Text('Enable half precision (FP16)'),
              subtitle: const Text('Use 16-bit precision for faster inference'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            SwitchListTile(
              title: const Text('Enable xformers'),
              subtitle: const Text('Use memory-efficient attention'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            SwitchListTile(
              title: const Text('Enable VAE tiling'),
              subtitle: const Text('Tile VAE decode for large images'),
              value: false,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
          ],
        ),
      ],
    );
  }
}
