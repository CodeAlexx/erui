import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import '../services/storage_service.dart';

/// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Color scheme provider
final colorSchemeProvider = StateNotifierProvider<ColorSchemeNotifier, FlexScheme>((ref) {
  return ColorSchemeNotifier();
});

/// Theme mode state notifier
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final savedTheme = StorageService.getStringStatic('theme_mode');
    if (savedTheme != null) {
      state = ThemeMode.values.firstWhere(
        (mode) => mode.name == savedTheme,
        orElse: () => ThemeMode.dark,
      );
    }
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    StorageService.setStringStatic('theme_mode', mode.name);
  }

  void toggleTheme() {
    if (state == ThemeMode.light) {
      setTheme(ThemeMode.dark);
    } else {
      setTheme(ThemeMode.light);
    }
  }
}

/// Color scheme state notifier
class ColorSchemeNotifier extends StateNotifier<FlexScheme> {
  ColorSchemeNotifier() : super(FlexScheme.gold) {
    _loadScheme();
  }

  Future<void> _loadScheme() async {
    final savedScheme = StorageService.getStringStatic('color_scheme');
    if (savedScheme != null) {
      try {
        state = FlexScheme.values.firstWhere(
          (scheme) => scheme.name == savedScheme,
          orElse: () => FlexScheme.gold,
        );
      } catch (_) {
        state = FlexScheme.gold;
      }
    }
  }

  void setScheme(FlexScheme scheme) {
    state = scheme;
    StorageService.setStringStatic('color_scheme', scheme.name);
  }
}
