import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/providers.dart';
import '../widgets/settings_section.dart';

/// User settings page
class UserSettingsPage extends ConsumerWidget {
  const UserSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'User',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your user account and preferences',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
        ),
        const SizedBox(height: 24),
        // User info
        SettingsSection(
          title: 'Account',
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(session.username ?? 'Guest User'),
              subtitle: Text(session.isAuthenticated ? 'Authenticated' : 'Not authenticated'),
              trailing: session.isAuthenticated
                  ? OutlinedButton(
                      onPressed: () {
                        ref.read(sessionProvider.notifier).logout();
                      },
                      child: const Text('Logout'),
                    )
                  : FilledButton(
                      onPressed: () {
                        _showLoginDialog(context, ref);
                      },
                      child: const Text('Login'),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Session info
        if (session.sessionId != null) ...[
          SettingsSection(
            title: 'Session',
            children: [
              ListTile(
                title: const Text('Session ID'),
                subtitle: Text(
                  '${session.sessionId!.substring(0, 8)}...',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    // TODO: Copy to clipboard
                  },
                  tooltip: 'Copy',
                ),
              ),
              ListTile(
                title: const Text('User ID'),
                subtitle: Text(
                  session.userId ?? 'N/A',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        // Permissions
        if (session.permissions.isNotEmpty) ...[
          SettingsSection(
            title: 'Permissions',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: session.permissions.map((perm) {
                    return Chip(
                      label: Text(perm),
                      backgroundColor: colorScheme.secondaryContainer,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        // Preferences
        SettingsSection(
          title: 'Preferences',
          children: [
            SwitchListTile(
              title: const Text('Save generation history'),
              subtitle: const Text('Keep a record of your generations'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            SwitchListTile(
              title: const Text('Save prompts'),
              subtitle: const Text('Remember recently used prompts'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
            SwitchListTile(
              title: const Text('Show NSFW warning'),
              subtitle: const Text('Warn before displaying potentially sensitive content'),
              value: true,
              onChanged: (value) {
                // TODO: Implement
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Data management
        SettingsSection(
          title: 'Data Management',
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Clear generation history'),
              subtitle: const Text('Remove all generation records'),
              trailing: OutlinedButton(
                onPressed: () {
                  _showClearHistoryDialog(context, ref);
                },
                child: const Text('Clear'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cached),
              title: const Text('Clear cache'),
              subtitle: const Text('Remove cached images and data'),
              trailing: OutlinedButton(
                onPressed: () {
                  _showClearCacheDialog(context, ref);
                },
                child: const Text('Clear'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_backup_restore),
              title: const Text('Reset all settings'),
              subtitle: const Text('Restore default settings'),
              trailing: OutlinedButton(
                onPressed: () {
                  _showResetDialog(context, ref);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                ),
                child: const Text('Reset'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showLoginDialog(BuildContext context, WidgetRef ref) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final success = await ref.read(sessionProvider.notifier).login(
                    usernameController.text,
                    passwordController.text,
                  );
              if (context.mounted) {
                Navigator.of(context).pop();
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Login failed')),
                  );
                }
              }
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all generation history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(generationHistoryProvider.notifier).clear();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('History cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear all cached data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // TODO: Clear cache
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to defaults? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // TODO: Reset settings
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
