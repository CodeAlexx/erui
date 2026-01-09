import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_service.dart';

/// Storage key for custom shortcuts
const String _shortcutsKey = 'eriui_keyboard_shortcuts';

/// Keyboard shortcuts service provider
final keyboardShortcutsServiceProvider = Provider<KeyboardShortcutsService>((ref) {
  return KeyboardShortcutsService();
});

/// Keyboard shortcuts state provider
final keyboardShortcutsProvider =
    StateNotifierProvider<KeyboardShortcutsNotifier, KeyboardShortcutsState>((ref) {
  final service = ref.watch(keyboardShortcutsServiceProvider);
  return KeyboardShortcutsNotifier(service);
});

/// Shortcut action identifiers
enum ShortcutAction {
  generate,
  generateLockedSeed,
  cancelGeneration,
  savePreset,
  undoPrompt,
  copySeed,
  toggleVideoMode,
  randomizeSeed,
  focusPrompt,
  focusNegativePrompt,
  openSettings,
  openModels,
  openGallery,
}

/// Extension to get display names for shortcut actions
extension ShortcutActionExtension on ShortcutAction {
  String get displayName {
    switch (this) {
      case ShortcutAction.generate:
        return 'Generate';
      case ShortcutAction.generateLockedSeed:
        return 'Generate (Locked Seed)';
      case ShortcutAction.cancelGeneration:
        return 'Cancel Generation';
      case ShortcutAction.savePreset:
        return 'Save Current as Preset';
      case ShortcutAction.undoPrompt:
        return 'Undo Prompt Change';
      case ShortcutAction.copySeed:
        return 'Copy Seed';
      case ShortcutAction.toggleVideoMode:
        return 'Toggle Video Mode';
      case ShortcutAction.randomizeSeed:
        return 'Randomize Seed';
      case ShortcutAction.focusPrompt:
        return 'Focus Prompt Field';
      case ShortcutAction.focusNegativePrompt:
        return 'Focus Negative Prompt';
      case ShortcutAction.openSettings:
        return 'Open Settings';
      case ShortcutAction.openModels:
        return 'Open Models';
      case ShortcutAction.openGallery:
        return 'Open Gallery';
    }
  }

  String get description {
    switch (this) {
      case ShortcutAction.generate:
        return 'Start image/video generation with current parameters';
      case ShortcutAction.generateLockedSeed:
        return 'Generate using the current seed without randomizing';
      case ShortcutAction.cancelGeneration:
        return 'Stop the current generation in progress';
      case ShortcutAction.savePreset:
        return 'Save current generation parameters as a preset';
      case ShortcutAction.undoPrompt:
        return 'Restore previous prompt text';
      case ShortcutAction.copySeed:
        return 'Copy the current seed value to clipboard';
      case ShortcutAction.toggleVideoMode:
        return 'Switch between image and video generation modes';
      case ShortcutAction.randomizeSeed:
        return 'Set seed to -1 for random generation';
      case ShortcutAction.focusPrompt:
        return 'Move keyboard focus to the prompt input field';
      case ShortcutAction.focusNegativePrompt:
        return 'Move keyboard focus to the negative prompt field';
      case ShortcutAction.openSettings:
        return 'Navigate to the settings page';
      case ShortcutAction.openModels:
        return 'Navigate to the models page';
      case ShortcutAction.openGallery:
        return 'Navigate to the gallery page';
    }
  }

  IconData get icon {
    switch (this) {
      case ShortcutAction.generate:
        return Icons.auto_awesome;
      case ShortcutAction.generateLockedSeed:
        return Icons.lock;
      case ShortcutAction.cancelGeneration:
        return Icons.stop;
      case ShortcutAction.savePreset:
        return Icons.save;
      case ShortcutAction.undoPrompt:
        return Icons.undo;
      case ShortcutAction.copySeed:
        return Icons.copy;
      case ShortcutAction.toggleVideoMode:
        return Icons.videocam;
      case ShortcutAction.randomizeSeed:
        return Icons.casino;
      case ShortcutAction.focusPrompt:
        return Icons.edit;
      case ShortcutAction.focusNegativePrompt:
        return Icons.edit_off;
      case ShortcutAction.openSettings:
        return Icons.settings;
      case ShortcutAction.openModels:
        return Icons.view_in_ar;
      case ShortcutAction.openGallery:
        return Icons.photo_library;
    }
  }
}

/// Represents a keyboard shortcut binding
class ShortcutBinding {
  final ShortcutAction action;
  final SingleActivator activator;
  final bool isDefault;

  const ShortcutBinding({
    required this.action,
    required this.activator,
    this.isDefault = false,
  });

