import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import 'pages/general_settings.dart';
import 'pages/appearance_settings.dart';
import 'pages/backend_settings.dart';
import 'pages/paths_settings.dart';
import 'pages/generation_settings.dart';
import 'pages/performance_settings.dart';
import 'pages/user_settings.dart';
import 'pages/about_page.dart';

/// Settings screen with horizontal tabs (ERI style)
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_SettingsTab> _tabs = [
    _SettingsTab('General', Icons.tune),
    _SettingsTab('Appearance', Icons.palette),
    _SettingsTab('Backend', Icons.dns),
    _SettingsTab('Paths', Icons.folder),
    _SettingsTab('Generation', Icons.auto_awesome),
    _SettingsTab('Performance', Icons.memory),
    _SettingsTab('User', Icons.person),
    _SettingsTab('About', Icons.info),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Tab bar (horizontal, like ERI sub-tabs)
        Container(
          color: colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            tabs: _tabs.map((tab) => Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 18),
                  const SizedBox(width: 8),
                  Text(tab.label),
                ],
              ),
            )).toList(),
          ),
        ),
        const Divider(height: 1),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              GeneralSettingsPage(),
              AppearanceSettingsPage(),
              BackendSettingsPage(),
              PathsSettingsPage(),
              GenerationSettingsPage(),
              PerformanceSettingsPage(),
              UserSettingsPage(),
              AboutPage(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTab {
  final String label;
  final IconData icon;
  const _SettingsTab(this.label, this.icon);
}

class _SettingsCategoriesPanel extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const _SettingsCategoriesPanel({
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.settings, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Category list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _SettingsCategoryTile(
                  icon: Icons.tune,
                  label: 'General',
                  selected: selectedCategory == 'general',
                  onTap: () => onCategorySelected('general'),
                ),
                _SettingsCategoryTile(
                  icon: Icons.palette,
                  label: 'Appearance',
                  selected: selectedCategory == 'appearance',
                  onTap: () => onCategorySelected('appearance'),
                ),
                _SettingsCategoryTile(
                  icon: Icons.dns,
                  label: 'Backend',
                  selected: selectedCategory == 'backend',
                  onTap: () => onCategorySelected('backend'),
                ),
                _SettingsCategoryTile(
                  icon: Icons.folder,
                  label: 'Paths',
                  selected: selectedCategory == 'paths',
                  onTap: () => onCategorySelected('paths'),
                ),
                _SettingsCategoryTile(
                  icon: Icons.auto_awesome,
                  label: 'Generation',
                  selected: selectedCategory == 'generation',
                  onTap: () => onCategorySelected('generation'),
                ),
                _SettingsCategoryTile(
                  icon: Icons.memory,
                  label: 'Performance',
                  selected: selectedCategory == 'performance',
                  onTap: () => onCategorySelected('performance'),
                ),
                _SettingsCategoryTile(
                  icon: Icons.person,
                  label: 'User',
                  selected: selectedCategory == 'user',
                  onTap: () => onCategorySelected('user'),
                ),
                const Divider(),
                _SettingsCategoryTile(
                  icon: Icons.info,
                  label: 'About',
                  selected: selectedCategory == 'about',
                  onTap: () => onCategorySelected('about'),
                ),
              ],
            ),
          ),
          // Version info
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'EriUI v0.1.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsCategoryTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(label),
      selected: selected,
      selectedColor: colorScheme.primary,
      selectedTileColor: colorScheme.primaryContainer.withOpacity(0.3),
      onTap: onTap,
    );
  }
}
