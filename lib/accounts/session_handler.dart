import 'dart:async';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../utils/logging.dart';
import '../utils/fds_parser.dart';
import 'user.dart';
import 'role.dart';
import 'session.dart';

/// Central session and user manager
/// Equivalent to SwarmUI's SessionHandler
class SessionHandler {
  static const int sessionIdLength = 40;
  static const Duration maxSessionAge = Duration(days: 31);

  /// Data directory path
  final String dataDir;

  /// Active sessions (in-memory)
  final Map<String, Session> sessions = {};

  /// Loaded users (in-memory cache)
  final Map<String, User> users = {};

  /// Permission roles
  final Map<String, Role> roles = {};

  /// Database boxes
  late Box<Map> _userBox;
  late Box<Map> _sessionBox;
  late Box<Map> _presetBox;
  late Box<Map> _genericDataBox;

  bool _hasShutdown = false;
  bool _initialized = false;

  /// Whether to persist data
  bool noPersist = false;

  SessionHandler({required this.dataDir});

  /// Initialize the session handler
  Future<void> init() async {
    if (_initialized) return;

    // Initialize Hive
    Hive.init('$dataDir/db');

    // Open boxes
    _userBox = await Hive.openBox<Map>('users');
    _sessionBox = await Hive.openBox<Map>('sessions');
    _presetBox = await Hive.openBox<Map>('presets');
    _genericDataBox = await Hive.openBox<Map>('generic_data');

    // Load roles from FDS file
    await _loadRoles();

    // Create default local user if needed
    if (!users.containsKey('local')) {
      users['local'] = User.local(roles['owner'] ?? Role.owner());
    }

    // Schedule old session cleanup
    Future.delayed(const Duration(seconds: 10), cleanOldSessions);

    _initialized = true;
    Logs.info('SessionHandler initialized');
  }

  /// Create new session
  Session createSession({
    required String source,
    String? userId,
    bool persist = true,
  }) {
    userId ??= 'local';

    final user = getUser(userId);

    if (!user.mayCreateSessions) {
      throw SessionException('User cannot create sessions');
    }

    // Generate unique ID
    String sessionId;
    var attempts = 0;
    do {
      sessionId = Session._generateId();
      attempts++;
      if (attempts > 1000) {
        throw SessionException('Failed to generate unique session ID');
      }
    } while (sessions.containsKey(sessionId));

    final session = Session(
      id: sessionId,
      user: user,
      originAddress: source,
      persist: persist,
    );

    sessions[sessionId] = session;
    user.currentSessions[sessionId] = session;

    // Persist to database
    if (persist && !noPersist) {
      _sessionBox.put(sessionId, session.toDbEntry().toJson());
    }

    Logs.debug('Created session $sessionId for user $userId from $source');
    return session;
  }

  /// Try to get session by ID
  Session? tryGetSession(String id) {
    // Check memory first
    if (sessions.containsKey(id)) {
      final session = sessions[id]!;
      session.updateLastUsedTime();
      return session;
    }

    // Try loading from database
    final dbEntry = _sessionBox.get(id);
    if (dbEntry == null) {
      return null;
    }

    try {
      final entry = SessionDatabaseEntry.fromJson(Map<String, dynamic>.from(dbEntry));

      // Check if session expired
      if (entry.isExpired(maxSessionAge)) {
        _sessionBox.delete(id);
        return null;
      }

      // Reconstruct session
      final user = getUser(entry.userId);
      final session = Session(
        id: entry.id,
        user: user,
        originAddress: entry.originAddress,
        originToken: entry.originToken,
      );

      sessions[id] = session;
      user.currentSessions[id] = session;
      session.updateLastUsedTime();

      return session;
    } catch (e) {
      Logs.warning('Failed to load session $id: $e');
      _sessionBox.delete(id);
      return null;
    }
  }

  /// Get session by ID, throwing if not found
  Session getSession(String id) {
    final session = tryGetSession(id);
    if (session == null) {
      throw SessionException('Session not found: $id');
    }
    return session;
  }