  /// Create from JSON map
  factory ShortcutBinding.fromJson(Map<String, dynamic> json) {
    final actionName = json['action'] as String;
    final action = ShortcutAction.values.firstWhere(
      (a) => a.name == actionName,
      orElse: () => ShortcutAction.generate,
    );

    return ShortcutBinding(
      action: action,
      activator: SingleActivator(
        LogicalKeyboardKey.findKeyByKeyId(json['keyId'] as int) ?? LogicalKeyboardKey.enter,
        control: json['control'] as bool? ?? false,
        shift: json['shift'] as bool? ?? false,
        alt: json['alt'] as bool? ?? false,
        meta: json['meta'] as bool? ?? false,
      ),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'action': action.name,
      'keyId': activator.trigger.keyId,
      'control': activator.control,
      'shift': activator.shift,
      'alt': activator.alt,
      'meta': activator.meta,
      'isDefault': isDefault,
    };
  }

  /// Get human-readable string for the shortcut
  String get displayString {
    final parts = <String>[];
    if (activator.control) parts.add('Ctrl');
    if (activator.alt) parts.add('Alt');
    if (activator.shift) parts.add('Shift');
    if (activator.meta) parts.add('Meta');
    parts.add(_getKeyLabel(activator.trigger));
    return parts.join('+');
  }

