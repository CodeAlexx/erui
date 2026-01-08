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

/// UI Density enum
enum UiDensity { compact, comfortable, spacious }

/// UI Density provider
final uiDensityProvider = StateNotifierProvider<UiDensityNotifier, UiDensity>((ref) {
  return UiDensityNotifier();
});

/// UI Density state notifier
class UiDensityNotifier extends StateNotifier<UiDensity> {
  UiDensityNotifier() : super(UiDensity.comfortable) {
    _loadDensity();
  }

  Future<void> _loadDensity() async {
    final saved = StorageService.getStringStatic('ui_density');
    if (saved != null) {
      state = UiDensity.values.firstWhere(
        (d) => d.name == saved,
        orElse: () => UiDensity.comfortable,
      );
    }
  }

  void setDensity(UiDensity density) {
    state = density;
    StorageService.setStringStatic('ui_density', density.name);
  }

  /// Get VisualDensity for Flutter widgets
  VisualDensity get visualDensity {
    switch (state) {
      case UiDensity.compact:
        return VisualDensity.compact;
      case UiDensity.comfortable:
        return VisualDensity.comfortable;
      case UiDensity.spacious:
        return const VisualDensity(horizontal: 2.0, vertical: 2.0);
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
