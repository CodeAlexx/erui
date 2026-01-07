import 'package:uuid/uuid.dart';
import '../core/events.dart';
import 'user.dart';
import 'gen_claim.dart';

/// Active user session with generation state tracking
/// Equivalent to SwarmUI's Session class
class Session {
  /// Unique 40-character session ID
  final String id;

  /// Owning user
  final User user;

  /// Source IP address
  final String originAddress;

  /// API token that created this session (null for browser sessions)
  final String? originToken;

  /// Whether session survives restarts
  final bool persist;

  /// Cancellation for all generation claims in this session
  CancellationTokenSource sessInterrupt = CancellationTokenSource();

  /// All active generation claims
  final Map<int, GenClaim> claims = {};

  /// Last activity timestamp (milliseconds since epoch)
  int _lastUsedTime = DateTime.now().millisecondsSinceEpoch;

  // ========== GENERATION STATE COUNTERS ==========

  /// Queued but not-yet-running generations
  int waitingGenerations = 0;

  /// Waiting for model loading
  int loadingModels = 0;

  /// Waiting for backend availability
  int waitingBackends = 0;

  /// Actively running generations
  int liveGens = 0;

  /// Extra metadata attached to this session
  final Map<String, dynamic> extraData = {};

  Session({
    String? id,
    required this.user,
    required this.originAddress,
    this.originToken,
    this.persist = true,
  }) : id = id ?? _generateId();

  /// Generate a 40-character hex session ID
  static String _generateId() {
    const uuid = Uuid();
    // Generate 40-char hex string like SwarmUI
    final base = uuid.v4() + uuid.v4();
    return base.replaceAll('-', '').substring(0, 40);
  }

  /// Update last used time
  void updateLastUsedTime() {
    _lastUsedTime = DateTime.now().millisecondsSinceEpoch;
    user.updateLastUsedTime();
  }

  /// Get last used time
  int get lastUsedTime => _lastUsedTime;

  /// Time since last activity
  Duration get timeSinceLastUsed =>
      Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - _lastUsedTime);

  /// Total number of pending operations
  int get totalPending => waitingGenerations + loadingModels + waitingBackends + liveGens;

  /// Create a generation claim
  GenClaim claim({
    int gens = 0,
    int modelLoads = 0,
    int backendWaits = 0,
    int liveGens = 0,
  }) {
    final claim = GenClaim(
      session: this,
      waitingGenerations: gens,
      loadingModels: modelLoads,
      waitingBackends: backendWaits,
      liveGens: liveGens,
    );
    claims[claim.id] = claim;
    return claim;
  }

  /// Cancel all ongoing generations
  void interrupt() {
    sessInterrupt.cancel();
    sessInterrupt = CancellationTokenSource();
  }

  /// Check if user has a specific permission
  bool hasPermission(String permission) => user.hasPermission(permission);

  /// Convert to database entry for persistence
  SessionDatabaseEntry toDbEntry() => SessionDatabaseEntry(
        id: id,
        userId: user.id,
        lastActiveUnixTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        originAddress: originAddress,
        originToken: originToken,
      );

  @override
  String toString() => 'Session($id, user: ${user.id})';
}

/// Database entry for session persistence
class SessionDatabaseEntry {
  final String id;
  final String userId;
  final int lastActiveUnixTime;
  final String originAddress;
  final String? originToken;

  SessionDatabaseEntry({
    required this.id,
    required this.userId,
    required this.lastActiveUnixTime,
    required this.originAddress,
    this.originToken,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'lastActiveUnixTime': lastActiveUnixTime,
        'originAddress': originAddress,
        'originToken': originToken,
      };

  factory SessionDatabaseEntry.fromJson(Map<String, dynamic> json) =>
      SessionDatabaseEntry(
        id: json['id'] as String,
        userId: json['userId'] as String,
        lastActiveUnixTime: json['lastActiveUnixTime'] as int,
        originAddress: json['originAddress'] as String,
        originToken: json['originToken'] as String?,
      );

  /// Check if entry has expired
  bool isExpired(Duration maxAge) {
    final expireTime = DateTime.fromMillisecondsSinceEpoch(lastActiveUnixTime * 1000)
        .add(maxAge);
    return DateTime.now().isAfter(expireTime);
  }
}
