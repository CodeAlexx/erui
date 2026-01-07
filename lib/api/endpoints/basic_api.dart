import '../../core/program.dart';
import '../../accounts/permissions.dart';
import '../api.dart';
import '../api_call.dart';
import '../api_context.dart';

/// Basic API endpoints for core functionality
class BasicAPI {
  /// Register all basic API endpoints
  static void register() {
    // Session management
    Api.registerCall(ApiCall.public(
      name: 'GetNewSession',
      description: 'Create a new session',
      handler: _getNewSession,
    ));

    Api.registerCall(ApiCall(
      name: 'GetMyUserData',
      description: 'Get current user data',
      handler: _getMyUserData,
    ));

    Api.registerCall(ApiCall(
      name: 'SetParamEdits',
      description: 'Save parameter settings for user',
      requiredPermissions: {'user'},
      handler: _setParamEdits,
    ));

    Api.registerCall(ApiCall(
      name: 'GetParamEdits',
      description: 'Get parameter settings for user',
      requiredPermissions: {'user'},
      handler: _getParamEdits,
    ));

    // Server info
    Api.registerCall(ApiCall.public(
      name: 'GetServerCapabilities',
      description: 'Get server capabilities and version info',
      handler: _getServerCapabilities,
    ));

    Api.registerCall(ApiCall.public(
      name: 'GetServerResourceInfo',
      description: 'Get server resource usage',
      handler: _getServerResourceInfo,
    ));

    Api.registerCall(ApiCall(
      name: 'InterruptAll',
      description: 'Interrupt all generations for current session',
      requiredPermissions: {'user'},
      handler: _interruptAll,
    ));

    // Language and theme
    Api.registerCall(ApiCall.public(
      name: 'GetLanguage',
      description: 'Get language strings',
      handler: _getLanguage,
    ));

    Api.registerCall(ApiCall.public(
      name: 'ListThemes',
      description: 'List available themes',
      handler: _listThemes,
    ));

    // User settings
    Api.registerCall(ApiCall(
      name: 'ChangeUserSettings',
      description: 'Update user settings',
      requiredPermissions: {'user'},
      handler: _changeUserSettings,
    ));

    Api.registerCall(ApiCall(
      name: 'GetCurrentStatus',
      description: 'Get current generation status',
      requiredPermissions: {'user'},
      handler: _getCurrentStatus,
    ));

    // Session management
    Api.registerCall(ApiCall(
      name: 'ListMySessions',
      description: 'List active sessions for current user',
      requiredPermissions: {'user'},
      handler: _listMySessions,
    ));

    Api.registerCall(ApiCall(
      name: 'RevokeSession',
      description: 'Revoke a session',
      requiredPermissions: {'user'},
      handler: _revokeSession,
    ));
  }

  /// Create a new session
  static Future<Map<String, dynamic>> _getNewSession(ApiContext ctx) async {
    final source = ctx.clientIp;
    final userId = ctx.get<String>('user_id');

    final session = Program.instance.sessions.createSession(
      source: source,
      userId: userId,
    );

    return {
      'session_id': session.id,
      'user_id': session.user.id,
      'output_append_user': Program.instance.serverSettings.paths.appendUserNameToOutputPath,
    };
  }

  /// Get current user data
  static Future<Map<String, dynamic>> _getMyUserData(ApiContext ctx) async {
    final session = ctx.session;
    if (session == null) {
      return {
        'user_id': 'local',
        'permissions': <String>[],
        'roles': ['guest'],
      };
    }

    final user = session.user;
    return {
      'user_id': user.id,
      'display_name': user.displayName,
      'permissions': user.role.permissions.toList(),
      'roles': [user.role.name],
      'max_t2i_simultaneous': user.maxT2ISimultaneous,
      'settings': user.settings,
    };
  }

  /// Save parameter settings
  static Future<Map<String, dynamic>> _setParamEdits(ApiContext ctx) async {
    final session = ctx.requireSession();
    final edits = ctx.getMap('edits');

    Program.instance.sessions.setGenericData(
      session.user.id,
      'param_edits',
      edits,
    );

    return {'success': true};
  }

