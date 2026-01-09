import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/keyboard_shortcuts_service.dart';

/// Keyboard shortcuts settings panel
class KeyboardShortcutsPanel extends ConsumerWidget {
  const KeyboardShortcutsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final shortcutsState = ref.watch(keyboardShortcutsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.keyboard, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Keyboard Shortcuts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
              ),
              const Spacer(),
              // Enable/Disable toggle
              Row(
                children: [
                  Text(
                    'Enabled',
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: shortcutsState.isEnabled,
                    onChanged: (value) {
                      ref.read(keyboardShortcutsProvider.notifier).setEnabled(value);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Customize keyboard shortcuts for common actions. Click on a shortcut to change it.',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Reset all button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  _showResetAllDialog(context, ref);
                },
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Reset All to Defaults'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Shortcuts list grouped by category
          _ShortcutsCategory(
            title: 'Generation',
            icon: Icons.auto_awesome,
            shortcuts: [
              ShortcutAction.generate,
              ShortcutAction.generateLockedSeed,
              ShortcutAction.cancelGeneration,
            ],
          ),
          const SizedBox(height: 16),

          _ShortcutsCategory(
            title: 'Editing',
            icon: Icons.edit,
            shortcuts: [
              ShortcutAction.focusPrompt,
              ShortcutAction.focusNegativePrompt,
              ShortcutAction.undoPrompt,
            ],
          ),
          const SizedBox(height: 16),

          _ShortcutsCategory(
            title: 'Parameters',
            icon: Icons.tune,
            shortcuts: [
              ShortcutAction.toggleVideoMode,
              ShortcutAction.randomizeSeed,
              ShortcutAction.copySeed,
              ShortcutAction.savePreset,
            ],
          ),
          const SizedBox(height: 16),

          _ShortcutsCategory(
            title: 'Navigation',
            icon: Icons.navigation,
            shortcuts: [
              ShortcutAction.openSettings,
              ShortcutAction.openModels,
              ShortcutAction.openGallery,
            ],
          ),
        ],
      ),
    );
  }

  void _showResetAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Shortcuts?'),
        content: const Text(
          'This will reset all keyboard shortcuts to their default values. '
          'Any custom shortcuts you have set will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(keyboardShortcutsProvider.notifier).resetAllShortcuts();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All shortcuts reset to defaults')),
              );
            },
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }
}

/// Category of shortcuts
class _ShortcutsCategory extends ConsumerWidget {
  final String title;
  final IconData icon;
  final List<ShortcutAction> shortcuts;

  const _ShortcutsCategory({
    required this.title,
    required this.icon,
    required this.shortcuts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final shortcutsState = ref.watch(keyboardShortcutsProvider);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          // Shortcuts list
          ...shortcuts.map((action) {
            final binding = shortcutsState.shortcuts[action];
            return _ShortcutListItem(
              action: action,
              binding: binding,
              isLast: action == shortcuts.last,
            );
          }),
        ],
      ),
    );
  }
}

/// Individual shortcut list item
class _ShortcutListItem extends ConsumerWidget {
  final ShortcutAction action;
  final ShortcutBinding? binding;
  final bool isLast;

