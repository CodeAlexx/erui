import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/settings_section.dart';

/// About page
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // App info
        Center(
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Text(
                    'F',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'EriUI',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Version 0.1.0',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI Image Generation Interface',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Description
        SettingsSection(
          title: 'About',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'EriUI is a modern, cross-platform interface for AI image generation. '
                'Built with Flutter, it provides a beautiful and responsive experience '
                'for creating images using Stable Diffusion, Flux, and other models.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Features
        SettingsSection(
          title: 'Features',
          children: [
            _FeatureItem(
              icon: Icons.auto_awesome,
              title: 'Multiple Model Support',
              description: 'Support for SD 1.5, SDXL, Flux, and more',
            ),
            _FeatureItem(
              icon: Icons.tune,
              title: 'Advanced Parameters',
              description: 'Full control over generation settings',
            ),
            _FeatureItem(
              icon: Icons.photo_library,
              title: 'Gallery Management',
              description: 'Browse and organize your generations',
            ),
            _FeatureItem(
              icon: Icons.devices,
              title: 'Cross-Platform',
              description: 'Works on Windows, macOS, Linux, and Web',
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Links
        SettingsSection(
          title: 'Links',
          children: [
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('Source Code'),
              subtitle: const Text('View on GitHub'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // TODO: Open GitHub
              },
            ),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Report Issue'),
              subtitle: const Text('Report bugs or request features'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // TODO: Open issue tracker
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Documentation'),
              subtitle: const Text('Read the docs'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // TODO: Open documentation
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // System info
        SettingsSection(
          title: 'System Information',
          children: [
            _InfoTile(label: 'Platform', value: 'Linux'),
            _InfoTile(label: 'Flutter', value: '3.x'),
            _InfoTile(label: 'Dart', value: '3.x'),
            _InfoTile(label: 'Build', value: 'Release'),
          ],
        ),
        const SizedBox(height: 24),
        // License
        SettingsSection(
          title: 'License',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MIT License',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Copyright (c) 2024 EriUI Contributors\n\n'
                    'Permission is hereby granted, free of charge, to any person obtaining a copy '
                    'of this software and associated documentation files...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // TODO: Show full license
                    },
                    child: const Text('View Full License'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(title),
      subtitle: Text(description),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}
