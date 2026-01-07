import '../utils/fds_parser.dart';

/// Role model - defines permissions for users
class Role {
  /// Role name/ID
  final String name;

  /// Display name
  String displayName;

  /// Description of the role
  String description;

  /// Set of permission strings
  final Set<String> permissions;

  /// Maximum simultaneous T2I generations for this role
  int maxT2ISimultaneous;

  /// Maximum image history storage in MB for this role
  int maxImageHistoryMB;

  /// Maximum output directory storage in MB for this role
  int maxOutpathMB;

  /// Whether users with this role can create new sessions
  bool mayCreateSessions;

  /// Permissions this role explicitly denies
  final Set<String> deniedPermissions;

  Role({
    required this.name,
    String? displayName,
    this.description = '',
    Set<String>? permissions,
    this.maxT2ISimultaneous = 1,
    this.maxImageHistoryMB = 1000,
    this.maxOutpathMB = 10000,
    this.mayCreateSessions = true,
    Set<String>? deniedPermissions,
  })  : displayName = displayName ?? name,
        permissions = permissions ?? {},
        deniedPermissions = deniedPermissions ?? {};

  /// Check if role has a specific permission
  bool hasPermission(String permission) {
    // Check for explicit denial
    if (deniedPermissions.contains(permission)) {
      return false;
    }

    // Wildcard grants all permissions
    if (permissions.contains('*')) {
      return true;
    }

    // Check direct permission
    if (permissions.contains(permission)) {
      return true;
    }

    // Check wildcard patterns (e.g., "admin.*" matches "admin.users")
    for (final perm in permissions) {
      if (perm.endsWith('.*')) {
        final prefix = perm.substring(0, perm.length - 2);
        if (permission.startsWith('$prefix.') || permission == prefix) {
          return true;
        }
      }
    }

    return false;
  }

  /// Create from FDS data
  factory Role.fromFds(String name, Map<String, dynamic> data) {
    Set<String> parsePermissions(dynamic value) {
      if (value == null) return {};
      if (value is List) {
        return Set<String>.from(value.map((e) => e.toString()));
      }
      if (value is String) {
        return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
      }
      return {};
    }

    return Role(
      name: name,
      displayName: data['DisplayName']?.toString() ?? name,
      description: data['Description']?.toString() ?? '',
      permissions: parsePermissions(data['Permissions']),
      maxT2ISimultaneous: data['MaxT2ISimultaneous'] as int? ?? 1,
      maxImageHistoryMB: data['MaxImageHistoryMB'] as int? ?? 1000,
      maxOutpathMB: data['MaxOutpathMB'] as int? ?? 10000,
      mayCreateSessions: data['MayCreateSessions'] as bool? ?? true,
      deniedPermissions: parsePermissions(data['DeniedPermissions']),
    );
  }

  /// Convert to FDS data
  Map<String, dynamic> toFds() => {
        'DisplayName': displayName,
        'Description': description,
        'Permissions': permissions.toList(),
        'MaxT2ISimultaneous': maxT2ISimultaneous,
        'MaxImageHistoryMB': maxImageHistoryMB,
        'MaxOutpathMB': maxOutpathMB,
        'MayCreateSessions': mayCreateSessions,
        'DeniedPermissions': deniedPermissions.toList(),
      };

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'name': name,
        'displayName': displayName,
        'description': description,
        'permissions': permissions.toList(),
        'maxT2ISimultaneous': maxT2ISimultaneous,
        'maxImageHistoryMB': maxImageHistoryMB,
        'maxOutpathMB': maxOutpathMB,
        'mayCreateSessions': mayCreateSessions,
        'deniedPermissions': deniedPermissions.toList(),
      };

  /// Create from JSON
  factory Role.fromJson(Map<String, dynamic> json) => Role(
        name: json['name'] as String,
        displayName: json['displayName'] as String?,
        description: json['description'] as String? ?? '',
        permissions: json['permissions'] is List
            ? Set<String>.from(json['permissions'] as List)
            : {},
        maxT2ISimultaneous: json['maxT2ISimultaneous'] as int? ?? 1,
        maxImageHistoryMB: json['maxImageHistoryMB'] as int? ?? 1000,
        maxOutpathMB: json['maxOutpathMB'] as int? ?? 10000,
        mayCreateSessions: json['mayCreateSessions'] as bool? ?? true,
        deniedPermissions: json['deniedPermissions'] is List
            ? Set<String>.from(json['deniedPermissions'] as List)
            : {},
      );

  /// Default owner role with all permissions
  factory Role.owner() => Role(
        name: 'owner',
        displayName: 'Owner',
        description: 'Full access to all features',
        permissions: {'*'},
        maxT2ISimultaneous: 100,
        maxImageHistoryMB: 100000,
        maxOutpathMB: 1000000,
      );

  /// Default admin role
  factory Role.admin() => Role(
        name: 'admin',
        displayName: 'Administrator',
        description: 'Administrative access',
        permissions: {
          'admin',
          'admin.*',
          'user',
          'generate',
          'view_backends',
          'edit_backends',
          'view_models',
          'edit_models',
          'view_users',
          'edit_users',
        },
        maxT2ISimultaneous: 50,
        maxImageHistoryMB: 50000,
        maxOutpathMB: 500000,
      );

  /// Default power user role
  factory Role.powerUser() => Role(
        name: 'poweruser',
        displayName: 'Power User',
        description: 'Enhanced user capabilities',
        permissions: {
          'user',
          'generate',
          'view_backends',
          'view_models',
          'edit_own_models',
        },
        maxT2ISimultaneous: 10,
        maxImageHistoryMB: 10000,
        maxOutpathMB: 100000,
      );

  /// Default user role
  factory Role.defaultUser() => Role(
        name: 'user',
        displayName: 'User',
        description: 'Standard user access',
        permissions: {
          'user',
          'generate',
          'view_models',
        },
        maxT2ISimultaneous: 4,
        maxImageHistoryMB: 5000,
        maxOutpathMB: 50000,
      );

  /// Default guest role
  factory Role.guest() => Role(
        name: 'guest',
        displayName: 'Guest',
        description: 'View-only access',
        permissions: {
          'view_only',
        },
        maxT2ISimultaneous: 1,
        maxImageHistoryMB: 100,
        maxOutpathMB: 1000,
        mayCreateSessions: false,
      );

  @override
  String toString() => 'Role($name)';
}
