import 'dart:ui';
import 'editor_models.dart';

/// Types of timeline markers
enum MarkerType {
  /// General comment marker
  comment,

  /// Chapter/section marker for navigation
  chapter,

  /// Todo/task marker
  todo,

  /// Sync point for multi-camera editing
  sync,

  /// Edit point marker
  edit,

  /// Cue point for external triggers
  cue,
}

/// A marker on the timeline
class Marker {
  final EditorId id;
  final EditorTime timestamp;
  final EditorTime? duration; // null = point marker, non-null = range marker
  final String label;
  final String? description;
  final Color color;
  final MarkerType type;
  final bool isLocked;
  final Map<String, dynamic>? metadata;

  const Marker({
    required this.id,
    required this.timestamp,
    this.duration,
    required this.label,
    this.description,
    required this.color,
    this.type = MarkerType.comment,
    this.isLocked = false,
    this.metadata,
  });

  factory Marker.create({
    required EditorTime timestamp,
    required String label,
    MarkerType type = MarkerType.comment,
    Color? color,
    EditorTime? duration,
    String? description,
  }) {
    return Marker(
      id: generateId(),
      timestamp: timestamp,
      duration: duration,
      label: label,
      description: description,
      color: color ?? _defaultColorForType(type),
      type: type,
    );
  }

  static Color _defaultColorForType(MarkerType type) {
    switch (type) {
      case MarkerType.comment:
        return const Color(0xFF42A5F5); // Blue
      case MarkerType.chapter:
        return const Color(0xFF66BB6A); // Green
      case MarkerType.todo:
        return const Color(0xFFFFCA28); // Yellow
      case MarkerType.sync:
        return const Color(0xFFAB47BC); // Purple
      case MarkerType.edit:
        return const Color(0xFFEF5350); // Red
      case MarkerType.cue:
        return const Color(0xFFFF7043); // Orange
    }
  }

  /// Whether this is a range marker (has duration)
  bool get isRange => duration != null && duration!.microseconds > 0;

  /// End time for range markers
  EditorTime get endTime => isRange ? timestamp + duration! : timestamp;

  /// Time range for range markers
  EditorTimeRange get timeRange => EditorTimeRange(timestamp, endTime);

  Marker copyWith({
    EditorId? id,
    EditorTime? timestamp,
    EditorTime? duration,
    String? label,
    String? description,
    Color? color,
    MarkerType? type,
    bool? isLocked,
    Map<String, dynamic>? metadata,
  }) {
    return Marker(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      label: label ?? this.label,
      description: description ?? this.description,
      color: color ?? this.color,
      type: type ?? this.type,
      isLocked: isLocked ?? this.isLocked,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Marker && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Marker(id: $id, label: $label, timestamp: $timestamp, type: $type)';
  }
}

/// Extension for MarkerType utilities
extension MarkerTypeExtension on MarkerType {
  String get displayName {
    switch (this) {
      case MarkerType.comment:
        return 'Comment';
      case MarkerType.chapter:
        return 'Chapter';
      case MarkerType.todo:
        return 'To-Do';
      case MarkerType.sync:
        return 'Sync Point';
      case MarkerType.edit:
        return 'Edit Point';
      case MarkerType.cue:
        return 'Cue Point';
    }
  }

  String get iconName {
    switch (this) {
      case MarkerType.comment:
        return 'comment';
      case MarkerType.chapter:
        return 'bookmark';
      case MarkerType.todo:
        return 'check_box';
      case MarkerType.sync:
        return 'sync';
      case MarkerType.edit:
        return 'edit';
      case MarkerType.cue:
        return 'flag';
    }
  }
}

/// Collection of markers for a project
class MarkerCollection {
  final List<Marker> markers;

  const MarkerCollection({this.markers = const []});

  /// Get markers sorted by timestamp
  List<Marker> get sortedMarkers => List.from(markers)
    ..sort((a, b) => a.timestamp.microseconds.compareTo(b.timestamp.microseconds));

  /// Get markers of a specific type
  List<Marker> byType(MarkerType type) =>
      markers.where((m) => m.type == type).toList();

  /// Get markers within a time range
  List<Marker> inRange(EditorTimeRange range) =>
      markers.where((m) => range.contains(m.timestamp)).toList();

  /// Find the next marker after a given time
  Marker? nextAfter(EditorTime time) {
    final sorted = sortedMarkers;
    for (final marker in sorted) {
      if (marker.timestamp > time) return marker;
    }
    return null;
  }

  /// Find the previous marker before a given time
  Marker? prevBefore(EditorTime time) {
    final sorted = sortedMarkers.reversed.toList();
    for (final marker in sorted) {
      if (marker.timestamp < time) return marker;
    }
    return null;
  }

  /// Find marker by ID
  Marker? findById(EditorId id) {
    for (final marker in markers) {
      if (marker.id == id) return marker;
    }
    return null;
  }

  MarkerCollection copyWith({List<Marker>? markers}) {
    return MarkerCollection(markers: markers ?? List.from(this.markers));
  }

  /// Add a marker
  MarkerCollection addMarker(Marker marker) {
    return copyWith(markers: [...markers, marker]);
  }

  /// Remove a marker by ID
  MarkerCollection removeMarker(EditorId markerId) {
    return copyWith(
      markers: markers.where((m) => m.id != markerId).toList(),
    );
  }

  /// Update a marker
  MarkerCollection updateMarker(Marker updated) {
    return copyWith(
      markers: markers.map((m) => m.id == updated.id ? updated : m).toList(),
    );
  }
}
