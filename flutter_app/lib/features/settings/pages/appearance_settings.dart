import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

import '../../../providers/providers.dart';
import '../../../theme/app_theme.dart';
import '../widgets/settings_section.dart';

/// Appearance settings page
class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final selectedScheme = ref.watch(colorSchemeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Appearance',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Customize the look and feel of the application',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.outline,
              ),
        ),
        const SizedBox(height: 24),
        // Theme mode
        SettingsSection(
          title: 'Theme Mode',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.auto_mode),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) {
                      ref.read(themeModeProvider.notifier).setTheme(selection.first);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Color scheme picker
        SettingsSection(
          title: 'Color Scheme',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose your accent color',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppTheme.availableSchemes.map((scheme) {
                      final isSelected = scheme == selectedScheme;
                      final schemeColors = FlexSchemeColor.from(
                        primary: FlexColor.schemes[scheme]!.light.primary,
                        secondary: FlexColor.schemes[scheme]!.light.secondary,
                      );

                      return Tooltip(
                        message: AppTheme.getSchemeName(scheme),
                        child: InkWell(
                          onTap: () {
                            ref.read(colorSchemeProvider.notifier).setScheme(scheme);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  FlexColor.schemes[scheme]!.light.primary,
                                  FlexColor.schemes[scheme]!.light.secondary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: FlexColor.schemes[scheme]!.light.primary.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 24)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Selected: ${AppTheme.getSchemeName(selectedScheme)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Theme preview
        SettingsSection(
          title: 'Preview',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _ThemePreview(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // UI density
        SettingsSection(
          title: 'UI Density',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interface Density',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'compact',
                        label: Text('Compact'),
                      ),
                      ButtonSegment(
                        value: 'comfortable',
                        label: Text('Comfortable'),
                      ),
                      ButtonSegment(
                        value: 'spacious',
                        label: Text('Spacious'),
                      ),
                    ],
                    selected: const {'comfortable'},
                    onSelectionChanged: (selection) {
                      // TODO: Implement
                    },
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

class _ThemePreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Color palette
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ColorChip(color: colorScheme.primary, label: 'Primary'),
            _ColorChip(color: colorScheme.secondary, label: 'Secondary'),
            _ColorChip(color: colorScheme.tertiary, label: 'Tertiary'),
            _ColorChip(color: colorScheme.error, label: 'Error'),
            _ColorChip(color: colorScheme.surface, label: 'Surface'),
            _ColorChip(color: colorScheme.surfaceContainerHighest, label: 'Container'),
          ],
        ),
        const SizedBox(height: 16),
        // Sample UI elements
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(onPressed: () {}, child: const Text('Primary')),
            FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
            OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            TextButton(onPressed: () {}, child: const Text('Text')),
          ],
        ),
        const SizedBox(height: 16),
        // Slider preview
        Slider(value: 0.6, onChanged: (_) {}),
        // Switch preview
        Row(
          children: [
            Switch(value: true, onChanged: (_) {}),
            const SizedBox(width: 8),
            Checkbox(value: true, onChanged: (_) {}),
            const SizedBox(width: 8),
            Radio(value: true, groupValue: true, onChanged: (_) {}),
          ],
        ),
      ],
    );
  }
}

class _ColorChip extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
