import 'role.dart';

/// User model - equivalent to SwarmUI's User class
class User {
  /// Unique user ID
  final String id;

  /// User's display name
  String displayName;

  /// User's role
  Role role;

  /// Password hash (null for local users)
  String? passwordHash;

  /// API keys for this user
  final Map<String, APIKey> apiKeys = {};

  /// Currently active sessions for this user
  final Map<String, dynamic> currentSessions = {};

  /// User-specific settings (overrides defaults)
  Map<String, dynamic> settings = {};

  /// Last activity timestamp
  int _lastUsedTime = DateTime.now().millisecondsSinceEpoch;

  /// Maximum simultaneous T2I generations
  int maxT2ISimultaneous = 1;

  /// Maximum image history storage in MB
  int maxImageHistoryMB = 1000;

  /// Maximum output directory storage in MB
  int maxOutpathMB = 10000;

  /// Whether user can create sessions
  bool mayCreateSessions = true;

  /// Timestamp when user was created
  final int createdTime;

  User({
    required this.id,
    String? displayName,
    required this.role,
    this.passwordHash,
    this.maxT2ISimultaneous = 1,
    this.maxImageHistoryMB = 1000,
    this.maxOutpathMB = 10000,
    this.mayCreateSessions = true,
    int? createdTime,
  })  : displayName = displayName ?? id,
        createdTime = createdTime ?? DateTime.now().millisecondsSinceEpoch;

  /// Update last used time
  void updateLastUsedTime() {
    _lastUsedTime = DateTime.now().millisecondsSinceEpoch;
  }

  /// Time since last activity
  Duration get timeSinceLastUsed =>
      Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - _lastUsedTime);

  /// Check if user has a specific permission
  bool hasPermission(String permission) {
    return role.hasPermission(permission);
  }

  /// Get a user setting with default fallback
  T getSetting<T>(String key, T defaultValue) {
    if (settings.containsKey(key)) {
      final value = settings[key];
      if (value is T) return value;
    }
    return defaultValue;
  }

  /// Set a user setting
  void setSetting(String key, dynamic value) {
    settings[key] = value;
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'role': role.name,
        'passwordHash': passwordHash,
        'maxT2ISimultaneous': maxT2ISimultaneous,
        'maxImageHistoryMB': maxImageHistoryMB,
        'maxOutpathMB': maxOutpathMB,
        'mayCreateSessions': mayCreateSessions,
        'createdTime': createdTime,
        'lastUsedTime': _lastUsedTime,
        'settings': settings,
        'apiKeys': apiKeys.map((k, v) => MapEntry(k, v.toJson())),
      };

  /// Create from JSON
  factory User.fromJson(Map<String, dynamic> json, Map<String, Role> roles) {
    final roleName = json['role'] as String? ?? 'user';
    final role = roles[roleName] ?? roles['user'] ?? Role.defaultUser();

    final user = User(
      id: json['id'] as String,
      displayName: json['displayName'] as String?,
      role: role,
      passwordHash: json['passwordHash'] as String?,
      maxT2ISimultaneous: json['maxT2ISimultaneous'] as int? ?? 1,
      maxImageHistoryMB: json['maxImageHistoryMB'] as int? ?? 1000,
      maxOutpathMB: json['maxOutpathMB'] as int? ?? 10000,
      mayCreateSessions: json['mayCreateSessions'] as bool? ?? true,
      createdTime: json['createdTime'] as int?,
    );

    user._lastUsedTime = json['lastUsedTime'] as int? ?? user._lastUsedTime;

    if (json['settings'] is Map) {
      user.settings = Map<String, dynamic>.from(json['settings'] as Map);
    }

    if (json['apiKeys'] is Map) {
      final keysMap = json['apiKeys'] as Map;
      for (final entry in keysMap.entries) {
        if (entry.value is Map) {
          user.apiKeys[entry.key.toString()] =
              APIKey.fromJson(Map<String, dynamic>.from(entry.value as Map));
        }
      }
    }

    return user;
  }

  /// Create the default local user
  factory User.local(Role ownerRole) => User(
        id: 'local',
        displayName: 'Local User',
        role: ownerRole,
        mayCreateSessions: true,
      );

  @override
  String toString() => 'User($id, role: ${role.name})';
}

/// API key for programmatic access
class APIKey {
  final String id;
  final String keyHash;
  final String name;
  final DateTime createdAt;
  DateTime? lastUsedAt;
  final Set<String> permissions;

  APIKey({
    required this.id,
    required this.keyHash,
    required this.name,
    required this.createdAt,
    this.lastUsedAt,
    Set<String>? permissions,
  }) : permissions = permissions ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'keyHash': keyHash,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt?.toIso8601String(),
        'permissions': permissions.toList(),
      };

  factory APIKey.fromJson(Map<String, dynamic> json) => APIKey(
        id: json['id'] as String,
        keyHash: json['keyHash'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastUsedAt: json['lastUsedAt'] != null
            ? DateTime.parse(json['lastUsedAt'] as String)
            : null,
        permissions: json['permissions'] is List
            ? Set<String>.from(json['permissions'] as List)
            : {},
      );
}
