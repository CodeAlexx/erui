import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/mask_models.dart';

/// State for mask editing
class MaskEditingState {
  /// Map of clip ID to mask state
  final Map<EditorId, ClipMaskState> clipMasks;

  /// Currently active clip for mask editing
  final EditorId? activeClipId;

  /// Currently selected mask ID
  final EditorId? selectedMaskId;

  /// Currently selected point index (for bezier masks)
  final int? selectedPointIndex;

  /// Current mask tool
  final MaskType currentTool;

  /// Whether mask editing mode is active
  final bool isEditing;

  /// Whether to show mask outlines
  final bool showOutlines;

  /// Whether to show mask overlay
  final bool showOverlay;

  const MaskEditingState({
    this.clipMasks = const {},
    this.activeClipId,
    this.selectedMaskId,
    this.selectedPointIndex,
    this.currentTool = MaskType.rectangle,
    this.isEditing = false,
    this.showOutlines = true,
    this.showOverlay = true,
  });

  MaskEditingState copyWith({
    Map<EditorId, ClipMaskState>? clipMasks,
    EditorId? activeClipId,
    EditorId? selectedMaskId,
    int? selectedPointIndex,
    MaskType? currentTool,
    bool? isEditing,
    bool? showOutlines,
    bool? showOverlay,
  }) {
    return MaskEditingState(
      clipMasks: clipMasks ?? this.clipMasks,
      activeClipId: activeClipId ?? this.activeClipId,
      selectedMaskId: selectedMaskId ?? this.selectedMaskId,
      selectedPointIndex: selectedPointIndex ?? this.selectedPointIndex,
      currentTool: currentTool ?? this.currentTool,
      isEditing: isEditing ?? this.isEditing,
      showOutlines: showOutlines ?? this.showOutlines,
      showOverlay: showOverlay ?? this.showOverlay,
    );
  }

  /// Get current clip's mask state
  ClipMaskState? get activeClipMasks {
    if (activeClipId == null) return null;
    return clipMasks[activeClipId];
  }

  /// Get selected mask
  Mask? get selectedMask {
    if (selectedMaskId == null || activeClipId == null) return null;
    final clipState = clipMasks[activeClipId];
    if (clipState == null) return null;

    for (final mask in clipState.masks) {
      if (mask.id == selectedMaskId) return mask;
    }
    return null;
  }
}

/// Provider for mask editing state
final maskProvider =
    StateNotifierProvider<MaskNotifier, MaskEditingState>((ref) {
  return MaskNotifier();
});

/// Notifier for mask editing
class MaskNotifier extends StateNotifier<MaskEditingState> {
  MaskNotifier() : super(const MaskEditingState());

  /// Set active clip for mask editing
  void setActiveClip(EditorId? clipId) {
    state = state.copyWith(activeClipId: clipId);
  }

  /// Enter mask editing mode
  void enterEditingMode(EditorId clipId) {
    state = state.copyWith(
      activeClipId: clipId,
      isEditing: true,
    );
  }

  /// Exit mask editing mode
  void exitEditingMode() {
    state = state.copyWith(
      isEditing: false,
      selectedMaskId: null,
      selectedPointIndex: null,
    );
  }

  /// Set current mask tool
  void setTool(MaskType tool) {
    state = state.copyWith(currentTool: tool);
  }

  /// Add a rectangle mask
  void addRectangleMask({
    double x = 0.25,
    double y = 0.25,
    double width = 0.5,
    double height = 0.5,
  }) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final mask = RectangleMask(
      id: generateId(),
      x: x,
      y: y,
      width: width,
      height: height,
    );

