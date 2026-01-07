import 'dart:async';

/// Abstract base class for all backends
/// Equivalent to SwarmUI's AbstractT2IBackend
abstract class AbstractBackend {
  /// Current status
  BackendStatus status = BackendStatus.disabled;

  /// Backend-specific settings
  final Map<String, dynamic> settings;

  /// Error message if status is errored
  String? errorMessage;

  AbstractBackend(this.settings);

  /// Initialize the backend
  Future<void> init();

  /// Shutdown the backend
  Future<void> shutdown();

  /// Load a model
  Future<void> loadModel(String modelName);

  /// Unload current model
  Future<void> unloadModel();

  /// Interrupt current operation
  Future<void> interrupt();

  /// Get current settings
  Map<String, dynamic> getSettings() => Map.from(settings);

  /// Check if backend is available
  bool get isAvailable =>
      status == BackendStatus.running || status == BackendStatus.idle;

  /// Check if backend is busy
  bool get isBusy => status == BackendStatus.loading || status == BackendStatus.running;
}

/// Backend status enum
enum BackendStatus {
  /// Backend is disabled
  disabled,

  /// Backend is initializing
  initializing,

  /// Backend is idle (ready but not generating)
  idle,

  /// Backend is loading a model
  loading,

  /// Backend is running (generating)
  running,

  /// Backend has errored
  errored,

  /// Backend is shutting down
  shuttingDown,
}

/// Extension methods for BackendStatus
extension BackendStatusExtension on BackendStatus {
  /// Whether this status indicates the backend is usable
  bool get isUsable => this == BackendStatus.running || this == BackendStatus.idle;

  /// Whether this status indicates the backend is busy
  bool get isBusy => this == BackendStatus.loading || this == BackendStatus.running;

  /// Human-readable name
  String get displayName {
    switch (this) {
      case BackendStatus.disabled:
        return 'Disabled';
      case BackendStatus.initializing:
        return 'Initializing';
      case BackendStatus.idle:
        return 'Idle';
      case BackendStatus.loading:
        return 'Loading';
      case BackendStatus.running:
        return 'Running';
      case BackendStatus.errored:
        return 'Error';
      case BackendStatus.shuttingDown:
        return 'Shutting Down';
    }
  }
}