  /// Remove session
  void removeSession(Session session) {
    try {
      session.interrupt();
    } catch (_) {}

    sessions.remove(session.id);
    session.user.currentSessions.remove(session.id);

    if (!noPersist) {
      _sessionBox.delete(session.id);
    }

    Logs.debug('Removed session ${session.id}');
  }

  /// Get or create user
  User getUser(String userId, {bool makeNew = true}) {
    // Clean user ID
    userId = _cleanUserId(userId);

    if (users.containsKey(userId)) {
      return users[userId]!;
    }

    // Try loading from database
    final dbEntry = _userBox.get(userId);
    if (dbEntry != null) {
      try {
        final user = User.fromJson(Map<String, dynamic>.from(dbEntry), roles);
        users[userId] = user;
        return user;
      } catch (e) {
        Logs.warning('Failed to load user $userId: $e');
      }
    }

    if (!makeNew) {
      throw SessionException('User not found: $userId');
    }

    // Create new user
    final defaultRole = roles['user'] ?? Role.defaultUser();
    final user = User(
      id: userId,
      role: defaultRole,
    );

    users[userId] = user;
    if (!noPersist) {
      _userBox.put(userId, user.toJson());
    }

    Logs.info('Created new user: $userId');
    return user;
  }

  /// Check if user exists
  bool userExists(String userId) {
    userId = _cleanUserId(userId);
    return users.containsKey(userId) || _userBox.containsKey(userId);
  }

  /// Delete user
  void deleteUser(String userId) {
    userId = _cleanUserId(userId);

    final user = users[userId];
    if (user != null) {
      // Remove all user sessions
      for (final sessionId in user.currentSessions.keys.toList()) {
        final session = sessions[sessionId];
        if (session != null) {
          removeSession(session);
        }
      }
      users.remove(userId);
    }

    if (!noPersist) {
      _userBox.delete(userId);
    }

    Logs.info('Deleted user: $userId');
  }

  /// Validate credentials
  User? validateCredentials(String userId, String password) {
    final user = users[userId] ?? getUser(userId, makeNew: false);

    if (user.passwordHash == null) {
      return null;
    }

    final hash = _hashPassword(password, userId);
    if (hash == user.passwordHash) {
      return user;
    }

    return null;
  }

  /// Set user password
  void setUserPassword(String userId, String password) {
    final user = getUser(userId, makeNew: false);
    user.passwordHash = _hashPassword(password, userId);
    saveUser(user);
  }

  /// Hash a password
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Save user to database
  void saveUser(User user) {
    if (!noPersist) {
      _userBox.put(user.id, user.toJson());
    }
  }

  /// Get all users
  List<User> getAllUsers() {
    // Load all from database
    for (final key in _userBox.keys) {
      if (!users.containsKey(key)) {
        getUser(key as String, makeNew: false);
      }
    }
    return users.values.toList();
  }

  /// Clean old sessions
  Future<void> cleanOldSessions() async {
    if (noPersist) return;

    var cleaned = 0;
    final keysToDelete = <String>[];

    for (final key in _sessionBox.keys) {
      final entry = _sessionBox.get(key);
      if (entry != null) {
        final entryData = SessionDatabaseEntry.fromJson(
            Map<String, dynamic>.from(entry));
        if (entryData.isExpired(maxSessionAge)) {
          keysToDelete.add(key as String);
          cleaned++;
        }
      }
    }

    for (final key in keysToDelete) {
      _sessionBox.delete(key);
      sessions.remove(key);
    }

    if (cleaned > 0) {
      Logs.info('Cleaned $cleaned old sessions');
    }
  }

  /// Get role by name
  Role? getRole(String name) => roles[name];

  /// Create or update role
  void setRole(Role role) {
    roles[role.name] = role;
    _saveRoles();
  }

  /// Delete role
  void deleteRole(String name) {
    if (['owner', 'admin', 'user', 'guest'].contains(name)) {
      throw SessionException('Cannot delete built-in role: $name');
    }
    roles.remove(name);
    _saveRoles();
  }

  /// Shutdown
  Future<void> shutdown() async {
    if (_hasShutdown) return;
    _hasShutdown = true;

    await save();
    sessions.clear();

    await _userBox.close();
    await _sessionBox.close();
    await _presetBox.close();
    await _genericDataBox.close();

    Logs.info('SessionHandler shutdown complete');
  }

