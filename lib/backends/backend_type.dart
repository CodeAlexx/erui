import 'abstract_backend.dart';

/// Definition of a backend type
class BackendType {
  /// Unique identifier
  final String id;

  /// Display name
  final String name;

  /// Description
  final String description;

  /// Factory function to create backend instances
  final AbstractBackend Function(Map<String, dynamic> settings) factory;

  /// Settings class type for validation
  final Type? settingsClass;

  /// Whether this backend type supports auto-scaling
  final bool supportsAutoScaling;

  /// Whether this type can self-start (launch a process)
  final bool canSelfStart;

  BackendType({
    required this.id,
    required this.name,
    required this.description,
    required this.factory,
    this.settingsClass,
    this.supportsAutoScaling = false,
    this.canSelfStart = false,
  });

  /// Get info for API
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'supports_auto_scaling': supportsAutoScaling,
        'can_self_start': canSelfStart,
      };

  @override
  String toString() => 'BackendType($id)';
}
