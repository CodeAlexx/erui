import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/editor_models.dart';

/// Base class for all editor commands implementing the Command Pattern.
/// Commands are immutable and store both old and new values for undo/redo.
abstract class EditorCommand {
  /// Display name for the command (shown in Edit menu)
  String get name;

  /// Execute the command (apply changes)
  void execute();

  /// Undo the command (revert changes)
  void undo();
}

/// State for the undo system
class UndoState {
  final List<EditorCommand> undoStack;
  final List<EditorCommand> redoStack;
  final int maxHistory;

  const UndoState({
    this.undoStack = const [],
    this.redoStack = const [],
    this.maxHistory = 100,
  });

  UndoState copyWith({
    List<EditorCommand>? undoStack,
    List<EditorCommand>? redoStack,
    int? maxHistory,
  }) {
    return UndoState(
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      maxHistory: maxHistory ?? this.maxHistory,
    );
  }
}

/// Notifier for managing editor project state
/// This should be provided by the main editor and passed to commands
abstract class EditorProjectNotifier extends StateNotifier<EditorProject> {
  EditorProjectNotifier(super.state);

  /// Update the entire project state
  void updateProject(EditorProject project);

  /// Find and update a specific clip
  void updateClip(EditorId clipId, EditorClip Function(EditorClip) updater);

  /// Add a clip to a track
  void addClip(EditorId trackId, EditorClip clip);

  /// Remove a clip from the project
  void removeClip(EditorId clipId);

  /// Add a track to the project
  void addTrack(Track track, {int? index});

  /// Remove a track from the project
  void removeTrack(EditorId trackId);

  /// Get current project state
  EditorProject get project => state;
}

/// Command to move a clip to a new position
class MoveClipCommand implements EditorCommand {
  @override
  final String name;

  final EditorProjectNotifier notifier;
  final EditorId clipId;
  final EditorTime oldStart;
  final EditorTime newStart;
  final int oldTrackIndex;
  final int newTrackIndex;

  MoveClipCommand({
    required this.notifier,
    required this.clipId,
    required this.oldStart,
    required this.newStart,
    required this.oldTrackIndex,
    required this.newTrackIndex,
    String? name,
  }) : name = name ?? 'Move Clip';

  @override
  void execute() {
    notifier.updateClip(clipId, (clip) {
      return clip.copyWith(
        timelineStart: newStart,
        trackIndex: newTrackIndex,
      );
    });
  }

  @override
  void undo() {
    notifier.updateClip(clipId, (clip) {
      return clip.copyWith(
        timelineStart: oldStart,
        trackIndex: oldTrackIndex,
      );
    });
  }
}

/// Command to resize a clip (change duration and/or source start)
class ResizeClipCommand implements EditorCommand {
  @override
  final String name;

  final EditorProjectNotifier notifier;
  final EditorId clipId;
  final EditorTime oldTimelineStart;
  final EditorTime newTimelineStart;
  final EditorTime oldDuration;
  final EditorTime newDuration;
  final EditorTime oldSourceStart;
  final EditorTime newSourceStart;

  ResizeClipCommand({
    required this.notifier,
    required this.clipId,
    required this.oldTimelineStart,
    required this.newTimelineStart,
    required this.oldDuration,
    required this.newDuration,
    required this.oldSourceStart,
    required this.newSourceStart,
    String? name,
  }) : name = name ?? 'Resize Clip';

  @override
  void execute() {
    notifier.updateClip(clipId, (clip) {
      return clip.copyWith(
        timelineStart: newTimelineStart,
        duration: newDuration,
        sourceStart: newSourceStart,
      );
    });
  }

  @override
  void undo() {
    notifier.updateClip(clipId, (clip) {
      return clip.copyWith(
        timelineStart: oldTimelineStart,
        duration: oldDuration,
        sourceStart: oldSourceStart,
      );
    });
  }
}

/// Command to delete a clip
class DeleteClipCommand implements EditorCommand {
  @override
  final String name;

  final EditorProjectNotifier notifier;
  final EditorId clipId;
  final EditorId trackId;
  final EditorClip deletedClip;

  DeleteClipCommand({
    required this.notifier,
    required this.clipId,
    required this.trackId,
    required this.deletedClip,
    String? name,
  }) : name = name ?? 'Delete Clip';

  @override
  void execute() {
    notifier.removeClip(clipId);
  }

  @override
  void undo() {
    notifier.addClip(trackId, deletedClip);
  }
}

/// Command to add a clip
class AddClipCommand implements EditorCommand {
  @override
  final String name;

  final EditorProjectNotifier notifier;
  final EditorId trackId;
  final EditorClip clip;

  AddClipCommand({
    required this.notifier,
    required this.trackId,
    required this.clip,
    String? name,
  }) : name = name ?? 'Add Clip';

  @override
  void execute() {
    notifier.addClip(trackId, clip);
  }

  @override
  void undo() {
    notifier.removeClip(clip.id);
  }
}

/// Command to add a track
class AddTrackCommand implements EditorCommand {
  @override
  final String name;

  final EditorProjectNotifier notifier;
  final Track track;
  final int? insertIndex;

  AddTrackCommand({
    required this.notifier,
    required this.track,
    this.insertIndex,
    String? name,
  }) : name = name ?? 'Add Track';

