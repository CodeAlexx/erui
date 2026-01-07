/// Permission constants and registry for EriUI
/// Equivalent to SwarmUI's Permissions class
class Permissions {
  /// All registered permissions
  static final Map<String, PermissionInfo> _registry = {};

  /// Ordered list of permissions (for UI display)
  static final List<PermissionInfo> _ordered = [];

  // ========== Core Permissions ==========

  /// Full administrative access - all permissions
  static const String admin = 'admin';

  /// Standard user access
  static const String user = 'user';

  /// Generate images
  static const String generate = 'generate';

  /// View-only access (no generation)
  static const String viewOnly = 'view_only';

  // ========== Backend Permissions ==========

  /// View backends and their status
  static const String viewBackends = 'view_backends';

  /// Create, edit, delete backends
  static const String editBackends = 'edit_backends';

  /// Restart backends
  static const String restartBackends = 'restart_backends';

  // ========== Model Permissions ==========

  /// View model list
  static const String viewModels = 'view_models';

  /// Edit model metadata
  static const String editModels = 'edit_models';

  /// Delete models
  static const String deleteModels = 'delete_models';

  /// Download/install models
  static const String installModels = 'install_models';

  /// Edit only own models (uploaded by this user)
  static const String editOwnModels = 'edit_own_models';

  // ========== User Permissions ==========

  /// View other users
  static const String viewUsers = 'view_users';

  /// Edit other users
  static const String editUsers = 'edit_users';

  /// Create new users
  static const String createUsers = 'create_users';

  /// Delete users
  static const String deleteUsers = 'delete_users';

  /// Modify roles
  static const String editRoles = 'edit_roles';

  // ========== Server Permissions ==========

  /// View server settings
  static const String viewServerSettings = 'view_server_settings';

  /// Edit server settings
  static const String editServerSettings = 'edit_server_settings';

  /// View server logs
  static const String viewLogs = 'view_logs';

  /// Shutdown/restart server
  static const String serverControl = 'server_control';

  // ========== Output Permissions ==========

  /// View image history
  static const String viewHistory = 'view_history';

  /// View other users' outputs
  static const String viewOthersOutputs = 'view_others_outputs';

  /// Delete outputs
  static const String deleteOutputs = 'delete_outputs';

  /// Delete other users' outputs
  static const String deleteOthersOutputs = 'delete_others_outputs';

  // ========== Feature Permissions ==========

  /// Use extensions
  static const String useExtensions = 'use_extensions';

  /// Install extensions
  static const String installExtensions = 'install_extensions';

  /// Use webhooks
  static const String useWebhooks = 'use_webhooks';

  /// Access API keys
  static const String manageApiKeys = 'manage_api_keys';

  /// Use batch generation
  static const String useBatch = 'use_batch';

  /// Use wildcards
  static const String useWildcards = 'use_wildcards';

