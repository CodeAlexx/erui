import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/color_grading_models.dart';
import '../models/editor_models.dart';

/// State for color grading across all clips
class ColorGradingState {
  /// Color grades by clip ID
  final Map<EditorId, ColorGrade> grades;

  /// LUTs by clip ID
  final Map<EditorId, LUTFile?> luts;

  /// HSL adjustments by clip ID
  final Map<EditorId, List<HSLAdjustment>> hslAdjustments;

  /// Color curves by clip ID
  final Map<EditorId, List<ColorCurve>> curves;

  const ColorGradingState({
    this.grades = const {},
    this.luts = const {},
    this.hslAdjustments = const {},
    this.curves = const {},
  });

  ColorGradingState copyWith({
    Map<EditorId, ColorGrade>? grades,
    Map<EditorId, LUTFile?>? luts,
    Map<EditorId, List<HSLAdjustment>>? hslAdjustments,
    Map<EditorId, List<ColorCurve>>? curves,
  }) {
    return ColorGradingState(
      grades: grades ?? this.grades,
      luts: luts ?? this.luts,
      hslAdjustments: hslAdjustments ?? this.hslAdjustments,
      curves: curves ?? this.curves,
    );
  }
}

/// Notifier for color grading state
class ColorGradingNotifier extends StateNotifier<ColorGradingState> {
  ColorGradingNotifier() : super(const ColorGradingState());

  /// Get or create color grade for a clip
  ColorGrade getGrade(EditorId clipId) {
    return state.grades[clipId] ?? ColorGrade.defaults(id: clipId);
  }

  /// Update color grade for a clip
  void updateGrade(EditorId clipId, ColorGrade grade) {
    state = state.copyWith(
      grades: {...state.grades, clipId: grade},
    );
  }

  /// Reset color grade to defaults
  void resetGrade(EditorId clipId) {
    state = state.copyWith(
      grades: {...state.grades, clipId: ColorGrade.defaults(id: clipId)},
    );
  }

  /// Set LUT for a clip
  void setLUT(EditorId clipId, LUTFile? lut) {
    state = state.copyWith(
      luts: {...state.luts, clipId: lut},
    );
  }

  /// Clear LUT for a clip
  void clearLUT(EditorId clipId) {
    final newLuts = Map<EditorId, LUTFile?>.from(state.luts);
    newLuts.remove(clipId);
    state = state.copyWith(luts: newLuts);
  }

  /// Set HSL adjustments for a clip
  void setHSLAdjustments(EditorId clipId, List<HSLAdjustment> adjustments) {
    state = state.copyWith(
      hslAdjustments: {...state.hslAdjustments, clipId: adjustments},
    );
  }

  /// Update a single HSL adjustment
  void updateHSLAdjustment(
      EditorId clipId, ColorRange range, HSLAdjustment adjustment) {
    final current = state.hslAdjustments[clipId] ?? [];
    final updated = current.map((a) => a.range == range ? adjustment : a).toList();
    if (!updated.any((a) => a.range == range)) {
      updated.add(adjustment);
    }
    state = state.copyWith(
      hslAdjustments: {...state.hslAdjustments, clipId: updated},
    );
  }

  /// Set color curves for a clip
  void setCurves(EditorId clipId, List<ColorCurve> curves) {
    state = state.copyWith(
      curves: {...state.curves, clipId: curves},
    );
  }

  /// Update a single curve
  void updateCurve(EditorId clipId, ColorCurve curve) {
    final current = state.curves[clipId] ?? [];
    final updated =
        current.map((c) => c.channel == curve.channel ? curve : c).toList();
    if (!updated.any((c) => c.channel == curve.channel)) {
      updated.add(curve);
    }
    state = state.copyWith(
      curves: {...state.curves, clipId: updated},
    );
  }

  /// Remove all grading for a clip
  void removeClip(EditorId clipId) {
    final newGrades = Map<EditorId, ColorGrade>.from(state.grades);
    final newLuts = Map<EditorId, LUTFile?>.from(state.luts);
    final newHsl = Map<EditorId, List<HSLAdjustment>>.from(state.hslAdjustments);
    final newCurves = Map<EditorId, List<ColorCurve>>.from(state.curves);

    newGrades.remove(clipId);
    newLuts.remove(clipId);
    newHsl.remove(clipId);
    newCurves.remove(clipId);

    state = ColorGradingState(
      grades: newGrades,
      luts: newLuts,
      hslAdjustments: newHsl,
      curves: newCurves,
    );
  }
}

/// Provider for color grading state
final colorGradingNotifierProvider =
    StateNotifierProvider<ColorGradingNotifier, ColorGradingState>((ref) {
  return ColorGradingNotifier();
});

/// Provider for a specific clip's color grade
final clipColorGradeProvider =
    Provider.family<ColorGrade?, EditorId>((ref, clipId) {
  final state = ref.watch(colorGradingNotifierProvider);
  return state.grades[clipId];
});

/// Provider for a specific clip's LUT
final clipLUTProvider = Provider.family<LUTFile?, EditorId>((ref, clipId) {
  final state = ref.watch(colorGradingNotifierProvider);
  return state.luts[clipId];
});

/// Provider for a specific clip's HSL adjustments
final clipHSLProvider =
    Provider.family<List<HSLAdjustment>, EditorId>((ref, clipId) {
  final state = ref.watch(colorGradingNotifierProvider);
  return state.hslAdjustments[clipId] ?? [];
});

/// Provider for a specific clip's color curves
final clipCurvesProvider =
    Provider.family<List<ColorCurve>, EditorId>((ref, clipId) {
  final state = ref.watch(colorGradingNotifierProvider);
  return state.curves[clipId] ?? [];
});

/// State for LUT library
class LUTLibraryState {
  final List<LUTFile> luts;
  final List<LUTFile> recentLuts;
  final bool isLoading;
  final String? error;

  const LUTLibraryState({
    this.luts = const [],
    this.recentLuts = const [],
    this.isLoading = false,
    this.error,
  });

  LUTLibraryState copyWith({
    List<LUTFile>? luts,
    List<LUTFile>? recentLuts,
    bool? isLoading,
    String? error,
  }) {
    return LUTLibraryState(
      luts: luts ?? this.luts,
      recentLuts: recentLuts ?? this.recentLuts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for LUT library
class LUTLibraryNotifier extends StateNotifier<LUTLibraryState> {
  LUTLibraryNotifier() : super(const LUTLibraryState());

  /// Load LUTs from directory
  Future<void> loadLUTs(String directoryPath) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // TODO: Implement actual LUT loading
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Toggle favorite status
  void toggleFavorite(EditorId lutId) {
    final updatedLuts = state.luts.map((lut) {
      if (lut.id == lutId) {
        return lut.copyWith(isFavorite: !lut.isFavorite);
      }
      return lut;
    }).toList();
    state = state.copyWith(luts: updatedLuts);
  }

  /// Add LUT to recent list
  void addToRecent(LUTFile lut) {
    final recent = [
      lut.copyWith(lastUsed: DateTime.now()),
      ...state.recentLuts.where((l) => l.id != lut.id).take(9),
    ];
    state = state.copyWith(recentLuts: recent);
  }

  /// Import a new LUT file
  Future<void> importLUT() async {
    // TODO: Implement file picker and import
  }

  /// Open LUT folder in file manager
  void openLUTFolder() {
    // TODO: Implement folder open
  }
}

/// Provider for LUT library
final lutLibraryProvider =
    StateNotifierProvider<LUTLibraryNotifier, LUTLibraryState>((ref) {
  return LUTLibraryNotifier();
});
