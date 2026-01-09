import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../providers/editor_provider.dart';
import '../providers/undo_system.dart';
import 'playback_controller.dart';

// ============================================================
// Editor Shortcut Action Enum
// ============================================================

/// Identifier for editor shortcut actions
enum EditorShortcutAction {
  // Playback - JKL shuttle control
  shuttleReverse,
  shuttlePause,
  shuttleForward,
  togglePlayPause,

  // In/Out points
  setInPoint,
  setOutPoint,

  // Navigation
  stepFrameBackward,
  stepFrameForward,
  stepTenFramesBackward,
  stepTenFramesForward,
  goToStart,
  goToEnd,

  // Editing
  deleteSelectedClips,
  undo,
  redo,
  selectAll,
  deselectAll,

  // Timeline zoom
  zoomIn,
  zoomOut,

  // Project
  saveProject,
}

/// Extension for display names
extension EditorShortcutActionExtension on EditorShortcutAction {
  String get displayName {
    switch (this) {
      case EditorShortcutAction.shuttleReverse:
        return 'Shuttle Reverse (J)';
      case EditorShortcutAction.shuttlePause:
        return 'Shuttle Pause (K)';
      case EditorShortcutAction.shuttleForward:
        return 'Shuttle Forward (L)';
      case EditorShortcutAction.togglePlayPause:
        return 'Play/Pause';
      case EditorShortcutAction.setInPoint:
        return 'Set In Point';
      case EditorShortcutAction.setOutPoint:
        return 'Set Out Point';
      case EditorShortcutAction.stepFrameBackward:
        return 'Step Frame Backward';
      case EditorShortcutAction.stepFrameForward:
        return 'Step Frame Forward';
      case EditorShortcutAction.stepTenFramesBackward:
        return 'Step 10 Frames Backward';
      case EditorShortcutAction.stepTenFramesForward:
        return 'Step 10 Frames Forward';
      case EditorShortcutAction.goToStart:
        return 'Go to Start';
      case EditorShortcutAction.goToEnd:
        return 'Go to End';
      case EditorShortcutAction.deleteSelectedClips:
        return 'Delete Selected Clips';
      case EditorShortcutAction.undo:
        return 'Undo';
      case EditorShortcutAction.redo:
        return 'Redo';
      case EditorShortcutAction.selectAll:
        return 'Select All Clips';
      case EditorShortcutAction.deselectAll:
        return 'Deselect All';
      case EditorShortcutAction.zoomIn:
        return 'Zoom In Timeline';
      case EditorShortcutAction.zoomOut:
        return 'Zoom Out Timeline';
      case EditorShortcutAction.saveProject:
        return 'Save Project';
    }
  }

  String get shortcutHint {
    switch (this) {
      case EditorShortcutAction.shuttleReverse:
        return 'J';
      case EditorShortcutAction.shuttlePause:
        return 'K';
      case EditorShortcutAction.shuttleForward:
        return 'L';
      case EditorShortcutAction.togglePlayPause:
        return 'Space';
      case EditorShortcutAction.setInPoint:
        return 'I';
      case EditorShortcutAction.setOutPoint:
        return 'O';
      case EditorShortcutAction.stepFrameBackward:
        return 'Left';
      case EditorShortcutAction.stepFrameForward:
        return 'Right';
      case EditorShortcutAction.stepTenFramesBackward:
        return 'Shift+Left';
      case EditorShortcutAction.stepTenFramesForward:
        return 'Shift+Right';
      case EditorShortcutAction.goToStart:
        return 'Home';
      case EditorShortcutAction.goToEnd:
        return 'End';
      case EditorShortcutAction.deleteSelectedClips:
        return 'Delete';
      case EditorShortcutAction.undo:
        return 'Ctrl+Z';
      case EditorShortcutAction.redo:
        return 'Ctrl+Shift+Z';
      case EditorShortcutAction.selectAll:
        return 'Ctrl+A';
      case EditorShortcutAction.deselectAll:
        return 'Escape';
      case EditorShortcutAction.zoomIn:
        return '+';
      case EditorShortcutAction.zoomOut:
        return '-';
      case EditorShortcutAction.saveProject:
        return 'Ctrl+S';
    }
  }
}

// ============================================================
// Intent Classes
// ============================================================

/// Intent for shuttle reverse playback (J key - NLE standard)
class ShuttleReverseIntent extends Intent {
  const ShuttleReverseIntent();
}

/// Intent for shuttle pause (K key - NLE standard)
class ShuttlePauseIntent extends Intent {
  const ShuttlePauseIntent();
}