  const _ShortcutListItem({
    required this.action,
    required this.binding,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDefault = binding?.isDefault ?? true;

    return InkWell(
      onTap: () => _showEditDialog(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
        ),
        child: Row(
          children: [
            // Action icon
            Icon(action.icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            // Action name and description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Shortcut badge
            if (binding != null) ...[
              _ShortcutBadge(
                shortcut: binding!.displayString,
                isDefault: isDefault,
              ),
              if (!isDefault) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.restore, size: 18),
                  onPressed: () {
                    ref.read(keyboardShortcutsProvider.notifier).resetShortcut(action);
                  },
                  tooltip: 'Reset to default',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ] else
              Text(
                'Not set',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _EditShortcutDialog(
        action: action,
        currentBinding: binding,
      ),
    );
  }
}

/// Badge showing the keyboard shortcut
class _ShortcutBadge extends StatelessWidget {
  final String shortcut;
  final bool isDefault;

  const _ShortcutBadge({
    required this.shortcut,
    required this.isDefault,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDefault
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDefault
              ? colorScheme.outlineVariant
              : colorScheme.primary.withOpacity(0.5),
        ),
      ),
      child: Text(
        shortcut,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'monospace',
          color: isDefault ? colorScheme.onSurfaceVariant : colorScheme.primary,
        ),
      ),
    );
  }
}

/// Dialog for editing a shortcut
class _EditShortcutDialog extends ConsumerStatefulWidget {
  final ShortcutAction action;
  final ShortcutBinding? currentBinding;

  const _EditShortcutDialog({
    required this.action,
    required this.currentBinding,
  });

  @override
  ConsumerState<_EditShortcutDialog> createState() => _EditShortcutDialogState();
}

class _EditShortcutDialogState extends ConsumerState<_EditShortcutDialog> {
  final _focusNode = FocusNode();
  SingleActivator? _recordedActivator;
  bool _isRecording = false;
  ShortcutAction? _conflictingAction;

  @override
  void initState() {
    super.initState();
    _recordedActivator = widget.currentBinding?.activator;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordedActivator = null;
      _conflictingAction = null;
    });
    _focusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isRecording) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Ignore modifier-only presses
    if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight ||
        event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight ||
        event.logicalKey == LogicalKeyboardKey.altLeft ||
        event.logicalKey == LogicalKeyboardKey.altRight ||
        event.logicalKey == LogicalKeyboardKey.metaLeft ||
        event.logicalKey == LogicalKeyboardKey.metaRight) {
      return KeyEventResult.handled;
    }

    final activator = SingleActivator(
      event.logicalKey,
      control: HardwareKeyboard.instance.isControlPressed,
      shift: HardwareKeyboard.instance.isShiftPressed,
      alt: HardwareKeyboard.instance.isAltPressed,
      meta: HardwareKeyboard.instance.isMetaPressed,
    );

    // Check for conflicts
    final conflict = ref.read(keyboardShortcutsProvider.notifier).findConflict(
          widget.action,
          activator,
        );

    setState(() {
      _isRecording = false;
      _recordedActivator = activator;
      _conflictingAction = conflict;
    });

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('Edit Shortcut: ${widget.action.displayName}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.action.description,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Recording area
            Focus(
              focusNode: _focusNode,
              onKeyEvent: _handleKeyEvent,
              child: GestureDetector(
                onTap: _startRecording,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? colorScheme.primaryContainer.withOpacity(0.3)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isRecording
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: _isRecording ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_isRecording)
                        Text(
                          'Press a key combination...',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else if (_recordedActivator != null)
                        Text(
                          ShortcutBinding(
                            action: widget.action,
                            activator: _recordedActivator!,
                          ).displayString,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: colorScheme.onSurface,
                          ),
                        )
                      else
                        Text(
                          'Click to record shortcut',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        _isRecording
                            ? 'Listening for keys...'
                            : 'Click here and press your desired key combination',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Conflict warning
            if (_conflictingAction != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.error.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This shortcut conflicts with "${_conflictingAction!.displayName}"',
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Default shortcut info
            if (widget.currentBinding != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Default: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    defaultShortcuts[widget.action]?.displayString ?? 'None',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_recordedActivator != null && _conflictingAction == null)
          FilledButton(
            onPressed: () {
              ref.read(keyboardShortcutsProvider.notifier).updateShortcut(
                    widget.action,
                    _recordedActivator!,
                  );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Shortcut updated: ${ShortcutBinding(action: widget.action, activator: _recordedActivator!).displayString}',
                  ),
                ),
              );
            },
            child: const Text('Save'),
          ),
      ],
    );
  }
}
