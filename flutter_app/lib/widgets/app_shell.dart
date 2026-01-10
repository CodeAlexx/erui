import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Main application shell with ERI-style top tabs
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      body: Column(
        children: [
          // Top navigation bar like ERI
          Container(
            color: colorScheme.surface,
            child: Row(
              children: [
                // Logo
                _buildLogo(colorScheme),
                // Main tabs
                _TopTab(
                  label: 'Trainer',
                  isSelected: location.startsWith('/trainer'),
                  onTap: () => context.go('/trainer'),
                ),
                _TopTab(
                  label: 'Generate',
                  isSelected: location.startsWith('/generate'),
                  onTap: () => context.go('/generate'),
                ),
                _TopTab(
                  label: 'Editor',
                  isSelected: location.startsWith('/editor'),
                  onTap: () => context.go('/editor'),
                ),
                _TopTab(
                  label: 'ComfyUI',
                  isSelected: location.startsWith('/comfyui'),
                  onTap: () => context.go('/comfyui'),
                ),
                // Utilities dropdown
                _UtilitiesDropdown(
                  isSelected: location.startsWith('/tools') ||
                      location.startsWith('/wildcards') ||
                      location.startsWith('/regional'),
                ),
                _TopTab(
                  label: 'User',
                  isSelected: location.startsWith('/settings'),
                  onTap: () => context.go('/settings'),
                ),
                // Workflow dropdown with browser and editor options
                _WorkflowDropdown(
                  isSelected: location.startsWith('/workflow'),
                ),
                const Spacer(),
                // Quick Tools button like ERI
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Text('Quick Tools'),
                    label: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
          // Main content
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildLogo(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'E',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Utilities dropdown menu
class _UtilitiesDropdown extends StatelessWidget {
  final bool isSelected;

  const _UtilitiesDropdown({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      onSelected: (route) => context.go(route),
      tooltip: 'Utilities',
      offset: const Offset(0, 40),
      itemBuilder: (context) => [
        _buildMenuItem(context, 'Analytics', Icons.analytics, '/tools/analytics'),
        _buildMenuItem(context, 'Batch Processing', Icons.batch_prediction, '/tools/batch'),
        _buildMenuItem(context, 'Grid Generator', Icons.grid_on, '/tools/grid'),
        _buildMenuItem(context, 'Image Interrogator', Icons.psychology, '/tools/interrogator'),
        _buildMenuItem(context, 'Model Comparison', Icons.compare, '/tools/compare'),
        _buildMenuItem(context, 'Model Merger', Icons.merge, '/tools/merger'),
        const PopupMenuDivider(),
        _buildMenuItem(context, 'Wildcards', Icons.shuffle, '/wildcards'),
        _buildMenuItem(context, 'Regional Prompts', Icons.crop_free, '/regional'),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.15) : null,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Utilities',
              style: TextStyle(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    BuildContext context,
    String label,
    IconData icon,
    String route,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final location = GoRouterState.of(context).uri.path;
    final isActive = location == route;

    return PopupMenuItem<String>(
      value: route,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isActive ? colorScheme.primary : colorScheme.onSurface,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isActive ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Workflow dropdown menu for workflow management
class _WorkflowDropdown extends StatelessWidget {
  final bool isSelected;

  const _WorkflowDropdown({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      onSelected: (route) => context.go(route),
      tooltip: 'Workflow',
      offset: const Offset(0, 40),
      itemBuilder: (context) => [
        _buildMenuItem(context, 'Workflow Browser', Icons.folder_open, '/workflow-browser'),
        _buildMenuItem(context, 'New Workflow', Icons.add_circle_outline, '/workflow/new'),
        const PopupMenuDivider(),
        _buildMenuItem(context, 'Visual Builder', Icons.account_tree, '/workflow-builder'),
        _buildMenuItem(context, 'ComfyUI', Icons.code, '/comfyui'),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.15) : null,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Workflow',
              style: TextStyle(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    BuildContext context,
    String label,
    IconData icon,
    String route,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final location = GoRouterState.of(context).uri.path;
    final isActive = location == route || location.startsWith(route);

    return PopupMenuItem<String>(
      value: route,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isActive ? colorScheme.primary : colorScheme.onSurface,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isActive ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Top tab button like ERI
class _TopTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TopTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.15) : null,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