/// Intent for shuttle forward playback (L key - NLE standard)
class ShuttleForwardIntent extends Intent {
  const ShuttleForwardIntent();
}

/// Intent for toggling play/pause (Spacebar)
class TogglePlayPauseIntent extends Intent {
  const TogglePlayPauseIntent();
}

/// Intent for setting in point (I key)
class SetInPointIntent extends Intent {
  const SetInPointIntent();
}

/// Intent for setting out point (O key)
class SetOutPointIntent extends Intent {
  const SetOutPointIntent();
}

/// Intent for stepping one frame backward (Left arrow)
class StepFrameBackwardIntent extends Intent {
  const StepFrameBackwardIntent();
}

/// Intent for stepping one frame forward (Right arrow)
class StepFrameForwardIntent extends Intent {
  const StepFrameForwardIntent();
}

/// Intent for stepping 10 frames backward (Shift+Left)
class StepTenFramesBackwardIntent extends Intent {
  const StepTenFramesBackwardIntent();
}

/// Intent for stepping 10 frames forward (Shift+Right)
class StepTenFramesForwardIntent extends Intent {
  const StepTenFramesForwardIntent();
}

/// Intent for going to timeline start (Home key)
class GoToStartIntent extends Intent {
  const GoToStartIntent();
}

/// Intent for going to timeline end (End key)
class GoToEndIntent extends Intent {
  const GoToEndIntent();
}

/// Intent for deleting selected clips (Delete/Backspace)
class DeleteSelectedClipsIntent extends Intent {
  const DeleteSelectedClipsIntent();
}

/// Intent for undo (Ctrl+Z)
class EditorUndoIntent extends Intent {
  const EditorUndoIntent();
}

/// Intent for redo (Ctrl+Shift+Z or Ctrl+Y)
class EditorRedoIntent extends Intent {
  const EditorRedoIntent();
}

/// Intent for selecting all clips (Ctrl+A)
class SelectAllClipsIntent extends Intent {
  const SelectAllClipsIntent();
}

/// Intent for deselecting all (Escape)
class DeselectAllIntent extends Intent {
  const DeselectAllIntent();
}

/// Intent for zooming in timeline (+/=)
class ZoomInTimelineIntent extends Intent {
  const ZoomInTimelineIntent();
}

/// Intent for zooming out timeline (-)
class ZoomOutTimelineIntent extends Intent {
  const ZoomOutTimelineIntent();
}

/// Intent for saving project (Ctrl+S)
class SaveProjectIntent extends Intent {
  const SaveProjectIntent();
}

// ============================================================
// Shuttle Speed State
// ============================================================

/// Tracks the current JKL shuttle speed state
/// Standard NLE behavior: pressing L increases forward speed, J increases reverse
class ShuttleSpeedState {
  /// Current shuttle speed multiplier
  /// Negative = reverse, 0 = paused, Positive = forward
  /// Values: -4x, -2x, -1x, 0, 1x, 2x, 4x
  final double speedMultiplier;

  const ShuttleSpeedState({this.speedMultiplier = 0.0});

  /// Speed levels for JKL shuttle: 0, 1x, 2x, 4x
  static const List<double> speedLevels = [0.0, 1.0, 2.0, 4.0];

  /// Get next faster forward speed
  ShuttleSpeedState faster() {
    if (speedMultiplier < 0) {
      // If reversing, slow down first
      return const ShuttleSpeedState(speedMultiplier: 0.0);
    }
    final currentIndex = speedLevels.indexOf(speedMultiplier);
    if (currentIndex < 0 || currentIndex >= speedLevels.length - 1) {
      return const ShuttleSpeedState(speedMultiplier: 4.0);
    }
    return ShuttleSpeedState(speedMultiplier: speedLevels[currentIndex + 1]);
  }

  /// Get next faster reverse speed
  ShuttleSpeedState reverse() {
    if (speedMultiplier > 0) {
      // If playing forward, slow down first
      return const ShuttleSpeedState(speedMultiplier: 0.0);
    }
    final absSpeed = speedMultiplier.abs();
    final currentIndex = speedLevels.indexOf(absSpeed);
    if (currentIndex < 0 || currentIndex >= speedLevels.length - 1) {
      return const ShuttleSpeedState(speedMultiplier: -4.0);
    }
    return ShuttleSpeedState(speedMultiplier: -speedLevels[currentIndex + 1]);
  }

