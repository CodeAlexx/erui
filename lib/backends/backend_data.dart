import 'abstract_backend.dart';
import 'backend_type.dart';

/// Wrapper for backend instance with metadata
class BackendData {
  /// Unique backend ID
  final int id;

  /// Display title
  String title;

  /// Backend type info
  final BackendType type;

  /// The actual backend instance
  final AbstractBackend backend;

  /// Whether this backend is enabled
  bool enabled;

  /// Currently loaded model name
  String? currentModelName;

  /// Number of current claims on this backend
  int _claimCount = 0;

  /// Total number of times this backend has been used
  int usageCount = 0;

  /// Extra data
  final Map<String, dynamic> extraData = {};

  BackendData({
    required this.id,
    required this.title,
    required this.type,
    required this.backend,
    this.enabled = true,
    this.currentModelName,
  });

  /// Whether this backend is currently in use
  bool get isInUse => _claimCount > 0;

  /// Claim this backend
  void claim() {
    _claimCount++;
    usageCount++;
  }

  /// Release claim on this backend
  void release() {
    if (_claimCount > 0) {
      _claimCount--;
    }
  }

  /// Get current claim count
  int get claimCount => _claimCount;

  /// Get backend status
  BackendStatus get status => backend.status;

  /// Get backend info for API
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.id,
        'type_name': type.name,
        'enabled': enabled,
        'status': backend.status.name,
        'current_model': currentModelName,
        'is_in_use': isInUse,
        'claim_count': _claimCount,
        'usage_count': usageCount,
      };

  @override
  String toString() => 'BackendData($id: $title, ${backend.status})';
}
