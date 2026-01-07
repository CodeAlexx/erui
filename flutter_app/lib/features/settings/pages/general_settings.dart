import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/settings_section.dart';

/// General settings page
class GeneralSettingsPage extends ConsumerWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'General',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Configure general application settings',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 24),
        // Startup settings
        SettingsSection(
          title: 'Startup',
          children: [
            SwitchListTile(
              title: const Text('Launch on system startup'),
              subtitle: const Text('Automatically start EriUI when your computer boots'),
              value: false,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            SwitchListTile(
              title: const Text('Minimize to tray'),
              subtitle: const Text('Minimize to system tray instead of closing'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            SwitchListTile(
              title: const Text('Check for updates'),
              subtitle: const Text('Automatically check for updates on startup'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Interface settings
        SettingsSection(
          title: 'Interface',
          children: [
            SwitchListTile(
              title: const Text('Show tooltips'),
              subtitle: const Text('Display helpful tooltips on hover'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            SwitchListTile(
              title: const Text('Confirm before delete'),
              subtitle: const Text('Show confirmation dialog before deleting items'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            SwitchListTile(
              title: const Text('Enable animations'),
              subtitle: const Text('Use smooth animations throughout the app'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Language settings
        SettingsSection(
          title: 'Language',
          children: [
            ListTile(
              title: const Text('Application language'),
              subtitle: const Text('English'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Open language picker
              },
            ),
          ],
        ),
      ],
    );
  }
}