  /// Pause shuttle
  ShuttleSpeedState pause() {
    return const ShuttleSpeedState(speedMultiplier: 0.0);
  }

  bool get isPaused => speedMultiplier == 0.0;
  bool get isForward => speedMultiplier > 0;
  bool get isReverse => speedMultiplier < 0;

  String get displayString {
    if (isPaused) return 'Paused';
    final prefix = isReverse ? '-' : '';
    return '$prefix${speedMultiplier.abs()}x';
  }
}

/// Provider for shuttle speed state
final shuttleSpeedProvider = StateProvider<ShuttleSpeedState>((ref) {
  return const ShuttleSpeedState();
});

// ============================================================
// Callbacks Interface
// ============================================================

/// Callbacks that the editor screen provides for shortcut actions
class EditorShortcutCallbacks {
  final VoidCallback? onShuttleReverse;
  final VoidCallback? onShuttlePause;
  final VoidCallback? onShuttleForward;
  final VoidCallback? onTogglePlayPause;
  final VoidCallback? onSetInPoint;
  final VoidCallback? onSetOutPoint;
  final VoidCallback? onStepFrameBackward;
  final VoidCallback? onStepFrameForward;
  final VoidCallback? onStepTenFramesBackward;
  final VoidCallback? onStepTenFramesForward;
  final VoidCallback? onGoToStart;
  final VoidCallback? onGoToEnd;
  final VoidCallback? onDeleteSelectedClips;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onSelectAll;
  final VoidCallback? onDeselectAll;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onSaveProject;

  const EditorShortcutCallbacks({
    this.onShuttleReverse,
    this.onShuttlePause,
    this.onShuttleForward,
    this.onTogglePlayPause,
    this.onSetInPoint,
    this.onSetOutPoint,
    this.onStepFrameBackward,
    this.onStepFrameForward,
    this.onStepTenFramesBackward,
    this.onStepTenFramesForward,
    this.onGoToStart,
    this.onGoToEnd,
    this.onDeleteSelectedClips,
    this.onUndo,
    this.onRedo,
    this.onSelectAll,
    this.onDeselectAll,
    this.onZoomIn,
    this.onZoomOut,
    this.onSaveProject,
  });
}

// ============================================================
// Action Classes
// ============================================================

/// Action for shuttle reverse
class ShuttleReverseAction extends Action<ShuttleReverseIntent> {
  final VoidCallback? onAction;

  ShuttleReverseAction({this.onAction});

