import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/text_clip_models.dart';

/// State for text clips
class TextClipsState {
  /// All text clips in the project
  final List<TextClip> clips;

  /// Currently selected text clip ID
  final EditorId? selectedClipId;

  /// Available title templates
  final List<TitleTemplate> templates;

  /// Text editing mode active
  final bool isEditing;

  const TextClipsState({
    this.clips = const [],
    this.selectedClipId,
    this.templates = const [],
    this.isEditing = false,
  });

  TextClipsState copyWith({
    List<TextClip>? clips,
    EditorId? selectedClipId,
    List<TitleTemplate>? templates,
    bool? isEditing,
  }) {
    return TextClipsState(
      clips: clips ?? this.clips,
      selectedClipId: selectedClipId ?? this.selectedClipId,
      templates: templates ?? this.templates,
      isEditing: isEditing ?? this.isEditing,
    );
  }

  /// Get selected clip
  TextClip? get selectedClip {
    if (selectedClipId == null) return null;
    for (final clip in clips) {
      if (clip.id == selectedClipId) return clip;
    }
    return null;
  }
}

/// Provider for text clips
final textClipsProvider =
    StateNotifierProvider<TextClipsNotifier, TextClipsState>((ref) {
  return TextClipsNotifier();
});

/// Notifier for text clips state
class TextClipsNotifier extends StateNotifier<TextClipsState> {
  TextClipsNotifier()
      : super(TextClipsState(
          templates: TitleTemplates.builtIn,
        ));

  /// Add a new text clip
  void addClip(TextClip clip) {
    state = state.copyWith(
      clips: [...state.clips, clip],
      selectedClipId: clip.id,
    );
  }

  /// Create and add a text clip from template
  TextClip addFromTemplate({
    required String templateId,
    required String text,
    required EditorTime startTime,
    required EditorTime duration,
    int trackIndex = 0,
  }) {
    final template = state.templates.firstWhere(
      (t) => t.id == templateId,
      orElse: () => TitleTemplates.builtIn.first,
    );

    final clip = template.createClip(
      text: text,
      timelineStart: startTime,
      duration: duration,
    ).copyWith(trackIndex: trackIndex) as TextClip;

    addClip(clip);
    return clip;
  }

  /// Create a simple text clip
  TextClip addSimpleText({
    required String text,
    required EditorTime startTime,
    required EditorTime duration,
    Offset position = const Offset(0.5, 0.5),
    TextClipStyle style = const TextClipStyle(),
    int trackIndex = 0,
  }) {
    final clip = TextClip(
      name: text.length > 20 ? '${text.substring(0, 20)}...' : text,
      timelineStart: startTime,
      duration: duration,
      text: text,
      style: style,
      position: position,
      trackIndex: trackIndex,
    );

    addClip(clip);
    return clip;
  }

  /// Remove a text clip
  void removeClip(EditorId clipId) {
    state = state.copyWith(
      clips: state.clips.where((c) => c.id != clipId).toList(),
      selectedClipId:
          state.selectedClipId == clipId ? null : state.selectedClipId,
    );
  }

  /// Update a text clip
  void updateClip(TextClip clip) {
    state = state.copyWith(
      clips: state.clips.map((c) => c.id == clip.id ? clip : c).toList(),
    );
  }

  /// Select a text clip
  void selectClip(EditorId? clipId) {
    state = state.copyWith(selectedClipId: clipId);
  }

  /// Update text content
  void updateText(EditorId clipId, String text) {
    final clip = state.clips.firstWhere((c) => c.id == clipId);
    updateClip(clip.copyWith(text: text) as TextClip);
  }

  /// Update text style
  void updateStyle(EditorId clipId, TextClipStyle style) {
    final clip = state.clips.firstWhere((c) => c.id == clipId);
    updateClip(clip.copyWith(style: style) as TextClip);
  }

  /// Update text position
  void updatePosition(EditorId clipId, Offset position) {
    final clip = state.clips.firstWhere((c) => c.id == clipId);
    updateClip(clip.copyWith(position: position) as TextClip);
  }

  /// Update text animation
  void updateAnimation(EditorId clipId, TextAnimation? animation) {
    final clip = state.clips.firstWhere((c) => c.id == clipId);
    updateClip(clip.copyWith(animation: animation) as TextClip);
  }

  /// Update text background
  void updateBackground(EditorId clipId, TextBackground? background) {
    final clip = state.clips.firstWhere((c) => c.id == clipId);
    updateClip(clip.copyWith(background: background) as TextClip);
  }

  /// Toggle editing mode
  void setEditing(bool editing) {
    state = state.copyWith(isEditing: editing);
  }

  /// Move clip to new time
  void moveClip(EditorId clipId, EditorTime newStart) {
    final clip = state.clips.firstWhere((c) => c.id == clipId);
    updateClip(clip.copyWith(timelineStart: newStart) as TextClip);
  }

  /// Change clip duration
  void resizeClip(EditorId clipId, EditorTime newDuration) {
    final clip = state.clips.firstWhere((c) => c.id == clipId);
    updateClip(clip.copyWith(duration: newDuration) as TextClip);
  }

  /// Duplicate a text clip
  TextClip duplicateClip(EditorId clipId, {EditorTime? offset}) {
    final original = state.clips.firstWhere((c) => c.id == clipId);
    final newClip = TextClip(
      name: '${original.name} (copy)',
      timelineStart: offset != null
          ? original.timelineStart + offset
          : original.timelineEnd,
      duration: original.duration,
      text: original.text,
      style: original.style,
      position: original.position,
      animation: original.animation,
      background: original.background,
      trackIndex: original.trackIndex,
    );

    addClip(newClip);
    return newClip;
  }

  /// Add a custom template
  void addTemplate(TitleTemplate template) {
    state = state.copyWith(
      templates: [...state.templates, template],
    );
  }

  /// Get clips at a specific time
  List<TextClip> clipsAt(EditorTime time) {
    return state.clips
        .where((c) => time >= c.timelineStart && time < c.timelineEnd)
        .toList();
  }
}

/// Provider for selected text clip
final selectedTextClipProvider = Provider<TextClip?>((ref) {
  return ref.watch(textClipsProvider).selectedClip;
});

/// Provider for text clips on a specific track
final textClipsOnTrackProvider =
    Provider.family<List<TextClip>, int>((ref, trackIndex) {
  return ref.watch(textClipsProvider).clips
      .where((c) => c.trackIndex == trackIndex)
      .toList();
});

/// Provider for available title templates
final titleTemplatesProvider = Provider<List<TitleTemplate>>((ref) {
  return ref.watch(textClipsProvider).templates;
});

/// Provider for text editing mode
final textEditingModeProvider = Provider<bool>((ref) {
  return ref.watch(textClipsProvider).isEditing;
});