  /// Get parameter settings
  static Future<Map<String, dynamic>> _getParamEdits(ApiContext ctx) async {
    final session = ctx.requireSession();

    final edits = Program.instance.sessions.getGenericData(
      session.user.id,
      'param_edits',
    );

    return {
      'edits': edits ?? {},
    };
  }

  /// Get server capabilities
  static Future<Map<String, dynamic>> _getServerCapabilities(ApiContext ctx) async {
    return {
      'version': '0.1.0',
      'server_name': 'EriUI',
      'features': [
        'comfyui_backend',
        'multi_backend',
        'model_management',
        'preset_system',
        'user_authentication',
        'session_management',
        'websocket_generation',
      ],
      'backends': Program.instance.backends.backendTypes.keys.toList(),
      'api_version': 1,
    };
  }

  /// Get server resource info
  static Future<Map<String, dynamic>> _getServerResourceInfo(ApiContext ctx) async {
    // TODO: Implement actual resource monitoring
    return {
      'cpu_usage': 0.0,
      'ram_usage': 0.0,
      'gpu_info': <Map<String, dynamic>>[],
      'queue_length': 0,
      'active_generations': 0,
    };
  }

  /// Interrupt all generations
  static Future<Map<String, dynamic>> _interruptAll(ApiContext ctx) async {
    final session = ctx.requireSession();
    session.interrupt();

    return {'success': true};
  }

  /// Get language strings
  static Future<Map<String, dynamic>> _getLanguage(ApiContext ctx) async {
    final lang = ctx.get<String>('language') ?? 'en';

    // TODO: Implement language loading
    return {
      'language': lang,
      'strings': <String, String>{},
    };
  }

  /// List available themes
  static Future<Map<String, dynamic>> _listThemes(ApiContext ctx) async {
    // TODO: Implement theme listing
    return {
      'themes': [
        {'id': 'dark_dreams', 'name': 'Dark Dreams'},
        {'id': 'modern_dark', 'name': 'Modern Dark'},
        {'id': 'light', 'name': 'Light'},
        {'id': 'gravity_blue', 'name': 'Gravity Blue'},
      ],
    };
  }

  /// Change user settings
  static Future<Map<String, dynamic>> _changeUserSettings(ApiContext ctx) async {
    final session = ctx.requireSession();
    final settings = ctx.getMap('settings');

    for (final entry in settings.entries) {
      session.user.setSetting(entry.key, entry.value);
    }

    Program.instance.sessions.saveUser(session.user);

    return {'success': true};
  }

  /// Get current generation status
  static Future<Map<String, dynamic>> _getCurrentStatus(ApiContext ctx) async {
    final session = ctx.requireSession();

    return {
      'waiting_gens': session.waitingGenerations,
      'loading_models': session.loadingModels,
      'waiting_backends': session.waitingBackends,
      'live_gens': session.liveGens,
    };
  }

  /// List user's sessions
  static Future<Map<String, dynamic>> _listMySessions(ApiContext ctx) async {
    final session = ctx.requireSession();
    final user = session.user;

    final sessions = user.currentSessions.values.map((s) {
      final sess = s as dynamic;
      return {
        'id': sess.id,
        'origin': sess.originAddress,
        'last_used': sess.lastUsedTime,
        'is_current': sess.id == session.id,
      };
    }).toList();

    return {'sessions': sessions};
  }

  /// Revoke a session
  static Future<Map<String, dynamic>> _revokeSession(ApiContext ctx) async {
    final currentSession = ctx.requireSession();
    final sessionId = ctx.require<String>('session_id');

    // Can't revoke current session
    if (sessionId == currentSession.id) {
      throw ApiException('Cannot revoke current session');
    }

    // Can only revoke own sessions (unless admin)
    final targetSession = Program.instance.sessions.tryGetSession(sessionId);
    if (targetSession == null) {
      throw ApiException('Session not found');
    }

    if (targetSession.user.id != currentSession.user.id) {
      ctx.requirePermission('admin');
    }

    Program.instance.sessions.removeSession(targetSession);

    return {'success': true};
  }
}