  @override
  Object? invoke(ShuttleReverseIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for shuttle pause
class ShuttlePauseAction extends Action<ShuttlePauseIntent> {
  final VoidCallback? onAction;

  ShuttlePauseAction({this.onAction});

  @override
  Object? invoke(ShuttlePauseIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for shuttle forward
class ShuttleForwardAction extends Action<ShuttleForwardIntent> {
  final VoidCallback? onAction;

  ShuttleForwardAction({this.onAction});

  @override
  Object? invoke(ShuttleForwardIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for toggle play/pause
class TogglePlayPauseAction extends Action<TogglePlayPauseIntent> {
  final VoidCallback? onAction;

  TogglePlayPauseAction({this.onAction});

  @override
  Object? invoke(TogglePlayPauseIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for set in point
class SetInPointAction extends Action<SetInPointIntent> {
  final VoidCallback? onAction;

  SetInPointAction({this.onAction});

  @override
  Object? invoke(SetInPointIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for set out point
class SetOutPointAction extends Action<SetOutPointIntent> {
  final VoidCallback? onAction;

  SetOutPointAction({this.onAction});

  @override
  Object? invoke(SetOutPointIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for step frame backward
class StepFrameBackwardAction extends Action<StepFrameBackwardIntent> {
  final VoidCallback? onAction;

  StepFrameBackwardAction({this.onAction});

  @override
  Object? invoke(StepFrameBackwardIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for step frame forward
class StepFrameForwardAction extends Action<StepFrameForwardIntent> {
  final VoidCallback? onAction;

  StepFrameForwardAction({this.onAction});

  @override
  Object? invoke(StepFrameForwardIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for step 10 frames backward
class StepTenFramesBackwardAction extends Action<StepTenFramesBackwardIntent> {
  final VoidCallback? onAction;

  StepTenFramesBackwardAction({this.onAction});

  @override
  Object? invoke(StepTenFramesBackwardIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for step 10 frames forward
class StepTenFramesForwardAction extends Action<StepTenFramesForwardIntent> {
  final VoidCallback? onAction;

  StepTenFramesForwardAction({this.onAction});

  @override
  Object? invoke(StepTenFramesForwardIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for go to start
class GoToStartAction extends Action<GoToStartIntent> {
  final VoidCallback? onAction;

  GoToStartAction({this.onAction});

  @override
  Object? invoke(GoToStartIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for go to end
class GoToEndAction extends Action<GoToEndIntent> {
  final VoidCallback? onAction;

  GoToEndAction({this.onAction});

  @override
  Object? invoke(GoToEndIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for delete selected clips
class DeleteSelectedClipsAction extends Action<DeleteSelectedClipsIntent> {
  final VoidCallback? onAction;

  DeleteSelectedClipsAction({this.onAction});

  @override
  Object? invoke(DeleteSelectedClipsIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for undo
class EditorUndoAction extends Action<EditorUndoIntent> {
  final VoidCallback? onAction;

  EditorUndoAction({this.onAction});

  @override
  Object? invoke(EditorUndoIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for redo
class EditorRedoAction extends Action<EditorRedoIntent> {
  final VoidCallback? onAction;

  EditorRedoAction({this.onAction});

  @override
  Object? invoke(EditorRedoIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for select all clips
class SelectAllClipsAction extends Action<SelectAllClipsIntent> {
  final VoidCallback? onAction;

  SelectAllClipsAction({this.onAction});

  @override
  Object? invoke(SelectAllClipsIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for deselect all
class DeselectAllAction extends Action<DeselectAllIntent> {
  final VoidCallback? onAction;

  DeselectAllAction({this.onAction});

  @override
  Object? invoke(DeselectAllIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for zoom in timeline
class ZoomInTimelineAction extends Action<ZoomInTimelineIntent> {
  final VoidCallback? onAction;

  ZoomInTimelineAction({this.onAction});

  @override
  Object? invoke(ZoomInTimelineIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for zoom out timeline
class ZoomOutTimelineAction extends Action<ZoomOutTimelineIntent> {
  final VoidCallback? onAction;

  ZoomOutTimelineAction({this.onAction});

  @override
  Object? invoke(ZoomOutTimelineIntent intent) {
    onAction?.call();
    return null;
  }
}

/// Action for save project
class SaveProjectAction extends Action<SaveProjectIntent> {
  final VoidCallback? onAction;

  SaveProjectAction({this.onAction});

  @override
  Object? invoke(SaveProjectIntent intent) {
    onAction?.call();
    return null;
  }
}

// ============================================================
// Default Shortcuts Map
// ============================================================

/// Default keyboard shortcuts for the video editor
/// Following standard NLE conventions
Map<ShortcutActivator, Intent> get defaultEditorShortcuts => {
      // JKL Shuttle Control
      const SingleActivator(LogicalKeyboardKey.keyJ): const ShuttleReverseIntent(),
      const SingleActivator(LogicalKeyboardKey.keyK): const ShuttlePauseIntent(),
      const SingleActivator(LogicalKeyboardKey.keyL): const ShuttleForwardIntent(),

      // Play/Pause
      const SingleActivator(LogicalKeyboardKey.space): const TogglePlayPauseIntent(),

      // In/Out Points
      const SingleActivator(LogicalKeyboardKey.keyI): const SetInPointIntent(),
      const SingleActivator(LogicalKeyboardKey.keyO): const SetOutPointIntent(),

      // Frame Navigation
      const SingleActivator(LogicalKeyboardKey.arrowLeft): const StepFrameBackwardIntent(),
      const SingleActivator(LogicalKeyboardKey.arrowRight): const StepFrameForwardIntent(),
      const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): const StepTenFramesBackwardIntent(),
      const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): const StepTenFramesForwardIntent(),

      // Timeline Navigation
      const SingleActivator(LogicalKeyboardKey.home): const GoToStartIntent(),
      const SingleActivator(LogicalKeyboardKey.end): const GoToEndIntent(),

      // Editing
      const SingleActivator(LogicalKeyboardKey.delete): const DeleteSelectedClipsIntent(),
      const SingleActivator(LogicalKeyboardKey.backspace): const DeleteSelectedClipsIntent(),

      // Undo/Redo
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): const EditorUndoIntent(),
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): const EditorRedoIntent(),
      const SingleActivator(LogicalKeyboardKey.keyY, control: true): const EditorRedoIntent(),

      // Selection
      const SingleActivator(LogicalKeyboardKey.keyA, control: true): const SelectAllClipsIntent(),
      const SingleActivator(LogicalKeyboardKey.escape): const DeselectAllIntent(),

      // Zoom
      const SingleActivator(LogicalKeyboardKey.equal): const ZoomInTimelineIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadAdd): const ZoomInTimelineIntent(),
      const SingleActivator(LogicalKeyboardKey.minus): const ZoomOutTimelineIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadSubtract): const ZoomOutTimelineIntent(),

      // Project
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): const SaveProjectIntent(),
    };

// ============================================================
// Editor Shortcuts Widget
// ============================================================

/// Widget that wraps the editor with keyboard shortcuts.
/// Provides standard NLE keyboard shortcuts for video editing.
///
/// Usage in editor_screen.dart:
/// ```dart
/// EditorShortcuts(
///   callbacks: EditorShortcutCallbacks(
///     onTogglePlayPause: () => ref.read(editorProjectProvider.notifier).togglePlayback(),
///     onUndo: () => ref.read(undoSystemProvider.notifier).undo(),
///     // ... other callbacks
///   ),
///   child: YourEditorContent(),
/// )
/// ```
class EditorShortcuts extends StatelessWidget {
  /// The child widget to wrap with shortcuts
  final Widget child;

  /// Callbacks for shortcut actions
  final EditorShortcutCallbacks callbacks;

  /// Whether shortcuts are enabled (default: true)
  final bool enabled;

  /// Custom shortcuts map (overrides defaults if provided)
  final Map<ShortcutActivator, Intent>? customShortcuts;

  /// Focus node for capturing keyboard input
  final FocusNode? focusNode;

  /// Whether to autofocus this widget
  final bool autofocus;

  const EditorShortcuts({
    super.key,
    required this.child,
    required this.callbacks,
    this.enabled = true,
    this.customShortcuts,
    this.focusNode,
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return Shortcuts(
      shortcuts: customShortcuts ?? defaultEditorShortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          ShuttleReverseIntent: ShuttleReverseAction(onAction: callbacks.onShuttleReverse),
          ShuttlePauseIntent: ShuttlePauseAction(onAction: callbacks.onShuttlePause),
          ShuttleForwardIntent: ShuttleForwardAction(onAction: callbacks.onShuttleForward),
          TogglePlayPauseIntent: TogglePlayPauseAction(onAction: callbacks.onTogglePlayPause),
          SetInPointIntent: SetInPointAction(onAction: callbacks.onSetInPoint),
          SetOutPointIntent: SetOutPointAction(onAction: callbacks.onSetOutPoint),
          StepFrameBackwardIntent: StepFrameBackwardAction(onAction: callbacks.onStepFrameBackward),
          StepFrameForwardIntent: StepFrameForwardAction(onAction: callbacks.onStepFrameForward),
          StepTenFramesBackwardIntent: StepTenFramesBackwardAction(onAction: callbacks.onStepTenFramesBackward),
          StepTenFramesForwardIntent: StepTenFramesForwardAction(onAction: callbacks.onStepTenFramesForward),
          GoToStartIntent: GoToStartAction(onAction: callbacks.onGoToStart),
          GoToEndIntent: GoToEndAction(onAction: callbacks.onGoToEnd),
          DeleteSelectedClipsIntent: DeleteSelectedClipsAction(onAction: callbacks.onDeleteSelectedClips),
          EditorUndoIntent: EditorUndoAction(onAction: callbacks.onUndo),
          EditorRedoIntent: EditorRedoAction(onAction: callbacks.onRedo),
          SelectAllClipsIntent: SelectAllClipsAction(onAction: callbacks.onSelectAll),
          DeselectAllIntent: DeselectAllAction(onAction: callbacks.onDeselectAll),
          ZoomInTimelineIntent: ZoomInTimelineAction(onAction: callbacks.onZoomIn),
          ZoomOutTimelineIntent: ZoomOutTimelineAction(onAction: callbacks.onZoomOut),
          SaveProjectIntent: SaveProjectAction(onAction: callbacks.onSaveProject),
        },
        child: Focus(
          focusNode: focusNode,
          autofocus: autofocus,
          child: child,
        ),
      ),
    );
  }
}

// ============================================================
// Helper Functions for Creating Callbacks
// ============================================================

/// Creates default callbacks wired to the editor providers.
///
/// Usage:
/// ```dart
/// final callbacks = createDefaultEditorCallbacks(ref);
/// ```
EditorShortcutCallbacks createDefaultEditorCallbacks(WidgetRef ref) {
  final editorNotifier = ref.read(editorProjectProvider.notifier);
  final undoNotifier = ref.read(undoSystemProvider.notifier);
  final state = ref.read(editorProjectProvider);
  final playbackController = ref.read(playbackControllerProvider);

  return EditorShortcutCallbacks(
    // JKL Shuttle
    onShuttleReverse: () {
      final currentSpeed = ref.read(shuttleSpeedProvider);
      ref.read(shuttleSpeedProvider.notifier).state = currentSpeed.reverse();
      // Handle playback based on new speed - reverse is typically just pause then backward frame stepping
      playbackController.decreaseSpeed();
    },
    onShuttlePause: () {
      ref.read(shuttleSpeedProvider.notifier).state = const ShuttleSpeedState();
      playbackController.stopShuttle();
    },
    onShuttleForward: () {
      final currentSpeed = ref.read(shuttleSpeedProvider);
      ref.read(shuttleSpeedProvider.notifier).state = currentSpeed.faster();
      playbackController.increaseSpeed();
    },

    // Play/Pause
    onTogglePlayPause: () {
      playbackController.togglePlayback();
    },

    // In/Out Points
    onSetInPoint: () {
      editorNotifier.markIn();
    },
    onSetOutPoint: () {
      editorNotifier.markOut();
    },

    // Frame Navigation
    onStepFrameBackward: () {
      playbackController.stepFrame(-1);
    },
    onStepFrameForward: () {
      playbackController.stepFrame(1);
    },
    onStepTenFramesBackward: () {
      playbackController.stepFrame(-10);
    },
    onStepTenFramesForward: () {
      playbackController.stepFrame(10);
    },

    // Timeline Navigation
    onGoToStart: () {
      playbackController.seekTo(const EditorTime.zero());
    },
    onGoToEnd: () {
      playbackController.seekTo(state.project.duration);
    },

    // Editing
    onDeleteSelectedClips: () {
      for (final clipId in state.selectedClipIds) {
        editorNotifier.removeClip(clipId);
      }
    },

    // Undo/Redo
    onUndo: () {
      undoNotifier.undo();
    },
    onRedo: () {
      undoNotifier.redo();
    },

    // Selection
    onSelectAll: () {
      final allClipIds = <EditorId>[];
      for (final track in state.project.tracks) {
        for (final clip in track.clips) {
          allClipIds.add(clip.id);
        }
      }
      editorNotifier.selectClips(allClipIds);
    },
    onDeselectAll: () {
      editorNotifier.clearSelection();
    },

    // Zoom
    onZoomIn: () {
      editorNotifier.zoomIn();
    },
    onZoomOut: () {
      editorNotifier.zoomOut();
    },

    // Project
    onSaveProject: () {
      // Placeholder - integrate with project save service
      editorNotifier.markSaved();
      // TODO: Trigger actual save to file
    },
  );
}

// ============================================================
// Map of Actions to Intents (for reference)
// ============================================================

/// Map of EditorShortcutAction to Intent classes
const Map<EditorShortcutAction, Intent> editorShortcutIntents = {
  EditorShortcutAction.shuttleReverse: ShuttleReverseIntent(),
  EditorShortcutAction.shuttlePause: ShuttlePauseIntent(),
  EditorShortcutAction.shuttleForward: ShuttleForwardIntent(),
  EditorShortcutAction.togglePlayPause: TogglePlayPauseIntent(),
  EditorShortcutAction.setInPoint: SetInPointIntent(),
  EditorShortcutAction.setOutPoint: SetOutPointIntent(),
  EditorShortcutAction.stepFrameBackward: StepFrameBackwardIntent(),
  EditorShortcutAction.stepFrameForward: StepFrameForwardIntent(),
  EditorShortcutAction.stepTenFramesBackward: StepTenFramesBackwardIntent(),
  EditorShortcutAction.stepTenFramesForward: StepTenFramesForwardIntent(),
  EditorShortcutAction.goToStart: GoToStartIntent(),
  EditorShortcutAction.goToEnd: GoToEndIntent(),
  EditorShortcutAction.deleteSelectedClips: DeleteSelectedClipsIntent(),
  EditorShortcutAction.undo: EditorUndoIntent(),
  EditorShortcutAction.redo: EditorRedoIntent(),
  EditorShortcutAction.selectAll: SelectAllClipsIntent(),
  EditorShortcutAction.deselectAll: DeselectAllIntent(),
  EditorShortcutAction.zoomIn: ZoomInTimelineIntent(),
  EditorShortcutAction.zoomOut: ZoomOutTimelineIntent(),
  EditorShortcutAction.saveProject: SaveProjectIntent(),
};