  @override
  void execute() {
    notifier.addTrack(track, index: insertIndex);
  }

  @override
  void undo() {
    notifier.removeTrack(track.id);
  }
}

/// Command to delete a track
class DeleteTrackCommand implements EditorCommand {
  @override
  final String name;

  final EditorProjectNotifier notifier;
  final EditorId trackId;
  final Track deletedTrack;
  final int originalIndex;

  DeleteTrackCommand({
    required this.notifier,
    required this.trackId,
    required this.deletedTrack,
    required this.originalIndex,
    String? name,
  }) : name = name ?? 'Delete Track';

  @override
  void execute() {
    notifier.removeTrack(trackId);
  }

  @override
  void undo() {
    notifier.addTrack(deletedTrack, index: originalIndex);
  }
}

/// Generic command for changing any clip property
class ChangeClipPropertyCommand<T> implements EditorCommand {
  @override
  final String name;

  final EditorProjectNotifier notifier;
  final EditorId clipId;
  final T oldValue;
  final T newValue;
  final EditorClip Function(EditorClip clip, T value) applyValue;

  ChangeClipPropertyCommand({
    required this.notifier,
    required this.clipId,
    required this.oldValue,
    required this.newValue,
    required this.applyValue,
    required this.name,
  });

  @override
  void execute() {
    notifier.updateClip(clipId, (clip) => applyValue(clip, newValue));
  }

  @override
  void undo() {
    notifier.updateClip(clipId, (clip) => applyValue(clip, oldValue));
  }
}

/// Command that groups multiple commands into a single undoable operation
class CompositeCommand implements EditorCommand {
  @override
  final String name;

  final List<EditorCommand> commands;

  CompositeCommand({
    required this.commands,
    required this.name,
  });

  @override
  void execute() {
    for (final command in commands) {
      command.execute();
    }
  }

  @override
  void undo() {
    // Undo in reverse order
    for (int i = commands.length - 1; i >= 0; i--) {
      commands[i].undo();
    }
  }
}

/// The main undo system that manages command history
class UndoSystem extends StateNotifier<UndoState> {
  UndoSystem({int maxHistory = 100})
      : super(UndoState(maxHistory: maxHistory));

  /// Execute a command and add it to the undo history
  void execute(EditorCommand command) {
    // Execute the command
    command.execute();

    // Add to undo stack
    List<EditorCommand> newUndoStack = [...state.undoStack, command];

    // Enforce max history limit
    if (newUndoStack.length > state.maxHistory) {
      newUndoStack = newUndoStack.sublist(newUndoStack.length - state.maxHistory);
    }

    // Clear redo stack when new command is executed
    state = state.copyWith(
      undoStack: newUndoStack,
      redoStack: [],
    );
  }

  /// Undo the last command
  void undo() {
    if (!canUndo) return;

    final command = state.undoStack.last;
    command.undo();

    state = state.copyWith(
      undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
      redoStack: [...state.redoStack, command],
    );
  }

  /// Redo the last undone command
  void redo() {
    if (!canRedo) return;

    final command = state.redoStack.last;
    command.execute();

    state = state.copyWith(
      undoStack: [...state.undoStack, command],
      redoStack: state.redoStack.sublist(0, state.redoStack.length - 1),
    );
  }

  /// Clear all history
  void clear() {
    state = state.copyWith(
      undoStack: [],
      redoStack: [],
    );
  }

  /// Whether there are commands to undo
  bool get canUndo => state.undoStack.isNotEmpty;

  /// Whether there are commands to redo
  bool get canRedo => state.redoStack.isNotEmpty;

  /// Get list of command names in undo history (most recent last)
  List<String> get undoHistory =>
      state.undoStack.map((c) => c.name).toList();

  /// Get list of command names in redo history (most recent last)
  List<String> get redoHistory =>
      state.redoStack.map((c) => c.name).toList();

  /// Set the maximum history limit
  void setMaxHistory(int maxHistory) {
    List<EditorCommand> newUndoStack = state.undoStack;
    if (newUndoStack.length > maxHistory) {
      newUndoStack = newUndoStack.sublist(newUndoStack.length - maxHistory);
    }
    state = state.copyWith(
      maxHistory: maxHistory,
      undoStack: newUndoStack,
    );
  }
}

/// Riverpod provider for the undo system
final undoSystemProvider =
    StateNotifierProvider<UndoSystem, UndoState>((ref) {
  return UndoSystem();
});

/// Convenience provider to check if undo is available
final canUndoProvider = Provider<bool>((ref) {
  return ref.watch(undoSystemProvider).undoStack.isNotEmpty;
});

/// Convenience provider to check if redo is available
final canRedoProvider = Provider<bool>((ref) {
  return ref.watch(undoSystemProvider).redoStack.isNotEmpty;
});

/// Provider for undo history names
final undoHistoryProvider = Provider<List<String>>((ref) {
  return ref.watch(undoSystemProvider).undoStack.map((c) => c.name).toList();
});

/// Provider for redo history names
final redoHistoryProvider = Provider<List<String>>((ref) {
  return ref.watch(undoSystemProvider).redoStack.map((c) => c.name).toList();
});