  /// Get label for a logical key
  static String _getKeyLabel(LogicalKeyboardKey key) {
    // Handle special keys
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.escape) return 'Escape';
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    if (key == LogicalKeyboardKey.backspace) return 'Backspace';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.arrowUp) return 'Up';
    if (key == LogicalKeyboardKey.arrowDown) return 'Down';
    if (key == LogicalKeyboardKey.arrowLeft) return 'Left';
    if (key == LogicalKeyboardKey.arrowRight) return 'Right';
    if (key == LogicalKeyboardKey.home) return 'Home';
    if (key == LogicalKeyboardKey.end) return 'End';
    if (key == LogicalKeyboardKey.pageUp) return 'PageUp';
    if (key == LogicalKeyboardKey.pageDown) return 'PageDown';

    // Function keys
    if (key == LogicalKeyboardKey.f1) return 'F1';
    if (key == LogicalKeyboardKey.f2) return 'F2';
    if (key == LogicalKeyboardKey.f3) return 'F3';
    if (key == LogicalKeyboardKey.f4) return 'F4';
    if (key == LogicalKeyboardKey.f5) return 'F5';
    if (key == LogicalKeyboardKey.f6) return 'F6';
    if (key == LogicalKeyboardKey.f7) return 'F7';
    if (key == LogicalKeyboardKey.f8) return 'F8';
    if (key == LogicalKeyboardKey.f9) return 'F9';
    if (key == LogicalKeyboardKey.f10) return 'F10';
    if (key == LogicalKeyboardKey.f11) return 'F11';
    if (key == LogicalKeyboardKey.f12) return 'F12';

    // Use the key label or debugName
    final label = key.keyLabel;
    if (label.isNotEmpty) return label.toUpperCase();
    return key.debugName ?? 'Unknown';
  }

  ShortcutBinding copyWith({
    ShortcutAction? action,
    SingleActivator? activator,
    bool? isDefault,
  }) {
    return ShortcutBinding(
      action: action ?? this.action,
      activator: activator ?? this.activator,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

/// Default keyboard shortcuts
final Map<ShortcutAction, ShortcutBinding> defaultShortcuts = {
  ShortcutAction.generate: ShortcutBinding(
    action: ShortcutAction.generate,
    activator: const SingleActivator(LogicalKeyboardKey.enter),
    isDefault: true,
  ),
  ShortcutAction.generateLockedSeed: ShortcutBinding(
    action: ShortcutAction.generateLockedSeed,
    activator: const SingleActivator(LogicalKeyboardKey.enter, control: true),
    isDefault: true,
  ),
  ShortcutAction.cancelGeneration: ShortcutBinding(
    action: ShortcutAction.cancelGeneration,
    activator: const SingleActivator(LogicalKeyboardKey.escape),
    isDefault: true,
  ),
  ShortcutAction.savePreset: ShortcutBinding(
    action: ShortcutAction.savePreset,
    activator: const SingleActivator(LogicalKeyboardKey.keyS, control: true),
    isDefault: true,
  ),
  ShortcutAction.undoPrompt: ShortcutBinding(
    action: ShortcutAction.undoPrompt,
    activator: const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
    isDefault: true,
  ),
  ShortcutAction.copySeed: ShortcutBinding(
    action: ShortcutAction.copySeed,
    activator: const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true),
    isDefault: true,
  ),
  ShortcutAction.toggleVideoMode: ShortcutBinding(
    action: ShortcutAction.toggleVideoMode,
    activator: const SingleActivator(LogicalKeyboardKey.keyV, control: true),
    isDefault: true,
  ),
  ShortcutAction.randomizeSeed: ShortcutBinding(
    action: ShortcutAction.randomizeSeed,
    activator: const SingleActivator(LogicalKeyboardKey.keyR, control: true),
    isDefault: true,
  ),
  ShortcutAction.focusPrompt: ShortcutBinding(
    action: ShortcutAction.focusPrompt,
    activator: const SingleActivator(LogicalKeyboardKey.keyP, control: true),
    isDefault: true,
  ),
  ShortcutAction.focusNegativePrompt: ShortcutBinding(
    action: ShortcutAction.focusNegativePrompt,
    activator: const SingleActivator(LogicalKeyboardKey.keyN, control: true),
    isDefault: true,
  ),
  ShortcutAction.openSettings: ShortcutBinding(
    action: ShortcutAction.openSettings,
    activator: const SingleActivator(LogicalKeyboardKey.comma, control: true),
    isDefault: true,
  ),
  ShortcutAction.openModels: ShortcutBinding(
    action: ShortcutAction.openModels,
    activator: const SingleActivator(LogicalKeyboardKey.keyM, control: true),
    isDefault: true,
  ),
  ShortcutAction.openGallery: ShortcutBinding(
    action: ShortcutAction.openGallery,
    activator: const SingleActivator(LogicalKeyboardKey.keyG, control: true),
    isDefault: true,
  ),
};

/// Keyboard shortcuts state
class KeyboardShortcutsState {
  final Map<ShortcutAction, ShortcutBinding> shortcuts;
  final bool isEnabled;
  final String? error;

  const KeyboardShortcutsState({
    this.shortcuts = const {},
    this.isEnabled = true,
    this.error,
  });

  KeyboardShortcutsState copyWith({
    Map<ShortcutAction, ShortcutBinding>? shortcuts,
    bool? isEnabled,
    String? error,
  }) {
    return KeyboardShortcutsState(
      shortcuts: shortcuts ?? this.shortcuts,
      isEnabled: isEnabled ?? this.isEnabled,
      error: error,
    );
  }

  /// Get the binding for a specific action
  ShortcutBinding? getBinding(ShortcutAction action) {
    return shortcuts[action];
  }

  /// Build shortcuts map for Flutter's Shortcuts widget
  Map<ShortcutActivator, Intent> buildShortcutsMap(Map<ShortcutAction, Intent> intents) {
    if (!isEnabled) return {};

    final result = <ShortcutActivator, Intent>{};
    for (final entry in shortcuts.entries) {
      final intent = intents[entry.key];
      if (intent != null) {
        result[entry.value.activator] = intent;
      }
    }
    return result;
  }
}

/// Keyboard shortcuts state notifier
class KeyboardShortcutsNotifier extends StateNotifier<KeyboardShortcutsState> {
  final KeyboardShortcutsService _service;

  KeyboardShortcutsNotifier(this._service) : super(const KeyboardShortcutsState()) {
    _loadShortcuts();
  }

  /// Load shortcuts from storage
  Future<void> _loadShortcuts() async {
    try {
      final customShortcuts = await _service.loadShortcuts();
      final mergedShortcuts = Map<ShortcutAction, ShortcutBinding>.from(defaultShortcuts);

      // Override with custom shortcuts
      for (final entry in customShortcuts.entries) {
        mergedShortcuts[entry.key] = entry.value;
      }

      state = state.copyWith(shortcuts: mergedShortcuts, error: null);
    } catch (e) {
      state = state.copyWith(
        shortcuts: Map.from(defaultShortcuts),
        error: e.toString(),
      );
    }
  }

  /// Update a shortcut binding
  Future<void> updateShortcut(ShortcutAction action, SingleActivator activator) async {
    try {
      final newBinding = ShortcutBinding(
        action: action,
        activator: activator,
        isDefault: false,
      );

      final updatedShortcuts = Map<ShortcutAction, ShortcutBinding>.from(state.shortcuts);
      updatedShortcuts[action] = newBinding;

      await _service.saveShortcuts(updatedShortcuts);
      state = state.copyWith(shortcuts: updatedShortcuts, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Reset a single shortcut to default
  Future<void> resetShortcut(ShortcutAction action) async {
    try {
      final defaultBinding = defaultShortcuts[action];
      if (defaultBinding == null) return;

      final updatedShortcuts = Map<ShortcutAction, ShortcutBinding>.from(state.shortcuts);
      updatedShortcuts[action] = defaultBinding;

      await _service.saveShortcuts(updatedShortcuts);
      state = state.copyWith(shortcuts: updatedShortcuts, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Reset all shortcuts to defaults
  Future<void> resetAllShortcuts() async {
    try {
      await _service.clearShortcuts();
      state = state.copyWith(shortcuts: Map.from(defaultShortcuts), error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Toggle shortcuts enabled/disabled
  void setEnabled(bool enabled) {
    state = state.copyWith(isEnabled: enabled);
  }

  /// Check if a shortcut conflicts with existing bindings
  ShortcutAction? findConflict(ShortcutAction forAction, SingleActivator activator) {
    for (final entry in state.shortcuts.entries) {
      if (entry.key == forAction) continue;

      final existing = entry.value.activator;
      if (existing.trigger == activator.trigger &&
          existing.control == activator.control &&
          existing.shift == activator.shift &&
          existing.alt == activator.alt &&
          existing.meta == activator.meta) {
        return entry.key;
      }
    }
    return null;
  }
}

/// Keyboard shortcuts service for storage operations
class KeyboardShortcutsService {
  /// Load custom shortcuts from storage
  Future<Map<ShortcutAction, ShortcutBinding>> loadShortcuts() async {
    final jsonString = StorageService.getStringStatic(_shortcutsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return {};
    }

    try {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final shortcuts = <ShortcutAction, ShortcutBinding>{};

      for (final entry in jsonMap.entries) {
        try {
          final action = ShortcutAction.values.firstWhere(
            (a) => a.name == entry.key,
          );
          final binding = ShortcutBinding.fromJson(entry.value as Map<String, dynamic>);
          shortcuts[action] = binding;
        } catch (e) {
          // Skip invalid entries
          continue;
        }
      }

      return shortcuts;
    } catch (e) {
      print('Error loading shortcuts: $e');
      return {};
    }
  }

  /// Save shortcuts to storage
  Future<void> saveShortcuts(Map<ShortcutAction, ShortcutBinding> shortcuts) async {
    final jsonMap = <String, dynamic>{};
    for (final entry in shortcuts.entries) {
      // Only save non-default shortcuts
      if (!entry.value.isDefault) {
        jsonMap[entry.key.name] = entry.value.toJson();
      }
    }
    await StorageService.setStringStatic(_shortcutsKey, jsonEncode(jsonMap));
  }

  /// Clear all custom shortcuts
  Future<void> clearShortcuts() async {
    await StorageService.remove(_shortcutsKey);
  }
}

/// Intent classes for shortcut actions
class GenerateIntent extends Intent {
  const GenerateIntent();
}

class GenerateLockedSeedIntent extends Intent {
  const GenerateLockedSeedIntent();
}

class CancelGenerationIntent extends Intent {
  const CancelGenerationIntent();
}

class SavePresetIntent extends Intent {
  const SavePresetIntent();
}

class UndoPromptIntent extends Intent {
  const UndoPromptIntent();
}

class CopySeedIntent extends Intent {
  const CopySeedIntent();
}

class ToggleVideoModeIntent extends Intent {
  const ToggleVideoModeIntent();
}

class RandomizeSeedIntent extends Intent {
  const RandomizeSeedIntent();
}

class FocusPromptIntent extends Intent {
  const FocusPromptIntent();
}

class FocusNegativePromptIntent extends Intent {
  const FocusNegativePromptIntent();
}

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class OpenModelsIntent extends Intent {
  const OpenModelsIntent();
}

class OpenGalleryIntent extends Intent {
  const OpenGalleryIntent();
}

/// Map of actions to intents
const Map<ShortcutAction, Intent> shortcutIntents = {
  ShortcutAction.generate: GenerateIntent(),
  ShortcutAction.generateLockedSeed: GenerateLockedSeedIntent(),
  ShortcutAction.cancelGeneration: CancelGenerationIntent(),
  ShortcutAction.savePreset: SavePresetIntent(),
  ShortcutAction.undoPrompt: UndoPromptIntent(),
  ShortcutAction.copySeed: CopySeedIntent(),
  ShortcutAction.toggleVideoMode: ToggleVideoModeIntent(),
  ShortcutAction.randomizeSeed: RandomizeSeedIntent(),
  ShortcutAction.focusPrompt: FocusPromptIntent(),
  ShortcutAction.focusNegativePrompt: FocusNegativePromptIntent(),
  ShortcutAction.openSettings: OpenSettingsIntent(),
  ShortcutAction.openModels: OpenModelsIntent(),
  ShortcutAction.openGallery: OpenGalleryIntent(),
};