  /// Save all data
  Future<void> save() async {
    await _saveRoles();

    // Save all users
    for (final user in users.values) {
      saveUser(user);
    }

    // Update session timestamps
    for (final session in sessions.values) {
      if (session.persist && !noPersist) {
        _sessionBox.put(session.id, session.toDbEntry().toJson());
      }
    }
  }

  String _cleanUserId(String userId) {
    // Remove invalid characters
    return userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();
  }

  Future<void> _loadRoles() async {
    // Add built-in roles
    roles['owner'] = Role.owner();
    roles['admin'] = Role.admin();
    roles['poweruser'] = Role.powerUser();
    roles['user'] = Role.defaultUser();
    roles['guest'] = Role.guest();

    // Load custom roles from FDS
    final rolesFile = File('$dataDir/Roles.fds');
    if (await rolesFile.exists()) {
      try {
        final content = await rolesFile.readAsString();
        final parsed = FdsParser.parse(content);
        for (final entry in parsed.entries) {
          if (entry.value is Map) {
            final role = Role.fromFds(entry.key, entry.value as Map<String, dynamic>);
            // Don't overwrite built-in roles with custom ones
            if (!['owner', 'admin', 'poweruser', 'user', 'guest'].contains(role.name)) {
              roles[entry.key] = role;
            }
          }
        }
        Logs.debug('Loaded ${roles.length} roles');
      } catch (e) {
        Logs.warning('Failed to load custom roles: $e');
      }
    }
  }

  Future<void> _saveRoles() async {
    if (noPersist) return;

    final rolesFile = File('$dataDir/Roles.fds');
    final data = <String, dynamic>{};

    for (final role in roles.values) {
      // Only save custom roles, not built-in ones
      if (!['owner', 'admin', 'poweruser', 'user', 'guest'].contains(role.name)) {
        data[role.name] = role.toFds();
      }
    }

    if (data.isNotEmpty) {
      await rolesFile.parent.create(recursive: true);
      await rolesFile.writeAsString(FdsParser.serialize(data));
    }
  }

  // ========== Preset Management ==========

  /// Get user presets
  Map<String, dynamic> getPresets(String userId) {
    final key = 'presets_$userId';
    final data = _presetBox.get(key);
    if (data == null) return {};
    return Map<String, dynamic>.from(data);
  }

  /// Save user presets
  void savePresets(String userId, Map<String, dynamic> presets) {
    if (noPersist) return;
    final key = 'presets_$userId';
    _presetBox.put(key, presets);
  }

  /// Get single preset
  Map<String, dynamic>? getPreset(String userId, String presetName) {
    final presets = getPresets(userId);
    final preset = presets[presetName];
    if (preset is Map) {
      return Map<String, dynamic>.from(preset);
    }
    return null;
  }

  /// Save single preset
  void savePreset(String userId, String presetName, Map<String, dynamic> preset) {
    final presets = getPresets(userId);
    presets[presetName] = preset;
    savePresets(userId, presets);
  }

  /// Delete preset
  void deletePreset(String userId, String presetName) {
    final presets = getPresets(userId);
    presets.remove(presetName);
    savePresets(userId, presets);
  }

  // ========== Generic Data Storage ==========

  /// Get generic data for user
  dynamic getGenericData(String userId, String key) {
    final fullKey = '${userId}_$key';
    final data = _genericDataBox.get(fullKey);
    return data;
  }

  /// Set generic data for user
  void setGenericData(String userId, String key, dynamic value) {
    if (noPersist) return;
    final fullKey = '${userId}_$key';
    _genericDataBox.put(fullKey, value);
  }

  /// Delete generic data for user
  void deleteGenericData(String userId, String key) {
    if (noPersist) return;
    final fullKey = '${userId}_$key';
    _genericDataBox.delete(fullKey);
  }
}

/// Exception for session-related errors
class SessionException implements Exception {
  final String message;
  SessionException(this.message);

  @override
  String toString() => 'SessionException: $message';
}
