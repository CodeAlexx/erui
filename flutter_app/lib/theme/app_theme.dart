import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_fonts/google_fonts.dart';

/// EriUI app theme using flex_color_scheme
class AppTheme {
  // Available theme options
  static const List<FlexScheme> availableSchemes = [
    FlexScheme.amber,
    FlexScheme.gold,
    FlexScheme.mango,
    FlexScheme.deepOrangeM3,
    FlexScheme.brandBlue,
    FlexScheme.indigo,
    FlexScheme.hippieBlue,
    FlexScheme.aquaBlue,
    FlexScheme.greenM3,
    FlexScheme.redWine,
    FlexScheme.rosewood,
    FlexScheme.purpleBrown,
    FlexScheme.deepPurple,
    FlexScheme.ebonyClay,
    FlexScheme.barossa,
    FlexScheme.shark,
    FlexScheme.outerSpace,
    FlexScheme.blumineBlue,
    FlexScheme.blueM3,
    FlexScheme.cyanM3,
  ];

  static String getSchemeName(FlexScheme scheme) {
    switch (scheme) {
      case FlexScheme.amber: return 'Amber';
      case FlexScheme.gold: return 'Gold';
      case FlexScheme.mango: return 'Mango';
      case FlexScheme.deepOrangeM3: return 'Deep Orange';
      case FlexScheme.brandBlue: return 'Brand Blue';
      case FlexScheme.indigo: return 'Indigo';
      case FlexScheme.hippieBlue: return 'Hippie Blue';
      case FlexScheme.aquaBlue: return 'Aqua Blue';
      case FlexScheme.greenM3: return 'Green';
      case FlexScheme.redWine: return 'Red Wine';
      case FlexScheme.rosewood: return 'Rosewood';
      case FlexScheme.purpleBrown: return 'Purple Brown';
      case FlexScheme.deepPurple: return 'Deep Purple';
      case FlexScheme.ebonyClay: return 'Ebony Clay';
      case FlexScheme.barossa: return 'Barossa';
      case FlexScheme.shark: return 'Shark';
      case FlexScheme.outerSpace: return 'Outer Space';
      case FlexScheme.blumineBlue: return 'Blumine';
      case FlexScheme.blueM3: return 'Blue';
      case FlexScheme.cyanM3: return 'Cyan';
      default: return scheme.name;
    }
  }

  /// Light theme
  static ThemeData light([FlexScheme scheme = FlexScheme.gold]) {
    return FlexThemeData.light(
      scheme: scheme,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        blendOnColors: false,
        useTextTheme: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: 8.0,
        cardRadius: 8.0,
        popupMenuRadius: 8.0,
        dialogRadius: 12.0,
        drawerRadius: 0.0,
        sliderTrackHeight: 4,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
    );
  }

  /// Dark theme - ERI style with deep dark backgrounds
  static ThemeData dark([FlexScheme scheme = FlexScheme.gold]) {
    return FlexThemeData.dark(
      scheme: scheme,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 13,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        useTextTheme: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: 8.0,
        cardRadius: 8.0,
        popupMenuRadius: 8.0,
        dialogRadius: 12.0,
        drawerRadius: 0.0,
        sliderTrackHeight: 4,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      darkIsTrueBlack: false,
    ).copyWith(
      // Extra dark scaffold for ERI-like look
      scaffoldBackgroundColor: const Color(0xFF0D0D12),
    );
  }

  /// Ultra dark theme variant
  static ThemeData ultraDark([FlexScheme scheme = FlexScheme.gold]) {
    return FlexThemeData.dark(
      scheme: scheme,
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 4,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        useTextTheme: true,
        useM2StyleDividerInM3: true,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: 8.0,
        cardRadius: 8.0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      darkIsTrueBlack: true, // AMOLED black
    );
  }
}
