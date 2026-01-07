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
                  label: 'Comfy Workflow',
                  isSelected: location.startsWith('/workflow'),
                  onTap: () => context.go('/workflow'),
                ),
                _TopTab(
                  label: 'ComfyUI',
                  isSelected: location.startsWith('/comfyui'),
                  onTap: () => context.go('/comfyui'),
                ),
                _TopTab(
                  label: 'Utilities',
                  isSelected: false,
                  onTap: () {}, // TODO
                ),
                _TopTab(
                  label: 'User',
                  isSelected: location.startsWith('/settings'),
                  onTap: () => context.go('/settings'),
                ),
                _TopTab(
                  label: 'Server',
                  isSelected: false,
                  onTap: () {}, // TODO
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
