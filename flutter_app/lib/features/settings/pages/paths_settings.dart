import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/settings_section.dart';

/// Paths settings page
class PathsSettingsPage extends ConsumerWidget {
  const PathsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Paths',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Configure file and folder locations',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
        ),
        const SizedBox(height: 24),
        // Output paths
        SettingsSection(
          title: 'Output',
          children: [
            _PathSetting(
              title: 'Output Directory',
              subtitle: 'Where generated images are saved',
              path: '~/eriui/output',
              onBrowse: () {
                // TODO: Open directory picker
              },
            ),
            _PathSetting(
              title: 'Temporary Directory',
              subtitle: 'For temporary files and cache',
              path: '~/eriui/temp',
              onBrowse: () {
                // TODO: Open directory picker
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Model paths
        SettingsSection(
          title: 'Models',
          children: [
            _PathSetting(
              title: 'Checkpoints',
              subtitle: 'Stable Diffusion models',
              path: '~/eriui/models/checkpoints',
              onBrowse: () {
                // TODO: Open directory picker
              },
            ),
            _PathSetting(
              title: 'LoRA',
              subtitle: 'LoRA model files',
              path: '~/eriui/models/loras',
              onBrowse: () {
                // TODO: Open directory picker
              },
            ),
            _PathSetting(
              title: 'VAE',
              subtitle: 'VAE model files',
              path: '~/eriui/models/vae',
              onBrowse: () {
                // TODO: Open directory picker
              },
            ),
            _PathSetting(
              title: 'ControlNet',
              subtitle: 'ControlNet model files',
              path: '~/eriui/models/controlnet',
              onBrowse: () {
                // TODO: Open directory picker
              },
            ),
            _PathSetting(
              title: 'Embeddings',
              subtitle: 'Textual inversion embeddings',
              path: '~/eriui/models/embeddings',
              onBrowse: () {
                // TODO: Open directory picker
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Input paths
        SettingsSection(
          title: 'Input',
          children: [
            _PathSetting(
              title: 'Input Images',
              subtitle: 'Default location for input images',
              path: '~/eriui/input',
              onBrowse: () {
                // TODO: Open directory picker
              },
            ),
            _PathSetting(
              title: 'Wildcards',
              subtitle: 'Wildcard text files',
              path: '~/eriui/wildcards',
              onBrowse: () {
                // TODO: Open directory picker
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Output organization
        SettingsSection(
          title: 'Output Organization',
          children: [
            SwitchListTile(
              title: const Text('Organize by date'),
              subtitle: const Text('Create subfolders for each day'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            ListTile(
              title: const Text('Filename Pattern'),
              subtitle: const Text('{date}_{time}_{seed}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Open pattern editor
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _PathSetting extends StatelessWidget {
  final String title;
  final String subtitle;
  final String path;
  final VoidCallback onBrowse;

  const _PathSetting({
    required this.title,
    required this.subtitle,
    required this.path,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              path,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.folder_open),
        onPressed: onBrowse,
        tooltip: 'Browse',
      ),
      isThreeLine: true,
    );
  }
}
