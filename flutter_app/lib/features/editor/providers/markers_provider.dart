import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_models.dart';
import '../models/marker_models.dart';
import 'editor_provider.dart';

/// State for project markers
class MarkersState {
  /// Collection of all markers
  final MarkerCollection collection;

  /// Currently selected marker ID
  final EditorId? selectedMarkerId;

  /// Whether marker editing is enabled
  final bool isEditing;

  const MarkersState({
    this.collection = const MarkerCollection(),
    this.selectedMarkerId,
    this.isEditing = false,
  });

  MarkersState copyWith({
    MarkerCollection? collection,
    EditorId? selectedMarkerId,
    bool? isEditing,
  }) {
    return MarkersState(
      collection: collection ?? this.collection,
      selectedMarkerId: selectedMarkerId ?? this.selectedMarkerId,
      isEditing: isEditing ?? this.isEditing,
    );
  }

  /// Get sorted markers
  List<Marker> get sortedMarkers => collection.sortedMarkers;

  /// Get selected marker
  Marker? get selectedMarker => selectedMarkerId != null
      ? collection.findById(selectedMarkerId!)
      : null;
}

/// Notifier for markers state
class MarkersNotifier extends StateNotifier<MarkersState> {
  final Ref _ref;

  MarkersNotifier(this._ref) : super(const MarkersState());

  /// Add a marker at the current playhead position
  void addMarkerAtPlayhead({
    required String label,
    MarkerType type = MarkerType.comment,
    Color? color,
    String? description,
  }) {
    final editorState = _ref.read(editorProjectProvider);
    final timestamp = editorState.project.playheadPosition;

    final marker = Marker.create(
      timestamp: timestamp,
      label: label,
      type: type,
      color: color,
      description: description,
    );

    state = state.copyWith(
      collection: state.collection.addMarker(marker),
      selectedMarkerId: marker.id,
    );
  }

  /// Add a marker at a specific time
  void addMarker(Marker marker) {
    state = state.copyWith(
      collection: state.collection.addMarker(marker),
    );
  }

  /// Remove a marker
  void removeMarker(EditorId markerId) {
    state = state.copyWith(
      collection: state.collection.removeMarker(markerId),
      selectedMarkerId:
          state.selectedMarkerId == markerId ? null : state.selectedMarkerId,
    );
  }

  /// Update a marker
  void updateMarker(Marker marker) {
    state = state.copyWith(
      collection: state.collection.updateMarker(marker),
    );
  }

  /// Move marker to a new time
  void moveMarker(EditorId markerId, EditorTime newTime) {
    final marker = state.collection.findById(markerId);
    if (marker == null || marker.isLocked) return;

    state = state.copyWith(
      collection: state.collection.updateMarker(
        marker.copyWith(timestamp: newTime),
      ),
    );
  }

  /// Select a marker
  void selectMarker(EditorId? markerId) {
    state = state.copyWith(selectedMarkerId: markerId);
  }

  /// Navigate to next marker
  void goToNextMarker() {
    final editorState = _ref.read(editorProjectProvider);
    final currentTime = editorState.project.playheadPosition;
    final nextMarker = state.collection.nextAfter(currentTime);

    if (nextMarker != null) {
      _ref.read(editorProjectProvider.notifier).setPlayhead(nextMarker.timestamp);
      state = state.copyWith(selectedMarkerId: nextMarker.id);
    }
  }

  /// Navigate to previous marker
  void goToPreviousMarker() {
    final editorState = _ref.read(editorProjectProvider);
    final currentTime = editorState.project.playheadPosition;
    final prevMarker = state.collection.prevBefore(currentTime);

    if (prevMarker != null) {
      _ref.read(editorProjectProvider.notifier).setPlayhead(prevMarker.timestamp);
      state = state.copyWith(selectedMarkerId: prevMarker.id);
    }
  }

  /// Navigate to a specific marker
  void goToMarker(EditorId markerId) {
    final marker = state.collection.findById(markerId);
    if (marker != null) {
      _ref.read(editorProjectProvider.notifier).setPlayhead(marker.timestamp);
      state = state.copyWith(selectedMarkerId: markerId);
    }
  }

  /// Toggle marker lock state
  void toggleMarkerLock(EditorId markerId) {
    final marker = state.collection.findById(markerId);
    if (marker != null) {
      state = state.copyWith(
        collection: state.collection.updateMarker(
          marker.copyWith(isLocked: !marker.isLocked),
        ),
      );
    }
  }

  /// Clear all markers
  void clearAllMarkers() {
    state = const MarkersState();
  }

  /// Get markers of a specific type
  List<Marker> getMarkersByType(MarkerType type) {
    return state.collection.byType(type);
  }

  /// Get markers in a time range
  List<Marker> getMarkersInRange(EditorTimeRange range) {
    return state.collection.inRange(range);
  }

  /// Import markers from a file (EDL, XML, etc.)
  Future<void> importMarkers(String filePath) async {
    // TODO: Implement marker import
  }

  /// Export markers to a file
  Future<void> exportMarkers(String filePath) async {
    // TODO: Implement marker export
  }
}

/// Provider for markers state
final markersProvider =
    StateNotifierProvider<MarkersNotifier, MarkersState>((ref) {
  return MarkersNotifier(ref);
});

/// Provider for sorted markers list
final sortedMarkersProvider = Provider<List<Marker>>((ref) {
  return ref.watch(markersProvider).sortedMarkers;
});

/// Provider for selected marker
final selectedMarkerProvider = Provider<Marker?>((ref) {
  return ref.watch(markersProvider).selectedMarker;
});

/// Provider for markers of a specific type
final markersByTypeProvider =
    Provider.family<List<Marker>, MarkerType>((ref, type) {
  return ref.watch(markersProvider).collection.byType(type);
});