  /// Register all default permissions
  static void registerDefaults() {
    // Clear existing
    _registry.clear();
    _ordered.clear();

    // Core
    _register(PermissionInfo(
      id: admin,
      name: 'Administrator',
      description: 'Full administrative access to all features',
      category: 'Core',
      order: 0,
    ));

    _register(PermissionInfo(
      id: user,
      name: 'User Access',
      description: 'Standard user features',
      category: 'Core',
      order: 1,
    ));

    _register(PermissionInfo(
      id: generate,
      name: 'Generate Images',
      description: 'Generate images using AI models',
      category: 'Core',
      order: 2,
    ));

    _register(PermissionInfo(
      id: viewOnly,
      name: 'View Only',
      description: 'View UI without generating',
      category: 'Core',
      order: 3,
    ));

    // Backends
    _register(PermissionInfo(
      id: viewBackends,
      name: 'View Backends',
      description: 'View backend list and status',
      category: 'Backends',
      order: 10,
    ));

    _register(PermissionInfo(
      id: editBackends,
      name: 'Edit Backends',
      description: 'Create, edit, and delete backends',
      category: 'Backends',
      order: 11,
    ));

    _register(PermissionInfo(
      id: restartBackends,
      name: 'Restart Backends',
      description: 'Restart backend processes',
      category: 'Backends',
      order: 12,
    ));

    // Models
    _register(PermissionInfo(
      id: viewModels,
      name: 'View Models',
      description: 'View model list and metadata',
      category: 'Models',
      order: 20,
    ));

    _register(PermissionInfo(
      id: editModels,
      name: 'Edit Models',
      description: 'Edit model metadata',
      category: 'Models',
      order: 21,
    ));

    _register(PermissionInfo(
      id: deleteModels,
      name: 'Delete Models',
      description: 'Delete model files',
      category: 'Models',
      order: 22,
    ));

    _register(PermissionInfo(
      id: installModels,
      name: 'Install Models',
      description: 'Download and install new models',
      category: 'Models',
      order: 23,
    ));

    _register(PermissionInfo(
      id: editOwnModels,
      name: 'Edit Own Models',
      description: 'Edit metadata for models you uploaded',
      category: 'Models',
      order: 24,
    ));

    // Users
    _register(PermissionInfo(
      id: viewUsers,
      name: 'View Users',
      description: 'View user list',
      category: 'Users',
      order: 30,
    ));

    _register(PermissionInfo(
      id: editUsers,
      name: 'Edit Users',
      description: 'Edit user settings and roles',
      category: 'Users',
      order: 31,
    ));

    _register(PermissionInfo(
      id: createUsers,
      name: 'Create Users',
      description: 'Create new user accounts',
      category: 'Users',
      order: 32,
    ));

    _register(PermissionInfo(
      id: deleteUsers,
      name: 'Delete Users',
      description: 'Delete user accounts',
      category: 'Users',
      order: 33,
    ));

    _register(PermissionInfo(
      id: editRoles,
      name: 'Edit Roles',
      description: 'Create and edit permission roles',
      category: 'Users',
      order: 34,
    ));

    // Server
    _register(PermissionInfo(
      id: viewServerSettings,
      name: 'View Server Settings',
      description: 'View server configuration',
      category: 'Server',
      order: 40,
    ));

    _register(PermissionInfo(
      id: editServerSettings,
      name: 'Edit Server Settings',
      description: 'Modify server configuration',
      category: 'Server',
      order: 41,
    ));

    _register(PermissionInfo(
      id: viewLogs,
      name: 'View Logs',
      description: 'View server logs',
      category: 'Server',
      order: 42,
    ));

    _register(PermissionInfo(
      id: serverControl,
      name: 'Server Control',
      description: 'Shutdown or restart the server',
      category: 'Server',
      order: 43,
    ));

    // Outputs
    _register(PermissionInfo(
      id: viewHistory,
      name: 'View History',
      description: 'View image generation history',
      category: 'Outputs',
      order: 50,
    ));

    _register(PermissionInfo(
      id: viewOthersOutputs,
      name: 'View Others\' Outputs',
      description: 'View other users\' generated images',
      category: 'Outputs',
      order: 51,
    ));

    _register(PermissionInfo(
      id: deleteOutputs,
      name: 'Delete Outputs',
      description: 'Delete your own generated images',
      category: 'Outputs',
      order: 52,
    ));

    _register(PermissionInfo(
      id: deleteOthersOutputs,
      name: 'Delete Others\' Outputs',
      description: 'Delete other users\' generated images',
      category: 'Outputs',
      order: 53,
    ));

    // Features
    _register(PermissionInfo(
      id: useExtensions,
      name: 'Use Extensions',
      description: 'Use installed extensions',
      category: 'Features',
      order: 60,
    ));

    _register(PermissionInfo(
      id: installExtensions,
      name: 'Install Extensions',
      description: 'Install new extensions',
      category: 'Features',
      order: 61,
    ));

    _register(PermissionInfo(
      id: useWebhooks,
      name: 'Use Webhooks',
      description: 'Configure webhook notifications',
      category: 'Features',
      order: 62,
    ));

    _register(PermissionInfo(
      id: manageApiKeys,
      name: 'Manage API Keys',
      description: 'Create and manage API keys',
      category: 'Features',
      order: 63,
    ));

    _register(PermissionInfo(
      id: useBatch,
      name: 'Use Batch',
      description: 'Use batch generation features',
      category: 'Features',
      order: 64,
    ));

    _register(PermissionInfo(
      id: useWildcards,
      name: 'Use Wildcards',
      description: 'Use wildcard prompts',
      category: 'Features',
      order: 65,
    ));

    // Sort ordered list
    _ordered.sort((a, b) => a.order.compareTo(b.order));
  }

  static void _register(PermissionInfo info) {
    _registry[info.id] = info;
    _ordered.add(info);
  }

  /// Get permission info by ID
  static PermissionInfo? getInfo(String id) => _registry[id];

  /// Get all permissions
  static List<PermissionInfo> get all => List.unmodifiable(_ordered);

  /// Get permissions by category
  static List<PermissionInfo> getByCategory(String category) {
    return _ordered.where((p) => p.category == category).toList();
  }

  /// Get all categories
  static List<String> get categories {
    return _ordered.map((p) => p.category).toSet().toList();
  }

  /// Check if a permission ID is valid
  static bool isValid(String id) => _registry.containsKey(id);

  /// Fix ordering (call after all permissions registered)
  static void fixOrdered() {
    _ordered.sort((a, b) => a.order.compareTo(b.order));
  }

  /// Get permissions that a given permission implies (grants)
  static Set<String> getImplied(String permission) {
    final implied = <String>{};

    // Admin implies everything
    if (permission == admin) {
      implied.addAll(_registry.keys);
      return implied;
    }

    // User implies basic permissions
    if (permission == user) {
      implied.add(generate);
      implied.add(viewModels);
      implied.add(viewHistory);
      implied.add(deleteOutputs);
      implied.add(useBatch);
      implied.add(useWildcards);
      implied.add(useExtensions);
      return implied;
    }

    // Edit permissions imply view permissions
    if (permission == editBackends) {
      implied.add(viewBackends);
    }
    if (permission == editModels) {
      implied.add(viewModels);
    }
    if (permission == editUsers) {
      implied.add(viewUsers);
    }
    if (permission == editServerSettings) {
      implied.add(viewServerSettings);
    }
    if (permission == deleteOthersOutputs) {
      implied.add(viewOthersOutputs);
      implied.add(deleteOutputs);
    }

    return implied;
  }
}

/// Information about a permission
class PermissionInfo {
  final String id;
  final String name;
  final String description;
  final String category;
  final int order;

  const PermissionInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.order,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'order': order,
      };

  @override
  String toString() => 'Permission($id)';
}