    _addMask(clipId, mask);
  }

  /// Add an ellipse mask
  void addEllipseMask({
    double centerX = 0.5,
    double centerY = 0.5,
    double radiusX = 0.25,
    double radiusY = 0.25,
  }) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final mask = EllipseMask(
      id: generateId(),
      centerX: centerX,
      centerY: centerY,
      radiusX: radiusX,
      radiusY: radiusY,
    );

    _addMask(clipId, mask);
  }

  /// Add a bezier mask
  void addBezierMask({List<MaskPoint>? points}) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final mask = BezierMask(
      id: generateId(),
      points: points ?? [],
      closed: true,
    );

    _addMask(clipId, mask);
  }

  /// Add a luminosity mask
  void addLuminosityMask({
    int lowThreshold = 128,
    int highThreshold = 255,
  }) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final mask = LuminosityMask(
      id: generateId(),
      lowThreshold: lowThreshold,
      highThreshold: highThreshold,
    );

    _addMask(clipId, mask);
  }

  /// Add mask helper
  void _addMask(EditorId clipId, Mask mask) {
    final current = state.clipMasks[clipId] ?? ClipMaskState(clipId: clipId);
    final updated = current.addMask(mask);

    state = state.copyWith(
      clipMasks: {...state.clipMasks, clipId: updated},
      selectedMaskId: mask.id,
    );
  }

  /// Remove a mask
  void removeMask(EditorId maskId) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final current = state.clipMasks[clipId];
    if (current == null) return;

    final updated = current.removeMask(maskId);
    state = state.copyWith(
      clipMasks: {...state.clipMasks, clipId: updated},
      selectedMaskId: state.selectedMaskId == maskId ? null : state.selectedMaskId,
    );
  }

  /// Update a mask
  void updateMask(Mask mask) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final current = state.clipMasks[clipId];
    if (current == null) return;

    final updated = current.updateMask(mask);
    state = state.copyWith(
      clipMasks: {...state.clipMasks, clipId: updated},
    );
  }

  /// Select a mask
  void selectMask(EditorId? maskId) {
    state = state.copyWith(
      selectedMaskId: maskId,
      selectedPointIndex: null,
    );
  }

  /// Select a point in bezier mask
  void selectPoint(int? pointIndex) {
    state = state.copyWith(selectedPointIndex: pointIndex);
  }

  /// Reorder masks
  void reorderMasks(int oldIndex, int newIndex) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final current = state.clipMasks[clipId];
    if (current == null) return;

    final updated = current.reorderMasks(oldIndex, newIndex);
    state = state.copyWith(
      clipMasks: {...state.clipMasks, clipId: updated},
    );
  }

  /// Set mask blend mode
  void setBlendMode(MaskBlendMode mode) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final current = state.clipMasks[clipId];
    if (current == null) return;

    state = state.copyWith(
      clipMasks: {
        ...state.clipMasks,
        clipId: current.copyWith(blendMode: mode),
      },
    );
  }

  /// Toggle mask enabled
  void toggleMaskEnabled(EditorId maskId) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final current = state.clipMasks[clipId];
    if (current == null) return;

    final mask = current.masks.firstWhere((m) => m.id == maskId);
    updateMask(mask.copyWith(enabled: !mask.enabled));
  }

  /// Toggle mask inverted
  void toggleMaskInverted(EditorId maskId) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final current = state.clipMasks[clipId];
    if (current == null) return;

    final mask = current.masks.firstWhere((m) => m.id == maskId);
    updateMask(mask.copyWith(inverted: !mask.inverted));
  }

  /// Set mask feather
  void setMaskFeather(EditorId maskId, double feather) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final current = state.clipMasks[clipId];
    if (current == null) return;

    final mask = current.masks.firstWhere((m) => m.id == maskId);
    updateMask(mask.copyWith(feather: feather));
  }

  /// Set mask opacity
  void setMaskOpacity(EditorId maskId, double opacity) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final current = state.clipMasks[clipId];
    if (current == null) return;

    final mask = current.masks.firstWhere((m) => m.id == maskId);
    updateMask(mask.copyWith(opacity: opacity));
  }

  /// Toggle show outlines
  void toggleShowOutlines() {
    state = state.copyWith(showOutlines: !state.showOutlines);
  }

  /// Toggle show overlay
  void toggleShowOverlay() {
    state = state.copyWith(showOverlay: !state.showOverlay);
  }

  /// Add point to bezier mask
  void addBezierPoint(EditorId maskId, MaskPoint point) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final current = state.clipMasks[clipId];
    if (current == null) return;

    final mask = current.masks.firstWhere((m) => m.id == maskId);
    if (mask is! BezierMask) return;

    updateMask(mask.addPoint(point));
  }

  /// Update bezier point
  void updateBezierPoint(EditorId maskId, int index, MaskPoint point) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final current = state.clipMasks[clipId];
    if (current == null) return;

    final mask = current.masks.firstWhere((m) => m.id == maskId);
    if (mask is! BezierMask) return;

    updateMask(mask.updatePoint(index, point));
  }

  /// Remove bezier point
  void removeBezierPoint(EditorId maskId, int index) {
    final clipId = state.activeClipId;
    if (clipId == null) return;

    final current = state.clipMasks[clipId];
    if (current == null) return;

    final mask = current.masks.firstWhere((m) => m.id == maskId);
    if (mask is! BezierMask) return;

    updateMask(mask.removePoint(index));
    state = state.copyWith(selectedPointIndex: null);
  }
}

/// Provider for masks on a specific clip
final clipMasksProvider =
    Provider.family<ClipMaskState?, EditorId>((ref, clipId) {
  return ref.watch(maskProvider).clipMasks[clipId];
});

/// Provider for selected mask
final selectedMaskProvider = Provider<Mask?>((ref) {
  return ref.watch(maskProvider).selectedMask;
});

/// Provider for mask editing mode
final maskEditingModeProvider = Provider<bool>((ref) {
  return ref.watch(maskProvider).isEditing;
});

/// Provider for current mask tool
final currentMaskToolProvider = Provider<MaskType>((ref) {
  return ref.watch(maskProvider).currentTool;
});
